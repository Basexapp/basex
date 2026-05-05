import 'package:flutter/material.dart';

class ControleAditivoPage extends StatefulWidget {
  final VoidCallback onVoltar;
  final String? terminalId;
  final String? empresaId;
  final String nomeTerminal;
  final String? empresaNome;
  final DateTime dataInicial;
  final DateTime dataFinal;
  final String tipoRelatorio;

  const ControleAditivoPage({
    super.key,
    required this.onVoltar,
    this.terminalId,
    this.empresaId,
    required this.nomeTerminal,
    this.empresaNome,
    required this.dataInicial,
    required this.dataFinal,
    required this.tipoRelatorio,
  });

  @override
  State<ControleAditivoPage> createState() => _ControleAditivoPageState();
}

class _ControleAditivoPageState extends State<ControleAditivoPage> {
  
  // Flags de carregamento
  bool _carregandoDados = false;
  String? _erro;
  
  // Dados da tabela
  List<Map<String, dynamic>> _movimentacoes = [];
  List<Map<String, dynamic>> _movimentacoesOrdenadas = [];
  
  // Controles de scroll
  final ScrollController _vertical = ScrollController();
  final ScrollController _hHeader = ScrollController();
  final ScrollController _hBody = ScrollController();
  
  // Dimensões da tabela
  static const double _hCab = 40;
  static const double _hRow = 40;
  
  static const double _wData = 120;
  static const double _wDescricao = 250;
  static const double _wNum = 130;
  
  double get _wTable {
    if (widget.tipoRelatorio == 'sintetico') {
      return _wData + (_wNum * 4); // Data + entradas + saídas + saldo
    } else {
      return _wData + _wDescricao + (_wNum * 3); // Data + Descrição + entradas + saídas + saldo
    }
  }
  
  // Ordenação
  String _coluna = 'data';
  bool _asc = true;
  
  // Totais
  double _totalEntradas = 0;
  double _totalSaidas = 0;
  double _saldoFinal = 0;

