import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'importers.dart';
import 'models.dart';
import 'schedule_controller.dart';

const _courseColors = <Color>[
  Color(0xff0f766e),
  Color(0xff2563eb),
  Color(0xff7c3aed),
  Color(0xffc2410c),
  Color(0xffbe185d),
  Color(0xff047857),
  Color(0xff4338ca),
  Color(0xffb45309),
];

const _weekdayNames = ['一', '二', '三', '四', '五', '六', '日'];

class ReScheduleApp extends StatelessWidget {
  const ReScheduleApp({super.key, required this.controller});

  final ScheduleController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => MaterialApp(
      title: 'Re课表',
      debugShowCheckedModeBanner: false,
      themeMode: switch (controller.settings.theme) {
        AppThemePreference.light => ThemeMode.light,
        AppThemePreference.dark => ThemeMode.dark,
        AppThemePreference.system => ThemeMode.system,
      },
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: HomeShell(controller: controller),
    ),
  );

  ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xff0f766e),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: brightness == Brightness.light
          ? const Color(0xfff6faf9)
          : const Color(0xff101716),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.controller});
  final ScheduleController controller;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      TodayPage(controller: widget.controller),
      WeekPage(controller: widget.controller),
      SettingsPage(controller: widget.controller),
    ];
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _index, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: '',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_view_week_outlined),
            selectedIcon: Icon(Icons.calendar_view_week),
            label: '',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '',
          ),
        ],
      ),
      floatingActionButton: _index == 2
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _editCourse(context, widget.controller),
              icon: const Icon(Icons.add),
              label: const Text('添加课程'),
            ),
    );
  }
}

class TodayPage extends StatelessWidget {
  const TodayPage({super.key, required this.controller});
  final ScheduleController controller;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final settings = controller.settings;
    final week = settings.weekFor(now);
    final courses = week != null && settings.isWeekInSemester(week)
        ? controller.coursesFor(week, now.weekday)
        : const <Course>[];
    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
          title: const Text('今天'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${now.month}月${now.day}日 · 星期${_weekdayNames[now.weekday - 1]}',
                ),
              ),
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          sliver: SliverList.list(
            children: [
              _WeekHero(settings: settings, week: week),
              const SizedBox(height: 18),
              if (settings.startDate == null)
                const _EmptyState(
                  icon: Icons.event_note,
                  title: '先设置开学日期',
                  message: '完成学期设置后，今天的课程会自动出现。',
                )
              else if (week != null && week! < 1)
                const _EmptyState(
                  icon: Icons.hourglass_top,
                  title: '学期还没开始',
                  message: '可以先在本周页面查看已导入的课程。',
                )
              else if (week != null && !settings.isWeekInSemester(week))
                const _EmptyState(
                  icon: Icons.beach_access_outlined,
                  title: '本学期已结束',
                  message: '新学期开始时，在设置页重新导入课表。',
                )
              else if (courses.isEmpty)
                const _EmptyState(
                  icon: Icons.free_breakfast_outlined,
                  title: '今天没有课',
                  message: '留一点时间给自己。',
                )
              else
                ...courses.map(
                  (course) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _TodayCourseCard(
                      course: course,
                      settings: settings,
                      onTap: () => _editCourse(context, controller, course),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeekHero extends StatelessWidget {
  const _WeekHero({required this.settings, required this.week});
  final SemesterSettings settings;
  final int? week;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xff0f766e), Color(0xff0891b2)],
      ),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                settings.name.isEmpty ? '当前学期' : settings.name,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 4),
              Text(
                week == null
                    ? '待设置'
                    : week! < 1
                    ? '开学前'
                    : '第 $week 周',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.school_outlined, color: Colors.white, size: 44),
      ],
    ),
  );
}

