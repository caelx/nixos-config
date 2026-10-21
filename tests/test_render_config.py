import importlib.util
import json
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
RENDER = ROOT / "modules/self-hosted/render-config.py"
SPEC = importlib.util.spec_from_file_location("check_privacy", ROOT / "scripts/check-privacy.py")
CHECK = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECK)


# The specimen is assembled rather than written out, so this file carries no
# literal that the published tree check would report.
SPECIMEN_ACCOUNT = "0" * 32


class RenderConfigTest(unittest.TestCase):
    def render(self, template, env, target, mode="0600", owner=""):
        with tempfile.TemporaryDirectory() as directory:
            base = pathlib.Path(directory)
            template_path = base / "template.json"
            env_path = base / "secrets.env"
            template_path.write_text(json.dumps(template))
            env_path.write_text(env)
            arguments = [sys.executable, str(RENDER), str(template_path), str(env_path),
                         str(target)]
            if mode:
                arguments += ["--mode", mode]
            if owner:
                arguments += ["--owner", owner]
            result = subprocess.run(arguments, capture_output=True, text=True)
            return result

    def published(self, directory, template, env, mode="0600", owner=""):
        base = pathlib.Path(directory)
        target = base / "config.json"
        result = self.render(template, env, target, mode, owner)
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(target.read_text())

    def test_string_placeholder_is_replaced(self):
        with tempfile.TemporaryDirectory() as directory:
            rendered = self.published(
                directory,
                {"expected_email": "{{PERSONAL_ACCOUNT_EMAIL}}"},
                "PERSONAL_ACCOUNT_EMAIL=owner@example.invalid\n",
            )
            self.assertEqual(rendered["expected_email"], "owner@example.invalid")

    def test_embedded_placeholder_is_replaced(self):
        with tempfile.TemporaryDirectory() as directory:
            rendered = self.published(
                directory,
                {"base_url": "https://api.example.com/accounts/{{CF_ACCOUNT_ID}}/ai/v1"},
                "CF_ACCOUNT_ID=" + SPECIMEN_ACCOUNT + "\n",
            )
            self.assertEqual(
                rendered["base_url"],
                "https://api.example.com/accounts/" + SPECIMEN_ACCOUNT + "/ai/v1",
            )

    def test_json_placeholder_injects_structure(self):
        with tempfile.TemporaryDirectory() as directory:
            rendered = self.published(
                directory,
                {"allowed_user_ids": "{{GITHUB_ALLOWED_USER_IDS:json}}"},
                "GITHUB_ALLOWED_USER_IDS=[4242]\n",
            )
            self.assertEqual(rendered["allowed_user_ids"], [4242])

    def test_json_placeholder_injects_object(self):
        with tempfile.TemporaryDirectory() as directory:
            rendered = self.published(
                directory,
                {"repositories": "{{T3_REPOSITORIES:json}}"},
                'T3_REPOSITORIES={"example/project":{"project_id":"identifier"}}\n',
            )
            self.assertEqual(
                rendered["repositories"],
                {"example/project": {"project_id": "identifier"}},
            )

    def test_quoted_value_is_unquoted(self):
        with tempfile.TemporaryDirectory() as directory:
            rendered = self.published(
                directory, {"name": "{{OPERATOR}}"}, "OPERATOR='operator account'\n")
            self.assertEqual(rendered["name"], "operator account")

    def test_missing_value_fails_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            base = pathlib.Path(directory)
            target = base / "config.json"
            result = self.render(
                {"expected_email": "{{PERSONAL_ACCOUNT_EMAIL}}"}, "OTHER=value\n", target)
            self.assertEqual(result.returncode, 1)
            self.assertIn("PERSONAL_ACCOUNT_EMAIL", result.stderr)
            self.assertFalse(target.exists())

    def test_unresolved_placeholder_fails_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            base = pathlib.Path(directory)
            target = base / "config.json"
            result = self.render(
                {"a": "{{KNOWN}}", "b": "{{OTHER}}"}, "KNOWN=value\n", target)
            self.assertEqual(result.returncode, 1)
            self.assertIn("OTHER", result.stderr)

    # --- publication boundaries -------------------------------------------

    def test_a_symbolic_link_target_is_replaced_not_followed(self):
        with tempfile.TemporaryDirectory() as directory:
            base = pathlib.Path(directory)
            victim = base / "victim.txt"
            victim.write_text("original\n")
            target = base / "config.json"
            target.symlink_to(victim)
            result = self.render({"a": "{{X}}"}, "X=value\n", target)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(victim.read_text(), "original\n")
            self.assertFalse(target.is_symlink())
            self.assertEqual(json.loads(target.read_text()), {"a": "value"})

    def test_a_pre_created_predictable_path_is_not_used(self):
        with tempfile.TemporaryDirectory() as directory:
            base = pathlib.Path(directory)
            victim = base / "victim.txt"
            victim.write_text("original\n")
            decoy = base / "config.json.new"
            decoy.symlink_to(victim)
            target = base / "config.json"
            result = self.render({"a": "{{X}}"}, "X=value\n", target)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(victim.read_text(), "original\n")
            self.assertEqual(json.loads(target.read_text()), {"a": "value"})

    def test_a_group_writable_directory_is_refused(self):
        with tempfile.TemporaryDirectory() as directory:
            base = pathlib.Path(directory)
            base.chmod(0o775)
            try:
                result = self.render({"a": "{{X}}"}, "X=value\n", base / "config.json")
                self.assertEqual(result.returncode, 1)
                self.assertIn("writable", result.stderr)
            finally:
                base.chmod(0o700)

    def test_a_world_writable_directory_is_refused(self):
        with tempfile.TemporaryDirectory() as directory:
            base = pathlib.Path(directory)
            base.chmod(0o777)
            try:
                result = self.render({"a": "{{X}}"}, "X=value\n", base / "config.json")
                self.assertEqual(result.returncode, 1)
                self.assertIn("writable", result.stderr)
            finally:
                base.chmod(0o700)

    def test_a_symbolic_link_directory_is_refused(self):
        with tempfile.TemporaryDirectory() as directory:
            base = pathlib.Path(directory)
            real = base / "real"
            real.mkdir()
            link = base / "link"
            link.symlink_to(real)
            result = self.render({"a": "{{X}}"}, "X=value\n", link / "config.json")
            self.assertEqual(result.returncode, 1)
            self.assertIn("symbolic link", result.stderr)

    def test_the_final_mode_is_applied_at_publication(self):
        with tempfile.TemporaryDirectory() as directory:
            base = pathlib.Path(directory)
            target = base / "config.json"
            result = self.render({"a": "{{X}}"}, "X=value\n", target, mode="0640")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(target.stat().st_mode & 0o777, 0o640)

    def test_no_temporary_file_is_left_behind(self):
        with tempfile.TemporaryDirectory() as directory:
            base = pathlib.Path(directory)
            self.render({"a": "{{X}}"}, "X=value\n", base / "config.json")
            self.assertEqual(sorted(p.name for p in base.iterdir()), ["config.json"])


