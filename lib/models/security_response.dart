class SecurityResponse {
  final bool success;
  final String message;
  final String? accessType; // 'rfid', 'pin', 'nfc'
  final DateTime timestamp;
  final String? cardId;

  SecurityResponse({
    required this.success,
    required this.message,
    this.accessType,
    required this.timestamp,
    this.cardId,
  });

  factory SecurityResponse.fromJson(Map<String, dynamic> json) {
    return SecurityResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      accessType: json['access_type'],
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      cardId: json['card_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'access_type': accessType,
      'timestamp': timestamp.toIso8601String(),
      'card_id': cardId,
    };
  }
}
