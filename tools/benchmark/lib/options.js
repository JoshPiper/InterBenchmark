import { parseArgs } from "node:util";
import path from "node:path";

export const MODES = ["all", "tag", "trial"];
export const ITERATIONS = ["default", "dynamic", "test"];
export const BRANCHES = ["live", "x86-64", "dev", "prerelease"];

// Trial names and tags end up inside generated Lua and a docker command line,
// so they are held to an identifier-ish shape rather than escaped and hoped for.
const NAME = /^[a-z0-9][a-z0-9_.-]*$/i;
const IMAGE = /^[a-z0-9][a-z0-9._\-/]*(:[a-z0-9][a-z0-9._-]*)?(@sha256:[a-f0-9]{64})?$/i;
const CONTAINER = /^[a-z0-9][a-z0-9_.-]*$/i;

export class UsageError extends Error {}

const SPEC = {
	mode: {type: "string", default: "all"},
	trial: {type: "string"},
	tag: {type: "string", multiple: true, default: []},
	"skip-tag": {type: "string", multiple: true, default: []},
	iterations: {type: "string", default: "default"},
	branch: {type: "string", default: "live"},
	image: {type: "string"},
	gamemode: {type: "string", default: "sandbox"},
	map: {type: "string", default: "gm_construct"},
	timeout: {type: "string", default: "30"},
	warmup: {type: "string", default: "5"},
	"logging-level": {type: "string", default: "20"},
	"extra-startup-args": {type: "string", default: ""},
	project: {type: "string", default: "."},
	output: {type: "string", default: "benchmark-output"},
	"work-dir": {type: "string", default: ".benchmark-work"},
	override: {type: "string", multiple: true, default: []},
	"container-name": {type: "string", default: "internet-benchmark-runner"},
	pull: {type: "boolean", default: true},
	"keep-container": {type: "boolean", default: false},
	help: {type: "boolean", short: "h", default: false}
};

export const USAGE = `Usage: node tools/benchmark/harness.js [options]

Runs Internet's Benchmark Suite on a headless Garry's Mod server in docker and
collects the generated report.

  --mode=all|tag|trial     What to benchmark. Default: all.
  --trial=<name>           The trial to run (--mode=trial).
  --tag=<a,b>              Only run trials with these tags (--mode=tag, repeatable).
  --skip-tag=<a,b>         Never run trials with these tags (repeatable).
  --iterations=<mode>      default, dynamic (calibrate) or test (fast smoke run).
  --branch=<branch>        live, x86-64, dev or prerelease. Default: live.
  --image=<ref>            Runner image. Default: derived from --branch.
  --gamemode=<name>        Default: sandbox.
  --map=<name>             Default: gm_construct.
  --timeout=<minutes>      Hard limit on the server's lifetime. Default: 30.
  --warmup=<seconds>       Settling time before the first trial. Default: 5.
  --logging-level=<n>      internet_benchmark_logging_level. Default: 20 (INFO).
  --extra-startup-args=<s> Extra srcds arguments.
  --project=<dir>          The addon to benchmark. Default: the working directory.
  --output=<dir>           Where the report is written. Default: benchmark-output.
  --work-dir=<dir>         Staging directory. Default: .benchmark-work.
  --override=<dir>         Extra files to merge over garrysmod/ (repeatable).
  --container-name=<name>  Default: internet-benchmark-runner.
  --no-pull                Skip pulling the runner image.
  --keep-container         Leave the container in place after collecting output.
  -h, --help               Show this message.`;

function positiveInt(value, flag) {
	if (!/^\d+$/.test(value) || Number(value) <= 0) {
		throw new UsageError(`--${flag} must be a positive whole number, got '${value}'.`);
	}

	return Number(value);
}

function oneOf(value, allowed, flag) {
	if (!allowed.includes(value)) {
		throw new UsageError(`--${flag} must be one of ${allowed.join(", ")}; got '${value}'.`);
	}

	return value;
}

function name(value, flag) {
	if (!NAME.test(value)) {
		throw new UsageError(`--${flag} must be a plain name (letters, digits, . _ -), got '${value}'.`);
	}

	return value;
}

