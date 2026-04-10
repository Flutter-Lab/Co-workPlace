import 'package:coworkplace/app/app.dart';
import 'package:coworkplace/core/notifications/notification_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:hive_flutter/hive_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('user_profiles');
  await Hive.openBox<int>('app_prefs');
  tz_data.initializeTimeZones();
  await NotificationService.initialize();
  runApp(const ProviderScope(child: TaskArenaApp()));
}
