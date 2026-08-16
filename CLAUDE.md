# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Pull Requests

PR titles must start with their conventional commit prefix
(e.g. `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`, `ci:`).

## Testing

- When fixing a bug, add a test case that reproduces it, so it can't
  silently regress in the future.
- When adding a new feature, following TDD may help, but at minimum every
  feature must ship with a comprehensive test suite covering its behavior.

## Comments

Default to writing no comments. Only add one when the *why* is non-obvious —
a hidden constraint, a subtle invariant, a workaround for a specific engine
quirk, or behavior that would surprise a reader. Never add a comment that
just restates what the code already says (e.g. `-- set x to 1` above
`x = 1`, or `--- Does the thing` above a function named `DoThing`).

Do not add comments that:
- Narrate the current task, fix, or PR ("added for the reporting feature",
  "fixes issue with templating").
- Describe *what* a line does when the identifiers already make it obvious.
- Mark removed/changed code (`-- removed`, `-- old: ...`).
- Restate a function's name/signature in prose.

If removing a comment wouldn't confuse a future reader, don't write it.

When a comment is warranted, keep it to a single short line. Never write
multi-line or multi-paragraph comment blocks, and never write a docstring
that walks through parameters, return values, or examples in prose — one
line max.
