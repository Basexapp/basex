import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_page.dart';

class EstoqueProdutoPage extends StatefulWidget {
  final String? filialId;
  final String? terminalId;
  final String nomeFilial;
  final String? empresaId;
  final DateTime dataInicial;
  final DateTime dataFinal;
  final String produtoId;
  final String produtoNome;
  final String tipoRelatorio;

  const EstoqueProdutoPage({
    super.key,
    this.filialId,
    this.terminalId,
    this.empresaId,
    required this.nomeFilial,
    required this.dataInicial,
    required this.dataFinal,
    required this.produtoId,
    required this.produtoNome,
    required this.tipoRelatorio,
  });

  @override
  State<EstoqueProdutoPage> createState() => _EstoqueProdutoPageState();
}

class _EstoqueProdutoPageState extends State<EstoqueProdutoPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _carregando = true;
  bool _erro = false;
  String _mensagemErro = '';

  String? _terminalId;
  String? _empresaId;
  bool _carregandoTerminal = true;

  List<Map<String, dynamic>> _movs = [];
  List<Map<String, dynamic>> _movsOrdenadas = [];

  Map<String, num?> _estoqueInicial = {'amb': 0, 'vinte': 0};
  Map<String, num?> _estoqueFinal = {'amb': null, 'vinte': null};

  num _totalEntradas = 0;
  num _totalSaidas = 0;
  num _totalSobraPerda = 0;
  String? _produtoNome;

  final ScrollController _vertical = ScrollController();
  final ScrollController _hHeader = ScrollController();
  final ScrollController _hBody = ScrollController();

  static const double _hCab = 40;
  static const double _hRow = 40;
  static const double _hFoot = 32;

  static const double _wData = 120;
  static const double _wDesc = 240;
  static const double _wNum = 130;

  double get _wTable => _wData + _wDesc + (_wNum * 7);

  String _coluna = 'data_mov';
  bool _asc = true;

  @override
  void initState() {
    super.initState();
    _syncScroll();
    _produtoNome = widget.produtoNome;
    _empresaId = widget.empresaId;
    _carregarTerminalDoUsuario();
  }

  Future<void> _carregarTerminalDoUsuario() async {
    try {
      final usuario = UsuarioAtual.instance;
      if (usuario == null) throw Exception('Usuário não logado');

      if (usuario.nivel < 3) {
        _terminalId = usuario.terminalId;
      } else {
        _terminalId = widget.terminalId;
      }

      // Se empresaId não veio do widget, tenta pegar do usuário
      if (_empresaId == null || _empresaId!.isEmpty) {
        _empresaId = usuario.empresaId;
      }

      await _carregar();
    } catch (e) {
      setState(() {
        _erro = true;
        _mensagemErro = 'Erro ao carregar terminal: $e';
        _carregandoTerminal = false;
        _carregando = false;
      });
    }
  }

  void _syncScroll() {
    _hHeader.addListener(() {
      if (_hBody.hasClients && _hBody.offset != _hHeader.offset) {
        _hBody.jumpTo(_hHeader.offset);
      }
    });
    _hBody.addListener(() {
      if (_hHeader.hasClients && _hHeader.offset != _hBody.offset) {
        _hHeader.jumpTo(_hBody.offset);
      }
    });
  }

  @override
  void dispose() {
    _vertical.dispose();
    _hHeader.dispose();
    _hBody.dispose();
    super.dispose();
  }

  Future<void> _carregarEstoqueInicialDoBanco() async {
    try {
      final dataStr = widget.dataInicial.toIso8601String().split('T')[0];
      final terminalId = _terminalId;
      
      if (terminalId == null || terminalId.isEmpty) {
        throw Exception('Terminal não identificado');
      }

      final response = await _supabase.rpc(
        'calcular_estoque_inicial_produto',
        params: {
          'p_terminal_id': terminalId,
          'p_produto_id': widget.produtoId,
          'p_data': dataStr,
        },
      );

      num saldo = 0;

      if (response is Map) {
        saldo = (response['estoque_inicial'] ?? 0) as num;
      } else {
        saldo = (response ?? 0) as num;
      }

      setState(() {
        _estoqueInicial = {'amb': saldo, 'vinte': saldo};
      });
    } catch (e) {
      debugPrint('❌ Erro ao buscar estoque inicial via função: $e');
      setState(() {
        _estoqueInicial = {'amb': 0, 'vinte': 0};
      });
    }
  }

  Future<void> _carregar() async {
    final terminalId = _terminalId;
    if (terminalId == null || terminalId.isEmpty) {
      setState(() {
        _erro = true;
        _mensagemErro = 'Terminal não identificado';
        _carregando = false;
        _carregandoTerminal = false;
      });
      return;
    }

    setState(() {
      _carregando = true;
      _erro = false;
      _carregandoTerminal = false;
    });

    try {
      await _carregarEstoqueInicialDoBanco();

      final String dataInicio;
      final String dataFim;

      final inicio = widget.dataInicial;
      final fim = widget.dataFinal;
      dataInicio =
          '${inicio.year}-${inicio.month.toString().padLeft(2, '0')}-${inicio.day.toString().padLeft(2, '0')} 00:00:00';
      dataFim =
          '${fim.year}-${fim.month.toString().padLeft(2, '0')}-${fim.day.toString().padLeft(2, '0')} 23:59:59';

      // Buscar movimentações do produto no terminal e empresa
      var query = _supabase
          .from('movimentacoes_tanque')
          .select('''
            id,
            movimentacao_id,
            data_mov,
            cliente,
            descricao,
            entrada_amb,
            entrada_vinte,
            saida_amb,
            saida_vinte,
            empresa_id,
            terminal_id,
            produto_id
          ''')
          .eq('produto_id', widget.produtoId)
          .eq('terminal_id', terminalId)
          .gte('data_mov', dataInicio)
          .lte('data_mov', dataFim);

      // Adicionar filtro por empresa_id se disponível
      if (_empresaId != null && _empresaId!.isNotEmpty) {
        query = query.eq('empresa_id', _empresaId!);
      }

      final dadosMov = await query;

      List<Map<String, dynamic>> registrosBrutos = [];

      // Adicionar movimentações normais
      for (var m in (dadosMov as List)) {
        registrosBrutos.add(Map<String, dynamic>.from(m));
      }

      // Aplicar agrupamento se for Sintético
      if (widget.tipoRelatorio == 'sintetico') {
        final Map<String, Map<String, dynamic>> agrupados = {};

        for (var reg in registrosBrutos) {
          final dtStr = reg['data_mov']?.toString() ?? '';
          if (dtStr.isEmpty) continue;
          
          final dataLimpa = dtStr.split(' ')[0];
          final dataApenas = dataLimpa.contains('T') 
              ? dataLimpa.split('T')[0] 
              : dataLimpa;

          if (!agrupados.containsKey(dataApenas)) {
            agrupados[dataApenas] = {
              'id': 'agrupado_$dataApenas',
              'movimentacao_id': null,
              'data_mov': '${dataApenas}T00:00:00',
              'cliente': 'MOVIMENTAÇÕES DO DIA',
              'descricao': '',
              'entrada_amb': 0.0,
              'entrada_vinte': 0.0,
              'saida_amb': 0.0,
              'saida_vinte': 0.0,
            };
          }

          final a = agrupados[dataApenas]!;
          a['entrada_amb'] =
              (a['entrada_amb'] as num) + (reg['entrada_amb'] ?? 0);
          a['entrada_vinte'] =
              (a['entrada_vinte'] as num) + (reg['entrada_vinte'] ?? 0);
          a['saida_amb'] = (a['saida_amb'] as num) + (reg['saida_amb'] ?? 0);
          a['saida_vinte'] =
              (a['saida_vinte'] as num) + (reg['saida_vinte'] ?? 0);
        }

        registrosBrutos = agrupados.values.toList();
      }

      final List<Map<String, dynamic>> listaOrdenadaParaUI = registrosBrutos;

      listaOrdenadaParaUI.sort((a, b) {
        final da = DateTime.parse(a['data_mov']);
        final db = DateTime.parse(b['data_mov']);

        final dataA = DateTime(da.year, da.month, da.day);
        final dataB = DateTime(db.year, db.month, db.day);

        final cmpData = dataA.compareTo(dataB);
        if (cmpData != 0) return cmpData;

        bool temSobraOuPerda(Map<String, dynamic> m) {
          final cliente = (m['cliente']?.toString() ?? '').toUpperCase();
          final descricao = (m['descricao']?.toString() ?? '').toUpperCase();
          return cliente.contains('SOBRA') ||
              descricao.contains('SOBRA') ||
              cliente.contains('PERDA') ||
              descricao.contains('PERDA');
        }

        final aLast = temSobraOuPerda(a) ? 1 : 0;
        final bLast = temSobraOuPerda(b) ? 1 : 0;

        if (aLast != bLast) {
          return aLast.compareTo(bLast);
        }

        return da.compareTo(db);
      });

      num saldoAmb = _estoqueInicial['amb'] ?? 0;
      num saldoVinte = _estoqueInicial['vinte'] ?? 0;

      num totalEntradas = 0;
      num totalSaidas = 0;
      num totalSobraPerda = 0;

      final List<Map<String, dynamic>> listaComSaldo = [];

      for (final m in listaOrdenadaParaUI) {
        final num entradaAmb = (m['entrada_amb'] ?? 0) as num;
        final num entradaVinte = (m['entrada_vinte'] ?? 0) as num;
        final num saidaAmb = (m['saida_amb'] ?? 0) as num;
        final num saidaVinte = (m['saida_vinte'] ?? 0) as num;

        final String cliente = (m['cliente']?.toString().trim() ?? '');
        final String desc = (m['descricao']?.toString().trim() ?? '');
        final String descricao = cliente.isNotEmpty ? cliente : desc;

        final num? sobraPerda = (saidaAmb != 0 && saidaVinte != 0) ? saidaAmb - saidaVinte : null;

        saldoAmb += entradaAmb - saidaAmb;
        saldoVinte += entradaVinte - saidaVinte;

        totalEntradas += entradaVinte;
        totalSaidas += saidaVinte;
        totalSobraPerda += sobraPerda ?? 0;

        listaComSaldo.add({
          'id': m['id'],
          'movimentacao_id': m['movimentacao_id'],
          'data_mov': m['data_mov'],
          'descricao': descricao,
          'entrada_amb': entradaAmb,
          'entrada_vinte': entradaVinte,
          'saida_amb': saidaAmb,
          'saida_vinte': saidaVinte,
          'sobra_perda': sobraPerda,
          'saldo_amb': saldoAmb,
          'saldo_vinte': saldoVinte,
        });
      }

      _movs = List<Map<String, dynamic>>.from(listaComSaldo);
      _movsOrdenadas = List<Map<String, dynamic>>.from(listaComSaldo);
      _totalEntradas = totalEntradas;
      _totalSaidas = totalSaidas;
      _totalSobraPerda = totalSobraPerda;

      _estoqueFinal = {
        'amb': _movs.isEmpty ? null : _movs.last['saldo_amb'],
        'vinte': _movs.isEmpty ? null : _movs.last['saldo_vinte'],
      };

      setState(() => _carregando = false);
    } catch (e) {
      setState(() {
        _carregando = false;
        _erro = true;
        _mensagemErro = e.toString();
      });
    }
  }

  void _ordenar(String col, bool asc) {
    final ord = List<Map<String, dynamic>>.from(_movs);
    ord.sort((a, b) {
      dynamic va, vb;
      switch (col) {
        case 'data_mov':
          va = DateTime.parse(a['data_mov']);
          vb = DateTime.parse(b['data_mov']);
          break;
        case 'descricao':
          va = (a['descricao'] ?? '').toString().toLowerCase();
          vb = (b['descricao'] ?? '').toString().toLowerCase();
          break;
        case 'entrada_amb':
        case 'entrada_vinte':
        case 'saida_amb':
        case 'saida_vinte':
        case 'saldo_amb':
        case 'saldo_vinte':
          va = a[col] ?? 0;
          vb = b[col] ?? 0;
          break;
        default:
          return 0;
      }
      if (va is DateTime && vb is DateTime) {
        return asc ? va.compareTo(vb) : vb.compareTo(va);
      }
      if (va is num && vb is num) {
        return asc ? va.compareTo(vb) : vb.compareTo(va);
      }
      if (va is String && vb is String) {
        return asc ? va.compareTo(vb) : vb.compareTo(va);
      }
      return 0;
    });

    setState(() {
      _movsOrdenadas = ord;
      _coluna = col;
      _asc = asc;
    });
  }

  void _onSort(String col) {
    final asc = _coluna == col ? !_asc : true;
    _ordenar(col, asc);
  }

  Color _bgEntrada() => Colors.green.shade50.withOpacity(0.3);
  Color _bgSaida() => Colors.red.shade50.withOpacity(0.3);

  String _fmtNum(num? v) {
    if (v == null) return '-';
    final s = v.abs().toStringAsFixed(0);
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final r = s.length - i;
      b.write(s[i]);
      if (r > 1 && r % 3 == 1) b.write('.');
    }
    return v < 0 ? '-${b.toString()}' : b.toString();
  }

  String _fmtData(String s) {
    final d = DateTime.parse(s);
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
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
              "Movimentação do Produto – ${_produtoNome ?? widget.produtoNome}",
            ),
            Text(
              '${widget.nomeFilial} | ${_fmtData(widget.dataInicial.toIso8601String())} a ${_fmtData(widget.dataFinal.toIso8601String())}',
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
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: () => _onSort('data_mov'),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _carregar),
        ],
      ),
      body: SelectionArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _carregandoTerminal || _carregando
              ? const Center(child: CircularProgressIndicator())
              : _erro
              ? Center(child: Text(_mensagemErro))
              : _buildConteudo(),
        ),
      ),
    );
  }

  Widget _buildConteudo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: _buildTabela()),
        _buildBlocoResumo(),
      ],
    );
  }

  Widget _buildBlocoResumo() {
    return Container(
      width: _wTable,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(10),
          bottomRight: Radius.circular(10),
        ),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 16,
        alignment: WrapAlignment.spaceAround,
        children: [
          _buildCampoResumo(
            'Saldo Inicial (20ºC):',
            _estoqueInicial['vinte'] ?? 0,
            cor: Colors.blue,
          ),
          _buildCampoResumo(
            'Total Entradas (20ºC):',
            _totalEntradas,
          ),
          _buildCampoResumo(
            'Total Saídas (20ºC):',
            _totalSaidas,
            cor: Colors.red,
          ),
          _buildCampoResumo(
            'Total Dif amb/20°C:',
            _totalSobraPerda,
            cor: _totalSobraPerda >= 0 ? const Color(0xFF0D47A1) : Colors.red,
          ),
          _buildCampoResumo(
            'Saldo Final (20ºC):',
            _estoqueFinal['vinte'] ?? 0,
            cor: const Color(0xFF0D47A1),
            negrito: true,
          ),
        ],
      ),
    );
  }

  Widget _buildCampoResumo(
    String label,
    num valor, {
    Color? cor,
    bool negrito = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _fmtNum(valor),
          style: TextStyle(
            fontSize: negrito ? 18 : 16,
            fontWeight: FontWeight.bold,
            color: cor ?? const Color(0xFF0D47A1),
          ),
        ),
      ],
    );
  }

  Widget _buildTabela() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          _cabecalho(),
          Expanded(
            child: Scrollbar(
              controller: _vertical,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _vertical,
                child: Column(children: [_corpo(), _rodape()]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cabecalho() {
    return Scrollbar(
      controller: _hHeader,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _hHeader,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: _wTable,
          child: Container(
            height: _hCab,
            color: const Color(0xFF0D47A1),
            child: Row(
              children: [
                _th('Data', _wData, () => _onSort('data_mov')),
                _th('Descrição', _wDesc, () => _onSort('descricao')),
                _th('Entrada (Amb)', _wNum, () => _onSort('entrada_amb')),
                _th('Entrada (20°C)', _wNum, () => _onSort('entrada_vinte')),
                _th('Saída (Amb)', _wNum, () => _onSort('saida_amb')),
                _th('Saída (20°C)', _wNum, () => _onSort('saida_vinte')),
                _th('Dif amb/20°C', _wNum, () => _onSort('sobra_perda')),
                _th('Saldo (Amb)', _wNum, () => _onSort('saldo_amb')),
                _th('Saldo (20°C)', _wNum, () => _onSort('saldo_vinte')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _th(String t, double w, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: w,
        alignment: Alignment.center,
        child: Text(
          t,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _corpo() {
    num totalEntradaAmb = 0;
    num totalEntradaVinte = 0;
    num totalSaidaAmb = 0;
    num totalSaidaVinte = 0;
    num totalSobraPerda = 0;

    for (final e in _movsOrdenadas) {
      totalEntradaAmb += (e['entrada_amb'] ?? 0) as num;
      totalEntradaVinte += (e['entrada_vinte'] ?? 0) as num;
      totalSaidaAmb += (e['saida_amb'] ?? 0) as num;
      totalSaidaVinte += (e['saida_vinte'] ?? 0) as num;
      totalSobraPerda += (e['sobra_perda'] ?? 0) as num;
    }

    return Scrollbar(
      controller: _hBody,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _hBody,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: _wTable,
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _movsOrdenadas.length + 2,
            itemBuilder: (context, i) {
              if (i == 0) {
                return _linhaResumo(
                  'Estoque Inicial',
                  _estoqueInicial['amb'],
                  _estoqueInicial['vinte'],
                  cor: Colors.blue,
                );
              }
              if (i == _movsOrdenadas.length + 1) {
                return _linhaResumo(
                  'Estoque Final',
                  _estoqueFinal['amb'],
                  _estoqueFinal['vinte'],
                  cor: Colors.grey.shade700,
                  entAmb: totalEntradaAmb,
                  entVinte: totalEntradaVinte,
                  saiAmb: totalSaidaAmb,
                  saiVinte: totalSaidaVinte,
                  sobraPerda: totalSobraPerda,
                );
              }

              final e = _movsOrdenadas[i - 1];
              
              return Container(
                height: _hRow,
                color: (i - 1) % 2 == 0 ? Colors.grey.shade50 : Colors.white,
                child: Row(
                  children: [
                    _cell(_fmtData(e['data_mov']), _wData),
                    _cell(e['descricao'] ?? '-', _wDesc),
                    _cell(_fmtNum(e['entrada_amb']), _wNum, bg: _bgEntrada()),
                    _cell(_fmtNum(e['entrada_vinte']), _wNum, bg: _bgEntrada()),
                    _cell(_fmtNum(e['saida_amb']), _wNum, bg: _bgSaida()),
                    _cell(_fmtNum(e['saida_vinte']), _wNum, bg: _bgSaida()),
                    _cell(
                      e['sobra_perda'] == null ? '' : _fmtNum(e['sobra_perda']),
                      _wNum,
                      cor: (e['sobra_perda'] ?? 0) < 0 ? Colors.red : Colors.green,
                    ),
                    _cell(
                      _fmtNum(e['saldo_amb']),
                      _wNum,
                      cor: (e['saldo_amb'] ?? 0) < 0 ? Colors.red : null,
                    ),
                    _cell(
                      _fmtNum(e['saldo_vinte']),
                      _wNum,
                      cor: (e['saldo_vinte'] ?? 0) < 0 ? Colors.red : null,
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

  Widget _linhaResumo(
    String label,
    num? amb,
    num? vinte, {
    Color? cor,
    num? entAmb,
    num? entVinte,
    num? saiAmb,
    num? saiVinte,
    num? sobraPerda,
  }) {
    return Container(
      height: _hRow,
      color: Colors.blue.shade50,
      child: Row(
        children: [
          _cell('', _wData),
          _cell(label, _wDesc, cor: cor, fw: FontWeight.bold),
          _cell(entAmb != null ? _fmtNum(entAmb) : '-', _wNum, cor: cor, fw: FontWeight.bold),
          _cell(entVinte != null ? _fmtNum(entVinte) : '-', _wNum, cor: cor, fw: FontWeight.bold),
          _cell(saiAmb != null ? _fmtNum(saiAmb) : '-', _wNum, cor: cor, fw: FontWeight.bold),
          _cell(saiVinte != null ? _fmtNum(saiVinte) : '-', _wNum, cor: cor, fw: FontWeight.bold),
          _cell(sobraPerda != null ? _fmtNum(sobraPerda) : '-', _wNum, cor: cor, fw: FontWeight.bold),
          _cell(_fmtNum(amb), _wNum, cor: cor, fw: FontWeight.bold),
          _cell(_fmtNum(vinte), _wNum, cor: cor, fw: FontWeight.bold),
        ],
      ),
    );
  }

  Widget _cell(String t, double w, {Color? bg, Color? cor, FontWeight? fw}) {
    return Container(
      width: w,
      alignment: Alignment.center,
      color: bg,
      child: Text(
        t.isEmpty ? '-' : t,
        style: TextStyle(
          fontSize: 12,
          color: cor ?? Colors.grey.shade700,
          fontWeight: fw,
        ),
      ),
    );
  }

  Widget _rodape() {
    return Container(
      height: _hFoot,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      color: Colors.grey.shade100,
      child: Text(
        '${_movsOrdenadas.length} movimentação(oes) no período',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade600,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}