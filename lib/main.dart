import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'app.dart';
import 'schedule_controller.dart';
import 'storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await pdfrxFlutterInitialize();
  final controller = ScheduleController(ScheduleStore());
  await controller.initialize();
  runApp(ReScheduleApp(controller: controller));
}
