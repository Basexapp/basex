import 'dart:ui';
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
                image: AssetImage('assets/background-login.png'),
                fit: BoxFit.fill,
              ),
            ),
          ),
          Positioned(
            top: 80,
            left: 80,
            child: Image.asset('assets/logo-top-login.png'),
          ),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  width: 420,
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1.5,
                    ),
                  ),
                  child: AutofillGroup(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "Entre com suas credenciais",
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 25),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "E-mail",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: emailController,
                          autofillHints: const [
                            AutofillHints.username,
                            AutofillHints.email
                          ],
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            hintText: 'Digite seu e-mail',
                            hintStyle: const TextStyle(color: Colors.black54, fontWeight: FontWeight.bold, fontSize: 13),
                            prefixIcon: const Icon(Icons.email_outlined,
                                color: Colors.black),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide:
                                  const BorderSide(color: Colors.black12, width: 1.0),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: const BorderSide(color: Colors.black26),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "Senha",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: passwordController,
                          obscureText: _obscureText,
                          autofillHints: const [AutofillHints.password],
                          onSubmitted: (_) => _isLoading ? null : loginUser(),
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            hintText: 'Digite sua senha',
                            hintStyle: const TextStyle(color: Colors.black54, fontWeight: FontWeight.bold, fontSize: 13),
                            prefixIcon: const Icon(Icons.lock_outline,
                                color: Colors.black),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureText
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: Colors.black,
                              ),
                              onPressed: () =>
                                  setState(() => _obscureText = !_obscureText),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide:
                                  const BorderSide(color: Colors.black12, width: 1.0),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: const BorderSide(color: Colors.black26),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            style: ButtonStyle(
                              backgroundColor:
                                  WidgetStateProperty.resolveWith<Color?>((states) {
                                    if (states.contains(WidgetState.hovered)) {
                                      return const Color.fromARGB(255, 65, 54, 49);
                                    }
                                    return Colors.black;
                                  }),
                              foregroundColor: WidgetStateProperty.all<Color>(
                                Colors.white,
                              ),
                              padding: WidgetStateProperty.all(
                                const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 16,
                                ),
                              ),
                              shape: WidgetStateProperty.all(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: const BorderSide(
                                    color: Color(0xFFFFB341),
                                    width: 1.6,
                                  ),
                                ),
                              ),
                              elevation: WidgetStateProperty.all(1),
                            ),
                            onPressed: _isLoading ? null : loginUser,
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : const Text(
                                    'Entrar',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 25),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const EsqueciSenhaPage()),
                            );
                          },
                          style: TextButton.styleFrom(
                            overlayColor: Colors.white.withOpacity(0.15),
                          ),
                          child: const Text(
                            "Esqueci minha senha",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
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
                          style: TextButton.styleFrom(
                            overlayColor: Colors.white.withOpacity(0.15),
                          ),
                          child: const Text(
                            "Me cadastrar",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                  Text.rich(
                    TextSpan(
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                      children: [
                        const TextSpan(text: 'PowerTank'),
                        WidgetSpan(
                          child: Transform.translate(
                            offset: const Offset(0, -5),
                            child: Text(
                              '®',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.grey.shade400,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                        const TextSpan(text: ' 2026, All rights reserved.'),
                      ],
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