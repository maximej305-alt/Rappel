import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../models/sound_option.dart';

/// Importe et conserve un son choisi par l'utilisateur.
///
/// Le fichier est copié dans le dossier des documents de l'app
/// (`documents/sounds/<nom>`) puis référencé par l'URI
/// `custom://file:///...` lu par [NotificationService].
class CustomSoundService {
  CustomSoundService._();

  static const _soundsDirName = 'sounds';

  static const _audioTypeGroup = XTypeGroup(
    label: 'audio',
    extensions: ['mp3', 'm4a', 'aac', 'wav', 'ogg', 'amr', 'flac', '3gp'],
  );

  /// Identifie un son personnalisé (`true`).
  static bool isCustom(String soundId) => soundId.startsWith('custom://');

  /// `true` si le fichier référencé par un son personnalisé existe encore.
  static bool fileExists(String soundId) {
    if (!isCustom(soundId)) return false;
    final path = soundId.replaceFirst('custom://', '');
    final uri = Uri.tryParse(path);
    if (uri == null) return false;
    return File(uri.toFilePath()).existsSync();
  }

  /// Identifiant de son « sûr » : [soundId] s'il est jouable (son intégré ou
  /// fichier présent), sinon `default`. Garantit qu'un son custom supprimé
  /// ne conduit jamais à une notification silencieuse.
  static String fallbackSoundId(String soundId) {
    if (!isCustom(soundId)) return soundId;
    return fileExists(soundId) ? soundId : 'default';
  }

  /// Ouvre le sélecteur de fichiers audio, copie le fichier choisi dans le
  /// dossier de l'app et retourne l'option correspondante.
  /// Retourne `null` si l'utilisateur annule ou si le fichier est illisible.
  static Future<SoundOption?> pickAndImport() async {
    final result = await openFile(acceptedTypeGroups: [_audioTypeGroup]);
    if (result == null) return null;

    final path = result.path;
    final source = File(path);
    if (!await source.exists()) return null;

    final docs = await getApplicationDocumentsDirectory();
    final soundsDir = Directory('${docs.path}/$_soundsDirName');
    await soundsDir.create(recursive: true);

    final name = path.split(Platform.pathSeparator).last;
    final safeName =
        name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final destPath = '${soundsDir.path}/$safeName';
    await source.copy(destPath);

    final label = safeName.contains('.')
        ? safeName.substring(0, safeName.lastIndexOf('.'))
        : safeName;

    return SoundOption(
      id: 'custom://file://$destPath',
      label: label,
      icon: Icons.audiotrack,
    );
  }
}
