import { summariseTrial } from "./summary.js";

const GATED = /Trial '([^']+)' is gated off in this environment/g;

const ENVIRONMENT_KEYS = [
	"Suite Version",
	"Suite Build",
	"Generated",
	"Game Branch",
	"Game Version",
	"Lua Runtime",
	"Architecture",
	"Operating System",
	"Kernel",
	"CPU Model",
	"Physical Cores",
	"Total Memory",
	"Map"
];

export function escapeHtml(value) {
	return String(value)
		.replace(/&/g, "&amp;")
		.replace(/</g, "&lt;")
		.replace(/>/g, "&gt;")
		.replace(/"/g, "&quot;");
}

/**
 * The trials the server refused to run, named from its own log.
 * Reading them back beats hard-coding a list of client-only trials, which
 * would drift the moment one is added. The line is logged at INFO, so a
 * quieter run simply reports none.
 * @param {string} log The server log.
 * @returns {string[]} Sorted, de-duplicated trial names.
 */
export function gatedTrials(log) {
	const names = new Set();
	for (const [, name] of log.matchAll(GATED)) {
		names.add(name);
	}

	return [...names].sort();
}

function rows(trials) {
	return trials.map((trial) => `
					<tr>
						<td>${escapeHtml(trial.name)}</td>
						<td class="n">${trial.candidates}</td>
						<td>${escapeHtml(trial.fastest)}</td>
						<td class="n">${escapeHtml(trial.perCall)}</td>
						<td class="n">${escapeHtml(trial.spread)}</td>
					</tr>`).join("");
}

function environmentRows(environment) {
	return ENVIRONMENT_KEYS
		.filter((key) => environment[key] !== undefined)
		.map((key) => `
					<div class="env-row"><dt>${escapeHtml(key)}</dt><dd>${escapeHtml(environment[key])}</dd></div>`)
		.join("");
}

function gatedNote(gated) {
	if (gated.length === 0) {
		return "";
	}

	const names = gated.map((name) => `<code>${escapeHtml(name)}</code>`).join(", ");
	// The log records that a trial gated off, never why, so the note lists them
	// without attributing one cause to all of them.
	return `
			<p class="note"><strong>${gated.length} trial${gated.length === 1 ? " was" : "s were"} not measured here.</strong>
			A trial can gate itself on the environment it needs — a realm, a gamemode, a particular engine
			build — and ${gated.length === 1 ? "this one" : "these"} opted out of this one: ${names}.
			Note that this report comes from a dedicated server, which has no client realm at all, so
			rendering trials can only ever be timed by running the suite from a client console.</p>`;
}

function provenance(meta) {
	if (!meta.repository || !meta.commit) {
		return "";
	}

	const short = meta.commit.slice(0, 7);
	const commit = `<a href="https://github.com/${escapeHtml(meta.repository)}/commit/${escapeHtml(meta.commit)}"><code>${escapeHtml(short)}</code></a>`;
	const run = meta.runId
		? ` by <a href="https://github.com/${escapeHtml(meta.repository)}/actions/runs/${escapeHtml(meta.runId)}">run ${escapeHtml(meta.runId)}</a>`
		: "";

	return `
			<p class="provenance">Built from ${commit}${run}.</p>`;
}

/**
 * Render the landing page that frames the published report.
 * @param {object} input
 * @param {object} input.results The parsed results.json.
 * @param {string} input.log The server log, for the gated-trial note.
 * @param {object} input.meta {repository, commit, runId}.
 * @returns {string} A self-contained HTML page.
 */
export function renderSite({results, log = "", meta = {}}) {
	const trials = (results.trials ?? []).map(summariseTrial);
	const candidates = trials.reduce((total, trial) => total + trial.candidates, 0);
	const environment = results.environment ?? {};
	const generated = environment.Generated ? `${escapeHtml(environment.Generated)}` : "an earlier run";

	return `<!doctype html>
<html lang="en">
	<head>
		<meta charset="utf-8">
		<meta name="viewport" content="width=device-width, initial-scale=1">
		<title>Internet's Benchmark Suite — CI reference report</title>
		<style>
			:root {
				color-scheme: light dark;
				--bg: #fbfbfd; --fg: #1c1c1f; --muted: #5c5c66; --line: #dcdce4;
				--card: #ffffff; --warn-bg: #fff5e6; --warn-line: #d99a2b; --warn-fg: #6b4508;
			}
			@media (prefers-color-scheme: dark) {
				:root {
					--bg: #131316; --fg: #e8e8ec; --muted: #9a9aa6; --line: #2c2c34;
					--card: #1b1b20; --warn-bg: #2c2313; --warn-line: #a8791f; --warn-fg: #f0cd8d;
				}
			}
			* { box-sizing: border-box; }
			body {
				margin: 0; padding: 2.5rem 1.25rem 4rem; background: var(--bg); color: var(--fg);
				font: 16px/1.6 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
			}
			main { max-width: 60rem; margin: 0 auto; }
			h1 { font-size: 1.75rem; margin: 0 0 .35rem; letter-spacing: -.02em; }
			h2 { font-size: 1.1rem; margin: 2.5rem 0 .75rem; letter-spacing: -.01em; }
			.lede { color: var(--muted); margin: 0 0 2rem; }
			.warning {
				background: var(--warn-bg); border: 1px solid var(--warn-line); border-left-width: 4px;
				border-radius: 6px; padding: 1rem 1.15rem; margin: 0 0 1.5rem; color: var(--warn-fg);
			}
			.warning p { margin: 0; }
			.warning p + p { margin-top: .6rem; }
			.note { color: var(--muted); font-size: .925rem; }
			.links { display: flex; flex-wrap: wrap; gap: .6rem; padding: 0; margin: 0 0 1rem; list-style: none; }
			.links a {
				display: block; padding: .55rem .9rem; background: var(--card); border: 1px solid var(--line);
				border-radius: 6px; text-decoration: none; color: inherit; font-weight: 500;
			}
			.links a:hover { border-color: var(--muted); }
			.links span { display: block; font-weight: 400; font-size: .8rem; color: var(--muted); }
			.scroll { overflow-x: auto; }
			table { border-collapse: collapse; width: 100%; font-size: .925rem; }
			th, td { text-align: left; padding: .5rem .7rem; border-bottom: 1px solid var(--line); white-space: nowrap; }
			th { font-size: .75rem; text-transform: uppercase; letter-spacing: .06em; color: var(--muted); }
			td.n, th.n { text-align: right; font-variant-numeric: tabular-nums; }
			dl.env { display: grid; grid-template-columns: repeat(auto-fill, minmax(15rem, 1fr)); gap: .1rem 1.5rem; margin: 0; }
			.env-row { display: flex; justify-content: space-between; gap: 1rem; padding: .35rem 0; border-bottom: 1px solid var(--line); }
			dt { color: var(--muted); font-size: .875rem; }
			dd { margin: 0; font-size: .875rem; text-align: right; font-variant-numeric: tabular-nums; }
			.provenance, footer { color: var(--muted); font-size: .875rem; }
			footer { margin-top: 3rem; padding-top: 1.25rem; border-top: 1px solid var(--line); }
			a { color: inherit; }
			code { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: .9em; }
		</style>
	</head>
	<body>
		<main>
			<h1>Internet's Benchmark Suite</h1>
			<p class="lede">An automated reference run, measured ${generated}.</p>

			<div class="warning">
				<p><strong>These are not authoritative numbers.</strong> This report is produced on a shared
				GitHub Actions runner — a virtual machine with neighbours, unpredictable clock speed and
				thermal behaviour. Timings here are only meaningful <em>relative to each other within this
				one run</em>.</p>
				<p>Do not compare them against another run of this page, against your own machine, or against
				any absolute figure. To learn how these candidates behave on hardware you care about, run the
				suite there.</p>
			</div>
${gatedNote(gatedTrials(log))}

			<h2>Report</h2>
			<ul class="links">
				<li><a href="report.html">Full report<span>Every trial, with sources and box plots</span></a></li>
				<li><a href="results.json">results.json<span>The same statistics, machine-readable</span></a></li>
				<li><a href="environment.txt">environment.txt<span>The machine that produced them</span></a></li>
			</ul>

			<h2>${trials.length} trials, ${candidates} candidates</h2>
			<div class="scroll">
				<table>
					<thead>
						<tr>
							<th>Trial</th><th class="n">Candidates</th><th>Fastest</th>
							<th class="n">Per call</th><th class="n">Spread</th>
						</tr>
					</thead>
					<tbody>${rows(trials)}
					</tbody>
				</table>
			</div>

			<h2>Environment</h2>
			<dl class="env">${environmentRows(environment)}
			</dl>
${provenance(meta)}
			<footer>
				Generated by <code>tools/benchmark</code> in Internet's Benchmark Suite.
			</footer>
		</main>
	</body>
</html>
`;
}
