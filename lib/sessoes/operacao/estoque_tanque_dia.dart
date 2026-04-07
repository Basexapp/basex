import 'dart:convert';
import 'dart:html' as html;
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'medicoes_emitir_cacl.dart';
import 'medicoes_editar_cacl.dart';

enum EstagioCACL {
  semAbertura,
  aberturaRealizada,
  fechado,
}

class EstoqueTanquePage extends StatefulWidget {
  final String tanqueId;
  final String referenciaTanque;
  final DateTime data;
  final VoidCallback? onVoltar;

  const EstoqueTanquePage({
    super.key,
    required this.tanqueId,
    required this.referenciaTanque,
    required this.data,
    this.onVoltar,
  });

  @override
  State<EstoqueTanquePage> createState() => _EstoqueTanquePageState();
}

class _EstoqueTanquePageState extends State<EstoqueTanquePage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _carregando = true;
  bool _erro = false;
  String _mensagemErro = '';
  
  String? _terminalId;
  String? _terminalNome;
  bool _carregandoTerminal = true;

  List<Map<String, dynamic>> _movs = [];
  List<Map<String, dynamic>> _movsOrdenadas = [];

  Map<String, num?> _estoqueInicial = {'amb': 0, 'vinte': 0};
  Map<String, num?> _estoqueFinal = {'amb': null, 'vinte': null};
  Map<String, num?> _estoqueCACL = {'amb': null, 'vinte': null};
  bool _possuiCACL = false;

  num _totalEntradas = 0;
  num _totalSaidas = 0;
  num _totalSobraPerda = 0;

  num? _valorSobraPerda;
  bool? _ehSobra;
  bool _baixandoExcel = false;
  String? _produtoNome;

  late DateTime _dataFiltro;

  final ScrollController _vertical = ScrollController();
  final ScrollController _hHeader = ScrollController();
  final ScrollController _hBody = ScrollController();

  EstagioCACL _estagioCACL = EstagioCACL.semAbertura;
  String? _caclId;

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
    _dataFiltro = widget.data;
    _syncScroll();
    _carregarTerminalDoUsuario();
  }

  Future<void> _carregarTerminalDoUsuario() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Usuário não logado');

      final response = await _supabase
          .from('usuarios')
          .select('terminal:terminais(id, nome)')
          .eq('id', user.id)
          .maybeSingle();

      if (response != null && response['terminal'] != null) {
        final terminal = response['terminal'] as Map;
        _terminalId = terminal['id']?.toString();
        _terminalNome = terminal['nome']?.toString();
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
      final dataStr = _dataFiltro.toIso8601String().split('T')[0];

      final response = await _supabase.rpc(
        'fn_estoque_inicial_tanque',
        params: {
          'p_tanque_id': widget.tanqueId,
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
      debugPrint('Erro ao buscar estoque inicial via função: $e');
      _estoqueInicial = {'amb': 0, 'vinte': 0};
    }
  }

  Future<void> _verificarEstagioCACL() async {
    try {
      final dataStr = _dataFiltro.toIso8601String().split('T')[0];
      
      final saldoDiario = await _supabase
          .from('saldo_tanque_diario')
          .select('saldo')
          .eq('tanque_id', widget.tanqueId)
          .eq('data_mov', dataStr)
          .maybeSingle();

      if (saldoDiario != null) {
        setState(() {
          _estagioCACL = EstagioCACL.fechado;
          _possuiCACL = true;
          _estoqueCACL = {
            'amb': saldoDiario['saldo'] ?? 0,
            'vinte': saldoDiario['saldo'] ?? 0,
          };
          _caclId = null;
        });
        return;
      }

      final caclExistente = await _supabase
          .from('cacl')
          .select('id, status, volume_20_final')
          .eq('tanque_id', widget.tanqueId)
          .eq('data', dataStr)
          .eq('tipo', 'verificacao')
          .neq('status', 'cancelado')
          .maybeSingle();

      if (caclExistente != null) {
        final hasFechamento = caclExistente['volume_20_final'] != null;
        
        if (!hasFechamento) {
          setState(() {
            _estagioCACL = EstagioCACL.aberturaRealizada;
            _possuiCACL = false;
            _estoqueCACL = {'amb': null, 'vinte': null};
            _caclId = caclExistente['id'].toString();
          });
        } else {
          setState(() {
            _estagioCACL = EstagioCACL.fechado;
            _possuiCACL = true;
            _estoqueCACL = {'amb': null, 'vinte': null};
            _caclId = null;
          });
        }
      } else {
        setState(() {
          _estagioCACL = EstagioCACL.semAbertura;
          _possuiCACL = false;
          _estoqueCACL = {'amb': null, 'vinte': null};
          _caclId = null;
        });
      }
    } catch (e) {
      debugPrint('Erro ao verificar estágio CACL: $e');
      setState(() {
        _estagioCACL = EstagioCACL.semAbertura;
        _possuiCACL = false;
        _estoqueCACL = {'amb': null, 'vinte': null};
        _caclId = null;
      });
    }
  }

  Future<void> _carregarProdutoDoTanque() async {
    try {
      final resp = await _supabase
          .from('tanques')
          .select('produtos (nome)')
          .eq('id', widget.tanqueId)
          .maybeSingle();

      if (resp != null) {
        final produtoObj = resp['produtos'];
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
      await _carregarEstoqueInicialDoBanco();
      await _carregarProdutoDoTanque();

      final dataStr = _dataFiltro.toIso8601String().split('T')[0];

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
              empresa_id,
              empresas(
                nome_dois
              )
            )
          ''')
          .eq('tanque_id', widget.tanqueId)
          .gte('data_mov', '$dataStr 00:00:00')
          .lte('data_mov', '$dataStr 23:59:59');

      final List<Map<String, dynamic>> listaOrdenadaParaUI =
          List<Map<String, dynamic>>.from(dados);

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
          final tipo = (m['tipo_mov']?.toString() ?? '').toUpperCase();
          return cliente.contains('SOBRA') || descricao.contains('SOBRA') || tipo.contains('SOBRA') ||
                 cliente.contains('PERDA') || descricao.contains('PERDA') || tipo.contains('PERDA');
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

        final String cliente = (m['cliente']?.toString().trim() ?? '');
        final String desc = (m['descricao']?.toString().trim() ?? '');
        String descricao = cliente.isNotEmpty ? cliente : desc;

        if (desc.contains("venda comum") || cliente.contains("venda comum") ||
            desc.toLowerCase().contains("venda comum") || cliente.toLowerCase().contains("venda comum")) {
          descricao = "Venda - $descricao";
        }

        String empresaNome = '-';
        final movData = m['movimentacoes'];
        if (movData is Map) {
          final empresaData = movData['empresas'];
          if (empresaData is Map) {
            empresaNome = empresaData['nome_dois']?.toString() ?? '-';
          }
        }

        final String? tipoMovRaw = m['tipo_mov']?.toString();
        final String tipoMov = (tipoMovRaw ?? '').toLowerCase();
        final String descLower = desc.toLowerCase();
        final String clienteLower = cliente.toLowerCase();

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
          'data_mov': m['data_mov'],
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

      _totalEntradas = _movs.fold<num>(0, (s, m) => s + ((m['entrada_vinte'] ?? 0) as num));
      _totalSaidas = _movs.fold<num>(0, (s, m) => s + ((m['saida_vinte'] ?? 0) as num));
      _totalSobraPerda = _movs.fold<num>(0, (s, m) => s + ((m['sobra_perda'] ?? 0) as num));

      _estoqueFinal = {
        'amb': _movs.isEmpty ? (_estoqueInicial['amb'] ?? 0) : _movs.last['saldo_amb'],
        'vinte': _movs.isEmpty ? (_estoqueInicial['vinte'] ?? 0) : _movs.last['saldo_vinte'],
      };

      await _verificarEstagioCACL();

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

    final semCacl = ord.where((m) => !_temCaclIdValido(m)).toList();
    final comCacl = ord.where(_temCaclIdValido).toList();
    final ordenadasParaUI = [...semCacl, ...comCacl];

    setState(() {
      _movsOrdenadas = ordenadasParaUI;
      _coluna = col;
      _asc = asc;
    });
  }

  bool _temCaclIdValido(Map<String, dynamic> mov) {
    final caclId = mov['cacl_id']?.toString().trim();
    return caclId != null &&
        caclId.isNotEmpty &&
        caclId.toLowerCase() != 'null';
  }

  void _onSort(String col) {
    final asc = _coluna == col ? !_asc : true;
    _ordenar(col, asc);
  }

  Future<void> _navegarParaAbertura() async {
    final estoqueFinalCalculado20 = (_estoqueFinal['vinte'] ?? 0).toDouble();
    String? movimentacaoIdReferencia;

    for (int i = _movsOrdenadas.length - 1; i >= 0; i--) {
      final candidate = _movsOrdenadas[i]['movimentacao_id']?.toString();
      if (candidate != null && candidate.isNotEmpty) {
        movimentacaoIdReferencia = candidate;
        break;
      }
    }

    final resultado = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MedicaoTanquesPage(
          onVoltar: () => Navigator.pop(context),
          tanqueSelecionadoId: widget.tanqueId,
          dataReferencia: _dataFiltro,
          caclBloqueadoComoVerificacao: true,
          estoqueFinalCalculado20: estoqueFinalCalculado20,
          movimentacaoIdReferencia: movimentacaoIdReferencia,
        ),
      ),
    );

    if (!mounted) return;

    if (resultado is Map && resultado['status'] == 'cacl_emitido') {
      if (widget.onVoltar != null) {
        widget.onVoltar!();
      } else {
        Navigator.of(context).pop();
      }
      return;
    }

    await _carregar();
  }

  Future<void> _navegarParaFechamento() async {
    if (_caclId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro: CACL não encontrado para fechamento'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final resultado = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EditarCaclPage(
          onVoltar: () => Navigator.pop(context),
          caclId: _caclId!,
          tanqueReferencia: widget.referenciaTanque,
          dataReferencia: _dataFiltro,
        ),
      ),
    );

    if (!mounted) return;

    if (resultado is Map && resultado['status'] == 'cacl_emitido') {
      if (widget.onVoltar != null) {
        widget.onVoltar!();
      } else {
        Navigator.of(context).pop();
      }
      return;
    }

    await _carregar();
  }

  Future<void> _baixarExcel() async {
    if (_movsOrdenadas.isEmpty) {
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
        'tanqueId': widget.tanqueId,
        'referenciaTanque': widget.referenciaTanque,
        'terminalId': _terminalId,
        'terminalNome': _terminalNome,
        'data': _dataFiltro.toIso8601String(),
        'estoqueInicial': _estoqueInicial,
        'estoqueFinal': _estoqueFinal,
        'estoqueCACL': _estoqueCACL,
        'possuiCACL': _possuiCACL,
        'valorSobraPerda': _valorSobraPerda,
        'ehSobra': _ehSobra,
      };

      final response = await _chamarEdgeFunctionBinaria(requestData);

      if (response.statusCode != 200) {
        final errorBody = response.body;
        throw Exception(
          'Erro ${response.statusCode}: ${errorBody.isNotEmpty ? errorBody : "Falha na Edge Function"}',
        );
      }

      final bytes = response.bodyBytes;

      if (bytes.isEmpty) {
        throw Exception('Arquivo vazio recebido da Edge Function');
      }

      final blob = html.Blob([
        bytes,
      ], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);

      final nomeTerminalFormatado = _terminalNome
          ?.replaceAll(' ', '_')
          .replaceAll(RegExp(r'[^\w_]'), '') ?? 'terminal';

      final dia = _dataFiltro.day.toString().padLeft(2, '0');
      final mes = _dataFiltro.month.toString().padLeft(2, '0');
      final ano = _dataFiltro.year.toString();
      final fileName =
          'estoque_tanque_${widget.referenciaTanque}_${nomeTerminalFormatado}_${dia}_${mes}_${ano}.xlsx';

      html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();

      html.Url.revokeObjectUrl(url);

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Download do Excel iniciado! Verifique sua pasta de downloads.',
          ),
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

  Future<http.Response> _chamarEdgeFunctionBinaria(
    Map<String, dynamic> requestData,
  ) async {
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
    Map<String, dynamic> requestData,
  ) async {
    final functionUrl = '$supabaseUrl/functions/v1/down_excel_estoque_tanque';

    debugPrint('URL: $functionUrl');
    debugPrint('Token (início): ${accessToken.substring(0, 20)}...');
    debugPrint('Dados: ${jsonEncode(requestData)}');

    final response = await http.post(
      Uri.parse(functionUrl),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'Accept':
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      },
      body: jsonEncode(requestData),
    );

    return response;
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
              "Movimentação do Tanque – ${widget.referenciaTanque}${_produtoNome != null ? ' - ${_produtoNome!}' : ''}",
            ),
            Text(
              '${_terminalNome ?? 'Carregando...'} | ${_fmtData(_dataFiltro.toIso8601String())}',
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: _buildCampoDataFiltro(),
          ),
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

  Widget _buildCampoDataFiltro() {
    final String textoData =
        '${_dataFiltro.day.toString().padLeft(2, '0')}/${_dataFiltro.month.toString().padLeft(2, '0')}/${_dataFiltro.year}';

    return InkWell(
      onTap: () async {
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
                            const Text('Selecionar data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF0D47A1))),
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
          _carregar();
        }
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF0D47A1).withOpacity(0.5)),
          borderRadius: BorderRadius.circular(4),
          color: Colors.white,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_today,
              size: 14,
              color: Color(0xFF0D47A1),
            ),
            const SizedBox(width: 4),
            Text(
              textoData,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF0D47A1),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConteudo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _cabecalho(),
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
        crossAxisAlignment: WrapCrossAlignment.center,
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
          _buildBotaoPorEstagio(),
        ],
      ),
    );
  }

  Widget _buildBotaoPorEstagio() {
    switch (_estagioCACL) {
      case EstagioCACL.semAbertura:
        return _buildBotaoAcao(
          texto: 'INSERIR MEDIÇÃO DE ABERTURA',
          cor: Colors.green,
          icone: Icons.play_arrow,
          onPressed: _navegarParaAbertura,
        );
        
      case EstagioCACL.aberturaRealizada:
        final bool todasApuracoesRealizadas = _movsOrdenadas.every((m) {
          final num entAmb = (m['entrada_amb'] ?? 0) as num;
          final num entVinte = (m['entrada_vinte'] ?? 0) as num;
          final num saiAmb = (m['saida_amb'] ?? 0) as num;
          final num saiVinte = (m['saida_vinte'] ?? 0) as num;

          if (entAmb != 0 && entVinte == 0) return false;
          if (saiAmb != 0 && saiVinte == 0) return false;
          return true;
        });

        if (!todasApuracoesRealizadas) {
          return Tooltip(
            message: 'Complete apurações pendentes!\nO fechamento do tanque só é permitido com todas as apurações a 20ºC realizadas.',
            preferBelow: false,
            verticalOffset: 30,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            textStyle: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.95),
              borderRadius: BorderRadius.circular(4),
            ),
            child: _buildBotaoAcao(
              texto: 'FECHAR TANQUE',
              cor: Colors.grey.shade300,
              icone: Icons.inventory,
              onPressed: () {}, // Desabilitado
            ),
          );
        }

        return _buildBotaoAcao(
          texto: 'FECHAR TANQUE',
          cor: const Color(0xFF0D47A1),
          icone: Icons.inventory,
          onPressed: _navegarParaFechamento,
        );
        
      case EstagioCACL.fechado:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBotaoAcao({
    required String texto,
    required Color cor,
    required IconData icone,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 250,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: cor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 3,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icone, size: 18),
            const SizedBox(width: 8),
            Text(
              texto,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
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
    return Scrollbar(
      controller: _vertical,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _vertical,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              left: BorderSide(color: Colors.grey.shade300),
              right: BorderSide(color: Colors.grey.shade300),
              bottom: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Column(children: [_corpo(), _rodape()]),
        ),
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
                  'Estoque Inicial do Dia',
                  _estoqueInicial['amb'],
                  _estoqueInicial['vinte'],
                  cor: Colors.blue,
                );
              }
              if (i == _movsOrdenadas.length + 1) {
                num totalEntradaAmb = _movsOrdenadas.fold<num>(0, (s, m) => s + ((m['entrada_amb'] ?? 0) as num));
                num totalEntradaVinte = _movsOrdenadas.fold<num>(0, (s, m) => s + ((m['entrada_vinte'] ?? 0) as num));
                num totalSaidaAmb = _movsOrdenadas.fold<num>(0, (s, m) => s + ((m['saida_amb'] ?? 0) as num));
                num totalSaidaVinte = _movsOrdenadas.fold<num>(0, (s, m) => s + ((m['saida_vinte'] ?? 0) as num));
                num totalSobraPerda = _movsOrdenadas.fold<num>(0, (s, m) => s + ((m['sobra_perda'] ?? 0) as num));

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
                    _cell(e['empresa_nome'] ?? '-', _wEmpresa),
                    _cell(e['descricao'] ?? '-', _wDesc),
                    _cell(_fmtNum(e['entrada_amb']), _wNum, bg: _bgEntrada()),
                    _cell(_fmtNum(e['entrada_vinte']), _wNum, bg: _bgEntrada()),
                    _cell(_fmtNum(e['saida_amb']), _wNum, bg: _bgSaida()),
                    _cell(_fmtNum(e['saida_vinte']), _wNum, bg: _bgSaida()),
                    _cell(
                      _fmtNum(e['sobra_perda']),
                      _wNum,
                      cor: (e['sobra_perda'] ?? 0) < 0
                          ? Colors.red
                          : (e['sobra_perda'] ?? 0) > 0
                              ? Colors.green
                              : null,
                      fw: (e['sobra_perda'] ?? 0) != 0 ? FontWeight.bold : null,
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
        '${_movsOrdenadas.length} movimentação(ões)',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade600,
          fontWeight: FontWeight.w500,
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