import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'voice_config.dart';

class VoiceRecorderService {
  final AudioRecorder _recorder = AudioRecorder();

  String? _currentPath;
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<bool> startRecording() async {
    final hasPermission = await _recorder.hasPermission();

    if (!hasPermission) {
      final granted = await requestPermission();
      if (!granted) return false;
    }

    final dir = await getTemporaryDirectory();
    _currentPath =
        '${dir.path}/emly_voice_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: VoiceConfig.sampleRate,
        numChannels: 1,
        bitRate: 256000,
      ),
      path: _currentPath!,
    );

    _isRecording = true;
    return true;
  }

  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    final path = await _recorder.stop();
    _isRecording = false;
    _currentPath = null;

    return path;
  }

  Future<void> cancelRecording() async {
    if (!_isRecording) return;

    final path = await _recorder.stop();
    _isRecording = false;

    final toDelete = path ?? _currentPath;
    if (toDelete != null) {
      final file = File(toDelete);
      if (await file.exists()) {
        await file.delete();
      }
    }

    _currentPath = null;
  }

  void dispose() {
    _recorder.dispose();
  }
}