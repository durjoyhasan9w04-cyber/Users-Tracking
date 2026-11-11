import 'package:flutter_test/flutter_test.dart';
import 'package:user_hub/services/fixture_discovery_service.dart';

void main() {
  group('FixtureDiscoveryService', () {
    test('builds unique searches from saved favourite teams and leagues', () {
      final queries = FixtureDiscoveryService.buildQueries([
        {'teams': 'Bangladesh, India', 'competitions': 'ICC T20 World Cup', 'sports': 'Cricket'},
        {'teams': 'Bangladesh', 'competitions': '', 'sports': 'Cricket'},
      ]);
      expect(queries, hasLength(3));
      expect(queries.join(' '), contains('Bangladesh'));
      expect(queries.join(' '), contains('ICC T20 World Cup'));
    });

    test('uses a sport search when no team or competition is saved', () {
      expect(
        FixtureDiscoveryService.buildQueries([{'teams': '', 'competitions': '', 'sports': 'Kabaddi'}]).single,
        contains('Kabaddi'),
      );
    });

    test('parses RSS items and decodes XML entities', () {
      const rss = '''
        <rss><channel><item>
          <title>Bangladesh vs India &amp; preview</title>
          <link>https://example.com/match</link>
          <pubDate>Tue, 11 Nov 2026 12:00:00 GMT</pubDate>
          <source>Sports News</source>
        </item></channel></rss>
      ''';
      final results = FixtureDiscoveryService.parseRss(rss, query: 'Bangladesh');
      expect(results, hasLength(1));
      expect(results.single.title, 'Bangladesh vs India & preview');
      expect(results.single.source, 'Sports News');
      expect(results.single.query, 'Bangladesh');
    });

    test('extracts teams from a versus headline', () {
      expect(FixtureDiscoveryService.parseTeams('Bangladesh vs India'), {'home': 'Bangladesh', 'away': 'India'});
      expect(FixtureDiscoveryService.parseTeams('ICC announces new schedule'), isNull);
    });
  });
}
