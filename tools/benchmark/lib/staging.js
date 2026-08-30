import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { renderConfig, renderServerConfig } from "./fixture.js";

const FIXTURE = fileURLToPath(new URL("../fixture", import.meta.url));

export const ADDON = "internet_benchmark";
export const HARNESS_ADDON = "internet_benchmark_harness";

/**
 * Build the server-file overlay the container mounts.
 * The layout matches GLuaTest's compose file: an overlay of garrysmod/, a
 * server config to append, a requirements list, and an artifacts directory.
 * @param {object} options As returned by parseOptions.
 * @returns {Promise<object>} The staged paths.
 */
export async function stage(options) {
	await fs.rm(options.workDir, {recursive: true, force: true});

	const paths = {
		override: path.join(options.workDir, "override"),
		serverCfg: path.join(options.workDir, "server.cfg"),
		requirements: path.join(options.workDir, "requirements.txt"),
		artifacts: path.join(options.workDir, "artifacts")
	};

	const addon = path.join(paths.override, "addons", ADDON);
	await fs.mkdir(addon, {recursive: true});
	// The entrypoint reads through a directory of the same name, as the
	// workflow's artifact download would have created.
	await fs.mkdir(path.join(paths.artifacts, "_gluatest_artifacts"), {recursive: true});

	// Stage what the packaged addon ships: the suite's own GLuaTest tests have
	// no business on a benchmark server.
	const tests = path.join(options.project, "lua", "tests");
	await fs.cp(path.join(options.project, "lua"), path.join(addon, "lua"), {
		recursive: true,
		filter: (source) => source !== tests
	});
	await fs.cp(path.join(options.project, "addon.json"), path.join(addon, "addon.json"));

	const harness = path.join(paths.override, "addons", HARNESS_ADDON);
	await fs.cp(FIXTURE, harness, {recursive: true});
	await fs.mkdir(path.join(harness, "lua", HARNESS_ADDON), {recursive: true});
	await fs.writeFile(path.join(harness, "lua", HARNESS_ADDON, "config.lua"), renderConfig(options));

	for (const override of options.overrides) {
		await fs.cp(override, paths.override, {recursive: true});
	}

	await fs.writeFile(paths.serverCfg, renderServerConfig(options));
	await fs.writeFile(paths.requirements, "");

	return paths;
}
