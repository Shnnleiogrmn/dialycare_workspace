import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:core_shared/core_shared.dart';

import 'mobile_store.dart';

const navy = Color(0xff0b3764),
    teal = Color(0xff43afc3),
    pale = Color(0xffdff8ff);
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DialyCareMobile());
}

class DialyCareMobile extends StatefulWidget {
  const DialyCareMobile({super.key, this.store});
  final MobileStore? store;
  @override
  State<DialyCareMobile> createState() => _DialyCareMobileState();
}

class _DialyCareMobileState extends State<DialyCareMobile> {
  late final store = widget.store ?? MobileStore();
  @override
  void initState() {
    super.initState();
    if (widget.store == null) store.initialize();
  }

  @override
  void dispose() {
    if (widget.store == null) store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'DialyCare',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: navy,
        primary: navy,
        secondary: teal,
      ),
      scaffoldBackgroundColor: Colors.white,
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? navy
                : Colors.black54,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.bold
                : FontWeight.normal,
            color: states.contains(WidgetState.selected)
                ? navy
                : Colors.black54,
          ),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xffbdcbd1), width: .7),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: navy),
        titleLarge: TextStyle(
          color: navy,
          fontWeight: FontWeight.bold,
          fontSize: 24,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xffeff6fa),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: Color(0xffd9e5ef)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: Color(0xffd9e5ef)),
        ),
      ),
    ),
    home: AnimatedBuilder(
      animation: store,
      builder: (context, _) => store.profile == null
          ? WelcomeScreen(store: store)
          : MobileShell(store: store),
    ),
  );
}

class Logo extends StatelessWidget {
  const Logo({super.key, this.size = 116});
  final double size;
  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/images/mobile-logo.png',
    width: size,
    height: size,
    fit: BoxFit.contain,
  );
}

class WaveBackground extends StatelessWidget {
  const WaveBackground({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xffb8d4e4), Color(0xffe8ecff), Color(0xff85b8dc)],
      ),
    ),
    child: CustomPaint(painter: WavePainter(), child: child),
  );
}

class WavePainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    for (var i = 0; i < 23; i++) {
      final p = Path()
        ..moveTo(s.width * .25 + i * 2, -15)
        ..cubicTo(
          s.width * .12,
          s.height * .18,
          s.width * .94,
          -s.height * .08,
          s.width + 20,
          s.height * .06 + i * 5,
        );
      final q = Path()
        ..moveTo(-40, s.height * .43 + i * 5)
        ..cubicTo(
          s.width * .7,
          s.height * .66,
          -s.width * .3,
          s.height * .91,
          s.width + 40,
          s.height * .78 + i * 5,
        );
      c.drawPath(
        p,
        Paint()
          ..color = teal.withValues(alpha: .5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .65,
      );
      c.drawPath(
        q,
        Paint()
          ..color = const Color(0xff32a8d5).withValues(alpha: .6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .75,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.store});
  final MobileStore store;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: WaveBackground(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 440),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 52,
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 45),
                      const Logo(size: 144),
                      const SizedBox(height: 10),
                      const Text(
                        'Stay on Schedule. Stay in Care.',
                        style: TextStyle(fontFamily: 'Georgia', fontSize: 17),
                      ),
                      const SizedBox(height: 78),
                      const Text(
                        'Welcome!',
                        style: TextStyle(
                          color: navy,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Choose how you will use this app.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.black87),
                      ),
                      const SizedBox(height: 36),
                      for (final role in ['patient', 'relative'])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: role == 'patient'
                                    ? navy
                                    : teal,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              icon: const Icon(Icons.person_outline, size: 26),
                              label: Text(
                                'I am a ${role == 'patient' ? 'Patient' : 'Relative'}',
                                style: const TextStyle(
                                  fontSize: 19,
                                  letterSpacing: 1,
                                ),
                              ),
                              onPressed: () async {
                                await store.cancelActivation();
                                if (!context.mounted) return;
                                store.role = role;
                                store.error = null;
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => AuthScreen(store: store),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.store});
  final MobileStore store;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final form = GlobalKey<FormState>();
  final id = TextEditingController(),
      password = TextEditingController(),
      pin = TextEditingController(),
      confirm = TextEditingController();
  bool registering = false, obscure = true;
  @override
  void dispose() {
    if (widget.store.profile == null) widget.store.cancelActivation();
    for (final c in [id, password, pin, confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    final s = widget.store;
    if (registering) {
      if (s.activationPreview == null) {
        await s.beginActivation(id.text, pin.text);
        if (s.activationPreview != null) pin.clear();
      } else {
        await s.completeActivation(password.text);
      }
    } else {
      await s.login(id.text, password.text);
    }
    if (mounted && s.profile != null) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  Future<void> recovery() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Account recovery'),
      content: const Text(
        'Please contact your dialysis center with your center-issued ID. The center must verify your identity and arrange secure account recovery. A new activation PIN cannot reset an activated password.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    ),
  );
  Widget field(
    TextEditingController c,
    String label,
    IconData icon, {
    bool secret = false,
    bool temporaryPin = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: c,
      obscureText: secret && obscure,
      autocorrect: false,
      enableSuggestions: !secret,
      keyboardType: temporaryPin ? TextInputType.number : TextInputType.text,
      inputFormatters: temporaryPin
          ? [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ]
          : null,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        hintText: c == id
            ? (widget.store.role == 'patient'
                  ? 'DP-${DateTime.now().year}-001'
                  : 'R-000001')
            : null,
        helperText: registering && c == password ? mobilePasswordHint : null,
        prefixIcon: Icon(icon),
        suffixIcon: secret
            ? IconButton(
                tooltip: obscure ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => obscure = !obscure),
                icon: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              )
            : null,
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Enter $label';
        if (temporaryPin && !RegExp(r'^\d{6}$').hasMatch(v)) {
          return 'Enter the six-digit Temporary PIN';
        }
        if (registering && secret) {
          final error = validateMobilePassword(v);
          if (error != null) return error;
        }
        if (c == confirm) return confirmMobilePassword(password.text, v);
        return null;
      },
    ),
  );
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final s = widget.store, preview = s.activationPreview;
      final idLabel = s.role == 'patient' ? 'Patient ID' : 'Relative ID';
      return Scaffold(
        appBar: AppBar(
          title: Text(s.role == 'patient' ? 'Patient' : 'Relative'),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(30, 16, 30, 32),
                child: Form(
                  key: form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: Logo()),
                      SizedBox(height: registering ? 24 : 56),
                      Text(
                        registering
                            ? (preview == null
                                  ? 'Activate Your Account'
                                  : 'Account Verified')
                            : 'Welcome Back!',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        registering
                            ? 'Use the access approved by your dialysis center.'
                            : 'Please log in with your center-issued ID and password.',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 28),
                      if (registering && preview != null) ...[
                        Text(
                          preview['displayName'] as String,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          '$idLabel: ${preview['publicId'] ?? centerIdLabel(preview['recipientId'] as String, s.role == 'patient' ? 'DC-' : 'R-')}',
                        ),
                        if (s.role == 'relative')
                          Text(
                            'Linked Patient ID: ${centerIdLabel((preview['patientPublicId'] ?? preview['patientId']) as String, 'DC-')}',
                          ),
                        const SizedBox(height: 16),
                        const Text('Create your DialyCare password.'),
                        const SizedBox(height: 16),
                        field(
                          password,
                          'New Password',
                          Icons.lock_outline,
                          secret: true,
                        ),
                        field(
                          confirm,
                          'Confirm Password',
                          Icons.lock_outline,
                          secret: true,
                        ),
                        TextButton(
                          onPressed: () =>
                              showPolicyDocument(context, privacy: false),
                          child: const Text('View Terms of Use'),
                        ),
                        CheckboxListTile(
                          key: const ValueKey('terms-agreement'),
                          contentPadding: EdgeInsets.zero,
                          value: s.termsAccepted,
                          onChanged: s.busy
                              ? null
                              : (value) => setState(
                                  () => s.termsAccepted = value ?? false,
                                ),
                          title: const Text('I agree to the Terms of Use'),
                        ),
                        TextButton(
                          onPressed: () =>
                              showPolicyDocument(context, privacy: true),
                          child: const Text('View Privacy Notice'),
                        ),
                        CheckboxListTile(
                          key: const ValueKey('privacy-acknowledgment'),
                          contentPadding: EdgeInsets.zero,
                          value: s.privacyAcknowledged,
                          onChanged: s.busy
                              ? null
                              : (value) => setState(
                                  () => s.privacyAcknowledged = value ?? false,
                                ),
                          title: const Text(
                            'I acknowledge that I have read the Privacy Notice',
                          ),
                        ),
                        const Text(
                          'Please read both documents. Privacy acknowledgment is separate from consent to medical processing.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ] else ...[
                        field(id, idLabel, Icons.person_outline),
                        if (registering) ...[
                          field(
                            pin,
                            'Temporary PIN',
                            Icons.pin_outlined,
                            temporaryPin: true,
                          ),
                          const Text(
                            'Use the six-digit PIN given directly by your center. This is for first-time activation only.',
                          ),
                        ] else ...[
                          field(
                            password,
                            'Password',
                            Icons.lock_outline,
                            secret: true,
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: s.busy ? null : recovery,
                              child: const Text('Forgot Password?'),
                            ),
                          ),
                        ],
                      ],
                      if (s.error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            s.error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 49,
                        child: FilledButton(
                          onPressed:
                              s.busy ||
                                  (registering &&
                                      preview != null &&
                                      (!s.termsAccepted ||
                                          !s.privacyAcknowledged))
                              ? null
                              : submit,
                          child: Text(
                            s.busy
                                ? (!registering
                                      ? 'Logging In…'
                                      : preview == null
                                      ? 'Verifying…'
                                      : 'Activating…')
                                : !registering
                                ? 'Log In'
                                : preview == null
                                ? 'Verify Account'
                                : 'Activate Account',
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      if (!registering)
                        const Text(
                          'First time using DialyCare?',
                          textAlign: TextAlign.center,
                        ),
                      OutlinedButton(
                        onPressed: s.busy
                            ? null
                            : () async {
                                await s.cancelActivation();
                                if (!mounted) return;
                                s.error = null;
                                pin.clear();
                                password.clear();
                                confirm.clear();
                                setState(() => registering = !registering);
                              },
                        child: Text(
                          registering
                              ? 'Already activated? Log In'
                              : 'Activate Account',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class MobileShell extends StatefulWidget {
  const MobileShell({super.key, required this.store});
  final MobileStore store;
  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> {
  int page = 0, filter = 0, notificationFilter = 0;
  MobileStore get s => widget.store;
  void go(int index) => setState(() {
    page = index;
  });
  void openSecondary(String title, Widget Function(StateSetter) screen) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => StatefulBuilder(
          builder: (context, update) => AnimatedBuilder(
            animation: s,
            builder: (context, _) => Scaffold(
              appBar: AppBar(title: Text(title)),
              body: SafeArea(
                child: Column(
                  children: [
                    if (s.error != null)
                      MaterialBanner(
                        content: Text(s.error!),
                        actions: [
                          TextButton(
                            onPressed: () => s.refresh(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: s.refresh,
                        child: screen(update),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void openNotifications() =>
      openSecondary('Notifications', (update) => notificationList(update));
  String date(DateTime d) => DateFormat('EEE, MMM d, yyyy').format(d.toLocal());
  String time(DateTime d) => DateFormat('h:mm a').format(d.toLocal());
  Widget badge() => Badge(
    isLabelVisible: s.unread > 0,
    label: Text('${s.unread}'),
    child: const Icon(Icons.notifications_outlined),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xfff7fcfd),
    appBar: page != 3
        ? null
        : AppBar(
            centerTitle: true,
            title: Text(
              'More',
              style: const TextStyle(fontWeight: FontWeight.bold, color: navy),
            ),
            backgroundColor: Colors.white,
            elevation: 2,
          ),
    body: SafeArea(
      child: Column(
        children: [
          if (s.error != null)
            MaterialBanner(
              content: Text(s.error!),
              actions: [
                TextButton(
                  onPressed: () => s.refresh(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          Expanded(
            child: IndexedStack(
              index: page,
              children: [
                RefreshIndicator(onRefresh: s.refresh, child: home()),
                if (page == 1)
                  FeedbackConcernsPage(service: s.concerns)
                else
                  const SizedBox(),
                if (page == 2)
                  ActivityHistoryPage(service: s.history)
                else
                  const SizedBox(),
                RefreshIndicator(onRefresh: s.refresh, child: profile()),
              ],
            ),
          ),
        ],
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: page,
      onDestinationSelected: go,
      backgroundColor: Colors.white,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected) ? navy : Colors.black54,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.bold
              : FontWeight.normal,
          fontSize: 12,
        ),
      ),
      indicatorColor: Colors.transparent,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        const NavigationDestination(
          icon: Icon(Icons.feedback_outlined),
          selectedIcon: Icon(Icons.feedback, color: navy),
          label: 'Feedback',
        ),
        const NavigationDestination(
          icon: Icon(Icons.history),
          selectedIcon: Icon(Icons.history, color: navy),
          label: 'History',
        ),
        const NavigationDestination(
          icon: Icon(Icons.more_horiz),
          label: 'More',
        ),
      ],
    ),
  );
  Widget heading(String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Text(
      value,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    ),
  );
  Widget home() {
    final now = DateTime.now();
    final next = nextDialysisSession(s.sessions, now);
    final current = currentDialysisSession(s.sessions, now);
    final recent = s.notifications.firstOrNull;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          date(now),
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            PersonAvatar(
              gender: s.role == 'patient'
                  ? (s.profile?['gender'] as String?)
                  : null,
              size: 58,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    now.hour < 12
                        ? 'Good Morning.'
                        : now.hour < 18
                        ? 'Good Afternoon.'
                        : 'Good Evening.',
                  ),
                  Text(
                    s.profile!['name'] as String,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${s.role == 'patient' ? 'Patient' : 'Relative'} ID: ${s.profile!['accountId'] ?? s.profile!['patientId']}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  if (ScheduleGroup.parse(s.profile!['scheduleGroup'])
                      case final group?)
                    Text(
                      '${group.label} • ${group.daysLabel}',
                      style: const TextStyle(fontSize: 11),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Open notifications',
              onPressed: openNotifications,
              icon: badge(),
            ),
          ],
        ),
        if (s.role == 'relative') ...[
          const SizedBox(height: 18),
          Card(
            color: pale,
            child: ListTile(
              leading: const Icon(Icons.person_outline, color: navy),
              title: Text(
                s.profile!['patientName'] as String,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Your linked Patient\nPatient ID: ${s.profile!['patientId']}',
              ),
            ),
          ),
        ],
        if (s.role == 'relative' &&
            current?.status == SessionStatus.readyForPickUp) ...[
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: Card(
              color: sessionStatusBackground(SessionStatus.readyForPickUp),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'READY FOR PICK UP',
                      style: TextStyle(
                        fontSize: 18,
                        color: navy,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('${s.profile!['patientName']} is ready for pick up.'),
                    Text(
                      '${date(current!.start)} • ${time(current.start)} • ${current.room}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        heading('Next Dialysis'),
        if (next == null)
          empty('No upcoming dialysis session is currently scheduled.')
        else
          sessionCard(next),
        FilledButton.icon(
          onPressed: () =>
              openSecondary('Schedule', (update) => schedule(update)),
          icon: const Icon(Icons.calendar_month_outlined),
          label: const Text('View Schedule'),
        ),
        heading('Current Session'),
        if (current == null)
          empty('No session status is available today.')
        else
          Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${date(current.start)} • ${time(current.start)}'),
                  Text('${current.room} • ${current.batch}'),
                  const SizedBox(height: 12),
                  status(current.status),
                  const SizedBox(height: 12),
                  SessionProgress(session: current),
                  const SizedBox(height: 16),
                  sessionTimeline(current.status),
                ],
              ),
            ),
          ),
        heading('Recent Notification'),
        if (recent == null)
          empty('No notifications yet.')
        else
          Card(
            color: Colors.white,
            child: ListTile(
              leading: const Icon(Icons.notifications_outlined, color: navy),
              title: Text(
                recent['title'] as String,
                style: TextStyle(
                  fontWeight: recent['readAt'] == null
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
              subtitle: Text(
                recent['message'] as String,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: openNotifications,
            ),
          ),
        TextButton(
          onPressed: openNotifications,
          child: const Text('View Notifications'),
        ),
        if (s.pushNotice != null)
          Text(s.pushNotice!, style: const TextStyle(color: Colors.black54)),
      ],
    );
  }

  Widget sessionTimeline(SessionStatus current) {
    final states = [
      SessionStatus.pending,
      SessionStatus.inProgress,
      SessionStatus.completed,
      if (s.role == 'relative' || current == SessionStatus.readyForPickUp)
        SessionStatus.readyForPickUp,
    ];
    if (!states.contains(current)) states.add(current);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Status overview',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in states)
              Chip(
                avatar: Icon(
                  value == current
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 16,
                  color: value == current
                      ? sessionStatusForeground(value)
                      : Colors.grey,
                ),
                backgroundColor: value == current
                    ? sessionStatusBackground(value)
                    : const Color(0xFFF5F7FA),
                label: Text(
                  value.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: value == current
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
          ],
        ),
        const Text(
          'Current status is highlighted.',
          style: TextStyle(fontSize: 11, color: Colors.black54),
        ),
      ],
    );
  }

  Widget quick(String text, IconData icon, VoidCallback tap, Color color) =>
      Material(
        color: color,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: tap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
            child: Column(
              children: [
                Icon(icon, size: 30, color: navy),
                const SizedBox(height: 6),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      );
  Widget sessionCard(SessionRecord v) => Card(
    color: Colors.white,
    elevation: 2,
    margin: const EdgeInsets.only(bottom: 16),
    child: InkWell(
      onTap: () => details(v),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.calendar_month, size: 34, color: navy),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    date(v.start),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    time(v.start),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 18,
                    runSpacing: 4,
                    children: [
                      if (v.scheduleGroup != null) Text(v.scheduleGroup!.label),
                      Text(v.room),
                      Text(v.batch),
                    ],
                  ),
                  const SizedBox(height: 9),
                  status(v.status),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget status(SessionStatus value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: sessionStatusBackground(value),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      value.label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: sessionStatusForeground(value),
      ),
    ),
  );
  void details(SessionRecord v) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            heading('Dialysis Session'),
            Text(s.profile!['patientName'] as String),
            Text('Patient ID: ${s.profile!['patientId']}'),
            const SizedBox(height: 16),
            sessionCardReadOnly(v),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    ),
  );
  Widget sessionCardReadOnly(SessionRecord v) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('${date(v.start)} • ${time(v.start)}'),
      Text('${v.room} • ${v.batch}'),
      const SizedBox(height: 12),
      status(v.status),
      const SizedBox(height: 12),
      SessionProgress(session: v),
      const SizedBox(height: 16),
      sessionTimeline(v.status),
    ],
  );
  Widget filters(
    List<String> labels,
    int selected,
    ValueChanged<int> changed,
  ) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
    child: Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: selected == i ? navy : pale,
                  foregroundColor: selected == i ? Colors.white : navy,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => changed(i),
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
  Widget schedule([StateSetter? update]) {
    final rows = s.sessions
        .where((v) => filter == 2 || (filter == 0 ? !v.finished : v.finished))
        .toList();
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        filters(
          ['Upcoming', 'History', 'All'],
          filter,
          (i) => (update ?? setState)(() => filter = i),
        ),
        if (rows.isEmpty)
          empty(
            filter == 1
                ? 'No session history yet.'
                : 'No upcoming dialysis schedule.',
          ),
        for (final v in rows) ...[
          const Divider(height: 1),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 12,
            ),
            leading: const Icon(Icons.calendar_month, size: 32, color: navy),
            title: Text(
              date(v.start),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${time(v.start)} | ${v.room} | ${v.batch}'),
                  const SizedBox(height: 6),
                  status(v.status),
                ],
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => details(v),
          ),
        ],
      ],
    );
  }

  Widget notificationList([StateSetter? update]) {
    const categories = ['All', 'Schedule', 'Session', 'Reminder'];
    final rows = s.notifications
        .where(
          (n) =>
              notificationFilter == 0 ||
              notificationCategory(n['type'] as String) ==
                  categories[notificationFilter],
        )
        .toList();
    String stamp(Map<String, dynamic> item) {
      final value = DateTime.tryParse(item['createdAt'] as String? ?? '');
      return value == null
          ? 'Time unavailable'
          : DateFormat('MMM d, h:mm a').format(value.toLocal());
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < categories.length; i++)
                ChoiceChip(
                  label: Text(categories[i]),
                  selected: notificationFilter == i,
                  onSelected: (_) =>
                      (update ?? setState)(() => notificationFilter = i),
                ),
            ],
          ),
        ),
        if (rows.isEmpty) empty('No notifications yet.'),
        for (final n in rows)
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: n['readAt'] == null ? const Color(0xFFEFF8FC) : Colors.white,
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Icon(
                notificationCategory(n['type'] as String) == 'Session'
                    ? Icons.monitor_heart_outlined
                    : Icons.calendar_month_outlined,
                color: navy,
              ),
              title: Text(
                n['title'] as String,
                style: TextStyle(
                  fontWeight: n['readAt'] == null
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  Text(
                    n['message'] as String,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${notificationCategory(n['type'] as String)} • ${stamp(n)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    '${s.profile!['patientName']} • ${s.profile!['patientId']}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              trailing: n['readAt'] == null
                  ? const Icon(Icons.circle, size: 8, color: teal)
                  : const Icon(Icons.chevron_right),
              onTap: () async {
                await s.readNotification(n['id'] as String);
                if (!mounted || s.error != null) return;
                showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(n['title'] as String),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${notificationCategory(n['type'] as String)} • ${stamp(n)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            '${s.profile!['patientName']} • ${s.profile!['patientId']}',
                          ),
                          const SizedBox(height: 16),
                          Text(n['message'] as String),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget profile() => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(24),
    children: [
      const Center(child: Logo()),
      const SizedBox(height: 30),
      Card(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              heading('Your Profile'),
              const Divider(),
              ListTile(
                leading: PersonAvatar(
                  gender: s.role == 'patient'
                      ? (s.profile?['gender'] as String?)
                      : null,
                  size: 55,
                ),
                title: Text(s.profile!['name'] as String),
                subtitle: Text(
                  s.role == 'patient'
                      ? 'Patient'
                      : 'Relative for ${s.profile!['patientName']}',
                ),
              ),
              _profileLine(
                s.role == 'patient' ? 'Patient ID' : 'Relative ID',
                s.profile!['accountId'] ?? s.profile!['patientId'],
              ),
              _profileLine('Contact Number', s.profile!['contact']),
              if (s.role == 'relative') ...[
                _profileLine('Relationship', s.profile!['relationship']),
                _profileLine('Linked Patient', s.profile!['patientName']),
                _profileLine('Patient ID', s.profile!['patientId']),
              ],
              if (s.role == 'patient' &&
                  (s.profile!['relativeName'] as String? ?? '').isNotEmpty) ...[
                const Divider(),
                heading('Designated Relative'),
                _profileLine('Name', s.profile!['relativeName']),
                _profileLine(
                  'Relationship',
                  s.profile!['relativeRelationship'],
                ),
              ],
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('Account & Security'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => AccountSecurityScreen(store: s),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.support_agent),
                title: const Text('Help & Support'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const HelpSupportPage(application: 'Mobile'),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy & Terms'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const PrivacyTermsScreen(),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('About DialyCare'),
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: 'DialyCare',
                  applicationVersion: applicationVersion,
                  children: const [Text(dialyCareDescription)],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Log Out'),
                onTap: s.busy ? null : s.logout,
              ),
              if (s.error != null)
                Text(s.error!, style: const TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ),
    ],
  );
  Widget _profileLine(String label, dynamic value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        '$label: ${value is String && value.isNotEmpty ? value : 'Not recorded'}',
      ),
    ),
  );
  Widget empty(String message) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        const Icon(Icons.event_note_outlined, size: 36, color: teal),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
      ],
    ),
  );
}

class PasswordScreen extends StatefulWidget {
  const PasswordScreen({super.key, required this.store});
  final MobileStore store;
  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {
  final current = TextEditingController(),
      next = TextEditingController(),
      confirm = TextEditingController();
  String? validation;
  @override
  void dispose() {
    current.dispose();
    next.dispose();
    confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Change Password')),
    body: AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          for (final f in [
            (current, 'Current password'),
            (next, 'New password'),
            (confirm, 'Confirm password'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: TextField(
                controller: f.$1,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(labelText: f.$2),
              ),
            ),
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(mobilePasswordHint),
          ),
          if (validation ?? widget.store.error case final String error)
            Text(error, style: const TextStyle(color: Colors.red)),
          FilledButton(
            onPressed: widget.store.busy
                ? null
                : () async {
                    final error =
                        validateMobilePassword(next.text) ??
                        confirmMobilePassword(next.text, confirm.text);
                    if (error != null) {
                      setState(() => validation = error);
                      return;
                    }
                    setState(() => validation = null);
                    await widget.store.changePassword(current.text, next.text);
                    if (context.mounted && widget.store.error == null) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Password updated.')),
                      );
                    }
                  },
            child: Text(widget.store.busy ? 'Saving…' : 'Save Password'),
          ),
        ],
      ),
    ),
  );
}

class AccountSecurityScreen extends StatelessWidget {
  const AccountSecurityScreen({super.key, required this.store});
  final MobileStore store;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Account & Security')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('Keep your DialyCare password private.'),
        const SizedBox(height: 16),
        ListTile(
          leading: const Icon(Icons.lock_outline),
          title: const Text('Change Password'),
          subtitle: const Text(mobilePasswordHint),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => PasswordScreen(store: store),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'For account recovery, please contact your dialysis center. A new activation PIN cannot reset an activated password.',
        ),
      ],
    ),
  );
}

class PrivacyTermsScreen extends StatelessWidget {
  const PrivacyTermsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Privacy & Terms')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: const Text('Terms of Use'),
          onTap: () => showPolicyDocument(context, privacy: false),
        ),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: const Text('Privacy Notice'),
          onTap: () => showPolicyDocument(context, privacy: true),
        ),
      ],
    ),
  );
}
