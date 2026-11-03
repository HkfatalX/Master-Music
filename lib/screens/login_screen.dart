import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _signup = false;
  bool _busy = false;
  bool _hide = true;
  String? _msg;
  bool _flip = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) setState(() => _flip = !_flip);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() job) async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      await job();
    } catch (e) {
      if (mounted) setState(() => _msg = authError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final mail = _email.text.trim();
    await _run(() => _signup ? AuthFlow.I.signUp(mail, _pass.text) : AuthFlow.I.passwordLogin(mail, _pass.text));
  }

  Future<void> _forgot() async {
    final mail = _email.text.trim();
    if (!mail.contains('@')) {
      setState(() => _msg = 'Digite seu e-mail acima para receber o código.');
      return;
    }
    await _run(() => AuthFlow.I.forgot(mail));
  }

  InputDecoration _dec(String label, IconData icon, {Widget? suffix}) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: C.muted),
        suffixIcon: suffix,
        filled: true,
        fillColor: C.surface2.withAlpha(200),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(seconds: 4),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: _flip ? Alignment.topRight : Alignment.topLeft,
            end: _flip ? Alignment.bottomLeft : Alignment.bottomRight,
            colors: const [Color(0xFF2A0F5C), C.bg, Color(0xFF4A0E3A)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: FadeSlide(
                  child: Form(
                    key: _form,
                    child: Column(children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [BoxShadow(color: C.violet.withAlpha(120), blurRadius: 40, offset: const Offset(0, 14))],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(32),
                          child: Image.asset('assets/logo.png', width: 104, height: 104),
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text('Master Music', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                      const SizedBox(height: 6),
                      Text(_signup ? 'Crie sua conta grátis' : 'Bem-vindo de volta', style: const TextStyle(color: C.muted, fontSize: 15)),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: _dec('E-mail', Icons.mail_outline_rounded),
                        validator: (v) => (v == null || !v.contains('@') || !v.contains('.')) ? 'E-mail inválido' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _pass,
                        obscureText: _hide,
                        autofillHints: const [AutofillHints.password],
                        decoration: _dec(
                          'Senha',
                          Icons.lock_outline_rounded,
                          suffix: IconButton(
                            icon: Icon(_hide ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: C.muted),
                            onPressed: () => setState(() => _hide = !_hide),
                          ),
                        ),
                        validator: (v) => (v == null || v.length < 8) ? 'Mínimo de 8 caracteres' : null,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        child: _msg == null
                            ? const SizedBox(height: 14)
                            : Padding(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                child: Row(children: [
                                  const Icon(Icons.error_outline_rounded, size: 18, color: C.pink),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(_msg!, style: const TextStyle(color: C.pink))),
                                ]),
                              ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: GradientButton(label: _signup ? 'Criar conta' : 'Entrar', loading: _busy, onPressed: _submit),
                      ),
                      const SizedBox(height: 14),
                      Row(children: const [
                        Expanded(child: Divider(color: C.surface2)),
                        Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('ou', style: TextStyle(color: C.muted))),
                        Expanded(child: Divider(color: C.surface2)),
                      ]),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: C.surface2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _busy ? null : () => _run(AuthFlow.I.googleLogin),
                          icon: Container(
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: const Text('G', style: TextStyle(color: Color(0xFF4285F4), fontWeight: FontWeight.w900, fontSize: 14)),
                          ),
                          label: const Text('Continuar com Google', style: TextStyle(color: C.text, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (!_signup) TextButton(onPressed: _busy ? null : _forgot, child: const Text('Esqueci minha senha', style: TextStyle(color: C.muted))),
                      TextButton(
                        onPressed: () => setState(() {
                          _signup = !_signup;
                          _msg = null;
                        }),
                        child: Text(_signup ? 'Já tenho conta • Entrar' : 'Não tem conta? Criar agora',
                            style: const TextStyle(color: C.cyan, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(height: 4),
                      const Text('Por segurança, enviamos um código de 6 dígitos para o seu e-mail em cada entrada.',
                          textAlign: TextAlign.center, style: TextStyle(color: C.muted, fontSize: 12, height: 1.4)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
