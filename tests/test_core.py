from __future__ import annotations

import io
import json
import os
import subprocess
import tempfile
import unittest
from contextlib import redirect_stderr
from pathlib import Path
from unittest.mock import patch

from glow_kit import cli, core


class CoreTests(unittest.TestCase):
    def test_daily_profile_resolves_for_both_desktops(self) -> None:
        self.assertEqual(
            core.resolve_sections("daily", "kde"),
            ("core", "extras", "kde", "security"),
        )
        self.assertEqual(
            core.resolve_sections("daily", "gnome"),
            ("core", "extras", "gnome", "security"),
        )

    def test_unknown_desktop_requires_explicit_choice(self) -> None:
        with patch.dict(os.environ, {}, clear=True):
            with self.assertRaisesRegex(ValueError, "desktop could not be detected"):
                core.resolve_sections("daily", "auto")

    def test_supported_release_rejects_wrong_or_immutable_targets(self) -> None:
        workstation = {
            "ID": "fedora",
            "VERSION_ID": "44",
            "VARIANT_ID": "workstation",
        }
        self.assertTrue(core.is_supported_release(workstation, ostree_booted=False))
        self.assertFalse(
            core.is_supported_release({**workstation, "VERSION_ID": "43"}, ostree_booted=False)
        )
        self.assertFalse(
            core.is_supported_release(
                {**workstation, "VARIANT_ID": "silverblue"}, ostree_booted=False
            )
        )
        self.assertFalse(core.is_supported_release(workstation, ostree_booted=True))

    def test_apply_refuses_unsupported_target_before_runtime(self) -> None:
        with (
            patch.object(
                cli,
                "require_supported_release",
                side_effect=RuntimeError("unsupported target"),
            ),
            patch.object(cli, "run_runtime") as runtime,
            redirect_stderr(io.StringIO()),
        ):
            code = cli.main(["apply", "--profile", "minimal", "--desktop", "kde", "--yes"])
        self.assertEqual(code, 2)
        runtime.assert_not_called()

    def test_settings_are_private_and_validated(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            env = {"XDG_CONFIG_HOME": temp, "HOME": temp}
            with patch.dict(os.environ, env, clear=False):
                saved = core.save_settings(
                    {
                        "profile": "gnome-polish",
                        "desktop": "gnome",
                        "tray_autostart": True,
                        "safe_aliases": True,
                    }
                )
                path = Path(temp) / core.APP_ID / "settings.json"
                self.assertEqual(path.stat().st_mode & 0o777, 0o600)
                self.assertEqual(saved, core.load_settings())
                with self.assertRaisesRegex(ValueError, "invalid profile"):
                    core.save_settings({"profile": "../../unsafe"})

    def test_legacy_state_migrates_without_identifiers(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            state_home = Path(temp)
            legacy = state_home / "fedora-starter-kit/install.state"
            legacy.parent.mkdir(parents=True)
            legacy.write_text("dnf=example\n", encoding="utf-8")
            with patch.dict(
                os.environ,
                {"XDG_STATE_HOME": temp, "HOME": temp},
                clear=False,
            ):
                self.assertEqual(core.read_state()["dnf"], ["example"])
                self.assertEqual(core.state_file().stat().st_mode & 0o777, 0o600)

    def test_diagnostics_schema_excludes_identifiers(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            with patch.dict(
                os.environ,
                {
                    "HOME": temp,
                    "XDG_STATE_HOME": temp,
                    "USER": "private-user",
                    "HOSTNAME": "private-host",
                },
                clear=False,
            ):
                report = json.dumps(core.diagnostics_payload("kde")).lower()
                for forbidden in (
                    "private-user",
                    "private-host",
                    "serial",
                    "mac_address",
                    "ip_address",
                    str(Path(temp)).lower(),
                ):
                    self.assertNotIn(forbidden, report)
                self.assertIn("local-only", report)

    def test_failed_transaction_is_resolved_by_rerun_or_revert(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            state_path = Path(temp) / core.APP_ID / "install.state"
            state_path.parent.mkdir(parents=True)
            with patch.dict(
                os.environ,
                {"HOME": temp, "XDG_STATE_HOME": temp},
                clear=False,
            ):
                state_path.write_text(
                    "transaction=first|core|started\ntransaction=first|core|failed:1\n",
                    encoding="utf-8",
                )
                self.assertEqual(core.status_payload("kde")["incomplete_transactions"], 1)

                with state_path.open("a", encoding="utf-8") as state:
                    state.write("transaction=second|core|started\n")
                    state.write("transaction=second|core|complete\n")
                self.assertEqual(core.status_payload("kde")["incomplete_transactions"], 0)

                with state_path.open("a", encoding="utf-8") as state:
                    state.write("transaction=third|gnome|started\n")
                    state.write("transaction=resolution|gnome|reverted\n")
                self.assertEqual(core.status_payload("kde")["incomplete_transactions"], 0)

    def test_cli_plan_is_machine_readable(self) -> None:
        result = subprocess.run(
            [
                "bash",
                "bin/glow-kit",
                "plan",
                "--profile",
                "daily",
                "--desktop",
                "gnome",
                "--json",
            ],
            check=True,
            capture_output=True,
            text=True,
        )
        payload = json.loads(result.stdout)
        self.assertEqual(
            [item["id"] for item in payload["actions"]], ["core", "extras", "gnome", "security"]
        )
        self.assertTrue(payload["requires_confirmation"])


if __name__ == "__main__":
    unittest.main()
