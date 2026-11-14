/// magic_devtools umbrella barrel.
///
/// Exposes [MagicDevtools], the one-call `installPre` / `installPost` wiring
/// for tapir and crumbs plus their Magic
/// integrations, installed around [Magic.init] under `!kReleaseMode`.
///
/// See the finer-grained `tapir.dart`, `crumbs.dart`, and `preview.dart`
/// barrels when you need direct access to a single integration, a
/// non-standard watcher set, or the preview catalog.
library;

export 'src/magic_devtools.dart';
