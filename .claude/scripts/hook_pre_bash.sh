#!/usr/bin/env bash
#
# PreToolUse hook for Bash. Blocks any command that would set or
# export ANTHROPIC_API_KEY / ANTHROPIC_API_TOKEN — those environment
# variables switch Claude Code from Max plan OAuth authentication
# to API credit billing, which silently breaks the loop's quota
# economics (see Phase 0 setup notes).
#
# Exit 0 = allow the Bash call to proceed.
# Exit 2 = block; stderr message is shown to Claude as the reason.

set -uo pipefail

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

# Match only SETTING/EXPORT of the env vars, not their incidental
# appearance in echo/grep/log strings. Patterns we want to block:
#   ANTHROPIC_API_KEY=...           (bare assignment)
#   export ANTHROPIC_API_KEY=...    (export form)
#   setenv ANTHROPIC_API_KEY ...    (csh form)
#   env ANTHROPIC_API_KEY=...       (one-shot env)
# Patterns we want to ALLOW:
#   echo "ANTHROPIC_API_KEY"        (string mention)
#   grep ANTHROPIC_API_KEY ...      (search)
#   unset ANTHROPIC_API_KEY         (already-unset OK)

if echo "$CMD" | grep -qE '(^|[[:space:];&|])(export[[:space:]]+|setenv[[:space:]]+|env[[:space:]]+)?ANTHROPIC_API_(KEY|TOKEN)[[:space:]]*='; then
    echo "Setting ANTHROPIC_API_KEY or ANTHROPIC_API_TOKEN would switch from Max plan OAuth to API billing. Refused." >&2
    echo "If you genuinely intend API billing, run the command manually outside the loop." >&2
    exit 2
fi

exit 0
