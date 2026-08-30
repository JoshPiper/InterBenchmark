import { spawn } from "node:child_process";

const ANSI = new RegExp("\\u001b\\[[0-9;?]*[ -/]*[@-~]", "g");

export const SERVER_ROOT = "/home/steam/gmodserver";
export const REPORT_DIR = `${SERVER_ROOT}/garrysmod/data/internet_benchmarks`;
export const CRASH_LOG = `${SERVER_ROOT}/debug.log`;

/** Strip terminal colour codes, which the runner emits unconditionally through unbuffer. */
export function stripAnsi(text) {
	return text.replace(ANSI, "");
}

/**
 * The docker arguments that boot one benchmark server.
 * Mirrors the mounts and environment of GLuaTest's docker-compose.yml, so the
 * image's own entrypoint drives the server exactly as it does for tests.
 * @param {object} options As returned by parseOptions.
 * @param {object} paths As returned by stage.
 * @returns {string[]}
 */
export function buildRunArgs(options, paths) {
	const environment = {
		TIMEOUT: String(options.timeout),
		GAMEMODE: options.gamemode,
		MAP: options.map,
		GMOD_BRANCH: options.branch,
		EXTRA_STARTUP_ARGS: options.extraStartupArgs,
		COLLECTION_ID: "0"
	};

	const mounts = [
		[paths.override, "/home/steam/garrysmod_override"],
		[paths.serverCfg, `${SERVER_ROOT}/custom_server.cfg`],
		[paths.requirements, `${SERVER_ROOT}/custom_requirements.txt`],
		[paths.artifacts, "/home/steam/_gluatest_artifacts"]
	];

	const args = ["run", "--name", options.containerName];
	for (const [key, value] of Object.entries(environment)) {
		args.push("--env", `${key}=${value}`);
	}

	for (const [source, target] of mounts) {
		args.push("--volume", `${source}:${target}:ro`);
	}

	args.push(options.image);
	return args;
}

/** The docker arguments that lift one path back out of the finished container. */
export function buildCopyArgs(container, source, destination) {
	return ["cp", `${container}:${source}`, destination];
}

/**
 * Run a command, streaming its output.
 * @param {string} command
 * @param {string[]} args
 * @param {object} [handlers]
 * @param {(line: string) => void} [handlers.onLine] Called per line of output.
 * @param {boolean} [handlers.quiet] Suppress the echo to this process's stdout.
 * @returns {Promise<number>} The exit code.
 */
export function run(command, args, {onLine, quiet = false} = {}) {
	return new Promise((resolve, reject) => {
		const child = spawn(command, args, {stdio: ["ignore", "pipe", "pipe"]});
		let pending = "";

		const consume = (chunk) => {
			if (!quiet) {
				process.stdout.write(chunk);
			}

			if (!onLine) {
				return;
			}

			pending += chunk;
			const lines = pending.split("\n");
			pending = lines.pop() ?? "";
			for (const line of lines) {
				onLine(line);
			}
		};

		child.stdout.setEncoding("utf8");
		child.stderr.setEncoding("utf8");
		child.stdout.on("data", consume);
		child.stderr.on("data", consume);

		child.on("error", reject);
		child.on("close", (code) => {
			if (pending !== "" && onLine) {
				onLine(pending);
			}

			resolve(code ?? 1);
		});
	});
}
