from __future__ import annotations

import json
import os
import platform
import re
import shutil
import subprocess
from collections.abc import Iterable
from dataclasses import asdict, dataclass
from pathlib import Path

APP_ID = "fedora-plasma-glow-kit"
SUPPORTED_FEDORA = "44"
SECTION_LABELS = {
    "core": "Core CLI and shell",
    "extras": "Optional apps and extras",
    "kde": "KDE Plasma polish",
    "gnome": "GNOME desktop polish",
    "ai": "AI CLI tools",
    "security": "Security baseline",
}
SECTION_RISKS = {
    "core": "low",
    "extras": "medium",
    "kde": "medium",
    "gnome": "medium",
    "ai": "medium",
    "security": "medium",
}
PROFILES = {
    "minimal": ("core", "security"),
    "daily": ("core", "extras", "desktop", "security"),
    "dev": ("core", "extras", "ai", "security"),
    "kde-polish": ("kde",),
    "gnome-polish": ("gnome",),
    "media": ("core", "extras", "desktop"),
    "gaming": ("core", "extras", "desktop"),
    "privacy": ("core", "security"),
    "ai": ("core", "ai"),
    "full-send": ("core", "extras", "desktop", "ai", "security"),
}
DEFAULT_SETTINGS = {
    "profile": "daily",
    "desktop": "auto",
    "tray_autostart": False,
    "safe_aliases": True,
}


@dataclass(frozen=True)
class Action:
    id: str
    label: str
    risk: str
    command: tuple[str, ...]


def xdg_dir(env_name: str, fallback: Path) -> Path:
    value = os.environ.get(env_name, "")
    return Path(value).expanduser() if value else fallback


def config_dir() -> Path:
    return xdg_dir("XDG_CONFIG_HOME", Path.home() / ".config") / APP_ID


def state_dir() -> Path:
    return xdg_dir("XDG_STATE_HOME", Path.home() / ".local/state") / APP_ID


def state_file() -> Path:
    return state_dir() / "install.state"


def legacy_state_file() -> Path:
    return (
        xdg_dir("XDG_STATE_HOME", Path.home() / ".local/state") / "fedora-starter-kit/install.state"
    )


def migrate_legacy_state() -> None:
    target = state_file()
    legacy = legacy_state_file()
    if target.exists() or not legacy.is_file():
        return
    target.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    shutil.copy2(legacy, target)
    target.chmod(0o600)


def project_root() -> Path:
    override = os.environ.get("GLOW_KIT_ROOT")
    candidates = [
        Path(override) if override else None,
        Path(__file__).resolve().parent.parent,
        Path("/usr/share/fedora-plasma-glow-kit"),
    ]
    for candidate in candidates:
        if candidate and (candidate / "manage.sh").is_file():
            return candidate
    raise RuntimeError("Fedora Glow Kit runtime files were not found")


def detect_desktop(value: str = "auto") -> str:
    if value in {"kde", "gnome"}:
        return value
    current = " ".join(
        (
            os.environ.get("XDG_CURRENT_DESKTOP", ""),
            os.environ.get("XDG_SESSION_DESKTOP", ""),
            os.environ.get("DESKTOP_SESSION", ""),
        )
    ).lower()
    if any(token in current for token in ("kde", "plasma")):
        return "kde"
    if "gnome" in current:
        return "gnome"
    return "unknown"


def resolve_sections(
    profile: str = "daily", desktop: str = "auto", section: str | None = None
) -> tuple[str, ...]:
    if section:
        if section not in SECTION_LABELS:
            raise ValueError(f"unknown section: {section}")
        return (section,)
    if profile not in PROFILES:
        raise ValueError(f"unknown profile: {profile}")
    resolved_desktop = detect_desktop(desktop)
    sections: list[str] = []
    for item in PROFILES[profile]:
        if item == "desktop":
            if resolved_desktop not in {"kde", "gnome"}:
                raise ValueError("desktop could not be detected; pass --desktop kde or gnome")
            item = resolved_desktop
        sections.append(item)
    return tuple(sections)


def build_plan(
    profile: str = "daily", desktop: str = "auto", section: str | None = None
) -> dict[str, object]:
    selected = resolve_sections(profile, desktop, section)
    actions = [
        Action(
            id=item,
            label=SECTION_LABELS[item],
            risk=SECTION_RISKS[item],
            command=("bash", "manage.sh", "--section", item),
        )
        for item in selected
    ]
    return {
        "schema_version": 1,
        "profile": profile if not section else None,
        "desktop": detect_desktop(desktop),
        "actions": [asdict(action) for action in actions],
        "requires_confirmation": True,
    }


def read_os_release(path: Path = Path("/etc/os-release")) -> dict[str, str]:
    values: dict[str, str] = {}
    try:
        for line in path.read_text(encoding="utf-8").splitlines():
            if "=" not in line or line.startswith("#"):
                continue
            key, value = line.split("=", 1)
            values[key] = value.strip().strip('"')
    except OSError:
        pass
    return values


def is_supported_release(release: dict[str, str], *, ostree_booted: bool | None = None) -> bool:
    if ostree_booted is None:
        ostree_booted = Path("/run/ostree-booted").exists()
    immutable_variants = {"silverblue", "kinoite", "sericea", "onyx"}
    return (
        release.get("ID") == "fedora"
        and release.get("VERSION_ID") == SUPPORTED_FEDORA
        and release.get("VARIANT_ID", "").lower() not in immutable_variants
        and not ostree_booted
    )


