import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'cadastro_motoristas.dart';

class MotoristasPage extends StatefulWidget {
  final VoidCallback onVoltar;

  const MotoristasPage({
    super.key,
    required this.onVoltar,
  });

  @override
  State<MotoristasPage> createState() => _MotoristasPageState();
}

class _MotoristasPageState extends State<MotoristasPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  List<Map<String, dynamic>> _motoristas = [];
  List<Map<String, dynamic>> _motoristasFiltrados = [];
  bool _carregando = true;
  bool _editando = false;
  Map<String, dynamic>? _motoristaEditando;
  String? _campoEditando;
  final TextEditingController _controller = TextEditingController();
  int _paginaAtual = 0;
  final int _itensPorPagina = 20;
  
  // Controllers para pesquisa
  final TextEditingController _pesquisaController = TextEditingController();
  final FocusNode _pesquisaFocusNode = FocusNode();
  Timer? _debounceTimer;

  // Sistema unificado de larguras (flex values para Row + Expanded)
  static const List<Map<String, dynamic>> _colunasConfig = [
    {'campo': 'nome', 'titulo': 'Nome', 'flex': 3, 'minWidth': 150.0},
    {'campo': 'nome_2', 'titulo': 'Nome 2', 'flex': 2, 'minWidth': 120.0},
    {'campo': 'cpf', 'titulo': 'CPF', 'flex': 2, 'minWidth': 120.0},
    {'campo': 'cnh', 'titulo': 'CNH', 'flex': 2, 'minWidth': 100.0},
    {'campo': 'categoria', 'titulo': 'Categoria CNH', 'flex': 2, 'minWidth': 100.0},
    {'campo': 'telefone', 'titulo': 'Celular', 'flex': 2, 'minWidth': 120.0},
    {'campo': 'telefone_2', 'titulo': 'Celular 2', 'flex': 2, 'minWidth': 120.0},
  ];

  @override
  void initState() {
    super.initState();
    _carregarMotoristas();
    _pesquisaController.addListener(_onPesquisaChanged);
  }

  @override
  void dispose() {
    _pesquisaController.dispose();
    _pesquisaFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onPesquisaChanged() {
    if (_debounceTimer != null) {
      _debounceTimer!.cancel();
    }
    
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _filtrarMotoristas();
    });
  }

  Future<void> _carregarMotoristas() async {
    setState(() => _carregando = true);
    
    try {
      var query = _supabase
          .from('motoristas')
          .select('*')
          .order('nome', ascending: true)
          .order('nome_2', ascending: true);

      final dados = await query;
      
      setState(() {
        _motoristas = List<Map<String, dynamic>>.from(dados);
        _motoristasFiltrados = List.from(_motoristas);
        _carregando = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar motoristas: $e');
      setState(() => _carregando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar motoristas: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _filtrarMotoristas() {
    final termo = _pesquisaController.text.toLowerCase().trim();
    
    if (termo.isEmpty) {
      setState(() {
        _motoristasFiltrados = List.from(_motoristas);
        _paginaAtual = 0;
      });
      return;
    }

    final filtrados = _motoristas.where((motorista) {
      return motorista['nome']?.toString().toLowerCase().contains(termo) == true ||
             motorista['nome_2']?.toString().toLowerCase().contains(termo) == true ||
             motorista['cpf']?.toString().toLowerCase().contains(termo) == true ||
             motorista['cnh']?.toString().toLowerCase().contains(termo) == true ||
             motorista['categoria']?.toString().toLowerCase().contains(termo) == true ||
             motorista['telefone']?.toString().toLowerCase().contains(termo) == true ||
             motorista['telefone_2']?.toString().toLowerCase().contains(termo) == true;
    }).toList();

    setState(() {
      _motoristasFiltrados = filtrados;
      _paginaAtual = 0;
    });
  }

  Future<void> _atualizarCampo(
    String motoristaId,
    String campo,
    dynamic valor,
  ) async {
    try {
      await _supabase
          .from('motoristas')
          .update({campo: valor})
          .eq('id', motoristaId);

      // Atualiza a lista local
      setState(() {
        final index = _motoristas.indexWhere((m) => m['id'] == motoristaId);
        if (index != -1) {
          _motoristas[index][campo] = valor;
        }
        // Atualiza também a lista filtrada
        final indexFiltrado = _motoristasFiltrados.indexWhere((m) => m['id'] == motoristaId);
        if (indexFiltrado != -1) {
          _motoristasFiltrados[indexFiltrado][campo] = valor;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Campo atualizado com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro ao atualizar campo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _iniciarEdicao(Map<String, dynamic> motorista, String campo) {
    setState(() {
      _editando = true;
      _motoristaEditando = motorista;
      _campoEditando = campo;
      _controller.text = motorista[campo]?.toString() ?? '';
    });
  }

  void _finalizarEdicao() {
    if (_motoristaEditando != null && _campoEditando != null) {
      _atualizarCampo(
        _motoristaEditando!['id'],
        _campoEditando!,
        _controller.text,
      );
    }
    
    setState(() {
      _editando = false;
      _motoristaEditando = null;
      _campoEditando = null;
    });
  }

  void _cancelarEdicao() {
    setState(() {
      _editando = false;
      _motoristaEditando = null;
      _campoEditando = null;
    });
  }

  List<Map<String, dynamic>> _getMotoristasPaginados() {
    final inicio = _paginaAtual * _itensPorPagina;
    final fim = inicio + _itensPorPagina;
    return _motoristasFiltrados.sublist(
      inicio.clamp(0, _motoristasFiltrados.length),
      fim.clamp(0, _motoristasFiltrados.length),
    );
  }

  void _abrirCadastroMotorista() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => CadastroMotoristaDialog(
        onCadastroConcluido: () {
          _carregarMotoristas();
          if (mounted) {
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }

  void _limparPesquisa() {
    _pesquisaController.clear();
    _pesquisaFocusNode.unfocus();
    _filtrarMotoristas();
  }

  // Widget para renderizar os cabeçalhos usando a configuração unificada
  Widget _buildCabecalhos() {
    return Row(
      children: _colunasConfig.map((coluna) {
        return Expanded(
          flex: coluna['flex'],
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            constraints: BoxConstraints(minWidth: coluna['minWidth']),
            child: Text(
              coluna['titulo'],
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D47A1),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      }).toList(),
    );
  }

  // Widget para renderizar uma linha da tabela usando a configuração unificada
  Widget _buildLinhaTabela(Map<String, dynamic> motorista, int index) {
    final isEditando = _editando && _motoristaEditando?['id'] == motorista['id'];

    String formatarCPFVisivel(String? cpf) {
      if (cpf == null || cpf.isEmpty) return '-';
      final cpfLimpo = cpf.replaceAll(RegExp(r'[^0-9]'), '');
      if (cpfLimpo.length < 2) return cpfLimpo;
      final ultimosDois = cpfLimpo.substring(cpfLimpo.length - 2);
      return '***.***.***-$ultimosDois';
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: _colunasConfig.map((coluna) {
          final campo = coluna['campo'];
          final isEditandoCampo = isEditando && _campoEditando == campo;
          
          return Expanded(
            flex: coluna['flex'],
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              constraints: BoxConstraints(minWidth: coluna['minWidth']),
              child: isEditandoCampo
                  ? _CelulaEditando(
                      controller: _controller,
                      onSalvar: _finalizarEdicao,
                      onCancelar: _cancelarEdicao,
                    )
                  : MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onDoubleTap: () => _iniciarEdicao(motorista, campo),
                        child: Text(
                          campo == 'cpf'
                              ? formatarCPFVisivel(motorista[campo]?.toString())
                              : (motorista[campo]?.toString().isNotEmpty == true
                                  ? motorista[campo].toString()
                                  : '-'),
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton(
        onPressed: _abrirCadastroMotorista,
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 28),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
                  onPressed: widget.onVoltar,
                ),
                const SizedBox(width: 10),
                const Text(
                  'Motoristas',
                  style: TextStyle(
                    fontSize: 24,
                    color: Color(0xFF0D47A1),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                
                // Campo de pesquisa
                Container(
                  width: 250,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, size: 20, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _pesquisaController,
                          focusNode: _pesquisaFocusNode,
                          decoration: const InputDecoration(
                            hintText: 'Pesquisar motorista...',
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      if (_pesquisaController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: _limparPesquisa,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _carregarMotoristas,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D47A1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh, size: 18),
                      SizedBox(width: 6),
                      Text('Atualizar'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Indicador de resultados da pesquisa
          if (_pesquisaController.text.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              color: Colors.grey.shade50,
              child: Row(
                children: [
                  Text(
                    '${_motoristasFiltrados.length} motorista(s) encontrado(s)',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

          // Tabela
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D47A1)))
                : _motoristasFiltrados.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_off_outlined,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Nenhum motorista encontrado',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          // Cabeçalho da tabela
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                            ),
                            child: _buildCabecalhos(),
                          ),

                          // Corpo da tabela
                          Expanded(
                            child: ListView.builder(
                              itemCount: _getMotoristasPaginados().length,
                              itemBuilder: (context, index) {
                                final motorista = _getMotoristasPaginados()[index];
                                return _buildLinhaTabela(motorista, index);
                              },
                            ),
                          ),

                          // Paginação
                          if (_motoristasFiltrados.length > _itensPorPagina)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border(top: BorderSide(color: Colors.grey.shade300)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.arrow_back_ios, size: 20),
                                    onPressed: _paginaAtual > 0
                                        ? () => setState(() => _paginaAtual--)
                                        : null,
                                  ),
                                  const SizedBox(width: 20),
                                  Text(
                                    'Página ${_paginaAtual + 1} de ${(_motoristasFiltrados.length / _itensPorPagina).ceil()}',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                  const SizedBox(width: 20),
                                  IconButton(
                                    icon: const Icon(Icons.arrow_forward_ios, size: 20),
                                    onPressed: (_paginaAtual + 1) * _itensPorPagina < _motoristasFiltrados.length
                                        ? () => setState(() => _paginaAtual++)
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

// Widget para célula em modo de edição
class _CelulaEditando extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSalvar;
  final VoidCallback onCancelar;

  const _CelulaEditando({
    required this.controller,
    required this.onSalvar,
    required this.onCancelar,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.all(4),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.check, size: 18, color: Colors.green),
          onPressed: onSalvar,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 18, color: Colors.red),
          onPressed: onCancelar,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }
}