/** Split, lower-case and de-duplicate a repeatable comma-separated flag, the way BENCH:ParseTagList does in-game. */
export function tagList(values, flag) {
	const tags = [];
	for (const value of values) {
		for (const entry of value.split(",")) {
			const tag = entry.trim().toLowerCase();
			if (tag === "") {
				continue;
			}

			name(tag, flag);
			if (!tags.includes(tag)) {
				tags.push(tag);
			}
		}
	}

	return tags;
}

/** The runner image for a GMod branch, mirroring how GLuaTest's workflow rewrites its compose file. */
export function imageFor(branch) {
	const suffix = {live: "", "x86-64": "/64bit", dev: "/dev", prerelease: "/prerelease"}[branch];
	return `ghcr.io/cfc-servers/gluatest${suffix}:latest`;
}

/** A one-line description of the run, echoed by the in-game fixture. */
export function describe(options) {
	const parts = [`mode=${options.mode}`];
	if (options.trial) {
		parts.push(`trial=${options.trial}`);
	}

	if (options.includeTags.length > 0) {
		parts.push(`tags=${options.includeTags.join(",")}`);
	}

	if (options.excludeTags.length > 0) {
		parts.push(`skip-tags=${options.excludeTags.join(",")}`);
	}

	parts.push(`iterations=${options.iterations}`);
	return parts.join(" ");
}

function checkCombination(mode, trial, includeTags, excludeTags) {
	if (mode === "trial") {
		if (!trial) {
			throw new UsageError("--mode=trial needs --trial=<name>.");
		}

		if (includeTags.length > 0 || excludeTags.length > 0) {
			throw new UsageError("--tag/--skip-tag filter a full run; --mode=trial already names one trial.");
		}

		return;
	}

	if (trial) {
		throw new UsageError(`--trial only applies to --mode=trial, not --mode=${mode}.`);
	}

	if (mode === "tag" && includeTags.length === 0) {
		throw new UsageError("--mode=tag needs at least one --tag=<name>.");
	}

	if (mode === "all" && includeTags.length > 0) {
		throw new UsageError("--tag needs --mode=tag; --mode=all runs every trial.");
	}
}

/**
 * Parse and validate the harness's command line.
 * @param {string[]} argv Arguments after the script name.
 * @returns {object} The validated options, with every path resolved.
 */
export function parseOptions(argv) {
	let values;
	try {
		({values} = parseArgs({args: argv, options: SPEC, allowNegative: true, strict: true}));
	} catch (error) {
		throw new UsageError(error.message);
	}

	if (values.help) {
		return {help: true};
	}

	const mode = oneOf(values.mode, MODES, "mode");
	const iterations = oneOf(values.iterations, ITERATIONS, "iterations");
	const branch = oneOf(values.branch, BRANCHES, "branch");
	const trial = values.trial === undefined ? null : name(values.trial, "trial");
	const includeTags = tagList(values.tag, "tag");
	const excludeTags = tagList(values["skip-tag"], "skip-tag");

	checkCombination(mode, trial, includeTags, excludeTags);

	if (values.image !== undefined && !IMAGE.test(values.image)) {
		throw new UsageError(`--image is not a valid image reference: '${values.image}'.`);
	}

	if (!CONTAINER.test(values["container-name"])) {
		throw new UsageError(`--container-name is not a valid container name: '${values["container-name"]}'.`);
	}

	const timeout = positiveInt(values.timeout, "timeout");

	const options = {
		help: false,
		mode,
		trial,
		includeTags,
		excludeTags,
		iterations,
		dynamic: iterations === "dynamic",
		test: iterations === "test",
		branch,
		image: values.image ?? imageFor(branch),
		gamemode: name(values.gamemode, "gamemode"),
		map: name(values.map, "map"),
		timeout,
		warmup: positiveInt(values.warmup, "warmup"),
		// The in-game watchdog has to give up before the container's own
		// timeout kills the server, or a stalled run is reported as a crash
		// with no report to show for it. Its clock only starts once the map is
		// up, so the margin has to cover the boot it missed as well.
		deadline: Math.max(60, timeout * 60 - 240),
		loggingLevel: positiveInt(values["logging-level"], "logging-level"),
		extraStartupArgs: values["extra-startup-args"],
		containerName: values["container-name"],
		pull: values.pull,
		keepContainer: values["keep-container"],
		project: path.resolve(values.project),
		output: path.resolve(values.output),
		workDir: path.resolve(values["work-dir"]),
		overrides: values.override.map((dir) => path.resolve(dir))
	};

	options.summary = describe(options);
	return options;
}
