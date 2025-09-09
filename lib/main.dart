import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quick_photo_sorter/screens/date_selection_screen.dart';
import 'services/app_state.dart';
import 'services/photo_sorter_model.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/permission_screen.dart';
import 'screens/home_screen.dart';
import 'screens/swipe_sort_screen.dart';
import 'screens/trash_screen.dart'; // ← Import trash screen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final photoSorterModel = PhotoSorterModel();
  photoSorterModel.loadAllImages();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()..initialize()),
        ChangeNotifierProvider(create: (_) => PhotoSorterModel()),
        ChangeNotifierProvider.value(value: photoSorterModel),
      ],
      child: const QuickPhotoSorter(),
    ),
  );
}

class QuickPhotoSorter extends StatelessWidget {
  const QuickPhotoSorter({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quick Gallery Cleaner',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      home: StartupRouter(),
      routes: {
        OnboardingScreen.routeName: (_) => const OnboardingScreen(),
        PermissionScreen.routeName: (_) => const PermissionScreen(),
        HomeScreen.routeName: (_) => const HomeScreen(),
        TrashScreen.routeName: (_) => const TrashScreen(),
        DateSelectionScreen.routeName: (context) =>
            DateSelectionScreen(), // Add this line
        SwipeSortScreen.routeName: (ctx) {
          final modeName = ModalRoute.of(ctx)!.settings.arguments as String;
          return SwipeSortScreen(modeName: modeName);
        },
      },
    );
  }
}

class StartupRouter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    if (!appState.initialized) {
      return const SplashScreen();
    }
    if (!appState.seenOnboarding) {
      return const OnboardingScreen();
    }
    if (!appState.permissionGranted) {
      return const PermissionScreen();
    }
    return const HomeScreen();
  }
}
