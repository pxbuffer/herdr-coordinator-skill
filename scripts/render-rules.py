#!/usr/bin/env python3
"""Render every repo's rules from the topology. One source of truth, no typing.

    render-rules.py [--check] [--dry-run] [--topology PATH]

Every value the templates need — role names, project names, relative paths, the
channel diagram, the sibling list — is derived from .claude/herdr/topology.json.
Nothing is passed by hand, because a hand-typed role name is a role name that can
disagree with the topology, and then the scripts and the rules describe different
systems.

Project count and project names are whatever the topology says. Two repos named
frontend and backend are one possible system, not the shape.

This script only ever READS topology.json. Gate commands in particular are
hand-authored there and nothing here rewrites them: the rendered "Gates" section
in a project's rules file is output, and the topology is the input.
"""
import json
import os
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
SKILL = HERE.parent

# Writing-style rule for the coordinator tier. "ste100" ships the ASD-STE100
# rules; "none" renders nothing and leaves no reference behind.
STYLES = ("ste100", "none")
DEFAULT_STYLE = "ste100"

# A project whose toolchain does not exist yet sets gates to this. It renders, so
# the coordinator can run wayfinder to choose the stack; it just cannot be
# dispatched to. An ABSENT gates field stays an error, so pending is always a
# deliberate choice rather than an oversight.
GATES_PENDING = "pending"

# Where the rendered rules land: (rules file, agent docs directory). "tracked"
# writes CLAUDE.md and docs/agents/ for repos that version them. "local" writes
# CLAUDE.local.md and .claude/herdr/docs/ and lists both in the repo's
# .git/info/exclude, for team repos: the rules carry this machine's absolute
# paths and pane IDs, which must never reach a shared commit.
LAYOUTS = {"tracked": ("CLAUDE.md", "docs/agents"),
           "local": ("CLAUDE.local.md", ".claude/herdr/docs")}
DEFAULT_LAYOUT = "tracked"


def find_topology(start: Path) -> Path:
    env = os.environ.get("HC_TOPOLOGY")
    if env:
        return Path(env)
    for d in [start, *start.parents]:
        c = d / ".claude" / "herdr" / "topology.json"
        if c.is_file():
            return c
    sys.exit("render-rules: no .claude/herdr/topology.json found above " + str(start))


def check_no_shadow_copies(topo_path: Path, roles: dict) -> list:
    """There is one topology, and it lives above every repo it describes.

    Discovery takes the NEAREST .claude/herdr/topology.json above the cwd, so a
    stale copy inside a repo silently replaces the canonical file for every
    script run from there. Comparing copies against "the discovered one" cannot
    catch that: run from inside that repo, the stale copy IS the discovered one
    and the system reports itself consistent.

    So the invariant is positional, not comparative: a topology that lives inside
    a repo it lists as a project is in the wrong place, whichever file won the
    walk-up. That holds from every cwd.
    """
    errors = []
    topo_repo = topo_path.resolve().parent.parent.parent   # <repo>/.claude/herdr/x.json
    cwds = {Path(r["cwd"]).resolve(): n for n, r in roles.items() if r.get("cwd")}

    if topo_repo in cwds:
        errors.append(
            f"the topology in use ({topo_path.resolve()}) lives inside {topo_repo.name}/, "
            f"which it lists as {cwds[topo_repo]}'s repo. Discovery takes the nearest match, "
            f"so this copy shadows the real one for everything run in {topo_repo.name}/. "
            f"The canonical topology belongs above every repo it describes — delete this copy")

    canonical = topo_path.resolve()
    for cwd, role in cwds.items():
        local = cwd / ".claude" / "herdr" / "topology.json"
        if local.exists() and local.resolve() != canonical:
            errors.append(
                f"{local} shadows the canonical topology ({canonical}) for anything run "
                f"inside {cwd.name}/. There is one topology, above every repo. Delete this copy")
    return errors


