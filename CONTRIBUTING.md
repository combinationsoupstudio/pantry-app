# Contributing

## Workflow
1. Branch from `main`: `feat/<short-name>`, `fix/<short-name>`, `docs/…`, `chore/…`.
2. Commit with [Conventional Commits](https://www.conventionalcommits.org/): `feat: move stock between locations`, `fix: clamp quantity at zero`.
3. Open a pull request. Fill in the template.
4. CI must be green: formatting, analysis with no infos, all tests, APK build.
5. Squash merge into `main`. Delete the branch.

## Code
- Every change to household data goes through `HouseholdStore`. Pages never edit lists directly.
- Logic that can be pure Dart lives in `lib/logic/` and has unit tests.
- New behaviour comes with a test. Widget tests run at phone size (411 x 914 dp).
- Run `dart format lib test` before committing. Line width is 120.
- Australian English in the interface.

## Decisions
A change to architecture, storage, a vendor or the release process gets an ADR in `docs/adr/`, numbered in order: context, options, decision, consequences.
