<h1 align="center">magic_devtools</h1>

<p align="center">
  <strong>Magic adapters for the tapir and crumbs dev tools.</strong><br/>
  Wire Magic's runtime into <a href="https://pub.dev/packages/tapir">tapir</a> (E2E driver) and <a href="https://pub.dev/packages/crumbs">crumbs</a> (runtime inspector), debug-only with zero release cost.
</p>

<p align="center">
  <a href="https://pub.dev/packages/magic_devtools"><img src="https://img.shields.io/pub/v/magic_devtools.svg" alt="pub package"></a>
  <a href="https://github.com/fluttersdk/magic_devtools/actions"><img src="https://img.shields.io/github/actions/workflow/status/fluttersdk/magic_devtools/ci.yml?branch=master&label=CI" alt="CI"></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT"></a>
  <a href="https://pub.dev/packages/magic_devtools/score"><img src="https://img.shields.io/pub/points/magic_devtools" alt="pub points"></a>
  <a href="https://github.com/fluttersdk/magic_devtools/stargazers"><img src="https://img.shields.io/github/stars/fluttersdk/magic_devtools?style=flat" alt="GitHub stars"></a>
</p>

<p align="center">
  <a href="https://magic.fluttersdk.com">Documentation</a> ·
  <a href="https://pub.dev/packages/magic_devtools">pub.dev</a> ·
  <a href="https://github.com/fluttersdk/magic_devtools/issues">Issues</a>
</p>

---

## What is magic_devtools?

