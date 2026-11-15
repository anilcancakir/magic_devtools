# Preview Catalog

`MagicPreview` hosts a dev-only component catalog at `/preview`: a sidebar of your registered previews next to the one you picked, with a light and dark toggle, generated from your `*.preview.dart` files and dropped from release builds.

- [Basic Usage](#basic-usage)
- [Quick Reference](#quick-reference)
- [Writing a Preview](#writing-a-preview)
- [Generating the Index](#generating-the-index)
- [The Release Boundary](#the-release-boundary)
- [Router Timing](#router-timing)
- [Gotchas](#gotchas)
- [Related Documentation](#related-documentation)

<a name="basic-usage"></a>
## Basic Usage

Register the generated entries and the routes from a provider's `boot()`:

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

Run the app and open `/preview`. Selecting an entry in the sidebar navigates to `/preview/<slug>`.

<a name="quick-reference"></a>
## Quick Reference

| Member | Type | Meaning |
|:-------|:-----|:--------|
| `PreviewEntry({label, slug, builder})` | `final class` | One catalog entry: the sidebar `label`, the URL `slug` and a `WidgetBuilder` |
| `MagicPreview.register(entries)` | `static void` | Stores an unmodifiable copy of the entries, replacing any earlier set |
| `MagicPreview.entries` | `List<PreviewEntry>` | The registered entries, read-only |
| `MagicPreview.registerRoutes()` | `static void` | Adds `/preview` (named `magic-preview.index`) and `/preview/:component` (named `magic-preview.component`) |
| `MagicPreviewCatalog` | `StatefulWidget` | The catalog page; `entries`, `activeSlug` and `onSelect` |
| `kPreviewEnabled` | `const bool` | `bool.fromEnvironment('PREVIEW_ENABLED', defaultValue: kDebugMode)` |

The catalog builds only the selected preview, so a long list of heavy screens stays responsive. An unknown slug, or `/preview` itself, shows the first entry. The header's "Toggle theme" button calls `WindTheme.of(context).toggleTheme()`, so the whole catalog flips between light and dark.

<a name="writing-a-preview"></a>
## Writing a Preview

A preview is a file ending in `.preview.dart` anywhere under the scanned directory, with exactly one public class whose name ends in `Preview` and that has a `const` constructor:

```dart
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

class PrimaryButtonPreview extends StatelessWidget {
  const PrimaryButtonPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return WButton(
      onTap: () {},
      className: 'px-4 py-2 rounded-md bg-primary',
      child: const WText('Save', className: 'text-white'),
    );
  }
}
```

The label is the class name without `Preview` (`PrimaryButton`) and the slug is its snake case (`primary_button`).

<a name="generating-the-index"></a>
## Generating the Index

```bash
dart run magic:dowel previews:refresh
dart run magic:dowel previews:refresh --path=lib/resources/views
```

The command scans `--path` (default `lib`), writes `<path>/_previews.g.dart`, and prints how many previews it found. The generated file imports `package:magic_devtools/preview.dart` and every preview file, and defines `List<PreviewEntry> previewEntries()`, sorted by slug, with each builder as `(_) => const XxxPreview()`. It is a function, never a top-level const list, so a release build can drop every entry.

The command stops with a `FormatException` when a file holds zero or several public `*Preview` classes, when a class name is not a PascalCase identifier, or when two previews produce the same slug.

<a name="the-release-boundary"></a>
## The Release Boundary

`registerRoutes()` returns at once when `kReleaseMode` is true or `kPreviewEnabled` is false. Both are compile-time constants, so a release build folds the whole body away along with the catalog and every entry it would reach.

| Build | Default | Override |
|:------|:--------|:---------|
| Debug | On | `--dart-define=PREVIEW_ENABLED=false` turns it off |
| Profile | Off | `--dart-define=PREVIEW_ENABLED=true` turns it on |
| Release | Off | None |

The `kDebugMode` check around the calls in the sample keeps `previewEntries()` itself out of profile and release builds. Drop it if you want the profile override to work.

<a name="router-timing"></a>
## Router Timing

`MagicRouter` locks its route table the first time `routerConfig` is read, and `Magic.init()` reads it itself as its last step, once every provider has booted. A provider's `boot()` runs before that read, so it is the place to call `registerRoutes()`. A call after `Magic.init()` has returned, before `runApp` included, throws the router's `StateError` ("Cannot add routes after the router has been built") from the first `MagicRoute.page` it adds.

<a name="gotchas"></a>
## Gotchas

| Mistake | Fix |
|:--------|:----|
| Calling `registerRoutes()` after `Magic.init()`, in `main` or later. | It throws a `StateError`; call it from a provider's `boot()`. |
| Calling `register()` after `registerRoutes()`. | The routes captured the entries at registration, so the catalog stays empty; call `register()` first. |
| Giving a preview class a non-const constructor. | The generated builder is `const XxxPreview()` and fails to compile; add a `const` constructor. |
| Declaring a helper `class FooPreview` next to the real one in the same file. | Only one public `*Preview` class per file; make the helper private or rename it. |
| Wrapping the calls in `kDebugMode` and then passing `PREVIEW_ENABLED=true` to a profile build. | The `kDebugMode` check is false in profile and nothing registers; use `!kReleaseMode` at the call site instead. |

<a name="related-documentation"></a>
## Related Documentation

- [Installation](../getting-started/installation.md): the tooling the catalog ships beside.
- [Testing](../guides/testing.md): resetting the registered entries between tests.
