// Configura los permisos de micrófono e internet en Android e iOS.
// Ejecutar UNA vez, después de `flutter create .`:
//
//   dart run tool/setup_platforms.dart
//
import 'dart:io';

void main() {
  _android();
  _androidMinSdk();
  _ios();
  stdout.writeln('\nListo. Ya podés ejecutar: flutter run --dart-define-from-file=env.json');
}

void _android() {
  final f = File('android/app/src/main/AndroidManifest.xml');
  if (!f.existsSync()) {
    stdout.writeln('⚠ No encontré $f. ¿Ejecutaste "flutter create ." antes?');
    return;
  }
  var xml = f.readAsStringSync();
  const perms = [
    'android.permission.INTERNET',
    'android.permission.RECORD_AUDIO',
  ];
  final missing = perms.where((p) => !xml.contains(p)).toList();
  if (missing.isEmpty) {
    stdout.writeln('✓ Android: permisos ya configurados');
    return;
  }
  final lines =
      missing.map((p) => '    <uses-permission android:name="$p"/>').join('\n');
  xml = xml.replaceFirst('<application', '$lines\n    <application');
  f.writeAsStringSync(xml);
  stdout.writeln('✓ Android: agregué ${missing.join(', ')}');
}

void _androidMinSdk() {
  for (final path in ['android/app/build.gradle.kts', 'android/app/build.gradle']) {
    final f = File(path);
    if (!f.existsSync()) continue;
    var src = f.readAsStringSync();
    final updated = src
        .replaceAll('minSdk = flutter.minSdkVersion', 'minSdk = 23')
        .replaceAll('minSdkVersion flutter.minSdkVersion', 'minSdkVersion 23');
    if (updated != src) {
      f.writeAsStringSync(updated);
      stdout.writeln('✓ Android: minSdk = 23 (lo pide el paquete de grabación)');
    } else {
      stdout.writeln('✓ Android: minSdk sin cambios (revisá que sea 23 o más)');
    }
    return;
  }
}

void _ios() {
  final f = File('ios/Runner/Info.plist');
  if (!f.existsSync()) {
    stdout.writeln('⚠ No encontré $f (normal si no vas a compilar para iPhone).');
    return;
  }
  var plist = f.readAsStringSync();
  if (plist.contains('NSMicrophoneUsageDescription')) {
    stdout.writeln('✓ iOS: permiso de micrófono ya configurado');
    return;
  }
  plist = plist.replaceFirst(
    '<dict>',
    '<dict>\n\t<key>NSMicrophoneUsageDescription</key>\n'
        '\t<string>SpeakRead usa el micrófono para escuchar tu lectura en voz alta y corregir tu pronunciación.</string>',
  );
  f.writeAsStringSync(plist);
  stdout.writeln('✓ iOS: agregué NSMicrophoneUsageDescription');
}
