# DialyCare Core Shared

Shared `SessionStatus`, `SessionRecord`, authenticated backend client, account-ID normalization and in-memory Staff Firebase identity adapter. Staff re-exports the shared session model from its existing import path. Mobile consumes the same definition directly.

Session JSON retains the original field names and status labels. New timestamps are serialized in UTC and normalized to local display time on read; legacy local timestamp strings remain readable. Neither app stores server credentials in this package.

Run `flutter pub get`, `flutter analyze`, and `flutter test` from this folder. This package is not a runnable application.
