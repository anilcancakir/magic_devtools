# Changelog

All notable changes to this package are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Documentation pages.** `doc/` now covers installation and the two-phase install, the tapir integration (the 14 snapshot enrichers and the navigate adapter), the crumbs integration (HTTP capture, the five watchers, credential masking and the tapir bridge), performance sessions and the insight rules, the preview catalog, and testing. The docs site publishes them under `https://anilcancakir.com/magic/docs/devtools/` from the next release. (`doc/`)
- **A docs check.** `python3 tool/check-docs.py` checks the page layout, titles, internal links, anchors and docs-site URLs offline, and the `Internal Links` and `External Links` jobs run it and lychee in CI. (`tool/check-docs.py`, `.github/workflows/docs-link-check.yml`, `.lycheeignore`, `.claude/rules/docs.md`)
- **`llms.txt` for AI coding agents.** A summary, the setup, the API of each barrel, the platform notes, the rules an agent follows and one line per doc page. `python3 tool/check-docs.py` resolves its doc lines against `doc/`, and the weekly `External Links` job checks its URLs. (`llms.txt`, `tool/check-docs.py`, `.github/workflows/docs-link-check.yml`)
- **An agent skill.** `skills/magic-devtools/SKILL.md` carries the install, the rules for each integration with their reasons, recipes and the test resets; install it with `npx skills add anilcancakir/magic_devtools`. A stable release mirrors it into the skill registry. (`skills/magic-devtools/SKILL.md`, `.github/workflows/dispatch-to-registry.yml`, `.github/workflows/publish.yml`)
- **A runnable example.** `example/` wires both tools around `Magic.init()` with `MagicDevtools`, registers a two-entry preview catalog, and has buttons that give tapir and crumbs a request and a `debugPrint` to record. (`example/`)

### Changed

- **The package page points to the new home.** The pub.dev homepage is now `https://anilcancakir.com/magic/devtools`, the repository and issue tracker are `github.com/anilcancakir/magic_devtools`, the description says what the package wires and that release builds drop it, and the package lists the `devtools`, `debugging`, `testing`, `observability` and `magic` topics. (`pubspec.yaml`)
- **`MagicPreview.registerRoutes()` documents what a late call does.** A call after `MagicRouter.instance.routerConfig` was first read throws the router's `StateError`; the doc comment used to say the routes silently never appear. (`lib/preview.dart`, `lib/src/preview/preview_routes.dart`)
- **API docs read cleanly on pub.dev.** The enricher formats in `MagicTapirIntegration` and the query binding note in `MagicCrumbsIntegration` are code spans, so dartdoc no longer reads `<Class>`, `<bool>` or `List<dynamic>` as HTML, and `MagicEventWatcher` describes its empty payload without pre-release wording. (`lib/src/tapir_integration.dart`, `lib/src/crumbs_integration.dart`)
- **The license names the author as `Anılcan Çakır`.** (`LICENSE`)
- **The README is rewritten around what each integration does and how it fails.** It now opens with an at-a-glance table, gives each integration a sample, a member table and its failure modes, adds a table of rules for AI coding agents, and links the new home on `anilcancakir.com` and `github.com/anilcancakir`. (`README.md`)
- **The README no longer misstates four things.** `crumbs:install` writes its block under `!kReleaseMode`, not `kDebugMode`, so a profile build carries crumbs; the preview catalog shows one preview at a time with a light and dark toggle, rather than every preview in both themes; a `registerRoutes()` call after the router is built throws the router's `StateError` instead of silently adding nothing; and local development against sibling clones uses absolute paths in `pubspec_overrides.yaml`, since a relative `../magic` does not resolve from a worktree. The README also says that `tapir:snap --includeEnrichers` fails in an app with no `auth` binding. (`README.md`)

## [1.0.0] - 2026-11-14

### BREAKING

