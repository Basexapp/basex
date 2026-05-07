import 'dart:convert';
import 'dart:html' as html;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ContabilFisicoPage extends StatefulWidget {
  final String? filialId;
  final String? terminalId;
  final String nomeFilial;
  final String? empresaId;
  final DateTime dataInicial;
  final DateTime dataFinal;
  final String? produtoFiltro;
  final String tipoRelatorio;

  const ContabilFisicoPage({
    super.key,
    this.filialId,
    this.terminalId,
    required this.nomeFilial,
    this.empresaId,
    required this.dataInicial,
    required this.dataFinal,
    this.produtoFiltro,
    required this.tipoRelatorio,
  });

  @override
  State<ContabilFisicoPage> createState() => _ContabilFisicoPageState();
}

class _ContabilFisicoPageState extends State<ContabilFisicoPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _movimentacoes = [];
  List<Map<String, dynamic>> _movimentacoesOrdenadas = [];
  String? _empresaId;
  String? _filialIdUsar;
  bool _carregando = true;
  bool _erro = false;
  String _mensagemErro = '';
  String? _nomeProdutoSelecionado;

  // Contábil x Físico - saldo inicial e final
  Map<String, dynamic> _contabilFisicoInicial = {
    'ambiente': 0,
    'vinte_graus': 0,
    'vinte_graus_base': 0,
  };
  
  Map<String, dynamic> _contabilFisicoFinal = {
    'ambiente': 0,
    'vinte_graus': 0,
    'vinte_graus_base': 0,
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
    
    // Soma das larguras fixas (agora 7 colunas numéricas)
    double soma = _larguraData + 
                  _larguraDescricao + 
                  _larguraClienteDestino +
                  (_larguraNumerica * 7); // 7 colunas numéricas
    
    // Adiciona coluna de produto se necessário
    if (mostrarColunaProduto) {
      soma += _larguraProduto;
    }
    
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

    try {
      // Resolver filial e empresa a partir dos parâmetros recebidos.
      if (widget.filialId != null && widget.filialId!.isNotEmpty) {
        _filialIdUsar = widget.filialId;

        if (widget.empresaId != null && widget.empresaId!.isNotEmpty) {
          _empresaId = widget.empresaId;
        } else {
          final filialData = await _supabase
              .from('filiais')
              .select('empresa_id')
              .eq('id', _filialIdUsar!)
              .maybeSingle();
          _empresaId = filialData?['empresa_id']?.toString();
        }
      } else if (widget.terminalId != null) {
        final filialData = await _supabase
            .from('filiais')
            .select('id, empresa_id')
            .or('terminal_id_1.eq.${widget.terminalId!},terminal_id_2.eq.${widget.terminalId!}')
            .maybeSingle();

        if (filialData != null) {
          _filialIdUsar = filialData['id']?.toString();
          _empresaId = filialData['empresa_id']?.toString();
        } else {
          debugPrint('❌ Filial associada ao terminal não encontrada');
          throw Exception('Filial associada ao terminal não encontrada');
        }
      } else {
        debugPrint('❌ Não foi possível identificar a filial - nenhum parâmetro válido');
        throw Exception('Não foi possível identificar a filial');
      }

      if (_filialIdUsar == null || _filialIdUsar!.isEmpty) {
        debugPrint('❌ _filialIdUsar está nulo ou vazio');
        throw Exception('Não foi possível identificar a filial');
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

      // Carregar contábil x físico inicial (do final do período anterior)
      await _carregarContabilFisicoInicial();

      await _carregarDadosAnalitico();

      if (widget.tipoRelatorio == 'sintetico') {
        await _carregarDadosSintetico();
      }
      
      // Calcular contábil x físico final
      _calcularContabilFisicoFinal();
      
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

  Future<void> _carregarContabilFisicoInicial() async {
    try {
      final diaAnterior = widget.dataInicial.subtract(const Duration(days: 1));

      if (widget.produtoFiltro != null && widget.produtoFiltro != 'todos') {
        final movsProduto = await _supabase
            .from('movimentacoes')
            .select('''
              entrada_amb,
              entrada_vinte,
              saida_amb,
              saida_vinte,
              data_mov,
              data_descarga
            ''')
            .or('filial_id.eq.$_filialIdUsar,filial_destino_id.eq.$_filialIdUsar,filial_origem_id.eq.$_filialIdUsar')
            .eq('empresa_id', _empresaId!)
            .eq('produto_id', widget.produtoFiltro!);

        if (movsProduto.isNotEmpty) {
          num saldoAmb = 0;
          num saldoVinte = 0;
          num saldoVinteBase = 0;

          for (var mov in movsProduto) {
            bool isEntrada = (mov['entrada_amb'] ?? 0) > 0 || (mov['entrada_vinte'] ?? 0) > 0;
            String dataComparacao = isEntrada ? (mov['data_descarga'] ?? mov['data_mov']) : mov['data_mov'];
            
            if (DateTime.parse(dataComparacao).isAfter(diaAnterior)) continue;

            saldoAmb += (mov['entrada_amb'] ?? 0) as num;
            saldoAmb -= (mov['saida_amb'] ?? 0) as num;
            saldoVinte += (mov['entrada_vinte'] ?? 0) as num;
            saldoVinte -= (mov['saida_vinte'] ?? 0) as num;
            saldoVinteBase += (mov['entrada_vinte'] ?? 0) as num;
            saldoVinteBase -= (mov['saida_vinte'] ?? 0) as num;
          }

          _contabilFisicoInicial = {
            'ambiente': saldoAmb,
            'vinte_graus': saldoVinte,
            'vinte_graus_base': saldoVinteBase,
          };
          return;
        }
      }

      final movimentacoesAnteriores = await _supabase
          .from('movimentacoes')
          .select('''
            entrada_amb,
            entrada_vinte,
            saida_amb,
            saida_vinte,
            data_mov,
            data_descarga
          ''')
          .or('filial_id.eq.$_filialIdUsar,filial_destino_id.eq.$_filialIdUsar,filial_origem_id.eq.$_filialIdUsar')
          .eq('empresa_id', _empresaId!);

      num saldoAmb = 0;
      num saldoVinte = 0;
      num saldoVinteBase = 0;

      for (var mov in movimentacoesAnteriores) {
        bool isEntrada = (mov['entrada_amb'] ?? 0) > 0 || (mov['entrada_vinte'] ?? 0) > 0;
        String dataComparacao = isEntrada ? (mov['data_descarga'] ?? mov['data_mov']) : mov['data_mov'];
        
        if (DateTime.parse(dataComparacao).isAfter(diaAnterior)) continue;

        saldoAmb += (mov['entrada_amb'] ?? 0) as num;
        saldoAmb -= (mov['saida_amb'] ?? 0) as num;
        saldoVinte += (mov['entrada_vinte'] ?? 0) as num;
        saldoVinte -= (mov['saida_vinte'] ?? 0) as num;
        saldoVinteBase += (mov['entrada_vinte'] ?? 0) as num;
        saldoVinteBase -= (mov['saida_vinte'] ?? 0) as num;
      }

      _contabilFisicoInicial = {
        'ambiente': saldoAmb,
        'vinte_graus': saldoVinte,
        'vinte_graus_base': saldoVinteBase,
      };

    } catch (e) {
      debugPrint('Erro ao carregar contábil x físico inicial: $e');
      _contabilFisicoInicial = {
        'ambiente': 0,
        'vinte_graus': 0,
        'vinte_graus_base': 0,
      };
    }
  }

  void _calcularContabilFisicoFinal() {
    if (_movimentacoesOrdenadas.isEmpty) {
      _contabilFisicoFinal = Map.from(_contabilFisicoInicial);
      return;
    }

    final ultimaMov = _movimentacoesOrdenadas.last;
    _contabilFisicoFinal = {
      'ambiente': ultimaMov['saldo_amb'] ?? 0,
      'vinte_graus': ultimaMov['saldo_vinte'] ?? 0,
      'vinte_graus_base': ultimaMov['saldo_vinte_base'] ?? 0,
    };
  }

  // FUNÇÃO: Normalização de movimentação
  Map<String, dynamic> _normalizarMovimentacao(
    Map<String, dynamic> mov,
    String filialId,
  ) {
    num entradaAmb = 0;
    num entradaVinte = 0;
    num saidaAmb = 0;
    num saidaVinte = 0;

    final tipoOp = mov['tipo_op']?.toString() ?? '';
    final filialDestinoId = mov['filial_destino_id']?.toString();
    final filialOrigemId = mov['filial_origem_id']?.toString();
    final tipoMovDest = mov['tipo_mov_dest']?.toString();
    final tipoMovOrig = mov['tipo_mov_orig']?.toString();

    switch (tipoOp) {
      case 'transf':
        if (filialDestinoId == filialId && tipoMovDest == 'entrada') {
          entradaAmb += (mov['entrada_amb'] ?? 0) as num;
          entradaVinte += (mov['entrada_vinte'] ?? 0) as num;
        } else if (filialOrigemId == filialId && tipoMovOrig == 'saida') {
          saidaAmb += (mov['saida_amb'] ?? 0) as num;
          saidaVinte += (mov['saida_vinte'] ?? 0) as num;
        }
        break;

      case 'venda':
        saidaAmb += (mov['saida_amb'] ?? 0) as num;
        saidaVinte += (mov['saida_vinte'] ?? 0) as num;
        break;

      default:
        entradaAmb += (mov['entrada_amb'] ?? 0) as num;
        entradaVinte += (mov['entrada_vinte'] ?? 0) as num;
        saidaAmb += (mov['saida_amb'] ?? 0) as num;
        saidaVinte += (mov['saida_vinte'] ?? 0) as num;
        break;
    }

    return {
      'entrada_amb': entradaAmb,
      'entrada_vinte': entradaVinte,
      'entrada_vinte_base': 0, // Placeholder para entrada 20º base
      'saida_amb': saidaAmb,
      'saida_vinte': saidaVinte,
      'saida_vinte_base': 0, // Placeholder para saída 20º base
    };
  }

  Future<void> _carregarDadosAnalitico() async {
    try {
      var query = _supabase
          .from('movimentacoes')
          .select('''
            id,
            data_mov,
            data_descarga,
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
          .or('filial_id.eq.$_filialIdUsar,filial_destino_id.eq.$_filialIdUsar,filial_origem_id.eq.$_filialIdUsar')
          .eq('empresa_id', _empresaId!);

      if (widget.produtoFiltro != null && widget.produtoFiltro != 'todos') {
        query = query.eq('produto_id', widget.produtoFiltro!);
      }

      final dados = await query.order('data_mov', ascending: true);

      final Set<String> filialDestinoIds = {};
      for (var mov in dados) {
        if ((mov['tipo_op']?.toString() ?? '') == 'transf' && mov['filial_destino_id'] != null) {
          filialDestinoIds.add(mov['filial_destino_id'].toString());
        }
      }

      final Map<String, String> filialNomes = {};
      if (filialDestinoIds.isNotEmpty) {
        try {
            final orExpr = filialDestinoIds.map((id) => 'id.eq.$id').join(',');
            final filiaisRes = await _supabase
              .from('filiais')
              .select('id, nome_dois')
              .or(orExpr);

          for (var f in filiaisRes) {
            filialNomes[f['id'].toString()] = f['nome_dois']?.toString() ?? '';
          }
        } catch (e) {
          debugPrint('Erro ao buscar nomes das filiais destino: $e');
        }
      }

      final List<Map<String, dynamic>> analitico = [];

      num saldoAmb = _contabilFisicoInicial['ambiente'] as num;
      num saldoVinte = _contabilFisicoInicial['vinte_graus'] as num;
      num saldoVinteBase = _contabilFisicoInicial['vinte_graus_base'] as num;

      for (var mov in dados) {
        final normalizado = _normalizarMovimentacao(
          mov,
          _filialIdUsar!,
        );

        final produto = mov['produtos'] as Map<String, dynamic>?;
        final produtoNome = produto?['nome']?.toString() ?? '';

        // Se for entrada, usa data_descarga se disponível, senão data_mov
        String dataExibicao = mov['data_mov'];
        if ((normalizado['entrada_amb'] as num) > 0 || (normalizado['entrada_vinte'] as num) > 0) {
          dataExibicao = mov['data_descarga'] ?? mov['data_mov'];
        }

        // Filtro local pelo período, já que agora estamos baseando na data de exibição
        final dataExibicaoDT = DateTime.parse(dataExibicao);
        if (dataExibicaoDT.isBefore(widget.dataInicial) || dataExibicaoDT.isAfter(widget.dataFinal)) {
          continue;
        }

        saldoAmb += (normalizado['entrada_amb'] as num) - (normalizado['saida_amb'] as num);
        saldoVinte += (normalizado['entrada_vinte'] as num) - (normalizado['saida_vinte'] as num);
        saldoVinteBase += (normalizado['entrada_vinte_base'] as num) - (normalizado['saida_vinte_base'] as num);

        analitico.add({
          ...normalizado,
          'id': mov['id'],
          'data_mov': dataExibicao,
          'data_mov_original': mov['data_mov'],
          'data_descarga': mov['data_descarga'],
          'descricao': mov['descricao'] ?? '',
          'cliente_destino': (() {
            final tipoOpMov = mov['tipo_op']?.toString() ?? '';
            if (tipoOpMov == 'venda') {
              return mov['cliente']?.toString() ?? '';
            } else if (tipoOpMov == 'transf') {
              final fd = mov['filial_destino_id']?.toString();
              return filialNomes[fd] ?? fd ?? '';
            }
            return mov['cliente']?.toString() ?? mov['filial_destino_id']?.toString() ?? '';
          })(),
          'produto_nome': produtoNome,
          'produto_id': mov['produto_id'],
          'saldo_amb': saldoAmb,
          'saldo_vinte': saldoVinte,
          'saldo_vinte_base': saldoVinteBase,
        });
      }

      _ordenarDados(analitico, 'data_mov', true);

    } catch (e) {
      debugPrint('❌ Erro ao carregar dados analíticos: $e');
      rethrow;
    }
  }

  Future<void> _carregarDadosSintetico() async {
    try {
      final Map<String, List<Map<String, dynamic>>> porDia = {};
      
      for (var mov in _movimentacoes) {
        final dataStr = mov['data_mov'] as String;
        if (!porDia.containsKey(dataStr)) {
          porDia[dataStr] = [];
        }
        porDia[dataStr]!.add(mov);
      }

      final List<Map<String, dynamic>> sintetico = [];
      final datasOrdenadas = porDia.keys.toList()..sort();

      num saldoAmbAcumulado = _contabilFisicoInicial['ambiente'] as num;
      num saldoVinteAcumulado = _contabilFisicoInicial['vinte_graus'] as num;
      num saldoVinteBaseAcumulado = _contabilFisicoInicial['vinte_graus_base'] as num;

      for (var dataStr in datasOrdenadas) {
        final movsDoDia = porDia[dataStr]!;
        
        num totalEntradaAmb = 0;
        num totalEntradaVinte = 0;
        num totalEntradaVinteBase = 0;
        num totalSaidaAmb = 0;
        num totalSaidaVinte = 0;
        num totalSaidaVinteBase = 0;

        for (var mov in movsDoDia) {
          totalEntradaAmb += (mov['entrada_amb'] ?? 0) as num;
          totalEntradaVinte += (mov['entrada_vinte'] ?? 0) as num;
          totalEntradaVinteBase += (mov['entrada_vinte_base'] ?? 0) as num;
          totalSaidaAmb += (mov['saida_amb'] ?? 0) as num;
          totalSaidaVinte += (mov['saida_vinte'] ?? 0) as num;
          totalSaidaVinteBase += (mov['saida_vinte_base'] ?? 0) as num;
        }

        saldoAmbAcumulado += totalEntradaAmb - totalSaidaAmb;
        saldoVinteAcumulado += totalEntradaVinte - totalSaidaVinte;
        saldoVinteBaseAcumulado += totalEntradaVinteBase - totalSaidaVinteBase;

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
          'entrada_vinte_base': totalEntradaVinteBase,
          'saida_amb': totalSaidaAmb,
          'saida_vinte': totalSaidaVinte,
          'saida_vinte_base': totalSaidaVinteBase,
          'produto_nome': produtoNome,
          'produto_id': widget.produtoFiltro,
          'saldo_amb': saldoAmbAcumulado,
          'saldo_vinte': saldoVinteAcumulado,
          'saldo_vinte_base': saldoVinteBaseAcumulado,
        });
      }

      setState(() {
        _movimentacoes = sintetico;
        _movimentacoesOrdenadas = List.from(sintetico);
      });

    } catch (e) {
      debugPrint('Erro ao carregar dados sintéticos: $e');
      rethrow;
    }
  }

  Future<void> _baixarExcel() async {
    if (_movimentacoesOrdenadas.isEmpty) {
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
        'filialId': _filialIdUsar,
        'terminalId': widget.terminalId,
        'nomeFilial': widget.nomeFilial,
        'empresaId': widget.empresaId,
        'dataInicial': widget.dataInicial.toIso8601String(),
        'dataFinal': widget.dataFinal.toIso8601String(),
        'produtoFiltro': widget.produtoFiltro,
        'tipoRelatorio': widget.tipoRelatorio,
        'estoqueInicial': _contabilFisicoInicial,
        'estoqueFinal': _contabilFisicoFinal,
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
      
      final nomeFormatado = widget.nomeFilial
          .replaceAll(' ', '_')
          .replaceAll(RegExp(r'[^\w_]'), '');
      
      final diaI = widget.dataInicial.day.toString().padLeft(2, '0');
      final mesI = widget.dataInicial.month.toString().padLeft(2, '0');
      final anoI = widget.dataInicial.year.toString();
      final diaF = widget.dataFinal.day.toString().padLeft(2, '0');
      final mesF = widget.dataFinal.month.toString().padLeft(2, '0');
      final anoF = widget.dataFinal.year.toString();
      final fileName = 'contabil_fisico_${nomeFormatado}_${diaI}_${mesI}_${anoI}_a_${diaF}_${mesF}_${anoF}.xlsx';
      
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
        case 'entrada_vinte_base':
        case 'saida_amb':
        case 'saida_vinte':
        case 'saida_vinte_base':
        case 'saldo_amb':
        case 'saldo_vinte':
        case 'saldo_vinte_base':
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
      _movimentacoes = dados;
      _movimentacoesOrdenadas = dadosOrdenados;
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
    
    _ordenarDados(_movimentacoes, coluna, ascendente);
  }

  String _getSubtitleFiltros() {
    List<String> filtros = [];

    final diaI = widget.dataInicial.day.toString().padLeft(2, '0');
    final mesI = widget.dataInicial.month.toString().padLeft(2, '0');
    final anoI = widget.dataInicial.year;
    final diaF = widget.dataFinal.day.toString().padLeft(2, '0');
    final mesF = widget.dataFinal.month.toString().padLeft(2, '0');
    final anoF = widget.dataFinal.year;
    filtros.add('Período: $diaI/$mesI/$anoI a $diaF/$mesF/$anoF');

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
              'Contábil x Físico – ${widget.nomeFilial}',
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
          if (!_carregando && !_erro && _movimentacoesOrdenadas.isNotEmpty)
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
                : Padding(
                    padding: const EdgeInsets.only(right: 100),
                    child: IconButton(
                        icon: const FaIcon(
                          FontAwesomeIcons.fileExcel,
                          size: 28,
                          color: Colors.green,
                        ),
                        onPressed: _baixarExcel,
                        tooltip: 'Baixar relatório Excel (XLSX)',
                      ),
                  ),
        ],
      ),
      body: SelectionArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _carregando
              ? _buildCarregando()
              : _erro
                  ? _buildErro()
                  : _movimentacoes.isEmpty
                      ? _buildSemDados()
                      : Column(
                          children: [
                            if (widget.produtoFiltro != null)
                              _buildIndicadorFiltros(),
                            const SizedBox(height: 16),
                            Expanded(child: _buildTabelaComContabilFisico()),
                          ],
                        ),
        ),
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
          Text(
            widget.produtoFiltro != null
                ? 'Não há movimentações para os filtros aplicados.'
                : 'Não há movimentações para esta filial.',
            style: const TextStyle(color: Colors.grey),
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
          if (widget.produtoFiltro != null)
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

  String _formatarData(String dataString) {
    try {
      final data = DateTime.parse(dataString);
      return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
    } catch (e) {
      return dataString;
    }
  }

  Widget _buildTabelaComContabilFisico() {
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

  Widget _buildTabelaCabecalho() {
    bool mostrarColunaProduto = widget.produtoFiltro == null || widget.produtoFiltro == 'todos';
    
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
                _th('Cliente/Destino', _larguraClienteDestino, onTap: () => _onSort('cliente_destino')),
                _th('Entrada (Amb)', _larguraNumerica, onTap: () => _onSort('entrada_amb')),
                _th('Entrada (20º NF)', _larguraNumerica, onTap: () => _onSort('entrada_vinte')),
                _th('Entrada (20º Base)', _larguraNumerica, onTap: () => _onSort('entrada_vinte_base')),
                _th('Saída (Amb)', _larguraNumerica, onTap: () => _onSort('saida_amb')),
                _th('Saída (20º NF)', _larguraNumerica, onTap: () => _onSort('saida_vinte')),
                _th('Saldo (Amb)', _larguraNumerica, onTap: () => _onSort('saldo_amb')),
                _th('Saldo (20º)', _larguraNumerica, onTap: () => _onSort('saldo_vinte')),
              ],
            ),
          ),
        ),
      ),
    );
  }

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

  Widget _buildTabelaCorpo() {
    bool mostrarColunaProduto = widget.produtoFiltro == null || widget.produtoFiltro == 'todos';
    
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
            itemCount: _movimentacoesOrdenadas.length + 2,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Container(
                  height: _alturaLinha,
                  color: Colors.blue.shade50,
                  child: Row(
                    children: [
                      _cell('', _larguraData),
                      if (mostrarColunaProduto)
                        _cell('', _larguraProduto),
                      _cell('Saldo Inicial', _larguraDescricao, cor: Colors.blue, fontWeight: FontWeight.bold),
                      _cell('', _larguraClienteDestino),
                      _cell('0', _larguraNumerica, isNumber: true),
                      _cell('0', _larguraNumerica, isNumber: true),
                      _cell('0', _larguraNumerica, isNumber: true),
                      _cell('0', _larguraNumerica, isNumber: true),
                      _cell('0', _larguraNumerica, isNumber: true),
                      _cell(
                        _formatarNumero(_contabilFisicoInicial['ambiente'] as num?),
                        _larguraNumerica,
                        cor: Colors.blue,
                        fontWeight: FontWeight.bold,
                        isNumber: true,
                      ),
                      _cell(
                        _formatarNumero(_contabilFisicoInicial['vinte_graus'] as num?),
                        _larguraNumerica,
                        cor: Colors.blue,
                        fontWeight: FontWeight.bold,
                        isNumber: true,
                      ),
                    ],
                  ),
                );
              }
              
              if (index == _movimentacoesOrdenadas.length + 1) {
                return Container(
                  height: _alturaLinha,
                  color: Colors.grey.shade100,
                  child: Row(
                    children: [
                      _cell('', _larguraData),
                      if (mostrarColunaProduto)
                        _cell('', _larguraProduto),
                      _cell('Saldo Final', _larguraDescricao, cor: Colors.grey.shade700, fontWeight: FontWeight.bold),
                      _cell('', _larguraClienteDestino),
                      _cell('0', _larguraNumerica, isNumber: true),
                      _cell('0', _larguraNumerica, isNumber: true),
                      _cell('0', _larguraNumerica, isNumber: true),
                      _cell('0', _larguraNumerica, isNumber: true),
                      _cell('0', _larguraNumerica, isNumber: true),
                      _cell(
                        _formatarNumero(_contabilFisicoFinal['ambiente'] as num?),
                        _larguraNumerica,
                        cor: ((_contabilFisicoFinal['ambiente'] as num?) ?? 0) < 0 ? Colors.red : Colors.black,
                        fontWeight: FontWeight.bold,
                        isNumber: true,
                      ),
                      _cell(
                        _formatarNumero(_contabilFisicoFinal['vinte_graus'] as num?),
                        _larguraNumerica,
                        cor: ((_contabilFisicoFinal['vinte_graus'] as num?) ?? 0) < 0 ? Colors.red : Colors.black,
                        fontWeight: FontWeight.bold,
                        isNumber: true,
                      ),
                    ],
                  ),
                );
              }
              
              final movIndex = index - 1;
              final e = _movimentacoesOrdenadas[movIndex];
              final saldoAmb = e['saldo_amb'] ?? 0;
              final saldoVinte = e['saldo_vinte'] ?? 0;

              return Container(
                height: _alturaLinha,
                decoration: BoxDecoration(
                  color: movIndex % 2 == 0
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
                    _cell(e['cliente_destino'] ?? '-', _larguraClienteDestino),
                    _cell(_formatarNumero(e['entrada_amb']), _larguraNumerica, 
                          fundo: _getCorFundoEntrada(), isNumber: true),
                    _cell(_formatarNumero(e['entrada_vinte']), _larguraNumerica, 
                          fundo: _getCorFundoEntrada(), isNumber: true),
                    _cell(_formatarNumero(e['entrada_vinte_base'] ?? 0), _larguraNumerica, 
                          fundo: _getCorFundoEntrada(), isNumber: true),
                    _cell(_formatarNumero(e['saida_amb']), _larguraNumerica, 
                          fundo: _getCorFundoSaida(), isNumber: true),
                    _cell(_formatarNumero(e['saida_vinte']), _larguraNumerica, 
                          fundo: _getCorFundoSaida(), isNumber: true),
                    _cell(
                      _formatarNumero(saldoAmb),
                      _larguraNumerica,
                      cor: saldoAmb < 0 ? Colors.red : Colors.black,
                      isNumber: true,
                    ),
                    _cell(
                      _formatarNumero(saldoVinte),
                      _larguraNumerica,
                      cor: saldoVinte < 0 ? Colors.red : Colors.black,
                      isNumber: true,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

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

  Widget _buildContadorResultados() {
    return Container(
      height: _alturaRodape,
      color: Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: Text(
        '${_movimentacoesOrdenadas.length} ${widget.tipoRelatorio == 'sintetico' ? 'dias' : 'movimentação(ões)'}',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade600,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}