import 'package:coworkplace/app/app.dart';
import 'package:coworkplace/core/notifications/notification_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:hive_flutter/hive_flutter.dart';

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await Hive.initFlutter();
  await Hive.openBox('user_profiles');
  await Hive.openBox<int>('app_prefs');
  tz_data.initializeTimeZones();
  await NotificationService.initialize();
  FlutterNativeSplash.remove();
  runApp(const ProviderScope(child: TaskArenaApp()));
}
