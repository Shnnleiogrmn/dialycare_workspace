import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:core_shared/core_shared.dart';

import '../firebase_options.dart';
import '../screens/staff_portal.dart';
import 'staff_login.dart';
import '../services/staff_store.dart';

class CloudWorkspace extends StatefulWidget {
  const CloudWorkspace({super.key});
  @override
  State<CloudWorkspace> createState() => _CloudWorkspaceState();
}

class _CloudWorkspaceState extends State<CloudWorkspace> {
  final email = TextEditingController(), password = TextEditingController();
  late final identity = PasswordIdentity(DefaultFirebaseOptions.windows.apiKey);
  late final api = FirestoreRepository(
    token: identity.idToken,
    uid: () => identity.uid ?? '',
  );
  StaffStore? store;
  int revision = 0;
  bool busy = false;
  String? error;
  Timer? timer;
  bool refreshing = false;
  Future<void> login() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await identity.signIn(email.text.trim(), password.text);
      final initial = await api.call('staffData');
      revision = initial['revision'] as int;
      var first = true;
      late final StaffStore cloud;
      cloud = StaffStore(
        shared: true,
        concerns: FirestoreConcernService(api),
        history: FirestoreHistoryService(api),
        saveCenterInformation: api.saveCenterInformation,
        readAuditEvents: api.loadAuditEvents,
        readSessionEvents: api.sessionHistory,
        issueActivation: (role, pid, rid) =>
            api.issueActivation(role: role, patientId: pid, recipientId: rid),
        cancelMobileAccess: (role, rid) =>
            api.cancelMobileAccess(role: role, recipientId: rid),
        changeMobileAccess: (role, rid, enabled) =>
            api.setMobileAccess(role: role, recipientId: rid, enabled: enabled),
        readData: () async {
          final data = first
              ? initial
              : await api.call('staffData', {'poll': true});
          first = false;
          revision = data['revision'] as int;
          return jsonEncode(data['bundle']);
        },
        writeData: (json) async {
          final response = await api.call('staffSave', {
            'revision': revision,
            'bundle': jsonDecode(json),
          });
          revision = response['revision'] as int;
          cloud.workspaceVersion = response['workspaceVersion'] as String?;
          if (response['sessions'] case final List sessions) {
            cloud.sessions = sessions
                .map(
                  (s) => SessionRecord.fromJson(
                    Map<String, dynamic>.from(s as Map),
                  ),
                )
                .toList();
          }
        },
      );
      // A new cloud workspace begins empty. Local demonstration data is never uploaded.
      cloud.patients = [];
      cloud.sessions = [];
      cloud.notifications = [];
      await cloud.load();
      if (cloud.loadError != null) {
        throw const BackendException('Unable to load the shared workspace.');
      }
      if (!mounted) {
        cloud.dispose();
        return;
      }
      cloud.addListener(() {
        if (!cloud.signedIn && store == cloud) disconnect();
      });
      setState(() => store = cloud);
      timer = Timer.periodic(const Duration(minutes: 1), (_) async {
        final lifecycle = WidgetsBinding.instance.lifecycleState;
        if (refreshing ||
            (lifecycle != null && lifecycle != AppLifecycleState.resumed) ||
            store?.signedIn != true) {
          return;
        }
        refreshing = true;
        try {
          await store?.refreshShared();
        } finally {
          refreshing = false;
        }
      });
    } catch (failure) {
      identity.signOut();
      if (mounted) {
        setState(
          () => error = failure is BackendException ? failure.message : 'Unable to reach Firebase. Check your internet connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void disconnect() {
    timer?.cancel();
    identity.signOut();
    final old = store;
    if (mounted) setState(() => store = null);
    WidgetsBinding.instance.addPostFrameCallback((_) => old?.dispose());
  }

  Future<void> recover() async {
    final address = TextEditingController(text: email.text);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Staff password'),
        content: TextField(
          controller: address,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Staff Email'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await identity.sendPasswordReset(address.text);
                if (context.mounted) {
                  Navigator.pop(context);
                  if (mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'If this account exists, password reset instructions have been sent.',
                        ),
                      ),
                    );
                  }
                }
              } on BackendException catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(e.message)));
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Recovery is unavailable. Check your connection.',
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text('Send reset email'),
          ),
        ],
      ),
    );
    address.dispose();
  }

  Future<void> invite() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mobile account setup'),
        content: const Text(
          'Save the Patient and designated Relative first. Open Patient Details → Mobile Access → Create Mobile Access. Give the generated Temporary PIN and center-issued ID directly to the approved person. They choose their own password in Mobile. Account recovery requires center verification and trusted administration; Staff/Admin accounts remain administrator-controlled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    api.close();
    identity.close();
    email.dispose();
    password.dispose();
    store?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (store != null) {
      return Column(
        children: [
          Material(
            color: const Color(0xffe4f6fa),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  const Expanded(child: Text('Shared care-center workspace')),
                  TextButton(
                    onPressed: () => store!.refreshShared(),
                    child: const Text('Refresh'),
                  ),
                  TextButton(
                    onPressed: invite,
                    child: const Text('Mobile account setup'),
                  ),
                  TextButton(
                    onPressed: disconnect,
                    child: const Text('Disconnect'),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: StaffPortal(store: store)),
        ],
      );
    }
    return StaffLogin(
      email: email,
      password: password,
      busy: busy,
      error: error,
      onLogin: login,
      onRecovery: recover,
    );
  }
}
