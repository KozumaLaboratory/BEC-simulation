#!/usr/bin/env python3
"""
Parse a turn's stream-json log (claude -p --output-format stream-json)
and extract per-subagent token usage.

Anthropic stream-json schema (as of Claude Code 2.x):
- Each `message_start` event reports usage with `input_tokens`,
  `cache_creation_input_tokens`, `cache_read_input_tokens`. The
  `output_tokens` field on message_start is small (initial).
- Each `message_delta` event reports usage with `output_tokens`
  *cumulatively* (i.e. the field grows as the message streams).
- Each `message_stop` event reports the final usage.

The correct extraction takes:
  per message: input_tokens (once, on start) + final output_tokens
  (on stop or final delta).

Previous bug: summed ALL events' total_tokens, double-counting because
deltas are cumulative.

Output schema (compatible with sim/turn_N.md §4 metrics tokens_used and
state.json history[].tokens_used):
    {
      "theorist": <int|null>,
      "researcher": <int|null>,
      "implementer": <int|null>,
      "critic": <int|null>,
      "orchestrator": <int|null>,
      "total": <int>,
      "n_messages": <int>,        # debug
      "n_message_starts": <int>   # debug
    }
"""

from __future__ import annotations

import json
import sys
from collections import defaultdict
from pathlib import Path


SUBAGENT_TYPES = {"theorist", "researcher", "implementer", "critic"}


def extract(log_path: Path) -> dict:
    if not log_path.exists():
        print(f"warn: log {log_path} not found", file=sys.stderr)
        return _empty()

    # Per-message accumulators keyed by message id; flushed at message_stop.
    open_messages: dict[str, dict] = {}
    by_agent: dict[str, int] = defaultdict(int)
    n_messages = 0
    n_starts = 0

    # Track which subagent is currently active via Task tool dispatches.
    # When a Task tool_use happens in an assistant message, the next
    # subagent context is attributed to that subagent type.
    pending_subagent_stack: list[str] = []  # depth tracking via Task open/close

    with log_path.open("r", encoding="utf-8") as fp:
        for raw in fp:
            raw = raw.strip()
            if not raw:
                continue
            try:
                event = json.loads(raw)
            except json.JSONDecodeError:
                continue

            etype = event.get("type")
            if etype == "system":
                continue

            # Track Task tool dispatches to attribute tokens to subagents.
            msg = event.get("message") or {}
            if etype == "assistant" and isinstance(msg.get("content"), list):
                for item in msg["content"]:
                    if (
                        isinstance(item, dict)
                        and item.get("type") == "tool_use"
                        and item.get("name") == "Task"
                    ):
                        sub_type = (item.get("input") or {}).get("subagent_type")
                        if sub_type in SUBAGENT_TYPES:
                            pending_subagent_stack.append(sub_type)

            # On a tool_result for a Task, the subagent finished.
            if etype == "user" and isinstance(msg.get("content"), list):
                for item in msg["content"]:
                    if (
                        isinstance(item, dict)
                        and item.get("type") == "tool_result"
                    ):
                        # Pop the most recent subagent dispatch.
                        # (Imperfect: doesn't match tool_use_id properly, but
                        # subagents are mostly sequential in our setup.)
                        if pending_subagent_stack:
                            pending_subagent_stack.pop()

            usage = _find_usage(event)
            if not usage:
                continue

            # The active attribution at this event time:
            attribution = (
                pending_subagent_stack[-1] if pending_subagent_stack else "orchestrator"
            )

            # Use a message id to dedupe deltas; the final usage per message
            # is taken from the message_stop (or last seen) event.
            msg_id = msg.get("id") or event.get("id") or f"_anon_{n_starts}"

            if msg_id not in open_messages:
                open_messages[msg_id] = {
                    "attr": attribution,
                    "input_tokens": 0,
                    "cache_creation": 0,
                    "cache_read": 0,
                    "output_tokens": 0,
                }
                n_starts += 1

            slot = open_messages[msg_id]
            # input_tokens / cache fields are non-cumulative — take max
            # (effectively "first non-zero value seen", since they're stable).
            for k_src, k_dst in [
                ("input_tokens", "input_tokens"),
                ("cache_creation_input_tokens", "cache_creation"),
                ("cache_read_input_tokens", "cache_read"),
            ]:
                v = usage.get(k_src)
                if isinstance(v, int) and v > slot[k_dst]:
                    slot[k_dst] = v

            # output_tokens grows during streaming; take max (final value).
            v_out = usage.get("output_tokens")
            if isinstance(v_out, int) and v_out > slot["output_tokens"]:
                slot["output_tokens"] = v_out

    # Flush all messages
    for slot in open_messages.values():
        total_for_msg = (
            slot["input_tokens"]
            + slot["cache_creation"]
            + slot["cache_read"]
            + slot["output_tokens"]
        )
        by_agent[slot["attr"]] += total_for_msg
        n_messages += 1

    # Also accumulate breakdown by category across all messages.
    breakdown = {"input_fresh": 0, "cache_creation": 0, "cache_read": 0, "output": 0}
    for slot in open_messages.values():
        breakdown["input_fresh"] += slot["input_tokens"]
        breakdown["cache_creation"] += slot["cache_creation"]
        breakdown["cache_read"] += slot["cache_read"]
        breakdown["output"] += slot["output_tokens"]

    if not by_agent:
        return _empty()

    raw_total = sum(by_agent.values())
    # Anthropic billing weights: input 1x, cache write 1.25x, cache read
    # 0.1x, output 5x. "Effective full-rate" = price-weighted, useful for
    # comparing per-turn cost against a budget that scales like the human
    # claude.ai rate limit.
    effective = (
        breakdown["input_fresh"]
        + breakdown["cache_creation"] * 1.25
        + breakdown["cache_read"] * 0.1
        + breakdown["output"] * 5
    )

    out = {
        "theorist": by_agent.get("theorist"),
        "researcher": by_agent.get("researcher"),
        "implementer": by_agent.get("implementer"),
        "critic": by_agent.get("critic"),
        "orchestrator": by_agent.get("orchestrator"),
        "total": raw_total,
        "effective_full_rate": int(effective),
        "breakdown": breakdown,
        "n_messages": n_messages,
        "n_message_starts": n_starts,
    }
    return out


def _empty() -> dict:
    return {
        "theorist": None,
        "researcher": None,
        "implementer": None,
        "critic": None,
        "orchestrator": None,
        "total": 0,
        "effective_full_rate": 0,
        "breakdown": {
            "input_fresh": 0,
            "cache_creation": 0,
            "cache_read": 0,
            "output": 0,
        },
        "n_messages": 0,
        "n_message_starts": 0,
    }


def _find_usage(event: dict) -> dict | None:
    if not isinstance(event, dict):
        return None
    if "usage" in event and isinstance(event["usage"], dict):
        return event["usage"]
    msg = event.get("message")
    if isinstance(msg, dict) and "usage" in msg and isinstance(msg["usage"], dict):
        return msg["usage"]
    return None


def main() -> int:
    if len(sys.argv) != 2:
        print(json.dumps(_empty()))
        return 0
    result = extract(Path(sys.argv[1]))
    print(json.dumps(result))
    return 0


if __name__ == "__main__":
    sys.exit(main())
