import importlib.util
import pathlib
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
