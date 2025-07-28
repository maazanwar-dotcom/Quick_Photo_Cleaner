import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppState extends ChangeNotifier {
  bool _initialized = false;
  bool _seenOnboarding = false;
  bool _permissionGranted = false;

  bool get initialized => _initialized;
  bool get seenOnboarding => _seenOnboarding;
  bool get permissionGranted => _permissionGranted;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _seenOnboarding = prefs.getBool('seenOnboarding') ?? false;
    _permissionGranted = prefs.getBool('permissionGranted') ?? false;
    _initialized = true;
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenOnboarding', true);
    _seenOnboarding = true;
    notifyListeners();
  }

  Future<void> grantPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('permissionGranted', true);
    _permissionGranted = true;
    notifyListeners();
  }
}
