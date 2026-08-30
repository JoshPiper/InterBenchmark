import assert from "node:assert/strict";
import test from "node:test";
import { formatSeconds, renderSummary, summariseTrial } from "../lib/summary.js";
import { parseOptions } from "../lib/options.js";

const RESULTS = {
	environment: {
		"Suite Version": "3.0.0",
		"Game Branch": "live",
		"Lua Runtime": "LuaJIT 2.0.4",
		Hosting: "Dedicated"
	},
	trials: [
		{
			id: "modulo",
			name: "modulo",
			functions: [
				{id: 1, label: "a % b", mean: 0.002, average: 2e-8, percentage: 100},
				{id: 2, label: "math.fmod", mean: 0.005, average: 5e-8, percentage: 250}
			]
		},
		{
			id: "nots",
			name: "nots",
			functions: [{id: 1, label: "not x", mean: 0.001, average: 1e-8, percentage: 100}]
		}
	]
};

test("formatSeconds picks the unit that keeps a number readable", () => {
	assert.equal(formatSeconds(2), "2s");
	assert.equal(formatSeconds(0.0123), "12.3ms");
	assert.equal(formatSeconds(1.5e-6), "1.5us");
	assert.equal(formatSeconds(2.34e-8), "23.4ns");
});

test("formatSeconds does not invent precision for a zero or absent timing", () => {
	assert.equal(formatSeconds(0), "0s");
	assert.equal(formatSeconds(-1), "0s");
	assert.equal(formatSeconds(Number.NaN), "0s");
	assert.equal(formatSeconds(undefined), "0s");
});

test("summariseTrial reports the fastest candidate and the widest spread", () => {
	assert.deepEqual(summariseTrial(RESULTS.trials[0]), {
		name: "modulo",
		candidates: 2,
		fastest: "a % b",
		perCall: "20ns",
		spread: "250%"
	});
});

test("summariseTrial holds a single-candidate trial at 100%", () => {
	assert.equal(summariseTrial(RESULTS.trials[1]).spread, "100%");
});

test("summariseTrial copes with a trial that produced no candidates", () => {
	assert.deepEqual(summariseTrial({id: "empty", functions: []}), {
		name: "empty",
		candidates: 0,
		fastest: "-",
		perCall: "-",
		spread: "100%"
	});
});

test("renderSummary tabulates every trial under the run's description", () => {
	const summary = renderSummary(RESULTS, parseOptions(["--mode=tag", "--tag=default"]));

	assert.match(summary, /^## Internet's Benchmark Suite$/m);
	assert.match(summary, /`mode=tag tags=default iterations=default`/);
	assert.match(summary, /^2 trials, 3 candidates\.$/m);
	assert.match(summary, /^\| modulo \| 2 \| a % b \| 20ns \| 250% \|$/m);
	assert.match(summary, /^\| nots \| 1 \| not x \| 10ns \| 100% \|$/m);
});

test("renderSummary lists the environment keys it recognises, in order", () => {
	const summary = renderSummary(RESULTS, parseOptions([]));

	assert.match(summary, /- \*\*Suite Version:\*\* 3\.0\.0/);
	assert.match(summary, /- \*\*Game Branch:\*\* live/);
	assert.ok(summary.indexOf("Suite Version") < summary.indexOf("Lua Runtime"));
	assert.doesNotMatch(summary, /Hosting/);
});

test("renderSummary warns off cross-run comparisons", () => {
	assert.match(renderSummary(RESULTS, parseOptions([])), /noisy neighbours/);
});

test("renderSummary escapes a pipe in a candidate's label", () => {
	const results = {
		trials: [{
			id: "nots",
			name: "nots",
			functions: [{id: 1, label: "a | b", mean: 1, average: 1, percentage: 100}]
		}]
	};

	assert.match(renderSummary(results, parseOptions([])), /\| a \\\| b \|/);
});

test("renderSummary survives an empty results file", () => {
	const summary = renderSummary({}, parseOptions([]));

	assert.match(summary, /^0 trials, 0 candidates\.$/m);
	assert.doesNotMatch(summary, /<details>/);
});
