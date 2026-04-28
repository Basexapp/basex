import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'nova_transf.dart';

// ==============================================================
//                PÁGINA DE TRANSFERÊNCIAS
// ==============================================================
class TransferenciasPage extends StatefulWidget {
  final VoidCallback onVoltar;

  const TransferenciasPage({super.key, required this.onVoltar});

  @override
  State<TransferenciasPage> createState() => _TransferenciasPageState();
}

class _TransferenciasPageState extends State<TransferenciasPage> {
  bool carregando = true;

  // Lista do dia (bloco 1)
  List<Map<String, dynamic>> transferenciasHoje = [];

  // Lista histórica paginada (bloco 2)
  List<Map<String, dynamic>> transferenciasHistorico = [];

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _horizontalHeaderControllerHoje = ScrollController();
  final ScrollController _horizontalBodyControllerHoje = ScrollController();
  final ScrollController _horizontalHeaderControllerHist = ScrollController();
  final ScrollController _horizontalBodyControllerHist = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  // Paginação histórico
  int _paginaAtual = 1;
  final int _porPagina = 20;
  bool _temMaisPaginas = true;
  bool _carregandoHistorico = false;

  @override
  void initState() {
    super.initState();
    carregarHoje();
    carregarHistorico(reset: true);

    // Sincroniza rolagem horizontal do bloco HOJE
    _horizontalHeaderControllerHoje.addListener(() {
      if (_horizontalBodyControllerHoje.hasClients &&
          _horizontalBodyControllerHoje.offset !=
              _horizontalHeaderControllerHoje.offset) {
        _horizontalBodyControllerHoje
            .jumpTo(_horizontalHeaderControllerHoje.offset);
      }
    });

    _horizontalBodyControllerHoje.addListener(() {
      if (_horizontalHeaderControllerHoje.hasClients &&
          _horizontalHeaderControllerHoje.offset !=
              _horizontalBodyControllerHoje.offset) {
        _horizontalHeaderControllerHoje
            .jumpTo(_horizontalBodyControllerHoje.offset);
      }
    });

    // Sincroniza rolagem horizontal do bloco HISTÓRICO
    _horizontalHeaderControllerHist.addListener(() {
      if (_horizontalBodyControllerHist.hasClients &&
          _horizontalBodyControllerHist.offset !=
              _horizontalHeaderControllerHist.offset) {
        _horizontalBodyControllerHist
            .jumpTo(_horizontalHeaderControllerHist.offset);
      }
    });

    _horizontalBodyControllerHist.addListener(() {
      if (_horizontalHeaderControllerHist.hasClients &&
          _horizontalHeaderControllerHist.offset !=
              _horizontalBodyControllerHist.offset) {
        _horizontalHeaderControllerHist
            .jumpTo(_horizontalBodyControllerHist.offset);
      }
    });
  }

