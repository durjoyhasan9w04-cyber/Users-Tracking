import 'package:flutter_test/flutter_test.dart';
import 'package:user_hub/services/match_notification_service.dart';

void main() {
  const match = <String, Object?>{
    'sport': 'Cricket',
    'home_team': 'Bangladesh',
    'away_team': 'India',
    'competition': 'Asia Cup',
  };

  test('matches opted-in users by favourite team and sport', () {
    const interest = <String, Object?>{
      'match_alerts': 1,
      'sports': 'Cricket, Football',
      'teams': 'Bangladesh; Pakistan',
      'competitions': '',
    };
    expect(MatchNotificationService.isRelevantMatch(match: match, interest: interest), isTrue);
  });

  test('matches opted-in users by competition', () {
    const interest = <String, Object?>{
      'match_alerts': 1,
      'sports': 'Cricket',
      'teams': '',
      'competitions': 'Asia Cup',
    };
    expect(MatchNotificationService.isRelevantMatch(match: match, interest: interest), isTrue);
  });

  test('does not notify users who have not opted in', () {
    const interest = <String, Object?>{
      'match_alerts': 0,
      'sports': 'Cricket',
      'teams': 'Bangladesh',
      'competitions': '',
    };
    expect(MatchNotificationService.isRelevantMatch(match: match, interest: interest), isFalse);
  });

  test('excludes users marked do not contact even when match alerts are opted in', () {
    const interest = <String, Object?>{
      'match_alerts': 1,
      'do_not_contact': 1,
      'sports': 'Cricket',
      'teams': 'Bangladesh',
      'competitions': '',
    };
    expect(MatchNotificationService.isEligibleForMatchAlerts(interest), isFalse);
  });

  test('allows match reminders only when opted in and contact is allowed', () {
    const interest = <String, Object?>{
      'match_alerts': 1,
      'do_not_contact': 0,
    };
    expect(MatchNotificationService.isEligibleForMatchAlerts(interest), isTrue);
  });

  test('does not match an unrelated sport or team', () {
    const interest = <String, Object?>{
      'match_alerts': 1,
      'sports': 'Football',
      'teams': 'Argentina',
      'competitions': '',
    };
    expect(MatchNotificationService.isRelevantMatch(match: match, interest: interest), isFalse);
  });
}

