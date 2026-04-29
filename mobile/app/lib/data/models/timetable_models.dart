typedef JsonMap = Map<String, dynamic>;

List<String> _readStringList(Object? value) {
  if (value is! List<Object?>) {
    return const [];
  }

  return value.whereType<String>().toList(growable: false);
}

enum DayKey {
  monday("Monday"),
  tuesday("Tuesday"),
  wednesday("Wednesday"),
  thursday("Thursday"),
  friday("Friday"),
  saturday("Saturday");

  const DayKey(this.label);

  final String label;

  static DayKey fromValue(String value) {
    return DayKey.values.firstWhere(
      (day) => day.name == value,
      orElse: () => DayKey.monday,
    );
  }
}

class TimetableVersion {
  const TimetableVersion({
    required this.versionId,
    required this.sourceFileName,
    required this.generatedDate,
    required this.publishStatus,
    required this.sectionCount,
    required this.meetingCount,
    required this.warningCount,
    required this.createdAt,
    required this.publishedAt,
  });

  factory TimetableVersion.fromJson(JsonMap json) {
    return TimetableVersion(
      versionId: json["versionId"] as String? ?? "",
      sourceFileName: json["sourceFileName"] as String? ?? "",
      generatedDate: json["generatedDate"] as String? ?? "",
      publishStatus: json["publishStatus"] as String? ?? "draft",
      sectionCount: json["sectionCount"] as int? ?? 0,
      meetingCount: json["meetingCount"] as int? ?? 0,
      warningCount: json["warningCount"] as int? ?? 0,
      createdAt: json["createdAt"] as String? ?? "",
      publishedAt: json["publishedAt"] as String?,
    );
  }

  final String versionId;
  final String sourceFileName;
  final String generatedDate;
  final String publishStatus;
  final int sectionCount;
  final int meetingCount;
  final int warningCount;
  final String createdAt;
  final String? publishedAt;

  JsonMap toJson() {
    return {
      "versionId": versionId,
      "sourceFileName": sourceFileName,
      "generatedDate": generatedDate,
      "publishStatus": publishStatus,
      "sectionCount": sectionCount,
      "meetingCount": meetingCount,
      "warningCount": warningCount,
      "createdAt": createdAt,
      "publishedAt": publishedAt,
    };
  }
}

class SectionSummary {
  const SectionSummary({
    required this.sectionCode,
    required this.displayName,
    required this.active,
    required this.meetingCount,
  });

  factory SectionSummary.fromJson(JsonMap json) {
    return SectionSummary(
      sectionCode:
          json["sectionCode"] as String? ?? json["code"] as String? ?? "",
      displayName: json["displayName"] as String? ?? "",
      active: json["active"] as bool? ?? false,
      meetingCount: json["meetingCount"] as int? ?? 0,
    );
  }

  final String sectionCode;
  final String displayName;
  final bool active;
  final int meetingCount;

  JsonMap toJson() {
    return {
      "sectionCode": sectionCode,
      "displayName": displayName,
      "active": active,
      "meetingCount": meetingCount,
    };
  }
}

class SectionDetail {
  const SectionDetail({
    required this.sectionCode,
    required this.displayName,
    required this.active,
    required this.meetingCount,
    required this.timetableVersion,
  });

  factory SectionDetail.fromJson(JsonMap json) {
    return SectionDetail(
      sectionCode: json["sectionCode"] as String? ?? "",
      displayName: json["displayName"] as String? ?? "",
      active: json["active"] as bool? ?? false,
      meetingCount: json["meetingCount"] as int? ?? 0,
      timetableVersion: TimetableVersion.fromJson(
        (json["timetableVersion"] as JsonMap?) ?? <String, dynamic>{},
      ),
    );
  }

  final String sectionCode;
  final String displayName;
  final bool active;
  final int meetingCount;
  final TimetableVersion timetableVersion;

  JsonMap toJson() {
    return {
      "sectionCode": sectionCode,
      "displayName": displayName,
      "active": active,
      "meetingCount": meetingCount,
      "timetableVersion": timetableVersion.toJson(),
    };
  }
}

class TimetableMeeting {
  const TimetableMeeting({
    required this.courseName,
    required this.instructor,
    required this.room,
    required this.day,
    required this.dayKey,
    required this.startTime,
    required this.endTime,
    required this.meetingType,
    required this.online,
    required this.sourcePage,
    required this.confidenceClass,
    required this.warnings,
  });

  factory TimetableMeeting.fromJson(JsonMap json) {
    return TimetableMeeting(
      courseName: json["courseName"] as String? ?? "",
      instructor: json["instructor"] as String?,
      room: json["room"] as String?,
      day: json["day"] as String? ?? "",
      dayKey: DayKey.fromValue(json["dayKey"] as String? ?? "monday"),
      startTime: json["startTime"] as String? ?? "",
      endTime: json["endTime"] as String? ?? "",
      meetingType: json["meetingType"] as String?,
      online: json["online"] as bool? ?? false,
      sourcePage: json["sourcePage"] as int? ?? 0,
      confidenceClass: json["confidenceClass"] as String? ?? "high",
      warnings: _readStringList(json["warnings"]),
    );
  }

