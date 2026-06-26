import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_page.dart';
import 'medicoes_emitir_cacl.dart';
import 'cacl_visualizacao.dart';
import 'estoque_tanque_dia.dart';
import 'estoque_tanque_mensal.dart';
import 'medicoes_editar_cacl.dart';
import 'medicoes.dart';
import 'movim_avulsa.dart';

class GerenciamentoTanquesPage extends StatefulWidget {
  final VoidCallback onVoltar;
  final String? terminalSelecionadoId;
  final Function(String terminalId)? onAbrirCACL;

  const GerenciamentoTanquesPage({
    super.key, 
    required this.onVoltar,
    this.terminalSelecionadoId,
    this.onAbrirCACL,
  });

  @override
  State<GerenciamentoTanquesPage> createState() => _GerenciamentoTanquesPageState();
}

class _GerenciamentoTanquesPageState extends State<GerenciamentoTanquesPage> {
  static const Color _ink = Color(0xFF0E1C2F);
  static const Color _accent = Color(0xFF1B6A6F);
  static const Color _line = Color(0xFFE6DCCB);
  static const Color _muted = Color(0xFF5A6B7A);
  static const Color _warn = Color(0xFFC17D2D);

  List<Map<String, dynamic>> tanques = [];
  List<Map<String, dynamic>> produtos = [];
  bool _carregando = true;
  bool _editando = false;
  bool _mostrandoCardsAcoes = false;
  Map<String, dynamic>? _tanqueEditando;
  Map<String, dynamic>? _tanqueSelecionadoParaAcoes;
  String? _nomeTerminal;
  bool _carregandoCacls = false;
  bool _mostrandoMedicoes = false;
  List<Map<String, dynamic>> _caclesTanque = [];
  int? _hoverCaclIndex;

  bool _exaSelecionado = false;
  bool _lctSelecionado = false;

  final List<String> _statusOptions = ['Em operação', 'Operação suspensa'];
  
  final TextEditingController _referenciaController = TextEditingController();
  final TextEditingController _capacidadeController = TextEditingController();
  final TextEditingController _lastroController = TextEditingController();
  String? _produtoSelecionado;
  String? _statusSelecionado;

  bool _houveAlteracao() {
    if (_tanqueEditando == null) {
      return _referenciaController.text.isNotEmpty ||
          _capacidadeController.text.isNotEmpty ||
          _produtoSelecionado != null ||
          _statusSelecionado != null ||
          _lastroController.text.isNotEmpty;
    }

    final refOriginal = _tanqueEditando!['referencia']?.toString() ?? '';
    final capOriginal = _formatarMilhar(_tanqueEditando!['capacidade']);
    final prodOriginal = _tanqueEditando!['produto_id']?.toString();
    final statusOriginal = _tanqueEditando!['status']?.toString();
    final lastroOriginal = _formatarMilhar(_tanqueEditando!['lastro']);

    final tipoOriginal = _tanqueEditando!['tipo_abastecimento']?.toString() ?? '';
    final exaOriginal = tipoOriginal.contains('exa') || tipoOriginal == 'all';
    final lctOriginal = tipoOriginal.contains('lct') || tipoOriginal == 'all';

    return _referenciaController.text != refOriginal ||
        _capacidadeController.text != capOriginal ||
        _produtoSelecionado != prodOriginal ||
        _statusSelecionado != statusOriginal ||
        _lastroController.text != lastroOriginal ||
        _exaSelecionado != exaOriginal ||
        _lctSelecionado != lctOriginal;
  }

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  int _extrairNumeroTanque(String referencia) {
    final match = RegExp(r'TQ[^0-9]*([0-9]+)', caseSensitive: false).firstMatch(referencia);
    if (match == null) {
      return 0;
    }
    return int.tryParse(match.group(1) ?? '') ?? 0;
  }

  void _mostrarAviso(String mensagem, {bool erro = true}) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(erro ? 'Atenção' : 'Sucesso', style: TextStyle(color: _ink)),
          content: Text(mensagem),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _carregarDados() async {
    try {
      final supabase = Supabase.instance.client;
      final usuario = UsuarioAtual.instance!;

      final produtosResponse = await supabase
          .from('produtos')
          .select('id, nome, nome_dois, posicao, grupo')
          .eq('lista_transf', true);
      
      var listaProdutos = List<Map<String, dynamic>>.from(produtosResponse);
      
      listaProdutos.sort((a, b) {
        final valA = a['posicao'];
        final valB = b['posicao'];
        
        double posA;
        if (valA is num) {
          posA = valA.toDouble();
        } else {
          posA = double.tryParse(valA?.toString() ?? '') ?? 999.0;
        }

        double posB;
        if (valB is num) {
          posB = valB.toDouble();
        } else {
          posB = double.tryParse(valB?.toString() ?? '') ?? 999.0;
        }
        
        return posA.compareTo(posB);
      });

      setState(() {
        produtos = listaProdutos;
      });

      String? terminalId;
      String? nomeTerminal;

      if (widget.terminalSelecionadoId != null) {
        terminalId = widget.terminalSelecionadoId!;
        try {
          final terminalCheck = await supabase
              .from('terminais')
              .select('id, nome')
              .eq('id', widget.terminalSelecionadoId!)
              .maybeSingle();
          if (terminalCheck != null) {
            nomeTerminal = terminalCheck['nome']?.toString();
          }
        } catch (_) {
          nomeTerminal = null;
        }
      }
      else if (usuario.terminalId != null) {
        terminalId = usuario.terminalId;
        
        try {
          final terminalData = await supabase
              .from('terminais')
              .select('nome')
              .eq('id', usuario.terminalId!)
              .maybeSingle();
          if (terminalData != null) {
            nomeTerminal = terminalData['nome'];
          }
        } catch (_) {
          nomeTerminal = null;
        }
      }

      if (terminalId == null) {
        print("ERRO: Não foi possível determinar o terminal para buscar tanques");
        setState(() {
          _carregando = false;
          tanques = [];
          _nomeTerminal = null;
        });
        return;
      }

      final query = supabase
          .from('tanques')
          .select('''
            id,
            referencia,
            capacidade,
            lastro,
            status,
            produto_id,
            tipo_abastecimento,
            produtos (nome),
            terminais!inner (nome)
          ''')
          .eq('terminal_id', terminalId)
          .order('referencia');

      final tanquesResponse = await query;

      final List<Map<String, dynamic>> tanquesFormatados = [];
      
      for (final tanque in tanquesResponse) {
        tanquesFormatados.add({
          'id': tanque['id'],
          'referencia': tanque['referencia']?.toString() ?? 'SEM REFERÊNCIA',
          'produto': tanque['produtos']?['nome']?.toString() ?? 'PRODUTO NÃO INFORMADO',
          'capacidade': tanque['capacidade']?.toString() ?? '0',
          'lastro': tanque['lastro']?.toString(),
          'status': tanque['status']?.toString() ?? 'Em operação',
          'produto_id': tanque['produto_id'],
          'tipo_abastecimento': tanque['tipo_abastecimento'],
          'terminal_nome': tanque['terminais']?['nome']?.toString() ?? nomeTerminal,
        });
      }

      tanquesFormatados.sort((a, b) {
        final numA = _extrairNumeroTanque(a['referencia']?.toString() ?? '');
        final numB = _extrairNumeroTanque(b['referencia']?.toString() ?? '');
        if (numA != numB) {
          return numA.compareTo(numB);
        }
        return (a['referencia']?.toString() ?? '').compareTo(b['referencia']?.toString() ?? '');
      });

      setState(() {
        tanques = tanquesFormatados;
        _carregando = false;
        _nomeTerminal = nomeTerminal;
      });
    } catch (e) {
      setState(() {
        _carregando = false;
        _nomeTerminal = null;
      });
      print('Erro ao carregar dados: $e');
    }
  }

