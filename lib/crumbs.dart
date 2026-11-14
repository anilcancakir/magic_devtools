/// Magic ↔ crumbs integration adapter barrel.
///
/// Import this file when your app uses both magic and crumbs
/// and wants the MagicCrumbsIntegration watchers wired into CrumbsPlugin.
/// Consumers MUST add magic_devtools as a regular dependency (lib/main.dart
/// imports it under `!kReleaseMode`, so a dev_dependency would trip
/// `depend_on_referenced_packages`); it depends on magic and crumbs, so
/// transitive resolution does not happen through magic itself.
///
/// Host integration (debug-only in lib/main.dart). MagicCrumbsIntegration
/// MUST run AFTER `Magic.init()` because MagicHttpFacadeAdapter resolves
/// the NetworkDriver via the IoC container. CrumbsPlugin itself
/// installs BEFORE `Magic.init()`, and so does the opt-in ExceptionWatcher
/// that catches Magic boot errors:
///
/// ```dart
/// if (!kReleaseMode) {
///   CrumbsPlugin.install();
///   CrumbsPlugin.registerWatcher(ExceptionWatcher());
///   CrumbsPlugin.registerWatcher(DumpWatcher());
/// }
/// await Magic.init(configFactories: [...]);
/// if (!kReleaseMode) {
///   MagicCrumbsIntegration.install();
/// }
/// ```
///
/// See `src/crumbs_integration.dart` for the concrete
/// MagicCrumbsIntegration class, its 5 Magic watchers, and
/// MagicHttpFacadeAdapter.
library;

export 'src/crumbs_integration.dart';
