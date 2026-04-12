import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../gestao_de_frota/dialog_cadastro_placas.dart';

class NovaVendaDialog extends StatefulWidget {
  final Function(bool, String?) onSalvar;
  final String filialId;
  final String? filialNome;
  final String? terminalId;
  final Map<String, dynamic>? movimentacaoParaEdicao;
  final String? ordemId;

  const NovaVendaDialog({
    super.key,
    required this.onSalvar,
    required this.filialId,
    this.filialNome,
    this.terminalId,
    this.movimentacaoParaEdicao,
    this.ordemId,
  });

  @override
  State<NovaVendaDialog> createState() => _NovaVendaDialogState();
}

class _NovaVendaDialogState extends State<NovaVendaDialog> {
  final List<_PlacaVenda> _placasVenda = [];
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _produtos = [];
  bool _carregandoProdutos = false;
  bool _salvando = false;
  
  DateTime? _dataSelecionada;
  
  bool get _modoEdicao => widget.movimentacaoParaEdicao != null;

  @override
  void initState() {
    super.initState();
    _carregarProdutos().then((_) {
      if (_modoEdicao) {
        _carregarDadosParaEdicao();
      } else {
        _adicionarPlaca();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (final p in _placasVenda) {
      p.dispose();
    }
    super.dispose();
  }

  DateTime _getHorarioBrasilia() {
    return DateTime.now().toUtc().subtract(const Duration(hours: 3));
  }

  void _carregarDadosParaEdicao() {
    final mov = widget.movimentacaoParaEdicao!;
    
    if (mov['ts_mov'] != null) {
      try {
        _dataSelecionada = DateTime.parse(mov['ts_mov'].toString());
      } catch (e) {
        _dataSelecionada = _getHorarioBrasilia();
      }
    } else {
      _dataSelecionada = _getHorarioBrasilia();
    }
    
    final placa = _PlacaVenda();
    
    final placasData = mov['placa'];
    if (placasData is List && placasData.isNotEmpty) {
      placa.controller.text = placasData.first.toString();
    } else if (placasData is String) {
      placa.controller.text = placasData;
    }
    
    final tanque = _TanqueVenda(
      capacidade: _calcularCapacidade(mov['saida_amb']?.toString() ?? '0'),
    );
    
    tanque.produtoId = mov['produto_id']?.toString();
    tanque.clienteController.text = (mov['cliente']?.toString() ?? '').toUpperCase();
    tanque.pagamentoController.text = mov['forma_pagamento']?.toString() ?? '';
    tanque.pagamentoController.text = (tanque.pagamentoController.text).toUpperCase();
    
    placa.tanques.add(tanque);
    _placasVenda.add(placa);
    
    setState(() {});
  }

  String _calcularCapacidade(String quantidadeLitros) {
    try {
      final litros = double.tryParse(quantidadeLitros) ?? 0;
      final metrosCubicos = litros / 1000;
      return metrosCubicos.toStringAsFixed(0);
    } catch (e) {
      return '0';
    }
  }

  Future<void> _carregarProdutos() async {
    setState(() => _carregandoProdutos = true);
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('produtos')
          .select('id, nome_dois');
      _produtos = ordenarProdutosPorClasse(
        List<Map<String, dynamic>>.from(response),
      );
    } catch (_) {
      _produtos = [];
    } finally {
      setState(() => _carregandoProdutos = false);
    }
  }

  void _adicionarPlaca() {
    setState(() {
      _placasVenda.add(_PlacaVenda());
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _removerPlaca(int index) {
    if (index > 0 && index < _placasVenda.length) {
      setState(() {
        final placaRemovida = _placasVenda.removeAt(index);
        placaRemovida.dispose();
      });
    }
  }

  Future<void> _buscarPlacas(_PlacaVenda placa, String texto) async {
    if (texto.isEmpty) {
      placa.placasEncontradas.clear();
      placa.mostrarSugestoes = false;
      setState(() {});
      return;
    }

    placa.carregandoPlacas = true;
    placa.mostrarSugestoes = true;
    setState(() {});

    try {
      final supabase = Supabase.instance.client;
      final termoBusca = texto.trim().toUpperCase();
      
      // Buscar na tabela equipamentos
      final responseEquipamentos = await supabase
          .from('equipamentos')
          .select('placa, tanques')
          .ilike('placa', '%$termoBusca%')
          .order('placa')
          .limit(10);
      
      // Buscar na tabela veiculos_geral
      final responseVeiculos = await supabase
          .from('veiculos_geral')
          .select('placa, tanques')
          .ilike('placa', '%$termoBusca%')
          .order('placa')
          .limit(10);
      
      // Combinar os resultados
      List<Map<String, dynamic>> resultadosCombinados = [];
      
      // Adicionar resultados de equipamentos
      for (var item in responseEquipamentos) {
        resultadosCombinados.add({
          'placas': item['placa']?.toString().toUpperCase() ?? '',
          'tanques': item['tanques'] ?? [],
          'origem': 'equipamentos'
        });
      }
      
      // Adicionar resultados de veiculos_geral
      for (var item in responseVeiculos) {
        resultadosCombinados.add({
          'placas': item['placa']?.toString().toUpperCase() ?? '',
          'tanques': item['tanques'] ?? [],
          'origem': 'veiculos_geral'
        });
      }
      
      // Remover duplicatas (mesma placa em ambas as tabelas)
      final placasUnicas = <String>{};
      resultadosCombinados = resultadosCombinados.where((item) {
        final placaAtual = item['placas'].toString();
        if (placasUnicas.contains(placaAtual)) {
          return false;
        }
        placasUnicas.add(placaAtual);
        return true;
      }).toList();
      
      // Ordenar por placa
      resultadosCombinados.sort((a, b) => 
        a['placas'].toString().compareTo(b['placas'].toString())
      );
      
      // Limitar a 10 resultados no total
      if (resultadosCombinados.length > 10) {
        resultadosCombinados = resultadosCombinados.sublist(0, 10);
      }
      
      placa.placasEncontradas = resultadosCombinados;
      
    } catch (e) {
      print('Erro ao buscar placas: $e');
      placa.placasEncontradas.clear();
    } finally {
      placa.carregandoPlacas = false;
      setState(() {});
    }
  }

  void _selecionarPlaca(_PlacaVenda placa, Map<String, dynamic> item) {
    placa.controller.text = item['placas'];
    placa.mostrarSugestoes = false;

    final List<dynamic> tanques = item['tanques'] ?? [];

    placa.tanques.clear();
    
    // Se não houver tanques definidos, criar pelo menos um tanque padrão
    if (tanques.isEmpty) {
      placa.tanques.add(_TanqueVenda(capacidade: '0'));
    } else {
      for (final t in tanques) {
        placa.tanques.add(_TanqueVenda(capacidade: t.toString()));
      }
    }

    setState(() {});
  }

  List<Map<String, dynamic>> ordenarProdutosPorClasse(
    List<Map<String, dynamic>> produtos,
  ) {
    const ordemPorId = {
      '82c348c8-efa1-4d1a-953a-ee384d5780fc': 1,
      '93686e9d-6ef5-4f7c-a97d-b058b3c2c693': 2,
      'c77a6e31-52f0-4fe1-bdc8-685dff83f3a1': 3,
      '58ce20cf-f252-4291-9ef6-f4821f22c29e': 4,
      '66ca957a-5698-4a02-8c9e-987770b6a151': 5,
      'f8e95435-471a-424c-947f-def8809053a0': 6,
      '4da89784-301f-4abe-b97e-c48729969e3d': 7,
      '3c26a7e5-8f3a-4429-a8c7-2e0e72f1b80a': 8,
      'cecab8eb-297a-4640-81ae-e88335b88d8b': 9,
      'ecd91066-e763-42e3-8a0e-d982ea6da535': 10,
    };

    produtos.sort((a, b) {
      final idA = a['id'].toString().toLowerCase();
      final idB = b['id'].toString().toLowerCase();

      return (ordemPorId[idA] ?? 999)
          .compareTo(ordemPorId[idB] ?? 999);
    });

    return produtos;
  }

  Future<void> _salvarVenda() async {
    if (widget.filialId.isEmpty) {
      _mostrarErro('Filial não informada');
      return;
    }

    final placasUnicas = <String>[];
    for (final placaVenda in _placasVenda) {
      final placa = placaVenda.controller.text.trim().toUpperCase();
      if (placa.isNotEmpty && !placasUnicas.contains(placa)) {
        placasUnicas.add(placa);
      }
    }

    if (placasUnicas.isEmpty) {
      _mostrarErro('Informe pelo menos uma placa');
      return;
    }

    bool existemCamposObrigatoriosVazios = false;

    for (final placaVenda in _placasVenda) {
      for (final tanque in placaVenda.tanques) {
        final produtoPreenchido =
            tanque.produtoId != null && tanque.produtoId!.isNotEmpty;
        final clientePreenchido =
            tanque.clienteController.text.trim().isNotEmpty;
        final pagamentoPreenchido =
            tanque.pagamentoController.text.trim().isNotEmpty;

        final algumCampoPreenchido =
            produtoPreenchido || clientePreenchido || pagamentoPreenchido;

        if (algumCampoPreenchido &&
            !(produtoPreenchido &&
                clientePreenchido &&
                pagamentoPreenchido)) {
          existemCamposObrigatoriosVazios = true;
          break;
        }
      }
      if (existemCamposObrigatoriosVazios) break;
    }

    if (existemCamposObrigatoriosVazios) {
      setState(() {});
      return;
    }

    int totalTanques = 0;
    int tanquesCompletos = 0;
    int tanquesVazios = 0;
    int tanquesParciais = 0;

    for (final placaVenda in _placasVenda) {
      totalTanques += placaVenda.tanques.length;

      for (final tanque in placaVenda.tanques) {
        final produtoPreenchido =
            tanque.produtoId != null && tanque.produtoId!.isNotEmpty;
        final clientePreenchido =
            tanque.clienteController.text.trim().isNotEmpty;
        final pagamentoPreenchido =
            tanque.pagamentoController.text.trim().isNotEmpty;

        final isCompleto = produtoPreenchido && clientePreenchido && pagamentoPreenchido;
        final isVazio = !produtoPreenchido && !clientePreenchido && !pagamentoPreenchido;
        final isParcial = !isCompleto && !isVazio;

        if (isCompleto) {
          tanquesCompletos++;
        } else if (isParcial) {
          tanquesParciais++;
        } else {
          tanquesVazios++;
        }
      }
    }

    if (tanquesCompletos == 0) {
      _mostrarErro('Preencha pelo menos um tanque completo');
      return;
    }

    if (tanquesParciais > 0) {
      setState(() {});
      return;
    }

    if (!_modoEdicao && tanquesVazios > 0 && tanquesCompletos < totalTanques) {
      final bool? resultado = await _mostrarDialogCarregamentoParcial(
        tanquesCompletos,
        totalTanques,
      );

      if (resultado == null || !resultado) {
        return;
      }
    }

    if (_modoEdicao) {
      await _processarEdicaoVenda();
    } else {
      await _processarSalvamentoVenda();
    }
  }

  Future<bool?> _mostrarDialogCarregamentoParcial(
    int preenchidos,
    int total,
  ) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Shortcuts(
          shortcuts: <LogicalKeySet, Intent>{
            LogicalKeySet(LogicalKeyboardKey.escape): DismissIntent(),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              DismissIntent: CallbackAction<DismissIntent>(
                onInvoke: (intent) {
                  Navigator.of(context).pop(false);
                  return null;
                },
              ),
            },
            child: Focus(
              autofocus: true,
              child: Dialog(
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
                              'Carregamento parcial',
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
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nem todos os tanques foram preenchidos.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _infoLinha('Tanques disponíveis', total.toString()),
                            const SizedBox(height: 6),
                            _infoLinha(
                              'Tanques preenchidos',
                              preenchidos.toString(),
                              destaque: true,
                            ),
                            const SizedBox(height: 14),
                            Divider(color: Colors.grey.shade300, height: 1),
                            const SizedBox(height: 14),
                            Text(
                              'Deseja continuar com carregamento parcial?',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(9),
                          ),
                          border: Border(
                            top: BorderSide(color: Colors.grey.shade300, width: 1),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            SizedBox(
                              width: 140,
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
                                  'Voltar e completar',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 140,
                              child: ElevatedButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0D47A1),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                child: const Text(
                                  'Seguir parcial',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
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
            ),
          ),
        );
      },
    );
  }

  Widget _infoLinha(String label, String valor, {bool destaque = false}) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade700,
        ),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          TextSpan(
            text: valor,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: destaque ? const Color.fromARGB(255, 255, 0, 0) : Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processarSalvamentoVenda() async {
    setState(() => _salvando = true);

    if (widget.terminalId == null || widget.terminalId!.isEmpty) {
      _mostrarErro('Terminal não informado. Contate o suporte.');
      setState(() => _salvando = false);
      return;
    }

    try {
      final supabase = Supabase.instance.client;

      final filialResponse = await supabase
          .from('filiais')
          .select('empresa_id')
          .eq('id', widget.filialId)
          .single();
      
      final empresaId = filialResponse['empresa_id'];

      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Usuário não autenticado');
      }

      final hoje = _getHorarioBrasilia();
      final dataMov = hoje.toIso8601String();

      final ordemResponse = await supabase
          .from('ordens')
          .insert({
            'empresa_id': empresaId,
            'filial_id': widget.filialId,
            'usuario_id': user.id,
            'tipo': 'venda',
            'data_ordem': dataMov,
          })
          .select('id')
          .single();

      final ordemId = ordemResponse['id'];

      int tanquesProcessados = 0;
      
      for (final placaVenda in _placasVenda) {
        for (final tanque in placaVenda.tanques) {
          final produtoPreenchido = tanque.produtoId != null && tanque.produtoId!.isNotEmpty;
          final clientePreenchido = tanque.clienteController.text.trim().isNotEmpty;
          final pagamentoPreenchido = tanque.pagamentoController.text.trim().isNotEmpty;
          
          if (!(produtoPreenchido && clientePreenchido && pagamentoPreenchido)) {
            continue;
          }

          final capacidadeMCubicos = double.tryParse(tanque.capacidade) ?? 0.0;
          final capacidadeLitros = capacidadeMCubicos * 1000.0;

          final Map<String, dynamic> movimentacao = {
            'ordem_id': ordemId,
            'filial_id': widget.filialId,
            'filial_origem_id': widget.filialId,
            'terminal_orig_id': widget.terminalId,
            'empresa_id': empresaId,
            'usuario_id': user.id,
            'produto_id': tanque.produtoId,
            'placa': [placaVenda.controller.text.trim().toUpperCase()],
            'cliente': tanque.clienteController.text.trim(),
            'forma_pagamento': tanque.pagamentoController.text.trim(),
            'tipo_op': 'venda',
            'tipo_mov': 'saida',
            'tipo_mov_orig': 'saida',
            'descricao': 'venda comum',
            'data_mov': dataMov,
            'ts_mov': hoje.toIso8601String(),
            'quantidade': capacidadeLitros,
            'anp': false,
            'status_circuito_orig': 1,
            'entrada_amb': 0,
            'entrada_vinte': 0,
            'saida_amb': capacidadeLitros,
            'saida_vinte': 0,
          };

          await supabase.from('movimentacoes').insert(movimentacao);
          
          tanquesProcessados++;
        }
      }

      if (tanquesProcessados == 0) {
        throw Exception('Nenhum tanque completo para processar');
      }

      widget.onSalvar(true, 'Venda registrada com sucesso! ($tanquesProcessados tanque(s) processado(s))');
      if (mounted) Navigator.of(context).pop(true);
      
    } catch (e) {
      _mostrarErro('Erro ao salvar venda: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _salvando = false);
      }
    }
  }
  
  Future<void> _processarEdicaoVenda() async {
    setState(() => _salvando = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      
      if (user == null) {
        throw Exception('Usuário não autenticado');
      }

      if (_placasVenda.isEmpty || _placasVenda.first.tanques.isEmpty) {
        throw Exception('Dados inválidos para edição');
      }

      final placaVenda = _placasVenda.first;
      final tanque = placaVenda.tanques.first;

      final capacidadeMCubicos = double.tryParse(tanque.capacidade) ?? 0.0;
      final capacidadeLitros = capacidadeMCubicos * 1000.0;

      final ordemId = widget.movimentacaoParaEdicao!['ordem_id']?.toString();
      
      if (ordemId == null || ordemId.isEmpty) {
        throw Exception('Ordem ID não encontrado para esta movimentação');
      }

      DateTime timestampParaSalvar;
      
      if (_dataSelecionada != null) {
        timestampParaSalvar = DateTime(
          _dataSelecionada!.year,
          _dataSelecionada!.month,
          _dataSelecionada!.day,
          0, 0, 0,
        );
      } else {
        timestampParaSalvar = _getHorarioBrasilia();
      }

      final dataMov = 
          '${timestampParaSalvar.year}-${timestampParaSalvar.month.toString().padLeft(2, '0')}-${timestampParaSalvar.day.toString().padLeft(2, '0')}';

      await supabase
          .from('ordens')
          .update({'data_ordem': dataMov})
          .eq('id', ordemId);

      final Map<String, dynamic> dadosBaseMovimentacao = {
        'data_mov': dataMov,
        'ts_mov': timestampParaSalvar.toIso8601String(),
        'updated_at': _getHorarioBrasilia().toIso8601String(),
      };

      await supabase
          .from('movimentacoes')
          .update(dadosBaseMovimentacao)
          .eq('ordem_id', ordemId);

      final Map<String, dynamic> dadosMovimentacaoEspecifica = {
        'produto_id': tanque.produtoId,
        'placa': [placaVenda.controller.text.trim().toUpperCase()],
        'cliente': tanque.clienteController.text.trim(),
        'forma_pagamento': tanque.pagamentoController.text.trim(),
        'quantidade': capacidadeLitros,
        'saida_amb': capacidadeLitros,
        'terminal_orig_id': widget.terminalId,
      };

      await supabase
          .from('movimentacoes')
          .update(dadosMovimentacaoEspecifica)
          .eq('id', widget.movimentacaoParaEdicao!['id']);

      widget.onSalvar(true, 'Programação atualizada!');
      if (mounted) Navigator.of(context).pop(true);
      
    } catch (e) {
      _mostrarErro('Erro ao atualizar venda: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _salvando = false);
      }
    }
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
    setState(() => _salvando = false);
  }

  Widget _buildTanqueLinha(_TanqueVenda tanque) {
    final produtoPreenchido = tanque.produtoId != null && tanque.produtoId!.isNotEmpty;
    final clientePreenchido = tanque.clienteController.text.trim().isNotEmpty;
    final pagamentoPreenchido = tanque.pagamentoController.text.trim().isNotEmpty;
    final incompleto = (produtoPreenchido || clientePreenchido || pagamentoPreenchido) &&
        !(produtoPreenchido && clientePreenchido && pagamentoPreenchido);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: incompleto ? Colors.orange.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: incompleto ? Colors.orange.shade300 : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 140,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D47A1).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF0D47A1).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  '${tanque.capacidade}.000 L',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<String>(
              initialValue: tanque.produtoId,
              isExpanded: true,
              items: [
                const DropdownMenuItem<String>(
                  value: '',
                  child: Text('', style: TextStyle(fontSize: 13)),
                ),
                ..._produtos
                    .map(
                      (p) => DropdownMenuItem<String>(
                        value: p['id'].toString(),
                        child: Text(
                          p['nome_dois'],
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
              ],
              onChanged: (v) => setState(() => tanque.produtoId = v),
              decoration: _inputDecoration('Produto*', incompleto: incompleto && !produtoPreenchido),
            ),
          ),
          
          const SizedBox(width: 12),
          
          SizedBox(
            width: 230,
            child: TextFormField(
              controller: tanque.clienteController,
              style: const TextStyle(fontSize: 13),
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [UpperCaseTextFormatter()],
              decoration: _inputDecoration('Cliente*', incompleto: incompleto && !clientePreenchido),
            ),
          ),
          
          const SizedBox(width: 12),
          
          SizedBox(
            width: 180,
            child: TextFormField(
              controller: tanque.pagamentoController,
              style: const TextStyle(fontSize: 13),
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [UpperCaseTextFormatter()],
              decoration: _inputDecoration('Forma de pagamento*', incompleto: incompleto && !pagamentoPreenchido),
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: IconButton(
              tooltip: 'Limpar linha',
              icon: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.all(6),
                child: const Icon(Icons.backspace, size: 18, color: Colors.black54),
              ),
              onPressed: () {
                tanque.produtoId = null;
                tanque.clienteController.clear();
                tanque.pagamentoController.clear();
                setState(() {});
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCampoData() {
    if (!_modoEdicao) return const SizedBox.shrink();
    
    final dataFormatada = _dataSelecionada != null
        ? '${_dataSelecionada!.day.toString().padLeft(2, '0')}/${_dataSelecionada!.month.toString().padLeft(2, '0')}/${_dataSelecionada!.year}'
        : 'Selecionar data';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(
            width: 180,
            child: Text(
              'Data da programação',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () async {
              DateTime tempDate = _dataSelecionada ?? DateTime.now();
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
                                  const Text('Data da programação', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF0D47A1))),
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
                  _dataSelecionada = DateTime(
                    dataSelecionada.year,
                    dataSelecionada.month,
                    dataSelecionada.day,
                  );
                });
              }
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: 200,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF0D47A1).withOpacity(0.5)),
                borderRadius: BorderRadius.circular(6),
                color: Colors.white,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dataFormatada,
                    style: TextStyle(
                      fontSize: 13,
                      color: _dataSelecionada != null ? Colors.black : Colors.grey.shade600,
                    ),
                  ),
                  const Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Color(0xFF0D47A1),
                  ),
                ],
              ),
            ),
          ),
          if (_dataSelecionada != null)
            IconButton(
              icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
              onPressed: () {
                setState(() {
                  _dataSelecionada = null;
                });
              },
              tooltip: 'Limpar data',
            ),
        ],
      ),
    );
  }

  Widget _buildPlaca(_PlacaVenda placa, {bool primeira = false}) {
    final index = _placasVenda.indexOf(placa);
    final mostrarRemover = !primeira && !_modoEdicao;
    
    return TapRegion(
      onTapOutside: (_) {
        if (placa.mostrarSugestoes) {
          setState(() => placa.mostrarSugestoes = false);
        }
      },
      child: Container(
        key: ValueKey<int>(index),
        margin: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 180,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Placa ${index + 1}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: placa.controller,
                        style: const TextStyle(fontSize: 13),
                        enabled: !_modoEdicao,
                        inputFormatters: [PlacaMascaraFormatter()],
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                          filled: true,
                          fillColor: _modoEdicao ? Colors.grey.shade200 : Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(
                              color: Colors.red,
                              width: 2.0,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(
                              color: Colors.red,
                              width: 2.0,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(
                              color: Colors.red,
                              width: 2.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 8),
                
                if (!_modoEdicao)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Pesquisar placa',
                          icon: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: Colors.grey.shade400),
                            ),
                            padding: const EdgeInsets.all(5),
                            child: placa.carregandoPlacas
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(
                                    Icons.search,
                                    color: Color(0xFF0D47A1),
                                    size: 18,
                                  ),
                          ),
                          onPressed: () => _buscarPlacas(placa, placa.controller.text),
                        ),
                        const SizedBox(width: 8),
                        if (primeira)
                          IconButton(
                            tooltip: 'Adicionar outra placa',
                            icon: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D47A1),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              padding: const EdgeInsets.all(5),
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            onPressed: _adicionarPlaca,
                          )
                        else if (mostrarRemover)
                          IconButton(
                            tooltip: 'Remover esta placa',
                            icon: Container(
                              decoration: BoxDecoration(
                                color: Colors.red.shade500,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              padding: const EdgeInsets.all(5),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            onPressed: () => _removerPlaca(index),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(width: 8),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      barrierDismissible: true,
                      builder: (context) => DialogCadastroPlacas(tipoCadastro: TipoCadastroVeiculo.terceiros),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Cadastrar placa',
                    style: TextStyle(fontSize: 14, decoration: TextDecoration.underline),
                  ),
                ),
              ],
            ),
    
            if (placa.mostrarSugestoes && !_modoEdicao)
              Container(
                margin: const EdgeInsets.only(top: 4, left: 0),
                width: 350,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: placa.placasEncontradas.map((item) {
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      title: Text(
                        item['placas'],
                        style: const TextStyle(fontSize: 13),
                      ),
                      onTap: () => _selecionarPlaca(placa, item),
                    );
                  }).toList(),
                ),
              ),
    
            if (placa.tanques.isNotEmpty) ...[
              const SizedBox(height: 12),
              if (_carregandoProdutos)
                const Center(child: CircularProgressIndicator()),
              ...placa.tanques.map(_buildTanqueLinha),
            ],
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, {bool incompleto = false}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        fontSize: 13,
        color: incompleto ? Colors.orange.shade700 : null,
      ),
      filled: true,
      fillColor: incompleto ? Colors.orange.shade50 : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: BorderSide(
          color: incompleto ? Colors.orange.shade400 : Colors.grey.shade400,
          width: 1,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: BorderSide(
          color: incompleto ? Colors.orange.shade400 : Colors.grey.shade400,
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: BorderSide(
          color: incompleto ? Colors.orange.shade600 : Colors.blue,
          width: 1.2,
        ),
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFF0D47A1), width: 1),
      ),
      child: SizedBox(
        width: 900,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: Color(0xFF0D47A1),
                borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
              ),
              child: Row(
                children: [
                  Text(
                    _modoEdicao ? 'Editar Venda' : 'Nova Venda',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  children: [
                    _buildCampoData(),
                    ...List.generate(
                      _placasVenda.length,
                      (i) => _buildPlaca(
                        _placasVenda[i],
                        primeira: i == 0,
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
                border: Border(top: BorderSide(color: Colors.grey.shade300, width: 1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 150,
                    child: OutlinedButton(
                      onPressed: _salvando
                          ? null
                          : () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        side: BorderSide(color: Colors.grey.shade400, width: 1),
                      ),
                      child: _salvando
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Cancelar',
                              style: TextStyle(fontSize: 13),
                            ),
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  SizedBox(
                    width: 150,
                    child: ElevatedButton(
                      onPressed: _salvando ? null : _salvarVenda,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D47A1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: _salvando
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _modoEdicao ? 'Salvar alterações' : 'Emitir ordem',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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

class _PlacaVenda {
  final TextEditingController controller = TextEditingController();

  bool mostrarSugestoes = false;
  bool carregandoPlacas = false;
  List<Map<String, dynamic>> placasEncontradas = [];

  final List<_TanqueVenda> tanques = [];

  void dispose() {
    controller.dispose();
    for (final t in tanques) {
      t.dispose();
    }
  }
}

class _TanqueVenda {
  final String capacidade;
  String? produtoId;
  final TextEditingController clienteController = TextEditingController();
  final TextEditingController pagamentoController = TextEditingController();

  _TanqueVenda({required this.capacidade});

  void reset() {
    produtoId = '';
    clienteController.clear();
    pagamentoController.clear();
  }

  void dispose() {
    clienteController.dispose();
    pagamentoController.dispose();
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class PlacaMascaraFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var texto = newValue.text.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();

    // Limitar a 7 caracteres alfanuméricos (ABC1234)
    if (texto.length > 7) {
      texto = texto.substring(0, 7);
    }

    String resultado = '';
    for (int i = 0; i < texto.length; i++) {
      if (i < 3) {
        // Primeiros 3 devem ser letras
        if (RegExp(r'[A-Z]').hasMatch(texto[i])) {
          resultado += texto[i];
        }
      } else {
        // Restantes podem ser letras ou números
        resultado += texto[i];
      }
    }

    // Adicionar hífen automático após o 3º caractere
    if (resultado.length > 3) {
      resultado = '${resultado.substring(0, 3)}-${resultado.substring(3)}';
    }

    return TextEditingValue(
      text: resultado,
      selection: TextSelection.collapsed(offset: resultado.length),
    );
  }
}