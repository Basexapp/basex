import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RedefinirSenhaPage extends StatefulWidget {
  const RedefinirSenhaPage({super.key});

  @override
  State<RedefinirSenhaPage> createState() => _RedefinirSenhaPageState();
}

class _RedefinirSenhaPageState extends State<RedefinirSenhaPage> {
  final TextEditingController _novaSenhaController = TextEditingController();
  final TextEditingController _confirmarSenhaController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscureText1 = true;
  bool _obscureText2 = true;
  bool _isLoading = false;
  bool _senhaRedefinida = false;

  @override
  void initState() {
    super.initState();
    Supabase.instance.client.auth.onAuthStateChange.listen((event) {});
  }

  Future<void> _redefinirSenha() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;

    try {      
      await supabase.auth.updateUser(
        UserAttributes(password: _novaSenhaController.text.trim()),
      );

      setState(() => _senhaRedefinida = true);

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Senha redefinida com sucesso!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro: ${error.message}'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro inesperado: $error'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  void _irParaLogin() {
    // Limpa toda a pilha de navegação e vai para a tela de login
    Navigator.pushNamedAndRemoveUntil(
      context, 
      '/login', 
      (route) => false,
    );
  }

  String? _validarForcaSenha(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor, digite a nova senha';
    }
    if (value.length < 6) {
      return 'A senha deve ter pelo menos 6 caracteres';
    }
    return null;
  }

  String? _validarConfirmacaoSenha(String? value) {
    if (value != _novaSenhaController.text) {
      return 'As senhas não coincidem';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background_login.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned(
            top: 80,
            left: 80,
            child: Image.asset('assets/logo_top_login.png'),
          ),
          if (!_senhaRedefinida)
            Positioned(
              top: 50,
              left: 20,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          Center(
            child: Container(
              width: 380,
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Icon(
                    _senhaRedefinida ? Icons.check_circle_outline : Icons.lock_outline,
                    size: 64,
                    color: const Color(0xFF0A4B78),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _senhaRedefinida ? 'Senha Redefinida!' : 'Redefinir Senha',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0A4B78),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _senhaRedefinida 
                      ? 'Sua senha foi redefinida com sucesso.'
                      : 'Digite sua nova senha nos campos abaixo',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  if (!_senhaRedefinida) ...[
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _novaSenhaController,
                            obscureText: _obscureText1,
                            decoration: InputDecoration(
                              labelText: 'Nova Senha',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureText1 
                                    ? Icons.visibility_off_outlined 
                                    : Icons.visibility_outlined,
                                ),
                                onPressed: () => setState(() => _obscureText1 = !_obscureText1),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              helperText: 'Mínimo 6 caracteres',
                            ),
                            validator: _validarForcaSenha,
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _confirmarSenhaController,
                            obscureText: _obscureText2,
                            decoration: InputDecoration(
                              labelText: 'Confirmar Nova Senha',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureText2 
                                    ? Icons.visibility_off_outlined 
                                    : Icons.visibility_outlined,
                                ),
                                onPressed: () => setState(() => _obscureText2 = !_obscureText2),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: _validarConfirmacaoSenha,
                          ),
                        ],
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
                        onPressed: _isLoading ? null : _redefinirSenha,
                        child: _isLoading 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Redefinir Senha',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white
                              ),
                            ),
                      ),
                    ),
                  ] else ...[
                    // Estado de sucesso com botão para fazer login
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 80,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Senha redefinida com sucesso.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),
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
                        onPressed: _irParaLogin,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.login, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Fazer login',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextButton(
                      onPressed: _irParaLogin,
                      child: const Text(
                        'Voltar para o login',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF0A4B78),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
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
                    'Base X 2026, All rights reserved.',
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
    _novaSenhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }
}