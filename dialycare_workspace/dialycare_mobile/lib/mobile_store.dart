import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:core_shared/core_shared.dart';

import 'firebase_options.dart';

class MobileStore extends ChangeNotifier {
  MobileStore({this.testApi});
  bool _disposed = false;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  final BackendClient? testApi;
  late final FirestoreRepository repository = FirestoreRepository(
    token: () async => FirebaseAuth.instance.currentUser?.getIdToken(),
    uid: () => FirebaseAuth.instance.currentUser?.uid ?? '',
  );
  BackendClient get api => testApi ?? repository;
  String role = 'patient';
  Map<String, dynamic>? profile;
  List<SessionRecord> sessions = [];
  List<Map<String, dynamic>> notifications = [];
  bool busy = false, ready = false;
  String? error, pushNotice;
  Timer? _timer;
  int _generation = 0;
  int get unread => notifications.where((n) => n['readAt'] == null).length;
  Future<void>? _initializing;
  bool _refreshing = false;
  void _startRefreshTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle == null || lifecycle == AppLifecycleState.resumed) {
        refresh(background: true);
      }
    });
  }

  Future<void> initialize() =>
      _initializing ??= _initialize().whenComplete(() => _initializing = null);
  Future<void> _initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      ready = true;
      await _discardTemporaryIdentity();
      if (FirebaseAuth.instance.currentUser != null) {
        await FirebaseAuth.instance.currentUser!.reload();
        await refresh(rethrowError: true, validateRole: false);
        _startRefreshTimer();
        await registerPush();
      }
    } on FirebaseAuthException catch (failure) {
      if ([
        'user-token-expired',
        'invalid-user-token',
        'user-disabled',
        'user-not-found',
      ].contains(failure.code)) {
        await FirebaseAuth.instance.signOut();
        error = 'Please sign in again with your center-issued ID.';
      } else {
        error = 'Unable to connect to your care center. Check your connection and try again.';
      }
    } catch (failure) {
      error = failure is BackendException ? failure.message : 'Unable to connect to your care center. Check your connection and try again.';
    }
    _notify();
  }

  Future<void> login(String id, String password) async {
    await action(() async {
      if (!ready) await initialize();
      if (!ready) {
        throw const BackendException(
          'The care center connection is unavailable.',
        );
      }
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: accountEmail(role, id),
        password: password,
      );
      try {
        await refresh(rethrowError: true);
      } catch (_) {
        await FirebaseAuth.instance.signOut();
        rethrow;
      }
      _timer?.cancel();
      _startRefreshTimer();
      await registerPush();
    });
  }

  Map<String, dynamic>? activationPreview;
  bool activationPending = false;
  bool termsAccepted = false, privacyAcknowledged = false;
  String _temporaryUid = '';
  Future<void>? _temporaryCleanup;

  Future<void> _discardTemporaryIdentity() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null &&
        (user.uid == _temporaryUid ||
            user.email?.endsWith('@activation.dialycare.invalid') == true)) {
      try {
        await user.delete();
      } catch (_) {
        /* Unlinked helper identities need trusted cleanup if offline. */
      }
      if (FirebaseAuth.instance.currentUser?.uid == user.uid) {
        await FirebaseAuth.instance.signOut();
      }
    }
    if (user?.uid == _temporaryUid) _temporaryUid = '';
  }

  Future<void> beginActivation(String id, String pin) => action(() async {
    final code = pinInvitationId(role, id, pin);
    if (!ready) await initialize();
    if (!ready) {
      throw const BackendException(
        'The care center connection is unavailable.',
      );
    }
    await cancelActivation();
    _generation++;
    _timer?.cancel();
    // Email/password Auth supplies an unlinked verification session without
    // requiring an inbox or enabling another provider. This is not a care role.
    final random = Random.secure();
    String secret() => base64Url
        .encode(List.generate(32, (_) => random.nextInt(256)))
        .replaceAll('=', '');
    final created = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: 'verify-${secret().toLowerCase()}@activation.dialycare.invalid',
      password: secret(),
    );
    _temporaryUid = created.user!.uid;
    activationPending = true;
    try {
      activationPreview = await repository.verifyActivation(
        code: code,
        role: role,
        recipientId: id.trim(),
      );
    } catch (_) {
      await cancelActivation();
      rethrow;
    }
  });

  Future<void> completeActivation(String password) => action(() async {
    if (!termsAccepted || !privacyAcknowledged) {
      throw const BackendException(
        'Agree to the Terms of Use and acknowledge the Privacy Notice.',
      );
    }
    final preview = activationPreview;
    if (preview == null) {
      throw const BackendException('Verify your ID and Temporary PIN first.');
    }
    final passwordError = validateMobilePassword(password);
    if (passwordError != null) throw BackendException(passwordError);
    await _discardTemporaryIdentity();
    final identifier = accountEmail(
      role,
      (preview['publicId'] ?? preview['recipientId']) as String,
    );
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: identifier,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code != 'email-already-in-use') rethrow;
      // An interrupted setup can resume only with its owner's chosen password.
      // Never reset or take over another UID through the client.
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: identifier,
        password: password,
      );
    }
    final existing = await repository.get(
      'users/${FirebaseAuth.instance.currentUser!.uid}',
    );
    if (existing == null) {
      await repository.claimActivation(
        preview,
        termsAccepted: termsAccepted,
        privacyAcknowledged: privacyAcknowledged,
      );
    } else {
      final owner = repository.data(existing);
      if (owner['role'] != role ||
          owner['recipientId'] != preview['recipientId'] ||
          owner['activationId'] != preview['code']) {
        throw const BackendException(
          'This ID already has an account. Log in with its password or contact your dialysis center for recovery.',
        );
      }
    }
    await refresh(rethrowError: true);
    activationPending = false;
    activationPreview = null;
    termsAccepted = false;
    privacyAcknowledged = false;
    _timer?.cancel();
    _startRefreshTimer();
  });

  Future<void> cancelActivation() {
    activationPending = false;
    activationPreview = null;
    termsAccepted = false;
    privacyAcknowledged = false;
    if (!ready) return Future<void>.value();
    return _temporaryCleanup ??= _discardTemporaryIdentity().whenComplete(
      () => _temporaryCleanup = null,
    );
  }

  Future<void> action(Future<void> Function() operation) async {
    if (busy) return;
    busy = true;
    error = null;
    _notify();
    try {
      await operation();
    } on FirebaseAuthException catch (e) {
      error = switch (e.code) {
        'invalid-email' => 'Enter the center-issued ID exactly as provided.',
        'weak-password' =>
          'Choose a stronger password with at least 8 characters.',
        'too-many-requests' =>
          'Too many attempts. Please wait a moment before trying again.',
        'network-request-failed' =>
          'Unable to reach Firebase. Check your connection and try again.',
        'user-disabled' => 'Your DialyCare access is currently disabled. Please contact your dialysis center.',
        'user-token-expired' ||
        'invalid-user-token' ||
        'requires-recent-login' =>
          'Your session expired. Please sign in again.',
        _ => 'Unable to sign in or set up this ID. Check your credentials, or contact your dialysis center for account recovery.',
      };
    } on BackendException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Unable to complete this request. Check your connection and try again.';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> refresh({
    bool rethrowError = false,
    bool validateRole = true,
    bool background = false,
  }) async {
    if (_refreshing) {
      if (rethrowError) {
        throw const BackendException(
          'An update is already in progress. Please try again.',
        );
      }
      return;
    }
    _refreshing = true;
    final generation = _generation;
    try {
      final data = await api.call('mobileData', {
        'poll': background,
        if (validateRole) 'role': role,
      });
      if (generation != _generation) return;
      final nextProfile = Map<String, dynamic>.from(data['profile'] as Map);
      for (final key in ['name', 'patientId', 'patientName', 'role']) {
        if (nextProfile[key] is! String) {
          throw const FormatException('Invalid account profile');
        }
      }
      if (!['patient', 'relative'].contains(nextProfile['role'])) {
        throw const FormatException('Invalid role');
      }
      final nextSessions =
          (data['sessions'] as List)
              .map(
                (s) =>
                    SessionRecord.fromJson(Map<String, dynamic>.from(s as Map)),
              )
              .toList()
            ..sort((a, b) => a.start.compareTo(b.start));
      final nextNotifications = (data['notifications'] as List)
          .map((n) => Map<String, dynamic>.from(n as Map))
          .toList();
      for (final item in nextNotifications) {
        for (final key in ['id', 'title', 'message', 'type']) {
          if (item[key] is! String) {
            throw const FormatException('Invalid notification');
          }
        }
      }
      profile = nextProfile;
      role = nextProfile['role'] as String;
      sessions = nextSessions;
      notifications = nextNotifications;
      error = null;
    } catch (e) {
      if (e is BackendException &&
          (e.statusCode == 401 || e.statusCode == 403)) {
        profile = null;
        sessions = [];
        notifications = [];
        _timer?.cancel();
      }
      if (rethrowError) rethrow;
      error = e is BackendException ? e.message : 'Unable to refresh your information. Check your connection and try again.';
    } finally {
      _refreshing = false;
    }
    _notify();
  }

  Future<void> readNotification(String id) => action(() async {
    await api.call('readNotification', {'id': id});
    await refresh();
  });
  Future<void> registerPush() async {
    // Spark: persisted in-app notifications are active; no privileged push sender.
    pushNotice = null;
  }

  Future<void> changePassword(String current, String next) => action(() async {
    final passwordError = validateMobilePassword(next);
    if (passwordError != null) throw BackendException(passwordError);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      throw const BackendException('Please log in again.');
    }
    await user.reload();
    final refreshed = FirebaseAuth.instance.currentUser;
    final refreshedEmail = refreshed?.email;
    if (refreshed == null || refreshedEmail == null) {
      throw const BackendException('Please log in again.');
    }
    await refreshed.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: refreshedEmail, password: current),
    );
    await refreshed.updatePassword(next);
  });
  Future<void> logout() async {
    await action(() async {
      _generation++;
      _timer?.cancel();
      await FirebaseAuth.instance.signOut();
      profile = null;
      sessions = [];
      notifications = [];
      pushNotice = null;
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    if (testApi == null) repository.close();
    super.dispose();
  }
}
