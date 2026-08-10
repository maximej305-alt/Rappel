import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const int sampleRate = 22050;

void main() {
  final outDir = Directory('android/app/src/main/res/raw');
  outDir.createSync(recursive: true);

  final tones = <String, List<double>>{
    'chime1': _chime1(),
    'chime2': _chime2(),
    'beep': _beep(),
    'bell': _bell(),
    'whistle': _whistle(),
  };

  for (final entry in tones.entries) {
    final file = File('${outDir.path}/${entry.key}.wav');
    file.writeAsBytesSync(_wav(entry.value));
    stdout.writeln('${file.path} (${file.lengthSync()} bytes)');
  }
}

List<double> _sine(double freq, double start, double dur, double amp) {
  final n = (dur * sampleRate).round();
  final out = List<double>.filled(n, 0);
  for (var i = 0; i < n; i++) {
    final t = start + i / sampleRate;
    // enveloppe douce : attack + decay
    final env = min(1.0, i / (0.02 * sampleRate)) *
        min(1.0, (n - i) / (0.12 * sampleRate));
    out[i] = amp * env * sin(2 * pi * freq * t);
  }
  return out;
}

List<double> _concat(List<List<double>> parts) =>
    [for (final p in parts) ...p];

double _bellEnv(int i, int n) {
  // decay exponentiel type cloche
  return exp(-3.2 * i / n) * min(1.0, i / (0.01 * sampleRate));
}

List<double> _chime1() {
  // ding-dong : 660 puis 880
  final a = _sine(660, 0, 0.55, 0.5);
  final b = _sine(880, 0.6, 0.65, 0.5);
  final gap = List<double>.filled((0.05 * sampleRate).round(), 0);
  return _concat([a, gap, b]);
}

List<double> _chime2() {
  // arpège ascendant DO MI SOL
  return _concat([
    _sine(523.25, 0, 0.32, 0.45),
    _sine(659.25, 0.36, 0.32, 0.45),
    _sine(783.99, 0.72, 0.5, 0.45),
  ]);
}

List<double> _beep() {
  // bip bip
  return _concat([
    _sine(1000, 0, 0.28, 0.5),
    List<double>.filled((0.18 * sampleRate).round(), 0),
    _sine(1000, 0.46, 0.28, 0.5),
  ]);
}

List<double> _bell() {
  final n = (1.3 * sampleRate).round();
  final out = List<double>.filled(n, 0);
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    out[i] = 0.55 *
        _bellEnv(i, n) *
        (sin(2 * pi * 880 * t) +
            0.35 * sin(2 * pi * 1320 * t) +
            0.18 * sin(2 * pi * 1760 * t));
  }
  return out;
}

List<double> _whistle() {
  final n = (1.0 * sampleRate).round();
  final out = List<double>.filled(n, 0);
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    final freq = 800 + 900 * (i / n); // monte de 800 à 1700 Hz
    final env = min(1.0, i / (0.03 * sampleRate)) *
        min(1.0, (n - i) / (0.15 * sampleRate));
    out[i] = 0.5 * env * sin(2 * pi * freq * t);
  }
  return out;
}

Uint8List _wav(List<double> samples) {
  final dataSize = samples.length * 2;
  final bytes = BytesBuilder();

  void str(String s) => bytes.add(s.codeUnits);
  void u32(int v) => bytes.add(Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little));
  void u16(int v) => bytes.add(Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.little));

  str('RIFF');
  u32(36 + dataSize);
  str('WAVE');
  str('fmt ');
  u32(16);
  u16(1); // PCM
  u16(1); // mono
  u32(sampleRate);
  u32(sampleRate * 2); // byte rate
  u16(2); // block align
  u16(16); // bits
  str('data');
  u32(dataSize);
  for (final s in samples) {
    final v = (s.clamp(-1.0, 1.0) * 32767).round();
    u16(v & 0xFFFF);
  }
  return bytes.toBytes();
}
