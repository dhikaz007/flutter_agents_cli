# Repository Maintenance Rules

- Before every commit and push, review `README.md` for GitHub-facing documentation impact.
- Every user-facing command, behavior, rule, profile, dependency, workflow, installation step, or release change must update `README.md` in the same commit.
- Update `CHANGELOG.md` for every released CLI version.
- Do not claim a commit or push is complete until the repository is clean and the README review is complete.

## Commit messages

Format `[<ACTION>]: <subject>`. The subject is at most 72 characters and ends without a period.

| Action | Use for |
| --- | --- |
| `[feat]` | a new command, flag, or profile |
| `[fix]` | a corrected behavior |
| `[refactor]` | code rearranged with no behavior change |
| `[docs]` | documentation only |
| `[test]` | new coverage |
| `[chore]` | maintenance, tooling, dependencies |

- Body is optional and at most 3 lines. It answers why, never what.
- Never restate the changed-file list. Never cite how many tests passed.
- If the diff already reads clearly on its own, write the subject alone.
- Keep unrelated changes in separate commits.
- Stage only the intended files. Never commit secrets, `graphify-out/`, or `.dart_tool/`.