class _TodayCourseCard extends StatelessWidget {
  const _TodayCourseCard({
    required this.course,
    required this.settings,
    required this.onTap,
  });
  final Course course;
  final SemesterSettings settings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _courseColors[course.colorIndex % _courseColors.length];
    final start = settings.periodTimes[course.startPeriod]?.start;
    final end = settings.periodTimes[course.endPeriod]?.end;
    final time = start?.isNotEmpty == true && end?.isNotEmpty == true
        ? '$start–$end'
        : '第${course.startPeriod}–${course.endPeriod}节';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 5,
                height: 72,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$time${course.location.isEmpty ? '' : ' · ${course.location}'}',
                    ),
                    if (course.teacher.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        course.teacher,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

DateTime _weekStart(SemesterSettings settings, int week) {
  final date = settings.startDate;
  if (date != null) return date.add(Duration(days: (week - 1) * 7));
  final now = DateTime.now();
  return now.subtract(Duration(days: now.weekday - 1));
}

String _weekLabel(int? week) {
  if (week == null) return '待设置';
  if (week! < 1) return '开学前';
  return '第 $week 周';
}

class WeekPage extends StatefulWidget {
  const WeekPage({super.key, required this.controller});
  final ScheduleController controller;

  @override
  State<WeekPage> createState() => _WeekPageState();
}

class _WeekPageState extends State<WeekPage> {
  late int _week;

  @override
  void initState() {
    super.initState();
    final current = widget.controller.settings.weekFor(DateTime.now());
    _week = current == null || current < 1 ? 1 : current;
  }

  @override
  Widget build(BuildContext context) {
    final totalWeeks = widget.controller.settings.totalWeeks;
    if (totalWeeks != null) _week = _week.clamp(1, totalWeeks);
    return Scaffold(
      appBar: AppBar(
        title: const Text('本周课表'),
        actions: [
          IconButton(
            tooltip: '上一周',
            onPressed: _week > 1 ? () => setState(() => _week--) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Center(child: Text('第 $_week 周')),
          IconButton(
            tooltip: '下一周',
            onPressed: totalWeeks == null || _week < totalWeeks
                ? () => setState(() => _week++)
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) < -250 &&
              (totalWeeks == null || _week < totalWeeks)) {
            setState(() => _week++);
          } else if ((details.primaryVelocity ?? 0) > 250 && _week > 1) {
            setState(() => _week--);
          }
        },
        child: _WeekGrid(
          controller: widget.controller,
          week: _week,
          onCourseTap: (course) =>
              _editCourse(context, widget.controller, course),
        ),
      ),
    );
  }
}

class _WeekGrid extends StatelessWidget {
  const _WeekGrid({
    required this.controller,
    required this.week,
    required this.onCourseTap,
  });
  final ScheduleController controller;
  final int week;
  final ValueChanged<Course> onCourseTap;

  static const periodWidth = 46.0;
  static const dayWidth = 44.0;
  static const headerHeight = 46.0;
  static const rowHeight = 68.0;

  @override
  Widget build(BuildContext context) {
    const width = periodWidth + dayWidth * 7;
    final weekStart = _weekStart(controller.settings, week);
    const height = headerHeight + rowHeight * 11;
    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              children: [
                for (var day = 0; day < 7; day++)
                  Positioned(
                    left: periodWidth + day * dayWidth,
                    top: 0,
                    width: dayWidth,
                    height: headerHeight,
                    child: _GridLabel(label: '星期${_weekdayNames[day]}'),
                  ),
                for (var period = 1; period <= 11; period++)
                  Positioned(
                    left: 0,
                    top: headerHeight + (period - 1) * rowHeight,
                    width: periodWidth,
                    height: rowHeight,
                    child: InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              PeriodTimesPage(controller: controller),
                        ),
                      ),
                      child: _GridLabel(
                        label: _periodLabel(
                          period,
                          controller.settings.periodTimes[period],
                        ),
                      ),
                    ),
                  ),
                for (var day = 1; day <= 7; day++)
                  for (var period = 1; period <= 11; period++)
                    Positioned(
                      left: periodWidth + (day - 1) * dayWidth,
                      top: headerHeight + (period - 1) * rowHeight,
                      width: dayWidth,
                      height: rowHeight,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).dividerColor.withValues(alpha: 0.35),
                            width: 0.5,
                          ),
                        ),
                      ),
                    ),
                for (final course in controller.courses)
                  Positioned(
                    left: periodWidth + (course.dayOfWeek - 1) * dayWidth + 3,
                    top:
                        headerHeight + (course.startPeriod - 1) * rowHeight + 3,
                    width: dayWidth - 6,
                    height:
                        (course.endPeriod - course.startPeriod + 1) *
                            rowHeight -
                        6,
                    child: _WeekCourseCard(
                      course: course,
                      active: course.weeks.contains(week),
                      onTap: () => onCourseTap(course),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _periodLabel(int period, PeriodTime? time) {
  if (time == null || time.start.isEmpty || time.end.isEmpty) {
    return '$period\n未设置';
  }
  return '$period\n${time.start}\n${time.end}';
}

class _GridLabel extends StatelessWidget {
  const _GridLabel({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainer,
      border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
    ),
    child: Text(label, style: Theme.of(context).textTheme.labelMedium),
  );
}

class _WeekCourseCard extends StatelessWidget {
  const _WeekCourseCard({
    required this.course,
    required this.active,
    required this.onTap,
  });
  final Course course;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final color = active
        ? _courseColors[course.colorIndex % _courseColors.length]
        : Colors.blueGrey;
    return Material(
      color: color.withValues(alpha: active ? 0.92 : 0.18),
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!active)
                const Text(
                  '非本周',
                  style: TextStyle(fontSize: 9, color: Colors.blueGrey),
                ),
              Text(
                course.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? Colors.white : Colors.blueGrey,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              if (course.location.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  course.location,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active ? Colors.white : Colors.blueGrey,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.controller});
  final ScheduleController controller;

  @override
  Widget build(BuildContext context) {
    final settings = controller.settings;
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _SettingsSection(
            title: '学期',
            children: [
              ListTile(
                leading: const Icon(Icons.school_outlined),
                title: Text(settings.name.isEmpty ? '学期信息' : settings.name),
                subtitle: Text(
                  settings.startDate == null
                      ? '尚未设置开学日期'
                      : '${_date(settings.startDate!)} · ${settings.totalWeeks == null ? '周数待设置' : '共${settings.totalWeeks}周'}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _editSemester(context, controller),
              ),
              ListTile(
                leading: const Icon(Icons.schedule_outlined),
                title: const Text('节次时间'),
                subtitle: Text(
                  settings.periodTimes.isEmpty
                      ? '未设置时仅显示节次'
                      : '已设置 ${settings.periodTimes.length}/11 节',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PeriodTimesPage(controller: controller),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: '课表数据',
            children: [
              ListTile(
                leading: const Icon(Icons.file_open_outlined),
                title: const Text('导入课表'),
                subtitle: const Text('支持 .xlsx 和文字型 .pdf'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _importSchedule(context, controller),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('清空课表'),
                subtitle: Text('当前有 ${controller.courses.length} 门课程'),
                onTap: controller.courses.isEmpty
                    ? null
                    : () => _confirmClear(context, controller),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: '外观',
            children: [
              RadioGroup<AppThemePreference>(
                groupValue: settings.theme,
                onChanged: (value) {
                  if (value != null) {
                    controller.updateSettings(settings.copyWith(theme: value));
                  }
                },
                child: Column(
                  children: const [
                    RadioListTile(
                      value: AppThemePreference.system,
                      title: Text('跟随系统'),
                    ),
                    RadioListTile(
                      value: AppThemePreference.light,
                      title: Text('浅色'),
                    ),
                    RadioListTile(
                      value: AppThemePreference.dark,
                      title: Text('深色'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _SettingsSection(
            title: '关于',
            children: [
              ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Re课表'),
                subtitle: Text('1.0.0 · 数据仅保存在本机'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 12, bottom: 8),
        child: Text(title, style: Theme.of(context).textTheme.labelLarge),
      ),
      Card(child: Column(children: children)),
    ],
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 64),
    child: Column(
      children: [
        Icon(icon, size: 58, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
      ],
    ),
  );
}

Future<void> _editCourse(
  BuildContext context,
  ScheduleController controller, [
  Course? original,
]) async {
  final course = await showModalBottomSheet<Course>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => CourseEditor(course: original),
  );
  if (course != null) await controller.saveCourse(course);
}

class CourseEditor extends StatefulWidget {
  const CourseEditor({super.key, this.course});
  final Course? course;

  @override
  State<CourseEditor> createState() => _CourseEditorState();
}

class _CourseEditorState extends State<CourseEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _teacher;
  late final TextEditingController _location;
  late final TextEditingController _weeks;
  late final TextEditingController _notes;
  late int _day;
  late int _start;
  late int _end;
  late int _color;

  @override
  void initState() {
    super.initState();
    final course = widget.course;
    _name = TextEditingController(text: course?.name ?? '');
    _teacher = TextEditingController(text: course?.teacher ?? '');
    _location = TextEditingController(text: course?.location ?? '');
    _weeks = TextEditingController(
      text: _formatWeeks(course?.weeks ?? const {}),
    );
    _notes = TextEditingController(text: course?.notes ?? '');
    _day = course?.dayOfWeek ?? DateTime.now().weekday;
    _start = course?.startPeriod ?? 1;
    _end = course?.endPeriod ?? 2;
    _color = course?.colorIndex ?? 0;
  }

  @override
  void dispose() {
    for (final controller in [_name, _teacher, _location, _weeks, _notes]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: 20,
      right: 20,
      top: 12,
      bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: Form(
      key: _formKey,
      child: ListView(
        shrinkWrap: true,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.course == null ? '添加课程' : '编辑课程',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: '课程名称 *'),
            validator: (value) =>
                value == null || value.trim().isEmpty ? '请输入课程名称' : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _intDropdown(
                  '星期',
                  _day,
                  1,
                  7,
                  (v) => _day = v,
                  labels: _weekdayNames,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _intDropdown('开始节次', _start, 1, 11, (v) => _start = v),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _intDropdown('结束节次', _end, 1, 11, (v) => _end = v),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _weeks,
            decoration: const InputDecoration(
              labelText: '上课周次 *',
              hintText: '例如：1-16 或 2-16双周 或 6-7,9',
            ),
            validator: (value) =>
                _parseWeekInput(value ?? '').isEmpty ? '请输入有效周次' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _location,
            decoration: const InputDecoration(labelText: '上课地点'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _teacher,
            decoration: const InputDecoration(labelText: '教师'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notes,
            decoration: const InputDecoration(labelText: '备注'),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            children: [
              for (var i = 0; i < _courseColors.length; i++)
                InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => setState(() => _color = i),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _courseColors[i],
                      shape: BoxShape.circle,
                      border: i == _color
                          ? Border.all(
                              color: Theme.of(context).colorScheme.onSurface,
                              width: 3,
                            )
                          : null,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
    ),
  );

  Widget _intDropdown(
    String label,
    int value,
    int min,
    int max,
    ValueChanged<int> onChanged, {
    List<String>? labels,
  }) => DropdownButtonFormField<int>(
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    items: [
      for (var i = min; i <= max; i++)
        DropdownMenuItem(
          value: i,
          child: Text(labels == null ? '$i' : labels[i - min]),
        ),
    ],
    onChanged: (value) {
      if (value != null) onChanged(value);
    },
  );

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_end < _start) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('结束节次不能早于开始节次')));
      return;
    }
    Navigator.pop(
      context,
      Course(
        id: widget.course?.id ?? newCourseId(),
        name: _name.text.trim(),
        teacher: _teacher.text.trim(),
        location: _location.text.trim(),
        dayOfWeek: _day,
        startPeriod: _start,
        endPeriod: _end,
        weeks: _parseWeekInput(_weeks.text),
        colorIndex: _color,
        notes: _notes.text.trim(),
      ),
    );
  }
}

Set<int> _parseWeekInput(String value) {
  var text = value.trim();
  if (!text.contains('周')) text += '周';
  if (text.endsWith('双周')) text = '${text.substring(0, text.length - 1)}(双)';
  if (text.endsWith('单周')) text = '${text.substring(0, text.length - 1)}(单)';
  return CourseTextParser.parseWeeks(text);
}

String _formatWeeks(Set<int> weeks) {
  if (weeks.isEmpty) return '';
  final sorted = weeks.toList()..sort();
  final parts = <String>[];
  var start = sorted.first;
  var previous = start;
  for (final week in sorted.skip(1)) {
    if (week == previous + 1) {
      previous = week;
      continue;
    }
    parts.add(start == previous ? '$start' : '$start-$previous');
    start = previous = week;
  }
  parts.add(start == previous ? '$start' : '$start-$previous');
  return parts.join(',');
}

Future<void> _editSemester(
  BuildContext context,
  ScheduleController controller,
) async {
  final result = await showModalBottomSheet<SemesterSettings>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => SemesterEditor(settings: controller.settings),
  );
  if (result != null) await controller.updateSettings(result);
}

class SemesterEditor extends StatefulWidget {
  const SemesterEditor({super.key, required this.settings});
  final SemesterSettings settings;

  @override
  State<SemesterEditor> createState() => _SemesterEditorState();
}

class _SemesterEditorState extends State<SemesterEditor> {
  late final TextEditingController _name;
  late final TextEditingController _weeks;
  DateTime? _start;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.settings.name);
    _weeks = TextEditingController(
      text: widget.settings.totalWeeks?.toString() ?? '',
    );
    _start = widget.settings.startDate;
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      16,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: ListView(
      shrinkWrap: true,
      children: [
        Text('学期设置', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 18),
        TextField(
          controller: _name,
          decoration: const InputDecoration(
            labelText: '学期名称',
            hintText: '例如：2026-2027学年第1学期',
          ),
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('第一周周一'),
          subtitle: Text(_start == null ? '尚未设置' : _date(_start!)),
          trailing: const Icon(Icons.calendar_month),
          onTap: _pickStart,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _weeks,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '学期总周数',
            hintText: '例如：20',
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _calibrate,
          icon: const Icon(Icons.tune),
          label: const Text('校准今天所在周'),
        ),
        const SizedBox(height: 18),
        FilledButton(onPressed: _save, child: const Text('保存')),
      ],
    ),
  );

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
      helpText: '选择第一周周一',
    );
    if (picked != null) setState(() => _start = picked);
  }

  Future<void> _calibrate() async {
    final controller = TextEditingController();
    final week = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('今天是第几周？'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '当前教学周'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, int.tryParse(controller.text)),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (week == null || week! < 1 || week > 60) return;
    final today = DateTime.now();
    final thisMonday = today.subtract(Duration(days: today.weekday - 1));
    setState(
      () => _start = DateTime(
        thisMonday.year,
        thisMonday.month,
        thisMonday.day,
      ).subtract(Duration(days: (week - 1) * 7)),
    );
  }

  void _save() {
    final total = int.tryParse(_weeks.text.trim());
    if (total != null && (total < 1 || total > 60)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('学期周数应为 1–60')));
      return;
    }
    Navigator.pop(
      context,
      widget.settings.copyWith(
        name: _name.text.trim(),
        startDate: _start,
        clearStartDate: _start == null,
        totalWeeks: total,
        clearTotalWeeks: total == null,
      ),
    );
  }
}

class PeriodTimesPage extends StatefulWidget {
  const PeriodTimesPage({super.key, required this.controller});
  final ScheduleController controller;

  @override
  State<PeriodTimesPage> createState() => _PeriodTimesPageState();
}

class _PeriodTimesPageState extends State<PeriodTimesPage> {
  late final Map<int, PeriodTime> _times;

  @override
  void initState() {
    super.initState();
    _times = {...widget.controller.settings.periodTimes};
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('节次时间'),
      actions: [TextButton(onPressed: _save, child: const Text('保存'))],
    ),
    body: ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 11,
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (context, index) {
        final period = index + 1;
        final value = _times[period];
        return ListTile(
          leading: CircleAvatar(child: Text('$period')),
          title: Text(
            value == null || value.start.isEmpty
                ? '时间未设置'
                : '${value.start} – ${value.end}',
          ),
          trailing: const Icon(Icons.edit_outlined),
          onTap: () => _edit(period),
        );
      },
    ),
  );

  Future<void> _edit(int period) async {
    final current = _times[period];
    final start = await showTimePicker(
      context: context,
      initialTime:
          _parseTime(current?.start) ?? const TimeOfDay(hour: 8, minute: 0),
      helpText: '第$period节开始时间',
    );
    if (start == null || !mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime:
          _parseTime(current?.end) ??
          TimeOfDay(hour: start.hour, minute: (start.minute + 45) % 60),
      helpText: '第$period节结束时间',
    );
    if (end == null) return;
    setState(
      () => _times[period] = PeriodTime(start: _time(start), end: _time(end)),
    );
  }

  Future<void> _save() async {
    await widget.controller.updateSettings(
      widget.controller.settings.copyWith(periodTimes: _times),
    );
    if (mounted) Navigator.pop(context);
  }
}

Future<void> _importSchedule(
  BuildContext context,
  ScheduleController controller,
) async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: const ['xlsx', 'pdf'],
  );
  if (file == null || !context.mounted) return;
  late final Uint8List bytes;
  try {
    bytes = await file.readAsBytes();
  } catch (_) {
    if (!context.mounted) return;
    _message(context, '无法读取所选文件');
    return;
  }
  if (!context.mounted) return;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  final draft = await OfflineScheduleImporter().import(
    bytes,
    file.extension ?? file.name.split('.').last,
  );
  if (!context.mounted) return;
  Navigator.pop(context);
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ImportReviewPage(controller: controller, draft: draft),
    ),
  );
}

class ImportReviewPage extends StatefulWidget {
  const ImportReviewPage({
    super.key,
    required this.controller,
    required this.draft,
  });
  final ScheduleController controller;
  final ImportDraft draft;

  @override
  State<ImportReviewPage> createState() => _ImportReviewPageState();
}

class _ImportReviewPageState extends State<ImportReviewPage> {
  late List<Course> _courses;

  ImportDraft get _validated =>
      validateImportCourses(_courses, semesterName: widget.draft.semesterName);

  @override
  void initState() {
    super.initState();
    _courses = [...widget.draft.courses];
  }

  @override
  Widget build(BuildContext context) {
    final validation = _validated;
    final issues = [...widget.draft.issues, ...validation.issues]
        .fold<List<ImportIssue>>([], (unique, issue) {
          if (!unique.any((item) => item.message == issue.message))
            unique.add(issue);
          return unique;
        });
    final fatal = issues.any(
      (issue) => issue.severity == ImportIssueSeverity.fatal,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('确认导入')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.draft.semesterName != null)
            ListTile(
              leading: const Icon(Icons.school_outlined),
              title: const Text('识别到学期'),
              subtitle: Text(widget.draft.semesterName!),
            ),
          for (final issue in issues)
            Card(
              color: issue.severity == ImportIssueSeverity.fatal
                  ? Theme.of(context).colorScheme.errorContainer
                  : Theme.of(context).colorScheme.tertiaryContainer,
              child: ListTile(
                leading: Icon(
                  issue.severity == ImportIssueSeverity.fatal
                      ? Icons.error_outline
                      : Icons.warning_amber,
                ),
                title: Text(issue.message),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 18, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '识别到 ${_courses.length} 门课程',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: _add,
                  icon: const Icon(Icons.add),
                  label: const Text('补充'),
                ),
              ],
            ),
          ),
          for (final course in _courses)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      _courseColors[course.colorIndex % _courseColors.length],
                  child: Text(
                    '${course.startPeriod}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(course.name),
                subtitle: Text(
                  '星期${_weekdayNames[course.dayOfWeek - 1]} 第${course.startPeriod}–${course.endPeriod}节\\n'
                  '${_formatWeeks(course.weeks)}周${course.location.isEmpty ? '' : ' · ${course.location}'}',
                ),
                isThreeLine: true,
                onTap: () => _edit(course),
                trailing: IconButton(
                  tooltip: '移除',
                  onPressed: () => setState(() => _courses.remove(course)),
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed: fatal ? null : _confirm,
          icon: const Icon(Icons.check),
          label: const Text('替换当前课表'),
        ),
      ),
    );
  }

  Future<void> _add() async {
    final course = await showModalBottomSheet<Course>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const CourseEditor(),
    );
    if (course != null) setState(() => _courses.add(course));
  }

  Future<void> _edit(Course course) async {
    final edited = await showModalBottomSheet<Course>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => CourseEditor(course: course),
    );
    if (edited == null) return;
    setState(
      () => _courses[_courses.indexWhere((item) => item.id == course.id)] =
          edited,
    );
  }

  Future<void> _confirm() async {
    await widget.controller.replaceCourses(_courses);
    final name = widget.draft.semesterName;
    if (name != null && widget.controller.settings.name.isEmpty) {
      await widget.controller.updateSettings(
        widget.controller.settings.copyWith(name: name),
      );
    }
    if (mounted) {
      Navigator.pop(context);
      _message(context, '已导入 ${_courses.length} 门课程');
    }
  }
}

Future<void> _confirmClear(
  BuildContext context,
  ScheduleController controller,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('清空课表？'),
      content: const Text('所有课程将从本机删除，学期设置会保留。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('清空'),
        ),
      ],
    ),
  );
  if (confirmed == true) await controller.clearCourses();
}

void _message(BuildContext context, String message) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(message)));

String _date(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _time(TimeOfDay value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

TimeOfDay? _parseTime(String? value) {
  final parts = value?.split(':');
  if (parts == null || parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  return hour == null || minute == null
      ? null
      : TimeOfDay(hour: hour, minute: minute);
}