def validate(roles: dict, style: str, layout: str) -> dict:
    """Fail loudly on anything that would make the rendered rules lie."""
    errors = []
    warnings = []

    if style not in STYLES:
        errors.append(f"style must be one of {' | '.join(STYLES)}, got {style!r} "
                      f"(omit the field for the {DEFAULT_STYLE!r} default)")
    if layout not in LAYOUTS:
        errors.append(f"rules must be one of {' | '.join(LAYOUTS)}, got {layout!r} "
                      f"(omit the field for the {DEFAULT_LAYOUT!r} default)")

    tops = [n for n, r in roles.items() if not r.get("parent")]
    if len(tops) != 1:
        errors.append(f"expected exactly one role with no parent (the coordinator), got {tops}")

    kinds = {n: r.get("kind") for n, r in roles.items()}
    for n, k in kinds.items():
        if k not in ("coordinator", "orchestrator", "worker"):
            errors.append(f"{n}: kind must be coordinator|orchestrator|worker, got {k!r}")

    prefixes = {r.get("prefix") for r in roles.values()}
    if len(prefixes) != 1 or not next(iter(prefixes)):
        errors.append(f"one ledger means one prefix on every role; found {prefixes}")

    panes = {}
    for n, r in roles.items():
        pane = r.get("pane")
        if not pane:
            errors.append(f"{n}: no pane")
        elif pane in panes:
            errors.append(f"{n} and {panes[pane]} both claim pane {pane}")
        else:
            panes[pane] = n
        if not r.get("cwd"):
            errors.append(f"{n}: no cwd")

    for n, r in roles.items():
        for child in r.get("children") or []:
            if child not in roles:
                errors.append(f"{n}: unknown child {child}")
            elif roles[child].get("parent") != n:
                errors.append(f"{n} lists child {child}, but {child}'s parent is "
                              f"{roles[child].get('parent')!r}")
        parent = r.get("parent")
        if parent:
            if parent not in roles:
                errors.append(f"{n}: unknown parent {parent}")
            elif n not in (roles[parent].get("children") or []):
                errors.append(f"{n}'s parent is {parent}, but {parent} does not list it as a child")

    if len(tops) == 1:
        top = tops[0]
        if kinds.get(top) != "coordinator":
            errors.append(f"{top} has no parent so it is the coordinator, but its kind is {kinds.get(top)!r}")
        for n, r in roles.items():
            if kinds.get(n) == "orchestrator":
                if r.get("parent") != top:
                    errors.append(f"orchestrator {n} must be a child of {top}, not {r.get('parent')!r}")
                children = r.get("children") or []
                workers = [c for c in children if kinds.get(c) == "worker"]
                if not workers:
                    errors.append(f"orchestrator {n} has no worker child")
                elif len(workers) > 1:
                    errors.append(
                        f"orchestrator {n} lists {len(workers)} workers ({', '.join(workers)}); "
                        f"a project tier is exactly one orchestrator and one worker. Parallelism "
                        f"belongs in that worker's own sub agents, not in a second pane sharing "
                        f"the repo")
                for c in children:
                    if kinds.get(c) != "worker":
                        errors.append(f"orchestrator {n} lists {c} (kind {kinds.get(c)!r}) as a "
                                      f"child; an orchestrator's only child is its worker")
                gates = r.get("gates")
                if "gates" not in r:
                    errors.append(
                        f"orchestrator {n} has no gates field: add a \"gates\" list of shell "
                        f"commands, in the order they must run, or \"{GATES_PENDING}\" if the "
                        f"toolchain does not exist yet. Leaving it out is not the same as "
                        f"{GATES_PENDING!r} — pending has to be chosen on purpose")
                elif gates == GATES_PENDING:
                    warnings.append(
                        f"{n}: gates are {GATES_PENDING}. {Path(r['cwd']).name}/ renders, but "
                        f"brief.sh will refuse to dispatch to it until the gate commands are "
                        f"recorded. Use 'brief.sh --bootstrap' for the toolchain-setup brief")
                elif isinstance(gates, str):
                    errors.append(f"{n}: gates must be a list of shell command strings, or the "
                                  f"string {GATES_PENDING!r}; got {gates!r}")
                elif not isinstance(gates, list) or not gates:
                    errors.append(f"{n}: gates must be a non-empty list of shell command "
                                  f"strings, or {GATES_PENDING!r}; got "
                                  f"{type(gates).__name__ if not isinstance(gates, list) else 'an empty list'}")
                else:
                    for i, g in enumerate(gates):
                        if not isinstance(g, str) or not g.strip():
                            errors.append(f"{n}: gates[{i}] must be a non-empty shell command "
                                          f"string, got {g!r}")
                for c in children:
                    if roles[c].get("cwd") != r.get("cwd"):
                        errors.append(f"{c} shares no cwd with its orchestrator {n} — a project "
                                      f"tier shares one repo and therefore one rules file")

    if errors:
        sys.exit("render-rules: topology is inconsistent:\n" + "\n".join("  - " + e for e in errors))

    return {"top": tops[0], "kinds": kinds, "prefix": next(iter(prefixes)),
            "warnings": warnings}


