import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../widgets.dart';

class ResetPasswordScreen extends StatefulWidget {
  final VoidCallback onDone;
  const ResetPasswordScreen({super.key, required this.onDone});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _p1 = TextEditingController();
  final _p2 = TextEditingController();
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    _p1.dispose();
    _p2.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await Supabase.instance.client.auth.updateUser(UserAttributes(password: _p1.text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Senha alterada com sucesso!')));
      }
      widget.onDone();
    } catch (_) {
      if (mounted) setState(() => _err = 'Não foi possível alterar. Peça um novo link e tente de novo.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _dec(String l) => InputDecoration(
        labelText: l,
        prefixIcon: const Icon(Icons.lock_outline_rounded, color: C.muted),
        filled: true,
        fillColor: C.surface2,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
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
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(gradient: C.gradient, borderRadius: BorderRadius.circular(26)),
                      child: const Icon(Icons.lock_reset_rounded, size: 44, color: Colors.white),
                    ),
                    const SizedBox(height: 20),
                    const Text('Criar nova senha', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    const Text('Escolha uma senha com 8+ caracteres', style: TextStyle(color: C.muted)),
                    const SizedBox(height: 26),
                    TextFormField(
                      controller: _p1,
                      obscureText: true,
                      decoration: _dec('Nova senha'),
                      validator: (v) => (v == null || v.length < 8) ? 'Mínimo de 8 caracteres' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _p2,
                      obscureText: true,
                      decoration: _dec('Repita a senha'),
                      validator: (v) => v != _p1.text ? 'As senhas não são iguais' : null,
                    ),
                    if (_err != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_err!, style: const TextStyle(color: C.pink))),
                    const SizedBox(height: 20),
                    SizedBox(width: double.infinity, child: GradientButton(label: 'Salvar senha', loading: _busy, onPressed: _save)),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
