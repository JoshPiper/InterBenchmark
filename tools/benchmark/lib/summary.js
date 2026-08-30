const UNITS = [[1, "s"], [1e-3, "ms"], [1e-6, "us"], [1e-9, "ns"]];

const ENVIRONMENT_KEYS = [
	"Suite Version",
	"Suite Build",
	"Game Branch",
	"Lua Runtime",
	"Architecture",
	"Operating System",
	"Map",
	"Generated"
];

/** Format a duration in seconds with the unit that keeps it readable. */
export function formatSeconds(seconds) {
	if (!Number.isFinite(seconds) || seconds <= 0) {
		return "0s";
	}

	for (const [scale, suffix] of UNITS) {
		if (seconds >= scale) {
			return `${Number((seconds / scale).toPrecision(3))}${suffix}`;
		}
	}

	return `${Number((seconds / 1e-9).toPrecision(3))}ns`;
}

/** The fastest candidate in a trial, and how far the slowest trails it. */
export function summariseTrial(trial) {
	const functions = trial.functions ?? [];
	const fastest = functions.reduce((best, candidate) => {
		return best === null || candidate.mean < best.mean ? candidate : best;
	}, null);

	const spread = functions.reduce((worst, candidate) => Math.max(worst, candidate.percentage ?? 100), 100);

	return {
		name: trial.name ?? trial.id,
		candidates: functions.length,
		fastest: fastest?.label ?? "-",
		perCall: fastest ? formatSeconds(fastest.average) : "-",
		spread: `${Math.round(spread)}%`
	};
}

function escapeCell(value) {
	return String(value).replace(/\|/g, "\\|");
}

/**
 * Render the run's markdown summary, for the job summary and the artifact.
 * @param {object} results The parsed results.json.
 * @param {object} options As returned by parseOptions.
 * @returns {string}
 */
export function renderSummary(results, options) {
	const trials = (results.trials ?? []).map(summariseTrial);
	const candidates = trials.reduce((total, trial) => total + trial.candidates, 0);

	const lines = [
		"## Internet's Benchmark Suite",
		"",
		`\`${options.summary}\` on \`${options.image}\``,
		"",
		`${trials.length} trials, ${candidates} candidates.`,
		"",
		"| Trial | Candidates | Fastest | Per call | Spread |",
		"| --- | ---: | --- | ---: | ---: |"
	];

	for (const trial of trials) {
		lines.push(`| ${escapeCell(trial.name)} | ${trial.candidates} | ${escapeCell(trial.fastest)} | ${trial.perCall} | ${trial.spread} |`);
	}

	const environment = results.environment ?? {};
	const known = ENVIRONMENT_KEYS.filter((key) => environment[key] !== undefined);
	if (known.length > 0) {
		lines.push("", "<details><summary>Environment</summary>", "");
		for (const key of known) {
			lines.push(`- **${key}:** ${environment[key]}`);
		}

		lines.push("", "</details>");
	}

	lines.push(
		"",
		"Shared CI runners are noisy neighbours: read these as one machine's snapshot, not as a baseline to compare later runs against.",
		""
	);

	return lines.join("\n");
}
