import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'screens/schedule/schedule_screen.dart';
import 'services/native_alarm_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize shared prayer schedule service (creates DB + seeds on first run).
  await PrayerScheduleController.instance.init();
  NativeAlarmService.instance.startListening();

  runApp(const SalahSilentApp());
}
