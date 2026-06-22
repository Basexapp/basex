import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'dart:convert' show base64Encode;
import 'dart:js' as js;
import 'ordem_carregamento_venda_pdf.dart';
import 'nova_venda.dart';
import 'dialog_venda_total.dart';
import 'dart:async';
import '../../login_page.dart';

class ProgramacaoPage extends StatefulWidget {
  final VoidCallback onVoltar;

  const ProgramacaoPage({
    super.key, 
    required this.onVoltar,
  });

  @override
  State<ProgramacaoPage> createState() => _ProgramacaoPageState();
}

class _ProgramacaoPageState extends State<ProgramacaoPage> {
  bool carregando = true;
  List<Map<String, dynamic>> movimentacoes = [];
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _horizontalHeaderController = ScrollController();
  final ScrollController _horizontalBodyController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  int grupoAtual = 0;
  DateTime _dataFiltro = DateTime.now();
  // Empresas vinculadas ao terminal
  List<Map<String, String>> _empresas = [
    {'id': '', 'nome': 'Todas'},
  ];
  String _empresaSelecionadaId = '';
  bool _empresaFixa = false; // true quando usuário possui empresa_id e o campo deve ficar fixo
  
  static const Map<String, Color> _alphabetColors = {
    'A': Color(0xFFE53935), 'B': Color(0xFF1E88E5), 'C': Color(0xFF43A047),
    'D': Color(0xFFFB8C00), 'E': Color(0xFF8E24AA), 'F': Color(0xFF0097A7),
    'G': Color(0xFFF4511E), 'H': Color(0xFF3949AB), 'I': Color(0xFF7CB342),
    'J': Color.fromARGB(255, 102, 14, 99), 'K': Color(0xFF5D4037), 'L': Color(0xFF546E7A),
    'M': Color(0xFFC2185B), 'N': Color(0xFF00897B), 'O': Color(0xFF5E35B1),
    'P': Color(0xFF00ACC1), 'Q': Color(0xFFF57C00), 'R': Color(0xFF303F9F),
    'S': Color(0xFF689F38), 'T': Color(0xFFAD1457), 'U': Color(0xFFD32F2F),
    'V': Color(0xFF1976D2), 'W': Color(0xFF388E3C), 'X': Color(0xFFF57C00),
    'Y': Color(0xFF7B1FA2), 'Z': Color(0xFF00796B),
  };
  
  static const Map<String, Map<String, dynamic>> _mapaProdutosColuna = {
    '82c348c8-efa1-4d1a-953a-ee384d5780fc': {'grupo': 0, 'coluna': 0}, // G. COMUM
    '93686e9d-6ef5-4f7c-a97d-b058b3c2c693': {'grupo': 0, 'coluna': 1}, // G. ADITIVADA
    '58ce20cf-f252-4291-9ef6-f4821f22c29e': {'grupo': 0, 'coluna': 2}, // D. S10
    'c77a6e31-52f0-4fe1-bdc8-685dff83f3a1': {'grupo': 0, 'coluna': 3}, // D. S500
    '66ca957a-5698-4a02-8c9e-987770b6a151': {'grupo': 0, 'coluna': 4}, // ETANOL
    'f8e95435-471a-424c-947f-def8809053a0': {'grupo': 0, 'coluna': 5}, // GASOLINA A
    '4da89784-301f-4abe-b97e-c48729969e3d': {'grupo': 0, 'coluna': 6}, // S500 A
    '3c26a7e5-8f3a-4429-a8c7-2e0e72f1b80a': {'grupo': 0, 'coluna': 7}, // S10 A
    'cecab8eb-297a-4640-81ae-e88335b88d8b': {'grupo': 0, 'coluna': 8}, // ANIDRO
    'ecd91066-e763-42e3-8a0e-d982ea6da535': {'grupo': 0, 'coluna': 9}, // B100
  };
  
  @override
  void initState() {
    super.initState();
    carregar();

    _horizontalHeaderController.addListener(() {
      if (_horizontalBodyController.hasClients &&
          _horizontalBodyController.offset != _horizontalHeaderController.offset) {
        _horizontalBodyController.jumpTo(_horizontalHeaderController.offset);
      }
    });

    _horizontalBodyController.addListener(() {
      if (_horizontalHeaderController.hasClients &&
          _horizontalHeaderController.offset != _horizontalBodyController.offset) {
        _horizontalHeaderController.jumpTo(_horizontalBodyController.offset);
      }
    });
  }

