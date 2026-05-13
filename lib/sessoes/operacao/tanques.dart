import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_page.dart';
import 'medicoes_emitir_cacl.dart';
import 'cacl_visualizacao.dart';
import 'estoque_tanque_dia.dart';
import 'estoque_tanque_mensal.dart';
import 'medicoes_editar_cacl.dart';

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
  List<Map<String, dynamic>> _caclesTanque = [];
  int? _hoverCaclIndex;
  bool _terminalEmiteCacl = false;

  final List<String> _statusOptions = ['Em operação', 'Operação suspensa'];
  
  final TextEditingController _referenciaController = TextEditingController();
  final TextEditingController _capacidadeController = TextEditingController();
  final TextEditingController _lastroController = TextEditingController();
  String? _produtoSelecionado;
  String? _statusSelecionado;

  bool _houveAlteracao() {
    if (_tanqueEditando == null) {
      // Caso de criação de novo tanque (se as variáveis estiverem vazias, não houve alteração)
      return _referenciaController.text.isNotEmpty ||
          _capacidadeController.text.isNotEmpty ||
          _produtoSelecionado != null ||
          _statusSelecionado != null ||
          _lastroController.text.isNotEmpty;
    }

    // Comparação para edição de tanque existente
    final refOriginal = _tanqueEditando!['referencia']?.toString() ?? '';
    final capOriginal = _formatarMilhar(_tanqueEditando!['capacidade']);
    final prodOriginal = _tanqueEditando!['id_produto']?.toString();
    final statusOriginal = _tanqueEditando!['status']?.toString();
    final lastroOriginal = _formatarMilhar(_tanqueEditando!['lastro']);

    return _referenciaController.text != refOriginal ||
        _capacidadeController.text != capOriginal ||
        _produtoSelecionado != prodOriginal ||
        _statusSelecionado != statusOriginal ||
        _lastroController.text != lastroOriginal;
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
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 350),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10.0,
                    offset: const Offset(0.0, 10.0),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: erro ? Colors.red.shade50 : Colors.green.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      erro ? Icons.error_outline : Icons.check_circle_outline,
                      color: erro ? Colors.red : Colors.green,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 20),
                Text(
                  erro ? 'Atenção' : 'Sucesso',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  mensagem,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: _muted),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: erro ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

  Future<void> _carregarDados() async {
    try {
      final supabase = Supabase.instance.client;
      final usuario = UsuarioAtual.instance!;

      // Captura o resultado bruto para debug
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
            id_produto,
            produtos (nome),
            terminais!inner (nome)
          ''')
          .eq('terminal_id', terminalId)
          .order('referencia');

      final tanquesResponse = await query;

      bool terminalEmite = false;
      final String? usuarioTerminalId = usuario.terminalId;
      if (usuarioTerminalId != null) {
        try {
          final terminalResp = await supabase
              .from('terminais')
              .select('emite_cacl_mov')
              .eq('id', usuarioTerminalId)
              .maybeSingle();

          if (terminalResp != null) {
            terminalEmite = terminalResp['emite_cacl_mov'] == true;
          }
        } catch (_) {
          terminalEmite = false;
        }
      }

      final List<Map<String, dynamic>> tanquesFormatados = [];
      
      for (final tanque in tanquesResponse) {
        tanquesFormatados.add({
          'id': tanque['id'],
          'referencia': tanque['referencia']?.toString() ?? 'SEM REFERÊNCIA',
          'produto': tanque['produtos']?['nome']?.toString() ?? 'PRODUTO NÃO INFORMADO',
          'capacidade': tanque['capacidade']?.toString() ?? '0',
          'lastro': tanque['lastro']?.toString(),
          'status': tanque['status']?.toString() ?? 'Em operação',
          'id_produto': tanque['id_produto'],
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
        _terminalEmiteCacl = terminalEmite;
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
      
      _produtoSelecionado = tanque['id_produto']?.toString();
      _statusSelecionado = tanque['status'];
      _lastroController.text = _formatarMilhar(tanque['lastro']);
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
            produto,
            tanque_id,
            status,
            horario_inicial,
            horario_final,
            tanques:tanque_id (referencia)
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

      // Primeiro, verificar se existe registro na tabela movimentacoes_tanque
      final movimentacaoExistente = await supabase
          .from('movimentacoes_tanque')
          .select('id')
          .eq('cacl_id', caclId)
          .maybeSingle();

      // Se existir, remover o registro
      if (movimentacaoExistente != null) {
        await supabase
            .from('movimentacoes_tanque')
            .delete()
            .eq('cacl_id', caclId);
      }

      // Depois, atualizar o status do CACL para cancelado
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

      // 1. Buscar estoque inicial (Fiel ao estoque_tanque_dia.dart)
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

      // 2. Buscar movimentações (Fiel ao estoque_tanque_dia.dart - sem sobra_perda que não existe na tabela)
      final dadosMovs = await supabase
          .from('movimentacoes_tanque')
          .select('entrada_vinte, saida_vinte, movimentacao_id, data_mov, cliente, descricao')
          .eq('tanque_id', tanqueId)
          .gte('data_mov', '$dataStr 00:00:00')
          .lte('data_mov', '$dataStr 23:59:59');

      final List<Map<String, dynamic>> movs = List<Map<String, dynamic>>.from(dadosMovs);
      
      // 3. Ordenar (Fiel ao estoque_tanque_dia.dart)
      movs.sort((a, b) {
        final da = DateTime.parse(a['data_mov'].toString());
        final db = DateTime.parse(b['data_mov'].toString());
        final dataA = DateTime(da.year, da.month, da.day);
        final dataB = DateTime(db.year, db.month, db.day);
        final cmpData = dataA.compareTo(dataB);
        if (cmpData != 0) return cmpData;
        return da.compareTo(db);
      });

      // 4. Calcular saldo final (Fiel ao estoque_tanque_dia.dart)
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
      return;
    }
    final novoTexto = _formatarMilhar(digitsOnly);
    if (_capacidadeController.text != novoTexto) {
      _capacidadeController.text = novoTexto;
      _capacidadeController.selection = TextSelection.fromPosition(
        TextPosition(offset: novoTexto.length),
      );
    }
  }

  void _aplicarMascaraLastro(String valor) {
    final digitsOnly = valor.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isEmpty) {
      _lastroController.clear();
      return;
    }

    final novoTexto = _formatarMilhar(digitsOnly);
    if (_lastroController.text != novoTexto) {
      _lastroController.text = novoTexto;
      _lastroController.selection = TextSelection.fromPosition(
        TextPosition(offset: novoTexto.length),
      );
    }
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

      // Validação: verificar se o produto está sendo alterado
      if (_tanqueEditando != null) {
        final tanqueId = _tanqueEditando!['id'];
        final produtoOriginal = _tanqueEditando!['id_produto']?.toString();
        final produtoNovo = _produtoSelecionado?.toString();
        final produtoAlterado = produtoOriginal != produtoNovo;

        if (produtoAlterado) {
          // Validação: verificar CACL pendente
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

              // Retorna o produto ao estado anterior
              setState(() {
                _produtoSelecionado = produtoOriginal;
              });
            }
            return;
          }

          // Validação: verificar estoque > 0
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

              // Retorna o produto ao estado anterior
              setState(() {
                _produtoSelecionado = produtoOriginal;
              });
            }
            return;
          }
        }
      }

      final Map<String, dynamic> dadosAtualizados = {
        'referencia': _referenciaController.text.trim(),
        'capacidade': capacidadeTexto.replaceAll('.', ''),
        'lastro': lastroValor,
        'status': _statusSelecionado,
        'id_produto': _produtoSelecionado,
        'terminal_id': idTerminal,
      };

      if (_tanqueEditando != null) {
        await supabase
            .from('tanques')
            .update(dadosAtualizados)
            .eq('id', _tanqueEditando!['id']);
      }

      await _carregarDados();

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
                      : (_mostrandoCardsAcoes ? _buildCardsAcoesDoTanque() : _buildListaTanques()),
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
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: tanques.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
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
                              border: Border.all(color: _accent.withOpacity(0.6), width: 1.2),
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
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _cancelarEdicao,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  side: const BorderSide(color: _accent, width: 1.4),
                                  foregroundColor: _accent,
                                ),
                                child: const Text('Cancelar'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
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
                        color: _accent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _accent.withOpacity(0.2)),
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
                            style: const TextStyle(fontSize: 12, color: _muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildCardAcao(
                      icon: Icons.inventory_2,
                      titulo: 'Movimentação do tanque',
                      descricao: 'Consultar movimentação do tanque',
                      onTap: _abrirEstoqueTanque,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildCardAcao(
                      icon: Icons.analytics,
                      titulo: 'CACL Movimentação',
                      descricao: 'Emitir CACL Movimentação',
                      onTap: _abrirCACL,
                      enabled: _terminalEmiteCacl,
                      tooltip: 'Disponível apenas para apuração de bombeios.',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildCardAcao(
                      icon: Icons.check_circle,
                      titulo: 'CACL verificação',
                      descricao: 'Emitir CACL Verificação',
                      onTap: _abrirCACLVerificacao,
                      enabled: _caclesTanque.isEmpty && !_carregandoCacls,
                      tooltip: 'Já existe CACL para a data atual.',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildCardAcao(
                      icon: Icons.edit,
                      titulo: 'Editar Tanque',
                      descricao: 'Atualizar dados do tanque',
                      onTap: _abrirEdicaoTanque,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildCardAcao(
                      icon: Icons.add_chart,
                      titulo: 'Lançar movimentação avulsa',
                      descricao: 'Registrar entrada ou saída manual',
                      onTap: _showDialogMovimentacaoAvulsa,
                    ),
                  ),
                ],
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
                    final produto = cacl['produto'] ?? 'Produto não informado';

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
                                        ? cardColor.withOpacity(0.85)
                                        : cardColor,
                                    borderRadius:
                                        BorderRadius.circular(12),
                                    border: Border.all(
                                        color: borderColor, width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(
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
                                                            : Colors.black87,
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
                                                    .withOpacity(0.15),
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
    final innerBg = enabled ? _accent.withOpacity(0.1) : Colors.grey.shade200;
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
        hoverColor: enabled ? _accent.withOpacity(0.1) : Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: enabled ? _line : Colors.grey.shade300, width: 1.2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: innerBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: enabled ? _accent.withOpacity(0.3) : Colors.grey.shade300, width: 1.5),
                ),
                child: Icon(icon, color: iconColor, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                titulo,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                descricao,
                style: TextStyle(
                  fontSize: 12,
                  color: descColor,
                ),
                textAlign: TextAlign.center,
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

  void _showDialogMovimentacaoAvulsa() {
    final TextEditingController dataMovController = TextEditingController(
      text: DateFormat('dd/MM/yyyy').format(DateTime.now()),
    );
    final TextEditingController descricaoController = TextEditingController();
    final TextEditingController quantidadeController = TextEditingController();
    DateTime dataSelecionada = DateTime.now();
    String tipoMovimento = 'Entrada';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final Color backgroundColor = tipoMovimento == 'Entrada' 
                ? const Color(0xFFE3F2FD) // Azul claro
                : const Color(0xFFFCE4EC); // Rosa claro
                
            final Color borderColor = tipoMovimento == 'Entrada'
                ? Colors.blue // Azul comum
                : Colors.red; // Vermelho

            return Dialog(
              backgroundColor: backgroundColor,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: borderColor, width: 0.8),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Lançar Movimentação Avulsa',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 18),
                      // Seletor de Tipo (Entrada/Saída)
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setStateDialog(() => tipoMovimento = 'Entrada'),
                              child: Row(
                                children: [
                                  Radio<String>(
                                    value: 'Entrada',
                                    groupValue: tipoMovimento,
                                    activeColor: tipoMovimento == 'Entrada' ? Colors.blue : _muted,
                                    onChanged: (value) => setStateDialog(() => tipoMovimento = value!),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  const Text('Entrada', style: TextStyle(fontSize: 13, color: _ink)),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setStateDialog(() => tipoMovimento = 'Saída'),
                              child: Row(
                                children: [
                                  Radio<String>(
                                    value: 'Saída',
                                    groupValue: tipoMovimento,
                                    activeColor: tipoMovimento == 'Saída' ? Colors.red : _muted,
                                    onChanged: (value) => setStateDialog(() => tipoMovimento = value!),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  const Text('Saída', style: TextStyle(fontSize: 13, color: _ink)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text('Data de lançamento',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _ink)),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: dataSelecionada,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2101),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.light(
                                    primary: borderColor,
                                    onPrimary: Colors.white,
                                    onSurface: _ink,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setStateDialog(() {
                              dataSelecionada = picked;
                              dataMovController.text = DateFormat('dd/MM/yyyy').format(picked);
                            });
                          }
                        },
                        child: IgnorePointer(
                          child: TextField(
                            controller: dataMovController,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'dd/mm/aaaa',
                              prefixIcon: Icon(Icons.calendar_today, size: 16, color: borderColor),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: borderColor.withOpacity(0.5)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: borderColor),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              isDense: true,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Quantidade (Litros)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _ink)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: quantidadeController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 13),
                        maxLength: 7,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onChanged: (value) {
                          if (value.isNotEmpty) {
                            final formatted = _formatarMilhar(value);
                            quantidadeController.value = TextEditingValue(
                              text: formatted,
                              selection: TextSelection.collapsed(offset: formatted.length),
                            );
                          }
                          setStateDialog(() {});
                        },
                        decoration: InputDecoration(
                          hintText: '0',
                          counterText: '',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: borderColor.withOpacity(0.5)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Descrição',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _ink)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: descricaoController,
                        style: const TextStyle(fontSize: 13),
                        maxLines: 4,
                        minLines: 4,
                        maxLength: 200,
                        keyboardType: TextInputType.multiline,
                        onChanged: (_) => setStateDialog(() {}),
                        decoration: InputDecoration(
                          hintText: 'Digite...',
                          counterText: '',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: borderColor.withOpacity(0.5)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: borderColor, width: 0.8),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: Text('Voltar', style: TextStyle(color: borderColor, fontSize: 13)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: (descricaoController.text.trim().isEmpty || 
                                         quantidadeController.text.trim().isEmpty)
                                  ? null 
                                  : () {
                                      Navigator.pop(context);
                                      _salvarMovimentacaoAvulsa(
                                        dataSelecionada,
                                        descricaoController.text,
                                        quantidadeController.text,
                                        tipoMovimento,
                                      );
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: borderColor,
                                disabledBackgroundColor: Colors.grey.shade400,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Salvar', style: TextStyle(color: Colors.white, fontSize: 13)),
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
      },
    );
  }

  Future<void> _salvarMovimentacaoAvulsa(
      DateTime data, String descricao, String quantidade, String tipo) async {
    try {
      final supabase = Supabase.instance.client;
      final tanqueId = _tanqueSelecionadoParaAcoes?['id'];

      if (tanqueId == null) return;

      final valorNumerico =
          double.tryParse(quantidade.replaceAll('.', '').replaceAll(',', '.')) ?? 0;

      await supabase.from('movimentacoes_tanque').insert({
        'tanque_id': tanqueId,
        'data_mov': data.toIso8601String(),
        'descricao': descricao,
        'tipo_mov': tipo,
        'entrada_vinte': tipo == 'Entrada' ? valorNumerico : 0,
        'saida_vinte': tipo == 'Saída' ? valorNumerico : 0,
        'terminal_id':
            widget.terminalSelecionadoId ?? UsuarioAtual.instance?.terminalId,
      });

      _mostrarAviso('Movimentação lançada com sucesso!', erro: false);
      _carregarDados();
    } catch (e) {
      _mostrarAviso('Erro ao salvar movimentação: $e');
    }
  }
}

class _TanqueCard extends StatefulWidget {
  final Map<String, dynamic> tanque;
  final Color statusColor;
  final VoidCallback onTap;

  const _TanqueCard({
    required this.tanque,
    required this.statusColor,
    required this.onTap,
  });

  @override
  State<_TanqueCard> createState() => _TanqueCardState();
}

class _TanqueCardState extends State<_TanqueCard> {
  static const Color _ink = Color(0xFF0E1C2F);
  static const Color _muted = Color(0xFF5A6B7A);
  static const Color _line = Color(0xFFE6DCCB);
  
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedScale(
        scale: _isHovering ? 1.01 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: Material(
          color: _isHovering ? const Color(0xFFF5F5F5) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: _line, width: 1.2),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 56,
                    decoration: BoxDecoration(
                      color: widget.statusColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.tanque['referencia'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.tanque['produto'],
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.tanque['lastro'] != null &&
                          widget.tanque['lastro'].toString().trim().isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _line, width: 1.2),
                          ),
                          child: Text(
                            'Lastro: ${_formatarMilhar(widget.tanque['lastro'])} L',
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (widget.tanque['lastro'] != null &&
                          widget.tanque['lastro'].toString().trim().isNotEmpty)
                        const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _line, width: 1.2),
                        ),
                        child: Text(
                          '${_formatarMilhar(widget.tanque['capacidade'])} L',
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: widget.statusColor, width: 1.2),
                        ),
                        child: Text(
                          widget.tanque['status'],
                          style: TextStyle(
                            color: widget.statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
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
  bool _tipoDataEspecifica = true;
  bool _tipoMensal = false;
  bool _mostrarDetalhado = true;
  
  DateTime _dataSelecionada = DateTime.now();
  int _mesSelecionado = DateTime.now().month;
  int _anoSelecionado = DateTime.now().year;
  
  final TextEditingController _dataController = TextEditingController();
  final TextEditingController _mesAnoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _atualizarDataController();
    _atualizarMesAnoController();
  }

  void _atualizarDataController() {
    _dataController.text = DateFormat('dd/MM/yyyy').format(_dataSelecionada);
  }

  void _atualizarMesAnoController() {
    _mesAnoController.text = '${_mesSelecionado.toString().padLeft(2, '0')}/${_anoSelecionado}';
  }

  Future<void> _selecionarData() async {
    DateTime tempDate = _dataSelecionada;
    final DateTime? picked = await showDialog<DateTime>(
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
                          Text('${_getNomeMes(tempDate.month)} ${tempDate.year}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF0D47A1))),
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

    if (picked != null) {
      setState(() {
        _dataSelecionada = picked;
        _tipoDataEspecifica = true;
        _tipoMensal = false;
        _atualizarDataController();
      });
    }
  }

  String _getNomeMes(int mes) {
    const meses = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    return meses[mes - 1];
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

  Future<void> _selecionarMesAno() async {
    int tempMes = _mesSelecionado;
    int tempAno = _anoSelecionado;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: Text(
                          'Selecionar Mês/Ano',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: tempMes,
                                  isExpanded: true,
                                  icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF0D47A1)),
                                  items: List.generate(12, (index) {
                                    final mes = index + 1;
                                    return DropdownMenuItem(
                                      value: mes,
                                      child: Text(
                                        _getNomeMes(mes),
                                        style: const TextStyle(fontSize: 15),
                                      ),
                                    );
                                  }),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setStateDialog(() => tempMes = value);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              initialValue: tempAno.toString(),
                              decoration: InputDecoration(
                                labelText: 'Ano',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                final ano = int.tryParse(value);
                                if (ano != null && ano >= 2000 && ano <= 2100) {
                                  setStateDialog(() => tempAno = ano);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      InkWell(
                        onTap: () {
                          setState(() => _mostrarDetalhado = !_mostrarDetalhado);
                          setStateDialog(() {});
                        },
                        child: Row(
                          children: [
                            Checkbox(
                              value: _mostrarDetalhado,
                              onChanged: (val) {
                                setState(() => _mostrarDetalhado = val ?? true);
                                setStateDialog(() {});
                              },
                              activeColor: const Color(0xFF0D47A1),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            const Text('Mostrar detalhado', style: TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                side: const BorderSide(color: Color(0xFF0D47A1)),
                                foregroundColor: const Color(0xFF0D47A1),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Cancelar'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context); // Fecha o Diálogo de Mês/Ano
                                Navigator.pop(context); // Fecha o BottomSheet Original

                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (ctx) => EstoqueTanqueMensalPage(
                                      tanqueId: widget.tanqueId,
                                      referenciaTanque: widget.referenciaTanque,
                                      terminalId: widget.terminalId,
                                      nomeTerminal: widget.nomeTerminal,
                                      mes: tempMes,
                                      ano: tempAno,
                                      mostrarDetalhado: _mostrarDetalhado,
                                      onVoltar: () {
                                        Navigator.of(ctx).pop();
                                        widget.onVoltar();
                                      },
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: const Color(0xFF0D47A1),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                              child: const Text('Confirmar'),
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
      },
    );
  }

  void _visualizar() {
    if (!_tipoDataEspecifica && !_tipoMensal) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 350),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10.0,
                        offset: const Offset(0.0, 10.0),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Atenção',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0E1C2F),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Selecione um tipo de visualização',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Color(0xFF5A6B7A)),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'OK',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }
    return;
  }

  Navigator.pop(context);

    if (_tipoDataEspecifica) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => EstoqueTanquePage(
            tanqueId: widget.tanqueId,
            referenciaTanque: widget.referenciaTanque,
            data: _dataSelecionada,
            onVoltar: () {
              Navigator.of(ctx).pop();
              widget.onVoltar();
            },
          ),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => EstoqueTanqueMensalPage(
            tanqueId: widget.tanqueId,
            referenciaTanque: widget.referenciaTanque,
            terminalId: widget.terminalId,
            nomeTerminal: widget.nomeTerminal,
            mes: _mesSelecionado,
            ano: _anoSelecionado,
            mostrarDetalhado: _mostrarDetalhado,
            onVoltar: () {
              Navigator.of(ctx).pop();
              widget.onVoltar();
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      behavior: HitTestBehavior.opaque,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onTap: () {},
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: Text(
                      'Selecionar Período',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  InkWell(
                    onTap: _selecionarData,
                    child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _tipoDataEspecifica 
                          ? const Color(0xFF0D47A1) 
                          : Colors.grey.shade300,
                      width: _tipoDataEspecifica ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: _tipoDataEspecifica 
                        ? const Color(0xFF0D47A1).withOpacity(0.05)
                        : Colors.white,
                  ),
                  child: Row(
                    children: [
                      Radio<bool>(
                        value: true,
                        groupValue: _tipoDataEspecifica,
                        onChanged: (value) {
                          setState(() {
                            _tipoDataEspecifica = true;
                            _tipoMensal = false;
                          });
                        },
                        activeColor: const Color(0xFF0D47A1),
                      ),
                      const Expanded(
                        child: Text(
                          'Data específica',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _dataController.text,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              
              InkWell(
                onTap: _selecionarMesAno,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _tipoMensal 
                          ? const Color(0xFF0D47A1) 
                          : Colors.grey.shade300,
                      width: _tipoMensal ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: _tipoMensal 
                        ? const Color(0xFF0D47A1).withOpacity(0.05)
                        : Colors.white,
                  ),
                  child: Row(
                    children: [
                      Radio<bool>(
                        value: true,
                        groupValue: _tipoMensal,
                        onChanged: (value) {
                          setState(() {
                            _tipoMensal = true;
                            _tipoDataEspecifica = false;
                          });
                        },
                        activeColor: const Color(0xFF0D47A1),
                      ),
                      const Expanded(
                        child: Text(
                          'Estoque mensal',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _mesAnoController.text,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (_tipoMensal)
                InkWell(
                  onTap: () => setState(() => _mostrarDetalhado = !_mostrarDetalhado),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10, left: 4),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _mostrarDetalhado,
                          onChanged: (val) => setState(() => _mostrarDetalhado = val ?? true),
                          activeColor: const Color(0xFF0D47A1),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        const Text('Mostrar detalhado', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 24),
              
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Color(0xFF0D47A1)),
                        foregroundColor: const Color(0xFF0D47A1),
                      ),
                      child: const Text('Voltar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _visualizar,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xFF0D47A1),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Visualizar'),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    ),
    ),
    );
  }

  @override
  void dispose() {
    _dataController.dispose();
    _mesAnoController.dispose();
    super.dispose();
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