  @override
  void initState() {
    super.initState();
    _syncScroll();
    _carregarDadosFicticios();
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

  Future<void> _carregarDadosFicticios() async {
    setState(() {
      _carregandoDados = true;
      _erro = null;
    });

    // Simulando delay de rede
    await Future.delayed(const Duration(milliseconds: 800));

    try {
      final List<Map<String, dynamic>> mockData = [
        {
          'data': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
          'descricao': 'Recebimento de Aditivo - NF 1234',
          'entradas': 1000.0,
          'saidas': 0.0,
        },
        {
          'data': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(),
          'descricao': 'Consumo Operacional - Carregamento GCI',
          'entradas': 0.0,
          'saidas': 15.5,
        },
        {
          'data': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
          'descricao': 'Consumo Operacional - Carregamento GAS',
          'entradas': 0.0,
          'saidas': 22.8,
        },
        {
          'data': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
          'descricao': 'Ajuste de Estoque - Inventário Mensal',
          'entradas': 5.0,
          'saidas': 0.0,
        },
        {
          'data': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
          'descricao': 'Consumo Operacional - Transferência entre Tanques',
          'entradas': 0.0,
          'saidas': 8.4,
        },
      ];

      if (widget.tipoRelatorio == 'sintetico') {
        _processarDadosSintetico(mockData);
      } else {
        _processarDadosAnalitico(mockData);
      }

    } catch (e) {
      setState(() {
        _erro = 'Erro ao processar dados fictícios';
        _carregandoDados = false;
      });
    }
  }

  void _processarDadosAnalitico(List<Map<String, dynamic>> mockData) {
    final List<Map<String, dynamic>> movimentacoes = [];
    double saldoAcumulado = 0;
    double totalEntradas = 0;
    double totalSaidas = 0;

    for (var item in mockData) {
      double entradas = item['entradas'];
      double saidas = item['saidas'];

      totalEntradas += entradas;
      totalSaidas += saidas;
      saldoAcumulado = saldoAcumulado + entradas - saidas;

      movimentacoes.add({
        'data': item['data'],
        'descricao': item['descricao'],
        'entradas': entradas,
        'saidas': saidas,
        'saldo': saldoAcumulado,
      });
    }

    setState(() {
      _movimentacoes = movimentacoes;
      _movimentacoesOrdenadas = List.from(movimentacoes);
      _totalEntradas = totalEntradas;
      _totalSaidas = totalSaidas;
      _saldoFinal = saldoAcumulado;
      _carregandoDados = false;
    });
  }

  void _processarDadosSintetico(List<Map<String, dynamic>> mockData) {
    final Map<String, Map<String, dynamic>> grupos = {};
    double totalEntradas = 0;
    double totalSaidas = 0;

    for (var item in mockData) {
      final String data = item['data'].split('T')[0];
      
      if (!grupos.containsKey(data)) {
        grupos[data] = {
          'data': item['data'],
          'entradas': 0.0,
          'saidas': 0.0,
          'movimentacoes': 0,
        };
      }

      grupos[data]!['entradas'] += item['entradas'];
      grupos[data]!['saidas'] += item['saidas'];
      grupos[data]!['movimentacoes'] += 1;

      totalEntradas += item['entradas'];
      totalSaidas += item['saidas'];
    }

    final List<Map<String, dynamic>> movimentacoes = [];
    final datasOrdenadas = grupos.keys.toList()..sort();
    double saldoAcumulado = 0;

    for (var data in datasOrdenadas) {
      final grupo = grupos[data]!;
      saldoAcumulado = saldoAcumulado + grupo['entradas'] - grupo['saidas'];
      
      movimentacoes.add({
        'data': grupo['data'],
        'descricao': '${grupo['movimentacoes']} movimentações',
        'entradas': grupo['entradas'],
        'saidas': grupo['saidas'],
        'saldo': saldoAcumulado,
      });
    }

    setState(() {
      _movimentacoes = movimentacoes;
      _movimentacoesOrdenadas = List.from(movimentacoes);
      _totalEntradas = totalEntradas;
      _totalSaidas = totalSaidas;
      _saldoFinal = saldoAcumulado;
      _carregandoDados = false;
    });
  }

  void _ordenar(String col, bool asc) {
    final ord = List<Map<String, dynamic>>.from(_movimentacoes);
    ord.sort((a, b) {
      dynamic va, vb;
      switch (col) {
        case 'data':
          va = DateTime.parse(a['data'] as String);
          vb = DateTime.parse(b['data'] as String);
          break;
        case 'descricao':
          va = (a['descricao'] as String? ?? '').toLowerCase();
          vb = (b['descricao'] as String? ?? '').toLowerCase();
          break;
        case 'entradas':
        case 'saidas':
        case 'saldo':
          va = a[col] as double? ?? 0.0;
          vb = b[col] as double? ?? 0.0;
          break;
        default:
          return 0;
      }
      return asc ? va.compareTo(vb) : vb.compareTo(va);
    });

    setState(() {
      _movimentacoesOrdenadas = ord;
      _coluna = col;
      _asc = asc;
    });
  }

  void _onSort(String col) {
    final asc = _coluna == col ? !_asc : true;
    _ordenar(col, asc);
  }

  String _fmtNum(double? v) {
    if (v == null) return '-';
    return v.toStringAsFixed(2).replaceAll('.', ',');
  }

  String _fmtData(String dataStr) {
    try {
      final date = DateTime.parse(dataStr);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return dataStr;
    }
  }

  Color _bgEntrada() => Colors.green.shade50.withOpacity(0.3);
  Color _bgSaida() => Colors.red.shade50.withOpacity(0.3);

  String _fmtPeriodo() {
    final di = widget.dataInicial;
    final df = widget.dataFinal;
    return '${di.day.toString().padLeft(2, '0')}/${di.month.toString().padLeft(2, '0')}/${di.year} a ${df.day.toString().padLeft(2, '0')}/${df.month.toString().padLeft(2, '0')}/${df.year}';
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
            const Text(
              'Conta Corrente de Aditivos',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              widget.nomeTerminal,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onVoltar,
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0D47A1).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  widget.tipoRelatorio == 'sintetico' ? Icons.view_week : Icons.view_list,
                  size: 16,
                  color: const Color(0xFF0D47A1),
                ),
                const SizedBox(width: 4),
                Text(
                  widget.tipoRelatorio == 'sintetico' ? 'Sintético' : 'Analítico',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0D47A1)),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregarDadosFicticios,
            tooltip: 'Recarregar dados',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Wrap(
                    spacing: 32,
                    runSpacing: 12,
                    children: [
                      _buildInfoFiltro(Icons.store, 'Terminal', widget.nomeTerminal),
                      _buildInfoFiltro(Icons.business, 'Empresa', widget.empresaNome ?? '-'),
                      _buildInfoFiltro(Icons.calendar_today, 'Período', _fmtPeriodo()),
                      _buildInfoFiltro(Icons.assessment, 'Tipo', widget.tipoRelatorio == 'sintetico' ? 'Sintético' : 'Analítico'),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _carregandoDados
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D47A1)))
                  : _erro != null
                      ? _buildErro()
                      : Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 900),
                            child: _movimentacoes.isEmpty ? _buildVazio() : _buildTabela(),
                          ),
                        ),
            ),
            if (_movimentacoes.isNotEmpty && _erro == null)
              Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 900), child: _buildRodape())),
          ],
        ),
      ),
    );
  }

  Widget _buildErro() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(_erro!, style: TextStyle(fontSize: 16, color: Colors.red.shade700), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _carregarDadosFicticios,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1)),
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  Widget _buildVazio() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
        const SizedBox(height: 16),
        Text('Nenhuma movimentação encontrada', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
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
              child: SingleChildScrollView(controller: _vertical, child: _corpo()),
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
                _th('Data', _wData, () => _onSort('data')),
                if (widget.tipoRelatorio == 'sintetico')
                  _th('Movimentações', _wNum, () => _onSort('descricao'))
                else
                  _th('Descrição', _wDescricao, () => _onSort('descricao')),
                _th('Qtd entrada (L)', _wNum, () => _onSort('entradas')),
                _th('Qtd saída (L)', _wNum, () => _onSort('saidas')),
                _th('Saldo (L)', _wNum, () => _onSort('saldo')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _th(String titulo, double largura, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: largura,
        alignment: Alignment.center,
        child: Text(
          titulo,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _corpo() {
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
            itemCount: _movimentacoesOrdenadas.length,
            itemBuilder: (context, index) {
              final item = _movimentacoesOrdenadas[index];
              return Container(
                height: _hRow,
                color: index % 2 == 0 ? Colors.grey.shade50 : Colors.white,
                child: Row(
                  children: [
                    _cell(_fmtData(item['data'] as String), _wData),
                    if (widget.tipoRelatorio == 'sintetico')
                      _cell(item['descricao'] as String? ?? '-', _wNum)
                    else
                      _cell(item['descricao'] as String? ?? '-', _wDescricao),
                    _cell(_fmtNum(item['entradas'] as double?), _wNum, bg: _bgEntrada()),
                    _cell(_fmtNum(item['saidas'] as double?), _wNum, bg: _bgSaida()),
                    _cell(_fmtNum(item['saldo'] as double?), _wNum, cor: (item['saldo'] as double? ?? 0) < 0 ? Colors.red : null),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _cell(String texto, double largura, {Color? bg, Color? cor}) {
    return Container(
      width: largura,
      alignment: Alignment.center,
      color: bg,
      child: Text(
        texto,
        style: TextStyle(fontSize: 12, color: cor ?? Colors.grey.shade700),
      ),
    );
  }

  Widget _buildInfoFiltro(IconData icon, String label, String valor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.grey.shade500)),
            Text(valor, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
          ],
        ),
      ],
    );
  }

  Widget _buildRodape() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildItemRodape('Total de entradas', _fmtNum(_totalEntradas), Colors.green.shade700),
          _buildItemRodape('Total de saídas', _fmtNum(_totalSaidas), Colors.red.shade700),
          _buildItemRodape('Saldo atual', _fmtNum(_saldoFinal), const Color(0xFF0D47A1), negrito: true),
        ],
      ),
    );
  }

  Widget _buildItemRodape(String label, String valor, Color cor, {bool negrito = false}) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Text(valor, style: TextStyle(fontSize: negrito ? 18 : 16, fontWeight: negrito ? FontWeight.bold : FontWeight.normal, color: cor)),
      ],
    );
  }
}