- **Needs core `magic` `^1.0.0`.** That release moves to `dowel`, `wind_kit` and `material_ui`, and raises the floors to Dart 3.13 and Flutter 3.47, which this package now shares. `fluttersdk_wind` is now `wind_kit` (`^1.12.0`), and `material_ui` (`^1.11.0`) replaces `package:flutter/material.dart` in `lib/` and `test/`. (`pubspec.yaml`, `lib/`, `test/`)
- **`fluttersdk_dusk` and `fluttersdk_telescope` are replaced by `tapir ^1.0.0` and `crumbs ^1.0.0`.** Both old packages are discontinued upstream. The barrels `package:magic_devtools/dusk.dart` and `package:magic_devtools/telescope.dart` become `tapir.dart` and `crumbs.dart`, `MagicDuskIntegration` becomes `MagicTapirIntegration` and `MagicTelescopeIntegration` becomes `MagicCrumbsIntegration`, with no alias left under the old names. `MagicDevtools.installPre()` and `installPost()` keep their signatures and now install `TapirPlugin` and `CrumbsPlugin`. The perf zone key an interaction is read from is tapir's `#tapir_interaction`, and the `tapir:install` and `crumbs:install` commands wire these integrations into `lib/main.dart` once this release is resolved. The three enrichers that read recent HTTP, log and exception records, and the three reader pointers `MagicCrumbsIntegration` assigns, now read `CrumbsStore`. (`pubspec.yaml`, `lib/tapir.dart`, `lib/crumbs.dart`, `lib/src/tapir_integration.dart`, `lib/src/crumbs_integration.dart`, `lib/src/perf_integration.dart`, `lib/src/magic_devtools.dart`)

### Changed

- **First stable release:** version 1.0.0 replaces the planned 0.0.12 and requires `magic ^1.0.0`, `magic_socket ^1.0.0`, `tapir ^1.0.0` and `crumbs ^1.0.0`; no API change beyond what is listed here.
- **Depends on `magic_socket` and `magic ^1.0.0`.** Core no longer ships `Echo` and the broadcasting layer, so `MagicTapirIntegration` imports them from `magic_socket`; it still skips the Echo enricher when no `broadcasting` binding is registered. (`pubspec.yaml`, `lib/src/tapir_integration.dart`)
- **Direct dependencies raised to their latest releases.** `tapir ^1.0.0`, `crumbs ^1.0.0` and dev `flutter_lints ^6.0.0`. (`pubspec.yaml`)
- **tapir reads Wind through the contract `wind_kit` publishes.** tapir looks Wind's debug data up through `wind_kit_diagnostics_contracts`, so the mismatch the dusk 0.0.23 pairing had with `fluttersdk_wind_diagnostics_contracts` no longer exists. The app still calls `Wind.installDebugResolver()` itself (tapir's installer does not write that line), and this package changed no code for it. (`pubspec.yaml`)

### Fixed

- **`MagicDevtools.installPre()` registered the exception and dump watchers on every call.** `registerWatcher` takes a new instance each time and the watchers guard per instance, so a second call (or a lazy debug toggle) chained a second pair onto the first and recorded every exception and `debugPrint` twice. The class now keeps the pair it registered and adds none on a later call; `MagicDevtools.resetForTesting()` uninstalls it for tests. (`lib/src/magic_devtools.dart`, `test/magic_devtools_test.dart`)
- **The docs called this package a `dev_dependency`, and claimed more than the installers do.** `lib/main.dart` imports it, so it is a regular dependency under `!kReleaseMode`; the README now says what `tapir:install` and `crumbs:install` write (single-tool blocks, crumbs under `kDebugMode`, no `MagicDevtools` or `MagicPerfIntegration`), and its Crumbs snippet registers the exception and dump watchers. (`README.md`, `CLAUDE.md`, `lib/tapir.dart`, `lib/crumbs.dart`)
- **`MagicCacheWatcher` documented itself as a no-op.** It has subscribed to `CacheHit`, `CacheMiss`, `CachePut`, `CacheForget` and `CacheFlush` since magic added them; the class and section comments now say so. (`lib/src/crumbs_integration.dart`)
- **`MagicTapirIntegration` documented a first-write-wins rule tapir does not apply.** tapir writes every enricher fragment, so two enrichers emitting one key put both lines in the snapshot; the doc comments and `CLAUDE.md` now say to keep keys distinct. (`lib/src/tapir_integration.dart`, `CLAUDE.md`)

