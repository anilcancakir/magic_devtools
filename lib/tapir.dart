/// Magic ↔ tapir integration adapter barrel.
///
/// Import this file when your app uses both magic and tapir
/// and wants the MagicTapirIntegration enrichers wired into TapirPlugin.
/// Consumers MUST add magic_devtools as a regular dependency (lib/main.dart
/// imports it under `!kReleaseMode`, so a dev_dependency would trip
/// `depend_on_referenced_packages`); it depends on magic and tapir, so
/// transitive resolution does not happen through magic itself.
///
/// Host integration (debug-only in lib/main.dart). MagicTapirIntegration
/// MUST run AFTER `Magic.init()` because its enrichers query
/// `Magic.find<X>()` for form / nav / controller state. TapirPlugin
/// itself installs BEFORE `Magic.init()` so the snapshot pipeline is
/// live during Magic boot:
///
/// ```dart
/// if (!kReleaseMode) {
///   TapirPlugin.install();
/// }
/// await Magic.init(configFactories: [...]);
/// if (!kReleaseMode) {
///   MagicTapirIntegration.install();
/// }
/// ```
///
/// See `src/tapir_integration.dart` for the concrete MagicTapirIntegration
/// class and 14 enrichers.
library;

export 'src/tapir_integration.dart';
