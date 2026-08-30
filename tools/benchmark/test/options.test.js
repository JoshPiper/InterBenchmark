import assert from "node:assert/strict";
import path from "node:path";
import test from "node:test";
import { describe, imageFor, parseOptions, tagList, UsageError, USAGE } from "../lib/options.js";

function rejects(argv, fragment) {
	assert.throws(() => parseOptions(argv), (error) => {
		assert.ok(error instanceof UsageError, `expected a UsageError, got ${error}`);
		assert.match(error.message, fragment);
		return true;
	});
}

test("defaults to a full run on the live branch", () => {
	const options = parseOptions([]);

	assert.equal(options.mode, "all");
	assert.equal(options.trial, null);
	assert.deepEqual(options.includeTags, []);
	assert.deepEqual(options.excludeTags, []);
	assert.equal(options.dynamic, false);
	assert.equal(options.test, false);
	assert.equal(options.image, "ghcr.io/cfc-servers/gluatest:latest");
	assert.equal(options.gamemode, "sandbox");
	assert.equal(options.map, "gm_construct");
	assert.equal(options.pull, true);
	assert.equal(options.keepContainer, false);
});

test("--help short-circuits before anything else is validated", () => {
	assert.deepEqual(parseOptions(["--help", "--mode=nonsense"]), {help: true});
	assert.match(USAGE, /--mode=all\|tag\|trial/);
});

test("resolves every path against the working directory", () => {
	const options = parseOptions(["--project=.", "--output=out", "--work-dir=work", "--override=extra"]);

	assert.equal(options.project, path.resolve("."));
	assert.equal(options.output, path.resolve("out"));
	assert.equal(options.workDir, path.resolve("work"));
	assert.deepEqual(options.overrides, [path.resolve("extra")]);
});

test("maps the iteration mode onto the suite's two flags", () => {
	assert.deepEqual(
		[parseOptions(["--iterations=dynamic"]).dynamic, parseOptions(["--iterations=dynamic"]).test],
		[true, false]
	);
	assert.deepEqual(
		[parseOptions(["--iterations=test"]).dynamic, parseOptions(["--iterations=test"]).test],
		[false, true]
	);
});

test("leaves the container timeout headroom over the in-game deadline", () => {
	assert.equal(parseOptions(["--timeout=30"]).deadline, 26 * 60);
	assert.equal(parseOptions(["--timeout=1"]).deadline, 60);
	assert.equal(parseOptions(["--timeout=4"]).deadline, 60);
});

test("names a single trial", () => {
	const options = parseOptions(["--mode=trial", "--trial=array_insertion"]);

	assert.equal(options.trial, "array_insertion");
	assert.equal(options.summary, "mode=trial trial=array_insertion iterations=default");
});

test("filters a run by tag", () => {
	const options = parseOptions(["--mode=tag", "--tag=Default,strings", "--tag=tables", "--skip-tag=slow"]);

	assert.deepEqual(options.includeTags, ["default", "strings", "tables"]);
	assert.deepEqual(options.excludeTags, ["slow"]);
	assert.equal(options.summary, "mode=tag tags=default,strings,tables skip-tags=slow iterations=default");
});

test("a full run may still exclude tags", () => {
	assert.deepEqual(parseOptions(["--skip-tag=slow"]).excludeTags, ["slow"]);
});

test("rejects mode combinations that would quietly ignore a flag", () => {
	rejects(["--mode=trial"], /needs --trial/);
	rejects(["--mode=trial", "--trial=modulo", "--tag=default"], /already names one trial/);
	rejects(["--mode=trial", "--trial=modulo", "--skip-tag=slow"], /already names one trial/);
	rejects(["--mode=tag"], /needs at least one --tag/);
	rejects(["--mode=tag", "--trial=modulo"], /--trial only applies/);
	rejects(["--mode=all", "--tag=default"], /--tag needs --mode=tag/);
});

test("rejects values outside their enumeration", () => {
	rejects(["--mode=everything"], /--mode must be one of/);
	rejects(["--iterations=quick"], /--iterations must be one of/);
	rejects(["--branch=nightly"], /--branch must be one of/);
});

test("rejects names that would escape the generated Lua or the mount path", () => {
	rejects(["--mode=trial", "--trial=../../etc/passwd"], /--trial must be a plain name/);
	rejects(["--mode=trial", "--trial=modulo\" or true --"], /--trial must be a plain name/);
	rejects(["--mode=tag", "--tag=a b"], /--tag must be a plain name/);
	rejects(["--gamemode=sand box"], /--gamemode must be a plain name/);
	rejects(["--container-name=-bad name"], /not a valid container name/);
	rejects(["--image=not a ref"], /not a valid image reference/);
});

test("rejects numbers that are not positive whole numbers", () => {
	rejects(["--timeout=0"], /--timeout must be a positive whole number/);
	rejects(["--timeout=-5"], /--timeout must be a positive whole number/);
	rejects(["--timeout=1.5"], /--timeout must be a positive whole number/);
	rejects(["--warmup=soon"], /--warmup must be a positive whole number/);
	rejects(["--logging-level=chatty"], /--logging-level must be a positive whole number/);
});

test("rejects unknown flags rather than ignoring them", () => {
	rejects(["--dynamic"], /Unknown option/);
});

test("--no-pull turns the image pull off", () => {
	assert.equal(parseOptions(["--no-pull"]).pull, false);
});

test("an explicit image wins over the branch's default", () => {
	const options = parseOptions(["--branch=x86-64", "--image=ghcr.io/example/runner:pinned"]);

	assert.equal(options.image, "ghcr.io/example/runner:pinned");
	assert.equal(options.branch, "x86-64");
});

test("accepts a digest-pinned image", () => {
	const digest = `ghcr.io/cfc-servers/gluatest@sha256:${"a".repeat(64)}`;
	assert.equal(parseOptions([`--image=${digest}`]).image, digest);
});

test("imageFor mirrors GLuaTest's per-branch image names", () => {
	assert.equal(imageFor("live"), "ghcr.io/cfc-servers/gluatest:latest");
	assert.equal(imageFor("x86-64"), "ghcr.io/cfc-servers/gluatest/64bit:latest");
	assert.equal(imageFor("dev"), "ghcr.io/cfc-servers/gluatest/dev:latest");
	assert.equal(imageFor("prerelease"), "ghcr.io/cfc-servers/gluatest/prerelease:latest");
});

test("tagList splits, lower-cases and de-duplicates", () => {
	assert.deepEqual(tagList(["Default, strings", "default", ""], "tag"), ["default", "strings"]);
});

test("describe names only the filters that are in play", () => {
	const base = {mode: "all", trial: null, includeTags: [], excludeTags: [], iterations: "default"};

	assert.equal(describe(base), "mode=all iterations=default");
	assert.equal(describe({...base, excludeTags: ["slow"]}), "mode=all skip-tags=slow iterations=default");
});
