import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';
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
  bool _msgOk = false;
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

  String _err(Object e) {
    final m = e is AuthException ? e.message.toLowerCase() : e.toString().toLowerCase();
    if (m.contains('invalid login')) return 'E-mail ou senha incorretos.';
    if (m.contains('already') || m.contains('registered')) return 'Esse e-mail já tem conta. Tente entrar.';
    if (m.contains('email not confirmed')) return 'Confirme seu e-mail pelo link que enviamos.';
    if (m.contains('rate') || m.contains('too many')) return 'Muitas tentativas. Aguarde um pouco.';
    if (m.contains('password')) return 'Senha muito fraca. Use 8+ caracteres.';
    if (m.contains('socket') || m.contains('network') || m.contains('host')) return 'Sem conexão com a internet.';
    return 'Algo deu errado. Tente de novo.';
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _msg = null;
    });
    final auth = Supabase.instance.client.auth;
    try {
      if (_signup) {
        final r = await auth.signUp(email: _email.text.trim(), password: _pass.text, emailRedirectTo: Config.authRedirect);
        if (r.session == null && mounted) {
          setState(() {
            _msgOk = true;
            _msg = 'Conta criada! Confira seu e-mail para confirmar e depois entre.';
            _signup = false;
          });
        }
      } else {
        await auth.signInWithPassword(email: _email.text.trim(), password: _pass.text);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _msgOk = false;
          _msg = _err(e);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    final mail = _email.text.trim();
    if (!mail.contains('@')) {
      setState(() {
        _msgOk = false;
        _msg = 'Digite seu e-mail acima para recuperar a senha.';
      });
      return;
    }
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(mail, redirectTo: Config.authRedirect);
      setState(() {
        _msgOk = true;
        _msg = 'Enviamos um link de recuperação para o seu e-mail.';
      });
    } catch (e) {
      setState(() {
        _msgOk = false;
        _msg = _err(e);
      });
    }
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
                          boxShadow: [BoxShadow(color: C.pink.withAlpha(110), blurRadius: 40, offset: const Offset(0, 14))],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(32),
                          child: Image.asset('assets/logo.png', width: 104, height: 104),
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text('Master Music', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                      const SizedBox(height: 6),
                      Text(
                        _signup ? 'Crie sua conta grátis' : 'Bem-vindo de volta',
                        style: const TextStyle(color: C.muted, fontSize: 15),
                      ),
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
                                  Icon(_msgOk ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                                      size: 18, color: _msgOk ? C.cyan : C.pink),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(_msg!, style: TextStyle(color: _msgOk ? C.cyan : C.pink))),
                                ]),
                              ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: GradientButton(
                          label: _signup ? 'Criar conta' : 'Entrar',
                          loading: _busy,
                          onPressed: _submit,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (!_signup)
                        TextButton(onPressed: _reset, child: const Text('Esqueci minha senha', style: TextStyle(color: C.muted))),
                      TextButton(
                        onPressed: () => setState(() {
                          _signup = !_signup;
                          _msg = null;
                        }),
                        child: Text(
                          _signup ? 'Já tenho conta • Entrar' : 'Não tem conta? Criar agora',
                          style: const TextStyle(color: C.cyan, fontWeight: FontWeight.w700),
                        ),
                      ),
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
