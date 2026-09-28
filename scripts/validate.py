#!/usr/bin/env python3
"""Lint Cuadrilla agent and command definitions.

Catches the mistakes that silently break OpenCode agents:
  * missing/invalid frontmatter fields
  * deprecated `tools:` key (use `permission:`)
  * hard-coded `model:` (breaks users without that provider)
  * permission maps where a catch-all "*" is not the FIRST rule
    (OpenCode evaluates rules in order and the LAST match wins, so a trailing
    "*" silently overrides every specific allow/deny above it)
  * subagents that can spawn other subagents
  * orchestrator task permissions pointing to agents that don't exist

Usage: python3 scripts/validate.py   (exit code 1 on errors)
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
PREFIX = "cuadrilla"
BUILTIN_AGENTS = {"build", "plan", "general", "explore"}
VALID_MODES = {"primary", "subagent", "all"}
ACTIONS = {"allow", "ask", "deny"}

errors: list[str] = []
warnings: list[str] = []


def parse(path: Path) -> tuple[dict, str]:
    text = path.read_text(encoding="utf-8")
    match = re.match(r"^---\n(.*?)\n---\n(.*)$", text, re.S)
    if not match:
        errors.append(f"{path.name}: missing YAML frontmatter")
        return {}, text
    try:
        data = yaml.safe_load(match.group(1)) or {}
    except yaml.YAMLError as exc:
        errors.append(f"{path.name}: invalid YAML: {exc}")
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
        if isinstance(rule, str):
            if rule not in ACTIONS:
                errors.append(f"{name}: permission.{key} = '{rule}' is not allow/ask/deny")
        elif isinstance(rule, dict):
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


def main() -> int:
    agents = sorted((ROOT / "agents").glob("*.md"))
    agent_names = {p.stem for p in agents}
    primaries = []

    for path in agents:
        name = path.stem
        data, body = parse(path)
        if not data:
            continue
        if not name.startswith(PREFIX):
            errors.append(f"{name}: agent file names must start with '{PREFIX}'")
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

        # Every @mention / backticked cuadrilla-* reference must exist
        for ref in set(re.findall(r"\b(cuadrilla-[a-z0-9-]+)\b", body)):
            if ref not in agent_names:
                errors.append(f"{name}: body references unknown agent '{ref}'")

    if len(primaries) != 1:
        warnings.append(f"expected exactly one primary agent, found {primaries}")

    for path in sorted((ROOT / "commands").glob("*.md")):
        data, body = parse(path)
        if not data:
            continue
        if not path.stem.startswith(PREFIX):
            errors.append(f"command {path.stem}: file names must start with '{PREFIX}'")
        if not str(data.get("description", "")).strip():
            errors.append(f"command {path.stem}: 'description' is required")
        agent = data.get("agent")
        if agent and agent not in agent_names and agent not in BUILTIN_AGENTS:
            errors.append(f"command {path.stem}: unknown agent '{agent}'")
        for ref in set(re.findall(r"\b(cuadrilla-[a-z0-9-]+)\b", body)):
            if ref not in agent_names and ref != path.stem:
                errors.append(f"command {path.stem}: body references unknown agent '{ref}'")

    for w in warnings:
        print(f"warning: {w}")
    for e in errors:
        print(f"error:   {e}")
    print(f"\n{len(agents)} agents, {len(list((ROOT / 'commands').glob('*.md')))} commands — "
          f"{len(errors)} errors, {len(warnings)} warnings")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