  @override
  void dispose() {
    _horizontalHeaderController.dispose();
    _horizontalBodyController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  Future<void> carregar() async {
    setState(() => carregando = true);

    try {
      final supabase = Supabase.instance.client;
      final usuario = UsuarioAtual.instance;

      // Carregar empresas vinculadas ao terminal do usuário
      if (usuario != null && usuario.terminalId != null && usuario.terminalId!.isNotEmpty) {
        try {
            final relacoesResponse = await supabase
              .from('relacoes_terminais')
              .select('empresas(id,nome_dois)')
              .eq('terminal_id', usuario.terminalId!);

          final List<Map<String, String>> empresasVinc = [
            {'id': '', 'nome': 'Todas'},
          ];

          for (var item in (relacoesResponse as List)) {
            final emp = item['empresas'];
            final id = emp?['id']?.toString();
            final nome = emp?['nome_dois']?.toString();
            if (id != null && nome != null) {
              if (!empresasVinc.any((e) => e['id'] == id)) {
                empresasVinc.add({'id': id, 'nome': nome});
              }
            }
          }

          // Se o usuário tiver empresa_id definido, fixa a seleção
          if (usuario.empresaId != null && usuario.empresaId!.isNotEmpty) {
            _empresaSelecionadaId = usuario.empresaId!;
            _empresaFixa = true;
            if (!empresasVinc.any((e) => e['id'] == _empresaSelecionadaId)) {
              try {
                final resp = await supabase
                    .from('empresas')
                    .select('nome_dois')
                    .eq('id', _empresaSelecionadaId)
                    .maybeSingle();
                final nome = resp != null ? resp['nome_dois']?.toString() : null;
                empresasVinc.add({'id': _empresaSelecionadaId, 'nome': nome ?? 'Minha Empresa'});
              } catch (_) {
                empresasVinc.add({'id': _empresaSelecionadaId, 'nome': 'Minha Empresa'});
              }
            }
          } else {
            // mantém seleção atual (ou 'Todas')
            _empresaFixa = false;
            if (_empresaSelecionadaId.isEmpty) _empresaSelecionadaId = '';
          }

          setState(() {
            _empresas = empresasVinc;
            if (!_empresas.any((e) => e['id'] == _empresaSelecionadaId)) {
              _empresaSelecionadaId = '';
            }
          });
        } catch (e) {
          // ignorar erro ao carregar empresas, continua sem filtro
        }
      }

      var query = supabase
          .from("movimentacoes")
          .select("""
            *,
            produtos:produto_id (
              id,
              nome,
              codigo
            ),
            ordens:ordem_id (
              id,
              n_controle,
              veic_parcial,
              status_term_orig
            )
          """)
          .eq("tipo_op", "venda");

      // Aplica filtro de empresa selecionada (se houver)
      if (_empresaSelecionadaId.isNotEmpty) {
        query = query.eq('empresa_id', _empresaSelecionadaId);
      }

      if (usuario != null) {
        if (usuario.terminalId != null && usuario.terminalId!.isNotEmpty) {
          query = query.eq("terminal_orig_id", usuario.terminalId!);
        }
      }
      
      final dataFormatada = _dataFiltro.toIso8601String().split('T')[0];
      final dataInicio = '$dataFormatada 00:00:00';
      final dataFim = '$dataFormatada 23:59:59';
      
      query = query
          .gte('data_mov', dataInicio)
          .lte('data_mov', dataFim);

      final response = await query
          .order('data_mov', ascending: true)
          .order('ordem_id', ascending: true)
          .order('id', ascending: true);

      List<Map<String, dynamic>> dadosProcessados = [];

      final listaResponse = List<Map<String, dynamic>>.from(response);

      for (final item in listaResponse) {
        final produtos = item['produtos'];
        if (produtos is Map<String, dynamic>) {
          item['produto_nome'] = produtos['nome'];
          item['produto_codigo'] = produtos['codigo'];
        }
        
        final ordens = item['ordens'];
        if (ordens is Map<String, dynamic>) {
          item['veic_parcial_ordem'] = ordens['veic_parcial'];
          item['status_term_orig_ordem'] = ordens['status_term_orig'];
        }

        dadosProcessados.add(item);
      }

      setState(() {
        movimentacoes = dadosProcessados;
      });
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar movimentações: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => carregando = false);
      }
    }
  }

  Color? _obterCorParaPlaca(dynamic placa) {
    if (placa == null) return null;
    
    String placaStr = "";
    if (placa is List && placa.isNotEmpty) {
      placaStr = placa.first.toString().toUpperCase().trim();
    } else {
      placaStr = placa.toString().toUpperCase().trim();
    }

    if (placaStr.length < 2) return null;
    
    final segundaLetra = placaStr[1];
    return _alphabetColors[segundaLetra];
  }

  void _mostrarDialogNovaVenda() async {
    final usuario = UsuarioAtual.instance;
    if (usuario == null || 
        usuario.empresaId == null || 
        usuario.terminalId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Apenas usuários vinculados a uma empresa (não apenas ao terminal) podem gerar nova venda.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => NovaVendaDialog(
        onSalvar: (sucesso, mensagem) {
          if (sucesso && mensagem != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(mensagem),
                backgroundColor: Colors.green,
              ),
            );
            carregar();
          } else if (mensagem != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(mensagem),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        terminalId: usuario.terminalId!,
        empresaId: usuario.empresaId!,
        dataFiltro: _dataFiltro,
      ),
    );

    if (result == true) {
      await carregar();
    }
  }

  void _mostrarDialogTotais() {
    showDialog(
      context: context,
      builder: (context) => DialogVendaTotal(
        movimentacoes: movimentacoes,
        mapaProdutosColuna: _mapaProdutosColuna,
      ),
    );
  }

  List<Map<String, dynamic>> get _movimentacoesFiltradas {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      return _agruparPorOrdem(_obterDadosFiltrados(grupoAtual));
    }

    final filtradas = _obterDadosFiltrados(grupoAtual).where((t) {
      if ((t['cliente']?.toString().toLowerCase() ?? '').contains(query) ||
          (t['placa']?.toString().toLowerCase() ?? '').contains(query) ||
          (t['forma_pagamento']?.toString().toLowerCase() ?? '').contains(query) ||
          (t['codigo']?.toString().toLowerCase() ?? '').contains(query) ||
          (t['uf']?.toString().toLowerCase() ?? '').contains(query) ||
          (t['ordem_id']?.toString().toLowerCase() ?? '').contains(query)) {
        return true;
      }

      final quantidadeFormatada = _formatarQuantidadeParaBusca(t['saida_amb']?.toString() ?? '');
      if (quantidadeFormatada.contains(query)) {
        return true;
      }
      
      final apenasNumeros = (t['saida_amb']?.toString() ?? '').replaceAll(RegExp(r'[^\d]'), '');
      if (apenasNumeros.contains(query)) {
        return true;
      }

      return false;
    }).toList();

    return _agruparPorOrdem(filtradas);
  }

  List<Map<String, dynamic>> _agruparPorOrdem(List<Map<String, dynamic>> dados) {
    if (dados.isEmpty) return [];

    List<Map<String, dynamic>> resultado = [];
    String? ultimaOrdemId;

    final List<Map<String, dynamic>> ordenados = List<Map<String, dynamic>>.from(dados);
    
    // Garantir que a lista esteja ordenada por ordem_id para agrupar corretamente
    ordenados.sort((a, b) {
      final idA = a['ordem_id']?.toString() ?? '';
      final idB = b['ordem_id']?.toString() ?? '';
      return idA.compareTo(idB);
    });

    for (var i = 0; i < ordenados.length; i++) {
      final mov = ordenados[i];
      final ordemId = mov['ordem_id']?.toString();

      // Se mudar a ordem (e não for a primeira), adiciona uma linha em branco
      if (ultimaOrdemId != null && ordemId != ultimaOrdemId) {
        resultado.add({'isSpacer': true});
      }

      resultado.add(mov);
      ultimaOrdemId = ordemId;
    }

    return resultado;
  }

  String _formatarQuantidadeParaBusca(String quantidade) {
    try {
      final apenasNumeros = quantidade.replaceAll(RegExp(r'[^\d]'), '');
      if (apenasNumeros.isEmpty || apenasNumeros == '0') return '';
      
      final valor = int.parse(apenasNumeros);
      if (valor == 0) return '';
      
      if (valor > 999) {
        final parteMilhar = (valor ~/ 1000).toString();
        final parteCentena = (valor % 1000).toString().padLeft(3, '0');
        return '$parteMilhar.$parteCentena';
      }
      
      return valor.toString();
    } catch (e) {
      return quantidade;
    }
  }

  List<Map<String, dynamic>> _obterDadosFiltrados(int grupo) {
    return movimentacoes.where((l) {
      final qtd = double.tryParse(l['saida_amb']?.toString() ?? '0') ?? 0;
      if (qtd <= 0) return false;
      
      final produtoId = l['produto_id']?.toString();
      if (produtoId == null) return false;
      
      return _mapaProdutosColuna.containsKey(produtoId);
    }).toList();
  }  

  String _obterTextoStatus(dynamic statusCircuito, {dynamic statusTerm}) {
    // Se houver status do terminal (saída), ele tem prioridade para refletir a realidade local
    if (statusTerm != null) {
      final st = int.tryParse(statusTerm.toString()) ?? 0;
      switch (st) {
        case 1: return "Programado";
        case 2: return "Em Fila";
        case 3: return "Em Operação";
        // Outros status podem ser adicionados conforme evolução do circuito
      }
    }

    if (statusCircuito == null) return "Programado";
    
    final statusNum = int.tryParse(statusCircuito.toString()) ?? 1;
    
    switch (statusNum) {
      case 1: return "Programado";
      case 2: return "Em check-list";
      case 3: return "Em operação";
      case 4: return "Aguardando NF";
      case 5: return "Expedido";
      default: return "Programado";
    }
  }

  Color _obterCorStatus(dynamic statusCircuito, {dynamic statusTerm}) {
    if (statusTerm != null) {
      final st = int.tryParse(statusTerm.toString()) ?? 0;
      switch (st) {
        case 1: return Colors.blue;
        case 2: return const Color(0xFFE65100); // Laranja do estágio "Em Fila"
        case 3: return const Color(0xFF4A148C); // Roxo do estágio "Em Operação"
      }
    }

    if (statusCircuito == null) return Colors.blue;
    
    final statusNum = int.tryParse(statusCircuito.toString()) ?? 1;
    
    switch (statusNum) {
      case 1: return Colors.blue;
      case 2: return Colors.orange;
      case 3: return Colors.green;
      case 4: return Colors.purple;
      case 5: return Colors.grey;
      default: return Colors.blue;
    }
  }

  Future<void> _editarOrdem(Map<String, dynamic> movimentacao) async {
    final statusOrig = int.tryParse(movimentacao['status_circuito_orig']?.toString() ?? '1') ?? 1;
    
    if (statusOrig > 2) {
      await _mostrarDialogBloqueioEdicao();
      return;
    }

    final ordemId = movimentacao['ordem_id']?.toString();
    if (ordemId == null || ordemId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Esta movimentação não possui uma ordem associada.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final usuario = UsuarioAtual.instance;
    if (usuario == null || 
        usuario.empresaId == null || 
        usuario.terminalId == null) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => NovaVendaDialog(
        onSalvar: (sucesso, mensagem) {
          if (sucesso && mensagem != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(mensagem),
                backgroundColor: Colors.green,
              ),
            );
            carregar();
          } else if (mensagem != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(mensagem),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        terminalId: usuario.terminalId!,
        empresaId: usuario.empresaId!,
        movimentacaoParaEdicao: movimentacao,
        ordemId: ordemId,
      ),
    );

    if (result == true) {
      await carregar();
    }
  }

  Future<void> _mostrarDialogBloqueioEdicao() async {
    return showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFF0D47A1), width: 1),
        ),
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFF0D47A1),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.block_flipped, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Operação não permitida',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'A etapa do circuito não permite alteração da ordem. '
                  'Entre em contato com o supervisor da operação para reverter a etapa, '
                  'se ainda for possível.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade800,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(9)),
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade300, width: 1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 150,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D47A1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text(
                          'Entendi',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _mostrarDialogBloqueioExclusao() async {
    return showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFF0D47A1), width: 1),
        ),
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFF0D47A1),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.block_flipped, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Operação não permitida',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'A etapa do circuito não permite exclusão da ordem. '
                  'Entre em contato com o supervisor da operação para reverter a etapa, '
                  'se ainda for possível.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade800,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(9)),
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade300, width: 1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 150,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D47A1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text(
                          'Entendi',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _excluirOrdem(Map<String, dynamic> movimentacao) async {
    final statusOrig = int.tryParse(movimentacao['status_circuito_orig']?.toString() ?? '1') ?? 1;
    
    if (statusOrig > 2) {
      await _mostrarDialogBloqueioExclusao();
      return;
    }

    final ordemId = movimentacao['ordem_id']?.toString();
    
    if (ordemId == null || ordemId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Esta movimentação não possui uma ordem associada.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFF0D47A1), width: 1),
        ),
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFF0D47A1),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Confirmar exclusão',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: Colors.black,
                    ),
                    children: [
                      TextSpan(
                        text: 'Tem certeza que quer excluir a programação?\n',
                      ),
                      TextSpan(
                        text: 'Atenção: a exclusão ocorrerá para todos os clientes do veículo. Esta ação é irreversível.',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(9)),
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade300, width: 1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 120,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          side: BorderSide(color: Colors.grey.shade400),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text(
                          'Voltar',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 120,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text(
                          'Sim, excluir',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmado != true) return;

    try {
      final supabase = Supabase.instance.client;
      
      await supabase
          .from('ordens')
          .delete()
          .eq('id', ordemId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Programação excluída com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        
        await carregar();
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir programação: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _visualizarOrdem(Map<String, dynamic> movimentacao) async {
    try {
      final pdf = await OrdemCarregamentoVendaPDF.gerar(dados: movimentacao);
      final pdfBytes = await pdf.save();

      if (kIsWeb) {
        await _downloadForWeb(pdfBytes, movimentacao['ordem_id']?.toString() ?? 'venda');
      } else {
        await Printing.layoutPdf(
          onLayout: (format) async => pdfBytes,
          name: 'Ordem_Carregamento_${movimentacao['ordem_id'] ?? 'venda'}.pdf',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao visualizar ordem: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadForWeb(Uint8List bytes, String ordemId) async {
    try {
      final base64 = base64Encode(bytes);
      final content = base64;
      
      js.context.callMethod('eval', [
        """
        (function() {
          var base64Data = '$content';
          var byteCharacters = atob(base64Data);
          var byteNumbers = new Array(byteCharacters.length);
          for (var i = 0; i < byteCharacters.length; i++) {
              byteNumbers[i] = byteCharacters.charCodeAt(i);
          }
          var byteArray = new Uint8Array(byteNumbers);
          var blob = new Blob([byteArray], {type: 'application/pdf'});
          var url = URL.createObjectURL(blob);
          
          var win = window.open();
          if (win) {
            win.location.href = url;
          } else {
            // Fallback se o popup for bloqueado
            var link = document.createElement('a');
            link.href = url;
            link.target = '_blank';
            link.click();
          }
        })();
        """
      ]);
    } catch (e) {
      debugPrint('Erro no download web: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null,
      body: Column(
        children: [
          Container(
            height: kToolbarHeight + MediaQuery.of(context).padding.top,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top,
              left: 16,
              right: 16,
            ),
            color: Colors.white,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: widget.onVoltar,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: const Text(
                      "Programação de Carregamentos",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0D47A1),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ),
                Container(
                  width: 260,
                  margin: const EdgeInsets.only(right: 12),
                  child: _buildEmpresaDropdown(),
                ),
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  child: _buildSeletorDataPresets(),
                ),
                Container(
                  width: 250,
                  margin: const EdgeInsets.only(right: 12),
                  child: _buildSearchField(),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.black),
                  onPressed: carregar,
                  tooltip: 'Atualizar',
                ),
              ],
            ),
          ),
          Container(
            height: 1,
            color: Colors.grey.shade300,
          ),
          Expanded(
            child: carregando
                ? const Center(child: CircularProgressIndicator())
                : _buildBodyContent(),
          ),
          Container(
            height: 50,
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Base X 2026, All rights reserved.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Licenciado e comercializado por Metabots Business Intelligence - Rua Leais Paulistanos, 416 - Ipiranga - São Paulo, SP | Uma iniciativa © Norton Technology',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'btnNovaVenda',
            onPressed: _mostrarDialogNovaVenda,
            backgroundColor: const Color(0xFF0D47A1),
            foregroundColor: Colors.white,
            mini: true,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
            child: const Icon(Icons.add_box, size: 24),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'btnTotaisDia',
            onPressed: _mostrarDialogTotais,
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF0D47A1),
            mini: true,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFF0D47A1), width: 1),
            ),
            elevation: 4,
            tooltip: 'Ver totais do dia',
            child: const Icon(Icons.analytics_outlined, size: 24),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildBodyContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth;
        return Column(
          children: [
            _buildFixedHeader(viewportWidth),
            Expanded(
              child: _buildScrollableTable(viewportWidth),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSeletorDataPresets() {
    final textoData = '${_dataFiltro.day.toString().padLeft(2, '0')}/${_dataFiltro.month.toString().padLeft(2, '0')}/${_dataFiltro.year}';

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Seta para DIA ANTERIOR
          _buildSetaNavegacao(
            icon: Icons.chevron_left,
            onTap: () {
              setState(() {
                _dataFiltro = _dataFiltro.subtract(const Duration(days: 1));
              });
              carregar();
            },
          ),
          Container(width: 1, color: Colors.grey.shade200),
          // Botão CENTRAL (Calendário + Data)
          InkWell(
            onTap: () => _abrirCalendarioDialog(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 14, color: Color(0xFF0D47A1)),
                  const SizedBox(width: 10),
                  Text(
                    textoData,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D47A1),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(width: 1, color: Colors.grey.shade200),
          // Seta para PRÓXIMO DIA
          _buildSetaNavegacao(
            icon: Icons.chevron_right,
            onTap: () {
              setState(() {
                _dataFiltro = _dataFiltro.add(const Duration(days: 1));
              });
              carregar();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmpresaDropdown() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _empresaSelecionadaId,
          isDense: true,
          icon: Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey.shade600),
          items: _empresas.map((e) {
            return DropdownMenuItem<String>(
              value: e['id'] ?? '',
              child: Text(e['nome'] ?? ''),
            );
          }).toList(),
          onChanged: _empresaFixa
              ? null
              : (val) {
                  setState(() {
                    _empresaSelecionadaId = val ?? '';
                  });
                  carregar();
                },
        ),
      ),
    );
  }

  Widget _buildSetaNavegacao({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 36,
        height: 40,
        alignment: Alignment.center,
        child: Icon(icon, size: 20, color: Colors.grey.shade600),
      ),
    );
  }

  Future<void> _abrirCalendarioDialog() async {
    DateTime tempDate = _dataFiltro;
    final dataSelecionada = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 350,
            padding: const EdgeInsets.all(20),
            child: StatefulBuilder(
              builder: (context, setStateDialog) {
                int? hoveredDay;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Color(0xFF0D47A1), size: 24),
                        const SizedBox(width: 12),
                        const Text('Filtrar por data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF0D47A1))),
                        const Spacer(),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop(), color: Colors.grey, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(icon: const Icon(Icons.chevron_left, color: Color(0xFF0D47A1)), onPressed: () { setStateDialog(() { tempDate = DateTime(tempDate.year, tempDate.month - 1, tempDate.day); }); }),
                          Text('${_getMonthName(tempDate.month)} ${tempDate.year}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF0D47A1))),
                          IconButton(icon: const Icon(Icons.chevron_right, color: Color(0xFF0D47A1)), onPressed: () { setStateDialog(() { tempDate = DateTime(tempDate.year, tempDate.month + 1, tempDate.day); }); }),
                        ],
                      ),
                    ),
                    GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: 7,
                      childAspectRatio: 1.0,
                      children: ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'].map((day) {
                        return Center(child: Text(day, style: const TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.bold)));
                      }).toList(),
                    ),
                    GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: 7,
                      childAspectRatio: 1.0,
                      children: _getDaysInMonth(tempDate).map((day) {
                        final isSelected = day != null && day == tempDate.day;
                        final isToday = day != null && day == DateTime.now().day && tempDate.month == DateTime.now().month && tempDate.year == DateTime.now().year;
                        return StatefulBuilder(
                          builder: (context, setDayState) {
                            return MouseRegion(
                              cursor: day != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
                              onEnter: (_) { if (day != null) { setDayState(() => hoveredDay = day); } },
                              onExit: (_) { if (day != null) { setDayState(() => hoveredDay = null); } },
                              child: GestureDetector(
                                onTap: day != null ? () { setStateDialog(() { tempDate = DateTime(tempDate.year, tempDate.month, day); }); } : null,
                                child: Container(
                                  margin: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFF0D47A1)
                                        : (day != null && hoveredDay == day) ? const Color(0xFF0D47A1).withOpacity(0.1)
                                        : isToday ? const Color(0x220D47A1) : Colors.transparent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(child: Text(
                                    day != null ? day.toString() : '',
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : isToday || (day != null && hoveredDay == day) ? const Color(0xFF0D47A1) : Colors.black87,
                                      fontWeight: isSelected || isToday || (day != null && hoveredDay == day) ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  )),
                                ),
                              ),
                            );
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () => Navigator.of(context).pop(), style: TextButton.styleFrom(foregroundColor: Colors.black87, padding: const EdgeInsets.symmetric(horizontal: 16)), child: const Text('CANCELAR')),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(tempDate),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          child: const Text('SELECIONAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
    
    if (dataSelecionada != null) {
      setState(() {
        _dataFiltro = DateTime(
          dataSelecionada.year,
          dataSelecionada.month,
          dataSelecionada.day,
        );
      });
      carregar();
    }
  }

  Widget _buildFixedHeader(double viewportWidth) {
    final larguraTabela = _obterLarguraTabela(viewportWidth);
    
    return Scrollbar(
      controller: _horizontalHeaderController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _horizontalHeaderController,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: larguraTabela,
          child: Container(
            height: 24,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(
              children: _obterColunasCabecalho(viewportWidth),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScrollableTable(double viewportWidth) {
    return Scrollbar(
      controller: _verticalScrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _verticalScrollController,
        child: Scrollbar(
          controller: _horizontalBodyController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _horizontalBodyController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: _obterLarguraTabela(viewportWidth),
              child: Column(
                children: [
                  // Exibe as movimentações reais
                  if (_movimentacoesFiltradas.isNotEmpty)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _movimentacoesFiltradas.length,
                      itemBuilder: (context, index) {
                        final t = _movimentacoesFiltradas[index];
                        
                        if (t['isSpacer'] == true) {
                          return _buildEmptyRow(index, viewportWidth, isSpacer: true);
                        }

                        final statusCircuito = t['status_circuito'];
                        final statusTermOrig = t['status_term_orig_ordem'];
                        
                        final statusTexto = _obterTextoStatus(statusCircuito, statusTerm: statusTermOrig);
                        final corStatus = _obterCorStatus(statusCircuito, statusTerm: statusTermOrig);
                        
                        String codigo = t["codigo"]?.toString() ?? "";
                        String uf = t["uf"]?.toString() ?? ""; 
                        String prazo = t["forma_pagamento"]?.toString() ?? "";
                        
                        return Container(
                          height: 22,
                          decoration: BoxDecoration(
                            color: index % 2 == 0 ? Colors.grey.shade50 : Colors.white,
                          ),
                          child: Row(
                            children: _obterCelulasLinha(t, statusTexto, corStatus, codigo, uf, prazo, viewportWidth),
                          ),
                        );
                      },
                    ),
                  // Preenche o restante até completar 100 linhas
                  ...List.generate(
                    (100 - _movimentacoesFiltradas.length).clamp(0, 100),
                    (index) => _buildEmptyRow(index + _movimentacoesFiltradas.length, viewportWidth),
                  ),
                  _buildTotalizadorLinha(viewportWidth),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyRow(int index, double viewportWidth, {bool isSpacer = false}) {
    double larguraFixaSemCliente = 40 + 110 + 90 + 70 + 50 + 90;
    double larguraRestante = viewportWidth - larguraFixaSemCliente;
    double larguraCliente = (larguraRestante * 0.3).clamp(200.0, double.infinity).roundToDouble();
    double larguraProduto = ((larguraRestante - larguraCliente) / 10).clamp(50.0, double.infinity).roundToDouble();

    final bgColor = isSpacer ? Colors.white : (index % 2 == 0 ? Colors.grey.shade50 : Colors.white);

    return Container(
      height: 22,
      decoration: BoxDecoration(
        color: bgColor,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 22,
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: Colors.grey.shade400, width: 1.0),
                right: BorderSide(color: Colors.grey.shade400, width: 1.0),
                bottom: BorderSide(color: Colors.grey.shade400, width: 1.0),
              ),
            ),
          ), // Menu placeholder
          _cellPlaca(" ", 110, isParcial: false), // Placa
          _statusCell(" ", Colors.transparent), // Status
          _cell(" ", larguraCliente, bgColor: bgColor), // Cliente
          _cell(" ", 70, bgColor: bgColor),  // Cód.
          _cell(" ", 50, bgColor: bgColor),  // UF
          _cell(" ", 90, bgColor: bgColor), // Prazo
          _cell(" ", larguraProduto, bgColor: Colors.orange.shade50, isProduct: true),    // G. COM.
          _cell(" ", larguraProduto, bgColor: Colors.orange.shade100, isProduct: true),   // G. ADITIV.
          _cell(" ", larguraProduto, bgColor: Colors.blueGrey.shade50, isProduct: true),  // D. S10
          _cell(" ", larguraProduto, bgColor: Colors.blueGrey.shade100, isProduct: true), // D. S500
          _cell(" ", larguraProduto, bgColor: Colors.green.shade50, isProduct: true),     // ETANOL
          _cell(" ", larguraProduto, bgColor: Colors.amber.shade50, isProduct: true),     // G. A
          _cell(" ", larguraProduto, bgColor: Colors.brown.shade50, isProduct: true),     // S500 A
          _cell(" ", larguraProduto, bgColor: Colors.purple.shade50, isProduct: true),    // S10 A
          _cell(" ", larguraProduto, bgColor: Colors.teal.shade50, isProduct: true),      // ANIDRO
          _cell(" ", larguraProduto, bgColor: Colors.cyan.shade50, isProduct: true),      // B100
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(Icons.search, color: Colors.grey.shade600, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Pesquisar...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.clear, color: Colors.grey.shade600, size: 20),
              onPressed: () {
                _searchController.clear();
                setState(() {});
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36),
            ),
        ],
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context, Map<String, dynamic> item) {
    return Container(
      width: 50,
      alignment: Alignment.center,
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: Colors.black, width: 0.5),
        ),
        itemBuilder: (BuildContext context) => [
          const PopupMenuItem<String>(
            value: 'visualizar_ordem',
            height: 32,
            child: Row(
              children: [
                Icon(Icons.visibility_outlined, size: 16),
                SizedBox(width: 8),
                Text('Visualizar ordem', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          const PopupMenuItem<String>(
            value: 'editar_ordem',
            height: 32,
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 16),
                SizedBox(width: 8),
                Text('Editar ordem', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          const PopupMenuItem<String>(
            value: 'excluir',
            height: 32,
            child: Row(
              children: [
                Icon(Icons.delete_outline, size: 16, color: Colors.red),
                SizedBox(width: 8),
                Text(
                  'Excluir programação',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
        onSelected: (String value) {
          if (value == 'visualizar_ordem') {
            _visualizarOrdem(item);
          } else if (value == 'editar_ordem') {
            _editarOrdem(item);
          } else if (value == 'excluir') {
            _excluirOrdem(item);
          }
        },
        tooltip: 'Opções',
        offset: const Offset(0, 30),
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: Colors.transparent,
          ),
          child: const Icon(
            Icons.more_vert,
            size: 14,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }

  double _obterLarguraTabela(double viewportWidth) {
    double larguraFixaSemCliente = 40 + 110 + 90 + 70 + 50 + 90;
    double larguraRestante = viewportWidth - larguraFixaSemCliente;
    
    // Tentamos dar 200px para cliente e o resto para produtos (min 50px cada)
    // Arredondamos para evitar pixels fracionários que causam anti-aliasing
    double larguraCliente = (larguraRestante * 0.3).clamp(200.0, double.infinity).roundToDouble();
    double larguraProduto = ((larguraRestante - larguraCliente) / 10).clamp(50.0, double.infinity).roundToDouble();
    
    return larguraFixaSemCliente + larguraCliente + (larguraProduto * 10);
  }

  List<Widget> _obterColunasCabecalho(double viewportWidth) {
    double larguraFixaSemCliente = 40 + 110 + 90 + 70 + 50 + 90;
    double larguraRestante = viewportWidth - larguraFixaSemCliente;
    double larguraCliente = (larguraRestante * 0.3).clamp(200.0, double.infinity).roundToDouble();
    double larguraProduto = ((larguraRestante - larguraCliente) / 10).clamp(50.0, double.infinity).roundToDouble();

    final colunasFixas = [
      _th("", 40, isFirst: true),
      _th("PLACA", 110),
      _th("STATUS", 90),
      _th("CLIENTE", larguraCliente),
      _th("CÓD.", 70),
      _th("UF", 50),
      _th("PRAZO", 90),
    ];

    return [
      ...colunasFixas,
      _th("G. COM.", larguraProduto, color: Colors.orange.shade400),
      _th("G. ADITIV.", larguraProduto, color: Colors.orange.shade700),
      _th("D. S10", larguraProduto, color: Colors.blueGrey.shade400),
      _th("D. S500", larguraProduto, color: Colors.blueGrey.shade700),
      _th("ETANOL", larguraProduto, color: Colors.green.shade600),
      _th("G. A", larguraProduto, color: Colors.amber.shade600),
      _th("S500 A", larguraProduto, color: Colors.brown.shade400),
      _th("S10 A", larguraProduto, color: Colors.purple.shade400),
      _th("ANIDRO", larguraProduto, color: Colors.teal.shade600),
      _th("B100", larguraProduto, color: Colors.cyan.shade700),
    ];
  }

  Widget _th(String texto, double largura, {bool isFirst = false, Color? color}) {
    return Container(
      width: largura,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        border: Border(
          left: isFirst ? BorderSide(color: Colors.white.withOpacity(0.2), width: 0.8) : BorderSide.none,
          right: BorderSide(color: Colors.white.withOpacity(0.2), width: 0.8),
        ),
      ),
      child: Text(
        texto.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 9,
          letterSpacing: 0.5,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  List<Widget> _obterCelulasLinha(
    Map<String, dynamic> t,
    String statusTexto,
    Color corStatus,
    String codigo,
    String uf,
    String prazo,
    double viewportWidth,
  ) {
    double larguraFixaSemCliente = 40 + 110 + 90 + 70 + 50 + 90;
    double larguraRestante = viewportWidth - larguraFixaSemCliente;
    double larguraCliente = (larguraRestante * 0.3).clamp(200.0, double.infinity).roundToDouble();
    double larguraProduto = ((larguraRestante - larguraCliente) / 10).clamp(50.0, double.infinity).roundToDouble();

    final placas = t["placa"];
    final placaText = placas is List && placas.isNotEmpty 
        ? placas.first.toString() 
        : placas?.toString() ?? "";

    final corCliente = _obterCorParaPlaca(t["placa"]);

    final ordemId = t['ordem_id'];

    // Verifica se é a primeira linha desta ordem para exibir placa e menu
    bool isPrimeiraLinhaOrdem = false;
    if (ordemId != null) {
      final index = _movimentacoesFiltradas.indexOf(t);
      if (index == 0) {
        isPrimeiraLinhaOrdem = true;
      } else {
        final anterior = _movimentacoesFiltradas[index - 1];
        if (anterior['isSpacer'] == true) {
          isPrimeiraLinhaOrdem = true;
        }
      }
    }

    final produtoId = t['produto_id']?.toString();
    final produtoInfo = produtoId != null ? _mapaProdutosColuna[produtoId] : null;
    final quantidadeSaidaAmb = _formatarQuantidade(t["saida_amb"]?.toString() ?? "0");

    final isParcialRow = t['veic_parcial_ordem'] == true;

    final celulasFixas = [
      Container(
        width: 40,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: Colors.grey.shade400, width: 1.0),
            right: BorderSide(color: Colors.grey.shade400, width: 1.0),
            bottom: BorderSide(color: Colors.grey.shade400, width: 1.0),
          ),
        ),
        child: isPrimeiraLinhaOrdem ? _buildMenuButton(context, t) : null,
      ),
      _cellPlaca(isPrimeiraLinhaOrdem ? placaText : "", 110, isParcial: isParcialRow && isPrimeiraLinhaOrdem),
      _statusCell(statusTexto, corStatus),
      _cellCliente(t["cliente"]?.toString() ?? "", larguraCliente, corCliente),
      _cell(codigo, 70),
      _cell(uf, 50),
      _cell(prazo, 90),
    ];

    final List<Widget> colunasQuantidade = [];
    final numColunas = 10;
    
    final coresColunas = [
      Colors.orange.shade50,     // G. COM.
      Colors.orange.shade100,    // G. ADITIV.
      Colors.blueGrey.shade50,   // D. S10
      Colors.blueGrey.shade100,  // D. S500
      Colors.green.shade50,      // ETANOL
      Colors.amber.shade50,      // G. A
      Colors.brown.shade50,      // S500 A
      Colors.purple.shade50,     // S10 A
      Colors.teal.shade50,       // ANIDRO
      Colors.cyan.shade50,       // B100
    ];
    
    for (int i = 0; i < numColunas; i++) {
      final corFundo = coresColunas[i];
      if (produtoInfo != null && produtoInfo['coluna'] == i) {
        colunasQuantidade.add(_cell(quantidadeSaidaAmb, larguraProduto, isNumber: true, bgColor: corFundo, isProduct: true));
      } else {
        colunasQuantidade.add(_cell("", larguraProduto, isNumber: true, bgColor: corFundo, isProduct: true));
      }
    }

    return [...celulasFixas, ...colunasQuantidade];
  }

  Widget _cellPlaca(String texto, double largura, {bool isParcial = false}) {
    return Container(
      width: largura,
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.grey.shade400, width: 1.0),
          bottom: BorderSide(color: Colors.grey.shade400, width: 1.0),
        ),
      ),
      child: isParcial
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  texto,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  height: 14,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.yellow,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: Colors.brown, width: 0.8),
                  ),
                  child: const Text(
                    "P",
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            )
          : Text(
              texto,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade800,
                fontWeight: FontWeight.normal,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
    );
  }

  Widget _cell(String texto, double largura, {bool isNumber = false, bool isFirst = false, Color? bgColor, bool isProduct = false}) {
    return Container(
      width: largura,
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          left: isFirst ? BorderSide(color: Colors.grey.shade400, width: 1.0) : BorderSide.none,
          right: BorderSide(color: Colors.grey.shade400, width: 1.0),
          bottom: BorderSide(color: Colors.grey.shade400, width: 1.0),
        ),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 11,
          color: Colors.grey.shade800,
          fontWeight: (isNumber || isProduct) ? FontWeight.w600 : FontWeight.normal,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _cellCliente(String texto, double largura, Color? cor) {
    return Container(
      width: largura,
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.grey.shade400, width: 1.0),
          bottom: BorderSide(color: Colors.grey.shade400, width: 1.0),
        ),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 11,
          color: cor ?? Colors.grey.shade800,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _statusCell(String statusTexto, Color corStatus) {
    return Container(
      width: 90,
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.grey.shade400, width: 1.0),
          bottom: BorderSide(color: Colors.grey.shade400, width: 1.0),
        ),
      ),
      child: statusTexto.trim().isEmpty 
        ? const SizedBox.shrink()
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
            decoration: BoxDecoration(
              color: corStatus.withOpacity(0.1),
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: corStatus.withOpacity(0.3), width: 0.5),
            ),
            child: Text(
              statusTexto.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 7.5,
                fontWeight: FontWeight.bold,
                color: corStatus,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
    );
  }

  String _formatarQuantidade(String quantidade) {
    try {
      final apenasNumeros = quantidade.replaceAll(RegExp(r'[^\d]'), '');
      if (apenasNumeros.isEmpty || apenasNumeros == '0') return '';
      
      final valor = int.parse(apenasNumeros);
      if (valor == 0) return '';
      
      if (valor > 999) {
        final parteMilhar = (valor ~/ 1000).toString();
        final parteCentena = (valor % 1000).toString().padLeft(3, '0');
        return '$parteMilhar.$parteCentena';
      }
      
      return valor.toString();
    } catch (e) {
      return quantidade;
    }
  }

  Widget _buildTotalizadorLinha(double viewportWidth) {
    double larguraFixaSemCliente = 40 + 110 + 90 + 70 + 50 + 90;
    double larguraRestante = viewportWidth - larguraFixaSemCliente;
    double larguraCliente = (larguraRestante * 0.3).clamp(200.0, double.infinity).roundToDouble();
    double larguraProduto = ((larguraRestante - larguraCliente) / 10).clamp(50.0, double.infinity).roundToDouble();

    final totais = List.filled(10, 0.0);

    for (final t in _movimentacoesFiltradas) {
      if (t['isSpacer'] == true) continue;
      final produtoId = t['produto_id']?.toString();
      if (produtoId == null) continue;
      final info = _mapaProdutosColuna[produtoId];
      if (info == null) continue;
      final col = info['coluna'] as int;
      if (col < 0 || col >= 10) continue;
      totais[col] += double.tryParse(t['saida_amb']?.toString() ?? '0') ?? 0;
    }

    return Container(
      height: 22,
      color: Colors.orange.shade50,
      child: Row(
        children: [
          _cellTot('', 40),
          _cellTot('TOTAL', 110, isLabel: true),
          _cellTot('', 90),
          _cellTot('', larguraCliente),
          _cellTot('', 70),
          _cellTot('', 50),
          _cellTot('', 90),
          for (int i = 0; i < 10; i++)
            _cellTot(
              totais[i] > 0 ? _formatarQuantidade(totais[i].toStringAsFixed(0)) : '',
              larguraProduto,
              isNumber: true,
              isProduct: true,
            ),
        ],
      ),
    );
  }

  Widget _cellTot(String texto, double largura,
      {bool isLabel = false, bool isNumber = false, bool isProduct = false}) {
    return Container(
      width: largura,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.orange.shade300, width: 1.0),
          bottom: BorderSide(color: Colors.orange.shade300, width: 1.0),
        ),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 11,
          fontWeight:
              (isLabel || isNumber || isProduct) ? FontWeight.bold : FontWeight.normal,
          color:
              isLabel ? const Color(0xFF0D47A1) : Colors.grey.shade800,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    return months[month - 1];
  }

  List<int?> _getDaysInMonth(DateTime date) {
    final firstDay = DateTime(date.year, date.month, 1);
    final lastDay = DateTime(date.year, date.month + 1, 0);
    final firstWeekday = firstDay.weekday;
    final startOffset = firstWeekday == 7 ? 0 : firstWeekday;
    List<int?> days = [];
    for (int i = 0; i < startOffset; i++) {
      days.add(null);
    }
    for (int i = 1; i <= lastDay.day; i++) {
      days.add(i);
    }
    while (days.length < 42) {
      days.add(null);
    }
    return days;
  }
}