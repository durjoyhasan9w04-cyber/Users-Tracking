class ReportRowFilter {
  static List<Map<String, Object?>> apply(
    Iterable<Map<String, Object?>> rows, {
    String typeFilter = 'All',
    String search = '',
  }) {
    final term = search.trim().toLowerCase();
    return rows.where((row) {
      if (typeFilter != 'All' && row['type']?.toString() != typeFilter) return false;
      if (term.isEmpty) return true;
      final haystack = [
        row['user_name'], row['phone'], row['reason'], row['notes'], row['transaction_date'],
      ].map((value) => value?.toString() ?? '').join(' ').toLowerCase();
      return haystack.contains(term);
    }).toList();
  }
}