  final String courseName;
  final String? instructor;
  final String? room;
  final String day;
  final DayKey dayKey;
  final String startTime;
  final String endTime;
  final String? meetingType;
  final bool online;
  final int sourcePage;
  final String confidenceClass;
  final List<String> warnings;

  JsonMap toJson() {
    return {
      "courseName": courseName,
      "instructor": instructor,
      "room": room,
      "day": day,
      "dayKey": dayKey.name,
      "startTime": startTime,
      "endTime": endTime,
      "meetingType": meetingType,
      "online": online,
      "sourcePage": sourcePage,
      "confidenceClass": confidenceClass,
      "warnings": warnings,
    };
  }
}

class SectionsSnapshot {
  const SectionsSnapshot({
    required this.timetableVersion,
    required this.sections,
    this.etag,
    this.isStale = false,
    this.cachedAt,
  });

  factory SectionsSnapshot.fromApiJson(JsonMap json) {
    return SectionsSnapshot(
      timetableVersion: TimetableVersion.fromJson(
        (json["timetableVersion"] as JsonMap?) ?? <String, dynamic>{},
      ),
      sections: ((json["sections"] as List<Object?>?) ?? const [])
          .whereType<JsonMap>()
          .map(SectionSummary.fromJson)
          .toList(growable: false),
    );
  }

  factory SectionsSnapshot.fromCacheJson(JsonMap json) {
    return SectionsSnapshot(
      timetableVersion: TimetableVersion.fromJson(
        (json["timetableVersion"] as JsonMap?) ?? <String, dynamic>{},
      ),
      sections: ((json["sections"] as List<Object?>?) ?? const [])
          .whereType<JsonMap>()
          .map(SectionSummary.fromJson)
          .toList(growable: false),
      etag: json["etag"] as String?,
      isStale: json["isStale"] as bool? ?? false,
      cachedAt: json["cachedAt"] as String?,
    );
  }

  final TimetableVersion timetableVersion;
  final List<SectionSummary> sections;
  final String? etag;
  final bool isStale;
  final String? cachedAt;

  SectionsSnapshot copyWith({
    TimetableVersion? timetableVersion,
    List<SectionSummary>? sections,
    String? etag,
    bool? isStale,
    String? cachedAt,
  }) {
    return SectionsSnapshot(
      timetableVersion: timetableVersion ?? this.timetableVersion,
      sections: sections ?? this.sections,
      etag: etag ?? this.etag,
      isStale: isStale ?? this.isStale,
      cachedAt: cachedAt ?? this.cachedAt,
    );
  }

  JsonMap toJson() {
    return {
      "timetableVersion": timetableVersion.toJson(),
      "sections": sections.map((section) => section.toJson()).toList(),
      "etag": etag,
      "isStale": isStale,
      "cachedAt": cachedAt,
    };
  }
}

class SectionTimetable {
  const SectionTimetable({
    required this.section,
    required this.timetableVersion,
    required this.meetings,
    this.etag,
    this.isStale = false,
    this.cachedAt,
  });

  factory SectionTimetable.fromApiJson(JsonMap json) {
    return SectionTimetable(
      section: SectionDetail.fromJson(
        (json["section"] as JsonMap?) ?? <String, dynamic>{},
      ),
      timetableVersion: TimetableVersion.fromJson(
        (json["timetableVersion"] as JsonMap?) ?? <String, dynamic>{},
      ),
      meetings: ((json["meetings"] as List<Object?>?) ?? const [])
          .whereType<JsonMap>()
          .map(TimetableMeeting.fromJson)
          .toList(growable: false),
    );
  }

  factory SectionTimetable.fromCacheJson(JsonMap json) {
    return SectionTimetable(
      section: SectionDetail.fromJson(
        (json["section"] as JsonMap?) ?? <String, dynamic>{},
      ),
      timetableVersion: TimetableVersion.fromJson(
        (json["timetableVersion"] as JsonMap?) ?? <String, dynamic>{},
      ),
      meetings: ((json["meetings"] as List<Object?>?) ?? const [])
          .whereType<JsonMap>()
          .map(TimetableMeeting.fromJson)
          .toList(growable: false),
      etag: json["etag"] as String?,
      isStale: json["isStale"] as bool? ?? false,
      cachedAt: json["cachedAt"] as String?,
    );
  }

  final SectionDetail section;
  final TimetableVersion timetableVersion;
  final List<TimetableMeeting> meetings;
  final String? etag;
  final bool isStale;
  final String? cachedAt;

  SectionTimetable copyWith({
    SectionDetail? section,
    TimetableVersion? timetableVersion,
    List<TimetableMeeting>? meetings,
    String? etag,
    bool? isStale,
    String? cachedAt,
  }) {
    return SectionTimetable(
      section: section ?? this.section,
      timetableVersion: timetableVersion ?? this.timetableVersion,
      meetings: meetings ?? this.meetings,
      etag: etag ?? this.etag,
      isStale: isStale ?? this.isStale,
      cachedAt: cachedAt ?? this.cachedAt,
    );
  }

  JsonMap toJson() {
    return {
      "section": section.toJson(),
      "timetableVersion": timetableVersion.toJson(),
      "meetings": meetings.map((meeting) => meeting.toJson()).toList(),
      "etag": etag,
      "isStale": isStale,
      "cachedAt": cachedAt,
    };
  }
}
