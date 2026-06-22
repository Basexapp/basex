import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';
import 'configuracoes/alterar_senha.dart';

class PerfilPage extends StatefulWidget {
  const PerfilPage({super.key});

  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  final supabase = Supabase.instance.client;

  String email = "";
  String nivelTexto = "";
  String terminalNome = "";
  String empresaNome = "";
  bool carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarPerfil();
  }

  Future<void> _carregarPerfil() async {
    final usuario = UsuarioAtual.instance;

    if (usuario == null) {
      setState(() => carregando = false);
      return;
    }

    try {
        final dados = await supabase
          .from('usuarios')
          .select('email, nivel, terminal_id, empresa_id')
          .eq('id', usuario.id)
          .maybeSingle();

      if (dados != null) {
        email = dados['email'] ?? "";
        final nivel = dados['nivel'] ?? 1;
        nivelTexto = _traduzirNivel(nivel);

        final terminalId = dados['terminal_id'];
        final empresaId = dados['empresa_id'];

        // Apenas para usuários nível 1 ou 2 mostramos o terminal e a empresa
        if (nivel == 1 || nivel == 2) {
          if (terminalId != null) {
            final fil = await supabase
                .from('terminais')
                .select('nome')
                .eq('id', terminalId)
                .maybeSingle();

            terminalNome = fil?['nome'] ?? "Não encontrada";
          } else {
            terminalNome = "Nenhuma";
          }

          if (empresaId != null) {
            final emp = await supabase
                .from('empresas')
                .select('nome_abrev')
                .eq('id', empresaId)
                .maybeSingle();

            empresaNome = emp?['nome_abrev'] ?? "Não encontrada";
          } else {
            empresaNome = "Nenhuma";
          }
        } else {
          // Nível 3: não mostrar campo
          terminalNome = "";
          empresaNome = "";
        }
      }
    } catch (e) {
      debugPrint("❌ Erro ao carregar perfil: $e");
      terminalNome = "Erro ao carregar";
    }

    if (mounted) {
      setState(() => carregando = false);
    }
  }

  String _traduzirNivel(int nivel) {
    switch (nivel) {
      case 1:
        return "Logística / Operações";
      case 2:
        return "Gerência / Supervisão";
      case 3:
        return "Diretoria / Administração";
      default:
        return "Nível desconhecido";
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = UsuarioAtual.instance;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Meu perfil",
            style: TextStyle(color: Color(0xFF0D47A1))),
        elevation: 1,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Color(0xFF0D47A1)),
      ),

      body: carregando
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D47A1)))
          : Center(
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

                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 45,
                      backgroundColor: Colors.blue.shade100,
                      child: const Icon(Icons.person,
                          size: 60, color: Color(0xFF0D47A1)),
                    ),

                    const SizedBox(height: 20),

                    Text(
                      usuario?.nome ?? "Usuário",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D47A1),
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      email,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),

                    const SizedBox(height: 25),

                    _infoBox("Nível de acesso", nivelTexto),
                    if ((usuario?.nivel ?? 0) == 1 || (usuario?.nivel ?? 0) == 2) ...[
                      _infoBox("Terminal", terminalNome),
                      _infoBox("Empresa", empresaNome),
                    ],

                    const SizedBox(height: 30),

                    SizedBox(
                      width: 240,
                      height: 45,
                      child: ElevatedButton(
                        onPressed: () {
                          final isReadOnly = (usuario?.nivel ?? 0) != 3;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditarPerfilPage(readOnly: isReadOnly),
                            ),
                          ).then((_) => _carregarPerfil());
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D47A1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          (usuario?.nivel ?? 0) != 3 ? "Visualizar dados" : "Editar perfil",
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    SizedBox(
                      width: 240,
                      height: 45,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => AlterarSenhaPage()),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF0D47A1)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text("Alterar senha",
                            style: TextStyle(color: Color(0xFF0D47A1))),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _infoBox(String titulo, String valor) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade100,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(titulo,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0D47A1))),
          Text(valor, style: const TextStyle(color: Colors.black87)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//                    🌟 TELA DE EDITAR PERFIL
// ---------------------------------------------------------------------------

class EditarPerfilPage extends StatefulWidget {
  final bool readOnly;

  const EditarPerfilPage({super.key, this.readOnly = false});

  @override
  State<EditarPerfilPage> createState() => _EditarPerfilPageState();
}

class _EditarPerfilPageState extends State<EditarPerfilPage> {
  final supabase = Supabase.instance.client;

  final nome = TextEditingController();
  final email = TextEditingController();
  final celular = TextEditingController();
  final funcao = TextEditingController();
  final empresa = TextEditingController();

  List<Map<String, dynamic>> terminais = [];
  String? terminalSelecionada;

  bool carregando = true;

  @override
  void initState() {
    super.initState();
    carregarDados();
  }

  Future<void> carregarDados() async {
    final usuario = UsuarioAtual.instance!;

    try {
      // ----------------------------------------------------------
      // 1️⃣ Buscar DADOS DO USUÁRIO
      // ----------------------------------------------------------
        final dados = await supabase
          .from('usuarios')
          .select('nome, email, celular, funcao, terminal_id, empresa_id')
          .eq('id', usuario.id)
          .maybeSingle();


      if (dados != null) {
        nome.text = dados['nome'] ?? "";
        email.text = dados['email'] ?? "";
        celular.text = dados['celular'] ?? "";
        funcao.text = dados['funcao'] ?? "";

        // 🔹 Convertendo terminal_id para String
        terminalSelecionada = dados['terminal_id']?.toString();

        // 🔹 Carregar nome abreviado da empresa (se existir)
        final empresaId = dados['empresa_id'];
        if (empresaId != null) {
          final emp = await supabase
              .from('empresas')
              .select('nome_abrev')
              .eq('id', empresaId)
              .maybeSingle();

          empresa.text = emp?['nome_abrev'] ?? "";
        }
      }

      // ----------------------------------------------------------
      // 2️⃣ Buscar LISTA DE TERMINAIS (quando aplicável)
      // ----------------------------------------------------------
      final lista = await supabase.from("terminais").select("id, nome");
      terminais = List<Map<String, dynamic>>.from(lista);

      // ----------------------------------------------------------
      // 3️⃣ Se o terminal do usuário existir, garantir que ele apareça selecionado
      // ----------------------------------------------------------
      if (terminalSelecionada != null) {
        final existe = terminais.any((f) => f['id'].toString() == terminalSelecionada);
        if (!existe) {
          terminalSelecionada = null; // evita erro no dropdown
        }
      }

    } catch (e) {
      debugPrint("Erro ao carregar dados: $e");
    }

    setState(() => carregando = false);
  }

  Future<void> salvar() async {
    final usuario = UsuarioAtual.instance!;

    try {
      await supabase.from('usuarios').update({
        'nome': nome.text,
        'email': email.text,
        'celular': celular.text,
        'funcao': funcao.text,
        'terminal_id': terminalSelecionada,
      }).eq('id', usuario.id);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Perfil atualizado com sucesso!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("Erro ao salvar: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Erro ao salvar alterações."),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.readOnly ? "Visualizar perfil" : "Editar perfil",
          style: const TextStyle(color: Color(0xFF0D47A1)),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Color(0xFF0D47A1)),
      ),

      body: carregando
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D47A1)))
          : Center(
              child: Container(
                width: 550,
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _campoTexto("Nome completo", nome, true),
                    _campoTexto("Email", email, true),
                    _campoTexto("Celular", celular, widget.readOnly),
                    _campoTexto("Função", funcao, widget.readOnly),
                    _campoTexto("Empresa", empresa, true),

                    const SizedBox(height: 10),
                    // Mostrar seleção de terminal apenas para níveis 1 e 2
                    if (UsuarioAtual.instance != null && (UsuarioAtual.instance!.nivel == 1 || UsuarioAtual.instance!.nivel == 2))
                      _dropFiliais(),

                    const SizedBox(height: 25),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 150,
                          height: 45,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF0D47A1)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              widget.readOnly ? "Voltar" : "Cancelar",
                              style: const TextStyle(color: Color(0xFF0D47A1)),
                            ),
                          ),
                        ),
                        if (!widget.readOnly) ...[
                          const SizedBox(width: 20),
                          SizedBox(
                            width: 180,
                            height: 45,
                            child: ElevatedButton(
                              onPressed: salvar,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E7D32),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text("Salvar alterações",
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ]
                      ],
                    )
                  ],
                ),
              ),
            ),
    );
  }

  Widget _campoTexto(String label, TextEditingController controller, bool bloqueado) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        enabled: !bloqueado,
        decoration: InputDecoration(
          labelText: label,
          filled: bloqueado,
          fillColor: bloqueado ? const Color.fromARGB(255, 245, 245, 245) : null,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _dropFiliais() {
    return DropdownButtonFormField<String>(
      initialValue: terminalSelecionada,
      decoration: InputDecoration(
        labelText: "Terminal",
        filled: widget.readOnly,
        fillColor: widget.readOnly ? const Color.fromARGB(255, 245, 245, 245) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      items: terminais.map((f) {
        return DropdownMenuItem<String>(
          value: f['id'].toString(),
          child: Text(f['nome'].toString()),
        );
      }).toList(),
      onChanged: widget.readOnly ? null : (v) => setState(() => terminalSelecionada = v),
    );
  }
}