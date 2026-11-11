import 'dart:async';
import 'dart:convert';
import 'dart:io';

class FixtureSearchResult {
  const FixtureSearchResult({
    required this.title,
    required this.url,
    required this.publishedAt,
    required this.source,
    required this.query,
    this.matchStartAt,
    this.imageUrl = '',
  });
  final String title;
  final String url;
  final String publishedAt;
  final String source;
  final String query;
  final DateTime? matchStartAt;
  final String imageUrl;
}

class FixtureDiscoveryService {
  FixtureDiscoveryService._();

  static List<String> buildQueries(List<Map<String, Object?>> interests) {
    final queries = <String>{};
    for (final interest in interests) {
      final sport = (interest['sports'] as String? ?? '').trim();
      final teams = _tokens(interest['teams']);
      final competitions = _tokens(interest['competitions']);
      for (final team in teams) {
        queries.add('"$team" (fixtures OR schedule OR upcoming match)');
      }
      for (final competition in competitions) {
        queries.add('"$competition" (fixtures OR schedule OR match)');
      }
      if (teams.isEmpty && competitions.isEmpty && sport.isNotEmpty) {
        queries.add('"$sport" upcoming fixtures schedule');
      }
    }
    return queries.take(10).toList();
  }


  // Scrape public sports schedule pages for structured SportsEvent records.
  // A source is skipped when it blocks requests or exposes no event data.
  static const Map<String, String> scheduleSources = {
    'ICC Cricket': 'https://www.icc-cricket.com/fixtures-results',
    'FanCode': 'https://www.fancode.com/pages/schedule',
    'Silbo Sports': 'https://silbosports.com/explore/',
    'World Football Portal': 'https://worldfootballportal.com/fixtures/',
    'Pro Kabaddi': 'https://www.prokabaddi.com/schedule-fixtures-results',
    'ATP Tour': 'https://www.atptour.com/en/scores/current',
    'WTA Tennis': 'https://www.wtatennis.com/tournaments',
    'BWF Badminton': 'https://bwfbadminton.com/tournament/',
  };

  static Future<List<FixtureSearchResult>> searchUpcomingFixtures({int days = 7}) async {
    final nowUtc = DateTime.now().toUtc();
    final endUtc = nowUtc.add(Duration(days: days));
    final found = <FixtureSearchResult>[];
    final seen = <String>{};
    for (final source in scheduleSources.entries) {
      try {
        final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
        try {
          final request = await client.getUrl(Uri.parse(source.value)).timeout(const Duration(seconds: 10));
          request.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0 (compatible; UserHubFixtureFinder/1.0)');
          request.headers.set(HttpHeaders.acceptHeader, 'text/html,application/xhtml+xml,application/ld+json');
          final response = await request.close().timeout(const Duration(seconds: 12));
          if (response.statusCode != HttpStatus.ok) continue;
          final html = await response.transform(utf8.decoder).join().timeout(const Duration(seconds: 12));
          for (final event in parseSportsEvents(html, sourceName: source.key, pageUrl: source.value)) {
            final instant = event.matchStartAt!.toUtc();
            if (instant.isBefore(nowUtc) || instant.isAfter(endUtc)) continue;
            final key = '${event.title.toLowerCase()}|${instant.toIso8601String()}';
            if (seen.add(key)) found.add(event);
          }
        } finally {
          client.close(force: true);
        }
      } catch (_) {
        // Keep searching other sources when an individual site is unavailable.
      }
    }
    found.sort((x, y) => x.matchStartAt!.compareTo(y.matchStartAt!));
    return found;
  }

  static List<FixtureSearchResult> parseSportsEvents(
    String html, {required String sourceName, required String pageUrl}
  ) {
    final results = <FixtureSearchResult>[];
    final seen = <String>{};
    void visit(Object? value) {
      if (value is List) {
        for (final item in value) { visit(item); }
      } else if (value is Map) {
        final rawType = value['@type'];
        final types = rawType is List ? rawType.map((e) => e.toString()).toList() : [rawType?.toString() ?? ''];
        if (types.any((t) => t.toLowerCase().contains('sportsevent') || t.toLowerCase() == 'event')) {
          final start = DateTime.tryParse(value['startDate']?.toString() ?? '');
          final name = value['name']?.toString().trim() ?? '';
          if (start != null && name.isNotEmpty) {
            String teamName(Object? team) => team is Map ? (team['name']?.toString() ?? '') : (team?.toString() ?? '');
            final home = teamName(value['homeTeam']);
            final away = teamName(value['awayTeam']);
            final title = home.isNotEmpty && away.isNotEmpty ? '$home vs $away' : name;
            final rawImage = value['image'];
            final image = rawImage is List ? (rawImage.isEmpty ? '' : rawImage.first.toString())
                : rawImage is Map ? (rawImage['url']?.toString() ?? '') : (rawImage?.toString() ?? '');
            final eventUrl = value['url']?.toString() ?? pageUrl;
            final key = '$title|${start.toUtc().toIso8601String()}';
            if (seen.add(key)) {
              results.add(FixtureSearchResult(
                title: title, url: eventUrl.startsWith('http') ? eventUrl : pageUrl,
                publishedAt: '', source: sourceName, query: 'Upcoming fixtures',
                matchStartAt: start, imageUrl: image.startsWith('http') ? image : '',
              ));
            }
          }
        }
        for (final child in value.values) { visit(child); }
      }
    }
    final scripts = RegExp(r'<script[^>]*application/ld\\+json[^>]*>([\\s\\S]*?)</script>', caseSensitive: false);
    for (final match in scripts.allMatches(html)) {
      final raw = match.group(1)?.trim() ?? '';
      if (raw.isNotEmpty) { try { visit(jsonDecode(raw)); } catch (_) {} }
    }
    return results;
  }

