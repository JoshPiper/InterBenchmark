# Security Policy

## Purpose

This document exists to:
- Say where to send a vulnerability report.
- Define what's in scope and what isn't.
- Set honest expectations for response time.

---

## Supported versions

Latest release only. No maintained LTS branch — a fix ships on top of current `main` in the next release.

---

## Reporting a vulnerability

**Don't open a public issue for this, and don't post it in a Discord channel.**

**[Report a vulnerability](https://github.com/JoshPiper/InterBenchmark/security/advisories/new)** — GitHub's private advisory flow, visible only to me and you until it's resolved. No GitHub? Open a normal issue asking for another contact, without report details in it.

Include, if you can:
- The version and build affected — the `Suite Version` and `Suite Build` rows of `internet_benchmark_environment`, or of the report's Environment page.
- Which realm it happens in (server, client, or across the bridge), and whether the addon came from a packaged release or a clone.
- Steps to reproduce, or a minimal repro.
- The impact — code execution in the game process, a read or write outside the addon's own output directory, a crash or hang, whatever it is.

Worth noting up front: this suite deliberately executes Lua and spends CPU doing it, so a benchmark run being expensive is the feature, not a vulnerability. Trials you add yourself are your own code, included and run on purpose — a trial that misbehaves is not a sandbox escape. Something that runs when it shouldn't, in a realm that shouldn't, or at the request of someone who shouldn't, is.

**This includes the `--realm` bridge working as designed.** Garry's Mod is server-authoritative, and the client handler for `ib_realm_request` accepts a request from whatever server you're connected to. With the addon installed clientside, any server you join can make your client run a benchmark: burn CPU, write a report into `garrysmod/data/internet_benchmarks/`, and open the report panel. That's the documented `--realm=client --target=...` feature, described in the [README](README.md#usage), and it's a matter of informed consent rather than a bug. Likewise, a `--realm=server` run returns a report that gets rendered in a `DHTML` panel — server-supplied HTML in a browser panel is what asking for a remote report *means*.

What is in scope on that bridge:
- A client that isn't a superadmin getting the server to run anything (the check lives in `BENCH:CanRunHere`).
- A crafted `ib_realm_request` or `ib_realm_result` that reaches either realm's handler and does more than run a shipped trial — executing attacker-chosen code or files, reading or writing outside `garrysmod/data/internet_benchmarks/`, or crashing or wedging the realm.
- A reply that is acted on without a matching outbound request, or one request's reply landing in another player's session.

---

## Scope

In scope:
- The addon's Lua under `lua/internet_benchmark/`, especially the net surface — `sh_realm.lua`, `sv_realm.lua`, `cl_realm.lua` — and the authorisation check in `sh_commands.lua`.
- The generated report. It inlines measured source, captured upvalues and environment data into a single HTML file; content that escapes into markup or script when that report is opened, in the in-game panel or a browser, is a vulnerability.
- The release pipeline (`.github/workflows/`) — a malicious `.gma` or `.zip` attached to a release under this project's name. See [Releases and provenance](README.md#releases-and-provenance) for how to verify a download.

Out of scope:
- Garry's Mod itself, its Lua sandbox, GLuaTest, or the optional [gm_sysinfo](https://github.com/JoshPiper/gm_sysinfo) module — report those upstream; gm_sysinfo has its own policy. Flag it here too if unsure, since a version bump or a defensive check is a small fix on this end regardless.
- The documented cost of a run — tickrate impact, disk writes to `data/internet_benchmarks/`, a client panel opening — when triggered by someone already allowed to trigger it.

---

## What to expect

No SLA — spare-time project. Credible reports get triaged fast. Give a fair window before public disclosure; credit goes in the release notes if you want it.
