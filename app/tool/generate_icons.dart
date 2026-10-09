// Genera los iconos de la app (originales, sin herramientas externas):
//   dart run tool/generate_icons.dart
//
// - mipmap-*/ic_launcher.png            icono clásico (Android < 8)
// - mipmap-*/ic_launcher_foreground.png capa frontal del icono adaptativo
// - mipmap-*/ic_launcher_monochrome.png icono temático (Android 13+)
// - assets/branding/play_store_icon.png 512×512 para la ficha de Google Play
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const _brand = (0x4F, 0x46, 0xE5); // índigo
const _res = 'android/app/src/main/res';

void main() {
  const densities = {'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0, 'xxxhdpi': 4.0};
  for (final e in densities.entries) {
    final legacy = (48 * e.value).round();
    final adaptive = (108 * e.value).round();
    _write('$_res/mipmap-${e.key}/ic_launcher.png', _render(legacy, background: true, rounded: true, scale: 0.78));
    // Zona segura del icono adaptativo: 66 dp de 108 dp.
    _write('$_res/mipmap-${e.key}/ic_launcher_foreground.png', _render(adaptive, background: false, scale: 0.56));
    _write('$_res/mipmap-${e.key}/ic_launcher_monochrome.png', _render(adaptive, background: false, scale: 0.56));
  }
  Directory('assets/branding').createSync(recursive: true);
  _write('assets/branding/play_store_icon.png', _render(512, background: true, rounded: false, scale: 0.72));
  stdout.writeln('Iconos generados.');
}

/// Dibuja el icono con supermuestreo 4×4 (bordes suaves).
Uint8List _render(int size, {required bool background, bool rounded = false, required double scale}) {
  final pixels = Uint8List(size * size * 4);
  const samples = 4;
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      var bg = 0.0;
      var fg = 0.0;
      for (var sy = 0; sy < samples; sy++) {
        for (var sx = 0; sx < samples; sx++) {
          final u = (x + (sx + 0.5) / samples) / size;
          final v = (y + (sy + 0.5) / samples) / size;
          if (background && (!rounded || _insideRoundedSquare(u, v, 0.22))) bg++;
          // Coordenadas del dibujo centradas y escaladas.
          final cu = 0.5 + (u - 0.5) / scale;
          final cv = 0.5 + (v - 0.5) / scale;
          if (_clock(cu, cv)) fg++;
        }
      }
      bg /= samples * samples;
      fg /= samples * samples;
      final i = (y * size + x) * 4;
      if (background) {
        // Reloj blanco sobre fondo índigo.
        final alpha = bg;
        final mix = fg;
        pixels[i] = (_brand.$1 * (1 - mix) + 255 * mix).round();
        pixels[i + 1] = (_brand.$2 * (1 - mix) + 255 * mix).round();
        pixels[i + 2] = (_brand.$3 * (1 - mix) + 255 * mix).round();
        pixels[i + 3] = (255 * alpha).round();
      } else {
        // Capa frontal: reloj blanco sobre transparente.
        pixels[i] = 255;
        pixels[i + 1] = 255;
        pixels[i + 2] = 255;
        pixels[i + 3] = (255 * fg).round();
      }
    }
  }
  return _png(size, size, pixels);
}

bool _insideRoundedSquare(double u, double v, double r) {
  final dx = max(max(r - u, u - (1 - r)), 0.0);
  final dy = max(max(r - v, v - (1 - r)), 0.0);
  return dx * dx + dy * dy <= r * r;
}

/// Reloj despertador: aro, dos campanas, agujas y patas.
bool _clock(double u, double v) {
  const cx = 0.5, cy = 0.55;
  final d = sqrt(pow(u - cx, 2) + pow(v - cy, 2));
  if ((d - 0.30).abs() <= 0.045) return true; // aro
  for (final bx in [0.25, 0.75]) {
    final db = sqrt(pow(u - bx, 2) + pow(v - 0.24, 2));
    if (db <= 0.12 && d > 0.37) return true; // campanas
  }
  if (_capsule(u, v, cx, cy, cx, 0.38, 0.035)) return true; // aguja larga
  if (_capsule(u, v, cx, cy, 0.62, 0.62, 0.035)) return true; // aguja corta
  if (_capsule(u, v, 0.33, 0.82, 0.26, 0.91, 0.04)) return true; // patas
  if (_capsule(u, v, 0.67, 0.82, 0.74, 0.91, 0.04)) return true;
  return false;
}

bool _capsule(double px, double py, double ax, double ay, double bx, double by, double r) {
  final pax = px - ax, pay = py - ay, bax = bx - ax, bay = by - ay;
  final h = ((pax * bax + pay * bay) / (bax * bax + bay * bay)).clamp(0.0, 1.0);
  final dx = pax - bax * h, dy = pay - bay * h;
  return dx * dx + dy * dy <= r * r;
}

// ---------------------------------------------------------------- PNG mínimo

Uint8List _png(int width, int height, Uint8List rgba) {
  final raw = BytesBuilder();
  for (var y = 0; y < height; y++) {
    raw.addByte(0); // filtro "none"
    raw.add(rgba.sublist(y * width * 4, (y + 1) * width * 4));
  }
  final header = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8) // bits por canal
    ..setUint8(9, 6) // RGBA
    ..setUint8(10, 0)
    ..setUint8(11, 0)
    ..setUint8(12, 0);
  final out = BytesBuilder()
    ..add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    ..add(_chunk('IHDR', header.buffer.asUint8List()))
    ..add(_chunk('IDAT', ZLibCodec(level: 9).encode(raw.toBytes())))
    ..add(_chunk('IEND', const []));
  return out.toBytes();
}

List<int> _chunk(String type, List<int> data) {
  final typeBytes = type.codeUnits;
  final length = ByteData(4)..setUint32(0, data.length);
  final crc = ByteData(4)..setUint32(0, _crc32([...typeBytes, ...data]));
  return [...length.buffer.asUint8List(), ...typeBytes, ...data, ...crc.buffer.asUint8List()];
}

final _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

void _write(String path, Uint8List bytes) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes);
}
