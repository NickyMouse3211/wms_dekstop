import '../models/modules/listener/listener_settings.dart';

/// Prepared once per scan. Call with the filename without its last extension.
class FileSearchMatcher {
  FileSearchMatcher({
    required this.mode,
    required String query,
    required String operator,
  }) : query = query.toLowerCase(),
       operator = operator.toLowerCase(),
       normalizedQuery =
           mode == FileSearchMode.normalizedExact ||
               mode == FileSearchMode.normalizedStart
           ? normalize(query)
           : '';

  final FileSearchMode mode;
  final String query;
  final String operator;
  final String normalizedQuery;

  // Preserve letters, numbers and combining marks; remove separators/symbols.
  static final _separators = RegExp(r'[^\p{L}\p{M}\p{N}]', unicode: true);
  static String normalize(String value) =>
      value.toLowerCase().replaceAll(_separators, '');

  String? get validationError {
    if (mode == FileSearchMode.startsWith && operator.isEmpty) {
      return 'Isi operator pemisah untuk pencarian Starts with.';
    }
    if ((mode == FileSearchMode.normalizedExact ||
            mode == FileSearchMode.normalizedStart) &&
        normalizedQuery.isEmpty) {
      return 'Kode pencarian harus berisi huruf atau angka.';
    }
    return null;
  }

  /// Zero means no match. Trim suffix ranks the longest matching prefix first,
  /// equivalent to retrying successively shorter input without rescanning disk.
  int score(String filenameStem) {
    final stem = filenameStem.toLowerCase();
    if (query.isEmpty || validationError != null) return 0;
    final matches = switch (mode) {
      FileSearchMode.exact => stem == query,
      FileSearchMode.contains => stem.contains(query),
      FileSearchMode.startsWith =>
        stem.contains(operator) &&
            stem.substring(0, stem.indexOf(operator)) == query,
      FileSearchMode.normalizedExact => normalize(stem) == normalizedQuery,
      FileSearchMode.normalizedStart => normalize(
        stem,
      ).startsWith(normalizedQuery),
      FileSearchMode.trimSuffix => stem.isNotEmpty && query.startsWith(stem),
    };
    if (!matches) return 0;
    return mode == FileSearchMode.trimSuffix ? stem.length : 1;
  }
}
