import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';

final FlutterSecureStorage secureStore = FlutterSecureStorage();

enum CodePurpose { login, signup, recovery }

String authError(Object e) {
  final m = (e is AuthException ? e.message : e.toString()).toLowerCase();
  if (m.contains('invalid login')) return 'E-mail ou senha incorretos.';
  if (m.contains('token has expired') || m.contains('expired')) return 'Esse código expirou. Toque em reenviar.';
  if (m.contains('invalid') && (m.contains('token') || m.contains('otp') || m.contains('code'))) {
    return 'Código incorreto. Confira e tente de novo.';
  }
  if (m.contains('rate') || m.contains('too many') || m.contains('seconds')) {
    return 'Muitas tentativas ou limite de e-mails atingido. Aguarde um pouco e tente de novo.';
  }
  if (m.contains('already')) return 'Esse e-mail já tem conta. Tente entrar.';
  if (m.contains('weak') || m.contains('password should')) return 'Senha fraca. Use 8+ caracteres.';
  if (m.contains('same password') || m.contains('different from the old')) return 'Escolha uma senha diferente da anterior.';
  if (m.contains('provider') && m.contains('enabled')) return 'O login com Google ainda não foi ativado neste servidor. Use e-mail e senha por enquanto.';
  if (m.contains('socket') || m.contains('network') || m.contains('host') || m.contains('failed host')) {
    return 'Sem conexão com a internet.';
  }
  return 'Algo deu errado. Tente de novo.';
}

/// Fluxo de login com código de 6 dígitos enviado por e-mail.
/// Nenhuma sessão fica salva no aparelho até o código ser confirmado.
class AuthFlow extends ChangeNotifier {
  AuthFlow._();
  static final I = AuthFlow._();

  GoTrueClient get _a => Supabase.instance.client.auth;

  String? pendingEmail;
  CodePurpose purpose = CodePurpose.login;
  bool recovery = false;

  void begin(String email, CodePurpose p) {
    pendingEmail = email;
    purpose = p;
    notifyListeners();
  }

  void cancel() {
    pendingEmail = null;
    recovery = false;
    notifyListeners();
  }

  void finish() {
    pendingEmail = null;
    notifyListeners();
  }

  void endRecovery() {
    recovery = false;
    notifyListeners();
  }

  Future<void> _sendLogin(String email) => _a.signInWithOtp(email: email, shouldCreateUser: false);

  Future<void> passwordLogin(String email, String pass) async {
    try {
      await _a.signInWithPassword(email: email, password: pass);
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('not confirmed')) {
        await _a.resend(type: OtpType.signup, email: email);
        begin(email, CodePurpose.signup);
        return;
      }
      rethrow;
    }
    await _a.signOut(); // só entra de verdade depois do código
    await _sendLogin(email);
    begin(email, CodePurpose.login);
  }

  Future<void> signUp(String email, String pass) async {
    final r = await _a.signUp(email: email, password: pass);
    if (r.session != null) {
      await _a.signOut();
      await _sendLogin(email);
      begin(email, CodePurpose.login);
    } else {
      begin(email, CodePurpose.signup);
    }
  }

  Future<void> forgot(String email) async {
    await _a.resetPasswordForEmail(email);
    begin(email, CodePurpose.recovery);
  }

  Future<void> verify(String code) async {
    final email = pendingEmail;
    if (email == null) return;
    switch (purpose) {
      case CodePurpose.login:
        await _a.verifyOTP(email: email, token: code, type: OtpType.email);
        break;
      case CodePurpose.signup:
        await _a.verifyOTP(email: email, token: code, type: OtpType.signup);
        break;
      case CodePurpose.recovery:
        recovery = true;
        try {
          await _a.verifyOTP(email: email, token: code, type: OtpType.recovery);
        } catch (_) {
          recovery = false;
          rethrow;
        }
        break;
    }
    finish();
  }

  Future<void> resend() async {
    final email = pendingEmail;
    if (email == null) return;
    switch (purpose) {
      case CodePurpose.login:
        await _sendLogin(email);
        break;
      case CodePurpose.signup:
        await _a.resend(type: OtpType.signup, email: email);
        break;
      case CodePurpose.recovery:
        await _a.resetPasswordForEmail(email);
        break;
    }
  }

  Future<void> updatePassword(String pass) async {
    await _a.updateUser(UserAttributes(password: pass));
    endRecovery();
  }

  /// Confere no servidor se o login com Google está ativado (evita abrir uma página de erro).
  static Future<void> ensureGoogleEnabled() async {
    try {
      final r = await http
          .get(Uri.parse('${Config.supabaseUrl}/auth/v1/settings'), headers: {'apikey': Config.supabaseKey})
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body);
        final ext = j is Map ? j['external'] : null;
        if (ext is Map && ext['google'] != true) {
          throw Exception('Unsupported provider: provider is not enabled');
        }
      }
    } on FormatException {
      return;
    }
  }

  Future<void> googleLogin() async {
    await ensureGoogleEnabled();
    await secureStore.write(key: 'oauth_pending', value: 'login');
    await _a.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: Config.authRedirect,
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }

  /// Chamado quando o Google devolve o usuário ao app.
  Future<void> handleOAuthReturn() async {
    final flag = await secureStore.read(key: 'oauth_pending');
    if (flag == null) return;
    final s = _a.currentSession;
    if (s == null) return;
    await secureStore.delete(key: 'oauth_pending');
    final tok = s.providerToken;
    if (tok != null) {
      await secureStore.write(key: 'yt_token', value: tok);
      await secureStore.write(key: 'yt_time', value: DateTime.now().millisecondsSinceEpoch.toString());
    }
    if (flag.startsWith('yt:') && flag.substring(3) == s.user.id) return; // só conectou o YouTube
    final email = s.user.email;
    if (email == null) return;
    await _a.signOut();
    await _sendLogin(email);
    begin(email, CodePurpose.login);
  }

  Future<void> signOut() async {
    await secureStore.delete(key: 'yt_token');
    await secureStore.delete(key: 'yt_time');
    await _a.signOut();
  }
}
