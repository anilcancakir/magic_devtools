import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:tapir/tapir.dart';
import 'package:crumbs/crumbs.dart';

import 'tapir_integration.dart';
import 'perf_integration.dart';
import 'crumbs_integration.dart';

export 'perf_insight_rules.dart';
export 'perf_integration.dart';

/// One-call wiring for the Magic dev-tooling bundle: tapir +
/// crumbs and their Magic integrations, installed in the two
/// phases that straddle [Magic.init].
///
/// The two tools cannot install in a single call because half of the work
/// has to happen BEFORE `Magic.init()` and half AFTER:
///
/// - [installPre] boots both plugins (VM Service extensions, capture hooks,
///   the tapir snapshot pipeline) and registers crumbs' opt-in
///   [ExceptionWatcher] + [DumpWatcher]. It MUST run before `Magic.init()`
///   so the snapshot pipeline and ExceptionWatcher are already live while
///   Magic boots (they capture boot-time errors and the first route resolve).
/// - [installPost] wires Magic's runtime into both tools
///   ([MagicCrumbsIntegration] + [MagicTapirIntegration]). It MUST run
///   after `Magic.init()` because the watchers, the HTTP adapter, and the
///   snapshot enrichers resolve dependencies through the IoC container
///   (`Magic.find` / `Magic.bound`).
///
/// Keep both calls inside a `!kReleaseMode` guard AT THE CALL SITE (debug and
/// profile builds carry the tools; release tree-shakes them). Do not move
/// the guard inside these methods: a live (unguarded) call defeats the
/// release tree-shake and pulls tapir + crumbs into the production bundle,
/// which is the whole reason this wiring lives outside `magic` core.
///
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///
///   if (!kReleaseMode) MagicDevtools.installPre();
///
///   await Magic.init(configFactories: [...]);
///
///   if (!kReleaseMode) MagicDevtools.installPost();
///
///   runApp(const MyApp());
/// }
/// ```
///
/// This is the umbrella entry point; reach for the finer-grained
/// `tapir.dart`, `crumbs.dart`, or `preview.dart` barrels only when you
/// need a non-standard watcher set or want to wire one tool without the
/// other.
class MagicDevtools {
  MagicDevtools._();

  /// Pre-`Magic.init()` half: boot both tool plugins and register the
  /// standard opt-in crumbs watchers.
  ///
  /// Installs [TapirPlugin] (Semantics tree, `ext.tapir.*` extensions,
  /// error/log capture) and [CrumbsPlugin] (`ext.crumbs.*`
  /// extensions, auto [LogWatcher]), then registers [ExceptionWatcher] and
  /// [DumpWatcher]: the two watchers crumbs leaves opt-in but every Magic
  /// dev session wants (uncaught exceptions and `debugPrint` dumps).
  ///
  /// Also installs [MagicPerfIntegration], the performance data path. It
  /// belongs in this half rather than [installPost] because it registers a
  /// [NavigatorObserver] through `MagicRouter.addObserver`, which throws once
  /// the router has been built; the rest of its wiring would work from either
  /// half and is kept with it at the one install site.
  ///
  /// Every step is idempotent, so a second call in the same isolate is safe:
  /// the two opt-in watchers guard per instance and `registerWatcher` takes a
  /// new one each time, so this class keeps the pair it registered and a second
  /// call adds none (a second pair would chain onto the first and record every
  /// exception and `debugPrint` twice). Register additional watchers after this
  /// call via [CrumbsPlugin.registerWatcher].
  ///
  /// It is NOT safe to call late, though, and that is new: the perf
  /// integration registers a [NavigatorObserver], and `MagicRouter.addObserver`
  /// throws a [StateError] once the router has been built. A host that installs
  /// this behind a lazy debug toggle after `runApp` used to get harmless
  /// no-ops and now crashes. The throw is deliberate, since a silently
  /// unregistered observer would produce a report with no route transitions
  /// and nothing to explain their absence, but it means this belongs at boot
  /// and nowhere else.
  static void installPre() {
    TapirPlugin.install();

    CrumbsPlugin.install();
    if (_exceptionWatcher == null) {
      CrumbsPlugin.registerWatcher(_exceptionWatcher = ExceptionWatcher());
      CrumbsPlugin.registerWatcher(_dumpWatcher = DumpWatcher());
    }

    MagicPerfIntegration.install();
  }

  /// Post-`Magic.init()` half: wire Magic's runtime into both tools.
  ///
  /// Installs [MagicCrumbsIntegration] (6 Magic watchers +
  /// `MagicHttpFacadeAdapter` + the tapir-to-crumbs bridge readers) and
  /// [MagicTapirIntegration] (14 Magic-aware snapshot enrichers + the
  /// [MagicRouter] navigate adapter). Both resolve their dependencies
  /// through the IoC container, so [Magic.init] must have completed first.
  ///
  /// Both integrations are idempotent.
  static void installPost() {
    MagicCrumbsIntegration.install();
    MagicTapirIntegration.install();
  }

  /// Test-only reset. Uninstalls the exception and dump watchers [installPre]
  /// registered, which restores `FlutterError.onError`, the platform error
  /// callback and `debugPrint`, and lets the next [installPre] register a pair.
  @visibleForTesting
  static void resetForTesting() {
    _exceptionWatcher?.uninstall();
    _dumpWatcher?.uninstall();
    _exceptionWatcher = null;
    _dumpWatcher = null;
  }

  static ExceptionWatcher? _exceptionWatcher;
  static DumpWatcher? _dumpWatcher;
}