  void _editarTanque(Map<String, dynamic> tanque) {
    setState(() {
      _editando = true;
      _tanqueEditando = tanque;
      _referenciaController.text = tanque['referencia'];
      
      final capacidade = tanque['capacidade'];
      if (capacidade != null && capacidade.isNotEmpty) {
        _capacidadeController.text = _formatarMilhar(capacidade);
      } else {
        _capacidadeController.clear();
      }
      
      _produtoSelecionado = tanque['produto_id']?.toString();
      _statusSelecionado = tanque['status'];
      _lastroController.text = _formatarMilhar(tanque['lastro']);
      
      final tipo = tanque['tipo_abastecimento']?.toString() ?? '';
      _exaSelecionado = tipo.contains('exa') || tipo == 'all';
      _lctSelecionado = tipo.contains('lct') || tipo == 'all';
    });
  }

  void _cancelarEdicao() {
    setState(() {
      _editando = false;
      _tanqueEditando = null;
      _referenciaController.clear();
      _capacidadeController.clear();
      _lastroController.clear();
      _produtoSelecionado = null;
      _statusSelecionado = null;
      _exaSelecionado = false;
      _lctSelecionado = false;
      _mostrandoCardsAcoes = true;
    });
  }

  void _mostrarCardsAcoesDoTanque(Map<String, dynamic> tanque) {
    setState(() {
      _mostrandoCardsAcoes = true;
      _tanqueSelecionadoParaAcoes = tanque;
    });
    final tanqueId = tanque['id']?.toString();
    if (tanqueId != null && tanqueId.isNotEmpty) {
      _carregarCaclsDoTanque(tanqueId);
    }
  }

  Future<void> _carregarCaclsDoTanque(String tanqueId) async {
    setState(() {
      _carregandoCacls = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final hoje = DateTime.now();
      final inicioDoDia = DateTime(hoje.year, hoje.month, hoje.day);
      final fimDoDia = DateTime(hoje.year, hoje.month, hoje.day, 23, 59, 59);

      final response = await supabase
          .from('cacl')
          .select('''
            id,
            data,
            tanque_id,
            status,
            horario_inicial,
            horario_final,
            tanques:tanque_id (referencia),
            produto_id,
            produtos:produto_id (nome),
            terminal_id,
            terminais:terminal_id (nome)
          ''')
          .eq('tanque_id', tanqueId)
          .order('data', ascending: false)
          .order('created_at', ascending: false);

      if (mounted) {
        final caclesFiltrados = List<Map<String, dynamic>>.from(response).where((cacl) {
          final status = cacl['status']?.toString().toLowerCase();
          final dataCacl = cacl['data'] != null 
              ? DateTime.parse(cacl['data'].toString())
              : null;
          
          if (status == 'pendente') {
            return true;
          }
          
          if (dataCacl != null) {
            return !dataCacl.isBefore(inicioDoDia) && !dataCacl.isAfter(fimDoDia);
          }
          
          return false;
        }).toList();

        setState(() {
          _caclesTanque = caclesFiltrados;
        });
      }
    } catch (e) {
      if (mounted) {
        _mostrarAviso('Erro ao carregar CACLs: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _carregandoCacls = false;
        });
      }
    }
  }

