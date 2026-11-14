# CLAUDE.md

Guidance for Claude Code working inside the `magic_devtools` repo. Path-scoped rules live in `.claude/rules/`.

## What this package is for, and why it is a package at all

`magic_devtools` is the seam between `magic` and the dev tooling: the adapters that wire `tapir` and
`crumbs` into a running Magic app, plus a dev-only component preview catalog.

It exists so that `magic` core keeps ZERO dependency on tapir and crumbs: a production app depends on
magic without dragging an E2E driver and a runtime inspector into its resolution graph. Every consumer
adds this package as a regular dependency imported only under `!kReleaseMode` (a dev_dependency would
trip `depend_on_referenced_packages`), so release builds tree-shake it.

Every install call is guarded by `!kReleaseMode` AT THE CALL SITE, in the consumer's `main.dart`, and
never inside a method here (debug and profile builds carry the tools, so a perf measurement runs on a
profile build). Moving the guard inward defeats the release tree-shake and pulls both tools into the
production bundle, the one failure this package's whole shape is arranged to prevent.

## Stack

Flutter package. Dart >=3.13.0, Flutter >=3.47.0. Runtime deps: `magic`, `magic_socket`, `tapir`,
`crumbs`, `wind_kit`, `material_ui`. No code generation.

tapir and crumbs depend on neither magic nor each other (tapir reads wind only through
`wind_kit_diagnostics_contracts`), so anything that joins them is assembled here: tapir reads crumbs
through function pointers this package assigns (`pendingHttpCountReader`, `recentLogsReader`,
`recentExceptionsReader` from `MagicCrumbsIntegration`, the perf readers from `MagicPerfIntegration`),
and three of the fourteen enrichers read `CrumbsStore` directly. `lib/` reaches `wind_kit` through
magic's barrel, except `lib/src/preview/`, which imports it directly.

## Commands

CI gates: `flutter analyze --no-fatal-infos`, `dart format --set-exit-if-changed .` (run it before
pushing: a branch that never ran the formatter fails there and nowhere earlier) and
`flutter test --coverage`. Pre-publish: `dart pub publish --dry-run`.

Local sibling development goes through the gitignored `pubspec_overrides.yaml` with ABSOLUTE paths
(`.worktreeinclude` explains why). The committed `pubspec.yaml` stays on hosted caret constraints so a
fork outside this workspace resolves on its own.

## Barrels

Four, and the split is the API: `magic_devtools.dart` (the umbrella `MagicDevtools.installPre` /
`installPost` pair, what a consumer imports), `tapir.dart` (`MagicTapirIntegration`: 14 snapshot
enrichers plus the `MagicRouter` navigate adapter), `crumbs.dart` (`MagicCrumbsIntegration`: 5 Magic
watchers plus `MagicHttpFacadeAdapter`) and `preview.dart` (the component preview catalog). Reach for a
narrow barrel only when wiring one tool without the other, or when a host wants a non-standard watcher
set.

## The two-phase install is a contract, not a convenience

`installPre` runs BEFORE `Magic.init()`; `installPost` runs after. Neither half can move.

- **Pre** boots `TapirPlugin` and `CrumbsPlugin` and registers crumbs' opt-in `ExceptionWatcher`
  and `DumpWatcher`. It has to be early so the snapshot pipeline and the exception watcher are already
  live while Magic boots: they capture boot-time errors and the first route resolve, which is exactly
  the window a later install misses.
- **Post** wires Magic's runtime in. Its watchers, HTTP adapter and enrichers resolve dependencies
  through the IoC container (`Magic.find` / `Magic.bound`), so `Magic.init()` must have completed.

When adding wiring, decide which half it belongs to by asking what it resolves, not by which reads
tidier. Anything that touches the container is post. Anything that has to observe Magic booting, or
that registers with a subsystem which locks its table on first read (the router does), is pre.

Every install here is idempotent, so a second call in the same isolate is safe. Keep it that way: a
consumer with a lazy debug toggle will call twice.

## Enrichers and watchers

An enricher is `String? Function(Element, RefRegistry)`, tapir's frozen typedef. It is synchronous and
stateless, and it must NEVER retain the `Element` across calls. `MagicTapirIntegration.resetForTesting()`
removes each enricher it added, one by one, so an enricher added to the install list without a matching
removal leaks into the next test. tapir does not deduplicate snapshot keys: two enrichers emitting the
same key put both lines in the output, so keep every key distinct.

A watcher implements crumbs' `CrumbsWatcher` contract (`name`, `install()`, `uninstall()`).
Dependency direction is one way and stays one way: `magic_devtools` depends on the crumbs and tapir
contracts, and neither of those ever depends on magic.

## Golden rules

1. `flutter analyze` clean, `dart format` zero diff, `flutter test` green, all three before pushing.
2. TDD, red then green: a behaviour change gets a failing test that fails for the right reason first.
3. `CHANGELOG.md` gets a bullet under `## [Unreleased]` for every behavioural or interface change.
4. Never add a dependency that would let magic core reach tapir or crumbs, and never move a
   `!kReleaseMode` guard inside this package.

## Branching

One long-lived `master`. Task branches (`feat/*`, `fix/*`, `docs/*`, `chore/*`) cut from master, PR
back into master. Release bumps `pubspec.yaml` and promotes `## [Unreleased]`, then a tag triggers
`publish.yml`.

## Style

- English only. Types everywhere. Docblocks on every public class and contract, saying WHY rather than
  restating the signature.
- Multi-line collections with trailing commas, 120-character lines, no linter suppressions.
- No em-dash or en-dash anywhere, including commits and PR bodies: comma, colon, semicolon, period or
  parentheses instead.
