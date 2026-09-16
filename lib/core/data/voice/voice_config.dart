class VoiceConfig {
  // For FYP/demo only. Do not commit real keys to public GitHub.
  static const String whisperApiKey = 'Api-Key';
  static const String whisperModel = 'gpt-4o-transcribe';

  static const String azureSpeechKey = 'Api-Key';
  static const String azureRegion = 'centralindia';

  static const int sampleRate = 16000;

  // Your requested therapist-style voice.
  static const String englishVoice = 'en-US-AvaMultilingualNeural';

  // We still use Ava multilingual because your SSML supports mixed English/Urdu.
  static const String urduVoice = 'en-US-AvaMultilingualNeural';
}