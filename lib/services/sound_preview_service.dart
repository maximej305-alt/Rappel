import 'package:audioplayers/audioplayers.dart';

import 'custom_sound_service.dart';

/// Lecteur d'aperçu des sons de notification.
///
/// Joue immédiatement le son sélectionné, stoppe le précédent, et peut être
/// arrêté à la sortie d'un écran. Instance unique réutilisée (pas de fuite :
/// [dispose] est appelé à la fermeture de l'app).
class SoundPreviewService {
  SoundPreviewService._();

  static final SoundPreviewService instance = SoundPreviewService._();

  AudioPlayer? _player;
  bool _playing = false;
  String? _currentId;

  /// Rejoue le son identifié par [soundId] (`chime1`, `custom://file://...`…).
  /// Stoppe d'abord un éventuel aperçu en cours, puis retourne `false` si le
  /// son est inconnu (aucun son joué).
  Future<bool> play(String soundId) async {
    final source = _sourceFor(soundId);
    if (source == null) return false;
    // Un fichier custom supprimé ne doit pas déclencher d'aperçu silencieux.
    if (CustomSoundService.isCustom(soundId) &&
        !CustomSoundService.fileExists(soundId)) {
      return false;
    }

    if (_playing && _currentId != soundId) {
      await _player?.stop();
      _playing = false;
    }

    _player ??= AudioPlayer();
    await _player!.stop();
    // mediaPlayer est le mode le plus compatible (Android comme iOS), et le
    // plus fiable sur les anciens appareils (« lowLatency » est Android-only).
    await _player!.play(source, mode: PlayerMode.mediaPlayer);
    _playing = true;
    _currentId = soundId;
    return true;
  }

  /// Arrête l'aperçu en cours (ex. sortie de l'écran, changement de son).
  Future<void> stop() async {
    if (!_playing) return;
    await _player?.stop();
    _playing = false;
    _currentId = null;
  }

  bool get isPlaying => _playing;

  /// Sources connues : les sons intégrés sont des assets Flutter, les sons
  /// personnalisés sont des fichiers locaux (`custom://<path>`).
  Source? _sourceFor(String soundId) {
    if (soundId.startsWith('custom://')) {
      final path = soundId.replaceFirst('custom://', '');
      final uri = Uri.tryParse(path);
      if (uri == null) return null;
      return DeviceFileSource(uri.toFilePath());
    }
    return switch (soundId) {
      'chime1' => AssetSource('sounds/chime1.wav'),
      'chime2' => AssetSource('sounds/chime2.wav'),
      'beep' => AssetSource('sounds/beep.wav'),
      'bell' => AssetSource('sounds/bell.wav'),
      'whistle' => AssetSource('sounds/whistle.wav'),
      // Sons système : pas de fichier local → aperçu via un son intégré.
      'default' => AssetSource('sounds/chime1.wav'),
      'alarm' => AssetSource('sounds/beep.wav'),
      _ => null,
    };
  }

  /// À appeler quand l'application se ferme pour libérer le lecteur.
  Future<void> dispose() async {
    await stop();
    await _player?.dispose();
    _player = null;
  }
}

/// Version fichier locale (utilisée dans les tests).
extension SoundPreviewServiceTest on SoundPreviewService {
  String? sourceFor(String soundId) => _sourceFor(soundId)?.toString();
}

/// Vérifie qu'un fichier local existe (utilisé en test).
bool soundFileExists(String soundId) => CustomSoundService.fileExists(soundId);
