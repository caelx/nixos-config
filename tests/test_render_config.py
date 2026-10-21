import json
import pathlib
import subprocess
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
RENDER = ROOT / "modules/self-hosted/render-config.py"


class RenderConfigTest(unittest.TestCase):
    def run_render(self, template, env, expected):
        with tempfile.TemporaryDirectory() as directory:
            base = pathlib.Path(directory)
            template_path = base / "template.json"
            env_path = base / "secrets.env"
            output_path = base / "config.json"
            template_path.write_text(json.dumps(template))
            env_path.write_text(env)
            result = subprocess.run(
                [sys.executable, str(RENDER), str(template_path), str(env_path), str(output_path)],
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            return json.loads(output_path.read_text())

    def test_string_placeholder_is_replaced(self):
        rendered = self.run_render(
            {"expected_email": "{{PERSONAL_ACCOUNT_EMAIL}}"},
            "PERSONAL_ACCOUNT_EMAIL=owner@example.invalid\n",
            None,
        )
        self.assertEqual(rendered["expected_email"], "owner@example.invalid")

    def test_embedded_placeholder_is_replaced(self):
        rendered = self.run_render(
            {"base_url": "https://api.example.com/accounts/{{CF_ACCOUNT_ID}}/ai/v1"},
            "CF_ACCOUNT_ID=test-account-identifier\n",
            None,
        )
        self.assertEqual(
            rendered["base_url"],
            "https://api.example.com/accounts/test-account-identifier/ai/v1",
        )

    def test_json_placeholder_injects_structure(self):
        rendered = self.run_render(
            {"allowed_user_ids": "{{GITHUB_ALLOWED_USER_IDS:json}}"},
            "GITHUB_ALLOWED_USER_IDS=[4242]\n",
            None,
        )
        self.assertEqual(rendered["allowed_user_ids"], [4242])

    def test_json_placeholder_injects_object(self):
        rendered = self.run_render(
            {"repositories": "{{T3_REPOSITORIES:json}}"},
            'T3_REPOSITORIES={"example/project":{"project_id":"project-identifier"}}\n',
            None,
        )
        self.assertEqual(
            rendered["repositories"],
            {"example/project": {"project_id": "project-identifier"}},
        )

    def test_quoted_value_is_unquoted(self):
        rendered = self.run_render(
            {"name": "{{OPERATOR}}"},
            "OPERATOR='operator account'\n",
            None,
        )
        self.assertEqual(rendered["name"], "operator account")

    def test_missing_value_fails_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            base = pathlib.Path(directory)
            template_path = base / "template.json"
            env_path = base / "secrets.env"
            template_path.write_text(json.dumps({"expected_email": "{{PERSONAL_ACCOUNT_EMAIL}}"}))
            env_path.write_text("OTHER=value\n")
            result = subprocess.run(
                [sys.executable, str(RENDER), str(template_path), str(env_path), str(base / "out.json")],
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 1)
            self.assertIn("PERSONAL_ACCOUNT_EMAIL", result.stderr)
            self.assertFalse((base / "out.json").exists())

    def test_unresolved_placeholder_fails_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            base = pathlib.Path(directory)
            template_path = base / "template.json"
            env_path = base / "secrets.env"
            template_path.write_text(json.dumps({"a": "{{KNOWN}}", "b": "{{OTHER}}"}))
            env_path.write_text("KNOWN=value\n")
            result = subprocess.run(
                [sys.executable, str(RENDER), str(template_path), str(env_path), str(base / "out.json")],
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 1)
            self.assertIn("OTHER", result.stderr)


if __name__ == "__main__":
    unittest.main()
