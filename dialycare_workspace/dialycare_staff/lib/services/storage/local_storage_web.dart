import 'dart:js_interop';

@JS('localStorage')
external BrowserStorage get _storage;

@JS()
extension type BrowserStorage(JSObject _) implements JSObject {
  external String? getItem(String key);
  external void setItem(String key, String value);
}

class LocalStorage {
  Future<String?> read() async =>
      _storage.getItem('dialycare.staff.workspace.v1');
  Future<void> write(String value) async =>
      _storage.setItem('dialycare.staff.workspace.v1', value);
}
