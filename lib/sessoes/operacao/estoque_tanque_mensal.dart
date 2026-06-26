import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'excel_helper.dart';

class EstoqueTanqueMensalPage extends StatefulWidget {
  final String tanqueId;
  final String referenciaTanque;
  final String terminalId;
  final String nomeTerminal;
  final int mes;
  final int ano;
  final VoidCallback? onVoltar;
  final bool mostrarDetalhado;

  const EstoqueTanqueMensalPage({
    super.key,
    required this.tanqueId,
    required this.referenciaTanque,
    required this.terminalId,
    required this.nomeTerminal,
    required this.mes,
    required this.ano,
    this.onVoltar,
    this.mostrarDetalhado = true,
  });

  @override
  State<EstoqueTanqueMensalPage> createState() => _EstoqueTanqueMensalPageState();
}

class _EstoqueTanqueMensalPageState extends State<EstoqueTanqueMensalPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _carregando = true;
  bool _erro = false;
  bool _baixandoExcel = false;
  String _mensagemErro = '';

  String? _terminalId;
  String? _produtoId;
  bool _carregandoTerminal = true;

  List<Map<String, dynamic>> _movs = [];
  List<Map<String, dynamic>> _movsOrdenadas = [];
  List<Map<String, dynamic>> _movsConsolidadas = [];

  Map<String, num?> _estoqueInicial = {'amb': 0, 'vinte': 0};
  Map<String, num?> _estoqueFinal = {'amb': null, 'vinte': null};

  num _totalEntradas = 0;
  num _totalEntradasAmb = 0;
  num _totalSaidas = 0;
  num _totalSaidasAmb = 0;
  num _totalSobraPerda = 0;
  String? _produtoNome;

  late DateTime _inicioMes;
  late DateTime _fimMes;

  final ScrollController _vertical = ScrollController();
  final ScrollController _hHeader = ScrollController();
  final ScrollController _hBody = ScrollController();

  static const double _hCab = 40;
  static const double _hRow = 40;
  static const double _hFoot = 32;

  static const double _wData = 120;
  static const double _wEmpresa = 150;
  static const double _wDesc = 240;
  static const double _wNum = 130;

  double get _wTable => _wData + _wEmpresa + _wDesc + (_wNum * 7);

  String _coluna = 'data_mov';
  bool _asc = true;

  @override
  void initState() {
    super.initState();
    _inicioMes = DateTime(widget.ano, widget.mes, 1);
    _fimMes = DateTime(widget.ano, widget.mes + 1, 0, 23, 59, 59);
    _syncScroll();
    _carregarTerminalDoUsuario();
  }

  Future<void> _carregarTerminalDoUsuario() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Usuário não logado');
      }

      final response = await _supabase
          .from('usuarios')
          .select('terminal:terminais(id, nome)')
          .eq('id', user.id)
          .maybeSingle();

      if (response != null && response['terminal'] != null) {
        final terminal = response['terminal'] as Map;
        _terminalId = terminal['id']?.toString();
      }
      
      // Após ter o terminal, carrega os dados
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
      final dataRef = DateTime(widget.ano, widget.mes, 1);
      final dataStr = dataRef.toIso8601String().split('T')[0];

      final response = await _supabase.rpc(
        'fn_estoque_inicial_mes_tanque',
        params: {
          'p_tanque_id': widget.tanqueId,
          'p_terminal_id': _terminalId,
          'p_produto_id': _produtoId,
          'p_data': dataStr,
        },
      );

      num saldo = 0;
      if (response is Map) {
        saldo = (response['estoque_inicial'] ?? 0) as num;
      } else {
        saldo = (response ?? 0) as num;
      }

      _estoqueInicial = {
        'amb': saldo,
        'vinte': saldo,
      };
    } catch (e) {
      debugPrint('Erro ao buscar estoque inicial mensal via função: $e');
      _estoqueInicial = {'amb': 0, 'vinte': 0};
    }
  }

  Future<void> _carregarProdutoDoTanque() async {
    try {
        final resp = await _supabase
          .from('tanques')
          .select('produto_id, produtos (id, nome)')
          .eq('id', widget.tanqueId)
          .maybeSingle();

      if (resp != null) {
        _produtoId = resp['produto_id']?.toString();

        final produtoObj = resp['produtos'];
        if (_produtoId == null && produtoObj is Map && produtoObj['id'] != null) {
          _produtoId = produtoObj['id'].toString();
        }

        if (produtoObj is Map && produtoObj['nome'] != null) {
          _produtoNome = produtoObj['nome'].toString();
        } else if (resp['nome'] != null) {
          _produtoNome = resp['nome'].toString();
        } else {
          _produtoNome = null;
        }
      } else {
        _produtoNome = null;
      }
    } catch (_) {
      _produtoNome = null;
    }
  }

  Future<void> _calcularTotais() async {
    try {
      // Soma todas as entradas do mês (20ºC e Amb)
      final entradasResp = await _supabase
          .from('movimentacoes_tanque')
          .select('''
            entrada_vinte, 
            entrada_amb, 
            tipo_mov, 
            descricao, 
            cliente,
            movimentacoes(data_descarga)
          ''')
          .eq('tanque_id', widget.tanqueId)
          .gte('data_mov', _inicioMes.toIso8601String())
          .lte('data_mov', _fimMes.toIso8601String());

      _totalEntradas = 0;
      _totalEntradasAmb = 0;
      _totalSobraPerda = 0;

      for (final item in entradasResp) {
        final num ev = (item['entrada_vinte'] ?? 0) as num;
        final num ea = (item['entrada_amb'] ?? 0) as num;
        
        final String tipo = (item['tipo_mov']?.toString() ?? '').toLowerCase();
        final String desc = (item['descricao']?.toString() ?? '').toLowerCase();
        final String cli = (item['cliente']?.toString() ?? '').toLowerCase();

        final bool eSobra = tipo.contains('sobra') || desc.contains('sobra') || cli.contains('sobra');

        if (eSobra) {
          _totalSobraPerda += ev;
        } else {
          _totalEntradas += ev;
          _totalEntradasAmb += ea;
        }
      }

      // Soma todas as saídas do mês (20ºC e Amb)
      final saidasResp = await _supabase
          .from('movimentacoes_tanque')
          .select('saida_vinte, saida_amb, tipo_mov, descricao, cliente')
          .eq('tanque_id', widget.tanqueId)
          .gte('data_mov', _inicioMes.toIso8601String())
          .lte('data_mov', _fimMes.toIso8601String());

      _totalSaidas = 0;
      _totalSaidasAmb = 0;

      for (final item in saidasResp) {
        final num sv = (item['saida_vinte'] ?? 0) as num;
        final num sa = (item['saida_amb'] ?? 0) as num;
        
        final String tipo = (item['tipo_mov']?.toString() ?? '').toLowerCase();
        final String desc = (item['descricao']?.toString() ?? '').toLowerCase();
        final String cli = (item['cliente']?.toString() ?? '').toLowerCase();

        final bool ePerda = tipo.contains('perda') || desc.contains('perda') || cli.contains('perda');

        if (ePerda) {
          _totalSobraPerda -= sv;
        } else if (!(tipo.contains('sobra') || desc.contains('sobra') || cli.contains('sobra'))) {
          _totalSaidas += sv;
          _totalSaidasAmb += sa;
        }
      }
    } catch (e) {
      debugPrint('Erro ao calcular totais: $e');
    }
  }

  Future<void> _carregar() async {
    if (_terminalId == null) {
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
      await _carregarProdutoDoTanque();
      await _carregarEstoqueInicialDoBanco();
      await _calcularTotais();

      final dados = await _supabase
          .from('movimentacoes_tanque')
          .select('''
            id,
            movimentacao_id,
            cacl_id,
            data_mov,
            cliente,
            descricao,
            tipo_mov,
            entrada_amb,
            entrada_vinte,
            saida_amb,
            saida_vinte,
            movimentacoes(
              data_descarga,
              empresa_id,
              empresas(
                nome_dois
              )
            )
          ''')
          .eq('tanque_id', widget.tanqueId)
          .gte('data_mov', _inicioMes.toIso8601String())
          .lte('data_mov', _fimMes.toIso8601String());

      final List<Map<String, dynamic>> listaOrdenadaParaUI =
          List<Map<String, dynamic>>.from(dados);

      listaOrdenadaParaUI.sort((a, b) {
        final bool aEntrada = (a['entrada_vinte'] ?? 0) > 0 || (a['entrada_amb'] ?? 0) > 0;
        final bool bEntrada = (b['entrada_vinte'] ?? 0) > 0 || (b['entrada_amb'] ?? 0) > 0;

        String? aDataDescarga;
        if (aEntrada && a['movimentacoes'] != null && a['movimentacoes']['data_descarga'] != null) {
          aDataDescarga = a['movimentacoes']['data_descarga'].toString();
        }
        
        String? bDataDescarga;
        if (bEntrada && b['movimentacoes'] != null && b['movimentacoes']['data_descarga'] != null) {
          bDataDescarga = b['movimentacoes']['data_descarga'].toString();
        }

        final da = DateTime.parse(aDataDescarga ?? a['data_mov']);
        final db = DateTime.parse(bDataDescarga ?? b['data_mov']);
        
        final dataA = DateTime(da.year, da.month, da.day);
        final dataB = DateTime(db.year, db.month, db.day);
        
        final cmpData = dataA.compareTo(dataB);
        if (cmpData != 0) return cmpData;
        
        bool temSobraOuPerda(Map<String, dynamic> m) {
          final cliente = (m['cliente']?.toString() ?? '').toUpperCase();
          final descricao = (m['descricao']?.toString() ?? '').toUpperCase();
          return cliente.contains('SOBRA') || descricao.contains('SOBRA') ||
                cliente.contains('PERDA') || descricao.contains('PERDA');
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

      final List<Map<String, dynamic>> listaComSaldo = [];

      for (final m in listaOrdenadaParaUI) {
        final num entradaAmb = (m['entrada_amb'] ?? 0) as num;
        final num entradaVinte = (m['entrada_vinte'] ?? 0) as num;
        final num saidaAmb = (m['saida_amb'] ?? 0) as num;
        final num saidaVinte = (m['saida_vinte'] ?? 0) as num;

        final bool isEntrada = entradaVinte > 0 || entradaAmb > 0;
        String dataExibicao = m['data_mov'];
        if (isEntrada && m['movimentacoes'] != null && m['movimentacoes']['data_descarga'] != null) {
          dataExibicao = m['movimentacoes']['data_descarga'].toString();
        }

        final String cliente = (m['cliente']?.toString().trim() ?? '');
        final String desc = (m['descricao']?.toString().trim() ?? '');
        String descricao = cliente.isNotEmpty ? cliente : desc;

        if (desc.toLowerCase().contains("venda comum") || cliente.toLowerCase().contains("venda comum")) {
          descricao = "Venda - $descricao";
        }

        final String? tipoMovRaw = m['tipo_mov']?.toString();
        final String tipoMov = (tipoMovRaw ?? '').toLowerCase();
        final String descLower = desc.toLowerCase();
        final String clienteLower = cliente.toLowerCase();

        final bool isSobraPerda = (tipoMovRaw != null
            ? (tipoMov.contains('sobra') || tipoMov.contains('perda'))
            : (descLower.contains('sobra') || descLower.contains('perda') ||
              clienteLower.contains('sobra') || clienteLower.contains('perda')));

        String empresaNome = '-';

        if (!isSobraPerda) {
          final movData = m['movimentacoes'];
          if (movData is Map) {
            final empresaData = movData['empresas'];
            if (empresaData is Map) {
              empresaNome = empresaData['nome_dois']?.toString() ?? '-';
            }
          }
        }

        final bool eSobra = tipoMovRaw != null
            ? tipoMov.contains('sobra')
            : descLower.contains('sobra') || clienteLower.contains('sobra');
        final bool ePerda = tipoMovRaw != null
            ? tipoMov.contains('perda')
            : descLower.contains('perda') || clienteLower.contains('perda');

        final num magnitude = entradaVinte != 0 ? entradaVinte : saidaVinte;
        num? sobraPerda;
        final num entradaVinteDisplay;
        final num saidaVinteDisplay;

        if (eSobra) {
          sobraPerda = magnitude;
          entradaVinteDisplay = 0;
          saidaVinteDisplay = 0;
        } else if (ePerda) {
          sobraPerda = -magnitude;
          entradaVinteDisplay = 0;
          saidaVinteDisplay = 0;
        } else {
          entradaVinteDisplay = entradaVinte;
          saidaVinteDisplay = saidaVinte;
        }

        saldoAmb += entradaAmb - saidaAmb;
        saldoVinte += entradaVinteDisplay - saidaVinteDisplay + (sobraPerda ?? 0);

        listaComSaldo.add({
          'id': m['id'],
          'movimentacao_id': m['movimentacao_id'],
          'cacl_id': m['cacl_id'],
          'data_mov': dataExibicao,
          'empresa_nome': empresaNome,
          'descricao': descricao,
          'entrada_amb': entradaAmb,
          'entrada_vinte': entradaVinteDisplay,
          'saida_amb': saidaAmb,
          'saida_vinte': saidaVinteDisplay,
          'sobra_perda': sobraPerda,
          'saldo_amb': saldoAmb,
          'saldo_vinte': saldoVinte,
        });
      }

      _movs = List<Map<String, dynamic>>.from(listaComSaldo);
      _movsOrdenadas = List<Map<String, dynamic>>.from(listaComSaldo);
      _movsConsolidadas = _consolidarPorData(_movs);

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

  List<Map<String, dynamic>> _consolidarPorData(List<Map<String, dynamic>> movs) {
    // Group rows by date and accumulate display totals.
    // Saldo is taken from the last row of each day (already correctly computed).
    final Map<String, Map<String, dynamic>> porData = {};
    final List<String> ordem = [];
    for (final m in movs) {
      final dataKey = m['data_mov'].toString().substring(0, 10);
      if (!porData.containsKey(dataKey)) {
        porData[dataKey] = {'entrada_vinte': 0 as num, 'saida_vinte': 0 as num, 'entrada_amb': 0 as num, 'saida_amb': 0 as num, 'sobra_perda': 0 as num};
        ordem.add(dataKey);
      }
      porData[dataKey]!['entrada_vinte'] =
          (porData[dataKey]!['entrada_vinte'] as num) + ((m['entrada_vinte'] ?? 0) as num);
      porData[dataKey]!['saida_vinte'] =
          (porData[dataKey]!['saida_vinte'] as num) + ((m['saida_vinte'] ?? 0) as num);
      porData[dataKey]!['entrada_amb'] =
          (porData[dataKey]!['entrada_amb'] as num) + ((m['entrada_amb'] ?? 0) as num);
      porData[dataKey]!['saida_amb'] =
          (porData[dataKey]!['saida_amb'] as num) + ((m['saida_amb'] ?? 0) as num);
      porData[dataKey]!['sobra_perda'] =
          (porData[dataKey]!['sobra_perda'] as num) + ((m['sobra_perda'] ?? 0) as num);
      // Always keep the last row's running saldo for this day
      porData[dataKey]!['saldo_vinte'] = m['saldo_vinte'];
      porData[dataKey]!['saldo_amb'] = m['saldo_amb'];
    }
    final result = <Map<String, dynamic>>[];
    for (final dataKey in ordem) {
      final entradaVinte = porData[dataKey]!['entrada_vinte'] as num;
      final saidaVinte = porData[dataKey]!['saida_vinte'] as num;
      final entradaAmb = porData[dataKey]!['entrada_amb'] as num;
      final saidaAmb = porData[dataKey]!['saida_amb'] as num;
      final sobraPerda = porData[dataKey]!['sobra_perda'] as num;
      result.add({
        'data_mov': '${dataKey}T00:00:00',
        'descricao': 'Consolidado',
        'entrada_amb': entradaAmb,
        'entrada_vinte': entradaVinte,
        'saida_amb': saidaAmb,
        'saida_vinte': saidaVinte,
        'sobra_perda': sobraPerda != 0 ? sobraPerda : null,
        'saldo_amb': porData[dataKey]!['saldo_amb'],
        'saldo_vinte': porData[dataKey]!['saldo_vinte'],
      });
    }
    return result;
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
        case 'sobra_perda':
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

  Future<void> _baixarExcel() async {
    final listaBase =
        widget.mostrarDetalhado ? _movsOrdenadas : _movsConsolidadas;

    if (listaBase.isEmpty) {
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
          content: Text('Preparando download...'),
          duration: Duration(seconds: 4),
        ),
      );

      final List<Map<String, dynamic>> dadosFormatados = listaBase.map((m) {
        return {
          'data_mov': _fmtData(m['data_mov']?.toString() ?? ''),
          'descricao': m['descricao'] ?? '',
          'entrada_amb': m['entrada_amb'] ?? 0,
          'entrada_vinte': m['entrada_vinte'] ?? 0,
          'saida_amb': m['saida_amb'] ?? 0,
          'saida_vinte': m['saida_vinte'] ?? 0,
          'saldo_amb': m['saldo_amb'] ?? 0,
          'saldo_vinte': m['saldo_vinte'] ?? 0,
        };
      }).toList();

      final nomeTerminalFormatado = widget.nomeTerminal
          .replaceAll(' ', '_')
          .replaceAll(RegExp(r'[^\w_]'), '');

      final mes = widget.mes.toString().padLeft(2, '0');
      final ano = widget.ano.toString();
      final fileName =
          'estoque_tanque_mensal_${widget.referenciaTanque}_${nomeTerminalFormatado}_${mes}_${ano}.xlsx';

      gerarExcelEstoqueTanque(
        dados: dadosFormatados,
        estoqueInicial: _estoqueInicial,
        estoqueFinal: _estoqueFinal,
        nomeArquivo: fileName,
      );

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Download do Excel iniciado! Verifique sua pasta de downloads.',
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
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

  String _getNomeMes(int mes) {
    const meses = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    return meses[mes - 1];
  }

  @override
  Widget build(BuildContext context) {
    final String mesAno = '${_getNomeMes(widget.mes)}/${widget.ano}';

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
              "Movimentação Mensal do Tanque – ${widget.referenciaTanque}${_produtoNome != null ? ' - ${_produtoNome!}' : ''}",
            ),
            Text(
              '${widget.nomeTerminal} | $mesAno',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onVoltar ?? () => Navigator.pop(context),
        ),
        actions: [
          _baixandoExcel
              ? const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF0D47A1),
                      ),
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.download),
                  tooltip: 'Baixar Excel',
                  onPressed: _baixarExcel,
                ),
          if (widget.mostrarDetalhado)
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
            'Total Sobra/Perda (20ºC):',
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
                _th('Empresa', _wEmpresa, () => _onSort('empresa_nome')),
                _th('Descrição', _wDesc, () => _onSort('descricao')),
                _th('Entrada (Amb)', _wNum, () => _onSort('entrada_amb')),
                _th('Entrada (20ºC)', _wNum, () => _onSort('entrada_vinte')),
                _th('Saída (Amb)', _wNum, () => _onSort('saida_amb')),
                _th('Saída (20ºC)', _wNum, () => _onSort('saida_vinte')),
                _th('Sobra/Perda', _wNum, () => _onSort('sobra_perda')),
                _th('Saldo (Amb)', _wNum, () => _onSort('saldo_amb')),
                _th('Saldo (20ºC)', _wNum, () => _onSort('saldo_vinte')),
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
    if (!widget.mostrarDetalhado) {
      return _corpoConsolidado();
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
                  'Estoque Inicial do Mês →',
                  _estoqueInicial['amb'],
                  _estoqueInicial['vinte'],
                  cor: Colors.blue,
                );
              }
              if (i == _movsOrdenadas.length + 1) {
                return _linhaResumo(
                  'Estoque Final →',
                  _estoqueFinal['amb'],
                  _estoqueFinal['vinte'],
                  cor: Colors.grey.shade700,
                  entAmb: _totalEntradasAmb,
                  entVinte: _totalEntradas,
                  saiAmb: _totalSaidasAmb,
                  saiVinte: _totalSaidas,
                  sobraPerda: _totalSobraPerda,
                );
              }

              final e = _movsOrdenadas[i - 1];
              return Container(
                height: _hRow,
                color: (i - 1) % 2 == 0 ? Colors.grey.shade50 : Colors.white,
                child: Row(
                  children: [
                    _cell(_fmtData(e['data_mov']), _wData),
                    _cell(e['empresa_nome'] ?? '-', _wEmpresa),
                    _cell(e['descricao'] ?? '-', _wDesc),
                    _cell(_fmtNum(e['entrada_amb']), _wNum, bg: _bgEntrada()),
                    _cell(_fmtNum(e['entrada_vinte']), _wNum, bg: _bgEntrada()),
                    _cell(_fmtNum(e['saida_amb']), _wNum, bg: _bgSaida()),
                    _cell(_fmtNum(e['saida_vinte']), _wNum, bg: _bgSaida()),
                    _cell(
                      e['sobra_perda'] != null ? _fmtNum(e['sobra_perda'] as num) : '-',
                      _wNum,
                      cor: e['sobra_perda'] != null
                          ? ((e['sobra_perda'] as num) < 0 ? Colors.red : const Color(0xFF0D47A1))
                          : null,
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

  Widget _corpoConsolidado() {
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
            itemCount: _movsConsolidadas.length + 2,
            itemBuilder: (context, i) {
              if (i == 0) {
                return _linhaResumo(
                  'Estoque Inicial do Mês',
                  _estoqueInicial['amb'],
                  _estoqueInicial['vinte'],
                  cor: Colors.blue,
                );
              }
              if (i == _movsConsolidadas.length + 1) {
                return _linhaResumo(
                  'Estoque Final',
                  _estoqueFinal['amb'],
                  _estoqueFinal['vinte'],
                  cor: Colors.grey.shade700,
                  entAmb: _totalEntradasAmb,
                  entVinte: _totalEntradas,
                  saiAmb: _totalSaidasAmb,
                  saiVinte: _totalSaidas,
                  sobraPerda: _totalSobraPerda,
                );
              }
              final e = _movsConsolidadas[i - 1];
              return Container(
                height: _hRow,
                color: (i - 1) % 2 == 0 ? Colors.grey.shade50 : Colors.white,
                child: Row(
                  children: [
                    _cell(_fmtData(e['data_mov']), _wData),
                    _cell('-', _wEmpresa),
                    _cell(e['descricao'] ?? '-', _wDesc),
                    _cell(_fmtNum(e['entrada_amb']), _wNum, bg: _bgEntrada()),
                    _cell(_fmtNum(e['entrada_vinte']), _wNum, bg: _bgEntrada()),
                    _cell(_fmtNum(e['saida_amb']), _wNum, bg: _bgSaida()),
                    _cell(_fmtNum(e['saida_vinte']), _wNum, bg: _bgSaida()),
                    _cell(
                      e['sobra_perda'] != null ? _fmtNum(e['sobra_perda'] as num) : '-',
                      _wNum,
                      cor: e['sobra_perda'] != null
                          ? ((e['sobra_perda'] as num) < 0 ? Colors.red : const Color(0xFF0D47A1))
                          : null,
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
          _cell('', _wEmpresa),
          _cell(label, _wDesc, cor: cor, fw: FontWeight.bold),
          _cell(_fmtNum(entAmb), _wNum, bg: _bgEntrada(), fw: FontWeight.bold),
          _cell(_fmtNum(entVinte), _wNum, bg: _bgEntrada(), fw: FontWeight.bold),
          _cell(_fmtNum(saiAmb), _wNum, bg: _bgSaida(), fw: FontWeight.bold),
          _cell(_fmtNum(saiVinte), _wNum, bg: _bgSaida(), fw: FontWeight.bold),
          _cell(
            _fmtNum(sobraPerda),
            _wNum,
            cor: sobraPerda != null
                ? (sobraPerda < 0 ? Colors.red : const Color(0xFF0D47A1))
                : null,
            fw: FontWeight.bold,
          ),
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
        widget.mostrarDetalhado
            ? '${_movsOrdenadas.length} movimentação(ões) no mês'
            : '${_movsConsolidadas.length} dia(s) com movimentação no mês',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade600,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}