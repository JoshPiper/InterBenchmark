# Contributing to Internet's Benchmark Suite

## Purpose

This document exists to:
- Explain how commit and PR titles drive versioning and releases.
- Set out what CI gates a PR on.
- Save you rediscovering the local lint/test setup by trial and error.

---

## Conventional Commits

release-please reads commit messages to drive versioning, changelogs and
releases. PRs land squashed, so the **PR title** is the commit message that
ends up on `main` — it has to carry the prefix, whatever the commits inside
the branch look like.

Format: `<type>[optional scope]: <description>`

Types:

| Type | Effect |
|---|---|
| `fix:` | Patch release (`x.y.Z`), under *Bug Fixes* |
| `feat:` | Minor release (`x.Y.0`), under *Features* |
| `perf:` | Patch release, under *Performance Improvements* |
| `feat!:` or a `BREAKING CHANGE:` footer | Major release (`X.0.0`) |
| `chore:`, `build:`, `ci:`, `docs:`, `test:`, `refactor:`, `style:` | Kept out of the changelog; never raise the bump past a patch |

Examples:

```
fix: Fall back to sorted extremes when outlier bounds exclude all samples

feat: Add tag support to trials, with --tag/--skip-tag filtering

feat!: Add BENCH:ParseArgs shared flag-parsing helper for console commands

BREAKING CHANGE: console command callbacks now receive a parsed flag map
and positional list rather than the raw argument table.
```

If a PR mixes several logical changes, split the commits by type rather than
reaching for whichever tag sounds biggest. release-please aggregates every
commit into the changelog regardless, so there's no upside to lumping it all
under one `feat:` — and smaller commits review better besides.

---

## What CI actually gates

`ci.yml` runs, on every PR:
- [glualint](https://github.com/FPtje/GLuaFixer) over every `.lua` outside
  `templates/`, with the bundled `.glualint.json`. Warnings are errors there,
  so a style nit fails the build like a syntax error does.
- The packaging job (`build.yml`), which stages, stamps and packs both the
  full and `-minimal` `.gma` and `.zip`. It runs on PRs so gmad's path
  whitelist rejects a stray file in your branch rather than in a release.
- [GLuaTest](https://github.com/CFC-Servers/GLuaTest) against a real Garry's
  Mod server, running `lua/tests/internet_benchmark/`. The released
  gm_sysinfo module is installed into that server, so the environment
  integration is exercised against the real binary and not only the injected
  fakes.

All of it needs to pass. There's no merging around a red check. The same
workflow runs weekly on a schedule, because a new game build or runner image
can break the suite without a commit here changing.

---

## What you don't need to do

- Bump `BENCH.Version`. The `-- x-release-please-version` marker on that line
  in `lua/autorun/internet_benchmarks.lua` is release-please's; leave the line
  alone entirely.
- Touch `CHANGELOG.md` or `.release-please-manifest.json`.
- Create a tag, or set `BENCH.Build`. The packaging workflow stamps the commit
  hash into the staged copy — a working copy is *supposed* to report `dev`.

release-please does all of it off the merged titles once your PR's on `main`,
accumulating into a rolling release PR. Merging that is the whole release
checklist, and a maintainer does it when it's time to ship; see
[Releases and provenance](README.md#releases-and-provenance).

---

## Local setup

There's no build step — it's a pure Lua addon. Clone it into
`garrysmod/addons/` and it loads.

### Linting

Same invocation CI uses, from the repository root:

```bash
find lua -name '*.lua' -not -path '*/templates/*' -print0 | xargs -0 glualint lint
```

Templates under `lua/internet_benchmark/templates/` are HTML/CSS/JS carried in
`.lua` files so they ride the client download list. They aren't Lua, and both
the `find` above and `lint_ignoreFiles` exclude them; a new template needs no
extra wiring to stay excluded.

The config is deliberately quiet about shadowing and unused variables, and
strict about whitespace and beginner mistakes. `.editorconfig` covers the rest:
tabs, a final newline, no trailing whitespace.

### Running the tests

Suites live in `lua/tests/internet_benchmark/`, one file per area, each
returning a `{groupName = ..., cases = {...}}` table for GLuaTest. To run them
locally, clone GLuaTest into `addons/` alongside this addon and start a server
with `gluatest_enable 1`.

They run **serverside**, so the client-only trials (`draw_rect`,
`set_draw_color`) are covered only to the extent that they are correctly
skipped; verifying their timings still needs a manual client-side run.

### Trying a change in-game

```
internet_benchmark_trial for_loops --test    # one trial, 10 iterations x 2 runs
internet_benchmark_run --test                # the full pipeline, report included
```

`--test` exists so you don't wait several minutes of real measuring to find out
whether the report renders. Drop it once you want numbers you'd publish.

---

## Code style

- Tabs, per `.editorconfig`. Double quotes for strings, matching everything
  already here.
- New files under `lua/internet_benchmark/` are named for the realm they load
  in (`sh_`, `sv_`, `cl_`) and need adding to the include list at the bottom of
  `lua/autorun/internet_benchmarks.lua`. Only `trials/` and `templates/` are
  walked automatically; nothing else is discovered by being on disk.
- Public functions carry LuaLS annotations (`--- @param`, `--- @return`), and a
  `---` summary line above them is welcome. Inline comments are not: never one
  that restates what the code already says. A comment earns its place when it
  captures a non-obvious *why* — a LuaJIT or Garry's Mod constraint, a
  workaround, a decision that reads like a mistake without it. `BENCH:Yield`
  and `TEMPLATE:Replace` are the shape to copy.
- Every feature ships with tests, and a bug fix ships with the case that
  reproduces it — the point of the suite is that a regression can't pass
  quietly.
- New trials go in `lua/internet_benchmark/trials/`, are discovered
  automatically, take a unique `:Order(n)`, and carry `:Tag("default")` if they
  belong to the shipped set. An environment gate (`:If(...)`) goes in a
  `<trial>.meta.lua` sidecar, which loads first — so the trial file itself may
  reference things that only exist where it runs. See
  [Writing trials](README.md#writing-trials).
- A benchmarked function has its source and captured upvalues read back for the
  report, so keep it a named local in the trial file. Anything that won't
  serialise — tables, entities — gets `:Exclude`d and covered by a
  `:ManualPredefine` line range instead; the suite warns when a capture needs
  it.
