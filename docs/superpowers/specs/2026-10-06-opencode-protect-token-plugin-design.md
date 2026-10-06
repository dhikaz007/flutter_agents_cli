# Opencode Protect-Token Plugin Design

Date: 2026-10-06
Status: approved in chat, pending written review

## Goal

Replace the Claude Code `PreToolUse` hook with an opencode plugin that enforces the
same secret-printing rules, and extend coverage to reading `.env` files.

The generated project currently ships:

```
.claude/settings.json              # wires the hook, matcher "Bash"
tool/hooks/protect-token.sh        # the hook body
```

`RuleGenerator._desiredFiles` copies every file under `templates/base/` recursively,
so both land in a project that runs opencode. opencode never reads
`.claude/settings.json`, so the hook is dead weight there: enforcement falls back to
prose in `docs/rules/SECURITY.md`.

opencode loads plugins automatically from `.opencode/plugins/`, which needs no
registration file. The plugin is the single enforcement point.

## Non-goals

- Not a harness-selection flag. `agents init` gains no `--harness` option; there is
  exactly one target harness, opencode. A Claude Code user who wants enforcement
  wires it by hand.
- Not a sandbox. Only Bash command inspection and `.env` reads are covered.
- No `fetch`/`webfetch` Authorization-header inspection.
- No blocking of `write`/`edit` on `.env`. An agent cannot copy `.env` somewhere more
  readable without reading it first, and reads are already closed.

## File changes

Add:

```
templates/base/.opencode/plugins/protect-token.js
```

No Dart change. `_desiredFiles` (`lib/src/generator.dart:131`) walks `templates/base/`
with `listSync(recursive: true)` and already copies `.claude/`, so a dot-directory is
copied the same way.

Delete:

```
templates/base/.claude/settings.json
templates/base/tool/hooks/protect-token.sh
```

`tool/hooks/` then holds nothing, and `_deleteEmptyManagedDirectories`
(`lib/src/generator.dart:109`) removes the empty path in the project.

## Migration of an already-generated project

No migration command and no manual step. On the next `agents init`:

1. `_desiredFiles` no longer returns `.claude/settings.json` or
   `tool/hooks/protect-token.sh`.
2. The delete pass (`lib/src/generator.dart:42-55`) sees both paths in the previous
   manifest but absent from `desired`, then deletes each one and records it under
   `report.deleted` — but only when the file on disk is unchanged or `--force` is
   given.
3. An edited copy is preserved and reported under `report.preservedModified`.

Both paths are CLI-owned, so in practice both are deleted. A user who edited
`.claude/settings.json` keeps it and no hook runs: the file has no other reader.

## Plugin behaviour

Shape, from the opencode plugin documentation:

```js
export const ProtectToken = async () => {
  return {
    "tool.execute.before": async (input, output) => { /* ... */ },
  }
}
```

`SECRETS` is one pipe-joined alternation, the same 13 names the bash hook used:

```
GITHUB_TOKEN|GH_TOKEN|GITLAB_TOKEN|FIREBASE_TOKEN|FIREBASE_API_KEY|FLUTTERFIRE_TOKEN|GCLOUD_SERVICE_KEY|SUPABASE_SERVICE_ROLE|OPENAI_API_KEY|ANTHROPIC_API_KEY|GEMINI_API_KEY|NPM_TOKEN|PUB_HOSTED_URL|DART_AUTH_TOKEN
```

In the plugin this is a single string, as in the bash hook.

Rules 1 through 4 are ported verbatim from the bash hook, same order, same
case-insensitive matching:

1. A printer (`echo`, `printf`, `cat`, `tee`, `printenv`, `env`, `export`, `set`)
   expanding a name from `SECRETS`. Denied.
2. A whole-environment dump: `env`, `printenv`, `export -p`, `set` with no argument.
   Denied.
3. `curl` with `-v`, `--verbose`, `--trace`, `--trace-ascii`, `--trace-config`. Denied.
4. `--dart-define` or `--verbose` on the same line as a `SECRETS` expansion. Denied.

Rule 5 is new: tool `read`, where `output.args.filePath` has basename `.env` or starts
with `.env.`, except `.env.example`, `.env.sample`, `.env.template`, and
`.env.defaults`. Those four are committed to the repository and are how an agent
learns the variable names; blocking them only makes it guess.

The two arguments read from opencode are pinned here because they are an external
contract, not a choice: `output.args.command` for `bash`, `output.args.filePath` for
`read`. A change in opencode renames them, and the tests fail rather than the plugin
silently allowing everything.

Still allowed, as before: reporting a secret's length (`echo ${#GITHUB_TOKEN}`) and
passing a token to a tool as an auth header (`curl -H "Authorization: Bearer
$GITHUB_TOKEN"`).

### How a denial reaches the agent

`tool.execute.before` denies by `throw new Error(reason)`. opencode surfaces that as
a tool error and the agent continues with an alternative command. The prompt is not
interrupted and no dialog reaches the user — the same observable behaviour as the
Claude Code `permissionDecision: "deny"`, reached by a different mechanism.

The reason strings are carried over from the bash hook so `SECURITY.md` and
`AGENTS.md` can keep describing the denial the same way.

## Testing

`test/protect_token_hook_test.dart` is renamed to `test/protect_token_plugin_test.dart`,
since it no longer tests a shell hook. Its five existing cases are kept, with the
runner switched from `bash` to `node`:

- a print of a secret is denied
- a whole-environment dump is denied
- `curl -v` is denied
- length reporting and auth headers pass
- an ordinary command falls through

Plus one new case: `read` on `.env` is denied, while `read` on `.env.example` and on
`lib/firebase_options.dart` passes.

### Why the temp directory needs a package.json

opencode loads the plugin through bun, but the test runs `node`. Node decides whether
a `.js` file is CommonJS or ESM from the nearest `package.json`; with none, it treats
the file as CommonJS and fails to parse `export`. `setUpAll` therefore writes
`{"type":"module"}` into the temp directory next to the copied plugin.

### Runner

One `node --input-type=module -e "<inline>"` per case, with `cwd` set to the temp
directory. The inline script imports the plugin from a path passed in `argv`, calls
`tool.execute.before` with a synthetic `{ tool, args }`, and prints `DENY:<reason>` or
`OK`. Dart asserts on that line.

`node` rather than `bun`: opencode loads the plugin under bun, but the plugin calls no
opencode API — it reads `input.tool` and `output.args` — so the logic is identical
under both runtimes, and `node` is likelier to exist on a CI machine.

## Documentation

Every user-facing change lands in the same commit, per the repository rules.

| File | Change |
| --- | --- |
| `README.md`, "Secret handling hook" | Rewrite: Claude Code hook becomes an opencode plugin, add the `.env` rule, delete the note about a project that owns `.claude/settings.json`. |
| `templates/base/AGENTS.md:104` | Rewrite the hook reference. |
| `templates/base/docs/rules/SECURITY.md:6` | Same. |
| `CHANGELOG.md` | Two `## Unreleased` entries: remove the bash hook and `.claude/settings.json`, add the opencode plugin. |

## Residual gaps

Stated so they are not mistaken for coverage:

- Matcher coverage is `bash` and `read` only. `write`, `edit`, `grep`, and `fetch` can
  still reach a `.env` path or a token that reached the context another way.
- A project that already edited its own `.claude/settings.json` keeps the file after
  migration, and nothing reads it.
- The plugin governs opencode only. The rules in `SECURITY.md` remain the portable
  statement of the same policy for any other agent.
