import importlib.util
import json
import os
import pathlib
import shutil
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("private_inputs", ROOT / "scripts/private-inputs.py")
PRIVATE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PRIVATE)

NIX = shutil.which("nix")

# The specimens are assembled rather than written out, so this file carries no
# literal that the published tree check would report.
SPECIMEN_REPOSITORY = "example/" + "private-project"
SPECIMEN_REVISION = "0" * 40


def nix(*arguments):
    return subprocess.run(
        ["nix", *arguments], capture_output=True, text=True, check=False
    )


@unittest.skipIf(NIX is None, "nix is not available")
class ImporterDurabilityTest(unittest.TestCase):
    """The importer must leave a resolution that survives its own exit.

    The defect this covers was an importer that pointed the lock at a working
    directory it then deleted, so the evaluation that followed the importer had
    nothing to resolve.
    """

    def make_source(self, directory):
        source = pathlib.Path(directory) / "source"
        (source / "lib").mkdir(parents=True)
        (source / "flake.nix").write_text(
            '{\n  outputs = { self }: { marker = "synthetic-source"; };\n}\n')
        (source / "lib" / "value.nix").write_text('"synthetic"\n')
        return source

    def test_the_store_copy_survives_the_working_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            source = self.make_source(directory)
            digest = nix("hash", "path", str(source)).stdout.strip()
            entry = {"narHash": digest, "lastModified": 0}
            store_path = PRIVATE.import_into_store(source, entry)
            self.assertTrue(store_path.startswith("/nix/store/"))
            self.assertTrue(pathlib.Path(store_path).is_dir())
            # The working directory is gone; the store copy is not.
            shutil.rmtree(directory)
            self.assertTrue(pathlib.Path(store_path).is_dir())
            listed = nix("path-info", store_path).stdout.strip()
            self.assertIn(store_path, listed)

    def test_an_evaluation_resolves_after_the_importer_exits(self):
        with tempfile.TemporaryDirectory() as directory:
            base = pathlib.Path(directory)
            source = self.make_source(base / "work")
            digest = nix("hash", "path", str(source)).stdout.strip()
            entry = {"narHash": digest, "lastModified": 0}
            store_path = PRIVATE.import_into_store(source, entry)

            consumer = base / "consumer"
            consumer.mkdir()
            (consumer / "flake.nix").write_text(
                (
                    '{\n'
                    '  inputs.src.url = "path:@STORE@";\n'
                    '  outputs = { self, src }: { marker = src.marker; };\n'
                    '}\n'
                ).replace("@STORE@", store_path)
            )
            subprocess.run(["git", "init", "-q", str(consumer)], check=True)
            subprocess.run(["git", "-C", str(consumer), "add", "-A"], check=True)
            subprocess.run(
                ["git", "-C", str(consumer), "-c", "user.name=t", "-c", "user.email=t@localhost",
                 "commit", "-qm", "consumer"],
                check=True,
            )
            # The working directory of the importer is removed before the
            # evaluation, exactly as the importer does.
            shutil.rmtree(base / "work")
            result = nix("eval", "--no-write-lock-file", "--raw", str(consumer) + "#marker")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(), "synthetic-source")

    def test_a_content_hash_mismatch_is_refused(self):
        with tempfile.TemporaryDirectory() as directory:
            source = self.make_source(directory)
            entry = {"narHash": "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
                     "lastModified": 0}
            with self.assertRaises(PRIVATE.StepError):
                PRIVATE.import_into_store(source, entry)


class PlaceholderInvariantTest(unittest.TestCase):
    """The published tree must never name a private source."""

    def build_tree(self, directory, flake_nix):
        base = pathlib.Path(directory)
        (base / "secrets").mkdir(parents=True, exist_ok=True)
        (base / "flake.nix").write_text(flake_nix)
        (base / "flake.lock").write_text(json.dumps({
            "nodes": {
                "ghostship-private-agent": {
                    "locked": dict(PRIVATE.LOCKED_PLACEHOLDER),
                    "original": dict(PRIVATE.ORIGINAL_PLACEHOLDER),
                },
                "root": {"inputs": {"ghostship-private-agent": "ghostship-private-agent"}},
            },
            "root": "root",
            "version": 7,
        }, indent=2) + "\n")
        subprocess.run(["git", "init", "-q", str(base)], check=True)
        subprocess.run(["git", "-C", str(base), "add", "-A"], check=True)
        subprocess.run(
            ["git", "-C", str(base), "-c", "user.name=t", "-c", "user.email=t@localhost",
             "commit", "-qm", "tree"],
            check=True,
        )
        return base

    def test_a_placeholder_tree_is_accepted(self):
        with tempfile.TemporaryDirectory() as directory:
            base = self.build_tree(
                directory,
                '{\n  inputs.ghostship-private-agent.url = "path:./private-agent-source";\n}\n',
            )
            previous = os.getcwd()
            os.chdir(base)
            try:
                PRIVATE.require_committed_placeholder()
            finally:
                os.chdir(previous)

    def test_a_committed_private_source_is_refused(self):
        with tempfile.TemporaryDirectory() as directory:
            base = self.build_tree(
                directory,
                '{\n  inputs.ghostship-private-agent.url = '
                '"github:' + SPECIMEN_REPOSITORY + "/" + SPECIMEN_REVISION + '";\n}\n',
            )
            previous = os.getcwd()
            os.chdir(base)
            try:
                with self.assertRaises(PRIVATE.StepError):
                    PRIVATE.require_committed_placeholder()
            finally:
                os.chdir(previous)

    def test_a_committed_lock_without_the_placeholder_is_refused(self):
        with tempfile.TemporaryDirectory() as directory:
            base = self.build_tree(
                directory,
                '{\n  inputs.ghostship-private-agent.url = "path:./private-agent-source";\n}\n',
            )
            lock = json.loads((base / "flake.lock").read_text())
            lock["nodes"]["ghostship-private-agent"]["locked"] = {
                "lastModified": 1,
                "narHash": "sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=",
                "owner": "example",
                "repo": SPECIMEN_REPOSITORY.split("/")[1],
                "rev": SPECIMEN_REVISION,
                "type": "github",
            }
            (base / "flake.lock").write_text(json.dumps(lock, indent=2) + "\n")
            subprocess.run(["git", "-C", str(base), "add", "-A"], check=True)
            subprocess.run(
                ["git", "-C", str(base), "-c", "user.name=t", "-c", "user.email=t@localhost",
                 "commit", "-qm", "lock"],
                check=True,
            )
            previous = os.getcwd()
            os.chdir(base)
            try:
                with self.assertRaises(PRIVATE.StepError):
                    PRIVATE.require_committed_placeholder()
            finally:
                os.chdir(previous)


if __name__ == "__main__":
    unittest.main()
