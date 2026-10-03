#!/usr/bin/env bash
#
# PreToolUse hook that blocks a Bash command from printing a secret value.
#
# Why a hook and not a rule: `SECURITY.md` can tell an agent never to log a
# token, but only the harness can stop it. This reads the PreToolUse event JSON
# on stdin and, for a command that would print a secret, prints a
# permissionDecision=deny object instead of running the command. Every other
# Bash command exits 0 and falls through to the normal permission flow.
#
# Allowed: existence and length checks such as ${#GITHUB_TOKEN}, and passing a
#          token to a tool as an auth header.
# Blocked:  echo/printf/cat/tee of a token value, environment dumps, and
#           curl -v/--verbose/--trace, which print the request headers.
#
# Reference: Claude Code hooks, https://code.claude.com/docs/en/hooks

set -uo pipefail

input="$(cat 2>/dev/null || true)"

# Extract the Bash command. Without jq, scan the raw event: enforcement still
# applies, just slightly more conservative.
if command -v jq >/dev/null 2>&1; then
  cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // ""' 2>/dev/null)"
else
  cmd="$input"
fi

[ -z "$cmd" ] && exit 0

deny() {
  # The reason is embedded in JSON, so it carries no double quotes or backslashes.
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$1"
  exit 0
}

# Variable names that hold a secret in a Flutter or CI context.
SECRETS='GITHUB_TOKEN|GH_TOKEN|GITLAB_TOKEN|FIREBASE_TOKEN|FIREBASE_API_KEY|FLUTTERFIRE_TOKEN|GCLOUD_SERVICE_KEY|SUPABASE_SERVICE_ROLE|OPENAI_API_KEY|ANTHROPIC_API_KEY|GEMINI_API_KEY|NPM_TOKEN|PUB_HOSTED_URL|DART_AUTH_TOKEN'

# Printing a value: an expansion inside a printer or a whole-environment dump.
if printf '%s' "$cmd" | grep -Eqi "(echo|printf|cat|tee|printenv|env|export|set)[[:space:]][^|;&]*\\\$\{?($SECRETS)([A-Za-z0-9_]*)?\}?"; then
  deny 'Blocked: this command prints a secret value. Report the presence and length instead, and pass the token to a tool as an auth header.'
fi

if printf '%s' "$cmd" | grep -Eqi '(^|[^-[:alnum:]])(env|printenv|export -p|set)[[:space:]]*($|[|;&])'; then
  deny 'Blocked: this command dumps the environment, which includes secrets. Print only the specific non-sensitive value you need.'
fi

# curl verbose modes print the Authorization header to stderr.
if printf '%s' "$cmd" | grep -Eqi 'curl[^|;&]*(-v|--verbose|--trace(-ascii|-ascii)?|--trace-config)'; then
  deny 'Blocked: curl verbose output prints request headers including Authorization. Remove the verbose flag.'
fi

# Debug/network tooling that echoes a full request, headers included.
if printf '%s' "$cmd" | grep -Eqi '(dart-define|--verbose)[[:space:]][^|;&]*\\\$\{?($SECRETS)'; then
  deny 'Blocked: this command passes a secret on the command line, where it lands in the process list and shell history.'
fi

exit 0