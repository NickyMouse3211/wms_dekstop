import 'package:flutter_test/flutter_test.dart';
import 'package:wms_windows_listener/core/models/modules/listener/listener_settings.dart';
import 'package:wms_windows_listener/core/utils/file_search_matcher.dart';

void main() {
  FileSearchMatcher matcher(
    FileSearchMode mode,
    String query, [
    String operator = '-',
  ]) => FileSearchMatcher(mode: mode, query: query, operator: operator);

  test('exact and contains ignore case but preserve separators', () {
    final exact = matcher(FileSearchMode.exact, 'AbC3211');
    expect(exact.score('abc3211'), 1);
    expect(exact.score('abc-3211'), 0);
    expect(exact.score('Xabc3211'), 0);
    final contains = matcher(FileSearchMode.contains, 'aBc');
    expect(contains.score('12ABC34'), 1);
    expect(contains.score('AB-C'), 0);
  });

  test(
    'starts with requires an equal first segment and a literal operator',
    () {
      final search = matcher(FileSearchMode.startsWith, '3211');
      for (final name in ['3211-234241', '3211-9089879', '3211-555151']) {
        expect(search.score(name), 1, reason: name);
      }
      for (final name in [
        '13211-234241',
        '32110-234241',
        '3211',
        'X-3211-234241',
      ]) {
        expect(search.score(name), 0, reason: name);
      }
      expect(
        matcher(FileSearchMode.startsWith, 'AbC', '--').score('abc--123'),
        1,
      );
      expect(
        matcher(FileSearchMode.startsWith, '3211', '.').score('3211.1305'),
        1,
      );
      expect(
        matcher(FileSearchMode.startsWith, '3211', ' ').score('3211 1305'),
        1,
      );
      expect(
        matcher(FileSearchMode.startsWith, '3211', '').validationError,
        isNotNull,
      );
    },
  );

  test('normalized exact ignores separators in both query and filename', () {
    final search = matcher(FileSearchMode.normalizedExact, '3211_1305');
    for (final name in ['3211-1305', '3211.1305', '32111305', '32 11_(13)05']) {
      expect(search.score(name), 1, reason: name);
    }
    expect(search.score('321113051'), 0);
    expect(search.score('132111305'), 0);
    expect(matcher(FileSearchMode.normalizedExact, 'é中12').score('É-中_12'), 1);
    expect(
      matcher(FileSearchMode.normalizedExact, '---').validationError,
      isNotNull,
    );
  });

  test('normalized start matches every supplied example, not middle text', () {
    final search = matcher(FileSearchMode.normalizedStart, '32-11');
    for (final name in [
      '3211-123421',
      '321-15345',
      '3211.654544',
      '32 11543563',
    ]) {
      expect(search.score(name), 1, reason: name);
    }
    expect(search.score('13211-123'), 0);
    expect(search.score('321-234'), 0);
    expect(matcher(FileSearchMode.normalizedStart, ' - ').score('anything'), 0);
  });

  test('trim suffix ranks exact first, then the longest nonempty prefix', () {
    final search = matcher(FileSearchMode.trimSuffix, '321113051');
    expect(search.score('321113051'), 9);
    expect(search.score('32111305'), 8);
    expect(search.score('321113'), 6);
    expect(search.score('3211130512'), 0);
    expect(search.score('3211-1305'), 0);
    expect(search.score(''), 0);
    expect(search.score('21113051'), 0);
  });
}
