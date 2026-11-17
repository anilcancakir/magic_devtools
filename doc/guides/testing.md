# Testing

Test code that installs the `magic_devtools` integrations, and reset every static they leave behind so one test cannot leak enrichers, watchers or tapir pointers into the next.

- [A Test That Installs](#a-test-that-installs)
- [What Each Reset Clears](#what-each-reset-clears)
- [Faking Interactions](#faking-interactions)
- [Gotchas](#gotchas)
- [Related Documentation](#related-documentation)

<a name="a-test-that-installs"></a>
## A Test That Installs

```dart
import 'package:crumbs/crumbs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_devtools/crumbs.dart';
import 'package:magic_devtools/tapir.dart';
import 'package:tapir/tapir.dart';

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    MagicRouter.reset();
    CrumbsStore.resetForTesting();
  });

  tearDown(() {
    MagicTapirIntegration.resetForTesting();
    MagicCrumbsIntegration.resetForTesting();
  });

  test('installs the Magic enrichers once', () {
    MagicTapirIntegration.install();
    MagicTapirIntegration.install();

    expect(TapirPlugin.enrichers, hasLength(14));
  });
}
```

Every `resetForTesting()` and `isInstalled` here is `@visibleForTesting`: call them from tests only.

<a name="what-each-reset-clears"></a>
## What Each Reset Clears

| Call | Clears | Leaves |
|:-----|:-------|:-------|
| `MagicDevtools.resetForTesting()` | Uninstalls the `ExceptionWatcher` and `DumpWatcher` that `installPre()` registered, which restores `FlutterError.onError`, the platform error callback and `debugPrint`; the next `installPre()` registers a new pair | The plugins and the perf integration |
| `MagicTapirIntegration.resetForTesting()` | Removes the 14 enrichers from `TapirPlugin.enrichers`, clears the navigate adapter, cancels the Echo subscription, drops the install guard | Enrichers the app added itself |
| `MagicCrumbsIntegration.resetForTesting()` | Drops the install guard; puts back the `log` manager `MagicLogWatcher` wrapped; resets `pendingHttpCountReader`, `recentLogsReader` and `recentExceptionsReader` to zero and empty lists | The adapter and the six watchers registered with `CrumbsPlugin`, and their `EventDispatcher` listeners |
| `MagicPerfIntegration.resetForTesting()` | Drops the install guard, clears the session counters and route transitions, removes `MagicPerfHooks.sink` and the insight contributor, uninstalls the frame watcher, turns wind's counting off, restores the interaction sources and puts every tapir perf pointer back to the default tapir declared | The navigator observer, which `MagicRouter.reset()` drops with the router |
| `MagicPreview.resetForTesting()` | The registered entries | Routes already added; `MagicRouter.reset()` clears those |

Pair them with the resets of the packages underneath:

| Call | Why |
|:-----|:----|
| `CrumbsStore.resetForTesting()` | Empties every crumbs buffer and restores the default masked names, including the auth header `MagicCrumbsIntegration.install()` added |
| `EventDispatcher.instance.clear()` | Removes the model, cache, event, gate and query listeners, since the watchers cannot remove their own |
| `MagicRouter.reset()` | A fresh router, unlocked, without the perf observer or the preview routes |
| `Gate.manager.flush()` | Empties the gate result cache the gate enrichers read |

<a name="faking-interactions"></a>
## Faking Interactions

tapir's `PerfInteraction` has a private constructor, so a host test cannot open a real interaction without a perf session over the VM Service. Three static fields on `MagicPerfIntegration` decide what counts as one, and a test may replace them:

| Field | Default reads |
|:------|:--------------|
| `zoneInteraction` | A `PerfInteraction` stored in the zone under `PerfInteraction.zoneKey` (`#tapir_interaction`) |
| `interactionIdAt` | tapir's `perfInteractionAt(us)` |
| `activeInteractionId` | tapir's `activeInteraction()` |

`MagicPerfIntegration.resetForTesting()` puts all three back.

<a name="gotchas"></a>
## Gotchas

| Mistake | Fix |
|:--------|:----|
| Calling `MagicDevtools.installPre()` in a `testWidgets` case and restoring `debugPrint` in `tearDown`. | flutter_test checks its debug variables right after the test body, before `tearDown`; call `MagicDevtools.resetForTesting()` at the end of the body. |
| Resetting `MagicCrumbsIntegration` and expecting its watchers gone. | The reset drops the guard only; clear `EventDispatcher.instance` too, or a reinstall records each event twice. |
| Calling `MagicPerfIntegration.install()` twice across tests without `MagicRouter.reset()`. | The reset clears the observer flag, so the next install adds a second observer to the same router; reset the router as well. |
| Asserting crumbs HTTP records while using `Http.fake()`. | The fake driver ignores interceptors; assert on the fake. |
| Expecting `MagicCrumbsIntegration.resetForTesting()` to restore the masked header list. | It does not; `CrumbsStore.resetForTesting()` restores crumbs' defaults, and the next `install()` adds the auth header again. |

<a name="related-documentation"></a>
## Related Documentation

- [Installation](../getting-started/installation.md): what each install call wires.
- [Tapir Integration](../basics/tapir-integration.md): the enrichers the reset removes.
- [Crumbs Integration](../basics/crumbs-integration.md): the watchers and the tapir bridge.
- [Performance](../basics/performance.md): the perf pointers and the interaction links.
