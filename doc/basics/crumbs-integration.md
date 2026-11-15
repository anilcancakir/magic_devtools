# Crumbs Integration

`MagicCrumbsIntegration` feeds Magic's HTTP traffic, model, cache, event, gate and query activity into crumbs' buffers, masks the auth header Magic sends, and points tapir's network-idle, console and exceptions readers at crumbs.

- [Basic Usage](#basic-usage)
- [Quick Reference](#quick-reference)
- [HTTP Capture](#http-capture)
- [Credential Masking](#credential-masking)
- [The Watchers](#the-watchers)
- [The Tapir Bridge](#the-tapir-bridge)
- [Release and Disabled Builds](#release-and-disabled-builds)
- [Gotchas](#gotchas)
- [Related Documentation](#related-documentation)

<a name="basic-usage"></a>
## Basic Usage

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

`MagicDevtools.installPre()` and `installPost()` make the same calls. `MagicCrumbsIntegration.install()` has to follow `Magic.init()`: the HTTP adapter looks the `network` driver up in the container.

<a name="quick-reference"></a>
## Quick Reference

| Unit | `name` | Listens to | Record | Read it with |
|:-----|:-------|:-----------|:-------|:-------------|
| `MagicHttpFacadeAdapter` | `magic_http_facade` | An interceptor on the `network` driver | `HttpRequestRecord` | `crumbs:requests` |
| `MagicModelWatcher` | `magic_model` | `ModelCreated`, `ModelSaved`, `ModelDeleted` | `ModelRecord` | `CrumbsStore.recentModels()` |
| `MagicCacheWatcher` | `magic_cache` | `CacheHit`, `CacheMiss`, `CachePut`, `CacheForget`, `CacheFlush` | `CacheRecord` | `crumbs:caches` |
| `MagicEventWatcher` | `magic_event` | `AuthLogin`, `AuthLogout`, `AuthFailed`, `AuthRestored`, `DatabaseConnected`, `GateAbilityDefined`, `GateBeforeRegistered` | `EventRecord` | `crumbs:events` |
| `MagicGateWatcher` | `magic_gate` | `GateAccessChecked` | `GateRecord` | `crumbs:gates` |
| `MagicQueryWatcher` | `magic_query` | `QueryExecuted` | `QueryRecord` | `crumbs:queries` |

`install()` is idempotent: a second call registers nothing twice. It does re-add the auth header to the masked list on every call (see [Credential Masking](#credential-masking)).

<a name="http-capture"></a>
## HTTP Capture

The adapter adds one interceptor to the driver `Magic.make<NetworkDriver>('network')` returns. Each answer becomes one `HttpRequestRecord`:

| Field | Value |
|:------|:------|
| `url`, `method`, `requestHeaders` | From the request; header values are stringified |
| `statusCode`, `isError` | From the response (`isError` is its `failed` flag); an error is always `isError: true` |
| `requestBody`, `responseBody` | Masked (below), then cut at 8192 characters with a `... [truncated N chars]` suffix; an error with a `message` stores the message as `responseBody` |
| `durationMs`, `startUs`, `endUs` | Timed on `FlutterTimeline.now` from request to answer |
| `requestId` | The id Magic's driver stamps on the request |
| `attributedHeuristically` | `true` only for an answer without an id, which is paired with the oldest id-less request in flight |
| `interactionId`, `linkedBy` | The tapir interaction the request was sent from (see [Performance](performance.md#interaction-links)) |

Requests and answers are paired by that id, so two requests that finish out of order keep their own URL and duration. An answer whose request went out before `install()` is dropped. `MagicHttpFacadeAdapter.pendingCount` is the number of requests in flight, which `CrumbsStore.pendingHttpCount` sums.

<a name="credential-masking"></a>
## Credential Masking

Every masked value reads `********` (`CrumbsRedaction.mask`).

| What | Masked by |
|:-----|:----------|
| The header `auth.token.header` names (default `Authorization`) | `install()` passes it to `CrumbsRedaction.hideRequestHeaders`, so a renamed bearer header is hidden too |
| `authorization`, `proxy-authorization`, `cookie`, `set-cookie`, `x-api-key` headers | crumbs' own defaults |
| Request body keys such as `password`, `token`, `access_token`, `secret`, `api_key` | `CrumbsRedaction.hiddenRequestParameters`, applied by the adapter before the body is stringified |
| Response body keys: the request list plus `plain_text_token`, `recovery_codes`, `qr_url`, `qr_svg` | `CrumbsRedaction.hiddenResponseParameters` |

The adapter masks a structured body (a `Map` or `List`) itself, because crumbs only parses JSON and form-encoded text, and `toString()` of a Dart map is neither. It masks a copy: the driver sends the object the interceptor saw, so masking in place would send the mask to the server.

Add your own names with `CrumbsRedaction.hideRequestHeaders`, `hideRequestParameters` and `hideResponseParameters`; additions merge with the defaults.

<a name="the-watchers"></a>
## The Watchers

| Watcher | What a record carries |
|:--------|:----------------------|
| `MagicModelWatcher` | `modelClass` (the runtime type), `event` (`created`, `saved` or `deleted`), `modelKey` (the `id` as a string, empty when null), a copy of `attributes` |
| `MagicCacheWatcher` | `operation` (`hit`, `miss`, `put`, `forget` or `flush`), `key` (`*` for a flush), `ttl` on a put |
| `MagicEventWatcher` | `eventType` (the class name) and an empty `payload` |
| `MagicGateWatcher` | `ability`, `result`, `arguments` (always one element; a `Model` is stored as `toMap()`), `userId` as a string or null |
| `MagicQueryWatcher` | `sql`, `bindings`, `timeMs`, `connectionName` |

Every record except the gate record also carries `interactionId` and `linkedBy`. Model lifecycle and `QueryExecuted` stay out of `MagicEventWatcher`, and `GateAccessDenied` is not subscribed, so each action lands on one channel once.

Each watcher guards its own `install()`, because magic's `EventDispatcher.register` is additive. `uninstall()` removes nothing: the dispatcher has no per-listener removal.

<a name="the-tapir-bridge"></a>
## The Tapir Bridge

tapir does not depend on crumbs; it reads crumbs through three function pointers this integration assigns.

| Pointer | Reads | Used by |
|:--------|:------|:--------|
| `pendingHttpCountReader` | `CrumbsStore.pendingHttpCount` | `tapir:wait_for_network_idle` |
| `recentLogsReader` | `CrumbsStore.recentLogs`, as `level`, `message`, `time`, `logger` and `error` | `tapir:console` |
| `recentExceptionsReader` | `CrumbsStore.recentExceptions`, as `type`, `message`, `time` and `stackHead` (the first three stack lines) | `tapir:exceptions` |

Without this integration the three pointers keep tapir's defaults: zero in-flight requests and empty lists.

<a name="release-and-disabled-builds"></a>
## Release and Disabled Builds

The integration has no build-mode check of its own. Under the `!kReleaseMode` guard a release build never reaches it and records nothing; a debug or profile build records everything above. A build compiled with `--dart-define=CRUMBS_DISABLE=true` turns `CrumbsPlugin.registerWatcher` and `registerHttpAdapter` into no-ops, so none of the Magic units is attached.

<a name="gotchas"></a>
## Gotchas

| Mistake | Fix |
|:--------|:----|
| Calling `MagicCrumbsIntegration.install()` before `Magic.init()`. | The adapter finds no `network` binding and attaches nothing, and the install guard stops a later call from retrying; call it after `Magic.init()`. |
| Expecting model attributes to be masked. | Only HTTP headers and bodies are masked by key; a `ModelRecord` copies every attribute as given, so keep secrets out of model attributes in a debug session. |
| Expecting HTTP records while the test uses `Http.fake()`. | The fake driver ignores interceptors, so nothing reaches crumbs; assert on the fake instead. |
| Reading `EventRecord.payload` for event details. | It is always empty; the record says which event fired and when, not its fields. |
| Registering `ExceptionWatcher` by hand and also calling `MagicDevtools.installPre()`. | Each registration chains onto `FlutterError.onError`, so every exception is recorded twice; use one style. |

<a name="related-documentation"></a>
## Related Documentation

- [Installation](../getting-started/installation.md): the two-phase install.
- [Tapir Integration](tapir-integration.md): the snapshot enrichers that read these buffers.
- [Performance](performance.md): how records are linked to tapir interactions.
- [Testing](../guides/testing.md): resetting the integration between tests.
