# magic_devtools example

A Magic app that calls `MagicDevtools.installPre()` before `Magic.init()` and `MagicDevtools.installPost()` after it, both under `!kReleaseMode`, and registers a two-entry preview catalog from its route provider. The home screen has three buttons: one opens `/preview`, one sends a request to a port nothing listens on (crumbs records it through the HTTP adapter), and one calls `debugPrint` (crumbs' dump watcher captures it).

```bash
cd example
flutter create --platforms=macos .
dart run tapir start --device=macos
```

`flutter create` adds the platform folder once and leaves `lib/` and `pubspec.yaml` as they are; pass the platform you run on to `--platforms` and `--device`. With the app running, read it the way an agent does:

```bash
dart run tapir tapir:snap --includeEnrichers   # magicRoute, magicRecentHttp, ...
dart run tapir tapir:navigate --route /preview/primary_button
dart run crumbs crumbs:requests
dart run crumbs crumbs:dumps
dart run tapir stop
```

The example registers `AuthServiceProvider` because the `magicAuthUser` enricher reads `Auth.user()`, and an enriched snapshot fails in an app with no `auth` binding. `previewEntries()` is written by hand to keep the example in one file; an app generates it with `dart run magic:dowel previews:refresh`.
