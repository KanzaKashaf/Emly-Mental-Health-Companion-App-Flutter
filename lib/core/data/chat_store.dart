import 'package:flutter/material.dart';

class ChatMessage {
  final String text;
  final bool fromUser;
  final DateTime time;

  ChatMessage({
    required this.text,
    required this.fromUser,
    required this.time,
  });
}

class ChatSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final List<ChatMessage> messages;

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.messages,
  });
}


class ChatStore extends ChangeNotifier {
  final List<ChatSession> _sessions = [];

  List<ChatSession> get sessions => _sessions;

  void upsertSession(ChatSession session) {
    _sessions.removeWhere((s) => s.id == session.id);
    _sessions.insert(0, session);
    notifyListeners();
  }

  ChatSession? getById(String id) {
    try {
      return _sessions.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  void deleteSession(String id) {
    _sessions.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  void clearAll() {
    _sessions.clear();
    notifyListeners();
  }
}

final chatStore = ChatStore();
