<p align="center">
  <img src="https://raw.githubusercontent.com/anilcancakir/magic_devtools/master/.github/magic-logo.svg" width="120" alt="Magic Devtools logo" />
</p>

<h1 align="center">Magic Devtools</h1>

<p align="center">
  <strong>Let an agent see your Magic app the way Magic sees it.</strong><br/>
  Wire a Magic app into <a href="https://pub.dev/packages/tapir">tapir</a> (the E2E driver) and <a href="https://pub.dev/packages/crumbs">crumbs</a> (the runtime inspector), so snapshots carry forms, routes, controllers, gates and auth, and crumbs records Magic's HTTP, model, cache, event, gate and query activity; debug and profile builds carry the tools, release builds drop them.
</p>

<p align="center">
  <a href="https://pub.dev/packages/magic_devtools"><img src="https://img.shields.io/pub/v/magic_devtools.svg" alt="pub package"></a>
  <a href="https://github.com/anilcancakir/magic_devtools/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/anilcancakir/magic_devtools/ci.yml?branch=master&label=CI" alt="CI"></a>
  <a href="https://codecov.io/gh/anilcancakir/magic_devtools"><img src="https://codecov.io/gh/anilcancakir/magic_devtools/graph/badge.svg" alt="codecov"></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT"></a>
  <a href="https://pub.dev/packages/magic_devtools/score"><img src="https://img.shields.io/pub/points/magic_devtools" alt="pub points"></a>
</p>

<p align="center">
  <a href="https://anilcancakir.com/magic/devtools">Documentation</a> ·
  <a href="https://pub.dev/packages/magic_devtools">pub.dev</a> ·
  <a href="https://github.com/anilcancakir/magic_devtools/issues">Issues</a>
</p>

## At a glance