`magic_devtools` is the Magic adapter layer for [`tapir`](https://pub.dev/packages/tapir) and [`crumbs`](https://pub.dev/packages/crumbs). It enriches tapir snapshots and crumbs records with Magic-aware context (forms, navigation, controllers, gates, auth, broadcasting, HTTP) so an LLM agent or CI driver sees your app the way Magic sees it.

It is **dev-only**: you install and wire it under `!kReleaseMode`, so debug and profile builds carry it (a performance measurement needs a profile build) and release builds tree-shake it entirely and it carries no runtime cost in production. This is exactly why it lives outside `magic` core; the framework keeps no dev-tooling production dependencies.

Four import barrels:

- `package:magic_devtools/magic_devtools.dart`: `MagicDevtools` is the umbrella one-call wiring: `installPre()` boots both tool plugins (plus crumbs' opt-in exception/dump watchers) before `Magic.init()`, `installPost()` wires both Magic integrations after it.
- `package:magic_devtools/tapir.dart`: `MagicTapirIntegration` registers 14 Magic-aware enrichers into tapir's snapshot pipeline.
- `package:magic_devtools/crumbs.dart`: `MagicCrumbsIntegration` registers 5 Magic watchers and `MagicHttpFacadeAdapter` into crumbs. The adapter masks credentials before a record reaches the agent-facing buffer: `password` / `token` style keys of a request or response body and the header `auth.token.header` names (default `Authorization`) read `********`.
- `package:magic_devtools/preview.dart`: `MagicPreview` hosts a dev-only component preview catalog via two plain pages (`/preview` and `/preview/:component`), tree-shaken from release builds.

## Install

`magic_devtools` and the tooling packages are imported in `lib/main.dart` (under `!kReleaseMode`), so they are regular `dependencies`, not `dev_dependencies`; `!kReleaseMode` tree-shakes them out of release builds, and because `lib/` imports them a `dev_dependencies` entry would trip the `depend_on_referenced_packages` lint. This matches how `tapir` and `crumbs` are installed on their own.

```yaml
dependencies:
  magic_devtools: ^1.0.0
  tapir: ^1.0.0   # add if you use tapir
  crumbs: ^1.0.0  # add if you use crumbs
```

`magic_devtools` depends on `magic`, `tapir`, and `crumbs` directly, so transitive resolution does not happen through `magic` itself.

## Wiring

Both integrations are debug-only and run in `lib/main.dart`. The ordering is load-bearing: the tapir/crumbs plugin installs **before** `Magic.init()` (so the snapshot pipeline is live during Magic boot, and the exception watcher registered beside `CrumbsPlugin.install()` catches boot errors), and the Magic integration installs **after** `Magic.init()` (its enrichers and adapter resolve Magic primitives through the IoC container).

### Both tools at once (recommended)

`MagicDevtools` collapses the four blocks below into the two halves of that ordering. Keep the `!kReleaseMode` guard at the call site: moving it inside the methods would make the call live in release and defeat the tree-shake.

```dart
if (!kReleaseMode) MagicDevtools.installPre();   // tapir + crumbs plugins + exception/dump watchers
await Magic.init(configFactories: [...]);
if (!kReleaseMode) MagicDevtools.installPost();  // MagicCrumbsIntegration + MagicTapirIntegration
```

Reach for the individual barrels below when you need only one tool, or a non-standard crumbs watcher set (register extra watchers with `CrumbsPlugin.registerWatcher` after `installPre`).

### Performance sessions

`installPre()` also installs `MagicPerfIntegration`, the data path behind tapir's `perf_begin` / `perf_end` / `perf_trace`. During an attribution session it counts magic's runtime activity through `MagicPerfHooks.sink` and wind's build, wrapper and inherited-read counters, stamps every crumbs record with the tapir interaction it belongs to (`linkedBy: zone | frame | window`), and contributes wind and magic insights (`PerfInsightRules`) whose thresholds each insight states in `evidence.threshold`. A timing session touches neither counter.

### Tapir

```dart
if (!kReleaseMode) {
  TapirPlugin.install();
}
await Magic.init(configFactories: [...]);
if (!kReleaseMode) {
  MagicTapirIntegration.install();
}
```

### Crumbs

```dart
if (!kReleaseMode) {
  CrumbsPlugin.install();
  CrumbsPlugin.registerWatcher(ExceptionWatcher()); // catches boot errors
  CrumbsPlugin.registerWatcher(DumpWatcher());      // captures debugPrint
}
await Magic.init(configFactories: [...]);
if (!kReleaseMode) {
  MagicCrumbsIntegration.install();
}
```

You can wire either integration on its own, or both together: install each plugin before `Magic.init()` and each Magic integration after it. The `tapir:install` and `crumbs:install` commands write the single-tool blocks above into `lib/main.dart` when `magic_devtools` is a dependency, with two limits: they write neither `MagicDevtools` nor `MagicPerfIntegration` (an app wired only by the installers gets the all-zero perf report), and crumbs' block sits under `kDebugMode`, so a profile build carries no crumbs. An app that calls `MagicDevtools.installPre()` does not need the installers.

### Preview catalog

`MagicPreview` hosts a dev-only component preview catalog: a sidebar of registered components next to each preview rendered in BOTH light and dark, with a global theme toggle bound to wind's `WindThemeController`. It is reachable only through `MagicPreview.registerRoutes()`, guarded by `kReleaseMode` plus `const bool.fromEnvironment('PREVIEW_ENABLED', defaultValue: kDebugMode)`, so the route, the catalog, and every registered `PreviewEntry` const-fold dead and tree-shake out of release builds.

The router-lock timing is load-bearing: `MagicRouter` locks its route table on the first `routerConfig` access, so registration MUST happen in a provider `boot()` (which runs during the Magic bootstrap lifecycle, before `MaterialApp` reads `routerConfig`). Register too late and `/preview` silently never appears.

```dart
class RouteServiceProvider extends ServiceProvider {
  RouteServiceProvider(super.app);

  @override
  Future<void> boot() async {
    registerAppRoutes();
    if (kDebugMode) {
      MagicPreview.register(previewEntries()); // from the generated _previews.g.dart
      MagicPreview.registerRoutes();
    }
  }
}
```

The `previews:refresh` command scans `*.preview.dart` files and regenerates `previewEntries()` returning a `List<PreviewEntry>` from a function (never a top-level const, the dart-lang/sdk#33920 retention foot-gun).

## Ecosystem

| Package | |
|---------|--|
| [magic](https://pub.dev/packages/magic) | The Laravel experience for Flutter |
| [tapir](https://pub.dev/packages/tapir) | E2E driver for LLM agents and CI |
| [crumbs](https://pub.dev/packages/crumbs) | Passive runtime inspector |

## Contributing

```bash
git clone https://github.com/fluttersdk/magic_devtools.git
cd magic_devtools && flutter pub get
flutter test && dart analyze
```

Local development resolves the `magic` and `magic_socket` siblings through a gitignored `pubspec_overrides.yaml` (path entries to the sibling clones); `tapir` and `crumbs` resolve from pub.dev. Create one alongside `pubspec.yaml`:

```yaml
# pubspec_overrides.yaml (gitignored; local path wiring only)
dependency_overrides:
  magic:
    path: ../magic
  magic_socket:
    path: ../magic_socket
```

[Report a bug](https://github.com/fluttersdk/magic_devtools/issues/new)

## License

MIT, see [LICENSE](LICENSE) for details.

---

<p align="center">
  <sub>Built with care by <a href="https://github.com/fluttersdk">FlutterSDK</a></sub><br/>
  <sub>If magic_devtools helps you, <a href="https://github.com/fluttersdk/magic_devtools">give it a star</a>; it helps others discover it.</sub>
</p>
