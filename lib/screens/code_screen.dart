import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets.dart';

class CodeScreen extends StatefulWidget {
  const CodeScreen({super.key});

  @override
  State<CodeScreen> createState() => _CodeScreenState();
}

class _CodeScreenState extends State<CodeScreen> {
  static const _cooldown = 45;
  final _code = TextEditingController();
  final _focus = FocusNode();
  bool _busy = false;
  String? _msg;
  bool _ok = false;
  int _left = _cooldown;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _t?.cancel();
    setState(() => _left = _cooldown);
    _t = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _left = _left > 0 ? _left - 1 : 0);
      if (_left == 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_code.text.length < 6 || _busy) return;
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      await AuthFlow.I.verify(_code.text);
    } catch (e) {
      if (mounted) {
        setState(() {
          _msg = authError(e);
          _ok = false;
          _code.clear();
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (_left > 0) return;
    try {
      await AuthFlow.I.resend();
      if (mounted) {
        setState(() {
          _msg = 'Novo código enviado! Confira também o spam.';
          _ok = true;
        });
      }
      _startTimer();
    } catch (e) {
      if (mounted) {
        setState(() {
          _msg = authError(e);
          _ok = false;
        });
      }
    }
  }

  String get _title {
    switch (AuthFlow.I.purpose) {
      case CodePurpose.signup:
        return 'Confirme seu e-mail';
      case CodePurpose.recovery:
        return 'Recuperar senha';
      case CodePurpose.login:
        return 'Código de segurança';
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = AuthFlow.I.pendingEmail ?? '';
    final digits = _code.text.padRight(6);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: FadeSlide(
                child: Column(children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(onPressed: AuthFlow.I.cancel, icon: const Icon(Icons.arrow_back_rounded)),
                  ),
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(gradient: C.gradient, borderRadius: BorderRadius.circular(26)),
                    child: const Icon(Icons.mark_email_read_rounded, size: 42, color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  Text(_title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text('Enviamos um código de 6 dígitos para\n$email',
                      textAlign: TextAlign.center, style: const TextStyle(color: C.muted, height: 1.4)),
                  const SizedBox(height: 28),
                  GestureDetector(
                    onTap: () => _focus.requestFocus(),
                    child: Stack(alignment: Alignment.center, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        for (var i = 0; i < 6; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 48,
                            height: 60,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: C.surface2,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: i == _code.text.length ? C.pink : Colors.transparent, width: 2),
                            ),
                            child: Text(digits[i].trim(), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                          ),
                      ]),
                      Opacity(
                        opacity: 0,
                        child: TextField(
                          controller: _code,
                          focusNode: _focus,
                          autofocus: true,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          onChanged: (v) {
                            setState(() {});
                            if (v.length == 6) _verify();
                          },
                        ),
                      ),
                    ]),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    child: _msg == null
                        ? const SizedBox(height: 18)
                        : Padding(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            child: Text(_msg!, textAlign: TextAlign.center, style: TextStyle(color: _ok ? C.cyan : C.pink)),
                          ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: GradientButton(label: 'Confirmar', loading: _busy, onPressed: _code.text.length == 6 ? _verify : null),
                  ),
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: _left == 0 ? _resend : null,
                    child: Text(_left == 0 ? 'Reenviar código' : 'Reenviar em ${_left}s',
                        style: TextStyle(color: _left == 0 ? C.cyan : C.muted, fontWeight: FontWeight.w700)),
                  ),
                  const Text('O código vale por pouco tempo. Não compartilhe com ninguém.',
                      textAlign: TextAlign.center, style: TextStyle(color: C.muted, fontSize: 12)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
