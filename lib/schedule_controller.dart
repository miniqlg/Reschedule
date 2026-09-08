import 'package:flutter/foundation.dart';

import 'models.dart';
import 'storage.dart';

class ScheduleController extends ChangeNotifier {
  ScheduleController(this.store);

  final ScheduleStore store;
  List<Course> courses = const [];
  SemesterSettings settings = const SemesterSettings();
  bool loading = true;

  Future<void> initialize() async {
    settings = await store.loadSettings();
    courses = await store.loadCourses();
    loading = false;
    notifyListeners();
  }

  List<Course> coursesFor(int week, int weekday) =>
      courses.where((course) => course.occursIn(week, weekday)).toList()
        ..sort((a, b) => a.startPeriod.compareTo(b.startPeriod));

  Future<void> saveCourse(Course course) async {
    await store.saveCourse(course);
    final index = courses.indexWhere((item) => item.id == course.id);
    courses = [...courses];
    if (index == -1) {
      courses.add(course);
    } else {
      courses[index] = course;
    }
    notifyListeners();
  }

  Future<void> deleteCourse(String id) async {
    await store.deleteCourse(id);
    courses = courses.where((course) => course.id != id).toList();
    notifyListeners();
  }

  Future<void> replaceCourses(List<Course> value) async {
    await store.replaceCourses(value);
    courses = [...value];
    notifyListeners();
  }

  Future<void> clearCourses() => replaceCourses(const []);

  Future<void> updateSettings(SemesterSettings value) async {
    await store.saveSettings(value);
    settings = value;
    notifyListeners();
  }
}
