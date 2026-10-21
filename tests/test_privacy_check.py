import importlib.util
import json
import pathlib
import re
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("check_privacy", ROOT / "scripts/check-privacy.py")
CHECK = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECK)


# The specimen is assembled rather than written out, so this file carries no
# literal that the published tree check would report. The check still sees the
# assembled value when it runs.
SPECIMEN_ADDRESS = "person@" + "personal.invalid"


class PrivacyCheckTest(unittest.TestCase):
    def scan(self, body, patterns=(), files=None, source="working-tree"):
        if files is None:
            directory = tempfile.mkdtemp()
            path = pathlib.Path(directory) / "sample.txt"
            path.write_text(body)
            files = [str(path)]
        findings, coverage = CHECK.scan(list(patterns), files=files, source=source)
        return findings, coverage

    def kinds(self, findings):
        return {entry["kind"] for entry in findings}

    def categories(self, findings):
        return {entry["category"] for entry in findings}

    # --- category heuristics ------------------------------------------------

    def test_personal_email_is_reported_as_a_heuristic(self):
        findings, _ = self.scan("owner = '{0}'\n".format(SPECIMEN_ADDRESS))
        self.assertIn("category-heuristic", self.kinds(findings))
        self.assertIn("email", self.categories(findings))

    def test_private_repository_path_is_reported_as_a_heuristic(self):
        findings, _ = self.scan("url = 'github:owner/private-project'\n")
        self.assertIn("repository-path", self.categories(findings))

    def test_account_identifier_is_reported_as_a_heuristic(self):
        findings, _ = self.scan("id = '0123456789abcdef0123456789abcdef'\n")
        self.assertIn("account-identifier", self.categories(findings))

    def test_windows_account_directory_is_reported(self):
        findings, _ = self.scan(r"path = 'C:\Users\somebody\Downloads'" + "\n")
        self.assertIn("windows-account", self.categories(findings))

    def test_home_account_directory_is_reported(self):
        findings, _ = self.scan("path = '/home/somebody/file'\n")
        self.assertIn("home-account", self.categories(findings))

    def test_oauth_client_identifier_is_reported(self):
        specimen = "AIza" + "Sy" + "0" * 33
        findings, _ = self.scan("key = '{0}'\n".format(specimen))
        self.assertIn("oauth-client-id", self.categories(findings))

    # --- false positives ----------------------------------------------------

    def test_system_account_email_is_allowed(self):
        findings, _ = self.scan("account = 'user@3000.service'\n")
        self.assertEqual(
            [entry for entry in findings if entry["category"] == "email"], [])

    def test_allowlisted_public_identifier_is_allowed(self):
        allowed, _, _ = CHECK.load_allowlist()
        self.assertTrue(allowed)
        public = sorted(allowed)[0]
        findings, _ = self.scan("value = '{0}'\n".format(public))
        self.assertNotIn(public, [entry["value"] for entry in findings])

    def test_suffix_allowlist_applies(self):
        allowed, suffixes, _ = CHECK.load_allowlist()
        self.assertTrue(suffixes)
        findings, _ = self.scan("value = 'someone@3000.service'\n")
        self.assertEqual(
            [entry for entry in findings if entry["category"] == "email"], [])

    def test_documented_placeholder_is_ignored(self):
        findings, _ = self.scan("path = 'C:\\\\Users\\\\<windows-user>\\\\Downloads'\n")
        self.assertEqual(
            [entry for entry in findings if entry["category"] == "windows-account"], [])

    def test_api_path_form_is_not_a_repository_path(self):
        findings, _ = self.scan(
            "url = 'https://api.github.com/repos/owner/project/releases'\n")
        self.assertEqual(
            [entry for entry in findings if entry["category"] == "repository-path"], [])

    # --- proven private mappings -------------------------------------------

    def test_exact_private_value_is_reported_as_proven(self):
        findings, _ = self.scan(
            "value = 'a-private-value'\n", patterns=["a-private-value"])
        self.assertIn("proven-private-mapping", self.kinds(findings))
        for entry in findings:
            if entry["kind"] == "proven-private-mapping":
                self.assertNotIn("value", entry)

    def test_heuristic_and_proven_kinds_are_distinct(self):
        # A value that is both a shape the heuristic recognises and an exact
        # match against the operator's private set produces both kinds, and
        # they are not the same claim.
        findings, _ = self.scan(
            "owner = '{0}'\n".format(SPECIMEN_ADDRESS), patterns=[SPECIMEN_ADDRESS])
        self.assertIn("category-heuristic", self.kinds(findings))
        self.assertIn("proven-private-mapping", self.kinds(findings))

    # --- bypass attempts ----------------------------------------------------

    def test_value_split_across_lines_is_still_caught(self):
        body = "value = 'a-private-" + "\n" + "value'\n"
        findings, _ = self.scan(body, patterns=["a-private-value"])
        self.assertIn("proven-private-mapping", self.kinds(findings))

    def test_value_split_by_spaces_is_still_caught(self):
        body = "value = 'a private value'\n"
        findings, _ = self.scan(body, patterns=["a private value"])
        self.assertIn("proven-private-mapping", self.kinds(findings))

    def test_private_value_in_a_heuristic_shape_is_caught(self):
        findings, _ = self.scan("owner = '{0}'\n".format(SPECIMEN_ADDRESS))
        self.assertIn("email", self.categories(findings))

    def test_an_empty_allowlist_does_not_suppress_findings(self):
        # A reviewer cannot widen the allowlist silently: an entry must carry
        # a reason, and the loader ignores a value with no reason text.
        allowed, _, reasons = CHECK.load_allowlist()
        for value in allowed:
            self.assertNotEqual(value.strip(), "")

    def test_a_public_identifier_that_extends_a_private_one_is_not_reported(self):
        # A private repository name is often the start of a longer public
        # identifier. Matching on the identifier boundary keeps a public value
        # from reading as a private one.
        findings, _ = self.scan(
            "image = 'ghcr.io/example/private-project-suffix:latest'\n",
            patterns=["example/private-project"])
        self.assertEqual(
            [entry for entry in findings if entry["kind"] == "proven-private-mapping"], [])

    def test_a_whole_identifier_is_reported(self):
        findings, _ = self.scan(
            "repo = 'example/private-project'\n",
            patterns=["example/private-project"])
        self.assertIn("proven-private-mapping", self.kinds(findings))

    # --- the managed placeholder invariant ----------------------------------

    def test_a_lock_that_names_an_unreviewed_source_is_refused(self):
        document = json.dumps({
            "version": 7,
            "root": "root",
            "nodes": {
                "nixpkgs": {
                    "locked": {
                        "lastModified": 1,
                        "narHash": "sha256-" + "A" * 43 + "=",
                        "owner": "example",
                        "repo": "unreviewed-project",
                        "rev": "0" * 40,
                        "type": "github",
                    },
                    "original": {
                        "owner": "example",
                        "repo": "unreviewed-project",
                        "rev": "0" * 40,
                        "type": "github",
                    },
                },
                "root": {"inputs": {"nixpkgs": "nixpkgs"}},
            },
        })
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "flake.lock"
            path.write_text(document)
            findings, _ = CHECK.scan([], files=[str(path)], source="working-tree")
            categories = {entry["category"] for entry in findings}
            self.assertIn("unapproved-flake-source", categories)

    def test_a_repository_that_does_not_declare_the_input_is_not_asked_for_one(self):
        document = json.dumps({
            "version": 7,
            "root": "root",
            "nodes": {
                "nixpkgs": {
                    "locked": {
                        "lastModified": 1,
                        "narHash": "sha256-" + "A" * 43 + "=",
                        "owner": "NixOS",
                        "repo": "nixpkgs",
                        "rev": "0" * 40,
                        "type": "github",
                    },
                    "original": {
                        "owner": "NixOS",
                        "ref": "nixos-unstable",
                        "repo": "nixpkgs",
                        "type": "github",
                    },
                },
                "root": {"inputs": {"nixpkgs": "nixpkgs"}},
            },
        })
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "flake.lock"
            path.write_text(document)
            findings, _ = CHECK.scan([], files=[str(path)], source="working-tree")
            categories = {entry["category"] for entry in findings}
            self.assertNotIn("private-source-placeholder", categories)

    # --- the workflow secret boundary ----------------------------------------

    def workflow_jobs(self):
        """Every job block in every workflow, with the lines that declare it.

        The workflows are read as text on purpose. There is no YAML library in
        the development shell, and the structure that matters here is the
        indentation of the job blocks, which is regular and checked by the
        workflow linter in the full suite.
        """
        jobs = []
        for path in sorted((ROOT / ".github" / "workflows").glob("*.yml")):
            lines = path.read_text().splitlines()
            in_jobs = False
            name = None
            body = []
            for line in lines:
                if line.rstrip() == "jobs:":
                    in_jobs = True
                    continue
                if not in_jobs:
                    continue
                if line and not line[0].isspace():
                    in_jobs = False
                    continue
                header = re.match(r"^  ([A-Za-z0-9_-]+):\s*$", line)
                if header:
                    if name is not None:
                        jobs.append((path.name, name, body))
                    name = header.group(1)
                    body = []
                    continue
                if name is not None:
                    body.append(line)
            if name is not None:
                jobs.append((path.name, name, body))
        return jobs

    def test_the_workflow_jobs_are_found(self):
        jobs = self.workflow_jobs()
        self.assertTrue(jobs)
        names = {(path, name) for path, name, _ in jobs}
        self.assertIn(("ci.yml", "check"), names)
        self.assertIn(("flake-update.yml", "update"), names)

    def test_a_job_that_uses_a_private_secret_declares_the_environment(self):
        """The private source and the deploy key belong behind the review.

        This proves the declaration in the workflow source. It says nothing
        about the forge's live secret scope, which a source file cannot show,
        so it does not claim to verify that.
        """
        private = ("GHOSTSHIP_PRIVATE_SOURCES", "GHOSTSHIP_AGENT_READ_KEY")
        for path, name, body in self.workflow_jobs():
            uses = [secret for secret in private if "secrets." + secret in "\n".join(body)]
            if not uses:
                continue
            declared = [
                line.strip() for line in body
                if line.strip().startswith("environment:")
            ]
            self.assertEqual(
                declared, ["environment: private-source-ci"],
                "{0} job {1} uses {2} without declaring the environment".format(
                    path, name, ", ".join(uses)),
            )

    def test_no_workflow_references_the_private_source_outside_an_environment(self):
        for path, name, body in self.workflow_jobs():
            text = "\n".join(body)
            if "secrets.GHOSTSHIP_PRIVATE_SOURCES" not in text:
                continue
            self.assertIn(
                "environment: private-source-ci",
                text,
                "{0} job {1} references the private source outside the environment".format(
                    path, name),
            )

    # --- coverage -----------------------------------------------------------

    def test_coverage_counts_the_scanned_files(self):
        findings, coverage = self.scan("value = 1\n")
        self.assertEqual(coverage["scanned"], 1)
        self.assertEqual(coverage["binary"], 0)

    def test_boundaries_are_declared(self):
        self.assertTrue(CHECK.BOUNDARIES)
        for boundary in CHECK.BOUNDARIES:
            self.assertIsInstance(boundary, str)
            self.assertTrue(boundary.strip())


if __name__ == "__main__":
    unittest.main()