  static Future<List<FixtureSearchResult>> searchSavedInterests(
    List<Map<String, Object?>> interests,
  ) async {
    final queries = buildQueries(interests);
    if (queries.isEmpty) {
      throw const FormatException('No saved teams or competitions were found. Add sports interests first.');
    }
    final results = <FixtureSearchResult>[];
    final seen = <String>{};
    Object? lastError;
    for (final query in queries) {
      try {
        final found = await search(query);
        for (final result in found) {
          if (seen.add(result.url.isEmpty ? result.title : result.url)) {
            results.add(result);
          }
        }
      } catch (error) {
        lastError = error;
      }
    }
    if (results.isEmpty && lastError != null) throw lastError;
    return results;
  }

  static Future<List<FixtureSearchResult>> search(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) throw const FormatException('Enter a team, league or competition to search.');
    final uri = Uri.https('news.google.com', '/rss/search', {
      'q': clean,
      'hl': 'en',
      'gl': 'BD',
      'ceid': 'BD:en',
    });
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 12));
      request.headers.set(HttpHeaders.userAgentHeader, 'UserHubFixtureFinder/1.0');
      request.headers.set(HttpHeaders.acceptHeader, 'application/rss+xml, application/xml, text/xml');
      final response = await request.close().timeout(const Duration(seconds: 15));
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Google News returned HTTP ${response.statusCode}.');
      }
      final body = await response.transform(utf8.decoder).join().timeout(const Duration(seconds: 15));
      return parseRss(body, query: clean);
    } finally {
      client.close(force: true);
    }
  }

  static List<FixtureSearchResult> parseRss(String xml, {String query = ''}) {
    final items = RegExp(r'<item(?:\s[^>]*)?>([\s\S]*?)</item>', caseSensitive: false)
        .allMatches(xml);
    final results = <FixtureSearchResult>[];
    for (final item in items) {
      final content = item.group(1) ?? '';
      final title = _tag(content, 'title');
      final link = _tag(content, 'link');
      if (title.isEmpty || link.isEmpty) continue;
      results.add(FixtureSearchResult(
        title: title,
        url: link,
        publishedAt: _tag(content, 'pubDate'),
        source: _tag(content, 'source'),
        query: query,
      ));
    }
    return results;
  }

  static Map<String, String>? parseTeams(String title) {
    final match = RegExp(
      r'^(.+?)\s+(?:vs?\.?|versus)\s+(.+?)(?:\s+(?:live|preview|match|fixture|highlights|score).*)?$',
      caseSensitive: false,
    ).firstMatch(title.trim());
    if (match == null) return null;
    final home = match.group(1)!.trim();
    final away = match.group(2)!.trim().replaceFirst(RegExp(r'\s*[-|:].*$'), '').trim();
    if (home.isEmpty || away.isEmpty) return null;
    return {'home': home, 'away': away};
  }

  static List<String> _tokens(Object? value) => (value as String? ?? '')
      .split(RegExp(r'[,;|\n]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();

  static String _tag(String xml, String name) {
    final match = RegExp(
      '<$name(?:\\s[^>]*)?>([\\s\\S]*?)</$name>',
      caseSensitive: false,
    ).firstMatch(xml);
    if (match == null) return '';
    var value = match.group(1)!.trim();
    if (value.startsWith('<![CDATA[') && value.endsWith(']]>')) {
      value = value.substring(9, value.length - 3);
    }
    return _decodeXml(value.trim());
  }

  static String _decodeXml(String value) {
    const entities = {
      '&amp;': '&',
      '&quot;': '"',
      '&apos;': "'",
      '&#39;': "'",
      '&lt;': '<',
      '&gt;': '>',
    };
    var decoded = value;
    entities.forEach((key, replacement) {
      decoded = decoded.replaceAll(key, replacement);
    });
    decoded = decoded.replaceAllMapped(RegExp(r'&#(x[0-9a-fA-F]+|[0-9]+);'), (match) {
      final token = match.group(1)!;
      final codePoint = token.startsWith('x')
          ? int.tryParse(token.substring(1), radix: 16)
          : int.tryParse(token);
      return codePoint == null ? match.group(0)! : String.fromCharCode(codePoint);
    });
    return decoded;
  }
}
