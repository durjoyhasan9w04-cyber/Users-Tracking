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
  });
  final String title;
  final String url;
  final String publishedAt;
  final String source;
  final String query;
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
