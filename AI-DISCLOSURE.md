# AI assistance

This repository is written with AI assistance.
This file says so plainly, so you don't have to work it out from the commit log.

## The short version

Most of the code here was written by me and Claude, working together.
Typically, AI assisted commits are attributed as such in git — nothing was
tidied up after the fact, and nothing is generated and shipped unread.

## What AI does

- Assists in writing code to my specifications.
- Writes documentation: code, design and specification.
- Writes tests to cover code paths.
- Diagnoses and fixes issues.

AI was also used to rebuild the design, based on my brand design.

## Who is responsible

> A computer can never be held accountable, therefore a computer must never
> make a management decision.
>
> — IBM training manual, 1979

Claude is a co-author; it is not accountable, I am.

Changes land through pull requests, and I read and merge each one. CI runs
the GLuaTest suites in a real Garry's Mod server on every push and pull
request, glualint enforces the house style, and releases are automated and
carry signed build provenance — see
[Releases and provenance](README.md#releases-and-provenance).

None of that makes a review infallible. AI code can be well-written, making
it easy to skim past — though that is the same issue as human-written PRs.
The bar is whether I, the test suite or my own use catches any issues, not
any formal auditing.

## If you contribute

Please properly attribute your code. If an AI agent worked on your patch, add
a `Co-Authored-By:` footer naming it, and say so in the pull request if it
wrote most of it. Nobody will think less of the contribution for it.
