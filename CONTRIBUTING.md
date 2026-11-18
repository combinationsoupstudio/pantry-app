# Contributing

## Workflow
Idea, spec, build, test, release. The full rules for people and AI assistants are in [CLAUDE.md](CLAUDE.md).

1. Start from a GitHub issue: the idea, the spec, a *Done when* checklist, what is out of scope.
2. Branch from `main`, named for the issue: `feat/30-recipes-pack-2`, `fix/41-…`, `docs/…`, `chore/…`.
3. Commit with [Conventional Commits](https://www.conventionalcommits.org/), naming the issue: `feat(recipes): pack 2 (#30)`.
4. Open a pull request that says `Closes #<issue>`. Fill in the template.
5. CI must be green: formatting, analysis with no infos, all tests, APK build.
6. Squash merge into `main`. Delete the branch.

## Code
- Every change to household data goes through `HouseholdStore`. Pages never edit lists directly.
- Logic that can be pure Dart lives in `lib/logic/` and has unit tests.
- New behaviour comes with a test. Widget tests run at phone size (411 x 914 dp).
- Run `dart format lib test` before committing. Line width is 120.
- Australian English in the interface.

## Decisions
A change to architecture, storage, a vendor or the release process gets an ADR in `docs/adr/`, numbered in order: context, options, decision, consequences.
