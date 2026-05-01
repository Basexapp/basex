import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AlterarSenhaPage extends StatefulWidget {
  const AlterarSenhaPage({super.key});

  @override
  State<AlterarSenhaPage> createState() => _AlterarSenhaPageState();
}

class _AlterarSenhaPageState extends State<AlterarSenhaPage> {
  final supabase = Supabase.instance.client;
  
  final _formKey = GlobalKey<FormState>();
  final _senhaAtualController = TextEditingController();
  final _novaSenhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();
  
  bool _carregando = false;
  bool _mostrarSenhaAtual = false;
  bool _mostrarNovaSenha = false;
  bool _mostrarConfirmarSenha = false;

  @override
  void dispose() {
    _senhaAtualController.dispose();
    _novaSenhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  Future<void> _alterarSenha() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _carregando = true);

    try {
      final usuario = supabase.auth.currentUser;
      if (usuario == null) {
        throw Exception('Usuário não autenticado');
      }

      // Verificar senha atual
      final email = usuario.email;
      if (email == null) {
        throw Exception('Email do usuário não encontrado');
      }

      // Tentar fazer sign in com a senha atual para verificar
      try {
        await supabase.auth.signInWithPassword(
          email: email,
          password: _senhaAtualController.text,
        );
      } catch (e) {
        throw Exception('Senha atual incorreta');
      }

      // Verificar se as novas senhas coincidem
      if (_novaSenhaController.text != _confirmarSenhaController.text) {
        throw Exception('As novas senhas não coincidem');
      }

      // Chamar a edge function para alterar a senha
      final response = await supabase.functions.invoke('alterar-senha', 
        body: {
          'nova_senha': _novaSenhaController.text,
        }
      );

      // ✅ CORREÇÃO: Verificar erro baseado na estrutura da sua edge function
      final data = response.data;
      if (data != null && data['success'] == false) {
        throw Exception(data['error'] ?? 'Erro ao alterar senha');
      }

      // Sucesso
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Senha alterada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  String? _validarSenha(String? value) {
    if (value == null || value.isEmpty) {
      return 'Este campo é obrigatório';
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
      appBar: AppBar(
        title: const Text(
          "Alterar Senha",
          style: TextStyle(color: Color(0xFF0D47A1)),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Color(0xFF0D47A1)),
      ),
      body: Center(
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 2),
              )
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 60,
                  color: Color(0xFF0D47A1),
                ),
                
                const SizedBox(height: 20),
                
                const Text(
                  "Alterar Senha",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                  ),
                ),
                
                const SizedBox(height: 10),
                
                const Text(
                  "Digite sua senha atual e a nova senha desejada",
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 30),

                // Senha Atual
                TextFormField(
                  controller: _senhaAtualController,
                  obscureText: !_mostrarSenhaAtual,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Este campo é obrigatório';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: "Senha Atual",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _mostrarSenhaAtual ? Icons.visibility : Icons.visibility_off,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() => _mostrarSenhaAtual = !_mostrarSenhaAtual);
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Nova Senha
                TextFormField(
                  controller: _novaSenhaController,
                  obscureText: !_mostrarNovaSenha,
                  validator: _validarSenha,
                  decoration: InputDecoration(
                    labelText: "Nova Senha",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _mostrarNovaSenha ? Icons.visibility : Icons.visibility_off,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() => _mostrarNovaSenha = !_mostrarNovaSenha);
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Confirmar Nova Senha
                TextFormField(
                  controller: _confirmarSenhaController,
                  obscureText: !_mostrarConfirmarSenha,
                  validator: _validarConfirmacaoSenha,
                  decoration: InputDecoration(
                    labelText: "Confirmar Nova Senha",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _mostrarConfirmarSenha ? Icons.visibility : Icons.visibility_off,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() => _mostrarConfirmarSenha = !_mostrarConfirmarSenha);
                      },
                    ),
                  ),
                ),
                
                const SizedBox(height: 30),
                
                if (_carregando)
                  const CircularProgressIndicator(color: Color(0xFF0D47A1))
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 150,
                        height: 45,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.grey),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            "Cancelar",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),

                      const SizedBox(width: 20),

                      SizedBox(
                        width: 180,
                        height: 45,
                        child: ElevatedButton(
                          onPressed: _alterarSenha,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            "Alterar Senha",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}