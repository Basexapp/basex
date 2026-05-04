import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:js_interop';
import 'dart:html' as html;
import 'login_page.dart';
import 'home.dart';
import 'configuracoes/escolher_senha.dart';
import 'configuracoes/redefinir_senha.dart';

@JS()
external JSFunction? atualizarApp;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final supabase = Supabase.instance.client;
  String _statusMessage = 'Verificando atualizações...';
  String _versaoExibida = '2.2.12';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _carregarVersao();
    _iniciarVerificacoes();
  }

  Future<void> _carregarVersao() async {
    final versao = _getVersaoAtual();
    if (mounted) {
      setState(() {
        _versaoExibida = versao;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _iniciarVerificacoes() async {
    try {
      final precisaAtualizar = await _verificarAtualizacao();
      
      if (precisaAtualizar && mounted) {
        // Verifica se já tentamos atualizar nesta sessão (anti-loop)
        final jaAtualizou = html.window.sessionStorage['app_atualizado'];
        if (jaAtualizou == 'true') {
          // Já tentou atualizar mas o código velho ainda está cacheado.
          // Segue para o login normalmente — no próximo acesso virá a versão nova.
          html.window.sessionStorage.remove('app_atualizado');
        } else {
          _mostrarDialogAtualizacao();
          return;
        }
      }
      
      // Limpa flag de atualização se versões batem
      html.window.sessionStorage.remove('app_atualizado');
      
      _statusMessage = 'Verificando sessão...';
      if (mounted) setState(() {});
      
      await _verificarSessao();
    } catch (e) {
      print('Erro na verificação inicial: $e');
      _statusMessage = 'Verificando sessão...';
      if (mounted) setState(() {});
      await _verificarSessao();
    }
  }

  /// Busca /version.json (com cache-bust) e compara com a versão hardcoded.
  /// O arquivo version.json é deployado junto com o app no Firebase Hosting
  /// e tem header Cache-Control: no-cache, garantindo que sempre retorne a
  /// versão mais recente do servidor.
  Future<bool> _verificarAtualizacao() async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final baseUrl = Uri.base.origin;
      final response = await http.get(
        Uri.parse('$baseUrl/version.json?t=$timestamp'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final String versaoServidor = data['versao']?.toString() ?? '0';
        final String versaoAtual = _getVersaoAtual();
        return versaoServidor != versaoAtual;
      }
    } catch (e) {
      // Falha ao buscar version.json — segue normalmente
    }
    return false;
  }

  String _getVersaoAtual() {
    return '2.2.12';
  }

  void _mostrarDialogAtualizacao() {
    // Tenta obter a versão do servidor novamente para exibir no dialog
    _verificarVersaoServidor().then((versaoServidor) {
      if (!mounted) return;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.white24, width: 1),
            ),
            title: const Text(
              'Atualização Disponível',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Uma nova versão do aplicativo está disponível.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ],
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _recarregarApp();
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: const Color(0xFF0A4B78),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'ATUALIZAR AGORA',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      );
    });
  }

  /// Helper para pegar a versão do servidor sem cache
  Future<String> _verificarVersaoServidor() async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final baseUrl = Uri.base.origin;
      final response = await http.get(
        Uri.parse('$baseUrl/version.json?t=$timestamp'),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['versao']?.toString() ?? '...';
      }
    } catch (_) {}
    return '...';
  }

  void _recarregarApp() {
    // Marca que já tentamos atualizar (previne loop infinito)
    html.window.sessionStorage['app_atualizado'] = 'true';
    
    // Chama a função JS que limpa service workers + caches e recarrega
    if (atualizarApp != null) {
      atualizarApp!.callAsFunction();
    } else {
      // Fallback: navega com cache-bust
      final uri = Uri.base.replace(queryParameters: {
        ...Uri.base.queryParameters,
        'cache_bust': DateTime.now().millisecondsSinceEpoch.toString(),
      });
      html.window.location.replace(uri.toString());
    }
  }

  Future<void> _verificarSessao() async {
    final uri = Uri.base.toString();

    // 🧩 Se for link de recuperação (contém #access_token&type=recovery)
    if (uri.contains('type=recovery')) {
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RedefinirSenhaPage()),
        (route) => false,
      );
      return;
    }

    // 🔐 Verificação normal de sessão
    final session = supabase.auth.currentSession;

    if (session == null) {
      _irParaLogin();
      return;
    }

    // ⚙️ Tenta atualizar a sessão
    try {
      final refresh = await supabase.auth.refreshSession();

      if (refresh.session == null) {
        _irParaLogin();
        return;
      }

      // 🕒 Verifica validade da sessão (24h)
      final dataLogin = DateTime.parse(session.user.createdAt);
      final limite = DateTime.now().subtract(const Duration(hours: 24));
      if (dataLogin.isBefore(limite)) {
        await supabase.auth.signOut();
        _irParaLogin();
        return;
      }

      // 🔐 Verifica se o usuário ainda tem senha provisória
      final usuario = await supabase
          .from('usuarios')
          .select('senha_temporaria')
          .eq('email', session.user.email ?? '')
          .maybeSingle();

      if (usuario != null && usuario['senha_temporaria'] == true) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const EscolherSenhaPage()),
        );
      } else {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    } catch (e) {
      print('Erro ao verificar sessão: $e');
      _irParaLogin();
    }
  }

  void _irParaLogin() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Image.asset(
                'assets/logo_top_login20.png',
                width: 250,
                height: 250,
                fit: BoxFit.contain,
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -20),
              child: Text(
                'v$_versaoExibida',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  const Color(0xFF0A4B78),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _statusMessage,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}