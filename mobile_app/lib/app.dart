// lib/app.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'routes/app_routes.dart';
import 'core/constants/theme/app_theme.dart';
import 'state/theme_provider.dart';
import 'state/user_provider.dart';
import 'state/recipe_provider.dart';
import 'state/saved_recipes_provider.dart';


class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  void initState() {
    super.initState();
    // Load saved profile from Firebase as soon as the app starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProvider>().loadFromFirebase();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'PIATRA',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          initialRoute: AppRoutes.home,
          onGenerateRoute: AppRoutes.onGenerateRoute,
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

class _AppProviders extends StatelessWidget {
  const _AppProviders();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => RecipeProvider()),
        ChangeNotifierProvider(
          create: (_) => SavedRecipesProvider()..init(),
        ),
      ],
      child: const App(),
    );
  }
}

/// Top-level widget — use this in main.dart instead of App() directly.
class RootApp extends StatelessWidget {
  const RootApp({super.key});

  @override
  Widget build(BuildContext context) => const _AppProviders();
}