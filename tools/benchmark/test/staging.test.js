import assert from "node:assert/strict";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { parseOptions } from "../lib/options.js";
import { stage, ADDON, HARNESS_ADDON } from "../lib/staging.js";

async function scratch(t) {
	const root = await fs.mkdtemp(path.join(os.tmpdir(), "benchmark-harness-"));
	t.after(() => fs.rm(root, {recursive: true, force: true}));
	return root;
}

async function fakeProject(root) {
	const project = path.join(root, "project");
	await fs.mkdir(path.join(project, "lua", "autorun"), {recursive: true});
	await fs.mkdir(path.join(project, "lua", "tests", "internet_benchmark"), {recursive: true});
	await fs.mkdir(path.join(project, "lua", "internet_benchmark", "trials"), {recursive: true});

	await fs.writeFile(path.join(project, "addon.json"), "{}");
	await fs.writeFile(path.join(project, "lua", "autorun", "internet_benchmarks.lua"), "-- suite");
	await fs.writeFile(path.join(project, "lua", "internet_benchmark", "trials", "modulo.lua"), "-- trial");
	await fs.writeFile(path.join(project, "lua", "tests", "internet_benchmark", "args.lua"), "-- test");

	return project;
}

async function exists(target) {
	try {
		await fs.stat(target);
		return true;
	} catch {
		return false;
	}
}

async function stageFrom(root, argv) {
	const project = await fakeProject(root);
	const options = parseOptions([
		`--project=${project}`,
		`--work-dir=${path.join(root, "work")}`,
		...argv
	]);

	return {options, paths: await stage(options)};
}

test("stages the addon under addons/, without its own test suite", async (t) => {
	const root = await scratch(t);
	const {paths} = await stageFrom(root, []);
	const addon = path.join(paths.override, "addons", ADDON);

	assert.ok(await exists(path.join(addon, "addon.json")));
	assert.ok(await exists(path.join(addon, "lua", "autorun", "internet_benchmarks.lua")));
	assert.ok(await exists(path.join(addon, "lua", "internet_benchmark", "trials", "modulo.lua")));
	assert.equal(await exists(path.join(addon, "lua", "tests")), false);
});

test("stages the fixture addon beside it, with its generated config", async (t) => {
	const root = await scratch(t);
	const {paths} = await stageFrom(root, ["--mode=trial", "--trial=modulo"]);
	const harness = path.join(paths.override, "addons", HARNESS_ADDON);

	assert.ok(await exists(path.join(harness, "lua", "autorun", "server", "internet_benchmark_harness.lua")));

	const config = await fs.readFile(path.join(harness, "lua", HARNESS_ADDON, "config.lua"), "utf8");
	assert.match(config, /trial = "modulo",/);
});

test("writes the server config, requirements and artifacts directory the entrypoint reads", async (t) => {
	const root = await scratch(t);
	const {paths} = await stageFrom(root, []);

	assert.match(await fs.readFile(paths.serverCfg, "utf8"), /gluatest_server_enable 0/);
	assert.equal(await fs.readFile(paths.requirements, "utf8"), "");
	assert.ok(await exists(path.join(paths.artifacts, "_gluatest_artifacts")));
});

test("merges extra overrides over the staged server files", async (t) => {
	const root = await scratch(t);
	const extra = path.join(root, "extra", "lua", "bin");
	await fs.mkdir(extra, {recursive: true});
	await fs.writeFile(path.join(extra, "gmsv_sysinfo_linux64.dll"), "binary");

	const {paths} = await stageFrom(root, [`--override=${path.join(root, "extra")}`]);

	assert.ok(await exists(path.join(paths.override, "lua", "bin", "gmsv_sysinfo_linux64.dll")));
});

test("clears the previous run's staging rather than layering on it", async (t) => {
	const root = await scratch(t);
	const {options, paths} = await stageFrom(root, []);
	const stale = path.join(paths.override, "addons", "stale");
	await fs.mkdir(stale, {recursive: true});

	await stage(options);

	assert.equal(await exists(stale), false);
});