| Fact | Value |
|---|---|
| Package | [`magic_devtools`](https://pub.dev/packages/magic_devtools) |
| Install | `flutter pub add magic_devtools tapir crumbs` |
| Import | `package:magic_devtools/magic_devtools.dart`; one tool alone: `tapir.dart` or `crumbs.dart`; the preview catalog: `preview.dart` |
| Entry points | `MagicDevtools.installPre()` and `installPost()` (the two-phase install), `MagicTapirIntegration`, `MagicCrumbsIntegration`, `MagicPerfIntegration`, `MagicPreview` |
| Platforms | No native code of its own: it follows `magic`, `tapir` and `crumbs`. pana 0.23.13 lists Android, iOS, macOS, Windows and Linux; web drops out through `magic`'s `path_provider` import |
| Requires | Dart >=3.13, Flutter >=3.47, `magic` ^1.0.0 |
| Dependencies | `magic`, `magic_socket`, `tapir`, `crumbs`, `wind_kit`, `material_ui` |
| License | MIT |

## Install

```bash
flutter pub add magic_devtools tapir crumbs
```

Call the two halves of `MagicDevtools` around `Magic.init()` in `lib/main.dart`, each under `!kReleaseMode`:

```dart
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';
import 'package:magic_devtools/magic_devtools.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kReleaseMode) MagicDevtools.installPre();

  await Magic.init(); // pass your configFactories and providers here

  if (!kReleaseMode) MagicDevtools.installPost();

  runApp(MagicApplication());
}
```

| Call | When | Installs |
|---|---|---|
| `MagicDevtools.installPre()` | Before `Magic.init()` | `TapirPlugin`, `CrumbsPlugin`, one `ExceptionWatcher` and one `DumpWatcher`, and `MagicPerfIntegration` |
| `MagicDevtools.installPost()` | After `Magic.init()` | `MagicCrumbsIntegration`, then `MagicTapirIntegration` |

The order is fixed by what each half touches. The pre half has to watch Magic boot, so a boot error lands in crumbs, and its perf integration adds a navigator observer that `MagicRouter` refuses once its route table is built. The post half resolves Magic's container, which exists only after `Magic.init()`.

The packages are regular `dependencies`, because `lib/main.dart` imports them and a `dev_dependencies` entry would trip the `depend_on_referenced_packages` lint. The `!kReleaseMode` guard is what keeps them out of a release build: `kReleaseMode` is a compile-time constant, so a release build drops the branch and everything it reaches. Nothing in this package checks the build mode on its own, so the guard stays at the call site. `dart run magic:dowel magic:install --with-devtools` writes the same wiring, block by block, while it installs Magic.

Failure modes:

- `installPre()` after `Magic.init()` throws the router's `StateError`: `Magic.init()` builds the router once the providers have booted.
- `installPost()` before `Magic.init()` attaches no HTTP adapter (there is no `network` binding yet), and the install guard stops a later call from retrying.
- `installPre()` next to a hand-written `CrumbsPlugin.registerWatcher(ExceptionWatcher())` chains a second exception watcher onto the first, so every exception is recorded twice. Use one style.

Both halves are idempotent: a second call in the same isolate registers nothing twice.

## Tapir integration

`MagicTapirIntegration.install()` appends 14 enrichers to `TapirPlugin.enrichers` and registers a navigate adapter that drives `MagicRouter`. `installPost()` makes the same call; to wire tapir alone:

```dart
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';
import 'package:magic_devtools/tapir.dart';
import 'package:tapir/tapir.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kReleaseMode) TapirPlugin.install();

  await Magic.init();

  if (!kReleaseMode) MagicTapirIntegration.install();

  runApp(MagicApplication());
}
```

Enricher lines appear in a snapshot that asks for them: `dart run tapir tapir:snap --includeEnrichers`.

| Snapshot keys | Read from |
|---|---|
| `magicFormField`, `magicFormErrors` | The nearest `MagicForm`: the field an `EditableText` belongs to, and the `ValidatesRequests` errors of the form's own fields |
| `magicRoute`, `magicRouteParams`, `magicMiddleware` | `MagicRouter.instance`: the current location, the path then query parameters, the current route's middlewares |
| `magicControllerState`, `magicControllerFlags` | The first `MagicStateMixin` controller in `Magic.controllers` |
| `magicGateResult`, `magicGateResultsAll` | The `Gate.manager` result cache (at most 5 abilities, newest first); no ability is run |
| `magicAuthUser` | `Auth.user<Model>()`: the `id`, plus `:<display_name>` when that attribute is a non-empty string |
| `magicEchoConnection` | The Echo connection of the `broadcasting` binding, absent when nothing is bound |
| `magicRecentHttp`, `magicRecentLogs`, `magicRecentExceptions` | `CrumbsStore`: the last 5 requests, 3 warnings or worse, 3 exceptions |

The navigate adapter makes `tapir:navigate --route /path` call `MagicRouter.instance.to(route)`, so the route is a URL path, not a route name. When the router throws a `StateError`, the adapter answers `false` and tapir falls back to its own navigation.

Failure modes:

- `tapir:snap` without `--includeEnrichers` prints no `magic*` lines; enrichers are off by default.
- `magicAuthUser` is absent for a guest and in an app with no `auth` binding (no `AuthServiceProvider`); it reads only the `id` and `display_name` attributes.
- `magicEchoConnection` follows the connection stream only when `broadcasting` was bound at `install()`; otherwise it can answer only `connected` or `disconnected`.
- tapir removes no duplicate keys: an app enricher that emits one of these keys produces two lines under the same element.

## Crumbs integration

`MagicCrumbsIntegration.install()` registers one HTTP adapter and five watchers with crumbs, masks the auth header Magic sends, and points tapir's network-idle, console and exceptions readers at crumbs. To wire crumbs alone:

```dart
import 'package:crumbs/crumbs.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';
import 'package:magic_devtools/crumbs.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kReleaseMode) {
    CrumbsPlugin.install();
    CrumbsPlugin.registerWatcher(ExceptionWatcher()); // boot errors
    CrumbsPlugin.registerWatcher(DumpWatcher()); // debugPrint
  }

  await Magic.init();

  if (!kReleaseMode) MagicCrumbsIntegration.install();

  runApp(MagicApplication());
}
```

| Unit | Listens to | Read it with |
|---|---|---|
| `MagicHttpFacadeAdapter` | An interceptor on the `network` driver | `crumbs:requests` |
| `MagicModelWatcher` | `ModelCreated`, `ModelSaved`, `ModelDeleted` | `CrumbsStore.recentModels()` |
| `MagicCacheWatcher` | `CacheHit`, `CacheMiss`, `CachePut`, `CacheForget`, `CacheFlush` | `crumbs:caches` |
| `MagicEventWatcher` | `AuthLogin`, `AuthLogout`, `AuthFailed`, `AuthRestored`, `DatabaseConnected`, `GateAbilityDefined`, `GateBeforeRegistered` | `crumbs:events` |
| `MagicGateWatcher` | `GateAccessChecked` | `crumbs:gates` |
| `MagicQueryWatcher` | `QueryExecuted` | `crumbs:queries` |

Request and response bodies are masked by key (`password`, `token` and the rest of crumbs' lists) before they are stringified and cut at 8192 characters, and the header `auth.token.header` names (default `Authorization`) is hidden; a masked value reads `********`. Requests and answers pair by the id Magic's driver stamps on each request, so two requests that finish out of order keep their own URL and duration.

Failure modes:

- Called before `Magic.init()`, the adapter finds no `network` binding and attaches nothing, and the install guard stops a retry.
- `Http.fake()` installs no interceptors, so a faked request never reaches crumbs; assert on the fake.
- A `ModelRecord` copies every attribute unmasked, and `EventRecord.payload` is always empty: the record says which event fired, not its fields.
- `--dart-define=CRUMBS_DISABLE=true` turns `registerWatcher` and `registerHttpAdapter` into no-ops, so none of the Magic units attaches.

## Performance

`MagicPerfIntegration` is the data path behind tapir's perf sessions: it counts Magic's runtime activity through `MagicPerfHooks.sink` and wind's build counters, stamps every crumbs record except gate records with the tapir interaction it belongs to (`linkedBy: zone | frame | window`), and adds the Magic and wind insight rules (`PerfInsightRules`) to the report. `installPre()` installs it; drive a session from a debug or profile build:

```bash
dart run tapir tapir:perf_begin --mode=attribution
# drive the screen you want to measure
dart run tapir tapir:perf_end
dart run tapir tapir:perf_trace --out=build/perf/trace.json
```

| Member | Meaning |
|---|---|
| `MagicPerfIntegration.install()` | Assigns tapir's perf pointers, registers a crumbs `FramePerfWatcher`, calls `Wind.installPerfResolver()` and adds a navigator observer to `MagicRouter`. Idempotent |
| `MagicPerfIntegration.interactionLink({int? startUs})` | The tapir interaction the calling code belongs to, and how that was decided |
| `MagicPerfIntegration.controllerNotifyCounts` | `refreshUI()` calls per controller type since the last attribution session began |
| `MagicPerfIntegration.routeTransitions` | Named route pushes since the last session began, at most 200, each timed to the first frame after it |
| `PerfInsightRules.evaluate(report, inputs)` | The insights that fired for one report, each with `severity: 'warn'` and the `threshold` in its `evidence` |

An `attribution` session (the `tapir:perf_begin` default) turns the counters on and evaluates the insights; a `timing` session counts nothing, so its milliseconds stay comparable.

Failure modes:

- Wired only through `tapir:install` and `crumbs:install`, an app gets a perf report of zeros: neither installer writes `MagicPerfIntegration` or `MagicDevtools`. An unassigned tapir pointer fails silently.
- `install()` after the router is built throws the router's `StateError`, on purpose: a silently missing observer would leave the report without route transitions and nothing to say why.
- A `kDebugMode` guard leaves a profile build without the tools; use `!kReleaseMode`, since a measurement belongs on a profile build.

## Preview catalog

`MagicPreview` hosts a component catalog at `/preview`: a sidebar of the registered previews next to one pane that builds only the selected preview, and a "Toggle theme" button that flips the whole catalog between light and dark through `WindTheme.of(context).toggleTheme()`. Register the entries and the routes from a provider's `boot()`:

```dart
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:magic/magic.dart';
import 'package:magic_devtools/preview.dart';

import '_previews.g.dart';

class RouteServiceProvider extends ServiceProvider {
  RouteServiceProvider(super.app);

  @override
  void register() {}

  @override
  Future<void> boot() async {
    // Register your app routes here first.
    if (kDebugMode) {
      MagicPreview.register(previewEntries());
      MagicPreview.registerRoutes();
    }
  }
}
```

`dart run magic:dowel previews:refresh` scans `*.preview.dart` files (one public `*Preview` class with a `const` constructor each) and writes `_previews.g.dart`, whose `previewEntries()` returns the `List<PreviewEntry>` from a function so a release build can drop every entry.

| Member | Meaning |
|---|---|
| `PreviewEntry({label, slug, builder})` | One entry: the sidebar label, the URL slug and a `WidgetBuilder` |
| `MagicPreview.register(entries)` | Stores an unmodifiable copy, replacing any earlier set |
| `MagicPreview.registerRoutes()` | Adds `/preview` and `/preview/:component`; returns at once in release, or when `kPreviewEnabled` is false |
| `kPreviewEnabled` | `bool.fromEnvironment('PREVIEW_ENABLED', defaultValue: kDebugMode)`: on in debug, off in profile unless `--dart-define=PREVIEW_ENABLED=true` |

Failure modes:

- `registerRoutes()` after the router is built throws the router's `StateError` ("Cannot add routes after the router has been built"). A provider's `boot()` runs inside `Magic.init()`, before that point.
- `register()` after `registerRoutes()` leaves the catalog empty: the routes captured the entries when they were added.
- The `kDebugMode` check in the sample is false in a profile build, so `PREVIEW_ENABLED=true` does nothing there; guard with `!kReleaseMode` to use the profile override.

## For AI coding agents

| Do | Because |
|---|---|
| Put each install call under `if (!kReleaseMode)` at the call site, never inside a helper of this package | The constant guard is what tree-shakes tapir, crumbs and this package from a release build; nothing here checks the build mode itself. |
| Call `installPre()` (or `TapirPlugin`, `CrumbsPlugin` and `MagicPerfIntegration`) before `Magic.init()`, and `installPost()` after it | The perf observer is refused once `Magic.init()` has built the router, and the post half resolves the container `Magic.init()` fills. |
| Use `!kReleaseMode`, not `kDebugMode`, for the tool wiring | A performance measurement runs on a profile build, where `kDebugMode` is false. |
| Pick one style: `MagicDevtools` or the per-tool blocks | Mixing them registers a second `ExceptionWatcher` or `DumpWatcher`, and each exception and `debugPrint` is recorded twice. |
| Add `magic_devtools`, `tapir` and `crumbs` under `dependencies` | `lib/main.dart` imports them; a `dev_dependencies` entry trips `depend_on_referenced_packages`. |
| Pass `--includeEnrichers` to `tapir:snap` when you need the `magic*` lines | Enrichers are off by default. |
| Register preview routes from a provider's `boot()`, after `MagicPreview.register()` | The router locks its table inside `Magic.init()`, and the routes capture the entries registered before them. |
| In tests, call each `resetForTesting()` and pair it with `CrumbsStore.resetForTesting()`, `EventDispatcher.instance.clear()` and `MagicRouter.reset()` | Every integration keeps static state, and the watchers cannot remove their own dispatcher listeners. |

## Dependencies

`magic` for the container, router, forms, gates, auth and the perf hooks; `magic_socket` for the Echo connection the broadcasting enricher reads; `tapir` and `crumbs`, the two tools this package wires; `wind_kit` for the preview catalog's widgets and the wind perf counters; `material_ui`, which `lib/` imports in place of `package:flutter/material.dart`. `magic` itself depends on neither tapir nor crumbs, so this package is the only place they meet a Magic app.

## Contributing

```bash
git clone https://github.com/anilcancakir/magic_devtools.git
cd magic_devtools && flutter pub get
flutter analyze --no-fatal-infos && dart format --set-exit-if-changed . && flutter test
python3 tool/check-docs.py
```

The committed `pubspec.yaml` keeps hosted constraints, so a fresh clone resolves `magic`, `tapir` and `crumbs` from pub.dev. To work against local clones of the sibling packages, list them in a gitignored `pubspec_overrides.yaml` with absolute paths: a worktree under `.claude/worktrees/` resolves a relative `../magic` to a directory that does not exist.

```yaml
# pubspec_overrides.yaml (gitignored; absolute paths)
dependency_overrides:
  magic:
    path: /absolute/path/to/magic
  magic_socket:
    path: /absolute/path/to/magic_socket
```

## Links

- [Documentation](https://anilcancakir.com/magic/docs/devtools/getting-started/installation): installation, the tapir and crumbs integrations, performance, the preview catalog and testing
- [API reference](https://pub.dev/documentation/magic_devtools/latest/)
- [llms.txt](llms.txt) and the [agent skill](skills/magic-devtools/SKILL.md) for AI coding agents: `npx skills add anilcancakir/magic_devtools`
- [Changelog](CHANGELOG.md)
- [Report an issue](https://github.com/anilcancakir/magic_devtools/issues)
- [Security policy](SECURITY.md)

## License

MIT, see [LICENSE](LICENSE). Built by [Anılcan Çakır](https://anilcancakir.com).
