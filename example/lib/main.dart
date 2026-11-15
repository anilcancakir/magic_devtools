import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';
import 'package:magic_devtools/magic_devtools.dart';
import 'package:magic_devtools/preview.dart';

/// Boots a Magic app with tapir and crumbs wired around `Magic.init()`.
///
/// Every devtools call sits under `!kReleaseMode` here, at the call site:
/// `kReleaseMode` is a compile-time constant, so a release build drops the
/// branches and, with them, tapir, crumbs and `magic_devtools`. Debug and
/// profile builds keep the tools.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Before Magic boots: the tool plugins, crumbs' exception and dump
  //    watchers, and the perf path, whose navigator observer the router
  //    refuses once `Magic.init()` has built it.
  if (!kReleaseMode) MagicDevtools.installPre();

  // 2. Magic registers and boots the providers, then builds the router.
  await Magic.init(configs: [_config]);

  // 3. After Magic boots: the HTTP adapter and the snapshot enrichers resolve
  //    the container, which exists only now.
  if (!kReleaseMode) MagicDevtools.installPost();

  runApp(const MagicApplication(title: 'magic_devtools example'));
}

/// The network driver gives crumbs' HTTP adapter something to intercept;
/// nothing listens on the port, so a request fails fast and is recorded.
///
/// The auth provider is there because the `magicAuthUser` enricher reads
/// `Auth.user()`, and a snapshot with enrichers fails in an app whose
/// container has no `auth` binding.
Map<String, dynamic> get _config => {
  'network': {
    'default': 'api',
    'drivers': {
      'api': {'base_url': 'http://localhost:8000/api/v1', 'timeout': 10000},
    },
  },
  'app': {
    'providers': [
      (app) => NetworkServiceProvider(app),
      (app) => AuthServiceProvider(app),
      (app) => ExampleRouteServiceProvider(app),
    ],
  },
};

/// Registers the home page and the preview catalog.
///
/// `boot()` runs inside `Magic.init()` before the router locks its route
/// table, which is the only window in which `/preview` can be added.
class ExampleRouteServiceProvider extends ServiceProvider {
  ExampleRouteServiceProvider(super.app);

  @override
  void register() {}

  @override
  Future<void> boot() async {
    MagicRoute.page('/', () => const HomeView());

    if (!kReleaseMode) {
      MagicPreview.register(previewEntries());
      MagicPreview.registerRoutes();
    }
  }
}

/// The catalog entries, returned from a function rather than held in a
/// top-level const list, so a release build can drop every entry.
///
/// An app generates this function into `_previews.g.dart` with
/// `dart run magic:dowel previews:refresh`; it is written by hand here to keep
/// the example in one file.
List<PreviewEntry> previewEntries() => <PreviewEntry>[
  PreviewEntry(
    label: 'Notice',
    slug: 'notice',
    builder: (_) => const NoticePreview(),
  ),
  PreviewEntry(
    label: 'PrimaryButton',
    slug: 'primary_button',
    builder: (_) => const PrimaryButtonPreview(),
  ),
];

/// One screen with something for each tool to record or read.
class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-col gap-4 p-6 w-full h-full bg-surface',
      children: [
        const WText(
          'magic_devtools example',
          className: 'text-fg text-xl font-semibold',
        ),
        const WText(
          'Each button gives tapir or crumbs something to see.',
          className: 'text-fg-muted text-sm',
        ),
        _action(
          label: 'Open the preview catalog',
          onTap: () => MagicRoute.to('/preview'),
        ),
        // Nothing listens on localhost:8000, so the request fails and crumbs
        // records it through the HTTP adapter installPost() attached.
        _action(label: 'Send a request', onTap: () => Http.get('/health')),
        // DumpWatcher, registered by installPre(), captures debugPrint.
        _action(
          label: 'Print a line',
          onTap: () => debugPrint('magic_devtools example: hello'),
        ),
      ],
    );
  }

  Widget _action({required String label, required VoidCallback onTap}) {
    return WButton(
      onTap: onTap,
      className: 'px-4 py-2 rounded-md bg-primary',
      child: WText(label, className: 'text-white text-sm'),
    );
  }
}

/// A preview of an informational notice.
class NoticePreview extends StatelessWidget {
  const NoticePreview({super.key});

  @override
  Widget build(BuildContext context) {
    return const WDiv(
      className: 'p-4 rounded-md border border-color-border bg-surface',
      child: WText('Your changes were saved.', className: 'text-fg text-sm'),
    );
  }
}

/// A preview of the primary action button.
class PrimaryButtonPreview extends StatelessWidget {
  const PrimaryButtonPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return WButton(
      onTap: () {},
      className: 'px-4 py-2 rounded-md bg-primary',
      child: const WText('Save', className: 'text-white'),
    );
  }
}
