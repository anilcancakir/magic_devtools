# Tapir Integration

`MagicTapirIntegration` adds 14 Magic-aware enrichers to tapir's snapshot pipeline and a navigate adapter that drives `MagicRouter`, so an agent reading a snapshot sees forms, routes, controllers, gates, auth, broadcasting and recent crumbs records next to each element.

- [Basic Usage](#basic-usage)
- [Quick Reference](#quick-reference)
- [Reading the Enrichers](#reading-the-enrichers)
- [Recent Crumbs Records](#recent-crumbs-records)
- [The Navigate Adapter](#the-navigate-adapter)
- [Install Behaviour](#install-behaviour)
- [Gotchas](#gotchas)
- [Related Documentation](#related-documentation)

<a name="basic-usage"></a>
## Basic Usage

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

`MagicDevtools.installPost()` makes the same `MagicTapirIntegration.install()` call. Enricher lines appear only in a snapshot that asks for them:

```bash
dart run tapir tapir:snap --includeEnrichers
```

<a name="quick-reference"></a>
## Quick Reference

The enrichers run in this order for every element tapir emits, and each returns nothing when it has nothing to say.

| Slot | Function | Line it adds |
|:-----|:---------|:-------------|
| 0 | `magicFormEnricher` | `magicFormField: <name>` |
| 1 | `magicNavigationEnricher` | `magicRoute: <location>` |
| 2 | `magicControllerEnricher` | `magicControllerState: <Class>.<status>` |
| 3 | `magicFormErrorsEnricher` | `magicFormErrors: <field>="<text>",...` |
| 4 | `magicGateResultEnricher` | `magicGateResult: <ability>.<allowed or denied>` |
| 5 | `magicMiddlewareEnricher` | `magicMiddleware: <name>,<name>` |
| 6 | `magicAuthUserEnricher` | `magicAuthUser: <id>` or `magicAuthUser: <id>:<display_name>` |
| 7 | `magicControllerFlagsEnricher` | `magicControllerFlags: <Class>.isLoading=<bool>,isSuccess=<bool>,isError=<bool>,isEmpty=<bool>` |
| 8 | `magicRouteParamsEnricher` | `magicRouteParams: <key>=<value>,...` |
| 9 | `magicEchoConnectionEnricher` | `magicEchoConnection: <state>` |
| 10 | `magicGateResultsAllEnricher` | `magicGateResultsAll: <ability>=<allowed or denied>,...` |
| 11 | `magicRecentHttpEnricher` | `magicRecentHttp: <METHOD> <url> <status> <ms>ms,...` |
| 12 | `magicRecentLogsEnricher` | `magicRecentLogs: [<LEVEL>] <message>,...` |
| 13 | `magicRecentExceptionsEnricher` | `magicRecentExceptions: <Type> at <file.dart>:<line>,...` |

Every enricher is synchronous, has tapir's `TapirSnapshotEnricher` signature (`String? Function(Element, RefRegistry)`), and keeps no reference to the element between calls.

<a name="reading-the-enrichers"></a>
## Reading the Enrichers

| Key | Source and rules |
|:----|:-----------------|
| `magicFormField` | The element, or a descendant, is an `EditableText` whose controller is a text controller of the `MagicFormData` on the nearest `MagicForm` ancestor. The value is that field's name. |
| `magicRoute` | `MagicRouter.instance.currentLocation`; absent while it is null or empty. |
| `magicControllerState` | The first controller in `Magic.controllers` that has an `rxStatus` (a `MagicStateMixin` controller); the status is the enum name, such as `loading` or `success`. |
| `magicControllerFlags` | The first such controller's `isLoading`, `isSuccess`, `isError` and `isEmpty`, always in that order. |
| `magicFormErrors` | `validationErrors` of the controller behind the nearest `MagicForm`, when that controller uses `ValidatesRequests`. Only the form's own fields are listed when it has `MagicFormData`; each message is quoted and cut to 80 characters (77 plus `...`). |
| `magicGateResult` | `Gate.manager.mostRecentResult`, the last ability any `Gate` check decided. |
| `magicGateResultsAll` | The cached result of every defined ability that has one, newest first, at most 5. It reads the cache only and never runs an ability. |
| `magicMiddleware` | The middlewares of `MagicRouter.instance.currentRoute`: a string alias as written, a `MagicMiddleware` by its `toString()`. |
| `magicAuthUser` | `Auth.user<Model>()`: the `id` attribute, plus `:<display_name>` when that attribute is a non-empty string. Absent for a guest. |
| `magicRouteParams` | `MagicRouter.instance.pathParameters` first, then `queryParameters`; absent when both are empty. |
| `magicEchoConnection` | Absent unless the container has a `broadcasting` binding. The last state the Echo connection stream emitted (`connecting`, `connected`, `reconnecting` or `disconnected`), or, before the first event, `connected` or `disconnected` from `isConnected`. |

The route, controller, gate, auth and Echo values do not depend on the element, so they repeat under every element of one snapshot.

The `wind:` block of a snapshot is not one of these: tapir reads it through `wind_kit_diagnostics_contracts` from the resolver `Wind.installDebugResolver()` registers, and this package does not install that resolver.

<a name="recent-crumbs-records"></a>
## Recent Crumbs Records

Three enrichers read `CrumbsStore` directly, so a snapshot carries the latest network, log and exception context without a second call.

| Key | Records | Limits |
|:----|:--------|:-------|
| `magicRecentHttp` | `CrumbsStore.recentHttp(limit: 5)` | URLs longer than 40 characters keep 37 plus `...` |
| `magicRecentLogs` | `CrumbsStore.recentLogs(limit: 3, minLevel: 'WARNING')` | `WARNING` prints as `WARN`, `SEVERE` as `ERROR`; messages longer than 50 characters keep 47 plus `...` |
| `magicRecentExceptions` | `CrumbsStore.recentExceptions(limit: 3)` | `<Type> at <file.dart>:<line>` from the first stack line, or the type alone when no location parses |

Each read is wrapped so a failure yields no line instead of an error. With crumbs installed but nothing recorded yet, the three keys are simply absent.

<a name="the-navigate-adapter"></a>
## The Navigate Adapter

`install()` registers a navigate adapter with `TapirPlugin.registerNavigateAdapter`, so `tapir:navigate --route /path` calls `MagicRouter.instance.to(route)`. The route is a URL path, not a route name. When the router throws a `StateError`, the adapter answers `false` and tapir falls back to its own path (a `Navigator` push, then the platform route broadcast).

<a name="install-behaviour"></a>
## Install Behaviour

- Idempotent: a second `install()` in the same isolate returns at once and adds nothing.
- The enrichers are appended to `TapirPlugin.enrichers` in the slot order above, after whatever the app added before.
- tapir writes every line every enricher returns and removes no duplicates, so an app enricher that emits one of these keys produces two lines under the same element.
- The Echo connection stream is subscribed during `install()` only when `broadcasting` is bound at that moment.

<a name="gotchas"></a>
## Gotchas

| Mistake | Fix |
|:--------|:----|
| Calling `tapir:snap` and finding no `magic*` lines. | Enrichers are off by default; pass `--includeEnrichers`. |
| Reading `tapir:observe` output and finding only `magicFormField`, `magicRoute` and `magicGateResult`. | That is observe's default subset; pass `--includeEnrichers=full` for every key. |
| Installing before the broadcasting provider has registered, then expecting `reconnecting`. | Without the stream subscription the enricher can only answer `connected` or `disconnected`; install after `Magic.init()`. |
| Expecting a readable name from a middleware object and getting `Instance of 'AuthMiddleware'`. | `MagicMiddleware` is printed with `toString()`; override it, or register the middleware under a string alias. |
| Expecting `magicAuthUser` to show a name. | Only the `display_name` attribute is read; the line falls back to the `id` alone. |
| Adding a custom enricher that reuses a `magic*` key. | Keep keys distinct; tapir prints both lines. |

<a name="related-documentation"></a>
## Related Documentation

- [Installation](../getting-started/installation.md): the two-phase install.
- [Crumbs Integration](crumbs-integration.md): where the recent HTTP, log and exception records come from.
- [Testing](../guides/testing.md): removing the enrichers between tests.
