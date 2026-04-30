import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../login_page.dart'; // Para acessar UsuarioAtual

class ControleAcessoUsuarios extends StatefulWidget {
  final VoidCallback onVoltar;

  const ControleAcessoUsuarios({super.key, required this.onVoltar});

  @override
  State<ControleAcessoUsuarios> createState() => _ControleAcessoUsuariosState();
}

class _ControleAcessoUsuariosState extends State<ControleAcessoUsuarios> {
  final supabase = Supabase.instance.client;
  final TextEditingController _buscaController = TextEditingController();
  final TextEditingController _buscaCardsController = TextEditingController();

  bool carregando = true;
  bool exibindoCards = false;
  bool acessoNegado = false;
  bool carregandoCards = false;

  List<Map<String, dynamic>> usuarios = [];
  List<Map<String, dynamic>> usuariosFiltrados = [];
  List<Map<String, dynamic>> cards = [];
  List<Map<String, dynamic>> cardsFiltrados = [];
  Map<String, bool> permissoes = {};
  String? usuarioSelecionadoId;
  String? usuarioSelecionadoNome;
  String? moduloSelecionado;

  @override
  void initState() {
    super.initState();
    _carregarUsuarios();
  }

  void _filtrarUsuarios(String query) {
    setState(() {
      if (query.isEmpty) {
        usuariosFiltrados = usuarios;
        return;
      }

      final nivelBusca = int.tryParse(query);

      if (nivelBusca != null && (nivelBusca >= 1 && nivelBusca <= 3)) {
        usuariosFiltrados =
            usuarios.where((u) => u['nivel'].toString() == query).toList();
      } else {
        usuariosFiltrados = usuarios
            .where((u) =>
                u['nome']
                    .toString()
                    .toLowerCase()
                    .contains(query.toLowerCase()) ||
                u['email']
                    .toString()
                    .toLowerCase()
                    .contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  // Filtrar cards por nome
  void _filtrarCards(String query) {
    setState(() {
      if (query.isEmpty) {
        cardsFiltrados = cards;
        return;
      }

      final queryLower = query.toLowerCase();

      cardsFiltrados = cards
          .where((card) {
            final nome = card['nome']?.toString() ?? '';
            return nome.toLowerCase().contains(queryLower);
          })
          .toList();
    });
  }

  Future<void> _carregarUsuarios() async {
    setState(() {
      carregando = true;
      acessoNegado = false;
    });

    try {
      final usuarioAtual = UsuarioAtual.instance;
      if (usuarioAtual == null) {
        acessoNegado = true;
        return;
      }

      final nivel = usuarioAtual.nivel;
      final filialId = usuarioAtual.filialId;

      if (nivel == 1) {
        acessoNegado = true;
        return;
      }

      var query = supabase.from('usuarios').select('id, nome, email, nivel');

      if (nivel == 2) {
        if (filialId == null || filialId.isEmpty) {
          acessoNegado = true;
          return;
        }
        query = query.eq('nivel', 1).eq('id_filial', filialId);
      }

      final response = await query.order('nome', ascending: true);

      setState(() {
        usuarios = List<Map<String, dynamic>>.from(response);
        usuariosFiltrados = usuarios;
      });
    } catch (e) {
      debugPrint('Erro ao carregar usuários: $e');
    } finally {
      setState(() => carregando = false);
    }
  }

  // Carregar todos os cards ativos e permissões do usuário
  Future<void> _carregarCards(String usuarioId, String usuarioNome) async {
    setState(() {
      exibindoCards = true;
      usuarioSelecionadoId = usuarioId;
      usuarioSelecionadoNome = usuarioNome;
      carregandoCards = true;
    });

    try {
      // 1. Carregar todos os cards ativos do banco (id, nome e modulo)
      final cardsData = await supabase
          .from('cards')
          .select('id, nome, modulo')
          .eq('ativo', true)
          .order('modulo', ascending: true)
          .order('ordem', ascending: true);

      // 2. Carregar permissões deste usuário
      final permissoesData = await supabase
          .from('permissoes')
          .select('id_sessao, permitido')
          .eq('id_usuario', usuarioId);

      // 3. Criar mapa de permissões (id_card → permitido)
      Map<String, bool> mapaPermissoes = {};

      for (var card in cardsData) {
        final cardId = card['id'].toString();
        final permissaoEncontrada = permissoesData.firstWhere(
          (p) => p['id_sessao'] == cardId,
          orElse: () => {'permitido': false},
        );
        mapaPermissoes[cardId] = permissaoEncontrada['permitido'] ?? false;
      }

      // 4. Preparar lista de cards com modulo
      List<Map<String, dynamic>> listaCards = [];

      for (var card in cardsData) {
        final cardId = card['id'].toString();
        listaCards.add({
          'id': cardId,
          'nome': card['nome'],
          'modulo': card['modulo'] ?? 'Sem Módulo',
          'permitido': mapaPermissoes[cardId] ?? false,
        });
      }

      setState(() {
        cards = listaCards;
        cardsFiltrados = listaCards;
        permissoes = mapaPermissoes;
        
        // Definir módulo padrão se houver
        if (listaCards.isNotEmpty) {
          final modulosValidos = listaCards
              .map((c) => c['modulo'] as String)
              .toSet()
              .toList()
            ..sort();
          moduloSelecionado = modulosValidos.first;
        } else {
          moduloSelecionado = null;
        }
      });
    } catch (e) {
      debugPrint('❌ Erro ao carregar cards: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao carregar cards: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => carregandoCards = false);
    }
  }

  // Atualizar permissão de um card específico
  Future<void> _atualizarPermissaoCard(String cardId, bool permitido) async {
    if (usuarioSelecionadoId == null) return;

    try {
      // Verificar se já existe uma permissão para este card e usuário
      final existente = await supabase
          .from('permissoes')
          .select('id')
          .eq('id_usuario', usuarioSelecionadoId!)
          .eq('id_sessao', cardId)
          .maybeSingle();

      if (permitido) {
        // Se precisa dar permissão
        if (existente == null) {
          // Inserir nova permissão
          await supabase.from('permissoes').insert({
            'id_usuario': usuarioSelecionadoId!,
            'id_sessao': cardId,
            'permitido': true,
          });
        } else {
          // Atualizar permissão existente
          await supabase
              .from('permissoes')
              .update({'permitido': true})
              .eq('id', existente['id']);
        }
      } else {
        // Se precisa REMOVER permissão
        if (existente != null) {
          await supabase.from('permissoes').delete().eq('id', existente['id']);
        }
      }

      // Atualizar estado local
      setState(() {
        permissoes[cardId] = permitido;
        
        // Atualizar também no array de cards
        final index = cards.indexWhere((c) => c['id'] == cardId);
        if (index != -1) {
          cards[index]['permitido'] = permitido;
        }
        
        // Atualizar cards filtrados
        final filtradoIndex = cardsFiltrados.indexWhere((c) => c['id'] == cardId);
        if (filtradoIndex != -1) {
          cardsFiltrados[filtradoIndex]['permitido'] = permitido;
        }
      });

    } catch (e) {
      debugPrint("❌ Erro ao atualizar permissão do card: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao atualizar permissão: $e'),
          backgroundColor: Colors.red,
        ),
      );
      
      // Reverter mudança no estado em caso de erro
      setState(() {
        permissoes[cardId] = !permitido;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (carregando) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF0D47A1)));
    }

    if (acessoNegado) {
      return const Center(
        child: Text("Você não tem permissão para acessar esta tela.",
            style: TextStyle(fontSize: 16, color: Colors.red)),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: exibindoCards ? _buildListaCards() : _buildListaUsuarios(),
    );
  }

  // ======================
  // LISTA DE USUÁRIOS
  // ======================
  Widget _buildListaUsuarios() {
    return Container(
      key: const ValueKey('lista_usuarios'),
      padding: const EdgeInsets.all(30),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
                onPressed: widget.onVoltar,
              ),
              const Text(
                "Controle de acesso — Usuários",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1)),
              ),
              const Spacer(),
              SizedBox(
                width: 300,
                child: TextField(
                  controller: _buscaController,
                  onChanged: _filtrarUsuarios,
                  decoration: InputDecoration(
                    hintText: "Nome, e-mail ou nível (1,2,3)...",
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    border:
                        OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: usuariosFiltrados.isEmpty
                ? const Center(
                    child: Text('Nenhum usuário encontrado.',
                        style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: usuariosFiltrados.length,
                    itemBuilder: (context, index) {
                      final u = usuariosFiltrados[index];
                      return ListTile(
                        leading: Icon(
                          Icons.person,
                          color: u['nivel'] == 3 
                            ? Colors.red 
                            : u['nivel'] == 2 
                              ? Colors.orange 
                              : Colors.blue,
                        ),
                        title: Text(u['nome'],
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(u['email'] ?? 'Sem e-mail'),
                            Text(
                              'Nível ${u['nivel']} - ${_getNivelDescricao(u['nivel'])}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        trailing:
                            const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () =>
                            _carregarCards(u['id'], u['nome']),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _getNivelDescricao(int nivel) {
    switch (nivel) {
      case 1:
        return 'Operador';
      case 2:
        return 'Supervisor';
      case 3:
        return 'Administrador';
      default:
        return 'Desconhecido';
    }
  }

  // ======================
  // LISTA DE CARDS
  // ======================
  Widget _buildListaCards() {
    if (carregandoCards) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF0D47A1)),
      );
    }

    return Container(
      key: const ValueKey('lista_cards'),
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
                onPressed: () => setState(() {
                  exibindoCards = false;
                  usuarioSelecionadoId = null;
                }),
              ),
              Expanded(
                child: Text(
                  "Permissões — ${usuarioSelecionadoNome ?? ''}",
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D47A1)),
                ),
              ),
              SizedBox(
                width: 300,
                child: TextField(
                  controller: _buscaCardsController,
                  onChanged: _filtrarCards,
                  decoration: InputDecoration(
                    hintText: "Buscar por nome do card...",
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    border:
                        OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
          const Divider(),
          
          Expanded(
            child: _buildConteudoCards(),
          ),
        ],
      ),
    );
  }

  // Conteúdo dos módulos como ExpansionTiles (Acordeão)
  Widget _buildConteudoCards() {
    if (cardsFiltrados.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 60, color: Colors.grey),
            SizedBox(height: 10),
            Text(
              'Nenhum card encontrado',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Obter lista única de módulos
    final modulos = cardsFiltrados
        .map((c) => c['modulo'] as String)
        .toSet()
        .toList()
      ..sort();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: modulos.length,
      itemBuilder: (context, index) {
        final modulo = modulos[index];
        final cardsDoModulo = cardsFiltrados
            .where((c) => c['modulo'] == modulo)
            .toList();
        
        final todosPermitidos = cardsDoModulo.isNotEmpty && 
                                cardsDoModulo.every((c) => c['permitido'] == true);

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ExpansionTile(
            key: PageStorageKey(modulo),
            title: Text(
              modulo,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Color(0xFF0D47A1),
              ),
            ),
            subtitle: Text(
              '${cardsDoModulo.length} cards',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            leading: Icon(
              Icons.folder_open,
              color: todosPermitidos ? Colors.green : const Color(0xFF0D47A1),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    todosPermitidos ? Icons.done_all : Icons.playlist_add_check,
                    color: todosPermitidos ? Colors.green : Colors.grey,
                    size: 20,
                  ),
                  tooltip: todosPermitidos ? 'Desmarcar Todos' : 'Marcar Todos',
                  onPressed: () {
                    // Chamamos a função passando o módulo específico
                    _alternarTodosModuloNoExpansion(modulo, !todosPermitidos);
                  },
                ),
                const Icon(Icons.expand_more),
              ],
            ),
            children: [
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _alternarTodosModuloNoExpansion(modulo, true),
                      icon: const Icon(Icons.check_circle_outline, size: 18, color: Colors.green),
                      label: const Text("Marcar Todos", style: TextStyle(color: Colors.green, fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _alternarTodosModuloNoExpansion(modulo, false),
                      icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.red),
                      label: const Text("Desmarcar Todos", style: TextStyle(color: Colors.red, fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ...cardsDoModulo.map((card) => _buildCardItem(card)).toList(),
            ],
          ),
        );
      },
    );
  }

  // Marcar ou desmarcar todos os cards de um módulo específico
  Future<void> _alternarTodosModuloNoExpansion(String modulo, bool marcar) async {
    if (usuarioSelecionadoId == null) return;

    final cardsDoModulo = cardsFiltrados
        .where((c) => c['modulo'] == modulo)
        .toList();

    if (cardsDoModulo.isEmpty) return;

    try {
      for (var card in cardsDoModulo) {
        if (card['permitido'] != marcar) {
          await _atualizarPermissaoCard(card['id'], marcar);
        }
      }
    } catch (e) {
      debugPrint("❌ Erro ao alternar permissões em massa: $e");
    }
  }

  // Widget para item individual do card
  Widget _buildCardItem(Map<String, dynamic> card) {
    final permitido = card['permitido'] ?? false;

    return InkWell(
      onTap: () async {
        await _atualizarPermissaoCard(card['id'], !permitido);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        color: permitido ? Colors.green.shade50.withOpacity(0.3) : Colors.transparent,
        child: Row(
          children: [
            Expanded(
              child: Text(
                card['nome'] ?? 'Sem nome',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: permitido ? FontWeight.w500 : FontWeight.normal,
                  color: permitido
                      ? const Color(0xFF2E7D32)
                      : Colors.grey.shade800,
                ),
              ),
            ),
            Transform.scale(
              scale: 0.8,
              child: Checkbox(
                value: permitido,
                activeColor: const Color(0xFF2E7D32),
                onChanged: (valor) async {
                  if (valor == null) return;
                  await _atualizarPermissaoCard(card['id'], valor);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

}