  Future<void> _cancelarCacl(String caclId) async {
    try {
      final supabase = Supabase.instance.client;

      final movimentacaoExistente = await supabase
          .from('movimentacoes_tanque')
          .select('id')
          .eq('cacl_id', caclId)
          .maybeSingle();

      if (movimentacaoExistente != null) {
        await supabase
            .from('movimentacoes_tanque')
            .delete()
            .eq('cacl_id', caclId);
      }

      await supabase
          .from('cacl')
          .update({'status': 'cancelado'}).eq('id', caclId);

      if (mounted) {
        _showDialogSucessoCancelamento();
        final tanqueId = _tanqueSelecionadoParaAcoes?['id']?.toString();
        if (tanqueId != null && tanqueId.isNotEmpty) {
          await _carregarCaclsDoTanque(tanqueId);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao cancelar CACL: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showDialogSucessoCancelamento() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: _accent, width: 1),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline,
                      color: Colors.green, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'CACL cancelado com sucesso.',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('OK'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDialogConfirmarCancelamento(Map<String, dynamic> cacl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: _accent, width: 1),
          ),
          elevation: 8,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 400,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.red.shade700,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Confirmar Cancelamento',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: _ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Tem certeza que quer cancelar o CACL já emitido?\n\n'
                    'Esta ação também removerá todas as movimentações de tanque associadas a este CACL.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Voltar',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color.fromARGB(255, 102, 102, 102),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _cancelarCacl(cacl['id'].toString());
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'Sim, cancelar.',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatarInicio(dynamic data, dynamic horarioInicial) {
    if (data == null) return 'Início: -';

    try {
      final d = DateTime.parse(data.toString());

      final dataFmt =
          '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

      String horaFmt = '';
      if (horarioInicial != null) {
        final h = horarioInicial.toString();
        if (h.contains('T')) {
          final dh = DateTime.parse(h);
          horaFmt =
              '${dh.hour.toString().padLeft(2, '0')}:${dh.minute.toString().padLeft(2, '0')}';
        } else {
          horaFmt = h.substring(0, 5);
        }
      } else {
        horaFmt =
            '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
      }

      return 'Início: $dataFmt, $horaFmt h';
    } catch (_) {
      return 'Início: -';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'emitido':
        return Colors.green;
      case 'pendente':
      case 'aguardando':
        return Colors.orange;
      case 'cancelado':
        return const Color.fromARGB(255, 192, 43, 43);
      default:
        return const Color.fromARGB(255, 128, 128, 128);
    }
  }

  Color _getCardColor(String? status) {
    if (status?.toLowerCase() == 'cancelado') {
      return Colors.grey.shade50;
    }

    switch (status?.toLowerCase()) {
      case 'emitido':
        return Colors.green.shade50;
      case 'pendente':
      case 'aguardando':
        return Colors.orange.shade50;
      case 'cancelado':
        return Colors.grey.shade50;
      default:
        return Colors.grey.shade50;
    }
  }

  Color _getBorderColor(String? status) {
    if (status?.toLowerCase() == 'cancelado') {
      return Colors.grey.shade300;
    }

    switch (status?.toLowerCase()) {
      case 'emitido':
        return Colors.green.shade300;
      case 'pendente':
      case 'aguardando':
        return Colors.orange.shade300;
      case 'cancelado':
        return Colors.grey.shade300;
      default:
        return Colors.grey.shade300;
    }
  }

  String _getStatusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'emitido':
        return 'Emitido';
      case 'pendente':
      case 'aguardando':
        return 'Pendente';
      case 'cancelado':
        return 'Cancelado';
      default:
        return 'Sem status';
    }
  }

  Future<void> _abrirCACL() async {
    final tanqueId = _tanqueSelecionadoParaAcoes?['id']?.toString();
    bool caclFinalizado = false;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MedicaoTanquesPage(
          onVoltar: () => Navigator.pop(context),
          tanqueSelecionadoId: tanqueId,
          caclBloqueadoComoMovimentacao: true,
          onFinalizarCACL: () {
            caclFinalizado = true;
          },
        ),
      ),
    );

    if (!mounted) return;

    if (caclFinalizado) {
      await _carregarDados();
    }
    