def require_supported_release() -> None:
    release = read_os_release()
    if is_supported_release(release):
        return
    detected = f"{release.get('ID', 'unknown')} {release.get('VERSION_ID', 'unknown')}"
    raise RuntimeError(
        "Fedora Glow Kit supports Fedora 44 KDE Plasma and GNOME Workstation only; "
        f"detected {detected}."
    )


def read_state() -> dict[str, list[str]]:
    migrate_legacy_state()
    result: dict[str, list[str]] = {}
    try:
        lines = state_file().read_text(encoding="utf-8").splitlines()
    except OSError:
        return result
    for line in lines:
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        if re.fullmatch(r"[a-z][a-z0-9_-]*", key):
            result.setdefault(key, []).append(value)
    return result


def status_payload(desktop: str = "auto") -> dict[str, object]:
    release = read_os_release()
    state = read_state()
    managed = state.get("managed", [])
    active_transactions: dict[tuple[str, str], None] = {}
    for item in state.get("transaction", []):
        parts = item.split("|", 2)
        if len(parts) != 3:
            continue
        transaction_id, section, transaction_status = parts
        key = (transaction_id, section)
        if transaction_status == "started":
            active_transactions[key] = None
        elif transaction_status == "complete":
            active_transactions.pop(key, None)
            active_transactions = {
                active_key: None
                for active_key in active_transactions
                if active_key[1] != section
            }
        elif transaction_status in {"recovered", "reverted"}:
            if section == "all":
                active_transactions.clear()
            else:
                active_transactions = {
                    active_key: None
                    for active_key in active_transactions
                    if active_key[1] != section
                }
    return {
        "schema_version": 1,
        "supported": is_supported_release(release),
        "os": release.get("ID", "unknown"),
        "os_version": release.get("VERSION_ID", "unknown"),
        "desktop": detect_desktop(desktop),
        "managed_items": len(managed)
        or sum(len(state.get(key, [])) for key in ("dnf", "flatpak", "npm", "copr", "service")),
        "incomplete_transactions": len(active_transactions),
        "telemetry": False,
    }


def load_settings() -> dict[str, object]:
    settings = dict(DEFAULT_SETTINGS)
    path = config_dir() / "settings.json"
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return settings
    if raw.get("profile") in PROFILES:
        settings["profile"] = raw["profile"]
    if raw.get("desktop") in {"auto", "kde", "gnome"}:
        settings["desktop"] = raw["desktop"]
    for key in ("tray_autostart", "safe_aliases"):
        if isinstance(raw.get(key), bool):
            settings[key] = raw[key]
    return settings


def save_settings(values: dict[str, object]) -> dict[str, object]:
    merged = dict(DEFAULT_SETTINGS)
    merged.update(values)
    if merged["profile"] not in PROFILES:
        raise ValueError("invalid profile")
    if merged["desktop"] not in {"auto", "kde", "gnome"}:
        raise ValueError("invalid desktop")
    path = config_dir() / "settings.json"
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    path.write_text(json.dumps(merged, indent=2) + "\n", encoding="utf-8")
    path.chmod(0o600)
    return merged


def update_commands() -> list[list[str]]:
    commands = [["sudo", "dnf", "upgrade", "--refresh"]]
    if shutil.which("flatpak"):
        commands.append(["flatpak", "update"])
    commands.append(["fwupdmgr", "get-updates"])
    return commands


def diagnostics_payload(desktop: str = "auto") -> dict[str, object]:
    status = status_payload(desktop)
    return {
        "schema_version": 1,
        "product_version": "1.0.0",
        "platform": platform.system(),
        "os": status["os"],
        "os_version": status["os_version"],
        "desktop": status["desktop"],
        "supported": status["supported"],
        "managed_items": status["managed_items"],
        "incomplete_transactions": status["incomplete_transactions"],
        "tools": {
            name: shutil.which(name) is not None
            for name in ("dnf", "flatpak", "fwupdmgr", "systemctl", "gsettings")
        },
        "privacy": "local-only; no personal or device identifiers collected",
    }


def diagnostics_text(desktop: str = "auto") -> str:
    payload = diagnostics_payload(desktop)
    lines = [
        "Fedora Glow Kit diagnostics",
        f"Product version: {payload['product_version']}",
        f"Operating system: {payload['os']} {payload['os_version']}",
        f"Desktop: {payload['desktop']}",
        f"Supported target: {'yes' if payload['supported'] else 'no'}",
        f"Managed items: {payload['managed_items']}",
        f"Incomplete transactions: {payload['incomplete_transactions']}",
        "Available tools:",
    ]
    lines.extend(
        f"  {name}: {'yes' if available else 'no'}" for name, available in payload["tools"].items()
    )
    lines.append("Privacy: local-only; no personal or device identifiers collected")
    return "\n".join(lines) + "\n"


def run_runtime(args: Iterable[str]) -> int:
    command = [str(item) for item in args]
    return subprocess.run(command, cwd=project_root(), check=False).returncode


def terminal_command(args: list[str]) -> list[str]:
    candidates = [
        ("konsole", ["konsole", "-e"]),
        ("kgx", ["kgx", "--"]),
        ("gnome-terminal", ["gnome-terminal", "--"]),
        ("xterm", ["xterm", "-e"]),
    ]
    for executable, prefix in candidates:
        if shutil.which(executable):
            return [*prefix, *args]
    raise RuntimeError("No supported terminal emulator was found")


def launch_terminal(args: list[str]) -> None:
    subprocess.Popen(terminal_command(args), cwd=project_root(), start_new_session=True)
