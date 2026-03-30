class ParseJob {
  final int? id;
  final int? logId;
  final String sourceType; // text_only | image_only | text_plus_image
  final String parserUsed; // local_parser | gemini_flash_lite | gemini_flash
  final String status; // success | failed | fallback
  final String? rawRequest;
  final String? rawResponse;
  final String? errorCode;
  final String? errorMessage;
  final int? durationMs;
  final DateTime createdAt;

  ParseJob({
    this.id,
    this.logId,
    required this.sourceType,
    required this.parserUsed,
    this.status = 'success',
    this.rawRequest,
    this.rawResponse,
    this.errorCode,
    this.errorMessage,
    this.durationMs,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'logId': logId,
      'sourceType': sourceType,
      'parserUsed': parserUsed,
      'status': status,
      'rawRequest': rawRequest,
      'rawResponse': rawResponse,
      'errorCode': errorCode,
      'errorMessage': errorMessage,
      'durationMs': durationMs,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ParseJob.fromMap(Map<String, dynamic> map) {
    return ParseJob(
      id: map['id'] as int?,
      logId: map['logId'] as int?,
      sourceType: map['sourceType'] as String? ?? 'text_only',
      parserUsed: map['parserUsed'] as String? ?? 'local_parser',
      status: map['status'] as String? ?? 'success',
      rawRequest: map['rawRequest'] as String?,
      rawResponse: map['rawResponse'] as String?,
      errorCode: map['errorCode'] as String?,
      errorMessage: map['errorMessage'] as String?,
      durationMs: map['durationMs'] as int?,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
    );
  }
}
