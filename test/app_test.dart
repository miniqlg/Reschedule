import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_schedule/app.dart';
import 'package:re_schedule/schedule_controller.dart';
import 'package:re_schedule/storage.dart';

void main() {
  testWidgets('三个主页面可在小屏设备切换', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = ScheduleController(ScheduleStore())..loading = false;
    await tester.pumpWidget(ReScheduleApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('今天'), findsWidgets);
    expect(find.text('本周'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);

    await tester.tap(find.text('本周'));
    await tester.pumpAndSettle();
    expect(find.text('本周课表'), findsOneWidget);

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.text('课表数据'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
