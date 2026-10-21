import importlib.util
import pathlib
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("check_privacy", ROOT / "scripts/check-privacy.py")
CHECK = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECK)


class PrivacyCheckTest(unittest.TestCase):
    def scan(self, body, patterns=()):
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "sample.txt"
            path.write_text(body)
            return CHECK.scan(list(patterns), files=[str(path)], source="working-tree")

    def test_personal_email_is_reported(self):
        findings = self.scan("owner = 'person@personal.invalid'\n")
        categories = {entry[2] for entry in findings}
        self.assertIn("email", categories)

    def test_system_account_email_is_allowed(self):
        findings = self.scan("account = 'user@3000.service'\n")
        self.assertEqual([entry for entry in findings if entry[2] == "email"], [])

    def test_private_repository_path_is_reported(self):
        findings = self.scan("url = 'github:owner/private-project'\n")
        categories = {entry[2] for entry in findings}
        self.assertIn("repository-path", categories)

    def test_api_path_form_is_not_a_repository_path(self):
        findings = self.scan("url = 'https://api.github.com/repos/owner/project/releases'\n")
        self.assertEqual([entry for entry in findings if entry[2] == "repository-path"], [])

    def test_documented_placeholder_is_ignored(self):
        findings = self.scan("path = 'C:\\\\Users\\\\<windows-user>\\\\Downloads'\n")
        self.assertEqual([entry for entry in findings if entry[2] == "windows-account"], [])

    def test_account_identifier_is_reported(self):
        findings = self.scan("id = '0123456789abcdef0123456789abcdef'\n")
        categories = {entry[2] for entry in findings}
        self.assertIn("account-identifier", categories)

    def test_exact_private_value_is_reported(self):
        findings = self.scan("value = 'a-private-value'\n", patterns=["a-private-value"])
        categories = {entry[2] for entry in findings}
        self.assertIn("exact-private-value", categories)
        for entry in findings:
            if entry[2] == "exact-private-value":
                self.assertEqual(entry[3], "<redacted>")

    def test_allowlist_has_no_empty_entries(self):
        allowed, suffixes, reasons = CHECK.load_allowlist()
        self.assertTrue(allowed)
        self.assertTrue(suffixes)
        for value in allowed:
            self.assertNotIn(" ", value)
        for value in reasons:
            self.assertTrue(value.strip())


if __name__ == "__main__":
    unittest.main()
