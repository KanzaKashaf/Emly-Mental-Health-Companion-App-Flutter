import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'voice_config.dart';

class SttService {
  Future<String> transcribe(String audioFilePath) async {
    final file = File(audioFilePath);

    if (!await file.exists()) {
      throw SttException('Audio file not found.');
    }

    final fileSize = await file.length();

    if (fileSize < 1000) {
      await _safeDelete(file);
      throw SttException('Please speak a bit longer.');
    }

    final uri = Uri.parse('https://api.openai.com/v1/audio/transcriptions');

    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer ${VoiceConfig.whisperApiKey}'
      ..fields['model'] = VoiceConfig.whisperModel
      ..fields['language'] = 'en'
      ..fields['prompt'] = 'Always output Roman Urdu. Do not use Urdu script.'
      ..files.add(
        await http.MultipartFile.fromPath(
          'file',
          audioFilePath,
          contentType: MediaType('audio', 'wav'),
        ),
      );

    try {
      final streamed = await request.send().timeout(
            const Duration(seconds: 35),
          );

      final response = await http.Response.fromStream(streamed);

      if (response.statusCode != 200) {
        String message = 'Could not understand audio. Please try again.';

        try {
          final body = jsonDecode(response.body);
          message = body['error']?['message']?.toString() ?? message;
        } catch (_) {}

        throw SttException(message);
      }

      final data = jsonDecode(response.body);
      final text = (data['text'] ?? '').toString().trim();

      if (text.isEmpty) {
        throw SttException('No speech detected. Please try again.');
      }

      return text;
    } finally {
      await _safeDelete(file);
    }
  }

  Future<void> _safeDelete(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}

class SttException implements Exception {
  final String message;

  SttException(this.message);

  @override
  String toString() => message;
}