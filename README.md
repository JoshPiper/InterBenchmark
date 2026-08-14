# Internet's Benchmark Suite

[![CI](https://github.com/JoshPiper/InterBenchmark/actions/workflows/ci.yml/badge.svg)](https://github.com/JoshPiper/InterBenchmark/actions/workflows/ci.yml)

A benchmarking suite for Garry's Mod Lua, built to put numbers behind (or against)
the performance folklore that circulates in the GLua community: "always localise
your globals", "never use `table.insert`", "`DrawRect` is faster than `RoundedBox`",
and friends.

Each claim lives in a small, self-contained **trial** comparing two or more
implementations. The suite runs every trial under controlled conditions and
produces a single self-contained HTML report — an overview, an environment
statement and a page per trial with summary statistics, box-and-whisker plots,
and the exact source code that was measured.

## Installation

Grab the latest packaged build from the
[releases page](https://github.com/JoshPiper/InterBenchmark/releases): drop the
`.gma` into your `garrysmod/addons` directory as-is, or extract the `.zip`
there (it unpacks to `addons/internet_benchmark/`). Release artifacts carry
signed build provenance — see
[Releases and provenance](#releases-and-provenance) to verify one.

Alternatively, clone (or extract) the repository into `garrysmod/addons`:

```bash
git clone https://github.com/JoshPiper/InterBenchmark.git
```

The suite loads on both the server and the client.

## Usage

| Command | Effect |
| --- | --- |
| `internet_benchmark_run [--dynamic] [--test] [--tag=...] [--skip-tag=...]` | Benchmark every trial and write the HTML report. |
| `internet_benchmark_trial <name> [--dynamic] [--test]` | Benchmark a single trial and print results to the console (autocompletes the name). |
| `internet_benchmark_environment` | Print the environment statement. |
| `internet_benchmark_logging_report` | Explain the logging levels and the current configuration. |

Run them from the server console, or from the client console (`F10` / tilde) to
benchmark the client realm — rendering trials such as `draw_rect` only run there.
On dedicated servers, benchmark commands are restricted to the server console and
superadmins.

Pass `--dynamic` to either command to recalibrate each trial's iteration count
from a live probe instead of using its fixed default — see
[Dynamic iteration calibration](#dynamic-iteration-calibration) below.

Pass `--test` to either command to force a low, fixed iteration and run count
(`BENCH.TestIterations` / `BENCH.TestRuns`, 10 iterations × 2 runs by default)
instead of a trial's authored, default, or dynamically calibrated counts —
useful for quickly smoke-testing a trial or the full report pipeline without
waiting for a real run. `--dynamic` and `--test` are mutually exclusive;
passing both together is rejected with a warning and nothing runs.

Pass `--tag=name` and `--skip-tag=name` to `internet_benchmark_run` to filter
which trials run, with the same precedence
[Ansible](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_tags.html)
gives its own `--tags`/`--skip-tags`: with no `--tag`, every trial not excluded
by `--skip-tag` runs; with `--tag`, only trials carrying at least one of the
given tags run; `--skip-tag` always wins, excluding a trial even if it also
matches `--tag`. Either flag accepts a comma-separated list, and either can be
repeated. Every trial shipped with the suite is tagged `default`, so
`internet_benchmark_run --tag=default` runs just the built-ins, excluding any
you add of your own.

Benchmarks run in the background on a small per-tick time budget, so the game
stays responsive while a full suite (several minutes of measuring) grinds away.
Progress is logged as it goes; the `internet_benchmark_logging_level` convar
(default `20`, INFO) controls how chatty that is.

### Output

On the client, `internet_benchmark_run` also opens the finished report directly
in an in-game panel — no file access needed. The report is written to
`garrysmod/data/internet_benchmarks/` either way:

| File | Content |
| --- | --- |
| `report.html.txt` | The report itself — a single, self-contained file (its stylesheet and script are inlined; no CDN dependencies). |
| `results.json` | The same per-trial statistics, as machine-readable JSON, plus the environment statement. |
| `environment.txt` | The environment statement for this run. |

Garry's Mod can only write a limited set of file extensions, so the HTML report
gets a `.txt` suffix (`.json` is written directly). To view it outside the game,
rename `report.html.txt` → `report.html` and open it in a browser. It has an
Overview, an Environment page
and one page per trial, navigable from the sidebar, and a light/dark theme
toggle.

## Methodology

For every trial, the suite:

1. **Loads** the trial's meta file first (if present). A meta file can gate the
   trial with `TRIAL:If(...)` — this is how client-only rendering trials and
   gamemode-specific trials skip environments where they cannot run.
2. **Snapshots sources** before anything executes: each benchmarked function's
   source is read from disk, and its captured upvalues are serialised, so the
   report shows the code and values exactly as they were measured — not whatever
   state the runs left behind.
3. **Warms up** every function with a quarter-scale pass (¼ of the runs, ¼ of the
   iterations), giving LuaJIT a chance to compile hot traces before measurement.
4. **Controls the garbage collector**: two full collections, then the collector is
   stopped for the duration of the trial. A full manual collection runs before and
   after every timed run, so allocation garbage from one run cannot bill the next.
5. **Times each run** with `SysTime()` around a tight loop of `iterations` calls
   (default: 100 runs × 100,000 iterations per function). `Before`/`After` hooks
   run outside the timed window. The runner yields around each run's garbage
   collections and its measurement so the game keeps ticking, even when a full
   collection against a large live heap takes a while.
6. **Computes statistics** per function: mean, median, quartiles (rank-averaged),
   IQR, population standard deviation, and a per-call average (mean ÷ iterations).
   Outliers beyond 1.5 × IQR are excluded from the reported minimum/maximum and
   drawn separately; the mean deliberately still includes them. Percentages
   compare each mean against the fastest function in the trial.

### Dynamic iteration calibration

By default, every trial runs its authored iteration count (100,000 unless the
trial sets its own). That fixed number can be badly wrong in either direction:
too small for an already-cheap function to produce a run duration that rises
meaningfully above clock-resolution and scheduler noise, or far larger than
necessary for a function where 100,000 iterations already takes a long time.

Passing `--dynamic` to `internet_benchmark_run` or `internet_benchmark_trial`
recalibrates every trial's iteration count from a live probe instead: each
function is timed at a doubling sequence of iteration counts (100, 200, 400,
…) until a run reaches a target duration (`BENCH.DynamicTargetDuration`,
0.05s by default), then that probe is extrapolated back to an exact
target-duration estimate.

Every function within a trial still shares one iteration count — otherwise the
raw per-run numbers in the Results table (median/min/max/mean) would no longer
be comparable across functions, since they'd represent different amounts of
work. The shared count is driven by whichever function in the trial is
**fastest**, since that's the one that needs the most iterations to reach the
target; slower functions in the same trial then run for longer than their own
individual minimum would require. That's an intentional trade-off: it keeps
the comparison meaningful at the cost of some wasted time on the slower
functions.

**This is an accuracy and consistency feature, not a speed one.** Most of this
suite's trials benchmark genuinely tiny operations that already clear a
reasonable resolution bar in well under 100,000 iterations — calibrating
toward a real target duration is as likely to *increase* total run time for
those trials as it is to decrease it. If your actual goal is a faster full
suite run, `internet_benchmark_trial <name>` against just the trials you care
about will get there faster than either mode of `internet_benchmark_run`.

### Caveats

These are microbenchmarks, with everything that implies. Results are specific to
the machine, the game build, and whatever else the process was doing; treat them
as *comparative* (A vs B on this box), never as absolute costs. Function-call
overhead dominates tiny bodies, and LuaJIT may compile competing forms into very
different (or occasionally identical) traces. Rendering trials execute outside a
real render hook, so they measure call overhead rather than true draw cost. When
a claim matters to you, benchmark it in your own context.

## Environment statement

Every report ships with an `environment.txt` stating the conditions it was
generated under. **Plain GLua** can provide, and the suite records:

| Field | Source |
| --- | --- |
| Suite version | `INTERNET_BENCHMARK.Version` |
| Suite build | `INTERNET_BENCHMARK.Build` |
| Timestamp (UTC) | `os.date` |
| Realm (server/client) | `SERVER` / `CLIENT` |
| Hosting (dedicated/listen/singleplayer) | `game.IsDedicated`, `game.SinglePlayer` |
| OS family | `system.IsWindows` / `IsLinux` / `IsOSX` |
| Game branch | `BRANCH` |
| Game version | `VERSION`, `VERSIONSTR` |
| Lua runtime | `jit.version` |
| Architecture | `jit.os`, `jit.arch` |
| JIT compiler state | `jit.status` |
| Map | `game.GetMap` |
| Tick interval / tickrate | `engine.TickInterval` |
| Player count | `player.GetCount` |

Packaged builds stamp `Build` with the short commit hash they were created
from, so a published report names the exact code that was measured. Working
copies — a git clone, or the repository mounted in CI — report `dev`, since
plain GLua cannot see the checkout's actual commit.

The following **cannot** be read from plain GLua, and needs a binary module
(a `require()`-able DLL/SO in `lua/bin`, using OS APIs) or manual recording
alongside the report:

- CPU model, core count, clock speed and thermal/boost state.
- Total and available system memory.
- GPU model and driver version.
- Precise OS version and kernel, beyond the OS family.
- Load from other processes on the machine.

No binary module ships with this suite, but if the optional
[gm_sysinfo](https://github.com/JoshPiper/gm_sysinfo) module (3.1.0+) is
installed for the running realm, the suite detects it automatically and
extends the statement with the precise OS version, kernel, distribution, CPU
model and architecture, physical core count, memory and swap totals,
1/5/15-minute load averages and host uptime. The host name is deliberately
never collected, since these statements are meant to be published.

Even with the module, the **CPU clock speed** (not yet exposed by gm_sysinfo)
and the **GPU** still need noting by hand next to `environment.txt` when you
publish results.

## Writing trials

Trials live in `lua/internet_benchmark/trials/`. Each trial is a Lua file which
receives a fresh builder as the `TRIAL` global:

```lua
local tab = {1, 2, 3}

local function viaLength(times)
	tab[#tab + 1] = times
end

local function viaInsert(times)
	table.insert(tab, times)
end

TRIAL
	:Name("My Trial")
	:Order(50)
	:Tag("default")
	:Function(viaLength)
	:Label("tab[#tab + 1]")
	:Function(viaInsert)
	:Label("table.insert")
	:Before(function() tab = {1, 2, 3} end)
	:ManualPredefine(1, 1)
	:Exclude("tab")
```

| Method | Purpose |
| --- | --- |
| `:Name(name)` | Display name in the report. |
| `:Order(n)` | Tab position (unique per trial; omit the argument to auto-number). |
| `:Function(fn)` | Add an implementation to measure. It receives the iteration index. |
| `:Label(text)` | Label the most recently added function. |
| `:Runs(n)` / `:Iterations(n)` | Override the 100 × 100,000 defaults. |
| `:Before(fn)` / `:After(fn)` | Hooks around every timed run (outside the timing). |
| `:If(boolOrFn)` | Gate the trial (meta files only — see below). |
| `:Tag(...)` | Tag the trial for `--tag`/`--skip-tag` filtering (see [Usage](#usage)). Accepts one or more names. |
| `:Exclude(name)` | Hide a captured upvalue from the report's pre-definitions. |
| `:ManualPredefine(first, last)` | Show these lines of the trial file as pre-definitions instead. |

Captured upvalues are serialised automatically where possible (globals resolve to
their names, locals defined in the file embed their source, plain values print as
literals). Tables, entities and other unserialisable values should be `:Exclude`d
and covered with a `:ManualPredefine` line range instead — the suite warns when a
capture needs this.

A sidecar meta file, `<trial>.meta.lua`, is included *before* the trial file and
is the place for `:If(...)` gates. Because the gate runs first, the trial file
itself may safely reference things that only exist in its intended environment —
see `draw_rect.meta.lua` (client-only) and `ns_accessors.meta.lua`
(gamemode-specific).

## Development

Testing runs in two tiers, both in CI on every push and pull request:

| Tier | Location | Runs | Covers |
| --- | --- | --- | --- |
| Unit | `tests/` | `luajit tests/run.lua` | Statistics and formatting maths, under stock LuaJIT via a small GMod shim. Fast, no game needed. |
| Integration | `lua/tests/internet_benchmark/` | [GLuaTest](https://github.com/CFC-Servers/GLuaTest), in a real GMod server | Trial discovery and realm gating, source introspection, the timing loop, the background job pump, report rendering, file output, and the console commands. |

To run the integration tier locally, clone GLuaTest into `addons/` alongside this
addon and start a server with `gluatest_enable 1`. In CI it runs automatically in
a containerised server via GLuaTest's reusable workflow, which also installs the
released, checksum-pinned gm_sysinfo module so the environment integration is
exercised against the real binary as well as injected fakes.

Integration tests run **serverside**, so the client-only trials (`draw_rect`,
`set_draw_color`) are covered only to the extent that they are correctly skipped;
verifying their timings still needs a manual client-side run.

**Linting**: [glualint](https://github.com/FPtje/GLuaFixer) with the bundled
`.glualint.json`. Templates under `lua/internet_benchmark/templates/` are
HTML/CSS/JS carried in `.lua` files (so they ride the client download list) and
are excluded from linting.

## Releases and provenance

Releases are automated with
[release-please](https://github.com/googleapis/release-please). Commits follow
[Conventional Commits](https://www.conventionalcommits.org); `feat:` and
`fix:` commits on `main` accumulate into a rolling release PR that carries the
next version number and changelog. Merging that PR is the entire release
checklist: it tags the release, packages the `.gma` and `.zip`, checksums them
into a `SHA256SUMS` file, and attaches everything to the GitHub release —
which stays a draft until its assets are in place, so a release is never
visible half-published.

Every artifact also carries signed
[SLSA build provenance](https://docs.github.com/en/actions/security-for-github-actions/using-artifact-attestations):
cryptographic proof of which workflow, commit and runner produced it. To
verify a download:

```bash
gh attestation verify internet_benchmark-2.0.0.gma -R JoshPiper/InterBenchmark
```

Inside the artifact, the environment statement's `Suite Build` row carries the
same commit, closing the loop from a published benchmark report back to the
exact source that produced its numbers.

## Licence

[MIT](LICENSE).
