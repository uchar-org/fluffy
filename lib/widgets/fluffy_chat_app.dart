import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fluffychat/config/routes.dart';
import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/config/locale_provide.dart';
import 'package:fluffychat/widgets/app_lock.dart';
import 'package:fluffychat/widgets/theme_builder.dart';
import '../utils/custom_scroll_behaviour.dart';
import 'matrix.dart';

class FluffyChatApp extends StatelessWidget {
  final Widget? testWidget;
  final List<Client> clients;
  final String? pincode;
  final SharedPreferences store;

  const FluffyChatApp({
    super.key,
    this.testWidget,
    required this.clients,
    required this.store,
    this.pincode,
  });

  static bool gotInitialLink = false;

  static final GoRouter router = GoRouter(
    routes: AppRoutes.routes,
    debugLogDiagnostics: true,
  );

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LocaleProvider>(
        create: (_) => LocaleProvider(),
        child: ThemeBuilder(
          builder: (context, themeMode, primaryColor) {
            return MaterialApp.router(
              title: AppSettings.applicationName.value,
              themeMode: themeMode,
              theme: FluffyThemes.buildTheme(
                  context, Brightness.light, primaryColor),
              darkTheme: FluffyThemes.buildTheme(
                  context, Brightness.dark, primaryColor),
              scrollBehavior: CustomScrollBehavior(),
              locale: context.watch<LocaleProvider>().locale,
              localizationsDelegates: L10n.localizationsDelegates,
              supportedLocales: L10n.supportedLocales,
              routerConfig: router,
              builder: (context, child) => AppLockWidget(
                pincode: pincode,
                clients: clients,
                child: Matrix(
                  clients: clients,
                  store: store,
                  child: testWidget ?? child,
                ),
              ),
            );
          },
        ));
  }
}
