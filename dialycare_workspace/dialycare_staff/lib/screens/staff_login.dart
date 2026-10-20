import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/staff_theme.dart';

class StaffLogin extends StatefulWidget {
  const StaffLogin({
    super.key,
    required this.email,
    required this.password,
    required this.busy,
    required this.onLogin,
    required this.onRecovery,
    this.error,
  });
  final TextEditingController email, password;
  final bool busy;
  final VoidCallback onLogin, onRecovery;
  final String? error;
  @override
  State<StaffLogin> createState() => _StaffLoginState();
}

class _StaffLoginState extends State<StaffLogin> {
  bool obscure = true;

  InputDecoration decoration(String label, {Widget? suffix}) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(color: Color(0xffa9c8f2)),
    );
    return InputDecoration(
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.never,
      labelStyle: const TextStyle(color: Color(0xff656b70), fontSize: 16),
      filled: true,
      fillColor: const Color(0xffe6eff3),
      contentPadding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
      border: border,
      enabledBorder: border,
      disabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: Color(0xff0054b8), width: 1.5),
      ),
      suffixIcon: suffix,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xfff1f3f5),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, outer) {
          const margin = 0.0;
          return Padding(
            padding: EdgeInsets.all(margin),
            child: ClipRect(
              child: CustomPaint(
                painter: const _LoginBackground(),
                child: LayoutBuilder(
                  builder: (context, box) {
                    final compact = box.maxHeight < 620;
                    final width = math.min(
                      box.maxWidth - 48,
                      (box.maxWidth * .40).clamp(300.0, 380.0),
                    );
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: box.maxHeight),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: compact ? 26 : 46,
                            horizontal: 24,
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const _LoginBrand(),
                                SizedBox(height: compact ? 38 : 52),
                                SizedBox(
                                  width: width,
                                  child: AutofillGroup(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        const Text(
                                          'Welcome Back!',
                                          style: TextStyle(
                                            color: StaffTheme.navy,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 26,
                                            letterSpacing: .4,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'Log in to your DialyCare Staff account.',
                                          style: TextStyle(
                                            color: StaffTheme.navy,
                                            fontSize: 16,
                                            height: 1.35,
                                            letterSpacing: .3,
                                          ),
                                        ),
                                        SizedBox(height: compact ? 30 : 38),
                                        TextField(
                                          controller: widget.email,
                                          enabled: !widget.busy,
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          textInputAction: TextInputAction.next,
                                          autofillHints: const [
                                            AutofillHints.username,
                                          ],
                                          autocorrect: false,
                                          decoration: decoration('Staff Email'),
                                        ),
                                        const SizedBox(height: 24),
                                        TextField(
                                          controller: widget.password,
                                          enabled: !widget.busy,
                                          obscureText: obscure,
                                          enableSuggestions: false,
                                          autocorrect: false,
                                          autofillHints: const [
                                            AutofillHints.password,
                                          ],
                                          textInputAction: TextInputAction.done,
                                          onSubmitted: widget.busy
                                              ? null
                                              : (_) => widget.onLogin(),
                                          decoration: decoration(
                                            'Password',
                                            suffix: IconButton(
                                              tooltip: obscure
                                                  ? 'Show password'
                                                  : 'Hide password',
                                              onPressed: widget.busy
                                                  ? null
                                                  : () => setState(
                                                      () => obscure = !obscure,
                                                    ),
                                              icon: Icon(
                                                obscure
                                                    ? Icons
                                                          .visibility_off_outlined
                                                    : Icons.visibility_outlined,
                                                size: 22,
                                                color: const Color(0xff737b80),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton(
                                            onPressed: widget.busy
                                                ? null
                                                : widget.onRecovery,
                                            style: TextButton.styleFrom(
                                              foregroundColor: const Color(
                                                0xff0055b9,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 10,
                                                  ),
                                            ),
                                            child: const Text(
                                              'Forgot password?',
                                              style: TextStyle(
                                                decoration:
                                                    TextDecoration.underline,
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (widget.error != null)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 10,
                                            ),
                                            child: Semantics(
                                              liveRegion: true,
                                              child: Text(
                                                widget.error!,
                                                style: const TextStyle(
                                                  color: Color(0xff9d2424),
                                                  height: 1.4,
                                                ),
                                              ),
                                            ),
                                          ),
                                        SizedBox(height: compact ? 26 : 32),
                                        SizedBox(
                                          height: 48,
                                          child: FilledButton(
                                            onPressed: widget.busy
                                                ? null
                                                : widget.onLogin,
                                            style: FilledButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xff064cb0,
                                              ),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(9),
                                              ),
                                            ),
                                            child: Text(
                                              widget.busy
                                                  ? 'Signing in…'
                                                  : 'Log In',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                letterSpacing: .4,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(height: compact ? 28 : 44),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _LoginBrand extends StatelessWidget {
  const _LoginBrand();
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'DialyCare. Stay on Schedule. Stay in Care.',
    image: true,
    child: ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Reuse the existing transparent logo's emblem without duplicating an asset.
          ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              widthFactor: .70,
              heightFactor: .73,
              child: Image.asset(
                'assets/images/auth-logo.png',
                width: 78,
                height: 78,
              ),
            ),
          ),
          const SizedBox(width: 3),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Dialy',
                      style: TextStyle(color: Color(0xff112b55)),
                    ),
                    TextSpan(
                      text: 'Care',
                      style: TextStyle(color: Color(0xff4ca0d4)),
                    ),
                  ],
                ),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .4,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Stay on Schedule. Stay in Care.',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: Color(0xff112b55),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _LoginBackground extends CustomPainter {
  const _LoginBackground();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, bounds = Offset.zero & size;
    canvas.save();
    canvas.clipRect(bounds);
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [Color(0xff3eb4da), Color(0xffeef9fc), Color(0xff54b8d9)],
        ).createShader(bounds),
    );
    // Broad white center and sweeping lower edge follow the supplied screenshot.
    final center = Path()
      ..moveTo(0, 0)
      ..lineTo(w * .63, 0)
      ..cubicTo(w * .72, h * .22, w * .88, -h * .03, w, h * .09)
      ..lineTo(w, h * .27)
      ..cubicTo(w * .89, h * .69, w * .68, h * .89, w * .40, h * .83)
      ..cubicTo(w * .22, h * .81, w * .11, h * .77, 0, h * .68)
      ..close();
    canvas.drawPath(
      center,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          stops: [0, .40, .75],
          colors: [Color(0xffbce5f3), Colors.white, Colors.white],
        ).createShader(bounds),
    );
    final top = Path()
      ..moveTo(w * .63, -2)
      ..cubicTo(w * .72, h * .23, w * .89, -h * .03, w + 2, h * .09);
    canvas.drawPath(
      top,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    final bottom = Path()
      ..moveTo(-5, h * .79)
      ..cubicTo(w * .04, h * .89, w * .08, h * .94, w * .16, h + 6);
    canvas.drawPath(
      bottom,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    final lines = Paint()
      ..color = const Color(0xff00a9ec)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .85;
    for (var i = 0; i < 20; i++) {
      final t = i / 19;
      final upper = Path()
        ..moveTo(-w * .03, h * (.015 + t * .24))
        ..cubicTo(
          w * .12,
          h * (.40 - t * .16),
          w * .12,
          -h * (.20 - t * .13),
          w * (.40 + t * .025),
          -h * .04,
        );
      canvas.drawPath(upper, lines);
      final lower = Path()
        ..moveTo(w * 1.03, h * (.47 + t * .46))
        ..cubicTo(
          w * (.68 + t * .21),
          h * (.47 + t * .13),
          w * (.92 - t * .03),
          h * (.85 + t * .15),
          w * (.78 + t * .23),
          h * 1.04,
        );
      canvas.drawPath(lower, lines);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LoginBackground oldDelegate) => false;
}
