import assert from "node:assert/strict";
import test from "node:test";
import { escapeHtml, gatedTrials, renderSite } from "../lib/site.js";

const LOG = [
	"[Internet's Benchmark Suite][sv][Info] Trial 'array_insertion' (1 of 17)",
	"[Internet's Benchmark Suite][sv][Info] Trial 'draw_rect' is gated off in this environment, skipping.",
	"[Internet's Benchmark Suite][sv][Info] Trial 'set_draw_color' is gated off in this environment, skipping.",
	"[Internet's Benchmark Suite][sv][Info] Trial 'draw_rect' is gated off in this environment, skipping."
].join("\n");

const RESULTS = {
	environment: {
		"Suite Version": "3.0.0",
		Generated: "2026-08-30 16:52:39 UTC",
		"CPU Model": "AMD EPYC 7763 64-Core Processor",
		Hosting: "Dedicated Server"
	},
	trials: [{
		id: "modulo",
		name: "modulo",
		functions: [
			{id: 1, label: "a % b", mean: 0.002, average: 2e-8, percentage: 100},
			{id: 2, label: "math.fmod", mean: 0.005, average: 5e-8, percentage: 250}
		]
	}]
};

test("gatedTrials names each skipped trial once, sorted", () => {
	assert.deepEqual(gatedTrials(LOG), ["draw_rect", "set_draw_color"]);
});

test("gatedTrials finds nothing in a log that skipped nothing", () => {
	assert.deepEqual(gatedTrials("Trial 'modulo' (1 of 1)"), []);
	assert.deepEqual(gatedTrials(""), []);
});

test("escapeHtml neutralises markup", () => {
	assert.equal(escapeHtml("<script>&\"x\""), "&lt;script&gt;&amp;&quot;x&quot;");
});

test("the page leads with the disclaimer, not the numbers", () => {
	const page = renderSite({results: RESULTS, log: LOG});

	assert.match(page, /not authoritative numbers/);
	assert.ok(page.indexOf("not authoritative numbers") < page.indexOf("modulo"));
	assert.match(page, /shared\s+GitHub Actions runner/);
	assert.match(page, /relative to each other within this\s+one run/);
});

test("the page names the trials the server could not measure", () => {
	const page = renderSite({results: RESULTS, log: LOG});

	assert.match(page, /2 trials were not measured here/);
	assert.match(page, /<code>draw_rect<\/code>/);
	assert.match(page, /<code>set_draw_color<\/code>/);
});

test("the gated note does not blame the client realm for every skipped trial", () => {
	// A trial can gate on a gamemode too, and the log does not say which.
	const log = "Trial 'ns_accessors' is gated off in this environment, skipping.";
	const page = renderSite({results: RESULTS, log});

	assert.match(page, /a realm, a gamemode, a particular engine\s+build/);
	assert.match(page, /rendering trials can only ever be timed/);
});

test("the gated note reads correctly for a single trial", () => {
	const log = "Trial 'draw_rect' is gated off in this environment, skipping.";
	assert.match(renderSite({results: RESULTS, log}), /1 trial was not measured here/);
});

test("the gated note is dropped when nothing was gated", () => {
	assert.doesNotMatch(renderSite({results: RESULTS, log: ""}), /not measured here/);
});

test("the page links the three published files", () => {
	const page = renderSite({results: RESULTS, log: LOG});

	assert.match(page, /href="report\.html"/);
	assert.match(page, /href="results\.json"/);
	assert.match(page, /href="environment\.txt"/);
});

test("the page tabulates the trials and counts the candidates", () => {
	const page = renderSite({results: RESULTS, log: LOG});

	assert.match(page, /1 trials, 2 candidates/);
	assert.match(page, /<td>a % b<\/td>/);
	assert.match(page, /<td class="n">20ns<\/td>/);
	assert.match(page, /<td class="n">250%<\/td>/);
});

test("the page lists the environment keys it recognises and no others", () => {
	const page = renderSite({results: RESULTS, log: LOG});

	assert.match(page, /<dt>CPU Model<\/dt><dd>AMD EPYC 7763 64-Core Processor<\/dd>/);
	assert.doesNotMatch(page, /Hosting/);
});

test("provenance links the commit and run when they are known", () => {
	const page = renderSite({
		results: RESULTS,
		log: LOG,
		meta: {repository: "JoshPiper/InterBenchmark", commit: "6c70d50abcdef", runId: "123"}
	});

	assert.match(page, /commit\/6c70d50abcdef"><code>6c70d50<\/code>/);
	assert.match(page, /actions\/runs\/123"/);
});

test("provenance is omitted outside a workflow run", () => {
	assert.doesNotMatch(renderSite({results: RESULTS, log: LOG}), /Built from/);
});

test("the page escapes a candidate label that carries markup", () => {
	const results = {
		trials: [{
			id: "x",
			name: "<b>x</b>",
			functions: [{id: 1, label: "a<b", mean: 1, average: 1, percentage: 100}]
		}]
	};

	const page = renderSite({results, log: ""});
	assert.match(page, /<td>&lt;b&gt;x&lt;\/b&gt;<\/td>/);
	assert.match(page, /<td>a&lt;b<\/td>/);
});

test("the page is a complete, self-contained document", () => {
	const page = renderSite({results: RESULTS, log: LOG});

	assert.match(page, /^<!doctype html>/);
	assert.match(page, /<\/html>\s*$/);
	assert.doesNotMatch(page, /<(script|link)\b/);
});
