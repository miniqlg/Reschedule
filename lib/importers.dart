import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart' hide ZLibDecoder;
import 'package:pdfrx/pdfrx.dart';
import 'package:xml/xml.dart';

import 'models.dart';

abstract interface class ScheduleImporter {
  Future<ImportDraft> import(Uint8List bytes, String extension);
}

class OfflineScheduleImporter implements ScheduleImporter {
  @override
  Future<ImportDraft> import(Uint8List bytes, String extension) async {
    switch (extension.toLowerCase().replaceFirst('.', '')) {
      case 'xlsx':
        return XlsxScheduleImporter().parse(bytes);
      case 'pdf':
        return PdfScheduleImporter().parse(bytes);
      default:
        return const ImportDraft(
          courses: [],
          issues: [
            ImportIssue(
              '仅支持 .xlsx 和 .pdf 文件',
              severity: ImportIssueSeverity.fatal,
            ),
          ],
        );
    }
  }
}

class CourseTextParser {
  static final RegExp _periodPattern = RegExp(
    r'[（(]\s*(\d{1,2})\s*[-—~～至]\s*(\d{1,2})\s*节\s*[）)]',
  );
  static final RegExp _semesterPattern = RegExp(
    r'(20\d{2}\s*[-–—]\s*20\d{2}\s*学年\s*第?\s*\d\s*学期)',
  );

