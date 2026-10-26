#!/usr/bin/env python3
"""Lint Cuadrilla agent and command definitions for OpenCode 1.x and 2.x.

Sources (`agents/*.md`, `commands/*.md`) use the V1 frontmatter format, which both
OpenCode 1.x and 2.x load. `dist/v2/agents/*.md` is generated from them by
`scripts/build.py`. This script catches the mistakes that silently break or weaken agents:

  * missing/invalid frontmatter fields, unknown fields, and V1/V2 fields mixed in one file
    (V2 decides per file which format it reads, so a mixed file loses fields)
  * deprecated `tools:` / `maxSteps:` keys and hard-coded `model:`
  * permission maps where a catch-all "*" is not the FIRST rule
    (OpenCode evaluates rules in order and the LAST match wins, so a trailing
    "*" silently overrides every specific allow/deny above it)
  * unknown permission actions (a typo is a rule that never matches)
  * agents that don't declare `external_directory` or `websearch` (V2 allows both by
    default, unlike V1) or that read `.env` files without asking
  * subagents that can spawn other subagents, and orchestrator task permissions or
    agent references pointing to agents that don't exist
  * a `dist/v2` that is missing, stale, or not equivalent to its source

Usage: python3 scripts/validate.py   (exit code 1 on errors)
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
PREFIX = "cuadrilla"
BUILTIN_AGENTS = {"build", "plan", "general", "explore"}
VALID_MODES = {"primary", "subagent", "all"}
ACTIONS = {"allow", "ask", "deny"}

# Frontmatter fields per format (OpenCode 1.19 / 2.1 agent schemas).
V1_AGENT_FIELDS = {"description", "mode", "temperature", "top_p", "color", "steps", "hidden",
                   "disable", "model", "variant", "permission", "prompt", "options", "tools", "maxSteps"}
V2_ONLY_AGENT_FIELDS = {"permissions", "request", "system", "disabled"}
V2_AGENT_FIELDS = {"description", "mode", "hidden", "color", "model", "steps", "disabled",
                   "request", "permissions", "system"}
COMMAND_FIELDS = {"description", "agent", "model", "variant", "subtask", "subagent"}

# Permission actions. V1 files may name V2-only actions: V1 accepts unknown keys and
# ignores them, V2 applies them.
V1_PERMISSION_ACTIONS = {"read", "edit", "glob", "grep", "list", "bash", "task", "external_directory",
                         "todowrite", "question", "webfetch", "websearch", "lsp", "doom_loop", "skill"}
V2_ONLY_PERMISSION_ACTIONS = {"browser"}
SIMPLE_ACTIONS = {"todowrite", "question", "webfetch", "websearch", "doom_loop"}  # string only, no map
V2_PERMISSION_ACTIONS = {"read", "edit", "glob", "grep", "shell", "subagent", "external_directory",
                         "todowrite", "question", "webfetch", "websearch", "skill", "browser", "lsp"}
REQUIRED_ACTIONS = {"external_directory", "websearch"}
ENV_PATTERNS = ("*.env", "*.env.*")

errors: list[str] = []
warnings: list[str] = []


def parse(path: Path) -> tuple[dict, str]:
    text = path.read_text(encoding="utf-8")
    match = build.FRONTMATTER.match(text)
    if not match:
        errors.append(f"{path.name}: missing YAML frontmatter")
        return {}, text
    if "\r\n" in text:
        warnings.append(f"{path.name}: CRLF line endings (the repo's .gitattributes expects LF)")
    try:
        data = yaml.safe_load(match.group(1)) or {}
    except yaml.YAMLError as exc:
        errors.append(f"{path.name}: invalid YAML: {exc}")
        return {}, match.group(2)
    if not isinstance(data, dict):
        errors.append(f"{path.name}: frontmatter must be a map")
        return {}, match.group(2)
    return data, match.group(2)


def check_permission(name: str, perm: object) -> None:
    if isinstance(perm, str):
        if perm not in ACTIONS:
            errors.append(f"{name}: permission value '{perm}' is not allow/ask/deny")
        return
    if not isinstance(perm, dict):
        errors.append(f"{name}: permission must be a string or map")
        return
    for key, rule in perm.items():
        if key not in V1_PERMISSION_ACTIONS | V2_ONLY_PERMISSION_ACTIONS:
            errors.append(f"{name}: unknown permission action '{key}' (the rule would never match)")
        if isinstance(rule, str):
            if rule not in ACTIONS:
                errors.append(f"{name}: permission.{key} = '{rule}' is not allow/ask/deny")
        elif isinstance(rule, dict):
            if key in SIMPLE_ACTIONS:
                errors.append(f"{name}: permission.{key} must be a single allow/ask/deny, not a map")
            patterns = list(rule.keys())
            if "*" in patterns and patterns[0] != "*":
                errors.append(
                    f"{name}: permission.{key} has '*' at position {patterns.index('*') + 1}; "
                    "it must be first (last matching rule wins)"
                )
            for pattern, action in rule.items():
                if action not in ACTIONS:
                    errors.append(f"{name}: permission.{key}['{pattern}'] = '{action}' is invalid")
        else:
            errors.append(f"{name}: permission.{key} has an invalid value")


def check_hardening(name: str, perm: object) -> None:
    """Rules that keep an agent as strict on OpenCode V2 as it was on V1."""
    if not isinstance(perm, dict):
        return
    for action in sorted(REQUIRED_ACTIONS - set(perm)):
        errors.append(f"{name}: permission.{action} must be set (OpenCode V2 allows it by default)")
    if perm.get("external_directory") == "allow":
        errors.append(f"{name}: external_directory must be 'ask' or 'deny', not 'allow'")
    read = perm.get("read", "allow")
    if read == "allow" or (isinstance(read, dict) and any(read.get(p, "allow") == "allow" for p in ENV_PATTERNS)):
        errors.append(f"{name}: read must ask or deny for {', '.join(ENV_PATTERNS)} (secrets)")


def check_v2_output(sources: dict[str, dict]) -> None:
    try:
        outputs = build.build()
    except build.BuildError as exc:
        errors.append(f"dist/v2: {exc}")
        return
    for filename, (expected_fm, text) in outputs.items():
        path = build.OUT / filename
        if not path.is_file():
            errors.append(f"dist/v2/agents/{filename} is missing — run: python3 scripts/build.py")
            continue
        if path.read_text(encoding="utf-8") != text:
            errors.append(f"dist/v2/agents/{filename} is out of date — run: python3 scripts/build.py")
            continue
        name = path.stem
        data, _ = parse(path)
        if data != expected_fm:
            errors.append(f"dist/v2/agents/{filename}: frontmatter does not parse back to the expected V2 config")
        unknown = sorted(set(data) - V2_AGENT_FIELDS)
        if unknown:
            errors.append(f"dist/v2/agents/{filename}: fields {unknown} are not V2 agent fields")
        rules = data.get("permissions", [])
        for rule in rules:
            if set(rule) != {"action", "resource", "effect"} or rule["effect"] not in ACTIONS:
                errors.append(f"dist/v2/agents/{filename}: invalid rule {rule}")
            elif rule["action"] not in V2_PERMISSION_ACTIONS:
                errors.append(f"dist/v2/agents/{filename}: unknown V2 action '{rule['action']}'")
        if sources.get(name, {}).get("mode") == "subagent":
            spawn = [r for r in rules if r.get("action") in ("subagent", "*")]
            if not spawn or spawn[-1].get("effect") != "deny" or spawn[-1].get("resource") != "*":
                errors.append(f"dist/v2/agents/{filename}: subagent must end with a 'subagent * deny' rule")
    for extra in sorted(p.name for p in build.OUT.glob("*.md") if p.name not in outputs):
        errors.append(f"dist/v2/agents/{extra} has no source in agents/")


def main() -> int:
    agents = sorted((ROOT / "agents").glob("*.md"))
    agent_names = {p.stem for p in agents}
    primaries = []
    sources: dict[str, dict] = {}

    for path in agents:
        name = path.stem
        data, body = parse(path)
        if not data:
            continue
        sources[name] = data
        if not name.startswith(PREFIX):
            errors.append(f"{name}: agent file names must start with '{PREFIX}'")
        mixed = sorted(set(data) & V2_ONLY_AGENT_FIELDS)
        if mixed:
            errors.append(f"{name}: V2 field(s) {mixed} in a V1 source — keep sources V1, "
                          "dist/v2 is generated (a mixed file loses fields on V2)")
        unknown = sorted(set(data) - V1_AGENT_FIELDS - V2_ONLY_AGENT_FIELDS)
        if unknown:
            errors.append(f"{name}: unknown frontmatter field(s) {unknown}")
        if not str(data.get("description", "")).strip():
            errors.append(f"{name}: 'description' is required (the orchestrator routes by it)")
        mode = data.get("mode")
        if mode not in VALID_MODES:
            errors.append(f"{name}: mode must be one of {sorted(VALID_MODES)}")
        if "tools" in data:
            errors.append(f"{name}: 'tools' is deprecated — use 'permission'")
        if "maxSteps" in data:
            errors.append(f"{name}: 'maxSteps' is deprecated — use 'steps'")
        if "model" in data:
            warnings.append(f"{name}: hard-coded 'model' — prefer per-user overrides in opencode.json")
        if len(body.strip()) < 200:
            warnings.append(f"{name}: system prompt looks very short")

        perm = data.get("permission", {})
        check_permission(name, perm)
        check_hardening(name, perm)
        task = perm.get("task") if isinstance(perm, dict) else None

        if mode == "subagent" and task != "deny":
            errors.append(f"{name}: subagents must set 'task: deny' (prevents recursive delegation)")

        if mode in {"primary", "all"}:
            primaries.append(name)
            if isinstance(task, dict):
                for pattern, action in task.items():
                    if action == "deny" or pattern == "*" or "*" in pattern:
                        continue
                    if pattern not in agent_names and pattern not in BUILTIN_AGENTS:
                        errors.append(f"{name}: task permission references unknown agent '{pattern}'")
                    elif pattern in BUILTIN_AGENTS:
                        warnings.append(f"{name}: delegates to built-in '{pattern}', whose permissions "
                                        "Cuadrilla doesn't control")

        # Every @mention / backticked cuadrilla-* reference must exist
        for ref in set(re.findall(r"\b(cuadrilla-[a-z0-9-]+)\b", body)):
            if ref not in agent_names:
                errors.append(f"{name}: body references unknown agent '{ref}'")

    if len(primaries) != 1:
        warnings.append(f"expected exactly one primary agent, found {primaries}")

    commands = sorted((ROOT / "commands").glob("*.md"))
    for path in commands:
        data, body = parse(path)
        if not data:
            continue
        if not path.stem.startswith(PREFIX):
            errors.append(f"command {path.stem}: file names must start with '{PREFIX}'")
        unknown = sorted(set(data) - COMMAND_FIELDS)
        if unknown:
            errors.append(f"command {path.stem}: unknown frontmatter field(s) {unknown}")
        if not str(data.get("description", "")).strip():
            errors.append(f"command {path.stem}: 'description' is required")
        agent = data.get("agent")
        if agent and agent not in agent_names and agent not in BUILTIN_AGENTS:
            errors.append(f"command {path.stem}: unknown agent '{agent}'")
        for ref in set(re.findall(r"\b(cuadrilla-[a-z0-9-]+)\b", body)):
            if ref not in agent_names and ref != path.stem:
                errors.append(f"command {path.stem}: body references unknown agent '{ref}'")

    check_v2_output(sources)

    for w in warnings:
        print(f"warning: {w}")
    for e in errors:
        print(f"error:   {e}")
    print(f"\n{len(agents)} agents, {len(commands)} commands, dist/v2 checked — "
          f"{len(errors)} errors, {len(warnings)} warnings")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
