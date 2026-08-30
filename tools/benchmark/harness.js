#!/usr/bin/env node
import fs from "node:fs/promises";
import path from "node:path";
import { parseOptions, UsageError, USAGE } from "./lib/options.js";
import { stage } from "./lib/staging.js";
import { buildCopyArgs, buildRunArgs, run, stripAnsi, CRASH_LOG, REPORT_DIR } from "./lib/docker.js";
import { renderSummary } from "./lib/summary.js";

const REPORT = "report.html";

function note(message) {
	console.log(`[harness] ${message}`);
}

function problem(message) {
	if (process.env.GITHUB_ACTIONS) {
		console.log(`::error title=Benchmark harness::${message}`);
	}

	console.error(`[harness] ${message}`);
}

async function renameIfPresent(from, to) {
	try {
		await fs.rename(from, to);
		return true;
	} catch (error) {
		if (error.code === "ENOENT") {
			return false;
		}

		throw error;
	}
}

/** Lift the report, and any crash log, back out of the finished container. */
async function collect(options) {
	const trouble = [];
	const copied = await run("docker", buildCopyArgs(options.containerName, `${REPORT_DIR}/.`, options.output), {
		onLine: (line) => trouble.push(line),
		quiet: true
	});

	let report = false;
	if (copied !== 0) {
		problem(`Could not read the report out of the container: ${trouble.join(" ").trim()}`);
	} else {
		// Garry's Mod can only write a whitelisted set of extensions, so the
		// report leaves the game as .html.txt.
		report = await renameIfPresent(path.join(options.output, "report.html.txt"), path.join(options.output, REPORT));
	}

	await run("docker", buildCopyArgs(options.containerName, CRASH_LOG, path.join(options.output, "debug.log")), {quiet: true});
	return report;
}

async function summarise(options) {
	let results;
	try {
		results = JSON.parse(await fs.readFile(path.join(options.output, "results.json"), "utf8"));
	} catch {
		return;
	}

	const markdown = renderSummary(results, options);
	await fs.writeFile(path.join(options.output, "summary.md"), markdown);

	if (process.env.GITHUB_STEP_SUMMARY) {
		await fs.appendFile(process.env.GITHUB_STEP_SUMMARY, markdown);
	}

	console.log(markdown);
}

async function main(argv) {
	let options;
	try {
		options = parseOptions(argv);
	} catch (error) {
		if (!(error instanceof UsageError)) {
			throw error;
		}

		console.error(`${error.message}\n\n${USAGE}`);
		return 2;
	}

	if (options.help) {
		console.log(USAGE);
		return 0;
	}

	note(`${options.summary} (${options.image})`);
	const paths = await stage(options);
	await fs.mkdir(options.output, {recursive: true});

	await run("docker", ["rm", "--force", options.containerName], {quiet: true});

	if (options.pull) {
		const pulled = await run("docker", ["pull", options.image]);
		if (pulled !== 0) {
			problem(`Could not pull ${options.image}.`);
			return pulled;
		}
	}

	const log = [];
	const status = await run("docker", buildRunArgs(options, paths), {
		onLine: (line) => log.push(stripAnsi(line))
	});

	await fs.writeFile(path.join(options.output, "server.log"), `${log.join("\n")}\n`);

	const report = await collect(options);

	if (!options.keepContainer) {
		await run("docker", ["rm", "--force", options.containerName], {quiet: true});
	}

	await summarise(options);

	if (status !== 0) {
		problem(`The benchmark server exited with status ${status}; see server.log in the artifact.`);
		return status;
	}

	if (!report) {
		problem("The run finished but wrote no report.");
		return 1;
	}

	note(`Wrote ${path.join(options.output, REPORT)}.`);
	return 0;
}

try {
	process.exitCode = await main(process.argv.slice(2));
} catch (error) {
	problem(error.message);
	console.error(error.stack);
	process.exitCode = 1;
}
