class AppErrorEvent {
  const AppErrorEvent({
    required this.timestamp,
    required this.source,
    required this.message,
    required this.exceptionType,
    required this.fatal,
    this.stackTrace,
  });

  factory AppErrorEvent.fromJson(Map<String, dynamic> json) {
    return AppErrorEvent(
      timestamp: json["timestamp"] as String? ?? "",
      source: json["source"] as String? ?? "unknown",
      message: json["message"] as String? ?? "Unknown error",
      exceptionType: json["exceptionType"] as String? ?? "Object",
      fatal: json["fatal"] as bool? ?? false,
      stackTrace: json["stackTrace"] as String?,
    );
  }

  final String timestamp;
  final String source;
  final String message;
  final String exceptionType;
  final bool fatal;
  final String? stackTrace;

  Map<String, dynamic> toJson() {
    return {
      "timestamp": timestamp,
      "source": source,
      "message": message,
      "exceptionType": exceptionType,
      "fatal": fatal,
      "stackTrace": stackTrace,
    };
  }
}