class PrivacyOutputTest(unittest.TestCase):
    def test_the_report_never_contains_a_detected_value(self):
        with tempfile.TemporaryDirectory() as directory:
            base = pathlib.Path(directory)
            secret = "person@" + "personal.invalid"
            target = base / "sample.txt"
            target.write_text("owner = '{0}'\n".format(secret))
            findings, _ = CHECK.scan([], files=[str(target)], source="working-tree")
            self.assertTrue(findings)
            rendered = json.dumps(findings)
            self.assertNotIn(secret, rendered)
            for entry in findings:
                self.assertNotIn("value", entry)

    def test_a_proven_finding_carries_no_value(self):
        with tempfile.TemporaryDirectory() as directory:
            base = pathlib.Path(directory)
            secret = "a-private-value"
            target = base / "sample.txt"
            target.write_text("value = '{0}'\n".format(secret))
            findings, _ = CHECK.scan([secret], files=[str(target)], source="working-tree")
            self.assertTrue(findings)
            for entry in findings:
                self.assertNotIn("value", entry)
                self.assertIn("kind", entry)
                self.assertIn("file", entry)
                self.assertIn("line", entry)


class StructuredSpecificationTest(unittest.TestCase):
    def write(self, directory, body):
        path = pathlib.Path(directory) / "spec.json"
        path.write_text(body)
        return [str(path)]

    def test_a_structured_private_specification_is_detected(self):
        with tempfile.TemporaryDirectory() as directory:
            files = self.write(directory, json.dumps({
                "owner": "example",
                "repo": "private-project",
                "rev": "0123456789abcdef0123456789abcdef01234567",
                "narHash": "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
            }))
            findings, _ = CHECK.scan([], files=files, source="working-tree")
            categories = {entry["category"] for entry in findings}
            self.assertIn("private-source-specification", categories)

    def test_a_documented_placeholder_is_not_a_specification(self):
        with tempfile.TemporaryDirectory() as directory:
            files = self.write(directory, json.dumps({
                "owner": "<owner>",
                "repo": "<repository>",
                "rev": "<revision>",
                "narHash": "<content hash>",
            }))
            findings, _ = CHECK.scan([], files=files, source="working-tree")
            categories = {entry["category"] for entry in findings}
            self.assertNotIn("private-source-specification", categories)

    def test_a_partial_field_set_is_not_a_specification(self):
        with tempfile.TemporaryDirectory() as directory:
            files = self.write(directory, json.dumps({
                "owner": "example",
                "repo": "public-project",
            }))
            findings, _ = CHECK.scan([], files=files, source="working-tree")
            categories = {entry["category"] for entry in findings}
            self.assertNotIn("private-source-specification", categories)


if __name__ == "__main__":
    unittest.main()
