import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;

import 'voice_config.dart';

class TtsService {
  final AudioPlayer _player = AudioPlayer();

  bool _isSpeaking = false;

  /// TTS tuning values for calm, human-like therapist voice.
  static const String _firstSentenceRate = '-4%';
  static const String _evenSentenceRate = '-2%';
  static const String _oddSentenceRate = '-5%';

  static const String _firstPause = '550ms';
  static const String _normalPause = '700ms';
  static const String _longPause = '850ms';

  static const String _evenPitch = '+0%';
  static const String _oddPitch = '-1%';

  bool get isSpeaking => _isSpeaking;

  Future<Uint8List> synthesize(String text, String language) async {
    final ssml = _buildSsml(text, language);

    final uri = Uri.parse(
      'https://${VoiceConfig.azureRegion}.tts.speech.microsoft.com/cognitiveservices/v1',
    );

    final response = await http
        .post(
          uri,
          headers: {
            'Ocp-Apim-Subscription-Key': VoiceConfig.azureSpeechKey,
            'Content-Type': 'application/ssml+xml',
            'X-Microsoft-OutputFormat':
                'audio-24khz-48kbitrate-mono-mp3',
            'User-Agent': 'EMLY-Flutter',
          },
          body: utf8.encode(ssml),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw TtsException('Azure TTS error: ${response.statusCode}');
    }

    return response.bodyBytes;
  }

  Future<void> speak(String text, String language) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    try {
      _isSpeaking = true;

      final audioBytes = await synthesize(cleanText, language);

      await _player.stop();
      await _player.play(BytesSource(audioBytes));
      await _player.onPlayerComplete.first;
    } finally {
      _isSpeaking = false;
    }
  }

  Future<void> stop() async {
    await _player.stop();
    _isSpeaking = false;
  }

  void dispose() {
    _player.dispose();
  }

  String _buildSsml(String text, String language) {
    final processedText = _formatTextAdvanced(text);

    return '''
  <speak version="1.0" xml:lang="en-US"
        xmlns="http://www.w3.org/2001/10/synthesis"
        xmlns:mstts="https://www.w3.org/2001/mstts">
    <voice name="${_voiceForLanguage(language)}">
      $processedText
    </voice>
  </speak>
  ''';
  }

  String _voiceForLanguage(String language) {
    if (language.toLowerCase() == 'ur-pk') {
      return VoiceConfig.urduVoice;
    }

    return VoiceConfig.englishVoice;
  }

  String _formatTextAdvanced(String text) {
    final sentences = _splitSentences(text);
    final formatted = <String>[];

    for (var i = 0; i < sentences.length; i++) {
      var sentence = sentences[i].trim();

      if (sentence.isEmpty) continue;

      sentence = _escapeXml(sentence);

      final isUrdu = _containsUrdu(sentence);

      String style;
      String rate;
      String pitch;

      if (i == 0) {
        style = 'calm';
        rate = _firstSentenceRate;
        pitch = _oddPitch;
      } else if (i % 2 == 0) {
        style = 'empathetic';
        rate = _evenSentenceRate;
        pitch = _evenPitch;
      } else {
        style = 'calm';
        rate = _oddSentenceRate;
        pitch = _oddPitch;
      }

      final pause = _pauseForSentence(sentence, i);

      if (isUrdu) {
        sentence = '<lang xml:lang="ur-PK">$sentence</lang>';
      }

      sentence = _addEmphasis(sentence);

      formatted.add('''
  <mstts:express-as style="$style" styledegree="1.4">
    <prosody rate="$rate" pitch="$pitch" volume="soft">
      $sentence
    </prosody>
  </mstts:express-as>
  <break time="$pause"/>
  ''');
    }

    return formatted.join('\n');
  }

  String _pauseForSentence(String sentence, int index) {
    final trimmed = sentence.trim();

    if (index == 0) return _firstPause;

    if (trimmed.endsWith('?') || trimmed.endsWith('؟')) {
      return _longPause;
    }

    if (trimmed.endsWith('!')) {
      return _normalPause;
    }

    if (trimmed.length > 120) {
      return _longPause;
    }

    return _normalPause;
  }

  List<String> _splitSentences(String text) {
    final normalized = text
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (normalized.isEmpty) return [];

    return normalized.split(RegExp(r'(?<=[.!?؟])\s+'));
  }

  bool _containsUrdu(String text) {
    return text.runes.any((code) => code >= 0x0600 && code <= 0x06FF);
  }

  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  String _addEmphasis(String text) {
    final emotionalWords = RegExp(
      r'\b(important|overwhelmed|difficult|heavy|safe|small|moment)\b',
      caseSensitive: false,
    );

    return text.replaceAllMapped(emotionalWords, (match) {
      return '<emphasis level="reduced">${match.group(0)}</emphasis>';
    });
  }
}

class TtsException implements Exception {
  final String message;

  TtsException(this.message);

  @override
  String toString() => message;
}