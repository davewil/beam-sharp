# The clean-room handoff

This directory holds the material for giving beam-sharp to someone who does not
have this repository's history, its author, or its conversations — a new
maintainer, or an agent fleet asked to implement the language from the
specification alone.

## Build the package

```
./bin/build-handoff.sh --out <dir>
```

One command, from a fresh clone, and the only definition of what goes in is
[`MANIFEST`](MANIFEST). The result is a directory the recipient can be handed
whole: the specification, the compiler's feature record, the example corpus that
acts as its oracle, and a `MANIFEST.lock` naming the source revision, the pinned
toolchain, and a SHA-256 for every file.

## Verify it

```
./bin/check-handoff-package.sh
```

Assembles the package into a temporary directory **outside the source tree** and
asks six questions of it: that the manifest covers what is on disk, that the
artifact contains what the manifest names, that every reference inside it can be
followed without the repository, that provenance is recorded and true, that two
builds to different paths agree, and that the artifact's examples still compile
against the reference compiler.

Both scripts carry `--self-test`, and neither is believed without it.

## What does not ship, and why the package says so

`wayfinder/` — 4.1M of tickets, research and prototypes — is deliberately
excluded. A recipient implements from `LANGUAGE.md`, not from the argument that
produced it.

That exclusion used to leak. Measured 2026-08-26, the shipping documents carried
**115 references into `wayfinder/`**, 98 of them across 27 of the 28 feature
files, every one a live link in the source tree and a dead pointer in a
recipient's hands. `build-handoff.sh` flattens them at assembly: the visible text
survives, the target is dropped, so a feature file still records which ticket it
implements without pointing at a file nobody was given.

Prose naming the excluded directory is left alone on purpose. `LANGUAGE.md`
telling its reader they have "no access to `wayfinder/`" is the package
explaining its own boundary, and that sentence is why a recipient does not go
looking.

## The audition

[`audition-switch/`](audition-switch/) is a bounded clean-room trial over the
`switch` slice. It is evidence about that slice and not about the language, and
its README says so. It does not ship inside the package.