  @override
  void dispose() {
    _horizontalHeaderControllerHoje.dispose();
    _horizontalBodyControllerHoje.dispose();
    _horizontalHeaderControllerHist.dispose();
    _horizontalBodyControllerHist.dispose();
    _verticalScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  DateTime _inicioHoje() {
    final agora = DateTime.now();
    return DateTime(agora.year, agora.month, agora.day);
  }

  DateTime _fimHoje() {
    final agora = DateTime.now();
    return DateTime(agora.year, agora.month, agora.day, 23, 59, 59);
  }

  Future<void> carregarHoje() async {
    setState(() => carregando = true);

    try {
      final supabase = Supabase.instance.client;
      final inicio = _inicioHoje().toIso8601String();
      final fim = _fimHoje().toIso8601String();

      final response = await supabase
          .from("movimentacoes")
          .select('''
            *,
            motoristas!motorista_id(nome),
            produtos!produto_id(nome),
            transportadoras!transportadora_id(nome_dois),
            terminal_origem:terminais!terminal_orig_id(nome_dois),
            terminal_destino:terminais!terminal_dest_id(nome_dois)
          ''')
          .or('tipo_op.eq.transf,tipo_op.eq.consumo')
          .gte("data_mov", inicio)
          .lte("data_mov", fim)
          .order("data_mov", ascending: false);

      setState(() {
        transferenciasHoje = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint("Erro ao carregar transferencias de hoje: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar transferências de hoje: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (mounted) {
      setState(() => carregando = false);
    }
  }

  Future<void> carregarHistorico({bool reset = false}) async {
    if (_carregandoHistorico) return;

    if (reset) {
      _paginaAtual = 1;
      _temMaisPaginas = true;
      transferenciasHistorico.clear();
    }

    if (!_temMaisPaginas) return;

    setState(() => _carregandoHistorico = true);

    try {
      final supabase = Supabase.instance.client;
      final from = (_paginaAtual - 1) * _porPagina;
      final to = from + _porPagina - 1;

      final response = await supabase
          .from("movimentacoes")
          .select('''
            *,
            motoristas!motorista_id(nome),
            produtos!produto_id(nome),
            transportadoras!transportadora_id(nome_dois),
            terminal_origem:terminais!terminal_orig_id(nome_dois),
            terminal_destino:terminais!terminal_dest_id(nome_dois)
          ''')
          .or('tipo_op.eq.transf,tipo_op.eq.consumo')
          .order("data_mov", ascending: false)
          .range(from, to);

      final novos = List<Map<String, dynamic>>.from(response);

      setState(() {
        transferenciasHistorico.addAll(novos);
        _temMaisPaginas = novos.length == _porPagina;
        if (_temMaisPaginas) _paginaAtual++;
      });
    } catch (e) {
      debugPrint("Erro ao carregar histórico: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar histórico: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _carregandoHistorico = false);
      }
    }
  }

  List<Map<String, dynamic>> _filtrar(List<Map<String, dynamic>> lista) {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) return lista;

    return lista.where((t) {
      final tipoOp = t['tipo_op']?.toString().toLowerCase() ?? '';
      return (t['descricao']?.toString().toLowerCase() ?? '').contains(query) ||
          (t['placa']?.toString().toLowerCase() ?? '').contains(query) ||
          tipoOp.contains(query) ||
          (t['data_mov']?.toString().toLowerCase() ?? '').contains(query) ||
          (t['qtd_faturada']?.toString().toLowerCase() ?? '').contains(query) ||
          (t['motoristas']?['nome']?.toString().toLowerCase() ?? '').contains(query) ||
          (t['produtos']?['nome']?.toString().toLowerCase() ?? '').contains(query) ||
          (t['transportadoras']?['nome_dois']?.toString().toLowerCase() ?? '').contains(query) ||
          (t['terminal_origem']?['nome_dois']?.toString().toLowerCase() ?? '').contains(query) ||
          (t['terminal_destino']?['nome_dois']?.toString().toLowerCase() ?? '').contains(query);
    }).toList();
  }

  String _extrairPrimeiraPlaca(dynamic placaData) {
    if (placaData == null) return "";
    if (placaData is List && placaData.isNotEmpty) return placaData.first.toString();
    if (placaData is String) return placaData;
    return placaData.toString();
  }

  String _extrairPlacaPorIndex(dynamic placaData, int index) {
    if (placaData == null) return "";
    if (placaData is List && placaData.length > index) {
      return placaData[index].toString();
    }
    return "";
  }

  String _formatarQuantidade(String quantidade) {
    try {
      final apenasNumeros = quantidade.replaceAll(RegExp(r'[^\d]'), '');
      if (apenasNumeros.isEmpty) return '';
      final valor = int.parse(apenasNumeros);
      if (valor == 0) return '';
      if (valor > 999) {
        final parteMilhar = (valor ~/ 1000).toString();
        final parteCentena = (valor % 1000).toString().padLeft(3, '0');
        return '$parteMilhar.$parteCentena';
      }
      return valor.toString();
    } catch (_) {
      return quantidade;
    }
  }

  Widget _buildTabela(
    String titulo,
    List<Map<String, dynamic>> dados, {
    required ScrollController headerController,
    required ScrollController bodyController,
    bool paginacao = false,
  }) {
    final lista = _filtrar(dados);

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text(
                    titulo,
                    style:
                        const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            if (lista.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nenhuma transferência encontrada',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                    if (!paginacao) ...[
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _mostrarDialogNovaTransferencia,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text(
                          'Nova transferência',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ],
                  ],
                ),
              )
            else
              Column(
                children: [
                  Scrollbar(
                    controller: headerController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: headerController,
                      scrollDirection: Axis.horizontal,
                        child: SizedBox(
                        width: 1390,
                        child: Container(
                          height: 40,
                          color: const Color(0xFF0D47A1),
                          child: Row(
                            children: [
                              _th("", 40),
                              _th("Data", 80),
                              _th("Placa", 100),
                              _th("Motorista", 140),
                              _th("Produto", 120),
                              _th("Qtd", 80),
                              _th("Transportadora", 140),
                              _th("Cavalo", 100),
                              _th("Reboq. 1", 100),
                              _th("Reboq. 2", 100),
                              _th("Origem", 140),
                              _th("Destino", 140),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Scrollbar(
                    controller: bodyController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: bodyController,
                      scrollDirection: Axis.horizontal,
                        child: SizedBox(
                        width: 1390,
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: lista.length,
                          itemBuilder: (context, index) {
                            final t = lista[index];
                            final data = t['data_mov'] is String
                                ? DateTime.parse(t['data_mov'])
                                : (t['data_mov'] is DateTime
                                    ? t['data_mov']
                                    : DateTime.now());

                            final motoristaNome =
                                t['motoristas']?['nome']?.toString() ?? '';
                            final produtoNome =
                                t['produtos']?['nome']?.toString() ?? '';
                            final transportadoraNome =
                                t['transportadoras']?['nome_dois']?.toString() ??
                                    '';
                            final origemNome =
                                t['terminal_origem']?['nome_dois']?.toString() ?? '';
                            final destinoNome =
                                t['terminal_destino']?['nome_dois']?.toString() ?? '';

                            final quantidade = t['qtd_faturada']?.toString() ?? '';
                            final quantidadeFormatada =
                                quantidade.isNotEmpty && quantidade != '0'
                                    ? _formatarQuantidade(quantidade)
                                    : '';

                            return Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: index % 2 == 0
                                    ? Colors.grey.shade50
                                    : Colors.white,
                                border: Border(
                                  bottom: BorderSide(
                                      color: Colors.grey.shade200, width: 0.5),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    alignment: Alignment.center,
                                    child: PopupMenuButton<String>(
                                      color: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      icon: Icon(Icons.more_vert, size: 18, color: Colors.grey.shade700),
                                      onSelected: (value) async {
                                        if (value == 'cancel') {
                                          final isConsumo = t['tipo_op'] == 'consumo';
                                          final tituloDialog = isConsumo ? 'Cancelar consumo' : 'Cancelar transferência';
                                          final corpoDialog = isConsumo ? 'Tem certeza que deseja cancelar o registro de consumo?\n' : 'Tem certeza que deseja cancelar a transferência?\n';

                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => Dialog(
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
                                                    // Header
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                                      decoration: const BoxDecoration(
                                                        color: Color(0xFF0D47A1),
                                                        borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                                                          const SizedBox(width: 8),
                                                          Text(
                                                            tituloDialog,
                                                            style: const TextStyle(
                                                              fontSize: 15,
                                                              fontWeight: FontWeight.w600,
                                                              color: Colors.white,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),

                                                    // Content
                                                    Padding(
                                                      padding: const EdgeInsets.all(20),
                                                      child: RichText(
                                                        textAlign: TextAlign.center,
                                                        text: TextSpan(
                                                          style: const TextStyle(
                                                            fontSize: 14,
                                                            height: 1.4,
                                                            color: Colors.black,
                                                          ),
                                                          children: [
                                                            TextSpan(text: corpoDialog),
                                                            const TextSpan(text: 'Essa ação é irreversível.', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                                          ],
                                                        ),
                                                      ),
                                                    ),

                                                    // Footer
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
                                                              onPressed: () => Navigator.of(ctx).pop(false),
                                                              style: OutlinedButton.styleFrom(
                                                                padding: const EdgeInsets.symmetric(vertical: 10),
                                                                side: BorderSide(color: Colors.grey.shade400),
                                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                              ),
                                                              child: const Text('Voltar', style: TextStyle(fontSize: 13)),
                                                            ),
                                                          ),
                                                          const SizedBox(width: 12),
                                                          SizedBox(
                                                            width: 120,
                                                            child: ElevatedButton(
                                                              onPressed: () => Navigator.of(ctx).pop(true),
                                                              style: ElevatedButton.styleFrom(
                                                                backgroundColor: Colors.red,
                                                                foregroundColor: Colors.white,
                                                                padding: const EdgeInsets.symmetric(vertical: 10),
                                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                              ),
                                                              child: const Text('Sim, cancelar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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

                                          if (confirm == true) {
                                            await _executarCancelarTransferencia(t);
                                          }
                                        }
                                      },
                                      itemBuilder: (ctx) {
                                        final isConsumo = t['tipo_op'] == 'consumo';
                                        return [
                                          PopupMenuItem<String>(
                                            value: 'cancel',
                                            height: 36,
                                            child: Text(
                                              isConsumo ? 'Cancelar consumo' : 'Cancelar transferência',
                                              style: const TextStyle(fontSize: 13),
                                            ),
                                          ),
                                        ];
                                      },
                                      offset: const Offset(0, 36),
                                    ),
                                  ),
                                  _cell(
                                      '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}',
                                      80),
                                  _cell(_extrairPrimeiraPlaca(t['placa']), 100),
                                  _cell(motoristaNome, 140),
                                  _cell(produtoNome, 120),
                                  _cell(quantidadeFormatada, 80,
                                      isNumber: true),
                                  _cell(transportadoraNome, 140),
                                  _cell(_extrairPlacaPorIndex(t['placa'], 0), 100),
                                  _cell(_extrairPlacaPorIndex(t['placa'], 1), 100),
                                  _cell(_extrairPlacaPorIndex(t['placa'], 2), 100),
                                  _cell(origemNome, 140),
                                  _cell(t['tipo_op'] == 'consumo' ? 'CONSUMO' : destinoNome, 140),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  Container(
                    color: Colors.grey.shade100,
                    padding: const EdgeInsets.all(12),
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${lista.length} transferência(s)',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (!paginacao) ...[
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _mostrarDialogNovaTransferencia,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text(
                              'Nova transferência',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7D32),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ],
                        if (paginacao && _temMaisPaginas) ...[
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () => carregarHistorico(),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF0D47A1)),
                              foregroundColor: const Color(0xFF0D47A1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            child: const Text('Carregar mais', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _th(String texto, double largura) {
    return Container(
      width: largura,
      alignment: Alignment.center,
      child: Text(
        texto,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _cell(String texto, double largura, {bool isNumber = false}) {
    return Container(
      width: largura,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      child: Text(
        texto.isNotEmpty ? texto : '-',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade700,
          fontWeight: isNumber ? FontWeight.w600 : FontWeight.normal,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Future<void> _executarCancelarTransferencia(Map<String, dynamic> t) async {
    final ordemId = t['ordem_id'];
    final isConsumo = t['tipo_op'] == 'consumo';
    
    if (ordemId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isConsumo ? 'Ordem não encontrada para este consumo.' : 'Ordem não encontrada para esta transferência.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      final supabase = Supabase.instance.client;

      final movimentacaoId = t['id'];
      if (movimentacaoId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ID da movimentação não encontrado.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final movimentacaoResponse = await supabase
          .from('movimentacoes')
          .select('status_circuito_orig, status_circuito_dest, tipo_op')
          .eq('id', movimentacaoId)
          .single();

      final statusCircuitoOrig = movimentacaoResponse['status_circuito_orig'];
      final statusCircuitoDest = movimentacaoResponse['status_circuito_dest'];
      
      int? statusOrigInt;
      int? statusDestInt;
      
      if (statusCircuitoOrig != null) {
        if (statusCircuitoOrig is int) {
          statusOrigInt = statusCircuitoOrig;
        } else if (statusCircuitoOrig is String) {
          statusOrigInt = int.tryParse(statusCircuitoOrig);
        }
      }
      
      if (statusCircuitoDest != null) {
        if (statusCircuitoDest is int) {
          statusDestInt = statusCircuitoDest;
        } else if (statusCircuitoDest is String) {
          statusDestInt = int.tryParse(statusCircuitoDest);
        }
      }

      // Verifica se algum dos status (origem ou destino) está acima de 3
      if ((statusOrigInt != null && statusOrigInt > 3) || 
          (statusDestInt != null && statusDestInt > 3)) {
        if (!mounted) return;

        await showDialog(
          context: context,
          builder: (ctx) => Dialog(
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
                        Icon(Icons.block, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Cancelamento não permitido',
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
                      isConsumo 
                        ? 'Não é possível cancelar este consumo, pois o veículo já teve ordem de análise emitida.'
                        : 'Não é possível cancelar esta transferência, pois o veículo já teve ordem de análise emitida. Entre em contato com o supervisor do terminal de origem.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: Colors.black,
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
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D47A1),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            child: const Text('OK', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
        
        return;
      }

      await supabase.from('ordens').delete().eq('id', ordemId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isConsumo ? 'Consumo cancelado com sucesso.' : 'Ordem cancelada com sucesso.')),
      );

      await carregarHoje();
      await carregarHistorico(reset: true);
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao cancelar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _mostrarDialogNovaTransferencia() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const NovaTransferenciaDialog(),
    );

    if (result == true) {
      await carregarHoje();
      await carregarHistorico(reset: true);
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Transferências entre filiais"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onVoltar,
        ),
        actions: [
          Container(
            width: 300,
            margin: const EdgeInsets.only(right: 16),
            child: _buildSearchField(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await carregarHoje();
              await carregarHistorico(reset: true);
            },
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    controller: _verticalScrollController,
                    children: [
                      _buildTabela(
                        "Transferências de hoje",
                        transferenciasHoje,
                        headerController: _horizontalHeaderControllerHoje,
                        bodyController: _horizontalBodyControllerHoje,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Divider(
                          color: const Color(0xFF0D47A1).withOpacity(0.3),
                          thickness: 1,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildTabela(
                        "Transferências entre filiais - Histórico",
                        transferenciasHistorico,
                        headerController: _horizontalHeaderControllerHist,
                        bodyController: _horizontalBodyControllerHist,
                        paginacao: true,
                      ),
                      if (_carregandoHistorico)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                // Rodapé Institucional Fixo
                Container(
                  height: 50,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade300, width: 0.5),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'PowerTank Terminais 2026, All rights reserved.',
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
    );
  }
}