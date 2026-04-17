import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'configuracoes/cadastro_novo_usuario.dart';
import 'configuracoes/esqueci_senha.dart';

class UsuarioAtual {
  static UsuarioAtual? instance;

  final String id;
  final String nome;
  final int nivel;
  final String? filialId;
  final String? empresaId;
  final String? empresaNome;
  final String? terminalId;
  final String? terminalNome;
  final List<String> cardsPermitidosIds;
  final bool senhaTemporaria;

  UsuarioAtual({
    required this.id,
    required this.nome,
    required this.nivel,
    required this.filialId,
    required this.empresaId,
    required this.empresaNome,
    required this.terminalId,
    required this.terminalNome,
    required this.cardsPermitidosIds,
    required this.senhaTemporaria,
  });

  bool podeAcessarCard(String cardId) {
    if (nivel >= 3) return true;
    return cardsPermitidosIds.contains(cardId);
  }

  bool get precisaTrocarSenha => senhaTemporaria;
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _obscureText = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkForRecoveryLink();
  }

  Future<void> _checkForRecoveryLink() async {
    final uri = Uri.base;
    
    if (uri.queryParameters.containsKey('code')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/redefinir-senha');
        }
      });
      return;
    }
    
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null && mounted) {
      _fetchUserData(session.user.id);
    }
  }

  Future<void> _fetchUserData(String userId) async {
    try {
      final supabase = Supabase.instance.client;
      
      final raw = await supabase
          .from('usuarios')
          .select('''
            id,
            nome,
            Nome_apelido,
            nivel,
            empresa_id,
            empresas ( nome_dois ),
            terminal_id,
            senha_temporaria
          ''')
          .eq('id', userId)
          .maybeSingle();

      if (raw != null && mounted) {
        _processarLogin(raw);
      }
    } catch (e) {
      print('Erro ao buscar dados do usuário: $e');
    }
  }

  Future<String?> _buscarFilialIdPorTerminal(String? terminalId) async {
    if (terminalId == null) return null;
    
    try {
      final supabase = Supabase.instance.client;
      
      final filial = await supabase
          .from('filiais')
          .select('id')
          .eq('terminal_id_1', terminalId)
          .maybeSingle();
      
      return filial?['id']?.toString();
    } catch (e) {
      print('Erro ao buscar filial: $e');
      return null;
    }
  }

  Future<String?> _buscarNomeTerminal(String? terminalId) async {
    if (terminalId == null) return null;
    
    try {
      final supabase = Supabase.instance.client;
      
      final terminal = await supabase
          .from('terminais')
          .select('nome')
          .eq('id', terminalId)
          .maybeSingle();
      
      return terminal?['nome']?.toString();
    } catch (e) {
      print('Erro ao buscar terminal: $e');
      return null;
    }
  }

  Future<List<String>> _carregarPermissoesCards(String usuarioId) async {
    try {
      final supabase = Supabase.instance.client;

      final permissoes = await supabase
          .from('permissoes')
          .select('id_sessao')
          .eq('id_usuario', usuarioId)
          .eq('permitido', true);

      return permissoes
          .map((p) => p['id_sessao']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
    } catch (e) {
      print('Erro ao carregar permissões: $e');
      return [];
    }
  }

  Future<void> _processarLogin(Map<String, dynamic> usuarioData) async {
    final int nivel = usuarioData['nivel'] as int;
    final String? empresaId = usuarioData['empresa_id']?.toString();
    
    final String? empresaNome = (usuarioData['empresas'] as Map?)?['nome_dois']?.toString();
    
    final String? terminalId = usuarioData['terminal_id']?.toString();
    
    final String? filialId = await _buscarFilialIdPorTerminal(terminalId);
    final String? terminalNome = await _buscarNomeTerminal(terminalId);
    final cardsPermitidosIds = await _carregarPermissoesCards(usuarioData['id'].toString());

    if (nivel < 3 && cardsPermitidosIds.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Você não tem permissão para acessar nenhuma funcionalidade.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }

      await Supabase.instance.client.auth.signOut();
      UsuarioAtual.instance = null;
      return;
    }

    UsuarioAtual.instance = UsuarioAtual(
      id: usuarioData['id'].toString(),
      nome: (usuarioData['Nome_apelido'] ?? usuarioData['nome']).toString(),
      nivel: nivel,
      filialId: filialId,
      empresaId: empresaId,
      empresaNome: empresaNome,
      terminalId: terminalId,
      terminalNome: terminalNome,
      cardsPermitidosIds: cardsPermitidosIds,
      senhaTemporaria: usuarioData['senha_temporaria'] == true,
    );

    if (mounted) {
      if (UsuarioAtual.instance!.precisaTrocarSenha) {
        Navigator.pushReplacementNamed(context, '/escolher-senha');
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    }
  }

  Future<void> loginUser() async {
    TextInput.finishAutofillContext();
    
    setState(() => _isLoading = true);

    final supabase = Supabase.instance.client;
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, preencha e-mail e senha.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) throw Exception('Falha na autenticação.');

      final raw = await supabase
          .from('usuarios')
          .select('''
            id,
            nome,
            Nome_apelido,
            nivel,
            empresa_id,
            empresas ( nome_dois ),
            terminal_id,
            senha_temporaria
          ''')
          .eq('id', user.id)
          .maybeSingle();

      if (raw == null) {
        throw Exception('Usuário não encontrado.');
      }

      await _processarLogin(Map<String, dynamic>.from(raw as Map));
      
    } on AuthException catch (error) {
      String mensagemErro = 'Erro ao fazer login.';
      final msg = error.message.toLowerCase();
      
      if (msg.contains('invalid')) {
        mensagemErro = 'E-mail ou senha incorretos.';
      } else if (msg.contains('email not confirmed')) {
        mensagemErro = 'E-mail não confirmado.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensagemErro),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro inesperado: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background_login9.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned(
            top: 80,
            left: 80,
            child: Image.asset('assets/logo_top_login20.png'),
          ),
          Center(
            child: Container(
              width: 380,
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: AutofillGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Entre com suas credenciais",
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 30),
                    TextField(
                      controller: emailController,
                      autofillHints: const [AutofillHints.username, AutofillHints.email],
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'E-mail',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: passwordController,
                      obscureText: _obscureText,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => _isLoading ? null : loginUser(),
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureText
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () =>
                              setState(() => _obscureText = !_obscureText),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A4B78),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isLoading ? null : loginUser,
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                'Entrar',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.white),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const EsqueciSenhaPage()),
                        );
                      },
                      child: const Text(
                        "Esqueci minha senha",
                        style: TextStyle(color: Color(0xFF0A4B78)),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const CadastroNovoUsuarioPage()),
                        );
                      },
                      child: const Text(
                        "Me cadastrar",
                        style: TextStyle(color: Color(0xFF0A4B78)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'PowerTank Terminais 2026, All rights reserved.',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Licenciado e comercializado por Metabots Business Intelligence - Rua Leais Paulistanos, 416 - Ipiranga - São Paulo, SP | Uma iniciativa © Norton Technology',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}