## [0.0.11] - 2026-10-14

### Changed

- **Every sibling floor names this batch's release.** `magic` moves `^0.0.28` to `^0.0.29` and `fluttersdk_wind` `^1.8.4` to `^1.9.0`; `fluttersdk_dusk` stays at `^0.0.20` and `fluttersdk_telescope` at `^0.0.12`. The old ranges already admitted the new versions, so a fresh `pub get` resolves nothing differently; what changes is that the floors name the releases this package is verified against. magic 0.0.29 adds two abstract members to `BroadcastChannel` and a `webOnlyWindowName` named parameter to `LaunchAdapter.launch()`, and this package implements neither; wind 1.9.0 makes `tracking-*` em, scaled by the rendered font size, and this package writes no `tracking-*` class. The README install snippet quotes the new devtools pin. (`pubspec.yaml`, `README.md`)

## [0.0.10] - 2026-10-13

### Changed

- **Every sibling floor names this batch's release.** `magic` moves `^0.0.27` to `^0.0.28`, `fluttersdk_dusk` `^0.0.19` to `^0.0.20`, `fluttersdk_telescope` `^0.0.10` to `^0.0.12` and `fluttersdk_wind` `^1.8.1` to `^1.8.4`. The old ranges already admitted the new versions, so a fresh `pub get` resolves nothing differently; what changes is that the floors name the releases this package is verified against. None of magic 0.0.28, dusk 0.0.20, telescope 0.0.11 and 0.0.12 or wind 1.8.2 to 1.8.4 is breaking for this package: dusk 0.0.20 and telescope 0.0.12 only move to artisan 0.0.20, whose connected commands print one retry line and exit 75 when an extension is not registered yet; wind 1.8.2 restores the click cursor under `hover:`, which the preview catalogue's navigation rows use, and 1.8.3 adds `autofillHints`, which this package does not call. The README install snippet quotes the new devtools, dusk and telescope pins. (`pubspec.yaml`, `README.md`)

## [0.0.9] - 2026-10-09

### Changed

- **Every sibling floor names this batch's release.** `magic` moves `^0.0.24` to `^0.0.27`, `fluttersdk_dusk` `^0.0.17` to `^0.0.19`, `fluttersdk_telescope` `^0.0.9` to `^0.0.10` and `fluttersdk_wind` `^1.8.0` to `^1.8.1`. The old ranges already admitted the new versions, so a fresh `pub get` resolves nothing differently; what changes is that the floors name the releases this package is verified against. None of magic 0.0.25 to 0.0.27, dusk 0.0.18 and 0.0.19, telescope 0.0.10 or wind 1.8.1 is breaking. The README install snippet quotes the new dusk and telescope pins. (`pubspec.yaml`, `README.md`)

## [0.0.8] - 2026-09-29

### Security

- **The HTTP adapter no longer hands telescope a login's password or token.** It stringified request and response bodies with `toString()`, and a Dart `Map` prints as `{email: a@b.test, password: hunter2}`, which telescope's JSON masking cannot read, so a login body and a Sanctum login answer reached the agent-facing buffer in the clear. `onRequest`, `onResponse` and `onError` now mask the body with telescope's hidden request or response parameters before truncating it (`TelescopeRedaction.redactParameters` for a Dart structure, `redactBody` for a JSON string, which would otherwise stop parsing once cut at 8 KB); the masked copy is what gets recorded, and the request object the driver sends on is never touched. `MagicTelescopeIntegration.install()` also hides the header magic's `AuthInterceptor` writes the token under, read from `auth.token.header` (default `Authorization`), so a renamed header is masked too, and it does so on every call, since a telescope store reset drops the addition. Needs the telescope release that ships `TelescopeRedaction`. (`lib/src/telescope_integration.dart`)

