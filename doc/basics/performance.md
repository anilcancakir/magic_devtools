# Performance

`MagicPerfIntegration` is the data path behind tapir's perf sessions: it counts Magic's runtime activity and wind's build work, links crumbs records to tapir interactions, and adds the Magic and wind insight rules (`PerfInsightRules`) to the session report.

- [Basic Usage](#basic-usage)
- [Quick Reference](#quick-reference)
- [Why It Lives Here](#why-it-lives-here)
- [Session Modes](#session-modes)
- [What a Session Collects](#what-a-session-collects)
- [Interaction Links](#interaction-links)
- [Insight Rules](#insight-rules)
- [Gotchas](#gotchas)
- [Related Documentation](#related-documentation)

<a name="basic-usage"></a>
## Basic Usage

`MagicDevtools.installPre()` installs it, so an app wired with the umbrella needs nothing more. Without the umbrella, install it before `Magic.init()`:

```dart
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';
import 'package:magic_devtools/magic_devtools.dart';
import 'package:tapir/tapir.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kReleaseMode) {
    TapirPlugin.install();
    MagicPerfIntegration.install();
  }

  await Magic.init();

  runApp(MagicApplication());
}
```

Then drive a session from the tapir CLI against a running debug or profile build:

```bash
dart run tapir tapir:perf_begin --mode=attribution
# drive the screen you want to measure
dart run tapir tapir:perf_end
dart run tapir tapir:perf_trace --out=build/perf/trace.json
```

<a name="quick-reference"></a>
## Quick Reference

| Member | Type | Meaning |
|:-------|:-----|:--------|
| `MagicPerfIntegration.install()` | `static void` | Wires the data path. Idempotent; throws the router's `StateError` once `routerConfig` has been read. |
| `MagicPerfIntegration.interactionLink({int? startUs})` | `({String? interactionId, String linkedBy})` | The tapir interaction the calling code belongs to, and how that was decided. |
| `MagicPerfIntegration.controllerNotifyCounts` | `Map<String, int>` | `refreshUI()` calls per controller type since the last attribution session began. |
| `MagicPerfIntegration.routeTransitions` | `List<Map<String, Object?>>` | Named route pushes since the last session began, oldest first, at most 200. |
| `PerfInsightRules.evaluate(report, inputs)` | `List<Map<String, Object?>>` | The insights that fired for one report; tapir calls it through `perfInsightContributors`. |
| `PerfRuleInputs` | `final class` | The uncut counters and per-interaction joins the rules read beyond the report. |

<a name="why-it-lives-here"></a>
## Why It Lives Here

tapir may not import magic, wind or crumbs, so it declares function pointers with no-op defaults and leaves them for someone else to assign. This package is the one place where all four packages are visible, so `install()` assigns them:

| tapir pointer | Assigned to |
|:--------------|:------------|
| `framePerfReader` | crumbs' frame records (`CrumbsStore.recentFramePerf()`) and `FramePerfWatcher.livenessCounter` |
| `perfExtrasReader` | The Magic counters of the current session (below) |
| `perfTimelineReader` | The session's Magic rows plus one row per crumbs HTTP, query, event, model and cache record |
| `perfSessionBeginHook`, `perfSessionEndHook` | Turn counting on and off (see [Session Modes](#session-modes)) |
| `perfInsightContributors` | Gains `PerfInsightRules.evaluate`, added once |

`install()` also registers a crumbs `FramePerfWatcher`, calls `Wind.installPerfResolver()` and adds a navigator observer to `MagicRouter`. An unassigned pointer fails silently: the report comes back structurally complete with every counter at zero.

<a name="session-modes"></a>
## Session Modes

| Mode | wind counters | `MagicPerfHooks.sink` | Insights |
|:-----|:--------------|:----------------------|:---------|
| `attribution` (the `tapir:perf_begin` default) | On | Set to the session recorder | Evaluated |
| `timing` | Off | `null` | None |

The begin hook resets wind's counters, clears crumbs' frame buffer with `CrumbsStore.clearFramePerf()` (the HTTP, log and exception buffers stay), and resets the Magic counters and route transitions. The end hook switches counting off and removes the sink but keeps the totals, which `tapir:perf_end` reads. Between sessions the sink and wind's counters stay off; the navigator observer keeps recording route transitions, and the next begin hook clears them.

<a name="what-a-session-collects"></a>
## What a Session Collects

`perfExtrasReader` returns exactly these keys, each a map of name to count unless noted:

| Key | Counts |
|:----|:-------|
| `controllerNotifies` | Controller notifies per controller type |
| `notifyCauses` | Controller notifies per cause name |
| `queryReloads` | Query reloads per model type |
| `actions` | Actions run per action type |
| `events` | Events dispatched per event type |
| `casts` | Attribute casts per cast type (counted only, no trace row) |
| `timerTicks` | Timer ticks per owner type |
| `broadcasts` | Broadcast messages per event name |
| `routeTransitions` | A list of `route`, `durationMicros` and `time` per named push |

A route transition is timed from the navigator's push to the first post-frame callback after it. Only named routes count: a dialog or bottom sheet pushes an unnamed route and is skipped. Pops are not timed.

The trace rows use the tracks `magic.notify`, `magic.repository`, `magic.query`, `magic.action`, `magic.event`, `magic.timer` and `magic.broadcast` for the sink, and `http`, `db`, `events`, `models` and `cache` for crumbs records. The session keeps at most 2000 sink rows.

<a name="interaction-links"></a>
## Interaction Links

Every crumbs record this package writes (except gate records) and every trace row carries an `interactionId` and a `linkedBy`, decided in this order:

| `linkedBy` | When |
|:-----------|:-----|
| `zone` | The code runs in the zone of an open tapir interaction (a gesture's callbacks and the timers, microtasks and streams they created) |
| `frame` | No zone reaches it, but an interaction is active (or, for a span, an interaction's window holds the span's start) |
| `window` | No interaction; `interactionId` is null and the work belongs to the session window only |

A span that is reported when it ends (a query reload, an action, an event dispatch) is linked from its start time, so a reload that outlives the tap that started it still belongs to that tap.

<a name="insight-rules"></a>
## Insight Rules

Rules run only on an `attribution` report with at least one painted frame. Each insight has `severity: 'warn'`, and its `evidence` carries `metric`, `value`, `perFrame` and the `threshold` it fired on.

| Rule | Metric | Fires when |
|:-----|:-------|:-----------|
| Wrapper emissions | `wind.wrapperEmissions.<Type>` | A wrapper type is emitted at least `wrapperMinPerWidgetBuild` (0.5) times per W-widget build and `wrapperMinPerFrame` (20) times per frame |
| MediaQuery reads | `wind.inheritedReads.mediaQuerySize` | At least `mediaQueryMinPerFrame` (10) size reads per frame |
| Warm parse misses | `wind.cacheMisses` | No route was pushed, at least `parseMinMisses` (20) misses and a miss rate of at least `parseMinMissRate` (0.1) |
| Notify storm | `magic.notifyCauses.<cause>` | One cause (timer ticks aside) notifies at least `notifyMinPerFrame` (2) times per frame |
| Timer notifies | `magic.notifyCauses.timerTick` | Timer-driven notifies reach `timerNotifyMinPerSecond` (4) per second |
| Uncached reloads | `magic.queryReloads.uncached` | One model type reloads with its own request more than `uncachedReloadsMaxPerInteraction` (1) times in one interaction |
| Attribute casts | `magic.casts` | At least `castMinPerFrame` (50) casts per frame |
| HTTP per interaction | `magic.httpPerInteraction` | One interaction sends more than `httpMaxPerInteraction` (4) requests, or the same request more than `httpMaxSameRequestPerInteraction` (1) time |

<a name="gotchas"></a>
## Gotchas

| Mistake | Fix |
|:--------|:----|
| Wiring only `tapir:install` and `crumbs:install`, then reading a perf report of zeros. | Neither installer writes `MagicPerfIntegration`; call `MagicDevtools.installPre()` or `MagicPerfIntegration.install()`. |
| Calling `MagicPerfIntegration.install()` (or `installPre()`) after `runApp`, from a lazy debug toggle. | It throws the router's `StateError`; install it before `Magic.init()`. |
| Guarding the wiring with `kDebugMode`. | A profile build then registers nothing; use `!kReleaseMode`, since a measurement belongs on a profile build. |
| Expecting insights from a `timing` session. | Timing sessions count nothing; run an `attribution` session for insights and a `timing` one for comparable milliseconds. |
| Expecting a dialog in `routeTransitions`. | Only named pushes are timed; give the route a name if it matters. |

<a name="related-documentation"></a>
## Related Documentation

- [Installation](../getting-started/installation.md): where `installPre()` installs this.
- [Crumbs Integration](crumbs-integration.md): the records the trace and the links read.
- [Testing](../guides/testing.md): resetting the perf pointers between tests.
