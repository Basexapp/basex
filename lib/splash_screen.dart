import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_page.dart';
import 'home.dart';
import 'configuracoes/escolher_senha.dart';
import 'configuracoes/redefinir_senha.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final supabase = Supabase.instance.client;
  String _statusMessage = 'Verificando atualizações...';
  String _versaoExibida = '2.1.5';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _carregarVersao();
    _iniciarVerificacoes();
  }

  Future<void> _carregarVersao() async {
    final versao = await _getVersaoAtual();
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
      // Primeiro verifica se há atualizações disponíveis
      final precisaAtualizar = await _verificarAtualizacao();
      
      if (precisaAtualizar && mounted) {
        _mostrarDialogAtualizacao();
        return;
      }
      
      // Se não precisa atualizar, continua com a verificação de sessão
      _statusMessage = 'Verificando sessão...';
      if (mounted) setState(() {});
      
      await _verificarSessao();
    } catch (e) {
      print('Erro na verificação inicial: $e');
      // Em caso de erro, continua com a verificação de sessão
      _statusMessage = 'Verificando sessão...';
      if (mounted) setState(() {});
      await _verificarSessao();
    }
  }

  Future<bool> _verificarAtualizacao() async {
    try {
      // URL do seu servidor com a versão mais recente
      // ATENÇÃO: Substitua pela URL real do seu backend quando estiver em produção
      // Por enquanto, retorna false para não bloquear o desenvolvimento
      final response = await http.get(
        Uri.parse('https://seuservidor.com/api/versao'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final String versaoServidor = data['versao']?.toString() ?? '0';
        
        // Obtém a versão atual do app
        final String versaoAtual = await _getVersaoAtual();
        
        // Compara as versões
        return _compararVersoes(versaoServidor, versaoAtual);
      }
    } catch (e) {
      // Servidor de versão não configurado ainda — ignora silenciosamente
    }
    return false; // Retorna false para desenvolvimento
  }

  Future<String> _getVersaoAtual() async {
    try {
      // Retorna uma versão padrão
      // Em produção, você pode usar package_info_plus para obter a versão real
      return '2.1.5';
    } catch (e) {
      return '2.1.5';
    }
  }

  bool _compararVersoes(String servidor, String atual) {
    try {
      List<int> versaoServidor = servidor.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      List<int> versaoAtual = atual.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      
      // Garante que ambas as listas tenham o mesmo tamanho
      while (versaoServidor.length < 3) {
        versaoServidor.add(0);
      }
      while (versaoAtual.length < 3) {
        versaoAtual.add(0);
      }
      
      for (int i = 0; i < versaoServidor.length; i++) {
        if (versaoServidor[i] > versaoAtual[i]) return true;
        if (versaoServidor[i] < versaoAtual[i]) return false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  void _mostrarDialogAtualizacao() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Atualização Disponível',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Uma nova versão do aplicativo está disponível.\n\n'
            'Por favor, atualize para continuar usando o app.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _recarregarApp();
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF0A4B78),
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
  }

  void _recarregarApp() {
    // Força o recarregamento completo do app
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (route) => false,
    );
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