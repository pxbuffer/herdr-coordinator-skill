#!/usr/bin/env python3
"""Check that the Matt Pocock skills the rules name are installed and enabled.

    check-skills.py              → every skill the templates name
    check-skills.py <name>...    → just these, e.g. the one brief.sh is about to send

The required list is read from the templates, not typed here: a skill a rules file
tells an agent to invoke is a skill that must exist, and a hand list would drift.

Looks for the mattpocock-skills plugin in Claude Code's installed_plugins.json,
installed for the user or for a project above the cwd and enabled in settings, then
lists the skills its manifest ships. Exit 0 when every name is there, 1 otherwise.
"""
import json
import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
SKILL = HERE.parent
PLUGIN = "mattpocock-skills"
NAMED = re.compile(r"mattpocock-skills:([a-z][a-z0-9-]*)")
CONFIG = Path(os.environ.get("CLAUDE_CONFIG_DIR") or Path.home() / ".claude")
INSTALL = f"/plugin install {PLUGIN}@claude-plugins-official"


def required() -> set:
    names = set()
    for f in [SKILL / "SKILL.md", *(SKILL / "templates").rglob("*.md")]:
        names.update(NAMED.findall(f.read_text()))
    return names


def load(path: Path) -> dict:
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return {}


def applies(entry: dict, cwd: Path) -> bool:
    if entry.get("scope") == "user":
        return True
    project = entry.get("projectPath")
    return bool(project) and (cwd == Path(project) or Path(project) in cwd.parents)


def enabled(key: str, cwd: Path) -> bool:
    """User settings first, then each project's above the cwd; the nearest says last."""
    files = [CONFIG / "settings.json"]
    for d in reversed([cwd, *cwd.parents]):
        if d == Path.home():    # its .claude/ is the user config, not a project's
            continue
        files +=[d / ".claude/settings.json", d / ".claude/settings.local.json"]
    state = None
    for f in files:
        v = load(f).get("enabledPlugins", {}).get(key)
        if v is not None:
            state = bool(v)
    return bool(state)


def shipped(install: Path) -> set:
    """Skill names the plugin ships: its manifest's list, or its skills/ tree."""
    manifest = load(install / ".claude-plugin/plugin.json")
    dirs = ([install / p for p in manifest["skills"]] if "skills" in manifest
            else [f.parent for f in (install / "skills").rglob("SKILL.md")])
    names = set()
    for d in dirs:
        m = re.search(r"^name:\s*(\S+)", (d / "SKILL.md").read_text(), re.M) \
            if (d / "SKILL.md").is_file() else None
        names.add(m.group(1) if m else d.name)
    return names


def main() -> int:
    want = set(sys.argv[1:]) or required()
    cwd = Path.cwd().resolve()
    plugins = load(CONFIG / "plugins/installed_plugins.json").get("plugins", {})
    keys = [k for k in plugins if k.split("@")[0] == PLUGIN]
    installs = [(k, e) for k in keys for e in plugins[k] if applies(e, cwd)]

    if not installs:
        print(f"check-skills: the {PLUGIN} plugin is not installed for {cwd}.\n"
              f"  Install it in Claude Code: {INSTALL}", file=sys.stderr)
        return 1
    live = [(k, e) for k, e in installs if enabled(k, cwd)]
    if not live:
        print(f"check-skills: {PLUGIN} is installed but disabled. "
              f"Enable it with /plugin, or set enabledPlugins.\"{installs[0][0]}\": true "
              f"in {CONFIG / 'settings.json'}", file=sys.stderr)
        return 1

    have = set().union(*(shipped(Path(e["installPath"])) for _, e in live))
    missing = sorted(want - have)
    version = live[0][1].get("version", "?")
    if missing:
        print(f"check-skills: {PLUGIN} {version} lacks {', '.join(missing)}. "
              f"Update it with /plugin, or drop the name from the brief", file=sys.stderr)
        return 1
    print(f"{PLUGIN} {version}: all {len(want)} skill(s) present")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
