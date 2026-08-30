# Benchmark harness

Runs Internet's Benchmark Suite on a headless Garry's Mod server in docker and
collects the generated report — a full run, a tag-filtered group, or a single
trial. Requires Node 24 and docker.

```bash
node tools/benchmark/harness.js --mode=trial --trial=modulo --iterations=test
```

## How it works

The harness reuses [GLuaTest](https://github.com/CFC-Servers/GLuaTest)'s runner
image and entrypoint, which is the same server the `ingame` CI job tests
against. Rather than pointing it at a test suite, the harness:

1. **Stages** the addon into an overlay of `garrysmod/`, exactly as GLuaTest's
   workflow does, alongside a second addon holding the in-game fixture
   (`fixture/`) and its generated config. The suite's own `lua/tests/` are left
   out, as they are in a packaged release.
2. **Turns GLuaTest's own suite off** in the appended server config. Its fixture
   closes the server as soon as tests finish, which would cut a benchmark short,
   so the fixture also removes that hook as a second line of defence.
3. **Runs the container** with the mounts and environment its compose file
   expects, so the entrypoint boots srcds exactly as it does for tests.
4. **Waits** while the fixture runs the benchmark on the suite's own background
   job pump, watched by a deadline that expires before the container's timeout.
   On the way out the fixture writes GLuaTest's clean-exit sentinel and calls
   `engine.CloseServer()`, so the entrypoint's own success check still applies.
5. **Collects** `report.html`, `results.json` and `environment.txt` out of the
   stopped container, along with the server log and any crash log, and writes a
   markdown summary.

Single-trial runs narrow trial discovery rather than filtering by tag, because
the report pipeline filters by tag and there is no per-trial tag to select.

## Output

Everything lands in `--output` (default `benchmark-output/`):

| File | Content |
| --- | --- |
| `report.html` | The report, renamed from the `.html.txt` the game must write. |
| `results.json` | Per-trial statistics and the environment statement. |
| `environment.txt` | The environment statement on its own. |
| `summary.md` | A markdown digest, also appended to the job summary in CI. |
| `server.log` | The server's console output, with colour codes stripped. |
| `debug.log` | Present only when the server crashed. |

The harness fails on a crash, a stalled run, or a run that produced no report.
It never fails on a *result*: numbers from a shared CI runner say nothing
reliable about how two candidates compare on real hardware, so nothing here
gates on them.

## Options

Run `node tools/benchmark/harness.js --help`. The ones worth knowing:

| Flag | Effect |
| --- | --- |
| `--mode=all\|tag\|trial` | Everything, a tag-filtered group, or one trial. |
| `--trial=<name>` | The trial to run, for `--mode=trial`. |
| `--tag`/`--skip-tag` | Tag filters, repeatable and comma-separated, as in-game. |
| `--iterations=default\|dynamic\|test` | Authored counts, live calibration, or a fast smoke run. |
| `--branch=live\|x86-64\|dev\|prerelease` | Picks the matching runner image. |
| `--timeout=<minutes>` | Hard limit on the server's lifetime. Default 30. |
| `--override=<dir>` | Extra files to merge over `garrysmod/` — how CI adds gm_sysinfo. |

A full run measures every trial at its authored counts and takes far longer
than the 30 minute default allows; `--iterations=test` exercises the whole
pipeline in a couple of minutes, and is the right way to check a change to the
harness itself.

## Publishing

`site.js` turns a bundle into a publishable site by writing `index.html` beside
the report:

```bash
node tools/benchmark/site.js --bundle=benchmark-output
```

The page exists to frame the numbers, because a report served from a URL
invites being read as authoritative when it is nothing of the sort. It leads
with that disclaimer, before any figure, and names the trials the run could not
measure — read back from the server's own log rather than a hard-coded list, so
the note cannot drift as trials are added. Note the log records *that* a trial
gated off, never why, so the page lists them without attributing a cause.

`.github/workflows/pages.yml` runs the harness at the trials' authored counts,
builds that page, and commits the four files into `reports/` on the `gh-pages`
branch. It touches nothing else on that branch: a docs publisher can own the
root without either side having to re-own the other's files, which an
artifact-based Pages deployment — a full site replacement every time — cannot
do.

## In CI

`.github/workflows/benchmark.yml` exposes the same choices as
`workflow_dispatch` inputs and uploads the output directory as an artifact.
This harness's own tests (`node --test`) run there before the container starts,
and on every push and pull request via the `harness` job in `ci.yml`.
