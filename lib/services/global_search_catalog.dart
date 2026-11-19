class SearchableReportShortcut {
  const SearchableReportShortcut({
    required this.title,
    required this.description,
    required this.terms,
  });

  final String title;
  final String description;
  final List<String> terms;
}

const searchableReportShortcuts = <SearchableReportShortcut>[
  SearchableReportShortcut(
    title: 'DP transaction report',
    description: 'Filter and export DP transactions by date, user and amount',
    terms: ['dp', 'deposit', 'transaction'],
  ),
  SearchableReportShortcut(
    title: 'Bonus distribution report',
    description: 'Review and export user bonus records and reasons',
    terms: ['bonus', 'reward'],
  ),
  SearchableReportShortcut(
    title: 'Quiz bonus report',
    description: 'Review quiz participant bonus records',
    terms: ['quiz bonus', 'participant bonus'],
  ),
  SearchableReportShortcut(
    title: 'Combined transaction report',
    description: 'Review filtered DP and bonus transaction records together',
    terms: ['combined', 'all transactions', 'transaction report'],
  ),
];

List<SearchableReportShortcut> findSearchableReports(String rawQuery) {
  final query = rawQuery.trim().toLowerCase();
  if (query.isEmpty) return const [];
  return searchableReportShortcuts.where((report) {
    return report.terms.any((term) =>
        term.contains(query) || query.contains(term));
  }).toList(growable: false);
}
