import 'dart:io';

class LocalStorage {
  File get _file {
    final root =
        Platform.environment['APPDATA'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;
    return File(
      '$root${Platform.pathSeparator}DialyCare${Platform.pathSeparator}Staff${Platform.pathSeparator}workspace.json',
    );
  }

  Future<String?> read() async {
    final file = _file;
    if (!await file.exists()) {
      return null;
    }
    return file.readAsString();
  }

  Future<void> write(String value) async {
    final file = _file;
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(value, flush: true);
    await temporary.rename(file.path);
  }
}
