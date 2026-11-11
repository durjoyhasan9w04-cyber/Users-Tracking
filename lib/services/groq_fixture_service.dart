import 'dart:convert';
import 'dart:io';
import 'fixture_discovery_service.dart';

class GroqFixtureService {
  static const _endpoint = 'https://api.groq.com/openai/v1/chat/completions';
  static const _defaultModel = 'openai/gpt-oss-20b';

  static Future<void> testConnection(String key, {String model = _defaultModel}) async {
    await _request(key, model, 'Reply with exactly GROQ_OK', useBrowserSearch: false);
  }

  static Future<List<FixtureSearchResult>> searchSavedInterests({
    required String apiKey,
    required List<Map<String, Object?>> interests,
    int days = 7,
    String model = _defaultModel,
  }) async {
    if (interests.isEmpty) throw const FormatException('Add sports interests to user profiles first.');
    final profiles = <String, Map<String, Object?>>{};
    final lines = <String>[];
    for (final row in interests) {
      final ref = 'profile_' + (row['user_id']?.toString() ?? '');
      profiles[ref] = row;
      lines.add('profileRef: ' + ref + ' | sports: ' + (row['sports']?.toString() ?? '') +
        ' | teams: ' + (row['teams']?.toString() ?? '') + ' | players: ' +
        (row['players']?.toString() ?? '') + ' | competitions: ' + (row['competitions']?.toString() ?? ''));
    }
    final prompt = 'Search the live web for real upcoming sports fixtures matching these interests. ' +
      'Time window: now through the next ' + days.toString() + ' days. Cover cricket, football, kabaddi, tennis, badminton and esports where reliable public fixture information exists. ' +
      'Return only actual scheduled events with exact ISO-8601 startAt including timezone, direct sourceUrl, title, sport, competition, and matchedProfileRefs. ' +
      'Never use article publication dates as match dates. Never guess times. Exclude postponed, cancelled, completed or unscheduled events. ' +
      'Return ONLY JSON: {"events":[{"title":"...","sport":"...","competition":"...","startAt":"...","sourceUrl":"https://...","matchedProfileRefs":["profile_..."]}]}. ' +
      'If none: {"events":[]}. Anonymous profile references only; never reveal or request real identities. Interests:\n' + lines.join('\n');
    final content = await _request(apiKey, model, prompt, useBrowserSearch: true);
    var clean = content.trim().replaceAll(RegExp(r'^\u0060\u0060\u0060(?:json)?\s*', caseSensitive: false), '');
    clean = clean.replaceAll(RegExp(r'\s*\u0060\u0060\u0060$'), '');
    final startIndex = clean.indexOf('{'), endIndex = clean.lastIndexOf('}');
    if (startIndex < 0 || endIndex <= startIndex) throw const FormatException('Groq did not return structured fixture data.');
    final parsed = jsonDecode(clean.substring(startIndex, endIndex + 1));
    if (parsed is! Map<String, dynamic> || parsed['events'] is! List) throw const FormatException('Groq returned invalid fixture data.');
    final now = DateTime.now().toUtc(), end = now.add(Duration(days: days));
    final results = <FixtureSearchResult>[], seen = <String>{};
    for (final raw in parsed['events'] as List) {
      if (raw is! Map) continue;
      final event = Map<String, dynamic>.from(raw);
      final title = (event['title'] ?? '').toString().trim();
      final url = (event['sourceUrl'] ?? '').toString().trim();
      final startAt = DateTime.tryParse((event['startAt'] ?? '').toString());
      if (title.isEmpty || !url.startsWith('https://') || startAt == null) continue;
      final instant = startAt.toUtc();
      if (instant.isBefore(now) || instant.isAfter(end)) continue;
      final matched = <String>[];
      final refs = event['matchedProfileRefs'];
      if (refs is List) {
        for (final ref in refs) {
          final row = profiles[ref.toString()];
          final name = row?['user_name']?.toString() ?? row?['name']?.toString() ?? '';
          if (name.isNotEmpty && !matched.contains(name)) matched.add(name);
        }
      }
      final unique = title.toLowerCase() + '|' + instant.toIso8601String();
      if (!seen.add(unique)) continue;
      results.add(FixtureSearchResult(
        title: title, url: url, publishedAt: '',
        source: 'Groq AI · Browser Search · ' + (event['sport']?.toString() ?? 'Sports'),
        query: 'Saved sports interests', matchStartAt: instant, matchedUsers: matched,
      ));
    }
    results.sort((x, y) => x.matchStartAt!.compareTo(y.matchStartAt!));
    return results;
  }

  static Future<String> _request(String key, String model, String prompt, {required bool useBrowserSearch}) async {
    if (key.trim().isEmpty) throw const FormatException('Add your Groq API key in Settings first.');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.postUrl(Uri.parse(_endpoint)).timeout(const Duration(seconds: 15));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer ' + key.trim());
      request.write(jsonEncode({
        'model': model, 'messages': [{'role': 'user', 'content': prompt}],
        'temperature': 0.1, 'max_completion_tokens': 8192, 'stream': false,
        if (useBrowserSearch) 'tool_choice': 'required',
        if (useBrowserSearch) 'tools': [{'type': 'browser_search'}],
      }));
      final response = await request.close().timeout(const Duration(seconds: 90));
      final body = await response.transform(utf8.decoder).join().timeout(const Duration(seconds: 90));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        var message = 'Groq API returned HTTP ' + response.statusCode.toString() + '.';
        try { final data = jsonDecode(body); message = (data['error']?['message'] ?? message).toString(); } catch (_) {}
        if (response.statusCode == 401 || response.statusCode == 403) throw FormatException('API key rejected. Check your Groq Console key. ' + message);
        if (response.statusCode == 429) throw const FormatException('Groq free-plan rate limit reached. Check model limits or try later.');
        throw FormatException(message);
      }
      final decoded = jsonDecode(body);
      final content = decoded['choices']?[0]?['message']?['content']?.toString();
      if (content == null || content.isEmpty) throw const FormatException('Groq returned an empty response.');
      return content;
    } finally { client.close(force: true); }
  }
}
