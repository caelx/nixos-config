"""Catch catalog interference, lost native login state, and mutable CLI installs."""

import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "packages/t3code/command-code"


def load(name):
    spec = importlib.util.spec_from_file_location(f"command_code_{name}", SOURCE / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


acp = load("acp")
setup = load("setup")


class NativeLauncherTest(unittest.TestCase):
    def test_native_acp_executes_without_protocol_interposition(self):
        # Native ACP owns model catalogs, order/defaults, configuration, slash
        # commands and session load. Exec preserves its stdio directly.
        class ExecCalled(Exception):
            pass
        with patch.object(acp.sys, "argv", ["cmd", "acp"]), \
             patch.object(acp.os, "execvpe", side_effect=ExecCalled) as execute:
            with self.assertRaises(ExecCalled):
                acp.main()
        command, args, environment = execute.call_args.args
        self.assertEqual(command, "node")
        self.assertEqual(args, ["node", str(SOURCE / "node_modules/command-code/dist/index.mjs"), "acp"])
        self.assertEqual(environment["CMD_ZDR"], "1")
        self.assertNotIn("CMD_DISABLE_REMOTE_MODEL_CATALOG", environment)

    def test_zdr_cannot_be_overridden_and_native_home_is_preserved(self):
        env = acp.provider_environment({"CMD_ZDR": "0", "PATH": "unit-path", "HOME": "unit-home",
                                        "COMMAND_CODE_UNUSED_OVERRIDE": "discard"})
        self.assertEqual(env["CMD_ZDR"], "1")
        self.assertEqual(env["HOME"], "unit-home")
        self.assertEqual(env["COMMANDCODE_SKIP_UPDATES"], "1")
        self.assertNotIn("CMD_DISABLE_REMOTE_MODEL_CATALOG", env)
        self.assertNotIn("COMMAND_CODE_UNUSED_OVERRIDE", env)

    def test_login_executes_native_cli_without_reading_auth_state(self):
        class ExecCalled(Exception):
            pass
        with patch.object(acp.sys, "argv", ["cmd", "login"]), \
             patch.object(acp.os, "execvpe", side_effect=ExecCalled) as execute:
            with self.assertRaises(ExecCalled):
                acp.main()
        args = execute.call_args.args
        self.assertEqual(args[0], "node")
        self.assertEqual(args[1][-1], "login")
        self.assertEqual(args[2]["CMD_ZDR"], "1")


class InstallTest(unittest.TestCase):
    def test_configure_failure_after_payload_install_preserves_previous_launcher(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            previous = home / ".local/share/t3code-tools/command-code/previous/acp.py"
            previous.parent.mkdir(parents=True)
            previous.write_text("previous ready CLI")
            cmd = home / ".local/bin/cmd"
            cmd.parent.mkdir(parents=True)
            cmd.symlink_to(previous)
            setup.configure(home, SOURCE)
            def run(command, **kwargs):
                if command[0] == "node":
                    return subprocess.CompletedProcess(command, 0, "v24.0.0\n")
                package = Path(command[command.index("--prefix") + 1]) / "node_modules/command-code/package.json"
                package.parent.mkdir(parents=True)
                package.write_text(json.dumps({"version": setup.VERSION}))
                return subprocess.CompletedProcess(command, 0)
            with patch.object(setup.subprocess, "run", side_effect=run), \
                 patch.object(setup, "configure", side_effect=ValueError("synthetic configure failure")), \
                 patch.object(setup.sys, "stderr"):
                self.assertEqual(setup.startup(home), 1)
            self.assertEqual(cmd.resolve(), previous)
            settings = json.loads((home / ".t3/userdata/settings.json").read_text())
            self.assertFalse(settings["providerInstances"]["commandCode"]["enabled"])

    def test_failed_optional_install_disables_provider_without_losing_ready_cli(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            ready = home / ".local/share/t3code-tools/command-code/previous/acp.py"
            ready.parent.mkdir(parents=True)
            ready.write_text("previous ready CLI")
            cmd = home / ".local/bin/cmd"
            cmd.parent.mkdir(parents=True)
            cmd.symlink_to(ready)
            setup.configure(home, SOURCE)
            with patch.object(setup, "install", side_effect=RuntimeError("synthetic install error")), \
                 patch.object(setup.sys, "stderr") as stderr:
                self.assertEqual(setup.startup(home), 1)
            self.assertEqual(cmd.resolve(), ready)
            self.assertEqual(ready.read_text(), "previous ready CLI")
            settings = json.loads((home / ".t3/userdata/settings.json").read_text())
            self.assertFalse(settings["providerInstances"]["commandCode"]["enabled"])
            self.assertEqual(stderr.write.call_count, 2)  # One line plus its newline.

    def test_committed_lock_rejects_wrong_integrity_and_mutable_version(self):
        setup.validate_lock(SOURCE)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for filename in ("package.json", "package-lock.json"):
                (root / filename).write_bytes((SOURCE / filename).read_bytes())
            data = json.loads((root / "package-lock.json").read_text())
            data["packages"]["node_modules/command-code"]["integrity"] = "sha512-wrong"
            (root / "package-lock.json").write_text(json.dumps(data))
            with self.assertRaisesRegex(ValueError, "integrity"):
                setup.validate_lock(root)
            (root / "package-lock.json").write_bytes((SOURCE / "package-lock.json").read_bytes())
            (root / "package.json").write_text('{"dependencies":{"command-code":"latest"}}')
            with self.assertRaisesRegex(ValueError, "version"):
                setup.validate_lock(root)

    def test_settings_merge_keeps_other_instances_and_has_only_zdr_environment(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            path = home / ".t3/userdata/settings.json"
            original = {"otherSetting": True, "providerInstances": {
                "unitProvider": {"driver": "unit"}}}
            setup.atomic_json(path, original)
            setup.configure(home, SOURCE)
            data = json.loads(path.read_text())
            self.assertEqual(data["providerInstances"]["unitProvider"], original["providerInstances"]["unitProvider"])
            self.assertTrue(data["otherSetting"])
            provider = data["providerInstances"]["commandCode"]
            self.assertEqual(provider["config"]["commandArgs"], ["acp"])
            self.assertEqual(provider["environment"], [{"name": "CMD_ZDR", "value": "1"}])
            before = path.stat().st_mtime_ns
            setup.configure(home, SOURCE)
            self.assertEqual(path.stat().st_mtime_ns, before)

    def test_install_is_pinned_scriptless_and_retry_safe(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            auth = home / ".commandcode/auth.json"
            auth.parent.mkdir()
            auth.write_text('{"synthetic": true}')
            auth_before = auth.stat().st_mtime_ns
            def run(command, **kwargs):
                if command[0] == "node":
                    return subprocess.CompletedProcess(command, 0, "v24.0.0\n")
                self.assertEqual(command[:2], ["npm", "ci"])
                self.assertIn("--ignore-scripts", command)
                stage = Path(command[command.index("--prefix") + 1])
                package = stage / "node_modules/command-code/package.json"
                package.parent.mkdir(parents=True)
                package.write_text(json.dumps({"version": setup.VERSION}))
                return subprocess.CompletedProcess(command, 0)
            with patch.object(setup.subprocess, "run", side_effect=run) as runner:
                setup.install(home)
                setup.install(home)
            self.assertEqual(sum(call.args[0][0] == "npm" for call in runner.call_args_list), 1)
            self.assertTrue((home / ".local/bin/cmd").is_file())
            self.assertEqual(auth.read_text(), '{"synthetic": true}')
            self.assertEqual(auth.stat().st_mtime_ns, auth_before)

    def test_image_installs_provider_before_t3_reads_settings(self):
        image = (ROOT / "packages/t3code/image.nix").read_text()
        self.assertIn("cp -r ${./command-code}/.", image)
        directive = "ExecStartPre=-${managedBin}/python3 /usr/share/t3code-command-code/setup.py"
        self.assertLess(image.index(directive),
                        image.index("ExecStart=${managedBin}/t3code-server-run"))

    def test_auth_location_is_under_the_writable_persisted_home_not_the_image(self):
        module = (ROOT / "modules/self-hosted/t3code.nix").read_text()
        image = (ROOT / "packages/t3code/image.nix").read_text()
        self.assertIn('"${t3codeHome}:/home/t3code:rw"', module)
        self.assertIn("Environment=HOME=/home/t3code", image)
        self.assertNotIn(".commandcode/auth.json", image)
        self.assertNotIn("auth.json", (SOURCE / "setup.py").read_text())


if __name__ == "__main__":
    unittest.main()
