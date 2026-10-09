// Genera los sonidos de alarma incluidos en la app (originales, sin licencias
// de terceros): `dart run tool/generate_sounds.dart`.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const sampleRate = 22050;

void main() {
  // Clásico: pitido doble agudo.
  _write('assets/sounds/classic.wav', _pattern([
    (880, 0.12), (0, 0.06), (880, 0.12), (0, 0.6),
  ], repeat: 3));
  // Suave: arpegio ascendente con atenuación.
  _write('assets/sounds/soft.wav', _pattern([
    (523.25, 0.25), (659.25, 0.25), (783.99, 0.35), (0, 0.65),
  ], repeat: 2, volume: 0.45));
  stdout.writeln('Sonidos generados en assets/sounds/');
}

List<double> _pattern(List<(double, double)> notes, {int repeat = 1, double volume = 0.7}) {
  final samples = <double>[];
  for (var r = 0; r < repeat; r++) {
    for (final (freq, seconds) in notes) {
      final count = (seconds * sampleRate).round();
      for (var i = 0; i < count; i++) {
        if (freq == 0) {
          samples.add(0);
          continue;
        }
        // Envolvente para evitar chasquidos.
        final attack = min(1.0, i / (0.01 * sampleRate));
        final release = min(1.0, (count - i) / (0.03 * sampleRate));
        final t = i / sampleRate;
        samples.add(volume * attack * release * sin(2 * pi * freq * t));
      }
    }
  }
  return samples;
}

void _write(String path, List<double> samples) {
  final data = ByteData(44 + samples.length * 2);
  void ascii(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + samples.length * 2, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little); // PCM
  data.setUint16(22, 1, Endian.little); // mono
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, samples.length * 2, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(44 + i * 2, (samples[i].clamp(-1.0, 1.0) * 32767).round(), Endian.little);
  }
  File(path).writeAsBytesSync(data.buffer.asUint8List());
}
