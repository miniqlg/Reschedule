import 'dart:convert';

enum AppThemePreference { system, light, dark }

class PeriodTime {
  const PeriodTime({required this.start, required this.end});

  final String start;
  final String end;

  Map<String, Object?> toJson() => {'start': start, 'end': end};

  factory PeriodTime.fromJson(Map<String, Object?> json) => PeriodTime(
    start: json['start'] as String? ?? '',
    end: json['end'] as String? ?? '',
  );
}

class SemesterSettings {
  const SemesterSettings({
    this.name = '',
    this.startDate,
    this.totalWeeks,
    this.periodTimes = const {},
    this.theme = AppThemePreference.system,
  });

  final String name;
  final DateTime? startDate;
  final int? totalWeeks;
  final Map<int, PeriodTime> periodTimes;
  final AppThemePreference theme;

  SemesterSettings copyWith({
    String? name,
    DateTime? startDate,
    bool clearStartDate = false,
    int? totalWeeks,
    bool clearTotalWeeks = false,
    Map<int, PeriodTime>? periodTimes,
    AppThemePreference? theme,
  }) => SemesterSettings(
    name: name ?? this.name,
    startDate: clearStartDate ? null : (startDate ?? this.startDate),
    totalWeeks: clearTotalWeeks ? null : (totalWeeks ?? this.totalWeeks),
    periodTimes: periodTimes ?? this.periodTimes,
    theme: theme ?? this.theme,
  );

  int? weekFor(DateTime date) {
    final start = startDate;
    if (start == null) return null;
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final normalizedStart = DateTime(start.year, start.month, start.day);
    final week =
        (normalizedDate.difference(normalizedStart).inDays / 7).floor() + 1;
    return week;
  }

  bool isWeekInSemester(int week) =>
      week >= 1 && (totalWeeks == null || week <= totalWeeks!);

  Map<String, Object?> toMap() => {
    'id': 1,
    'name': name,
    'start_date': startDate?.toIso8601String(),
    'total_weeks': totalWeeks,
    'period_times': jsonEncode(
      periodTimes.map((key, value) => MapEntry(key.toString(), value.toJson())),
    ),
    'theme': theme.name,
  };

  factory SemesterSettings.fromMap(Map<String, Object?> map) {
    final rawTimes =
        jsonDecode(map['period_times'] as String? ?? '{}')
            as Map<String, dynamic>;
    return SemesterSettings(
      name: map['name'] as String? ?? '',
      startDate: DateTime.tryParse(map['start_date'] as String? ?? ''),
      totalWeeks: map['total_weeks'] as int?,
      periodTimes: rawTimes.map(
        (key, value) => MapEntry(
          int.parse(key),
          PeriodTime.fromJson(Map<String, Object?>.from(value as Map)),
        ),
      ),
      theme: AppThemePreference.values.firstWhere(
        (value) => value.name == map['theme'],
        orElse: () => AppThemePreference.system,
      ),
    );
  }
}

class Course {
  const Course({
    required this.id,
    required this.name,
    required this.dayOfWeek,
    required this.startPeriod,
    required this.endPeriod,
    required this.weeks,
    this.teacher = '',
    this.location = '',
    this.colorIndex = 0,
    this.notes = '',
  });

  final String id;
  final String name;
  final String teacher;
  final String location;
  final int dayOfWeek;
  final int startPeriod;
  final int endPeriod;
  final Set<int> weeks;
  final int colorIndex;
  final String notes;

  bool occursIn(int week, int weekday) =>
      dayOfWeek == weekday && weeks.contains(week);

  Course copyWith({
    String? id,
    String? name,
    String? teacher,
    String? location,
    int? dayOfWeek,
    int? startPeriod,
    int? endPeriod,
    Set<int>? weeks,
    int? colorIndex,
    String? notes,
  }) => Course(
    id: id ?? this.id,
    name: name ?? this.name,
    teacher: teacher ?? this.teacher,
    location: location ?? this.location,
    dayOfWeek: dayOfWeek ?? this.dayOfWeek,
    startPeriod: startPeriod ?? this.startPeriod,
    endPeriod: endPeriod ?? this.endPeriod,
    weeks: weeks ?? this.weeks,
    colorIndex: colorIndex ?? this.colorIndex,
    notes: notes ?? this.notes,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'teacher': teacher,
    'location': location,
    'day_of_week': dayOfWeek,
    'start_period': startPeriod,
    'end_period': endPeriod,
    'weeks': jsonEncode(weeks.toList()..sort()),
    'color_index': colorIndex,
    'notes': notes,
  };

  factory Course.fromMap(Map<String, Object?> map) => Course(
    id: map['id']! as String,
    name: map['name']! as String,
    teacher: map['teacher'] as String? ?? '',
    location: map['location'] as String? ?? '',
    dayOfWeek: map['day_of_week']! as int,
    startPeriod: map['start_period']! as int,
    endPeriod: map['end_period']! as int,
    weeks: (jsonDecode(map['weeks']! as String) as List)
        .map((value) => value as int)
        .toSet(),
    colorIndex: map['color_index'] as int? ?? 0,
    notes: map['notes'] as String? ?? '',
  );
}

enum ImportIssueSeverity { warning, fatal }

class ImportIssue {
  const ImportIssue(
    this.message, {
    this.severity = ImportIssueSeverity.warning,
  });

  final String message;
  final ImportIssueSeverity severity;
}

class ImportDraft {
  const ImportDraft({
    required this.courses,
    this.issues = const [],
    this.semesterName,
  });

  final List<Course> courses;
  final List<ImportIssue> issues;
  final String? semesterName;

  bool get hasFatalIssues =>
      issues.any((issue) => issue.severity == ImportIssueSeverity.fatal);
}

String newCourseId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-'
    '${Object().hashCode.toRadixString(36)}';
