import "dart:convert";

import "package:http/http.dart" as http;
import "package:timetable_app/data/api/api_exception.dart";
import "package:timetable_app/data/models/timetable_models.dart";

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

  Future<SectionsSnapshot> fetchSections() async {
    final payload = await _getJson("/v1/sections");

    return SectionsSnapshot.fromApiJson(payload);
  }

  Future<SectionTimetable> fetchSectionTimetable(String sectionCode) async {
    final encodedSectionCode = Uri.encodeComponent(sectionCode);
    final payload =
        await _getJson("/v1/sections/$encodedSectionCode/timetable");

    return SectionTimetable.fromApiJson(payload);
  }

  Future<Map<String, dynamic>> _getJson(String path) async {
    final response = await _httpClient.get(
      Uri.parse("$_baseUrl$path"),
      headers: const {
        "accept": "application/json",
      },
    );

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

    return payload;
  }
}
