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
    expect(find.byIcon(Icons.calendar_view_week_outlined), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.calendar_view_week_outlined));
    await tester.pumpAndSettle();
    expect(find.text('本周课表'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('课表数据'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('重新打开周课表会回到当前周', (tester) async {
    final controller = ScheduleController(ScheduleStore())..loading = false;
    await tester.pumpWidget(ReScheduleApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.calendar_view_week_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('下一周'));
    await tester.pumpAndSettle();
    expect(find.text('第 2 周'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.calendar_view_week_outlined));
    await tester.pumpAndSettle();
    expect(find.text('第 1 周'), findsOneWidget);
  });
}
