# Repository Maintenance Rules

- Before every commit and push, review `README.md` for GitHub-facing documentation impact.
- Every user-facing command, behavior, rule, profile, dependency, workflow, installation step, or release change must update `README.md` in the same commit.
- Update `CHANGELOG.md` for every released CLI version.
- Do not claim a commit or push is complete until the repository is clean and the README review is complete.

## Commit messages

Every commit message uses `[<ACTION>]: <message>`.

| Action | Use for |
| --- | --- |
| `[feat]` | a new command, flag, or profile |
| `[fix]` | a corrected behavior |
| `[refactor]` | code rearranged with no behavior change |
| `[docs]` | documentation only |
| `[test]` | new coverage |
| `[chore]` | maintenance, tooling, dependencies |

- One line. Name the outcome, not the activity: write `split cli into command-group files`, not `refactor cli.dart`.
- Keep unrelated changes in separate commits.
- Stage only the intended files. Never commit secrets, `graphify-out/`, or `.dart_tool/`.
