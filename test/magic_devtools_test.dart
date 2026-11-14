import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tapir/src/tapir_plugin.dart' show tapirInstallCount;
import 'package:tapir/tapir.dart';
import 'package:crumbs/crumbs.dart';
import 'package:magic/magic.dart';
import 'package:magic_devtools/tapir.dart';
import 'package:magic_devtools/magic_devtools.dart';
import 'package:magic_devtools/crumbs.dart';

/// Tests for the [MagicDevtools] umbrella wiring.
///
/// [installPre] and [installPost] delegate to the underlying plugin +
/// integration installs (each covered in depth by tapir_integration_test /
/// crumbs_integration_test). These tests assert only that the umbrella
/// groups them into the correct pre/post halves and that the composed calls
/// stay idempotent.
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    MagicRouter.reset();
    MagicTapirIntegration.resetForTesting();
    MagicCrumbsIntegration.resetForTesting();
    CrumbsStore.resetForTesting();
  });

  tearDown(() {
    MagicDevtools.resetForTesting();
    MagicTapirIntegration.resetForTesting();
    MagicCrumbsIntegration.resetForTesting();
  });

  group('MagicDevtools.installPre', () {
    test('boots both tool plugins', () {
      MagicDevtools.installPre();

      expect(tapirInstallCount, greaterThan(0));
      expect(CrumbsPlugin.installCount, greaterThan(0));
    });

    group('opt-in crumbs watchers', () {
      late FlutterExceptionHandler? savedOnError;
      late DebugPrintCallback savedDebugPrint;

      setUp(() {
        savedOnError = FlutterError.onError;
        savedDebugPrint = debugPrint;
        // flutter_test's own handler fails the test on a reported error and
        // debugPrint writes to the console; end both chains in a no-op.
        FlutterError.onError = (FlutterErrorDetails details) {};
        debugPrint = (String? message, {int? wrapWidth}) {};
      });

      tearDown(() {
        MagicDevtools.resetForTesting();
        FlutterError.onError = savedOnError;
        debugPrint = savedDebugPrint;
      });

      test('a second call registers no second exception watcher', () {
        MagicDevtools.installPre();
        MagicDevtools.installPre();

        FlutterError.onError!(
          FlutterErrorDetails(exception: StateError('boom')),
        );

        expect(CrumbsStore.recentExceptions(), hasLength(1));
      });

      test('a second call registers no second dump watcher', () {
        MagicDevtools.installPre();
        MagicDevtools.installPre();

        debugPrint('hello');

        expect(CrumbsStore.recentDumps(), hasLength(1));
      });
    });
  });

  group('MagicDevtools.installPost', () {
    test('installs both Magic integrations', () {
      expect(TapirPlugin.enrichers, isEmpty);

      MagicDevtools.installPost();

      expect(MagicTapirIntegration.isInstalled, isTrue);
      expect(MagicCrumbsIntegration.isInstalled, isTrue);
      // MagicTapirIntegration registers its full 14-enricher chain.
      expect(TapirPlugin.enrichers, hasLength(14));
    });

    test('is idempotent on a second call', () {
      MagicDevtools.installPost();
      MagicDevtools.installPost();

      expect(TapirPlugin.enrichers, hasLength(14));
    });
  });
}