def channels(roles: dict, top: str, prefix: str) -> str:
    """The confirmed graph as ASCII, drawn from the topology rather than typed."""
    design = Path(roles[top]["cwd"]).name
    lines = [f"user ──► {top}",
             f"         {design}/ · ledger `{prefix}-` · the only pane the user talks to",
             "            │"]
    orchs = [n for n, r in roles.items() if r.get("parent") == top]
    for i, o in enumerate(orchs):
        last = i == len(orchs) - 1
        elbow = "└" if last else "├"
        gutter = " " if last else "│"
        workers = [c for c in (roles[o].get("children") or [])
                   if roles[c].get("kind") == "worker"]
        tail = "".join(f" ──► {w}" for w in workers)
        lines.append(f"            {elbow}──► {o}{tail} ──► sub agents (Task tool)")
        lines.append(f"            {gutter}    {Path(roles[o]['cwd']).name}/")
        if not last:
            lines.append("            │")
    lines += ["", "briefs flow down · verdicts flow up · no horizontal calls"]
    return "\n".join(lines)


def render(template: Path, out: Path, values: dict, dry: bool) -> None:
    args = [str(HERE / "render.py"), str(template)]
    if not dry:
        args += ["--out", str(out)]
    args += [f"{k}={v}" for k, v in values.items()]
    r = subprocess.run(args, stdin=subprocess.DEVNULL, capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit(f"render-rules: {template.name} → {out}\n{r.stderr.strip()}")
    print(("would render " if dry else "") + str(out))


def exclude(repo: Path, paths: list, dry: bool) -> None:
    """List rendered paths in the repo's own .git/info/exclude, never a .gitignore:
    the exclusion is as local as the files, so a team repo shows no trace of it."""
    r = subprocess.run(["git", "-C", str(repo), "rev-parse", "--git-path", "info/exclude"],
                       capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit(f"render-rules: {repo} is not a git repository, so the local rules "
                 f"there cannot be kept out of its commits")
    f = Path(r.stdout.strip())
    if not f.is_absolute():
        f = repo / f
    have = set(f.read_text().splitlines()) if f.exists() else set()
    missing = [p for p in paths if p not in have]
    if not missing:
        return
    if not dry:
        f.parent.mkdir(parents=True, exist_ok=True)
        with f.open("a") as fh:
            fh.write(("" if not have or f.read_text().endswith("\n") else "\n")
                     + "# herdr-coordinator: rendered rules, local to this machine\n"
                     + "".join(p + "\n" for p in missing))
    print(("would exclude " if dry else "excluded ") + ", ".join(missing) + f" in {repo.name}/")


def main() -> int:
    check = "--check" in sys.argv
    dry = "--dry-run" in sys.argv
    if "--topology" in sys.argv:
        os.environ["HC_TOPOLOGY"] = sys.argv[sys.argv.index("--topology") + 1]

    topo_path = find_topology(Path.cwd())
    topo = json.loads(topo_path.read_text())
    roles = topo["roles"]
    style = topo.get("style", DEFAULT_STYLE)
    layout = topo.get("rules", DEFAULT_LAYOUT)
    meta = validate(roles, style, layout)
    shadows = check_no_shadow_copies(topo_path, roles)
    if shadows:
        sys.exit("render-rules: topology is inconsistent:\n"
                 + "\n".join("  - " + e for e in shadows))
    top, kinds, prefix = meta["top"], meta["kinds"], meta["prefix"]

    design_cwd = Path(roles[top]["cwd"])
    orchs = [n for n, r in roles.items() if kinds.get(n) == "orchestrator"]
    projects = {n: Path(roles[n]["cwd"]) for n in orchs}

    print(f"topology: {topo_path}")
    print(f"coordinator: {top} ({design_cwd.name}/), ledger prefix {prefix}-, style {style}, "
          f"rules {layout}")
    print(f"projects ({len(projects)}): " + ", ".join(f"{n}→{p.name}/" for n, p in projects.items()))
    for w in meta["warnings"]:
        print(f"warning: {w}")
    if check:
        print("topology is consistent"
              + (f" ({len(meta['warnings'])} warning(s) above)" if meta["warnings"] else ""))
        return 0

    rules_file, agent_docs = LAYOUTS[layout]
    if layout == "local":
        for repo in [design_cwd, *projects.values()]:
            exclude(repo, [f"/{rules_file}", f"/{agent_docs}/"], dry)

    labels = "\n".join(f"- `project-{p.name}` — the `{n}` tier" for n, p in projects.items())
    chan = channels(roles, top, prefix)

    # --- the coordinator's repo ---
    cdir = SKILL / "templates/rules/coordinator"
    if style == "none":
        style_section, style_pointer = "", ""
    else:
        style_section = (
            "## Writing style\n\n"
            "Write every reply and every document you author in ASD-STE100 Simplified\n"
            "Technical English: active voice, one idea per sentence, 20 words or fewer.\n"
            f"`{agent_docs}/writing-style.md` has the full rule and the allowed exceptions.\n"
            "It binds this tier only.\n\n")
        style_pointer = f"\n- `{agent_docs}/writing-style.md` — the ASD-STE100 writing rule"

    topo_abs = topo_path.resolve()
    base = dict(PROJECT=design_cwd.name, PREFIX=prefix, TOP=top, SCRIPTS=str(HERE),
                TOPOLOGY=os.path.relpath(topo_abs, design_cwd),
                CHANNELS=chan, PROJECT_LABELS=labels,
                CHILD_EXAMPLE=orchs[0] if orchs else top,
                STYLE_SECTION=style_section, STYLE_POINTER=style_pointer,
                RULES_FILE=rules_file, AGENT_DOCS=agent_docs)
    render(cdir / "CLAUDE.md", design_cwd / rules_file, base, dry)
    base["SCRATCH"] = f"/tmp/{prefix}-maps"
    for name in ("orchestration", "ledger", "triage-labels", "domain", "wayfinder"):
        render(cdir / f"{name}.md", design_cwd / agent_docs / f"{name}.md", base, dry)

    # The style rule is coordinator-only, so it renders only here and only when asked.
    style_doc = design_cwd / agent_docs / "writing-style.md"
    if style == "none":
        if style_doc.exists() and not dry:
            style_doc.unlink()
            print(f"removed {style_doc}")
    else:
        render(cdir / "writing-style.md", style_doc, base, dry)

    # --- each project repo ---
    pdir = SKILL / "templates/rules/project"
    for orch, cwd in projects.items():
        workers = [c for c in (roles[orch].get("children") or []) if kinds.get(c) == "worker"]
        others = [p for n, p in projects.items() if n != orch]
        siblings = ("\n".join(f"  - `{os.path.relpath(o, cwd)}/`" for o in others)
                    or "  (none — this is the only project in the system)")
        g = roles[orch]["gates"]
        if g == GATES_PENDING:
            gates = (
                "This project has no gates yet: `gates` is `\"pending\"` in\n"
                f"`{os.path.relpath(topo_abs, cwd)}`, because the toolchain is not chosen.\n\n"
                "`brief.sh` refuses to dispatch ordinary work here, because nothing would\n"
                "verify its commit. The one brief that arrives is a **toolchain-setup brief**\n"
                "(`brief.sh --bootstrap`), and it is what ends this state.\n\n"
                "That brief sets up the toolchain, then runs the gate commands it established.\n"
                "If every gate passes, it commits the scaffold on its bead branch and pushes —\n"
                "an uncommitted scaffold would sit in the working tree with nothing recording\n"
                "it, and the next bead would branch on top of work that is in no commit. If any\n"
                "gate fails, it reports `blocked` and commits nothing.\n\n"
                f"Its `done` verdict reports the gate commands verbatim, the gate results and\n"
                f"the commit hash, so {top} can record the commands here and open this project\n"
                "for normal work.")
        else:
            gates = ("Run these in order. Each one passes before the next starts:\n\n"
                     + "\n".join(f"{i}. `{c}`" for i, c in enumerate(g, 1))
                     + "\n\nA gate that fails, and that you cannot fix inside this bead, is a "
                       "`blocked`\nverdict with the failing output in the detail.")
        vals = dict(PROJECT=cwd.name, PREFIX=prefix, TOP=top, MAIN=orch,
                    AGENT=workers[0], DESIGN_REL=os.path.relpath(design_cwd, cwd),
                    SIBLINGS=siblings, SCRIPTS=str(HERE), GATES=gates,
                    TOPOLOGY=os.path.relpath(topo_abs, cwd),
                    RULES_FILE=rules_file, AGENT_DOCS=agent_docs)
        render(pdir / "CLAUDE.md", cwd / rules_file, vals, dry)
        render(pdir / "design-docs.md", cwd / agent_docs / "design-docs.md", vals, dry)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
