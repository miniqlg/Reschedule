import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_schedule/importers.dart';
import 'package:re_schedule/models.dart';

void main() {
  group('教学周计算', () {
    const settings = SemesterSettings();

    test('开学前和跨年日期正确计算', () {
      final configured = settings.copyWith(
        startDate: DateTime(2026, 12, 28),
        totalWeeks: 20,
      );
      expect(configured.weekFor(DateTime(2026, 12, 27)), 0);
      expect(configured.weekFor(DateTime(2026, 12, 28)), 1);
      expect(configured.weekFor(DateTime(2027, 1, 4)), 2);
    });
  });

  group('周次解析', () {
    test('解析连续、单双周与非连续周次', () {
      expect(
        CourseTextParser.parseWeeks('(1-12周)'),
        Set<int>.from(List.generate(12, (index) => index + 1)),
      );
      expect(CourseTextParser.parseWeeks('2-16周(双)'), {
        2,
        4,
        6,
        8,
        10,
        12,
        14,
        16,
      });
      expect(CourseTextParser.parseWeeks('6-7周,9周'), {6, 7, 9});
      expect(CourseTextParser.parseWeeks('18-19周'), {18, 19});
    });
  });

  test('解析样例格式课程块', () {
    final course = CourseTextParser.parseBlock(
      '光学测量技术 (3-4节)2-16周(双)/校区:彩石校区/'
      '场地:彩石南116117/教师:李杰,姜辉,张伟力/教学班:B864107-01',
      dayOfWeek: 5,
    );
    expect(course, isNotNull);
    expect(course!.name, '光学测量技术');
    expect(course.startPeriod, 3);
    expect(course.endPeriod, 4);
    expect(course.location, '彩石南116117');
    expect(course.teacher, '李杰,姜辉,张伟力');
    expect(course.weeks, {2, 4, 6, 8, 10, 12, 14, 16});
  });

  test('冲突仅作为可确认警告', () {
    Course course(String id, String name) => Course(
      id: id,
      name: name,
      dayOfWeek: 1,
      startPeriod: 1,
      endPeriod: 2,
      weeks: const {1},
    );
    final draft = validateImportCourses([course('a', 'A'), course('b', 'B')]);
    expect(draft.hasFatalIssues, isFalse);
    expect(draft.issues.single.message, contains('冲突'));
  });

  test('解析含合并单元格和多个星期列的 XLSX', () {
    final archive = Archive()
      ..add(
        ArchiveFile.string('xl/worksheets/sheet1.xml', '''
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetData>
    <row r="1">
      <c r="A1" t="inlineStr"><is><t>节次</t></is></c>
      <c r="B1" t="inlineStr"><is><t>星期一</t></is></c>
      <c r="C1" t="inlineStr"><is><t>星期二</t></is></c>
      <c r="D1" t="inlineStr"><is><t>2026-2027学年第1学期</t></is></c>
    </row>
    <row r="2">
      <c r="A2"><v>1</v></c>
      <c r="B2" t="inlineStr"><is><t>光学基础 (1-2节)1-4周/场地:教室101/教师:张老师</t></is></c>
    </row>
    <row r="3"><c r="A3"><v>2</v></c></row>
    <row r="4">
      <c r="A4"><v>3</v></c>
      <c r="C4" t="inlineStr"><is><t>实验课 (3-4节)2-8周(双)/场地:实验室/教师:李老师</t></is></c>
    </row>
    <row r="5"><c r="A5"><v>4</v></c></row>
  </sheetData>
  <mergeCells count="2">
    <mergeCell ref="B2:B3"/>
    <mergeCell ref="C4:C5"/>
  </mergeCells>
</worksheet>
'''),
      );
    final draft = XlsxScheduleImporter().parse(
      ZipEncoder().encodeBytes(archive),
    );
    expect(draft.hasFatalIssues, isFalse);
    expect(draft.courses, hasLength(2));
    expect(draft.semesterName, '2026-2027学年第1学期');
    expect(draft.courses.first.weeks, {1, 2, 3, 4});
    expect(draft.courses.last.weeks, {2, 4, 6, 8});
  });

  test('解析无 ToUnicode 的 UniGB UTF-16BE PDF 内容流', () async {
    String literal(String value) {
      final bytes = <int>[];
      for (final codeUnit in value.codeUnits) {
        bytes
          ..add(codeUnit >> 8)
          ..add(codeUnit & 0xff);
      }
      return bytes
          .map((byte) => '\\${byte.toRadixString(8).padLeft(3, '0')}')
          .join();
    }

    final commands = StringBuffer('BT\n/F1 8 Tf\n')
      ..writeln('1 0 0 1 100 700 Tm (${literal('星期一')}) Tj')
      ..writeln('1 0 0 1 200 700 Tm (${literal('星期二')}) Tj')
      ..writeln('1 0 0 1 100 600 Tm (${literal('合成课程')}) Tj')
      ..writeln('1 0 0 1 100 590 Tm (${literal('(1-2节)1-4周')}) Tj')
      ..writeln('1 0 0 1 100 580 Tm (${literal('/场地:教室101/教师:张老师')}) Tj')
      ..writeln('ET');
    final compressed = ZLibEncoder().encode(utf8.encode(commands.toString()));
    final prefix = latin1.encode('''%PDF-1.4
1 0 obj
<< /Encoding /UniGB-UCS2-H /Filter /FlateDecode /Length ${compressed.length} >>
stream
''');
    final suffix = latin1.encode('\nendstream\nendobj\n%%EOF');
    final bytes = Uint8List.fromList([...prefix, ...compressed, ...suffix]);

    final draft = await PdfScheduleImporter().parse(bytes);
    expect(draft.hasFatalIssues, isFalse);
    expect(draft.courses, hasLength(1));
    expect(draft.courses.single.name, '合成课程');
    expect(draft.courses.single.teacher, '张老师');
    expect(draft.courses.single.location, '教室101');
    expect(draft.courses.single.weeks, {1, 2, 3, 4});
  });
}
