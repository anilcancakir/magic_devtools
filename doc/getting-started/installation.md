# Installation

Add `magic_devtools` to a Magic app and wire tapir and crumbs into it in the two phases around `Magic.init()`, so debug and profile builds carry the tools and release builds drop them.

- [Install](#install)
- [Requirements](#requirements)
- [The Two-Phase Install](#the-two-phase-install)
- [Wiring One Tool](#wiring-one-tool)
- [What the Installers Write](#what-the-installers-write)
- [Release Builds](#release-builds)
- [Related Documentation](#related-documentation)

<a name="install"></a>
## Install

From an app that already runs Magic, one command adds the three packages and wires `lib/main.dart`:

```bash
dart run magic:dowel magic:install --with-devtools
```

To do it by hand, add the packages as regular dependencies and call the two halves of `MagicDevtools` in `lib/main.dart`:

```yaml
dependencies:
  magic_devtools: ^1.0.0
  tapir: ^1.0.0
  crumbs: ^1.0.0
```

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

`lib/main.dart` imports these packages, so they belong under `dependencies`: a `dev_dependencies` entry would trip the `depend_on_referenced_packages` lint. The `!kReleaseMode` guard, not the dependency section, is what keeps them out of a release build.

<a name="requirements"></a>
## Requirements

| Requirement | Value |
|:------------|:------|
| Dart | `>=3.13.0` |
| Flutter | `>=3.47.0` |
| `magic` | `^1.0.0` |
| `tapir`, `crumbs` | `^1.0.0`, resolved through `magic_devtools` |
| Also pulled in | `magic_socket`, `wind_kit`, `material_ui` |

`magic` core depends on neither tapir nor crumbs; this package is the only place they meet a Magic app.

<a name="the-two-phase-install"></a>
## The Two-Phase Install

| Call | When | What it wires |
|:-----|:-----|:--------------|
| `MagicDevtools.installPre()` | Before `Magic.init()` | `TapirPlugin.install()`, `CrumbsPlugin.install()` (which adds crumbs' `LogWatcher` itself), one `ExceptionWatcher` and one `DumpWatcher`, and `MagicPerfIntegration.install()` |
| `MagicDevtools.installPost()` | After `Magic.init()` | `MagicCrumbsIntegration.install()`, then `MagicTapirIntegration.install()` |

The order is fixed by what each half touches:

- The pre half has to observe Magic booting: the snapshot pipeline and the exception watcher are live before the first provider runs, so a boot error lands in crumbs. `MagicPerfIntegration` adds a navigator observer through `MagicRouter.addObserver`, which throws a `StateError` once `routerConfig` has been read, so it cannot run later.
- The post half resolves Magic's container: the HTTP adapter looks up the `network` binding and the enrichers read controllers, the router, `Gate`, `Auth` and the `broadcasting` binding.

Both halves are idempotent: a second call in the same isolate registers nothing twice. `installPre()` keeps the watcher pair it registered, so a second call does not chain a second `ExceptionWatcher` or `DumpWatcher` onto the first.

<a name="wiring-one-tool"></a>
## Wiring One Tool

Import a narrow barrel when the app uses one tool, or wants a different crumbs watcher set. The rule stays the same: the plugin before `Magic.init()`, the Magic integration after it.

| Barrel | Exports |
|:-------|:--------|
| `package:magic_devtools/magic_devtools.dart` | `MagicDevtools`, `MagicPerfIntegration`, `PerfInsightRules`, `PerfRuleInputs` |
| `package:magic_devtools/tapir.dart` | `MagicTapirIntegration` and its 14 enricher functions |
| `package:magic_devtools/crumbs.dart` | `MagicCrumbsIntegration`, `MagicHttpFacadeAdapter` and the five watchers |
| `package:magic_devtools/preview.dart` | `MagicPreview`, `PreviewEntry`, `MagicPreviewCatalog`, `kPreviewEnabled` |

```dart
import 'package:crumbs/crumbs.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';
import 'package:magic_devtools/crumbs.dart';
import 'package:magic_devtools/tapir.dart';
import 'package:tapir/tapir.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kReleaseMode) {
    TapirPlugin.install();
    CrumbsPlugin.install();
    CrumbsPlugin.registerWatcher(ExceptionWatcher());
    CrumbsPlugin.registerWatcher(DumpWatcher());
  }

  await Magic.init();

  if (!kReleaseMode) {
    MagicCrumbsIntegration.install();
    MagicTapirIntegration.install();
  }

  runApp(MagicApplication());
}
```

This wiring leaves out `MagicPerfIntegration`, so tapir's perf reports come back with zero counters. Add `MagicPerfIntegration.install()` to the first block, or use `MagicDevtools`, when you measure performance. Do not mix the two styles: `MagicDevtools.installPre()` after a hand-written `ExceptionWatcher` registration adds a second one.

<a name="what-the-installers-write"></a>
## What the Installers Write

| Command | Writes into `lib/main.dart` |
|:--------|:----------------------------|
| `dart run magic:dowel magic:install --with-devtools` | The tapir, crumbs (with `ExceptionWatcher` and `DumpWatcher`) and `MagicPerfIntegration.install()` blocks before `await Magic.init(`, the `MagicCrumbsIntegration` and `MagicTapirIntegration` blocks after it, all under `!kReleaseMode`; adds `magic_devtools`, `tapir` and `crumbs` at `^1.0.0` to `dependencies` |
| `dart run tapir tapir:install` | A `TapirPlugin.install()` block under `!kReleaseMode`, and `MagicTapirIntegration.install()` after `await Magic.init(` when the pubspec lists `magic_devtools` and `flutter pub get` has resolved it |
| `dart run crumbs crumbs:install` | A `CrumbsPlugin.install()` block with `ExceptionWatcher` and `DumpWatcher` under `!kReleaseMode`, and `MagicCrumbsIntegration.install()` after `await Magic.init(` when the pubspec lists `magic_devtools` and `flutter pub get` has resolved it |

Every installer decides by call presence, so a re-run writes nothing twice. `magic:install` leaves a file that already calls `MagicDevtools.installPre(` untouched. Neither `tapir:install` nor `crumbs:install` writes `MagicDevtools` or `MagicPerfIntegration`.

<a name="release-builds"></a>
## Release Builds

`kReleaseMode` is a compile-time constant, so a release build drops every `if (!kReleaseMode)` branch and, with it, the tapir, crumbs and `magic_devtools` code those branches reach. Nothing in this package checks the build mode on its own: `installPre()`, `installPost()` and every `install()` do their work wherever they are called, so the guard belongs at the call site. The one exception is the preview catalog, whose `MagicPreview.registerRoutes()` returns early in release by itself.

A profile build keeps the tools, which is what a performance measurement needs.

<a name="related-documentation"></a>
## Related Documentation

- [Tapir Integration](../basics/tapir-integration.md): the 14 snapshot enrichers and the navigate adapter.
- [Crumbs Integration](../basics/crumbs-integration.md): the HTTP adapter, the five watchers and credential masking.
- [Performance](../basics/performance.md): the perf data path and the insight rules.
- [Preview Catalog](../basics/preview-catalog.md): the dev-only `/preview` pages.
- [Testing](../guides/testing.md): resetting the integrations between tests.
