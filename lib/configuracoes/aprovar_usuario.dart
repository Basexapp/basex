import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class AprovarUsuarioPage extends StatefulWidget {
  final VoidCallback onVoltar;
  final Map<String, dynamic> usuario;

  const AprovarUsuarioPage({
    super.key,
    required this.onVoltar,
    required this.usuario,
  });

  @override
  State<AprovarUsuarioPage> createState() => _AprovarUsuarioPageState();
}

class _AprovarUsuarioPageState extends State<AprovarUsuarioPage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  bool _salvando = false;

  String? filialSelecionada;
  String? nivelSelecionado;

  List<Map<String, dynamic>> _filiais = [];

  final nomeController = TextEditingController();
  final emailController = TextEditingController();
  final celularController = TextEditingController();
  final funcaoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _carregarFiliais();
    _preencherCampos();
  }

  void _preencherCampos() {
    final u = widget.usuario;
    nomeController.text = u['nome'] ?? '';
    emailController.text = u['email'] ?? '';
    celularController.text = u['celular'] ?? '';
    funcaoController.text = u['funcao'] ?? '';

    // UUID vem como string
    filialSelecionada = u['id_filial']?.toString();
  }

  Future<void> _carregarFiliais() async {
    try {
      final res = await supabase.from('filiais').select('id, nome');

      setState(() {
        _filiais = List<Map<String, dynamic>>.from(res);
      });
    } catch (e) {
      debugPrint("Erro ao carregar filiais: $e");
    }
  }

  Future<void> _aprovarUsuario() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);

    try {
      final nome = nomeController.text.trim();
      final email = emailController.text.trim();
      final celular = celularController.text.trim();
      final funcao = funcaoController.text.trim();

      final uuidFilial = filialSelecionada;

      final int nivel =
          nivelSelecionado == "Gerência e supervisão ♦ Nível 2" ||
                  nivelSelecionado == "Diretoria e Administração ♦ Nível 3"
              ? 2
              : 1;

      const url =
          "https://ikaxzlpaihdkqyjqrxyw.functions.supabase.co/aprovar-usuario";

      final session = supabase.auth.currentSession;

      if (session == null) {
        throw Exception("Usuário não autenticado");
      }

      final response = await http.post(
        Uri.parse(url),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${session.accessToken}",
        },
        body: jsonEncode({
          "nome": nome,
          "email": email,
          "celular": celular,
          "funcao": funcao,
          "id_filial": uuidFilial,
          "nivel": nivel,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(
            "Erro HTTP ${response.statusCode}: ${response.body}");
      }

      final result = jsonDecode(response.body);

      if (result['success'] == true) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Usuário aprovado com sucesso!\nA senha temporária foi enviada para: $email",
              textAlign: TextAlign.center,
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );

        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) widget.onVoltar();
        });
      } else {
        throw Exception(result['error'] ?? "Erro ao aprovar usuário");
      }
    } catch (e) {
      debugPrint("Erro ao aprovar usuário: $e");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erro ao aprovar usuário:\n$e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(30),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
                  onPressed: widget.onVoltar,
                ),
                const Text(
                  "Aprovar Usuário",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                  ),
                ),
              ],
            ),

            const Divider(),
            const SizedBox(height: 20),

            _campoEditavel("Nome completo", nomeController),
            _campoEditavel("E-mail", emailController,
                tipo: TextInputType.emailAddress),
            _campoEditavel("Celular", celularController,
                tipo: TextInputType.phone),
            _campoEditavel("Função / Cargo", funcaoController),

            // 🔥 APENAS UM DROPDOWN – CORRETO E FUNCIONAL
            DropdownButtonFormField<String>(
              value: (_filiais.any((f) => f['id'].toString() == filialSelecionada))
                  ? filialSelecionada
                  : null,
              decoration: const InputDecoration(
                labelText: "Filial",
                border: OutlineInputBorder(),
              ),
              items: _filiais
                  .map((f) => DropdownMenuItem<String>(
                        value: f['id'].toString(),
                        child: Text(f['nome']),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => filialSelecionada = v),
              validator: (v) =>
                  v == null ? "Selecione uma filial" : null,
            ),

            const SizedBox(height: 20),

            DropdownButtonFormField<String>(
              value: (const [
                "Logística / Operações ♦ Nível 1",
                "Gerência e supervisão ♦ Nível 2",
                "Diretoria e Administração ♦ Nível 3"
              ].contains(nivelSelecionado))
                  ? nivelSelecionado
                  : null,
              decoration: const InputDecoration(
                labelText: "Nível de acesso",
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: "Logística / Operações ♦ Nível 1",
                  child: Text("Logística / Operações ♦ Nível 1"),
                ),
                DropdownMenuItem(
                  value: "Gerência e supervisão ♦ Nível 2",
                  child: Text("Gerência e supervisão ♦ Nível 2"),
                ),
                DropdownMenuItem(
                  value: "Diretoria e Administração ♦ Nível 3",
                  child: Text("Diretoria e Administração ♦ Nível 3"),
                ),
              ],
              onChanged: (v) => setState(() => nivelSelecionado = v),
              validator: (v) => v == null ? "Selecione o nível de acesso" : null,
            ),

            const SizedBox(height: 30),

            _mensagemSenha(),

            const SizedBox(height: 30),

            Center(
              child: ElevatedButton.icon(
                onPressed: _salvando ? null : _aprovarUsuario,
                icon: _salvando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.check_circle, color: Colors.white),
                label: Text(_salvando ? "Aprovando..." : "Aprovar Usuário"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 50, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _campoEditavel(
    String label,
    TextEditingController controller, {
    TextInputType tipo = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: tipo,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (v) => v == null || v.isEmpty ? "Preencha este campo" : null,
      ),
    );
  }

  Widget _mensagemSenha() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.vpn_key, color: Colors.green[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Uma senha temporária será gerada automaticamente e enviada por e-mail ao usuário.\n"
              "Ele deverá alterá-la no primeiro acesso.",
              style: TextStyle(
                color: Colors.green[800],
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    nomeController.dispose();
    emailController.dispose();
    celularController.dispose();
    funcaoController.dispose();
    super.dispose();
  }
}
