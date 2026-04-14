import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'database/app_database.dart';
import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

class KhataApp extends StatelessWidget {
  const KhataApp({super.key, required this.database, required this.settings});

  final AppDatabase database;
  final SettingsProvider settings;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: database),
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'Virtual Manager',
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(
              urduFont: settings.urduFont,
              englishFont: settings.englishFont,
            ),
            home: const SplashScreen(child: HomeScreen()),
          );
        },
      ),
    );
  }
}
