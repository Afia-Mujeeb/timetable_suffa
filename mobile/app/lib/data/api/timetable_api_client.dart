import "dart:convert";

import "package:http/http.dart" as http;
import "package:timetable_app/data/api/api_exception.dart";
import "package:timetable_app/data/models/timetable_models.dart";

class TimetableApiResult<T> {
  const TimetableApiResult({
    required this.notModified,
    this.etag,
    this.payload,
  });

  final bool notModified;
  final String? etag;
  final T? payload;
}

class TimetableApiClient {
  TimetableApiClient({
    required String baseUrl,
    required http.Client httpClient,
  })  : _baseUrl = baseUrl.endsWith("/")
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl,
        _httpClient = httpClient;

  final String _baseUrl;
  final http.Client _httpClient;

  Future<TimetableApiResult<SectionsSnapshot>> fetchSections({
    String? ifNoneMatch,
  }) async {
    final response = await _getJson(
      "/v1/sections",
      ifNoneMatch: ifNoneMatch,
    );
    if (response.notModified) {
      return TimetableApiResult(
        notModified: true,
        etag: response.etag,
      );
    }

    return TimetableApiResult(
      notModified: false,
      etag: response.etag,
      payload: SectionsSnapshot.fromApiJson(response.payload),
    );
  }

  Future<TimetableApiResult<SectionTimetable>> fetchSectionTimetable(
    String sectionCode, {
    String? ifNoneMatch,
  }) async {
    final encodedSectionCode = Uri.encodeComponent(sectionCode);
    final response = await _getJson(
      "/v1/sections/$encodedSectionCode/timetable",
      ifNoneMatch: ifNoneMatch,
    );
    if (response.notModified) {
      return TimetableApiResult(
        notModified: true,
        etag: response.etag,
      );
    }

    return TimetableApiResult(
      notModified: false,
      etag: response.etag,
      payload: SectionTimetable.fromApiJson(response.payload),
    );
  }

  Future<
      ({
        String? etag,
        bool notModified,
        Map<String, dynamic> payload,
      })> _getJson(
    String path, {
    String? ifNoneMatch,
  }) async {
    final response = await _httpClient.get(
      Uri.parse("$_baseUrl$path"),
      headers: {
        "accept": "application/json",
        if (ifNoneMatch != null && ifNoneMatch.isNotEmpty)
          "if-none-match": ifNoneMatch,
      },
    );

    if (response.statusCode == 304) {
      return (
        etag: response.headers["etag"],
        notModified: true,
        payload: const <String, dynamic>{},
      );
    }

    final dynamic decoded = response.body.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(response.body);
    final payload =
        decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errorBody = payload["error"];
      final errorMap = errorBody is Map<String, dynamic>
          ? errorBody
          : const <String, dynamic>{};
      throw ApiException(
        statusCode: response.statusCode,
        code: errorMap["code"] as String?,
        message: errorMap["message"] as String? ??
            "Request failed with status ${response.statusCode}.",
      );
    }

    return (
      etag: response.headers["etag"],
      notModified: false,
      payload: payload,
    );
  }
}
