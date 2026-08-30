#!/usr/bin/env node
import fs from "node:fs/promises";
import path from "node:path";
import { parseArgs } from "node:util";
import { renderSite } from "./lib/site.js";

const USAGE = `Usage: node tools/benchmark/site.js --bundle=<dir>

Writes index.html into a bundle produced by harness.js, framing the report for
publication: the disclaimer it has to carry, what was not measured, and where
it came from.

  --bundle=<dir>        The harness's output directory. Required.
  --repository=<o/r>    Repository the run came from, for provenance links.
  --commit=<sha>        Commit the run was built from.
  --run-id=<id>         Workflow run that produced it.
  -h, --help            Show this message.`;

const {values} = parseArgs({
	options: {
		bundle: {type: "string"},
		repository: {type: "string", default: process.env.GITHUB_REPOSITORY ?? ""},
		commit: {type: "string", default: process.env.GITHUB_SHA ?? ""},
		"run-id": {type: "string", default: process.env.GITHUB_RUN_ID ?? ""},
		help: {type: "boolean", short: "h", default: false}
	},
	strict: true
});

if (values.help) {
	console.log(USAGE);
	process.exit(0);
}

if (!values.bundle) {
	console.error(`--bundle is required.\n\n${USAGE}`);
	process.exit(2);
}

const bundle = path.resolve(values.bundle);
const results = JSON.parse(await fs.readFile(path.join(bundle, "results.json"), "utf8"));

// The gated-trial note is a nicety; a run whose log did not survive still gets
// a page.
let log = "";
try {
	log = await fs.readFile(path.join(bundle, "server.log"), "utf8");
} catch {
	log = "";
}

const page = renderSite({
	results,
	log,
	meta: {repository: values.repository, commit: values.commit, runId: values["run-id"]}
});

await fs.writeFile(path.join(bundle, "index.html"), page);
console.log(`[site] Wrote ${path.join(bundle, "index.html")}.`);
