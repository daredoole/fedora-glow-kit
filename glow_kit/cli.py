from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

from . import __version__
from .core import (
    PROFILES,
    build_plan,
    diagnostics_payload,
    diagnostics_text,
    project_root,
    require_supported_release,
    run_runtime,
    status_payload,
    update_commands,
)


def output(value: object, as_json: bool) -> None:
    if as_json:
        print(json.dumps(value, indent=2))
    elif isinstance(value, str):
        print(value, end="" if value.endswith("\n") else "\n")
    else:
        print(value)


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(prog="glow-kit", description="Safe Fedora setup manager")
    root.add_argument("--version", action="version", version=__version__)
    sub = root.add_subparsers(dest="command", required=True)

    status = sub.add_parser("status", help="Show managed state without device identifiers")
    status.add_argument("--desktop", choices=("auto", "kde", "gnome"), default="auto")
    status.add_argument("--json", action="store_true")

    plan = sub.add_parser("plan", help="Preview an installation plan")
    add_selection_arguments(plan)
    plan.add_argument("--json", action="store_true")

    apply = sub.add_parser("apply", help="Run a confirmed installation flow")
    add_selection_arguments(apply)
    apply.add_argument("--yes", action="store_true", help="Confirm all installer prompts")

    revert = sub.add_parser("revert", help="Revert kit-managed changes")
    revert.add_argument(
        "section",
        nargs="?",
        default="all",
        choices=("core", "extras", "kde", "gnome", "ai", "security", "all"),
    )
    revert.add_argument("--yes", action="store_true")

    update = sub.add_parser("update", help="Preview safe system update commands")
    update.add_argument("--apply", action="store_true", help="Run the displayed commands")
    update.add_argument("--yes", action="store_true", help="Skip the final confirmation")
    update.add_argument("--json", action="store_true")

    diagnostics = sub.add_parser("diagnostics", help="Create a local, identifier-free report")
    diagnostics.add_argument("--desktop", choices=("auto", "kde", "gnome"), default="auto")
    diagnostics.add_argument("--json", action="store_true")
    diagnostics.add_argument("--export", type=Path)
    diagnostics.add_argument("--confirm-export", action="store_true")

    sub.add_parser("audit", help="Run the repository release-readiness audit")
    return root


def add_selection_arguments(command: argparse.ArgumentParser) -> None:
    command.add_argument("--profile", choices=tuple(PROFILES), default="daily")
    command.add_argument(
        "--section",
        choices=("core", "extras", "kde", "gnome", "ai", "security"),
    )
    command.add_argument("--desktop", choices=("auto", "kde", "gnome"), default="auto")


def render_plan(plan: dict[str, object]) -> str:
    lines = [
        f"Profile: {plan.get('profile') or 'custom'}",
        f"Desktop: {plan['desktop']}",
        "",
    ]
    for action in plan["actions"]:
        lines.append(f"• {action['label']}  [{action['risk']} risk]")
    lines.extend(("", "Nothing changes until you run glow-kit apply."))
    return "\n".join(lines) + "\n"


def confirm(prompt: str) -> bool:
    if not sys.stdin.isatty():
        return False
    return input(f"{prompt} [y/N] ").strip().lower() in {"y", "yes"}


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    try:
        if args.command == "status":
            payload = status_payload(args.desktop)
            output(payload if args.json else status_text(payload), args.json)
            return 0
        if args.command == "plan":
            payload = build_plan(args.profile, args.desktop, args.section)
            output(payload if args.json else render_plan(payload), args.json)
            return 0
        if args.command == "apply":
            require_supported_release()
            build_plan(args.profile, args.desktop, args.section)
            command = ["bash", str(project_root() / "manage.sh"), "--desktop", args.desktop]
            command.extend(
                ["--section", args.section] if args.section else ["--profile", args.profile]
            )
            if args.yes:
                command.append("--yes")
            return run_runtime(command)
        if args.command == "revert":
            command = ["bash", str(project_root() / "revert.sh"), args.section]
            env = None
            if args.yes:
                import os

                env = {**os.environ, "FEDORA_PLASMA_GLOW_ASSUME": "yes"}
            return subprocess.run(command, cwd=project_root(), env=env, check=False).returncode
        if args.command == "update":
            commands = update_commands()
            payload = {"schema_version": 1, "commands": commands, "automatic": False}
            if args.json:
                output(payload, True)
                return 0
            print("Update preview:")
            for command in commands:
                print("  " + " ".join(command))
            if not args.apply:
                print("\nNothing changed. Run glow-kit update --apply to continue.")
                return 0
            if not args.yes and not confirm("Run these update commands?"):
                print("Update cancelled.")
                return 1
            for command in commands:
                if command[0] == "fwupdmgr" and not shutil_which(command[0]):
                    continue
                code = subprocess.run(command, check=False).returncode
                if code not in (0, 100):
                    return code
            return 0
        if args.command == "diagnostics":
            value = (
                diagnostics_payload(args.desktop) if args.json else diagnostics_text(args.desktop)
            )
            if args.export:
                if not args.confirm_export:
                    print(
                        "Export refused: review the report, then add --confirm-export.",
                        file=sys.stderr,
                    )
                    return 2
                text = json.dumps(value, indent=2) + "\n" if args.json else str(value)
                args.export.write_text(text, encoding="utf-8")
                args.export.chmod(0o600)
            output(value, args.json)
            return 0
        if args.command == "audit":
            return run_runtime(["bash", str(project_root() / "scripts/audit-public.sh")])
    except (OSError, RuntimeError, ValueError) as error:
        print(f"glow-kit: {error}", file=sys.stderr)
        return 2
    return 2


def shutil_which(command: str) -> str | None:
    import shutil

    return shutil.which(command)


def status_text(payload: dict[str, object]) -> str:
    return (
        f"Fedora target: {payload['os']} {payload['os_version']}\n"
        f"Desktop: {payload['desktop']}\n"
        f"Supported: {'yes' if payload['supported'] else 'no'}\n"
        f"Managed items: {payload['managed_items']}\n"
        f"Incomplete transactions: {payload['incomplete_transactions']}\n"
        "Telemetry: disabled\n"
    )


if __name__ == "__main__":
    raise SystemExit(main())