    if (tanqueId != null && tanqueId.isNotEmpty) {
      await _carregarCaclsDoTanque(tanqueId);
    }
  }

  Future<void> _abrirCACLVerificacao() async {
    final tanqueId = _tanqueSelecionadoParaAcoes?['id']?.toString();
    if (tanqueId == null) return;

    setState(() => _carregandoCacls = true);

    try {
      final supabase = Supabase.instance.client;
      final hoje = DateTime.now();
      final dataStr = hoje.toIso8601String().split('T')[0];

      final responseEstoque = await supabase.rpc(
        'fn_estoque_inicial_tanque',
        params: {
          'p_tanque_id': tanqueId,
          'p_data': dataStr,
        },
      );
      
      num estoqueInicial = 0;
      if (responseEstoque is Map) {
        estoqueInicial = (responseEstoque['estoque_inicial'] ?? 0) as num;
      } else {
        estoqueInicial = (responseEstoque ?? 0) as num;
      }

      final dadosMovs = await supabase
          .from('movimentacoes_tanque')
          .select('entrada_vinte, saida_vinte, movimentacao_id, data_mov, cliente, descricao')
          .eq('tanque_id', tanqueId)
          .gte('data_mov', '$dataStr 00:00:00')
          .lte('data_mov', '$dataStr 23:59:59');

      final List<Map<String, dynamic>> movs = List<Map<String, dynamic>>.from(dadosMovs);
      
      movs.sort((a, b) {
        final da = DateTime.parse(a['data_mov'].toString());
        final db = DateTime.parse(b['data_mov'].toString());
        final dataA = DateTime(da.year, da.month, da.day);
        final dataB = DateTime(db.year, db.month, db.day);
        final cmpData = dataA.compareTo(dataB);
        if (cmpData != 0) return cmpData;
        return da.compareTo(db);
      });

      num saldoVinte = estoqueInicial;
      String? lastMovId;

      for (final m in movs) {
        final num entradaVinte = (m['entrada_vinte'] ?? 0) as num;
        final num saidaVinte = (m['saida_vinte'] ?? 0) as num;

        saldoVinte += entradaVinte - saidaVinte;

        final mid = m['movimentacao_id']?.toString();
        if (mid != null && mid.isNotEmpty && mid.toLowerCase() != 'null') {
          lastMovId = mid;
        }
      }

      if (!mounted) return;

      bool caclFinalizado = false;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MedicaoTanquesPage(
            onVoltar: () => Navigator.pop(context),
            tanqueSelecionadoId: tanqueId,
            dataReferencia: hoje,
            caclBloqueadoComoVerificacao: true,
            estoqueFinalCalculado20: saldoVinte.toDouble(),
            movimentacaoIdReferencia: lastMovId,
            onFinalizarCACL: () {
              caclFinalizado = true;
            },
          ),
        ),
      );

      if (!mounted) return;
      if (caclFinalizado) await _carregarDados();
      await _carregarCaclsDoTanque(tanqueId);

    } catch (e) {
      if (mounted) {
        _mostrarAviso('Erro ao preparar CACL Verificação: $e');
      }
    } finally {
      if (mounted) setState(() => _carregandoCacls = false);
    }
  }

  void _abrirEdicaoTanque() {
    if (_tanqueSelecionadoParaAcoes != null) {
      final tanqueId = _tanqueSelecionadoParaAcoes?['id'];
      final tanqueAtualizado = tanques.firstWhere(
        (t) => t['id'] == tanqueId,
        orElse: () => _tanqueSelecionadoParaAcoes!,
      );
      _editarTanque(tanqueAtualizado);
      setState(() {
        _mostrandoCardsAcoes = false;
      });
    }
  }

  void _abrirEstoqueTanque() {
    final usuario = UsuarioAtual.instance;
    final tanqueId = _tanqueSelecionadoParaAcoes?['id']?.toString();
    final referencia = _tanqueSelecionadoParaAcoes?['referencia']?.toString();

    if (usuario == null || tanqueId == null || tanqueId.isEmpty) {
      return;
    }

    final terminalId = _tanqueSelecionadoParaAcoes?['id_terminal']?.toString() ?? 
                     widget.terminalSelecionadoId ?? 
                     usuario.terminalId;
    if (terminalId == null || terminalId.isEmpty) {
      return;
    }

    final nomeTerminal = _tanqueSelecionadoParaAcoes?['terminal_nome']?.toString() ??
        _nomeTerminal ??
        '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SelecaoTipoVisualizacaoBottomSheet(
        tanqueId: tanqueId,
        referenciaTanque: referencia ?? 'Tanque',
        terminalId: terminalId,
        nomeTerminal: nomeTerminal,
        onVoltar: () {
          setState(() {
          });
          _carregarDados();
          if (tanqueId.isNotEmpty) {
            _carregarCaclsDoTanque(tanqueId);
          }
        },
      ),
    );
  }
  
  void _aplicarMascaraCapacidade(String valor) {
    final digitsOnly = valor.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isEmpty) {
      _capacidadeController.clear();
      setState(() {});
      return;
    }
    final novoTexto = _formatarMilhar(digitsOnly);
    if (_capacidadeController.text != novoTexto) {
      _capacidadeController.text = novoTexto;
      _capacidadeController.selection = TextSelection.fromPosition(
        TextPosition(offset: novoTexto.length),
      );
    }
    setState(() {});
  }

  void _aplicarMascaraLastro(String valor) {
    final digitsOnly = valor.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isEmpty) {
      _lastroController.clear();
      setState(() {});
      return;
    }

    final novoTexto = _formatarMilhar(digitsOnly);
    if (_lastroController.text != novoTexto) {
      _lastroController.text = novoTexto;
      _lastroController.selection = TextSelection.fromPosition(
        TextPosition(offset: novoTexto.length),
      );
    }
    setState(() {});
  }

  Future<void> _salvarTanque() async {
    final capacidadeTexto = _capacidadeController.text.trim();
    final valorNumerico = int.tryParse(capacidadeTexto.replaceAll('.', '')) ?? 0;
    final lastroTexto = _lastroController.text.trim();
    final lastroValor = lastroTexto.isEmpty
      ? null
      : int.tryParse(lastroTexto.replaceAll('.', ''));
    
    if (valorNumerico < 1000) {
      if (mounted) {
        _mostrarAviso('A capacidade deve ser de no mínimo 1.000 litros');
      }
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      final usuario = UsuarioAtual.instance!;
      
      String? idTerminal;
      if (usuario.nivel == 3) {
        idTerminal = widget.terminalSelecionadoId;
      } else {
        idTerminal = usuario.terminalId;
      }

      if (idTerminal == null) {
        if (mounted) {
          _mostrarAviso('Erro: Não foi possível determinar o terminal');
        }
        return;
      }

      if (_tanqueEditando != null) {
        final tanqueId = _tanqueEditando!['id'];
        final produtoOriginal = _tanqueEditando!['produto_id']?.toString();
        final produtoNovo = _produtoSelecionado?.toString();
        final produtoAlterado = produtoOriginal != produtoNovo;

        if (produtoAlterado) {
          final caclPendente = await supabase
              .from('cacl')
              .select('id')
              .eq('tanque_id', tanqueId)
              .eq('status', 'pendente')
              .limit(1);

          if (caclPendente.isNotEmpty) {
            if (mounted) {
              _mostrarAviso(
                  'Não é possível alterar o produto: existe um CACL pendente para este tanque.');

              setState(() {
                _produtoSelecionado = produtoOriginal;
              });
            }
            return;
          }

          final agora = DateTime.now();
          final inicioMes = DateTime(agora.year, agora.month, 1);
          final fimMes = DateTime(agora.year, agora.month + 1, 0, 23, 59, 59);
          final dataRefStr = inicioMes.toIso8601String().split('T')[0];

          num estoqueInicial = 0;
          try {
            final responseEstoque = await supabase.rpc(
              'fn_estoque_inicial_mes_tanque',
              params: {
                'p_tanque_id': tanqueId,
                'p_data': dataRefStr,
              },
            );
            estoqueInicial = (responseEstoque['estoque_inicial'] ?? 0) as num;
          } catch (_) {
            estoqueInicial = 0;
          }

          final movimentacoes = await supabase
              .from('movimentacoes_tanque')
              .select('entrada_vinte, saida_vinte, tipo_mov, descricao, cliente')
              .eq('tanque_id', tanqueId)
              .gte('data_mov', inicioMes.toIso8601String())
              .lte('data_mov', fimMes.toIso8601String());

          num totalEntradas = 0;
          num totalSaidas = 0;
          num totalSobraPerda = 0;

          for (final mov in movimentacoes) {
            final num entradaVinte = (mov['entrada_vinte'] ?? 0) as num;
            final num saidaVinte = (mov['saida_vinte'] ?? 0) as num;
            final String tipo =
                (mov['tipo_mov']?.toString() ?? '').toLowerCase();
            final String desc =
                (mov['descricao']?.toString() ?? '').toLowerCase();
            final String cli = (mov['cliente']?.toString() ?? '').toLowerCase();

            final bool eSobra = tipo.contains('sobra') ||
                desc.contains('sobra') ||
                cli.contains('sobra');
            final bool ePerda = tipo.contains('perda') ||
                desc.contains('perda') ||
                cli.contains('perda');

            if (eSobra) {
              totalSobraPerda += entradaVinte;
            } else if (ePerda) {
              totalSobraPerda -= saidaVinte;
            } else {
              totalEntradas += entradaVinte;
              totalSaidas += saidaVinte;
            }
          }

          final saldoFinal =
              estoqueInicial + totalEntradas - totalSaidas + totalSobraPerda;

          if (saldoFinal > 0) {
            if (mounted) {
              _mostrarAviso(
                  'Não é possível alterar o produto. O tanque ainda possui estoque residual.');

              setState(() {
                _produtoSelecionado = produtoOriginal;
              });
            }
            return;
          }
        }
      }

      String tipoAbastecimento = '';
      if (_exaSelecionado && _lctSelecionado) {
        tipoAbastecimento = 'all';
      } else if (_exaSelecionado) {
        tipoAbastecimento = 'exa';
      } else if (_lctSelecionado) {
        tipoAbastecimento = 'lct';
      }

      final Map<String, dynamic> dadosAtualizados = {
        'referencia': _referenciaController.text.trim(),
        'capacidade': capacidadeTexto.replaceAll('.', ''),
        'lastro': lastroValor,
        'status': _statusSelecionado,
        'produto_id': _produtoSelecionado,
        'tipo_abastecimento': tipoAbastecimento.isEmpty ? null : tipoAbastecimento,
        'terminal_id': idTerminal,
      };

      if (_tanqueEditando != null) {
        await supabase
            .from('tanques')
            .update(dadosAtualizados)
            .eq('id', _tanqueEditando!['id']);
      }

      await _carregarDados();

      if (_tanqueEditando != null && _tanqueSelecionadoParaAcoes != null) {
        final idEditado = _tanqueEditando!['id'];
        final tanqueAtualizado = tanques.firstWhere(
          (t) => t['id'] == idEditado,
          orElse: () => _tanqueSelecionadoParaAcoes!,
        );
        setState(() {
          _tanqueSelecionadoParaAcoes = tanqueAtualizado;
        });
      }

      if (mounted) {
        final String referencia = _referenciaController.text.trim();
        final String acao = _tanqueEditando != null ? 'editado' : 'criado';
        
        _mostrarAviso('Tanque $referencia $acao com sucesso!', erro: false);
      }

      _cancelarEdicao();
    } catch (e) {
      if (mounted) {
        _mostrarAviso('Erro ao salvar tanque: $e');
      }
    }
  }

  @override
  void dispose() {
    _referenciaController.dispose();
    _capacidadeController.dispose();
    _lastroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.escape): const _UnfocusIntent(),
      },
      child: Actions(
        actions: {
          _UnfocusIntent: CallbackAction<_UnfocusIntent>(
            onInvoke: (intent) {
              FocusManager.instance.primaryFocus?.unfocus();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: Colors.white,
            body: Column(
              children: [
                if (!_mostrandoMedicoes)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(bottom: BorderSide(color: _line, width: 1)),
                    ),
                    child: Row(children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: _ink),
                        onPressed: _editando 
                            ? _cancelarEdicao 
                            : (_mostrandoCardsAcoes 
                                ? () => setState(() => _mostrandoCardsAcoes = false) 
                            : widget.onVoltar),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _editando 
                                  ? 'Editar Tanque' 
                                  : (_mostrandoCardsAcoes 
                                      ? 'Ações do Tanque' 
                                      : 'Gerenciamento de Tanques'),
                              style: const TextStyle(
                                fontSize: 19, 
                                fontWeight: FontWeight.bold, 
                                color: _ink
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!_editando && !_mostrandoCardsAcoes)
                        IconButton(
                          icon: const Icon(Icons.refresh, color: _ink),
                          onPressed: _carregarDados,
                          tooltip: 'Recarregar',
                        ),
                    ]),
                  ),

                Expanded(
                  child: _editando 
                      ? _buildFormularioEdicao()
                      : (_mostrandoMedicoes
                          ? MedicoesPage(
                              onVoltar: () => setState(() => _mostrandoMedicoes = false),
                              produtoNome: _tanqueSelecionadoParaAcoes != null 
                                  ? _tanqueSelecionadoParaAcoes!['produto'] 
                                  : null,
                              tanqueReferencia: _tanqueSelecionadoParaAcoes != null
                                  ? _tanqueSelecionadoParaAcoes!['referencia']
                                  : null,
                            )
                          : (_mostrandoCardsAcoes ? _buildCardsAcoesDoTanque() : _buildListaTanques())),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListaTanques() {
    if (_carregando) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _accent),
            SizedBox(height: 16),
            Text('Carregando tanques...', style: TextStyle(fontSize: 16, color: _ink)),
          ],
        ),
      );
    }

    if (tanques.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.storage, size: 64, color: _muted),
            const SizedBox(height: 16),
            Text(
              'Nenhum tanque encontrado',
              style: const TextStyle(fontSize: 16, color: _ink),
            ),
            const SizedBox(height: 8),
            Text(
              widget.terminalSelecionadoId != null && UsuarioAtual.instance!.nivel == 3
                ? 'Não há tanques cadastrados para este terminal'
                : 'Não há tanques cadastrados',
              style: const TextStyle(fontSize: 14, color: _muted),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(60, 18, 60, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _line, width: 1.2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildEstatisticaCompacta('Total', tanques.length.toString(), Icons.storage),
                Container(height: 36, width: 1.2, color: _line),
                _buildEstatisticaCompacta(
                  'Em operacao',
                  tanques.where((t) => t['status'] == 'Em operação').length.toString(),
                  Icons.check_circle,
                ),
                Container(height: 36, width: 1.2, color: _line),
                _buildEstatisticaCompacta(
                  'Suspensos',
                  tanques.where((t) => t['status'] == 'Operação suspensa').length.toString(),
                  Icons.pause_circle,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = constraints.maxWidth;
                // desired approximate card width (reduced to fit more cards per row)
                const desiredCardWidth = 180.0;
                int crossAxisCount = (maxWidth / desiredCardWidth).floor();
                if (crossAxisCount < 1) crossAxisCount = 1;
                if (crossAxisCount > 6) crossAxisCount = 6;

                final spacing = 12.0;
                final usableWidth = maxWidth - (spacing * (crossAxisCount - 1));
                final cardWidth = usableWidth / crossAxisCount;
                // approximate height for card based on content
                final cardHeight = 130.0;
                final childAspectRatio = cardWidth / cardHeight;

                return GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: spacing,
                    childAspectRatio: childAspectRatio,
                  ),
                  itemCount: tanques.length,
                  itemBuilder: (context, index) {
                    final tanque = tanques[index];
                    final isOperando = tanque['status'] == 'Em operação';
                    final statusColor = isOperando ? _accent : _warn;

                    return _TanqueCard(
                      tanque: tanque,
                      statusColor: statusColor,
                      onTap: () => _mostrarCardsAcoesDoTanque(tanque),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEstatisticaCompacta(String titulo, String valor, IconData icone) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 16, color: _accent),
            const SizedBox(width: 4),
            Text(
              valor,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          titulo,
          style: const TextStyle(fontSize: 11, color: _muted),
        ),
      ],
    );
  }

  Widget _buildFormularioEdicao() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _line, width: 1.2),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 700;
                    final fieldWidth = isWide
                        ? (constraints.maxWidth - 16) / 2
                        : constraints.maxWidth;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.tune, color: _accent),
                            SizedBox(width: 8),
                            Text(
                              'Editar Tanque',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _ink,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Atualize os dados operacionais do tanque.',
                          style: TextStyle(fontSize: 12, color: _muted),
                        ),
                        const SizedBox(height: 18),

                        if (_nomeTerminal != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _accent.withValues(alpha: 0.6), width: 1.2),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.business, size: 16, color: _accent),
                                const SizedBox(width: 8),
                                Text(
                                  'Terminal: $_nomeTerminal',
                                  style: const TextStyle(
                                    color: _accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        if (_nomeTerminal != null) const SizedBox(height: 18),

                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            SizedBox(
                              width: fieldWidth,
                              child: TextFormField(
                                controller: _referenciaController,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: 'Referência *',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.tag, color: _accent),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: fieldWidth,
                              child: TextFormField(
                                controller: _capacidadeController,
                                decoration: const InputDecoration(
                                  labelText: 'Capacidade *',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.analytics, color: _accent),
                                  suffixText: 'Litros',
                                  hintText: '1.000',
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: _aplicarMascaraCapacidade,
                              ),
                            ),
                            SizedBox(
                              width: fieldWidth,
                              child: TextFormField(
                                controller: _lastroController,
                                decoration: const InputDecoration(
                                  labelText: 'Lastro',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.opacity, color: _accent),
                                  suffixText: 'Litros',
                                  hintText: '999.999',
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: _aplicarMascaraLastro,
                              ),
                            ),
                            SizedBox(
                              width: fieldWidth,
                              child: DropdownButtonFormField<String>(
                                value: _produtoSelecionado,
                                dropdownColor: Colors.white,
                                decoration: const InputDecoration(
                                  labelText: 'Produto *',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.local_gas_station, color: _accent),
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('Selecione um produto'),
                                  ),
                                  ...produtos.map((produto) {
                                    final grupo = produto['grupo']?.toString();
                                    final isEspecial = grupo == '2' || grupo == '3';

                                    return DropdownMenuItem(
                                      value: produto['id']?.toString(),
                                      child: Container(
                                        height: 32,
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: isEspecial ? const Color.fromARGB(255, 255, 195, 195) : null,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          produto['nome_dois']?.toString() ?? produto['nome']?.toString() ?? '',
                                          style: const TextStyle(fontSize: 13),
                                          overflow: TextOverflow.visible,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _produtoSelecionado = value;
                                  });
                                },
                              ),
                            ),
                            SizedBox(
                              width: fieldWidth,
                              child: DropdownButtonFormField<String>(
                                value: _statusSelecionado,
                                dropdownColor: Colors.white,
                                decoration: const InputDecoration(
                                  labelText: 'Status *',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.info, color: _accent),
                                ),
                                items: _statusOptions.map((status) {
                                  return DropdownMenuItem(
                                    value: status,
                                    child: Text(status),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _statusSelecionado = value;
                                  });
                                },
                              ),
                            ),
                            SizedBox(
                              width: fieldWidth,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Tipo de abastecimento:',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: _ink,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: _exaSelecionado,
                                        activeColor: _accent,
                                        onChanged: (value) {
                                          setState(() {
                                            _exaSelecionado = value ?? false;
                                          });
                                        },
                                      ),
                                      const Text('EXA', style: TextStyle(color: _ink)),
                                      const SizedBox(width: 20),
                                      Checkbox(
                                        value: _lctSelecionado,
                                        activeColor: _accent,
                                        onChanged: (value) {
                                          setState(() {
                                            _lctSelecionado = value ?? false;
                                          });
                                        },
                                      ),
                                      const Text('LCT', style: TextStyle(color: _ink)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            SizedBox(
                              width: 140,
                              height: 44,
                              child: OutlinedButton(
                                onPressed: _cancelarEdicao,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  side: const BorderSide(color: _accent, width: 1.4),
                                  foregroundColor: _accent,
                                ),
                                child: const Text('Voltar'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 140,
                              height: 44,
                              child: ElevatedButton(
                                onPressed: _houveAlteracao() ? _salvarTanque : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _houveAlteracao() ? _ink : Colors.grey.shade300,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  foregroundColor: _houveAlteracao() ? Colors.white : Colors.grey.shade500,
                                ),
                                child: const Text('Salvar'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardsAcoesDoTanque() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(60, 18, 60, 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_tanqueSelecionadoParaAcoes != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _line, width: 1.2),
                    ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _accent.withValues(alpha: 0.2)),
                      ),
                      child: const Icon(Icons.storage, color: _accent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _tanqueSelecionadoParaAcoes!['referencia'] ?? 'Tanque',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _tanqueSelecionadoParaAcoes!['produto'] ?? 'Produto',
                            style: TextStyle(fontSize: 12, color: _accent),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  int crossAxisCount = (constraints.maxWidth / 175).floor();
                  if (crossAxisCount < 1) crossAxisCount = 1;
                  if (crossAxisCount > 6) crossAxisCount = 6;

                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 175 / 160,
                    children: [
                      _buildCardAcao(
                        icon: Icons.inventory_2,
                        titulo: 'Movimentação do tanque',
                        descricao: 'Consultar movimentação',
                        onTap: _abrirEstoqueTanque,
                      ),
                      _buildCardAcao(
                        icon: Icons.list_alt,
                        titulo: 'Medições',
                        descricao: 'Consultar medições realizadas',
                        onTap: () => setState(() => _mostrandoMedicoes = true),
                      ),
                      Builder(
                        builder: (context) {
                          final tanqueAtual = tanques.firstWhere(
                            (t) => t['id'] == _tanqueSelecionadoParaAcoes!['id'],
                            orElse: () => _tanqueSelecionadoParaAcoes!,
                          );
                          final tipo = tanqueAtual['tipo_abastecimento']?.toString() ?? '';
                          final disponivelParaTipo = tipo == 'all' || tipo == 'exa';
                          
                          return _buildCardAcao(
                            icon: Icons.analytics,
                            titulo: 'CACL Movimentação',
                            descricao: 'Emitir CACL Movimentação',
                            onTap: _abrirCACL,
                            enabled: disponivelParaTipo,
                            tooltip: !disponivelParaTipo 
                                ? 'Disponível apenas para tanques com tipo EXA.' 
                                : null,
                          );
                        }
                      ),
                      _buildCardAcao(
                        icon: Icons.check_circle,
                        titulo: 'CACL verificação',
                        descricao: 'Emitir CACL Verificação',
                        onTap: _abrirCACLVerificacao,
                        enabled: _caclesTanque.isEmpty && !_carregandoCacls,
                        tooltip: 'Já existe CACL para a data atual.',
                      ),
                      _buildCardAcao(
                        icon: Icons.add_chart,
                        titulo: 'Entrada/Saída manual',
                        descricao: 'Registrar entrada ou saída manual',
                        onTap: _showDialogMovimentacaoAvulsa,
                      ),
                      _buildCardAcao(
                        icon: Icons.settings,
                        titulo: 'Ajustes',
                        descricao: 'Atualizar dados do tanque',
                        onTap: _abrirEdicaoTanque,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _line, width: 1.2),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long_outlined, size: 18, color: _accent),
                    const SizedBox(width: 8),
                    const Text(
                      'CACLs da data atual ou pendentes:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 18, color: _accent),
                      onPressed: _tanqueSelecionadoParaAcoes?['id'] == null
                          ? null
                          : () {
                              final tanqueId =
                                  _tanqueSelecionadoParaAcoes?['id']?.toString();
                              if (tanqueId != null && tanqueId.isNotEmpty) {
                                _carregarCaclsDoTanque(tanqueId);
                              }
                            },
                      tooltip: 'Recarregar CACLs',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (_carregandoCacls)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: CircularProgressIndicator(color: _accent),
                  ),
                )
              else if (_caclesTanque.isEmpty)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.receipt_long_outlined, size: 52, color: _muted),
                      SizedBox(height: 10),
                      Text(
                        'Nenhum CACL encontrado para este tanque',
                        style: TextStyle(fontSize: 14, color: _muted),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _caclesTanque.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final cacl = _caclesTanque[index];
                    final status = cacl['status']?.toString();
                    final isCancelado = status?.toLowerCase() == 'cancelado';
                    final statusColor = _getStatusColor(status);
                    final cardColor = _getCardColor(status);
                    final borderColor = _getBorderColor(status);
                    final statusText = _getStatusText(status);
                    final tanqueRef =
                        cacl['tanques']?['referencia']?.toString() ?? '-';
                    final produto = cacl['produtos']?['nome']?.toString() ?? 'Produto não informado';

                    final inicio =
                        _formatarInicio(cacl['data'], cacl['horario_inicial']);

                    return Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      child: Align(
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: 1300,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            onEnter: (_) =>
                                setState(() => _hoverCaclIndex = index),
                            onExit: (_) =>
                                setState(() => _hoverCaclIndex = null),
                            child: GestureDetector(
                              onTap: () async {
                                final nivelUsuario =
                                    UsuarioAtual.instance?.nivel ?? 0;
                                if (nivelUsuario == 2 && isCancelado) return;

                                final caclId = cacl['id'].toString();
                                final isPendente =
                                    status?.toLowerCase() == 'pendente';
                                final isAguardando =
                                    status?.toLowerCase() == 'aguardando';

                                if (!context.mounted) return;

                                if (isPendente || isAguardando) {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => EditarCaclPage(
                                        caclId: caclId,
                                        onVoltar: () =>
                                            Navigator.pop(context),
                                      ),
                                    ),
                                  );
                                } else {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CaclHistoricoPage(
                                        caclId: caclId,
                                        onVoltar: () =>
                                            Navigator.pop(context),
                                      ),
                                    ),
                                  );
                                }

                                final tanqueId =
                                    _tanqueSelecionadoParaAcoes?['id']
                                        ?.toString();
                                if (tanqueId != null && tanqueId.isNotEmpty) {
                                  _carregarCaclsDoTanque(tanqueId);
                                }
                              },
                              child: Opacity(
                                opacity: isCancelado ? 0.85 : 1.0,
                                child: AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 180),
                                  curve: Curves.easeOut,
                                  transform: _hoverCaclIndex == index
                                      ? (Matrix4.identity()
                                        ..scale(1.01, 1.01))
                                      : Matrix4.identity(),
                                  decoration: BoxDecoration(
                                    color: _hoverCaclIndex == index
                                        ? cardColor.withValues(alpha: 0.85)
                                        : cardColor,
                                    borderRadius:
                                        BorderRadius.circular(12),
                                    border: Border.all(
                                        color: borderColor, width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 
                                          _hoverCaclIndex == index
                                              ? 0.15
                                              : 0.05,
                                        ),
                                        blurRadius: _hoverCaclIndex == index
                                            ? 12
                                            : 4,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 4,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            color: statusColor,
                                            borderRadius:
                                                BorderRadius.circular(2),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(Icons.storage,
                                                      size: 16,
                                                      color:
                                                          Colors.black54),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Tanque $tanqueRef',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: isCancelado
                                                          ? Colors.grey
                                                          : Colors.black87,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.local_gas_station,
                                                    size: 14,
                                                    color: isCancelado
                                                        ? Colors.grey
                                                        : Colors.black54,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      produto,
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: isCancelado
                                                            ? Colors.grey
                                                            : _accent,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.play_circle_outline,
                                                    size: 14,
                                                    color: isCancelado
                                                        ? Colors.grey
                                                        : Colors.black54,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      inicio,
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: isCancelado
                                                            ? Colors.grey
                                                            : Colors.black54,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: statusColor
                                                    .withValues(alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                statusText,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: statusColor,
                                                ),
                                              ),
                                            ),
                                            if (!isCancelado)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 8.0),
                                                child: IconButton(
                                                  icon: const Icon(
                                                    Icons.cancel_outlined,
                                                    color: Colors.red,
                                                    size: 20,
                                                  ),
                                                  onPressed: () =>
                                                      _showDialogConfirmarCancelamento(
                                                          cacl),
                                                  tooltip: 'Cancelar CACL',
                                                  constraints:
                                                      const BoxConstraints(),
                                                  padding: EdgeInsets.zero,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCardAcao({
    required IconData icon,
    required String titulo,
    required String descricao,
    required VoidCallback onTap,
    bool enabled = true,
    String? tooltip,
  }) {
    final cardBg = enabled ? Colors.white : Colors.grey.shade50;
    final innerBg = enabled ? _accent.withValues(alpha: 0.1) : Colors.grey.shade200;
    final iconColor = enabled ? _accent : Colors.grey.shade500;
    final titleColor = enabled ? _ink : Colors.grey.shade600;
    final descColor = enabled ? _muted : Colors.grey.shade500;

    Widget card = Material(
      elevation: 2,
      color: cardBg,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: enabled ? onTap : null,
        hoverColor: enabled ? _accent.withValues(alpha: 0.1) : Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(color: enabled ? _line : Colors.grey.shade300, width: 1.2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: innerBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: enabled ? _accent.withValues(alpha: 0.3) : Colors.grey.shade300, width: 1.5),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(height: 12),
              Text(
                titulo,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                descricao,
                style: TextStyle(
                  fontSize: 10.5,
                  color: descColor,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );

    if (tooltip != null && !enabled) {
      return Tooltip(
        message: tooltip,
        child: card,
      );
    }

    return card;
  }

  // Método substituído para usar o novo dialog separado
  void _showDialogMovimentacaoAvulsa() {
    final tanqueId = _tanqueSelecionadoParaAcoes?['id']?.toString();
    if (tanqueId == null || tanqueId.isEmpty) return;

    final terminalId = _tanqueSelecionadoParaAcoes?['id_terminal']?.toString() ??
        widget.terminalSelecionadoId ??
        UsuarioAtual.instance?.terminalId;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return MovimentacaoAvulsaDialog(
          tanqueId: tanqueId,
          terminalId: terminalId,
          onSalvar: () {
            _carregarDados();
            // Recarrega os CACLs do tanque se necessário
            if (tanqueId.isNotEmpty) {
              _carregarCaclsDoTanque(tanqueId);
            }
          },
        );
      },
    );
  }
}

