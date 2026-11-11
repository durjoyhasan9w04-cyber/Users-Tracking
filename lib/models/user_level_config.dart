class UserLevelTier {
  const UserLevelTier({
    required this.key,
    required this.label,
    required this.lifetimeMinimum,
    required this.monthlyMinimum,
  });

  final String key;
  final String label;
  final double lifetimeMinimum;
  final double monthlyMinimum;

  Map<String, Object?> toJson() => {
    'key': key,
    'label': label,
    'lifetime_minimum': lifetimeMinimum,
    'monthly_minimum': monthlyMinimum,
  };

  factory UserLevelTier.fromJson(Map<String, dynamic> json) => UserLevelTier(
    key: json['key'] as String,
    label: json['label'] as String,
    lifetimeMinimum: (json['lifetime_minimum'] as num).toDouble(),
    monthlyMinimum: (json['monthly_minimum'] as num).toDouble(),
  );
}

class UserLevelConfig {
  const UserLevelConfig({required this.tiers});

  static const defaults = UserLevelConfig(tiers: [
    UserLevelTier(key: 'neighborly', label: 'Neighborly', lifetimeMinimum: 0, monthlyMinimum: 0),
    UserLevelTier(key: 'low', label: 'Low Value', lifetimeMinimum: 500, monthlyMinimum: 200),
    UserLevelTier(key: 'medium', label: 'Medium Value', lifetimeMinimum: 3000, monthlyMinimum: 1500),
    UserLevelTier(key: 'high', label: 'High Value', lifetimeMinimum: 10000, monthlyMinimum: 5000),
  ]);

  final List<UserLevelTier> tiers;

  String labelFor(double amount, {required bool monthly}) {
    for (final tier in tiers.reversed) {
      final minimum = monthly ? tier.monthlyMinimum : tier.lifetimeMinimum;
      if (amount >= minimum) return tier.label;
    }
    return tiers.first.label;
  }

  int indexFor(double amount, {required bool monthly}) {
    for (var i = tiers.length - 1; i >= 0; i--) {
      final minimum = monthly ? tiers[i].monthlyMinimum : tiers[i].lifetimeMinimum;
      if (amount >= minimum) return i;
    }
    return 0;
  }

  void validate() {
    if (tiers.length != 4) {
      throw ArgumentError('Exactly four user levels are required.');
    }
    final labels = tiers.map((tier) => tier.label.trim().toLowerCase()).toSet();
    if (labels.length != 4 || tiers.any((tier) => tier.label.trim().isEmpty)) {
      throw ArgumentError('Each user level must have a unique, non-empty label.');
    }
    if (tiers.first.lifetimeMinimum != 0 || tiers.first.monthlyMinimum != 0) {
      throw ArgumentError('The lowest level must start at zero DP.');
    }
    for (var i = 0; i < tiers.length; i++) {
      final tier = tiers[i];
      if (!tier.lifetimeMinimum.isFinite || !tier.monthlyMinimum.isFinite ||
          tier.lifetimeMinimum < 0 || tier.monthlyMinimum < 0) {
        throw ArgumentError('DP requirements must be valid non-negative numbers.');
      }
      if (i > 0 && (tier.lifetimeMinimum <= tiers[i - 1].lifetimeMinimum ||
          tier.monthlyMinimum <= tiers[i - 1].monthlyMinimum)) {
        throw ArgumentError('Level requirements must increase from lowest to highest for both periods.');
      }
    }
  }

  Map<String, Object?> toJson() => {
    'tiers': tiers.map((tier) => tier.toJson()).toList(),
  };

  factory UserLevelConfig.fromJson(Map<String, dynamic> json) {
    final raw = json['tiers'];
    if (raw is! List) return defaults;
    try {
      final config = UserLevelConfig(
        tiers: raw.map((item) => UserLevelTier.fromJson(Map<String, dynamic>.from(item as Map))).toList(),
      );
      config.validate();
      return config;
    } catch (_) {
      return defaults;
    }
  }
}
