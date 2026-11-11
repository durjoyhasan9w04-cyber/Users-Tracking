import 'dart:convert';
import 'dart:io';

import 'fixture_discovery_service.dart';

/// Gemini + Google Search grounded fixture discovery for the next seven days.
class GeminiFixtureService {
  GeminiFixtureService._();

  static const String _model = 'gemini-2.5-flash';
  static const String _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  static Future<bool> testConnection(String apiKey) async {
    final response = await _request(apiKey, 'Reply with exactly: connected', useSearch: false);
    final candidates = response['candidates'];
    return candidates is List && candidates.isNotEmpty;
  }

  static Future<List<FixtureSearchResult>> searchSavedInterests({
    required String apiKey,
    required List<Map<String, Object?>> interests,
    int days = 7,
  }) async {
    final selections = <Map<String, String>>[];
    for (final row in interests) {
      final user = (row['user_name'] ?? row['name'] ?? 'User').toString();
      for (final field in ['sports', 'teams', 'players', 'competitions']) {
        final raw = (row[field] ?? '').toString();
        for (final item in raw.split(RegExp(r'[,;\n]')).map((e) => e.trim()).where((e) => e.isNotEmpty)) {
          selections.add({'user': user, 'type': field, 'interest': item});
        }
      }
    }
    if (selections.isEmpty) {
      throw const FormatException('Add sports, teams, players or competitions to User interests first.');
    }

    final now = DateTime.now().toUtc();
    final end = now.add(Duration(days: days));
    final prompt = '''
You are a sports fixture research assistant. Use Google Search to find REAL scheduled sports fixtures for the saved interests below.
Search across sports worldwide: cricket, football/soccer, kabaddi, tennis, badminton, esports, basketball, hockey and any other sport named.
Only include matches scheduled from \${now.toIso8601String()} through \${end.toIso8601String()} (UTC).
Prioritize official league, tournament, team and governing-body schedules. Search each saved team/competition carefully, including common aliases.
Never invent a fixture, opponent, date, time, venue or URL. Do not treat article publication dates as match dates. Do not include live scores or completed matches.
If the exact kickoff time is unavailable, set startAt to an ISO date-time at 12:00:00Z only if the source confirms the match date, and set timeConfirmed to false. If the date itself is not confirmed, omit the event.
Return ONLY valid JSON in this exact shape:
{"events":[{"title":"Team A vs Team B","sport":"Football","competition":"League name","startAt":"2026-11-12T15:00:00Z","timeConfirmed":true,"sourceUrl":"https://official-source.example/fixture","venue":"optional"}]}
For every event, sourceUrl must be a real source page found through Google Search. No markdown fences, explanations, predictions or fabricated image URLs.
Saved user interests:
\${jsonEncode(selections)}
''';

    final response = await _request(apiKey, prompt, useSearch: true);
    final candidates = response['candidates'];
    if (candidates is! List || candidates.isEmpty || candidates.first is! Map) {
      throw const FormatException('Gemini did not return any fixture results.');
    }
    final candidate = Map<String, dynamic>.from(candidates.first as Map);
    final parts = (candidate['content'] is Map)
        ? (candidate['content']['parts'] as List? ?? const [])
        : const [];
    final outputText = parts.whereType<Map>().map((p) => p['text']?.toString() ?? '').join('\n').trim();
    if (outputText.isEmpty) throw const FormatException('Gemini returned an empty fixture response.');

    final decoded = _decodeJson(outputText);
    final events = decoded['events'];
    if (events is! List) throw const FormatException('Gemini returned an invalid fixture list.');

    final grounding = candidate['groundingMetadata'];
    final chunks = grounding is Map ? grounding['groundingChunks'] : null;
    final groundedUrls = <String>[];
    if (chunks is List) {
      for (final chunk in chunks) {
        if (chunk is Map && chunk['web'] is Map) {
          final uri = (chunk['web']['uri'] ?? '').toString();
          if (uri.startsWith('http')) groundedUrls.add(uri);
        }
      }
    }

    final found = <FixtureSearchResult>[];
    final seen = <String>{};
    for (final raw in events) {
      if (raw is! Map) continue;
      final event = Map<String, dynamic>.from(raw);
      final title = (event['title'] ?? '').toString().trim();
      final startText = (event['startAt'] ?? '').toString();
      final start = DateTime.tryParse(startText);
      if (title.isEmpty || start == null) continue;
      final instant = start.toUtc();
      if (instant.isBefore(now) || instant.isAfter(end)) continue;

      final rawUrl = (event['sourceUrl'] ?? '').toString().trim();
      final parsedUrl = Uri.tryParse(rawUrl);
      final url = parsedUrl != null && parsedUrl.hasScheme && parsedUrl.host.isNotEmpty
          ? rawUrl
          : (groundedUrls.isEmpty ? '' : groundedUrls.first);
      if (url.isEmpty) continue;

      final key = '\${title.toLowerCase()}|\${instant.toIso8601String()}';
      if (!seen.add(key)) continue;
      final timeConfirmed = event['timeConfirmed'] != false;
      found.add(FixtureSearchResult(
        title: title,
        url: url,
        publishedAt: '',
        source: 'Gemini AI · Google Search\${timeConfirmed ? '' : ' · time unconfirmed'}',
        query: (event['competition'] ?? event['sport'] ?? 'Saved interests').toString(),
        matchStartAt: instant,
      ));
    }
    found.sort((a, b) => a.matchStartAt!.compareTo(b.matchStartAt!));
    return found;
  }

  static Map<String, dynamic> _decodeJson(String text) {
    var clean = text.trim();
    clean = clean.replaceFirst(RegExp(r'^\x60{3}(?:json)?\s*'), '');
    clean = clean.replaceFirst(RegExp(r'\s*\x60{3}$'), '');
    final start = clean.indexOf('{');
    final end = clean.lastIndexOf('}');
    if (start < 0 || end <= start) {
      throw const FormatException('Gemini did not return structured fixture data.');
    }
    final value = jsonDecode(clean.substring(start, end + 1));
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Gemini returned an invalid JSON object.');
    }
    return value;
  }

  static Future<Map<String, dynamic>> _request(
    String apiKey,
    String prompt, {
    required bool useSearch,
  }) async {
    if (apiKey.trim().isEmpty) throw const FormatException('Add your Google Gemini API key in Settings first.');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.postUrl(Uri.parse(_endpoint)).timeout(const Duration(seconds: 15));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set('x-goog-api-key', apiKey.trim());
      request.write(jsonEncode({
        'contents': [
          {'role': 'user', 'parts': [{'text': prompt}]}
        ],
        if (useSearch) 'tools': [{'google_search': {}}],
        'generationConfig': {'temperature': 0.1, 'maxOutputTokens': 8192},
      }));
      final response = await request.close().timeout(const Duration(seconds: 60));
      final body = await response.transform(utf8.decoder).join().timeout(const Duration(seconds: 60));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        String message = 'Gemini API returned HTTP \${response.statusCode}.';
        try {
          final data = jsonDecode(body);
          message = (data['error']?['message'] ?? message).toString();
        } catch (_) {}
        if (response.statusCode == 401 || response.statusCode == 403) {
          throw FormatException('API key rejected. Check your Google AI Studio key and API access. $message');
        }
        if (response.statusCode == 429) {
          throw const FormatException('Google Gemini free quota or rate limit reached. Try again later.');
        }
        throw FormatException(message);
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Gemini returned an unexpected response.');
      }
      return decoded;
    } finally {
      client.close(force: true);
    }
  }
}
