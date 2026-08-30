import assert from "node:assert/strict";
import test from "node:test";
import { buildCopyArgs, buildRunArgs, run, stripAnsi, CRASH_LOG, REPORT_DIR } from "../lib/docker.js";
import { parseOptions } from "../lib/options.js";

const PATHS = {
	override: "/work/override",
	serverCfg: "/work/server.cfg",
	requirements: "/work/requirements.txt",
	artifacts: "/work/artifacts"
};

function pairs(args, flag) {
	return args.filter((_, index) => args[index - 1] === flag);
}

test("buildRunArgs names the container and ends on the image", () => {
	const options = parseOptions(["--container-name=bench", "--image=ghcr.io/example/runner:1"]);
	const args = buildRunArgs(options, PATHS);

	assert.deepEqual(args.slice(0, 3), ["run", "--name", "bench"]);
	assert.equal(args.at(-1), "ghcr.io/example/runner:1");
});

test("buildRunArgs passes the entrypoint's environment through", () => {
	const options = parseOptions(["--timeout=45", "--branch=x86-64", "--map=gm_flatgrass", "--gamemode=terrortown"]);

	assert.deepEqual(pairs(buildRunArgs(options, PATHS), "--env"), [
		"TIMEOUT=45",
		"GAMEMODE=terrortown",
		"MAP=gm_flatgrass",
		"GMOD_BRANCH=x86-64",
		"EXTRA_STARTUP_ARGS=",
		"COLLECTION_ID=0"
	]);
});

test("buildRunArgs mounts the staged files read-only", () => {
	assert.deepEqual(pairs(buildRunArgs(parseOptions([]), PATHS), "--volume"), [
		"/work/override:/home/steam/garrysmod_override:ro",
		"/work/server.cfg:/home/steam/gmodserver/custom_server.cfg:ro",
		"/work/requirements.txt:/home/steam/gmodserver/custom_requirements.txt:ro",
		"/work/artifacts:/home/steam/_gluatest_artifacts:ro"
	]);
});

test("the report and crash log live where the image puts them", () => {
	assert.equal(REPORT_DIR, "/home/steam/gmodserver/garrysmod/data/internet_benchmarks");
	assert.equal(CRASH_LOG, "/home/steam/gmodserver/debug.log");
});

test("buildCopyArgs addresses a path inside the container", () => {
	assert.deepEqual(
		buildCopyArgs("bench", `${REPORT_DIR}/.`, "/out"),
		["cp", "bench:/home/steam/gmodserver/garrysmod/data/internet_benchmarks/.", "/out"]
	);
});

test("stripAnsi leaves the text and drops the colour", () => {
	const escape = String.fromCharCode(27);

	assert.equal(stripAnsi(`${escape}[0;32mTrial 'modulo'${escape}[0m`), "Trial 'modulo'");
	assert.equal(stripAnsi("no colour here"), "no colour here");
});

test("run reports the exit code and streams output a line at a time", async () => {
	const lines = [];
	const code = await run(process.execPath, ["-e", "console.log('one');console.log('two');process.exit(3)"], {
		onLine: (line) => lines.push(line),
		quiet: true
	});

	assert.equal(code, 3);
	assert.deepEqual(lines.filter((line) => line !== ""), ["one", "two"]);
});