  static Course? parseBlock(
    String raw, {
    required int dayOfWeek,
    int? fallbackPeriod,
    int colorIndex = 0,
  }) {
    final text = raw
        .replaceAll('\u0000', '')
        .replaceAll(RegExp(r'[\r\t]+'), ' ')
        .replaceAll(RegExp(r'\s*\n\s*'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAllMapped(
          RegExp(
            r'(校\s*区|场\s*地|地\s*点|教\s*师|教\s*学\s*班|选\s*课\s*备\s*注|备\s*注)\s*[:：]',
          ),
          (match) => '${match.group(1)!.replaceAll(RegExp(r'\s+'), '')}:',
        )
        .trim();
    final period = _periodPattern.firstMatch(text);
    final startPeriod = int.tryParse(period?.group(1) ?? '') ?? fallbackPeriod;
    final endPeriod = int.tryParse(period?.group(2) ?? '') ?? fallbackPeriod;
    if (startPeriod == null || endPeriod == null) return null;

    var name = period == null ? text : text.substring(0, period.start).trim();
    name = name.split(RegExp(r'[/；;]')).last.trim();
    if (name.isEmpty || RegExp(r'^(星期|周)[一二三四五六日天]$').hasMatch(name)) {
      return null;
    }

    final weeks = parseWeeks(text);
    if (weeks.isEmpty) return null;
    final location = _capture(
      text,
      RegExp(r'(?:校区[:：][^/；;]*[/；;])?(?:场地|地点)[:：]\s*([^/；;]+)'),
    );
    final teacher = _capture(text, RegExp(r'教师[:：]\s*([^/；;]+)'));
    final notes = _capture(text, RegExp(r'(?:选课备注|备注)[:：]\s*([^/；;]*)'));

    return Course(
      id: newCourseId(),
      name: name,
      teacher: teacher,
      location: location,
      dayOfWeek: dayOfWeek,
      startPeriod: startPeriod,
      endPeriod: endPeriod,
      weeks: weeks,
      colorIndex: colorIndex,
      notes: notes,
    );
  }

  static String? semesterName(String text) => _semesterPattern
      .firstMatch(text)
      ?.group(1)
      ?.replaceAll(RegExp(r'\s+'), '');

  static List<Course> parseBlocks(
    String raw, {
    required int dayOfWeek,
    int? fallbackPeriod,
    int colorIndex = 0,
  }) {
    final text = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final periods = _periodPattern.allMatches(text).toList();
    if (periods.length < 2) {
      final course = parseBlock(
        text,
        dayOfWeek: dayOfWeek,
        fallbackPeriod: fallbackPeriod,
        colorIndex: colorIndex,
      );
      return course == null ? const [] : [course];
    }

    final starts = <int>[0];
    for (final period in periods.skip(1)) {
      final beforePeriod = text.lastIndexOf('\n', period.start);
      final lineStart = beforePeriod + 1;
      final periodLinePrefix = text.substring(lineStart, period.start).trim();
      if (periodLinePrefix.isNotEmpty) {
        starts.add(lineStart);
      } else {
        starts.add(text.lastIndexOf('\n', beforePeriod - 1) + 1);
      }
    }

    final courses = <Course>[];
    for (var index = 0; index < starts.length; index++) {
      final course = parseBlock(
        text.substring(
          starts[index],
          index + 1 < starts.length ? starts[index + 1] : text.length,
        ),
        dayOfWeek: dayOfWeek,
        fallbackPeriod: fallbackPeriod,
        colorIndex: colorIndex + index,
      );
      if (course != null) courses.add(course);
    }
    return courses;
  }

  static Set<int> parseWeeks(String text) {
    final normalized = text.replaceAll('，', ',').replaceAll('、', ',');
    final result = <int>{};
    final isOdd = RegExp(r'[（(]\s*单\s*[）)]').hasMatch(normalized);
    final isEven = RegExp(r'[（(]\s*双\s*[）)]').hasMatch(normalized);
    final matches = RegExp(
      r'(\d{1,2}(?:\s*[-—~～至]\s*\d{1,2})?)\s*周',
    ).allMatches(normalized);
    if (matches.isEmpty) return result;
    for (final match in matches) {
      final part = match.group(1)!;
      final numbers = RegExp(
        r'\d{1,2}',
      ).allMatches(part).map((item) => int.parse(item.group(0)!)).toList();
      if (numbers.length == 1) {
        result.add(numbers.first);
      } else if (numbers.length >= 2) {
        for (var week = numbers[0]; week <= numbers[1]; week++) {
          result.add(week);
        }
      }
    }
    if (isOdd) result.removeWhere((week) => week.isEven);
    if (isEven) result.removeWhere((week) => week.isOdd);
    return result.where((week) => week >= 1 && week <= 60).toSet();
  }

  static String _capture(String text, RegExp pattern) {
    var value = pattern.firstMatch(text)?.group(1)?.trim() ?? '';
    // Legacy Chinese PDFs often split a single field into positioned glyph
    // runs. Remove only the artificial gaps between CJK characters/digits.
    for (var i = 0; i < 2; i++) {
      value = value.replaceAllMapped(
        RegExp(r'([\u3400-\u9fff\d])\s+([\u3400-\u9fff\d])'),
        (match) => '${match.group(1)}${match.group(2)}',
      );
    }
    return value;
  }
}

class XlsxScheduleImporter {
  ImportDraft parse(Uint8List bytes) {
    try {
      final sheets = _XlsxReader.read(bytes);
      if (sheets.isEmpty) return _fatal('Excel 中没有工作表');
      final candidates = sheets.map((sheet) => (_score(sheet), sheet)).toList()
        ..sort((a, b) => b.$1.compareTo(a.$1));
      if (candidates.isEmpty || candidates.first.$1 < 2) {
        return _fatal('没有找到包含星期列和节次行的课表');
      }
      final sheet = candidates.first.$2;
      final headers = _weekdayHeaders(sheet);
      final periodColumn = _periodColumn(sheet);
      if (headers.length < 2 || periodColumn == null) {
        return _fatal('无法确定课表的星期列或节次列');
      }

      final courses = <Course>[];
      final seen = <String>{};
      final allText = StringBuffer();
      for (var row = 0; row < sheet.maxRows; row++) {
        for (var column = 0; column < sheet.maxColumns; column++) {
          final value = _cellText(sheet, row, column);
          if (value.isNotEmpty) allText.writeln(value);
        }
      }
      for (var row = 0; row < sheet.maxRows; row++) {
        for (final entry in headers.entries) {
          final raw = _cellText(sheet, row, entry.key);
          if (raw.isEmpty) continue;
          final fallback = int.tryParse(_cellText(sheet, row, periodColumn));
          final parsed = CourseTextParser.parseBlocks(
            raw,
            dayOfWeek: entry.value,
            fallbackPeriod: fallback,
            colorIndex: courses.length % 8,
          );
          for (final course in parsed) {
            final key =
                '${course.dayOfWeek}|${course.startPeriod}|${course.endPeriod}|${course.name}|${course.weeks.join(',')}';
            if (seen.add(key)) courses.add(course);
          }
        }
      }
      return _validated(
        courses,
        CourseTextParser.semesterName(allText.toString()),
      );
    } catch (_) {
      return _fatal('Excel 文件损坏、加密或格式不受支持');
    }
  }

  int _score(_XlsxSheet sheet) {
    var weekdays = 0;
    var periods = 0;
    for (var row = 0; row < sheet.maxRows; row++) {
      for (var column = 0; column < sheet.maxColumns; column++) {
        final value = _cellText(sheet, row, column);
        if (_weekday(value) != null) weekdays++;
        final number = int.tryParse(value);
        if (number != null && number >= 1 && number <= 11) periods++;
      }
    }
    return weekdays * 3 + periods;
  }

  Map<int, int> _weekdayHeaders(_XlsxSheet sheet) {
    final result = <int, int>{};
    for (var row = 0; row < sheet.maxRows; row++) {
      for (var column = 0; column < sheet.maxColumns; column++) {
        final weekday = _weekday(_cellText(sheet, row, column));
        if (weekday != null) result[column] = weekday;
      }
      if (result.length >= 2) return result;
      result.clear();
    }
    return result;
  }

  int? _periodColumn(_XlsxSheet sheet) {
    var bestColumn = -1;
    var bestScore = 0;
    for (var column = 0; column < sheet.maxColumns; column++) {
      var score = 0;
      for (var row = 0; row < sheet.maxRows; row++) {
        final number = int.tryParse(_cellText(sheet, row, column));
        if (number != null && number >= 1 && number <= 11) score++;
      }
      if (score > bestScore) {
        bestScore = score;
        bestColumn = column;
      }
    }
    return bestScore >= 2 ? bestColumn : null;
  }

  String _cellText(_XlsxSheet sheet, int row, int column) =>
      sheet.cell(row, column).trim();

  int? _weekday(String text) {
    const chars = '一二三四五六日';
    final match = RegExp(r'(?:星期|周)([一二三四五六日天])').firstMatch(text);
    if (match == null) return null;
    if (match.group(1) == '天') return 7;
    return chars.indexOf(match.group(1)!) + 1;
  }
}

class _XlsxReader {
  static List<_XlsxSheet> read(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    final sharedStrings = _sharedStrings(archive);
    final result = <_XlsxSheet>[];
    final files =
        archive.files
            .where(
              (file) =>
                  file.name.startsWith('xl/worksheets/') &&
                  file.name.endsWith('.xml'),
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    for (final file in files) {
      final data = file.readBytes();
      if (data == null) continue;
      final document = XmlDocument.parse(utf8.decode(data));
      final values = <(int, int), String>{};
      for (final cell in document.findAllElements('c')) {
        final reference = cell.getAttribute('r');
        if (reference == null) continue;
        final coordinate = _coordinate(reference);
        if (coordinate == null) continue;
        final type = cell.getAttribute('t');
        final raw = type == 'inlineStr'
            ? cell.findAllElements('t').map((node) => node.innerText).join()
            : _firstElementText(cell, 'v');
        final value = type == 's'
            ? switch (int.tryParse(raw)) {
                final index? when index >= 0 && index < sharedStrings.length =>
                  sharedStrings[index],
                _ => '',
              }
            : raw;
        if (value.trim().isNotEmpty) values[coordinate] = value.trim();
      }
      for (final merge in document.findAllElements('mergeCell')) {
        final range = merge.getAttribute('ref')?.split(':');
        if (range == null || range.length != 2) continue;
        final start = _coordinate(range[0]);
        final end = _coordinate(range[1]);
        if (start == null || end == null) continue;
        final value = values[start];
        if (value == null) continue;
        for (var row = start.$1; row <= end.$1; row++) {
          for (var column = start.$2; column <= end.$2; column++) {
            values.putIfAbsent((row, column), () => value);
          }
        }
      }
      result.add(_XlsxSheet(values));
    }
    return result;
  }

  static List<String> _sharedStrings(Archive archive) {
    final file = archive.findFile('xl/sharedStrings.xml');
    final data = file?.readBytes();
    if (data == null) return const [];
    final document = XmlDocument.parse(utf8.decode(data));
    return document
        .findAllElements('si')
        .map(
          (item) =>
              item.findAllElements('t').map((node) => node.innerText).join(),
        )
        .toList(growable: false);
  }

  static String _firstElementText(XmlElement parent, String name) {
    final elements = parent.findElements(name);
    return elements.isEmpty ? '' : elements.first.innerText;
  }

  static (int, int)? _coordinate(String reference) {
    final match = RegExp(
      r'^([A-Z]+)(\d+)$',
    ).firstMatch(reference.toUpperCase());
    if (match == null) return null;
    var column = 0;
    for (final code in match.group(1)!.codeUnits) {
      column = column * 26 + code - 64;
    }
    return (int.parse(match.group(2)!) - 1, column - 1);
  }
}

class _XlsxSheet {
  _XlsxSheet(this.values)
    : maxRows = values.keys.fold(
        0,
        (value, key) => key.$1 >= value ? key.$1 + 1 : value,
      ),
      maxColumns = values.keys.fold(
        0,
        (value, key) => key.$2 >= value ? key.$2 + 1 : value,
      );

  final Map<(int, int), String> values;
  final int maxRows;
  final int maxColumns;

  String cell(int row, int column) => values[(row, column)] ?? '';
}

class PdfScheduleImporter {
  Future<ImportDraft> parse(Uint8List bytes) async {
    if (!ascii
        .decode(bytes.take(5).toList(), allowInvalid: true)
        .startsWith('%PDF-')) {
      return _fatal('文件不是有效的 PDF');
    }
    final courses = <Course>[];
    final allText = StringBuffer();
    try {
      final document = await PdfDocument.openData(
        bytes,
        sourceName: 'import.pdf',
      );
      try {
        if (document.isEncrypted) return _fatal('暂不支持加密 PDF');
        try {
          for (final page in document.pages) {
            final text = await page.loadStructuredText();
            final pageFragments = <_PositionedText>[];
            allText.writeln(text.fullText);
            final weekdayFragments = text.fragments
                .where((fragment) => _weekday(fragment.text) != null)
                .toList();
            final leftSpread = _spread(
              weekdayFragments.map((fragment) => fragment.bounds.left),
            );
            final topSpread = _spread(
              weekdayFragments.map((fragment) => fragment.bounds.top),
            );
            final dayAxisIsTop = topSpread > leftSpread;
            for (final fragment in text.fragments) {
              pageFragments.add(
                _PositionedText(
                  fragment.text.trim(),
                  dayAxisIsTop ? fragment.bounds.top : fragment.bounds.left,
                  dayAxisIsTop ? fragment.bounds.left : fragment.bounds.top,
                ),
              );
            }
            courses.addAll(_parsePositioned(pageFragments));
          }
        } catch (_) {
          courses.clear();
        }
      } finally {
        await document.dispose();
      }
    } catch (_) {
      // PDFium may reject a malformed text map; the legacy reader below still
      // supports the known offline timetable export.
    }
    try {
      var semester = CourseTextParser.semesterName(allText.toString());
      if (courses.isEmpty) {
        final fallback = _LegacyPdfTextExtractor.extract(bytes);
        courses.addAll(_parsePositioned(fallback));
        semester ??= CourseTextParser.semesterName(
          fallback.map((item) => item.text).join(' '),
        );
      }
      final seen = <String>{};
      final merged = courses
          .where(
            (course) => seen.add(
              '${course.dayOfWeek}|${course.startPeriod}|${course.name}|${course.weeks.join(',')}',
            ),
          )
          .toList();
      return _validated(merged, semester);
    } catch (_) {
      return _fatal('PDF 文件损坏、加密、为扫描件或版式不受支持');
    }
  }

  List<Course> _parsePositioned(List<_PositionedText> items) {
    final headers = <int, double>{};
    for (final item in items) {
      final weekday = _weekday(item.text);
      if (weekday != null) headers[weekday] = item.x;
    }
    if (headers.length < 2) return const [];
    final sortedHeaders = headers.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final columns = <int, List<_PositionedText>>{};
    for (final item in items) {
      final nearest = sortedHeaders.reduce(
        (a, b) => (item.x - a.value).abs() <= (item.x - b.value).abs() ? a : b,
      );
      final spacing = sortedHeaders.length > 1
          ? (sortedHeaders.last.value - sortedHeaders.first.value).abs() /
                (sortedHeaders.length - 1)
          : double.infinity;
      if ((item.x - nearest.value).abs() <= spacing * 0.65) {
        columns.putIfAbsent(nearest.key, () => []).add(item);
      }
    }

    final result = <Course>[];
    final seen = <String>{};
    for (final entry in columns.entries) {
      final tokens =
          entry.value
              .where(
                (item) => item.text.isNotEmpty && _weekday(item.text) == null,
              )
              .toList()
            ..sort((a, b) => a.y.compareTo(b.y));
      final anchors = <int>[];
      for (var i = 0; i < tokens.length; i++) {
        if (RegExp(
          r'[（(]\s*\d{1,2}\s*[-—~～至]\s*\d{1,2}\s*节',
        ).hasMatch(tokens[i].text)) {
          anchors.add(i);
        }
      }
      for (var index = 0; index < anchors.length; index++) {
        final anchor = anchors[index];
        final start = anchor > 0 ? anchor - 1 : anchor;
        final end = index + 1 < anchors.length
            ? (anchors[index + 1] - 1).clamp(start + 1, tokens.length)
            : tokens.length;
        final raw = tokens
            .sublist(start, end)
            .map((item) => item.text)
            .join(' ');
        final course = CourseTextParser.parseBlock(
          raw,
          dayOfWeek: entry.key,
          colorIndex: result.length % 8,
        );
        if (course == null) continue;
        final key =
            '${course.dayOfWeek}|${course.startPeriod}|${course.name}|${course.weeks.join(',')}';
        if (seen.add(key)) result.add(course);
      }
    }
    return result;
  }

  int? _weekday(String text) {
    const chars = '一二三四五六日';
    final match = RegExp(r'(?:星期|周)([一二三四五六日天])').firstMatch(text);
    if (match == null) return null;
    if (match.group(1) == '天') return 7;
    return chars.indexOf(match.group(1)!) + 1;
  }

  double _spread(Iterable<double> values) {
    if (values.isEmpty) return 0;
    final sorted = values.toList()..sort();
    return sorted.last - sorted.first;
  }
}

class _LegacyPdfTextExtractor {
  static List<_PositionedText> extract(Uint8List bytes) {
    final result = <_PositionedText>[];
    for (final stream in _flateStreams(bytes)) {
      final text = latin1.decode(stream, allowInvalid: true);
      if (!text.contains(' Tm') || !text.contains('Tj')) continue;
      final pattern = RegExp(r'1\s+0\s+0\s+1\s+([\d.\-]+)\s+([\d.\-]+)\s+Tm');
      for (final match in pattern.allMatches(text)) {
        final open = text.indexOf('(', match.end);
        if (open < 0) continue;
        final nextPosition = text.indexOf(' Tm', match.end);
        final endTextObject = text.indexOf('ET', match.end);
        if ((nextPosition >= 0 && nextPosition < open) ||
            (endTextObject >= 0 && endTextObject < open)) {
          continue;
        }
        final literal = _readLiteral(text, open);
        if (literal == null) continue;
        final decoded = _decodeUcs2(literal.$1);
        if (decoded.trim().isNotEmpty) {
          result.add(
            _PositionedText(
              decoded.trim(),
              double.parse(match.group(1)!),
              -double.parse(match.group(2)!),
            ),
          );
        }
      }
    }
    return result;
  }

  static Iterable<Uint8List> _flateStreams(Uint8List bytes) sync* {
    final source = latin1.decode(bytes, allowInvalid: true);
    var cursor = 0;
    while (true) {
      final marker = source.indexOf('stream', cursor);
      if (marker < 0) break;
      final dictionaryStart = source.lastIndexOf('<<', marker);
      final dictionary = dictionaryStart >= 0
          ? source.substring(dictionaryStart, marker)
          : '';
      var dataStart = marker + 6;
      if (source.startsWith('\r\n', dataStart)) {
        dataStart += 2;
      } else if (source.startsWith('\n', dataStart) ||
          source.startsWith('\r', dataStart)) {
        dataStart++;
      }
      final end = source.indexOf('endstream', dataStart);
      if (end < 0) break;
      var dataEnd = end;
      while (dataEnd > dataStart &&
          (bytes[dataEnd - 1] == 10 || bytes[dataEnd - 1] == 13)) {
        dataEnd--;
      }
      if (dictionary.contains('/FlateDecode')) {
        try {
          yield Uint8List.fromList(
            ZLibDecoder().convert(bytes.sublist(dataStart, dataEnd)),
          );
        } catch (_) {
          // Ignore unrelated or unsupported compressed streams.
        }
      }
      cursor = end + 9;
    }
  }

  static (List<int>, int)? _readLiteral(String source, int open) {
    final output = <int>[];
    var depth = 1;
    for (var i = open + 1; i < source.length; i++) {
      var code = source.codeUnitAt(i);
      if (code == 92) {
        if (++i >= source.length) break;
        code = source.codeUnitAt(i);
        const escaped = {110: 10, 114: 13, 116: 9, 98: 8, 102: 12};
        if (escaped.containsKey(code)) {
          output.add(escaped[code]!);
        } else if (code >= 48 && code <= 55) {
          var octal = String.fromCharCode(code);
          for (var count = 0; count < 2 && i + 1 < source.length; count++) {
            final next = source.codeUnitAt(i + 1);
            if (next < 48 || next > 55) break;
            octal += String.fromCharCode(next);
            i++;
          }
          output.add(int.parse(octal, radix: 8));
        } else if (code == 10 || code == 13) {
          if (code == 13 &&
              i + 1 < source.length &&
              source.codeUnitAt(i + 1) == 10) {
            i++;
          }
        } else {
          output.add(code & 0xff);
        }
      } else if (code == 40) {
        depth++;
        output.add(code);
      } else if (code == 41) {
        depth--;
        if (depth == 0) return (output, i);
        output.add(code);
      } else {
        output.add(code & 0xff);
      }
    }
    return null;
  }

  static String _decodeUcs2(List<int> bytes) {
    if (bytes.length < 2) return latin1.decode(bytes, allowInvalid: true);
    final codeUnits = <int>[];
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      codeUnits.add((bytes[i] << 8) | bytes[i + 1]);
    }
    return String.fromCharCodes(codeUnits);
  }
}

class _PositionedText {
  const _PositionedText(this.text, this.x, this.y);
  final String text;
  final double x;
  final double y;
}

ImportDraft _validated(List<Course> courses, String? semesterName) {
  final issues = <ImportIssue>[];
  if (courses.isEmpty) {
    issues.add(
      const ImportIssue(
        '没有识别到课程。扫描件、图片型 PDF 和非网格课表暂不支持。',
        severity: ImportIssueSeverity.fatal,
      ),
    );
  }
  for (final course in courses) {
    if (course.startPeriod < 1 ||
        course.endPeriod > 11 ||
        course.startPeriod > course.endPeriod) {
      issues.add(
        ImportIssue(
          '“${course.name}”的节次超出 1–11 节',
          severity: ImportIssueSeverity.fatal,
        ),
      );
    }
  }
  for (var i = 0; i < courses.length; i++) {
    for (var j = i + 1; j < courses.length; j++) {
      final a = courses[i];
      final b = courses[j];
      final overlaps =
          a.dayOfWeek == b.dayOfWeek &&
          a.startPeriod <= b.endPeriod &&
          b.startPeriod <= a.endPeriod &&
          a.weeks.intersection(b.weeks).isNotEmpty;
      if (overlaps) {
        issues.add(ImportIssue('“${a.name}”与“${b.name}”存在上课时间冲突'));
      }
    }
  }
  return ImportDraft(
    courses: courses,
    issues: issues,
    semesterName: semesterName,
  );
}

ImportDraft validateImportCourses(
  List<Course> courses, {
  String? semesterName,
}) => _validated(courses, semesterName);

ImportDraft _fatal(String message) => ImportDraft(
  courses: const [],
  issues: [ImportIssue(message, severity: ImportIssueSeverity.fatal)],
);