### Changed

- **The floors name the releases this work needs.** `magic` moves `^0.0.22` to `^0.0.24` (`MagicPerfHooks`, the request ids, `AuthRestored.changed`, and the removal of `onRefreshUI`), `fluttersdk_dusk` `^0.0.16` to `^0.0.17` (`PerfMode` and the interaction readers), `fluttersdk_telescope` `^0.0.7` to `^0.0.9` (`TelescopeRedaction` and the record link fields) and `fluttersdk_wind` `^1.7.0` to `^1.8.0` (the size-only `MediaQuery` read the `mediaQuerySize` insight describes). Each is a real requirement: this release does not compile, or describes the wrong behaviour, below it. The README install snippet quotes the new dusk and telescope floors. (`pubspec.yaml`, `README.md`)
- **BREAKING: the perf path reads magic through `MagicPerfHooks.sink`, and `MagicController.onRefreshUI` is gone.** `MagicPerfIntegration` no longer hooks a single notify site: its session begin hook installs the sink for an attribution session only (a timing session, and an app between sessions, allocate no event and leave wind counting off), and the end hook removes it. `perfExtrasReader` returns dusk's documented key set: `controllerNotifies`, `notifyCauses`, `queryReloads`, `actions`, `events`, `casts`, `timerTicks`, `broadcasts` and `routeTransitions`. Needs the magic, dusk, telescope and wind releases that ship `MagicPerfHooks`, `PerfMode`, record links and per-type wind counters. (`lib/src/perf_integration.dart`)
- **HTTP records pair by request id.** The telescope interceptor matches each response or error to its request through `MagicRequest.id` / `MagicResponse.id` / `MagicError.id`, so two requests completing out of order keep their own URL and duration; only an answer without an id (a hand-built one; `Http.fake` installs no interceptors) falls back to the oldest request in flight that has no id either, with `attributedHeuristically: true`. A request with an id is never handed to an id-less answer, since its own answer would then find nothing to pair with and be dropped. Records carry `requestId`, `startUs` and `endUs`. (`lib/src/telescope_integration.dart`)
- **A span is linked from when it began, not when it ended.** `QueryReloaded`, `ActionRan` and `EventDispatched` arrive at span end, so resolving the link then dropped a reload that outlived its tap and gave one that ended during the next tap to that tap. `MagicPerfIntegration.interactionLink({startUs})` now accepts the zone handle when its window `[startUs, closedAtUs ?? now]` holds the span's start (closed or not), else dusk's `perfInteractionAt(startUs)` (`frame`), else `window`; an instant with no start keeps the open-handle and active-interaction rules. The `zoneInteractionId` test seam becomes `zoneInteraction` (it returns the handle's window), with a new `interactionIdAt` seam beside `activeInteractionId`. Needs the dusk release that exports `perfInteractionAt`. (`lib/src/perf_integration.dart`)
- **The `mediaQuerySize` insight describes a size-only subscription.** wind now reads `MediaQuery.sizeOf`, so a counted read rebuilds its widget on a resize or a rotation and not on a keyboard inset; the summary and next step said every MediaQuery change, which is no longer true. The metric name, threshold and firing rule are unchanged. (`lib/src/perf_insight_rules.dart`)

- **The install guard is `!kReleaseMode`.** `MagicDevtools.installPre` / `installPost` and the per-tool blocks are documented under `!kReleaseMode` instead of `kDebugMode`, so a profile build carries dusk and telescope and a perf measurement can run on it; release still tree-shakes both, and the guard still belongs at the call site. `lib/src/dusk_integration.dart` and `lib/src/perf_integration.dart` already said so, and the rest of the package said `kDebugMode`. Apps wired under `kDebugMode` keep working in debug and simply carry no tooling in profile. (`CLAUDE.md`, `README.md`, `lib/magic_devtools.dart`, `lib/dusk.dart`, `lib/telescope.dart`, `lib/src/magic_devtools.dart`, `lib/src/telescope_integration.dart`)

### Added

- **Interaction links on every record.** HTTP, query, event, model and cache records, and every sink row, carry `interactionId` and `linkedBy`: `zone` when the work read an open dusk interaction off its own zone, `frame` when it ran in the frame zone and joined dusk's active interaction, `window` when neither. `MagicPerfIntegration.interactionLink()` is the one rule. Gate records are not stamped: telescope's `GateRecord` has no link fields. (`lib/src/perf_integration.dart`, `lib/src/telescope_integration.dart`)
- **`perfTimelineReader` and `perfInsightContributors` are assigned.** The timeline reader returns the sink rows (notifies, query reloads, actions, event dispatches, timer ticks, broadcasts) plus one row per telescope HTTP, query, event, model and cache record, in dusk's row schema. The contributor runs `PerfInsightRules`: wind wrapper emissions per W-widget build, `mediaQuerySize` reads per frame, parse misses on a warm surface, notify storms by cause, timer-driven notifies per second, uncached query reloads per interaction, attribute casts per frame, and HTTP requests per interaction. Every rule states its threshold in `evidence.threshold` and normalises by painted frames. (`lib/src/perf_insight_rules.dart`)

## [0.0.7] - 2026-09-27

### Changed

- **Every sibling floor names this batch's release.** `magic` moves `^0.0.16` to `^0.0.22`, `fluttersdk_dusk` `^0.0.15` to `^0.0.16` and `fluttersdk_wind` `^1.6.3` to `^1.7.0`; `fluttersdk_telescope` stays at `^0.0.7`, still the newest. The old ranges already admitted the new versions, so a fresh `pub get` resolves nothing differently; what changes is that the floors name the releases this package is verified against. Of magic 0.0.22's BREAKING changes, the one that reaches this package is `Auth.fake()` dispatching `AuthLogin`/`AuthLogout` through the real `Event` facade, which only its tests call; the suite passes unchanged. dusk 0.0.16 stops `dusk:fill`/`dusk:type`/`dusk:clear` writing into a field on a covered route. (`pubspec.yaml`, `README.md`)

## [0.0.6] - 2026-09-22

### Changed

- **Every sibling floor names this batch's release.** `magic` moves `^0.0.15` to `^0.0.16`, `fluttersdk_telescope` `^0.0.6` to `^0.0.7` and `fluttersdk_wind` `^1.6.2` to `^1.6.3`; `fluttersdk_dusk` stays at `^0.0.15`, still the newest. The old ranges already admitted the new versions, so a fresh `pub get` resolves nothing differently; what changes is that the floors name the releases this package is verified against. telescope 0.0.7 is a documentation fix, and nothing in wind 1.6.3 or magic 0.0.16 touches an API this package calls. (`pubspec.yaml`, `README.md`)

## [0.0.5] - 2026-09-21

### Changed

- **Every sibling floor names this batch's release.** `magic` moves `^0.0.7` to `^0.0.15`, `fluttersdk_dusk` `^0.0.12` to `^0.0.15`, `fluttersdk_telescope` `^0.0.5` to `^0.0.6` and `fluttersdk_wind` `^1.5.0` to `^1.6.2`. The old ranges already admitted the new versions, so a fresh `pub get` resolves nothing differently; what changes is that the floors name the releases this package is verified against. magic 0.0.15 is breaking in its database layer (a migration may no longer manage its own transaction, and `DB.transaction` refuses a callback that closes the transaction itself); nothing in this package calls either, so no code here changes, but an app below magic 0.0.15 no longer resolves this release. (`pubspec.yaml`)

## [0.0.4] - 2026-08-25

### Added

- `MagicPerfIntegration`: the wiring that assembles the performance-diagnostic
  data path across four packages. It sets `MagicController.onRefreshUI` to a
  counter keyed by controller runtime type, registers a `NavigatorObserver`
  through `MagicRouter.addObserver` that times each route push to the first
  post-frame callback after the new route builds, calls
  `Wind.installPerfResolver()`, registers telescope's `FramePerfWatcher`, and
  assigns the four `fluttersdk_dusk` pointers (`framePerfReader`,
  `perfExtrasReader`, `perfSessionBeginHook`, `perfSessionEndHook`). This
  package is the only place dusk, telescope, wind and magic are all visible at
  once, so it is the only place those pointers can be assigned; dusk declares
  them with no-op defaults and never imports the packages it reports on.
- `MagicDevtools.installPre()` now installs `MagicPerfIntegration`. It belongs
  in the pre-`Magic.init()` half because `MagicRouter.addObserver` throws once
  the router has been built, and that `StateError` is deliberately not caught:
  a silently unregistered observer would produce a report with no route
  transitions and nothing to explain their absence.

### Changed

- **The four sibling dependency floors now state what the code actually needs.**
  They were `magic: ^0.0.6`, `fluttersdk_dusk: ^0.0.9`,
  `fluttersdk_telescope: ^0.0.4` and `fluttersdk_wind: ^1.2.1`, and every one of
  them was below the release that introduced an API `MagicPerfIntegration` calls:
  `MagicController.onRefreshUI` arrived in magic 0.0.7, the four
  `perf_readers.dart` pointers in dusk 0.0.12, `FramePerfWatcher` and
  `TelescopeStore.recentFramePerf` / `clearFramePerf` in telescope 0.0.5, and
  `WindPerfCounters` with `Wind.installPerfResolver()` in wind 1.5.0.

  A caret range resolves to the newest version available, so a fresh resolution
  always picked up the right siblings and CI stayed green. A consumer whose own
  constraints hold one of them back would not: pub would report the graph as
  satisfiable and the build would then fail on undefined symbols. That is not
  hypothetical, it is what this branch's own CI did while `^1.2.1` was still
  resolving wind 1.4.1, with 18 errors all naming `WindPerfCounters` or
  `installPerfResolver`. Now `^0.0.7`, `^0.0.12`, `^0.0.5` and `^1.5.0`.

## [0.0.3] - 2026-08-05

Documentation only; no runtime change. The package code is identical to 0.0.2.

### Changed

- The README install snippet pins the versions actually shipped rather than a
  looser range, so a copy-paste resolves to the combination this package is tested
  against.
- `.github/workflows/publish.yml` names the pub.dev prerequisite it cannot check
  for itself. Automated publishing has to be enabled per package on pub.dev, and
  without it a tag gets all the way through validate, a clean `--dry-run` and the
  upload before pub.dev refuses; that is what left 0.0.2 unpublished for a week
  while consumers requiring `^0.0.2` could not resolve at all. That setting is still
  off, so this release was published by hand as well.

## [0.0.2] - 2026-07-29

### Added

- `MagicDevtools` umbrella wiring: a new `package:magic_devtools/magic_devtools.dart`
  barrel exposing `MagicDevtools.installPre()` / `MagicDevtools.installPost()`.
  `installPre` boots both tool plugins and registers telescope's opt-in
  `ExceptionWatcher` + `DumpWatcher` (call before `Magic.init()`); `installPost`
  wires `MagicTelescopeIntegration` + `MagicDuskIntegration` (call after
  `Magic.init()`). Collapses the previous four `kDebugMode` blocks in a host's
  `lib/main.dart` into two, while preserving the load-bearing pre/post ordering
  and the call-site `kDebugMode` guard (moving the guard inside would defeat the
  release tree-shake).
- `MagicPreview` framework: a dev-only component preview catalog hosted via two
  plain pages (`/preview` and `/preview/:component`). New
  `package:magic_devtools/preview.dart` barrel exports
  the `PreviewEntry` contract (`label`, `slug`, `builder`), the
  `MagicPreviewCatalog` widget (a scrollable sidebar next to a SINGLE active
  preview pane — tapping a sidebar item, or deep-linking `/preview/<slug>`,
  swaps the pane to that entry; only the selected preview is mounted, so a
  large screen-heavy catalog stays responsive — plus a global light/dark toggle
  bound to wind's `WindTheme.of(context).toggleTheme()`),
  and the `MagicPreview` registration entrypoint (`register` plus `registerRoutes`).
  The route, catalog, and every registered `PreviewEntry` are reachable only
  through `MagicPreview.registerRoutes`, which is guarded by `kReleaseMode` plus
  `const bool.fromEnvironment('PREVIEW_ENABLED', defaultValue: kDebugMode)`, so
  the whole surface const-folds dead and tree-shakes out of release builds.
  Entries are held in a function-scoped list (never a top-level const, the
  dart-lang/sdk#33920 foot-gun). The generated `_previews.g.dart` (Step 18) feeds
  a `List<PreviewEntry>` into `MagicPreview.register`. Consumers must call
  `MagicPreview.registerRoutes()` from a provider `boot()` BEFORE the router locks
  on first `routerConfig` access, else `/preview` silently never registers.
- `fluttersdk_wind` is now a direct dependency (the catalog renders on
  `WDiv`/`WText`/`WAnchor` and binds the theme toggle to `WindThemeController`).
- `MagicDuskIntegration.install()` now registers a navigate adapter via
  `DuskPlugin.registerNavigateAdapter` so `ext.dusk.navigate --route <path>`
  drives GoRouter through `MagicRouter.instance.to(path)` instead of falling
  back to the `SystemNavigator` platform broadcast. Returns `true` on success
  and `false` when the router is not yet initialised (catches `StateError`).
  `resetForTesting()` clears the adapter with `DuskPlugin.registerNavigateAdapter(null)`.

### Fixed

- **`/preview/<slug>` deep links now select the right entry**: the catalog moved off a persistent ShellRoute (which did not rebuild when only the child route swapped, leaving every deep link stuck on the first entry) to two plain pages; the `/preview/:component` builder receives the slug and rebuilds on navigation. Known dev-only limitation: feature-SCREEN previews (full controller-backed `MagicStatefulView`s) emit a couple of non-fatal `setState() during build` warnings because the catalog mounts the same screen in both the light and dark panes sharing a singleton controller; the screens render correctly and the real app routes are clean (the catalog is stripped from release).
- **`/preview` route no longer crashes the app**: the catalog group's index child path was `/` which composed to `/preview/`, tripping go_router's `route path may not end with '/'` assertion and blanking the entire app on every route. Changed the index child path to `''` so the composed path is exactly `/preview`.
- **Catalog previews now inherit the host theme**: each light/dark pane copied a bare `WindThemeData` that carried no aliases, so component semantic tokens (`text-fg`, `bg-surface`, ...) resolved to no-ops and every preview rendered Flutter's red unstyled-text fallback. Panes now `copyWith(brightness:)` the ambient app theme, preserving aliases and brand colors.
- **Catalog overflow**: the preview surface now scrolls vertically and each pane scrolls horizontally, so wide variant matrices no longer trigger RenderFlex overflows in the side-by-side light/dark layout.

## [0.0.1] - 2026-06-17

### Added

- Initial release, extracted from the `magic` package. `MagicDuskIntegration`
  (14 enrichers for `fluttersdk_dusk` snapshots) and `MagicTelescopeIntegration`
  (5 watchers plus `MagicHttpFacadeAdapter` for `fluttersdk_telescope`) now live
  here as a dedicated, debug-only dev-tooling adapter rather than as sub-barrels
  of `magic`.
- Two import barrels: `package:magic_devtools/dusk.dart` and
  `package:magic_devtools/telescope.dart`.
- The relocated enricher and watcher test suites moved over unchanged.

### Note

- Local development resolves the `magic`, `fluttersdk_dusk`, and
  `fluttersdk_telescope` siblings through `dependency_overrides` path entries.
  Those overrides are dev-only; version pins replace them at publish (the
  publish-time pubspec is user-owned).
