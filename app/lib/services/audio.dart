import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Graba la voz en WAV PCM mono a 16 kHz: el formato que pide Azure.
class VoiceRecorder {
  final AudioRecorder _rec = AudioRecorder();

  Future<bool> hasPermission() => _rec.hasPermission();

  Future<void> start() async {
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _rec.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
  }

  /// Detiene la grabación y devuelve los bytes (borra el archivo temporal:
  /// la voz del usuario no se guarda en el teléfono).
  Future<Uint8List?> stop() async {
    final path = await _rec.stop();
    if (path == null) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    await file.delete();
    return bytes;
  }

  Future<void> cancel() => _rec.cancel();

  Future<void> dispose() => _rec.dispose();
}

/// Reproduce el audio nativo de Storage; si la lección todavía no tiene audio
/// generado, usa la voz del teléfono (TTS) como respaldo.
class Speaker {
  final AudioPlayer _player = AudioPlayer();
  final FlutterTts _tts = FlutterTts();
  bool _ttsReady = false;

  Stream<bool> get playingStream => _player.playingStream;

  Future<void> _initTts() async {
    if (_ttsReady) return;
    await _tts.setLanguage('en-US');
    await _tts.awaitSpeakCompletion(true);
    _ttsReady = true;
  }

  /// Reproduce y espera a que termine (o a que se llame a [stop]).
  Future<void> play({String? url, required String text, double speed = 1.0}) async {
    await stop();
    if (url != null && url.isNotEmpty) {
      await _player.setUrl(url);
      await _player.setSpeed(speed);
      _player.play(); // no se espera: play() solo termina al pausar
      await _player.processingStateStream.firstWhere((s) =>
          s == ProcessingState.completed || s == ProcessingState.idle);
    } else {
      await _initTts();
      // 0.5 es la velocidad "normal" en Android e iOS.
      await _tts.setSpeechRate((0.45 * speed).clamp(0.2, 0.8));
      await _tts.speak(text);
    }
  }

  Future<void> stop() async {
    await _player.stop();
    if (_ttsReady) await _tts.stop();
  }

  Future<void> dispose() async {
    await _player.dispose();
    if (_ttsReady) await _tts.stop();
  }
}
