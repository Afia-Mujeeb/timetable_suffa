enum ReminderLeadTime {
  fiveMinutes(5, "5 minutes before"),
  tenMinutes(10, "10 minutes before"),
  fifteenMinutes(15, "15 minutes before"),
  thirtyMinutes(30, "30 minutes before");

  const ReminderLeadTime(this.minutes, this.label);

  final int minutes;
  final String label;

  static ReminderLeadTime fromMinutes(int? minutes) {
    return ReminderLeadTime.values.firstWhere(
      (leadTime) => leadTime.minutes == minutes,
      orElse: () => ReminderLeadTime.tenMinutes,
    );
  }
}

class ReminderPreferences {
  const ReminderPreferences({
    required this.enabled,
    required this.leadTime,
  });

  factory ReminderPreferences.fromJson(Map<String, dynamic> json) {
    return ReminderPreferences(
      enabled: json["enabled"] as bool? ?? true,
      leadTime: ReminderLeadTime.fromMinutes(json["leadTimeMinutes"] as int?),
    );
  }

  static const ReminderPreferences defaults = ReminderPreferences(
    enabled: true,
    leadTime: ReminderLeadTime.tenMinutes,
  );

  final bool enabled;
  final ReminderLeadTime leadTime;

  int get leadTimeMinutes => leadTime.minutes;

  ReminderPreferences copyWith({
    bool? enabled,
    ReminderLeadTime? leadTime,
  }) {
    return ReminderPreferences(
      enabled: enabled ?? this.enabled,
      leadTime: leadTime ?? this.leadTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "enabled": enabled,
      "leadTimeMinutes": leadTime.minutes,
    };
  }
}

enum ReminderPermissionStatus {
  granted,
  denied,
  unsupported,
  unknown,
}