// Implementações mínimas das classes auxiliares que eram parte do arquivo original.

class _TanqueCard extends StatelessWidget {
  final Map<String, dynamic> tanque;
  final Color statusColor;
  final VoidCallback onTap;

  const _TanqueCard({required this.tanque, required this.statusColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final referencia = tanque['referencia']?.toString() ?? 'Tanque';
    final produto = tanque['produto']?.toString() ?? '';
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200, width: 1.4),
      ),
      child: ListTile(
        onTap: onTap,
        title: Text(referencia, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(produto, style: TextStyle(color: Color(0xFF1B6A6F))),
        // Removed small status circle to simplify card layout per request
      ),
    );
  }
}

class _SelecaoTipoVisualizacaoBottomSheet extends StatefulWidget {
  final String tanqueId;
  final String referenciaTanque;
  final String terminalId;
  final String nomeTerminal;
  final VoidCallback onVoltar;

  const _SelecaoTipoVisualizacaoBottomSheet({
    required this.tanqueId,
    required this.referenciaTanque,
    required this.terminalId,
    required this.nomeTerminal,
    required this.onVoltar,
  });

  @override
  State<_SelecaoTipoVisualizacaoBottomSheet> createState() => _SelecaoTipoVisualizacaoBottomSheetState();
}

