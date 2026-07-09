import 'dart:convert';
import 'dart:html' as html;
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RelatorioVendasPage extends StatefulWidget {
  final String? terminalId;
  final String nomeTerminal;
  final String? empresaId;
  final DateTime dataInicial;
  final DateTime dataFinal;
  final String? produtoFiltro;
  final String tipoRelatorio;

  const RelatorioVendasPage({
    super.key,
    this.terminalId,
    required this.nomeTerminal,
    this.empresaId,
    required this.dataInicial,
    required this.dataFinal,
    this.produtoFiltro,
    required this.tipoRelatorio,
  });

  @override
  State<RelatorioVendasPage> createState() => _RelatorioVendasPageState();
}

class _RelatorioVendasPageState extends State<RelatorioVendasPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _vendas = [];
  List<Map<String, dynamic>> _vendasOrdenadas = [];
  String? _empresaId;
  String? _terminalIdUsar;
  bool _carregando = true;
  bool _erro = false;
  String _mensagemErro = '';
  String? _nomeProdutoSelecionado;

  // Estoque inicial e final
  Map<String, dynamic> _estoqueInicial = {
    'ambiente': 0,
    'vinte_graus': 0,
  };
  
  Map<String, dynamic> _estoqueFinal = {
    'ambiente': 0,
    'vinte_graus': 0,
  };

  // ScrollControllers
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalHeaderController = ScrollController();
  final ScrollController _horizontalBodyController = ScrollController();

  // Constantes de layout
  static const double _alturaCabecalho = 40;
  static const double _alturaLinha = 40;
  static const double _alturaRodape = 32;

  // Larguras das colunas
  static const double _larguraData = 120;
  static const double _larguraProduto = 180;
  static const double _larguraClienteDestino = 160;
  static const double _larguraDescricao = 240;
  static const double _larguraNumerica = 120;

  // GETTER para calcular largura total DINAMICAMENTE
  double get _larguraTabela {
    bool mostrarColunaProduto = widget.produtoFiltro == null || widget.produtoFiltro == 'todos';
    bool mostrarColunaClienteDestino = widget.tipoRelatorio != 'sintetico';

    // 4 colunas numéricas: Entrada Amb, Entrada 20°C, Saída Amb, Saída 20°C
    double soma = _larguraData +
                  _larguraDescricao +
                  (_larguraNumerica * 4);

    if (mostrarColunaClienteDestino) soma += _larguraClienteDestino;
    if (mostrarColunaProduto) soma += _larguraProduto;

    return soma;
  }

  Color _getCorFundoEntrada() {
    return Colors.green.shade50.withOpacity(0.3);
  }

  Color _getCorFundoSaida() {
    return Colors.red.shade50.withOpacity(0.3);
  }

  String _colunaOrdenacao = 'data_mov';
  bool _ordenacaoAscendente = true;
  bool _baixandoExcel = false;

  @override
  void initState() {
    super.initState();
    _setupScrollControllers();
    _carregarDados();
  }
  
  void _setupScrollControllers() {
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

  Future<void> _carregarDados() async {
    setState(() {
      _carregando = true;
      _erro = false;
    });

    // Print dos parâmetros recebidos

    try {
      if (widget.terminalId != null && widget.terminalId!.isNotEmpty) {
        _terminalIdUsar = widget.terminalId;
      }

      if (widget.empresaId != null && widget.empresaId!.isNotEmpty) {
        _empresaId = widget.empresaId;
      } else if (_terminalIdUsar != null && _terminalIdUsar!.isNotEmpty) {
        final relacaoTerminal = await _supabase
            .from('relacoes_terminais')
            .select('empresa_id')
            .eq('terminal_id', _terminalIdUsar!)
            .maybeSingle();

        _empresaId = relacaoTerminal?['empresa_id']?.toString();
      }

      if (_empresaId == null || _empresaId!.isEmpty) {
        debugPrint('❌ _empresaId está nulo ou vazio');
        throw Exception('Não foi possível identificar a empresa');
      }

      if (widget.produtoFiltro != null && widget.produtoFiltro != 'todos') {
        final produtoData = await _supabase
            .from('produtos')
            .select('nome')
            .eq('id', widget.produtoFiltro!)
            .maybeSingle();
        
        _nomeProdutoSelecionado = produtoData?['nome']?.toString();
      }

      // Carregar estoque inicial (do final do período anterior)
      await _carregarEstoqueInicial();

      await _carregarDadosAnalitico();

      if (widget.tipoRelatorio == 'sintetico') {
        await _carregarDadosSintetico();
      }
      
      // Calcular estoque final
      _calcularEstoqueFinal();
      
      if (mounted) {
        setState(() {
          _carregando = false;
        });
      }
      
    } catch (e) {
      debugPrint('❌ Erro ao carregar movimentações: $e');
      if (mounted) {
        setState(() {
          _carregando = false;
          _erro = true;
          _mensagemErro = e.toString();
        });
      }
    }
  }

  Future<void> _carregarEstoqueInicial() async {
    try {
      // Buscar saldo acumulado até o dia anterior à data inicial
      final diaAnterior = widget.dataInicial.subtract(const Duration(days: 1));
      final diaAnteriorStr =
          '${diaAnterior.year}-${diaAnterior.month.toString().padLeft(2, '0')}-${diaAnterior.day.toString().padLeft(2, '0')}T23:59:59.999';

      var query = _supabase
          .from('movimentacoes')
          .select('''
            entrada_amb,
            entrada_vinte,
            saida_amb,
            saida_vinte
          ''')
          .eq('empresa_id', _empresaId!)
          .lte('data_mov', diaAnteriorStr);

      if (widget.produtoFiltro != null && widget.produtoFiltro != 'todos') {
        query = query.eq('produto_id', widget.produtoFiltro!);
      }

      final registrosAnteriores = await query;

      num saldoAmb = 0;
      num saldoVinte = 0;

      for (var mov in registrosAnteriores) {
        saldoAmb += (mov['entrada_amb'] ?? 0) as num;
        saldoAmb -= (mov['saida_amb'] ?? 0) as num;
        saldoVinte += (mov['entrada_vinte'] ?? 0) as num;
        saldoVinte -= (mov['saida_vinte'] ?? 0) as num;
      }

      _estoqueInicial = {
        'ambiente': saldoAmb,
        'vinte_graus': saldoVinte,
      };

    } catch (e) {
      debugPrint('Erro ao carregar estoque inicial: $e');
      _estoqueInicial = {
        'ambiente': 0,
        'vinte_graus': 0,
      };
    }
  }

  void _calcularEstoqueFinal() {
    if (_vendasOrdenadas.isEmpty) {
      _estoqueFinal = Map.from(_estoqueInicial);
      return;
    }

    // Pegar o último saldo das vendas
    final ultimaMov = _vendasOrdenadas.last;
    _estoqueFinal = {
      'ambiente': ultimaMov['saldo_amb'] ?? 0,
      'vinte_graus': ultimaMov['saldo_vinte'] ?? 0,
    };
  }

  // FUNÇÃO: Normalização de venda
  Map<String, dynamic> _normalizarVenda(
    Map<String, dynamic> mov,
    String contextoId,
  ) {
    // Inicializar acumuladores
    num entradaAmb = 0;
    num entradaVinte = 0;
    num saidaAmb = 0;
    num saidaVinte = 0;

    final tipoOp = mov['tipo_op']?.toString() ?? '';
    final destinoId = mov['filial_destino_id']?.toString();
    final origemId = mov['filial_origem_id']?.toString();
    final tipoMovDest = mov['tipo_mov_dest']?.toString();
    final tipoMovOrig = mov['tipo_mov_orig']?.toString();

    // Regras por tipo de operação
    switch (tipoOp) {
      case 'transf':
        if (destinoId == contextoId && tipoMovDest == 'entrada') {
          // ENTRADA por transferência
          entradaAmb += (mov['entrada_amb'] ?? 0) as num;
          entradaVinte += (mov['entrada_vinte'] ?? 0) as num;
        } else if (origemId == contextoId && tipoMovOrig == 'saida') {
          // SAÍDA por transferência
          saidaAmb += (mov['saida_amb'] ?? 0) as num;
          saidaVinte += (mov['saida_vinte'] ?? 0) as num;
        }
        break;

      case 'venda':
        // Para vendas, usar os campos diretos saida_amb e saida_vinte
        saidaAmb += (mov['saida_amb'] ?? 0) as num;
        saidaVinte += (mov['saida_vinte'] ?? 0) as num;
        break;

      default:
        // Outros tipos (CACL, etc): usar campos diretos
        entradaAmb += (mov['entrada_amb'] ?? 0) as num;
        entradaVinte += (mov['entrada_vinte'] ?? 0) as num;
        saidaAmb += (mov['saida_amb'] ?? 0) as num;
        saidaVinte += (mov['saida_vinte'] ?? 0) as num;
        break;
    }

    return {
      'entrada_amb': entradaAmb,
      'entrada_vinte': entradaVinte,
      'saida_amb': saidaAmb,
      'saida_vinte': saidaVinte,
    };
  }

  Future<void> _carregarDadosAnalitico() async {
    try {
      // Query única para buscar todas as vendas relevantes
      var query = _supabase
          .from('movimentacoes')
          .select('''
            id,
            data_mov,
            descricao,
            cliente,
            entrada_amb,
            entrada_vinte,
            saida_amb,
            saida_vinte,
            produto_id,
            tipo_op,
            tipo_mov_orig,
            tipo_mov_dest,
            filial_id,
            filial_destino_id,
            filial_origem_id,
            produtos!movimentacoes_produto_id_fkey1(
              id,
              nome
            )
          ''')
          .eq('empresa_id', _empresaId!);

      // FILTRO DE DATA: usar dataInicial e dataFinal
      final dataInicioStr = DateTime(
        widget.dataInicial.year,
        widget.dataInicial.month,
        widget.dataInicial.day,
        0, 0, 0, 0,
      ).toIso8601String();

      final dataFimStr = DateTime(
        widget.dataFinal.year,
        widget.dataFinal.month,
        widget.dataFinal.day,
        23, 59, 59, 999,
      ).toIso8601String();

      query = query
          .gte('data_mov', dataInicioStr)
          .lte('data_mov', dataFimStr);

      // FILTRO DE PRODUTO
      if (widget.produtoFiltro != null && widget.produtoFiltro != 'todos') {
        query = query.eq('produto_id', widget.produtoFiltro!);
      }

      // EXECUTAR QUERY
      final dados = await query.order('data_mov', ascending: true);

      // Coletar IDs de destinos de transferências e buscar nomes em lote
      final Set<String> destinosIds = {};
      for (var mov in dados) {
        if ((mov['tipo_op']?.toString() ?? '') == 'transf' && mov['filial_destino_id'] != null) {
          destinosIds.add(mov['filial_destino_id'].toString());
        }
      }

      final Map<String, String> nomesDestino = {};
      if (destinosIds.isNotEmpty) {
        try {
            final orExpr = destinosIds.map((id) => 'id.eq.$id').join(',');
            final filiaisRes = await _supabase
              .from('filiais')
              .select('id, nome_dois')
              .or(orExpr);

          for (var f in filiaisRes) {
            nomesDestino[f['id'].toString()] = f['nome_dois']?.toString() ?? '';
          }
        } catch (e) {
          debugPrint('Erro ao buscar nomes dos destinos: $e');
        }
      }

      if (dados.isEmpty) {
        // nenhum dado encontrado
      }

      // PROCESSAR DADOS
      final List<Map<String, dynamic>> analitico = [];

      // Calcular saldo acumulado começando com estoque inicial
      num saldoAmb = _estoqueInicial['ambiente'] as num;
      num saldoVinte = _estoqueInicial['vinte_graus'] as num;

      for (var mov in dados) {
        final normalizado = _normalizarVenda(
          mov,
          _terminalIdUsar ?? widget.terminalId ?? '',
        );

        final produto = mov['produtos'] as Map<String, dynamic>?;
        final produtoNome = produto?['nome']?.toString() ?? '';

        // Atualizar saldos
        saldoAmb += (normalizado['entrada_amb'] as num) - (normalizado['saida_amb'] as num);
        saldoVinte += (normalizado['entrada_vinte'] as num) - (normalizado['saida_vinte'] as num);

        analitico.add({
          ...normalizado,
          'id': mov['id'],
          'data_mov': mov['data_mov'],
          'descricao': mov['descricao'] ?? '',
          'cliente_destino': (() {
            final tipoOpMov = mov['tipo_op']?.toString() ?? '';
            if (tipoOpMov == 'venda') {
              return mov['cliente']?.toString() ?? '';
            } else if (tipoOpMov == 'transf') {
              final fd = mov['filial_destino_id']?.toString();
              return nomesDestino[fd] ?? fd ?? '';
            }
            return mov['cliente']?.toString() ?? mov['filial_destino_id']?.toString() ?? '';
          })(),
          'produto_nome': produtoNome,
          'produto_id': mov['produto_id'],
          'saldo_amb': saldoAmb,
          'saldo_vinte': saldoVinte,
        });
      }

      // Ordenar e atualizar estado
      _ordenarDados(analitico, 'data_mov', true);

    } catch (e) {
      debugPrint('❌ Erro ao carregar dados analíticos: $e');
      rethrow;
    }
  }

  Future<void> _carregarDadosSintetico() async {
    try {
      
      final Map<String, List<Map<String, dynamic>>> porDia = {};
      
      for (var mov in _vendas) {
        final dataStr = (mov['data_mov'] as String).substring(0, 10);
        if (!porDia.containsKey(dataStr)) {
          porDia[dataStr] = [];
        }
        porDia[dataStr]!.add(mov);
      }

      // Gerar lista sintética agrupada por dia
      final List<Map<String, dynamic>> sintetico = [];
      
      // Ordenar datas
      final datasOrdenadas = porDia.keys.toList()..sort();

      // Calcular saldos começando com estoque inicial
      num saldoAmbAcumulado = _estoqueInicial['ambiente'] as num;
      num saldoVinteAcumulado = _estoqueInicial['vinte_graus'] as num;

      for (var dataStr in datasOrdenadas) {
        final movsDoDia = porDia[dataStr]!;
        
        // Calcular totais do dia
        num totalEntradaAmb = 0;
        num totalEntradaVinte = 0;
        num totalSaidaAmb = 0;
        num totalSaidaVinte = 0;

        for (var mov in movsDoDia) {
          totalEntradaAmb += (mov['entrada_amb'] ?? 0) as num;
          totalEntradaVinte += (mov['entrada_vinte'] ?? 0) as num;
          totalSaidaAmb += (mov['saida_amb'] ?? 0) as num;
          totalSaidaVinte += (mov['saida_vinte'] ?? 0) as num;
        }

        // Atualizar saldos acumulados
        saldoAmbAcumulado += totalEntradaAmb - totalSaidaAmb;
        saldoVinteAcumulado += totalEntradaVinte - totalSaidaVinte;

        // Obter nome do produto
        String produtoNome;
        if (widget.produtoFiltro == null || widget.produtoFiltro == 'todos') {
          produtoNome = 'Todos';
        } else {
          produtoNome = _nomeProdutoSelecionado ?? 'Produto Selecionado';
        }

        sintetico.add({
          'id': 'sintetico_$dataStr',
          'data_mov': dataStr,
          'descricao': 'Resumo do dia',
          'entrada_amb': totalEntradaAmb,
          'entrada_vinte': totalEntradaVinte,
          'saida_amb': totalSaidaAmb,
          'saida_vinte': totalSaidaVinte,
          'produto_nome': produtoNome,
          'produto_id': widget.produtoFiltro,
          'saldo_amb': saldoAmbAcumulado,
          'saldo_vinte': saldoVinteAcumulado,
        });
      }

      // Atualizar estado com dados sintéticos
      setState(() {
        _vendas = sintetico;
        _vendasOrdenadas = List.from(sintetico);
      });

    } catch (e) {
      debugPrint('Erro ao carregar dados sintéticos: $e');
      rethrow;
    }
  }

  Future<void> _baixarExcel() async {
    if (_vendasOrdenadas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não há dados para exportar'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _baixandoExcel = true;
    });

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Gerando relatório Excel...'),
          duration: Duration(seconds: 5),
        ),
      );

      final requestData = {
        'produto_id': widget.produtoFiltro,
        'empresa_id': widget.empresaId,
        'terminal_id': widget.terminalId,
        'data': {
          'inicial': widget.dataInicial.toIso8601String(),
          'final': widget.dataFinal.toIso8601String(),
        },
        'tipoRelatorio': widget.tipoRelatorio,
        'estoqueInicial': _estoqueInicial,
        'estoqueFinal': _estoqueFinal,
      };

      final response = await _chamarEdgeFunctionBinaria(requestData);
      
      if (response.statusCode != 200) {
        final errorBody = await response.body;
        throw Exception('Erro ${response.statusCode}: ${errorBody.isNotEmpty ? errorBody : "Falha na Edge Function"}');
      }

      final bytes = response.bodyBytes;
      
      if (bytes.isEmpty) {
        throw Exception('Arquivo vazio recebido da Edge Function');
      }

      final blob = html.Blob(
        [bytes], 
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      );
      final url = html.Url.createObjectUrlFromBlob(blob);
      
      final nomeFormatado = widget.nomeTerminal
          .replaceAll(' ', '_')
          .replaceAll(RegExp(r'[^\w_]'), '');
      
      final diaIni = widget.dataInicial.day.toString().padLeft(2, '0');
      final mesIni = widget.dataInicial.month.toString().padLeft(2, '0');
      final anoIni = widget.dataInicial.year.toString();
      final diaFim = widget.dataFinal.day.toString().padLeft(2, '0');
      final mesFim = widget.dataFinal.month.toString().padLeft(2, '0');
      final anoFim = widget.dataFinal.year.toString();
      final fileName = 'relatorio_vendas_${nomeFormatado}_${diaIni}_${mesIni}_${anoIni}_a_${diaFim}_${mesFim}_${anoFim}.xlsx';
      
      html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      
      html.Url.revokeObjectUrl(url);

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Download do Excel iniciado! Verifique sua pasta de downloads.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );

    } catch (e) {
      debugPrint('Erro detalhado ao baixar relatório: $e');
      
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Erro: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _baixandoExcel = false;
        });
      }
    }
  }

  Future<http.Response> _chamarEdgeFunctionBinaria(Map<String, dynamic> requestData) async {
    try {
      const supabaseUrl = 'https://ikaxzlpaihdkqyjqrxyw.supabase.co';
      
      final session = Supabase.instance.client.auth.currentSession;

      if (session == null || session.accessToken.isEmpty) {
        throw Exception('Sessão inválida. Faça login novamente.');
      }

      return await _fazerRequisicao(
        supabaseUrl,
        session.accessToken,
        requestData,
      );
      
    } catch (e) {
      debugPrint('Erro detalhado ao chamar Edge Function: $e');
      rethrow;
    }
  }

  Future<http.Response> _fazerRequisicao(
    String supabaseUrl, 
    String accessToken, 
    Map<String, dynamic> requestData
  ) async {
    final functionUrl = '$supabaseUrl/functions/v1/down_excel_estoques';
    
    final response = await http.post(
      Uri.parse(functionUrl),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'Accept': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      },
      body: jsonEncode(requestData),
    );
    
    return response;
  }

  void _ordenarDados(
    List<Map<String, dynamic>> dados, 
    String coluna, 
    bool ascendente
  ) {
    List<Map<String, dynamic>> dadosOrdenados = List.from(dados);
    
    dadosOrdenados.sort((a, b) {
      dynamic valorA;
      dynamic valorB;
      
      switch (coluna) {
        case 'data_mov':
          valorA = DateTime.parse(a['data_mov']);
          valorB = DateTime.parse(b['data_mov']);
          break;
        case 'descricao':
          valorA = (a['descricao'] ?? '').toString().toLowerCase();
          valorB = (b['descricao'] ?? '').toString().toLowerCase();
          break;
        case 'produto_nome':
          valorA = (a['produto_nome'] ?? '').toString().toLowerCase();
          valorB = (b['produto_nome'] ?? '').toString().toLowerCase();
          break;
        case 'cliente_destino':
          valorA = (a['cliente_destino'] ?? '').toString().toLowerCase();
          valorB = (b['cliente_destino'] ?? '').toString().toLowerCase();
          break;
        case 'entrada_amb':
        case 'entrada_vinte':
        case 'saida_amb':
        case 'saida_vinte':
          valorA = a[coluna] ?? 0;
          valorB = b[coluna] ?? 0;
          break;
        default:
          return 0;
      }
      
      if (valorA is DateTime && valorB is DateTime) {
        return ascendente 
            ? valorA.compareTo(valorB)
            : valorB.compareTo(valorA);
      } else if (valorA is num && valorB is num) {
        return ascendente 
            ? (valorA - valorB).toInt()
            : (valorB - valorA).toInt();
      } else if (valorA is String && valorB is String) {
        return ascendente 
            ? valorA.compareTo(valorB)
            : valorB.compareTo(valorA);
      }
      
      return 0;
    });
    
    setState(() {
      _vendas = dados;
      _vendasOrdenadas = dadosOrdenados;
      _colunaOrdenacao = coluna;
      _ordenacaoAscendente = ascendente;
    });
  }

  void _onSort(String coluna) {
    bool ascendente = true;
    
    if (_colunaOrdenacao == coluna) {
      ascendente = !_ordenacaoAscendente;
    } else {
      ascendente = coluna == 'data_mov' ? true : true;
    }
    
    _ordenarDados(_vendas, coluna, ascendente);
  }

  String _getSubtitleFiltros() {
    List<String> filtros = [];

    final diaIni = widget.dataInicial.day.toString().padLeft(2, '0');
    final mesIni = widget.dataInicial.month.toString().padLeft(2, '0');
    final diaFim = widget.dataFinal.day.toString().padLeft(2, '0');
    final mesFim = widget.dataFinal.month.toString().padLeft(2, '0');
    filtros.add('Período: $diaIni/$mesIni/${widget.dataInicial.year} a $diaFim/$mesFim/${widget.dataFinal.year}');

    if (widget.produtoFiltro != null && widget.produtoFiltro != 'todos') {
      filtros.add('Produto: ${_nomeProdutoSelecionado ?? widget.produtoFiltro}');
    } else if (widget.produtoFiltro == 'todos') {
      filtros.add('Produto: Todos os produtos');
    }

    filtros.add('Relatório: ${widget.tipoRelatorio == 'sintetico' ? 'Sintético' : 'Analítico'}');

    return filtros.join(' | ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0D47A1),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Relatório de Vendas – ${widget.nomeTerminal}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
              Text(
                _getSubtitleFiltros(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_carregando && !_erro && _vendasOrdenadas.isNotEmpty)
            _baixandoExcel
                ? const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.download),
                    onPressed: _baixarExcel,
                    tooltip: 'Baixar relatório Excel (XLSX)',
                  ),
          
          if (!_carregando && widget.produtoFiltro != null)
            IconButton(
              icon: const Icon(Icons.filter_alt),
              tooltip: 'Alterar filtros',
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          
          if (!_carregando && !_erro && _vendas.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.sort),
              tooltip: 'Ordenar por',
              onSelected: (value) {
                _onSort(value);
              },
              itemBuilder: (context) {
                return [
                  PopupMenuItem<String>(
                    value: 'data_mov',
                    child: Text(_ordenacaoAscendente && _colunaOrdenacao == 'data_mov' 
                      ? 'Data (mais antigo primeiro)' 
                      : 'Data (mais recente primeiro)'),
                  ),
                  if (widget.produtoFiltro == null || widget.produtoFiltro == 'todos')
                    PopupMenuItem<String>(
                      value: 'produto_nome',
                      child: Text(_ordenacaoAscendente && _colunaOrdenacao == 'produto_nome'
                        ? 'Produto (Z-A)'
                        : 'Produto (A-Z)'),
                    ),
                  PopupMenuItem<String>(
                    value: 'entrada_amb',
                    child: Text(_ordenacaoAscendente && _colunaOrdenacao == 'entrada_amb'
                      ? 'Entrada Ambiente (menor-maior)'
                      : 'Entrada Ambiente (maior-menor)'),
                  ),

                ];
              },
            ),
          
          if (!_carregando && !_erro)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _carregarDados,
              tooltip: 'Atualizar dados',
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _carregando
                  ? _buildCarregando()
                  : _erro
                      ? _buildErro()
                      : _vendas.isEmpty
                          ? _buildSemDados()
                          : Column(
                              children: [
                                if (widget.produtoFiltro != null)
                                  _buildIndicadorFiltros(),
                                const SizedBox(height: 16),
                                Expanded(child: _buildTabelaComEstoque()),
                              ],
                            ),
            ),
          ),
          _buildRodapeInstitucional(),
        ],
      ),
    );
  }

  Widget _buildIndicadorFiltros() {
    return const SizedBox.shrink();
  }

  Widget _buildCarregando() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF0D47A1)),
          SizedBox(height: 20),
          Text(
            'Carregando dados das movimentações...',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErro() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 60,
          ),
          const SizedBox(height: 20),
          const Text(
            'Erro ao carregar dados',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _mensagemErro,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _carregarDados,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1),
              foregroundColor: Colors.white,
            ),
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  Widget _buildSemDados() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            color: Colors.grey,
            size: 60,
          ),
          const SizedBox(height: 20),
          const Text(
            'Nenhum registro encontrado',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Não há movimentações para os filtros aplicados.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _carregarDados,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Atualizar'),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'Alterar filtros',
                style: TextStyle(color: Color(0xFF0D47A1)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatarNumero(num? valor) {
    if (valor == null) return '0';
    
    if (valor == 0) return '0';
    
    bool isNegativo = valor < 0;
    
    String valorString = valor.abs().toStringAsFixed(0);
    
    String resultado = '';
    int contador = 0;
    
    for (int i = valorString.length - 1; i >= 0; i--) {
      contador++;
      resultado = valorString[i] + resultado;
      
      if (contador % 3 == 0 && i > 0) {
        resultado = '.$resultado';
      }
    }
    
    if (isNegativo) {
      resultado = '-$resultado';
    }
    
    return resultado;
  }

  // Método para formatar data
  String _formatarData(String dataString) {
    try {
      final data = DateTime.parse(dataString);
      return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
    } catch (e) {
      return dataString;
    }
  }

  // Método principal da tabela com estoque
  Widget _buildTabelaComEstoque() {
    return Scrollbar(
      controller: _verticalScrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _verticalScrollController,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              _buildTabelaCabecalho(),
              _buildTabelaCorpo(),
              _buildContadorResultados(),
            ],
          ),
        ),
      ),
    );
  }

  // Cabeçalho da tabela
  Widget _buildTabelaCabecalho() {
    bool mostrarColunaProduto = widget.produtoFiltro == null || widget.produtoFiltro == 'todos';
    bool mostrarColunaClienteDestino = widget.tipoRelatorio != 'sintetico';

    return Scrollbar(
      controller: _horizontalHeaderController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _horizontalHeaderController,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: _larguraTabela,
          child: Container(
            height: _alturaCabecalho,
            color: const Color(0xFF0D47A1),
            child: Row(
              children: [
                _th('Data', _larguraData, onTap: () => _onSort('data_mov')),
                if (mostrarColunaProduto)
                  _th('Produto', _larguraProduto, onTap: () => _onSort('produto_nome')),
                _th('Descrição', _larguraDescricao, onTap: () => _onSort('descricao')),
                if (mostrarColunaClienteDestino)
                  _th('Cliente/Destino', _larguraClienteDestino, onTap: () => _onSort('cliente_destino')),
                _th('Entrada (Amb)', _larguraNumerica, onTap: () => _onSort('entrada_amb')),
                _th('Entrada (20ºC)', _larguraNumerica, onTap: () => _onSort('entrada_vinte')),
                _th('Saída (Amb)', _larguraNumerica, onTap: () => _onSort('saida_amb')),
                _th('Saída (20ºC)', _larguraNumerica, onTap: () => _onSort('saida_vinte')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Célula de cabeçalho
  Widget _th(String texto, double largura, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: largura,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.center,
        child: SelectableText(
          texto,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            overflow: TextOverflow.ellipsis,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
        ),
      ),
    );
  }

  // Corpo da tabela com scroll horizontal sincronizado
  Widget _buildTabelaCorpo() {
    bool mostrarColunaProduto = widget.produtoFiltro == null || widget.produtoFiltro == 'todos';
    bool mostrarColunaClienteDestino = widget.tipoRelatorio != 'sintetico';

    return Scrollbar(
      controller: _horizontalBodyController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _horizontalBodyController,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: _larguraTabela,
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _vendasOrdenadas.length + 1, // +1 para a linha de totais
            itemBuilder: (context, index) {
              // Última linha: Totais
              if (index == _vendasOrdenadas.length) {
                num totalEntradaAmb = 0;
                num totalEntradaVinte = 0;
                num totalSaidaAmb = 0;
                num totalSaidaVinte = 0;
                for (final mov in _vendasOrdenadas) {
                  totalEntradaAmb += (mov['entrada_amb'] ?? 0) as num;
                  totalEntradaVinte += (mov['entrada_vinte'] ?? 0) as num;
                  totalSaidaAmb += (mov['saida_amb'] ?? 0) as num;
                  totalSaidaVinte += (mov['saida_vinte'] ?? 0) as num;
                }
                return Container(
                  height: _alturaLinha,
                  color: Colors.orange.shade50,
                  child: Row(
                    children: [
                      _cell('', _larguraData),
                      if (mostrarColunaProduto)
                        _cell('', _larguraProduto),
                      _cell('TOTAL', _larguraDescricao, cor: Colors.orange.shade800, fontWeight: FontWeight.bold),
                      if (mostrarColunaClienteDestino)
                        _cell('', _larguraClienteDestino),
                      _cell(_formatarNumero(totalEntradaAmb), _larguraNumerica,
                            fundo: _getCorFundoEntrada(), cor: Colors.green.shade800, fontWeight: FontWeight.bold, isNumber: true),
                      _cell(_formatarNumero(totalEntradaVinte), _larguraNumerica,
                            fundo: _getCorFundoEntrada(), cor: Colors.green.shade800, fontWeight: FontWeight.bold, isNumber: true),
                      _cell(_formatarNumero(totalSaidaAmb), _larguraNumerica,
                            fundo: _getCorFundoSaida(), cor: Colors.red.shade800, fontWeight: FontWeight.bold, isNumber: true),
                      _cell(_formatarNumero(totalSaidaVinte), _larguraNumerica,
                            fundo: _getCorFundoSaida(), cor: Colors.red.shade800, fontWeight: FontWeight.bold, isNumber: true),
                    ],
                  ),
                );
              }

              // Linhas normais das vendas
              final e = _vendasOrdenadas[index];

              return Container(
                height: _alturaLinha,
                decoration: BoxDecoration(
                  color: index % 2 == 0
                      ? Colors.grey.shade50
                      : Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey.shade200,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    _cell(_formatarData(e['data_mov']), _larguraData),
                    if (mostrarColunaProduto)
                      _cell(e['produto_nome'] ?? '-', _larguraProduto),
                    _cell(e['descricao'] ?? '-', _larguraDescricao),
                    if (mostrarColunaClienteDestino)
                      _cell(e['cliente_destino'] ?? '-', _larguraClienteDestino),
                    _cell(_formatarNumero(e['entrada_amb']), _larguraNumerica,
                          fundo: _getCorFundoEntrada(), isNumber: true),
                    _cell(_formatarNumero(e['entrada_vinte']), _larguraNumerica,
                          fundo: _getCorFundoEntrada(), isNumber: true),
                    _cell(_formatarNumero(e['saida_amb']), _larguraNumerica,
                          fundo: _getCorFundoSaida(), isNumber: true),
                    _cell(_formatarNumero(e['saida_vinte']), _larguraNumerica,
                          fundo: _getCorFundoSaida(), isNumber: true),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // Célula genérica para o corpo da tabela
  Widget _cell(
    String texto,
    double largura, {
    Color? fundo,
    Color? cor,
    FontWeight? fontWeight,
    bool isNumber = false,
  }) {
    return Container(
      width: largura,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      color: fundo,
      child: SelectableText(
        texto.isNotEmpty ? texto : '-',
        style: TextStyle(
          fontSize: 12,
          color: cor ?? Colors.grey.shade700,
          fontWeight: fontWeight ?? (isNumber ? FontWeight.w600 : FontWeight.normal),
          overflow: TextOverflow.ellipsis,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
      ),
    );
  }

  Widget _buildRodapeInstitucional() {
    return Container(
      height: 50,
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'PowerTank 2026, All rights reserved.',
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
    );
  }

  // Rodapé com contador de resultados
  Widget _buildContadorResultados() {
    return Container(
      height: _alturaRodape,
      color: Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: Text(
        '${_vendasOrdenadas.length} ${widget.tipoRelatorio == 'sintetico' ? 'dias' : 'venda(s)'}',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade600,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}