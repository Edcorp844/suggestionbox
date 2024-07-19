import 'package:cloud_firestore/cloud_firestore.dart';

class Suggestion {
  String content;
  DateTime timestamp;

  Suggestion({required this.content, required this.timestamp});

  Map<String, dynamic> toJson() => {
        'content': content,
        'timestamp': timestamp,
      };

  static Suggestion fromJson(Map<String, dynamic> json) => Suggestion(
        content: json['content'],
        timestamp: (json['timestamp'] as Timestamp).toDate(),
      );
}