class _SelecaoTipoVisualizacaoBottomSheetState extends State<_SelecaoTipoVisualizacaoBottomSheet> {
  final DateTime _dataSelecionada = DateTime.now();
  final int _mesSelecionado = DateTime.now().month;
  final int _anoSelecionado = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      behavior: HitTestBehavior.opaque,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Visualizar estoque - ${widget.referenciaTanque}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => EstoqueTanquePage(
                          tanqueId: widget.tanqueId,
                          referenciaTanque: widget.referenciaTanque,
                          data: _dataSelecionada,
                          onVoltar: () {
                            Navigator.of(ctx).pop();
                            widget.onVoltar();
                          },
                        )));
                      },
                      child: const Text('Diário'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => EstoqueTanqueMensalPage(
                          tanqueId: widget.tanqueId,
                          referenciaTanque: widget.referenciaTanque,
                          terminalId: widget.terminalId,
                          nomeTerminal: widget.nomeTerminal,
                          mes: _mesSelecionado,
                          ano: _anoSelecionado,
                          mostrarDetalhado: true,
                          onVoltar: () {
                            Navigator.of(ctx).pop();
                            widget.onVoltar();
                          },
                        )));
                      },
                      child: const Text('Mensal'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnfocusIntent extends Intent {
  const _UnfocusIntent();
}

String _formatarMilhar(dynamic valor) {
  if (valor == null) return '';
  final digitsOnly = valor.toString().replaceAll(RegExp(r'[^\d]'), '');
  if (digitsOnly.isEmpty) return '';

  final buffer = StringBuffer();
  for (int i = 0; i < digitsOnly.length; i++) {
    final reverseIndex = digitsOnly.length - i;
    buffer.write(digitsOnly[i]);
    if (reverseIndex > 1 && reverseIndex % 3 == 1) {
      buffer.write('.');
    }
  }

  return buffer.toString();
}