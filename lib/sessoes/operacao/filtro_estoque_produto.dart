import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_page.dart';

class FiltroEstoqueProdutoPage extends StatefulWidget {
  final String? filialId;
  final String? terminalId;
  final String nomeFilial;
  final String? empresaId;
  final String? empresaNome;
  final Function({
    required String? filialId,
    required String? terminalId,
    required String nomeFilial,
    String? empresaId,
    required DateTime dataInicial,
    required DateTime dataFinal,
    required String produtoId,
    required String produtoNome,
    required String tipoRelatorio,
  })
  onConsultarEstoqueProduto;
  final VoidCallback onVoltar;

  const FiltroEstoqueProdutoPage({
    super.key,
    this.filialId,
    this.terminalId,
    required this.nomeFilial,
    this.empresaId,
    this.empresaNome,
    required this.onConsultarEstoqueProduto,
    required this.onVoltar,
  });

  @override
  State<FiltroEstoqueProdutoPage> createState() =>
      _FiltroEstoqueProdutoPageState();
}

class _FiltroEstoqueProdutoPageState extends State<FiltroEstoqueProdutoPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  DateTime _dataInicial = DateTime.now();
  DateTime _dataFinal = DateTime.now();
  String _tipoRelatorio = 'sintetico';
  String? _produtoSelecionadoId;
  String? _produtoSelecionadoNome;
  String? _filialSelecionadaId;
  String? _filialSelecionadaNome;
  String? _terminalSelecionadoId;
  String? _terminalSelecionadoNome;
  List<Map<String, dynamic>> _produtosDisponiveis = [];
  List<Map<String, dynamic>> _filiaisDisponiveis = [];
  List<Map<String, dynamic>> _terminaisDisponiveis = [];
  bool _carregandoProdutos = false;
  bool _carregandoFiliais = false;
  bool _carregandoTerminais = false;
  bool _terminalVinculado = false;

  @override
  void initState() {
    super.initState();

    final usuario = UsuarioAtual.instance;

    // Verificar se usuário tem terminal vinculado no login
    if (usuario?.terminalId != null && usuario!.terminalId!.isNotEmpty) {
      _terminalVinculado = true;
      _terminalSelecionadoId = usuario.terminalId;
      _terminalSelecionadoNome = usuario.terminalNome ?? 'Terminal vinculado';

      // Se tem terminal vinculado, já carrega as filiais baseadas nele
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _carregarFilialPorTerminal(_terminalSelecionadoId!);
      });
    }

    // Inicializar filial a partir do usuário logado
    _filialSelecionadaId = usuario?.filialId ?? '';

    _carregarTerminaisDisponiveis();
    if (_terminalVinculado && _terminalSelecionadoId != null) {
      _carregarProdutosPorTerminal(_terminalSelecionadoId!);
    }
  }

  Future<void> _carregarFilialPorTerminal(String terminalId) async {
    setState(() {
      _carregandoFiliais = true;
    });

    try {
      final usuario = UsuarioAtual.instance;
      if (usuario == null) return;

      // Buscar empresa_id do usuário
      String? empresaId = usuario.empresaId;
      if (empresaId == null || empresaId.isEmpty) {
        empresaId = widget.empresaId;
      }

      if (empresaId == null || empresaId.isEmpty) {
        setState(() {
          _filialSelecionadaId = '';
          _filialSelecionadaNome = null;
          _filiaisDisponiveis = [
            {'id': '', 'nome': '<empresa não identificada>'},
          ];
        });
        return;
      }

      // Primeiro, buscar a relação para obter os IDs das filiais
      final relacao = await _supabase
          .from('relacoes_terminais')
          .select('filial_id_1, filial_id_2')
          .eq('empresa_id', empresaId)
          .eq('terminal_id', terminalId)
          .maybeSingle();

      // Preparar lista de filiais disponíveis
      List<Map<String, dynamic>> filiais = [];
      filiais.add({'id': '', 'nome': '<selecione>'});

      if (relacao != null) {
        // Buscar dados da filial 1 se existir
        if (relacao['filial_id_1'] != null) {
          final filialId1 = relacao['filial_id_1']?.toString();
          if (filialId1 != null && filialId1.isNotEmpty) {
            final filialData1 = await _supabase
                .from('filiais')
                .select('id, nome, nome_dois')
                .eq('id', filialId1)
                .maybeSingle();

            if (filialData1 != null) {
              final nome =
                  filialData1['nome_dois'] ?? filialData1['nome'] ?? '';
              filiais.add({'id': filialId1, 'nome': nome.toString()});
            }
          }
        }

        // Buscar dados da filial 2 se existir
        if (relacao['filial_id_2'] != null) {
          final filialId2 = relacao['filial_id_2']?.toString();
          if (filialId2 != null && filialId2.isNotEmpty) {
            // Evitar duplicata caso seja igual à filial 1
            if (!filiais.any((f) => f['id'] == filialId2)) {
              final filialData2 = await _supabase
                  .from('filiais')
                  .select('id, nome, nome_dois')
                  .eq('id', filialId2)
                  .maybeSingle();

              if (filialData2 != null) {
                final nome =
                    filialData2['nome_dois'] ?? filialData2['nome'] ?? '';
                filiais.add({'id': filialId2, 'nome': nome.toString()});
              }
            }
          }
        }
      }

      setState(() {
        _filiaisDisponiveis = filiais;

        // Se só tiver uma filial disponível (além da opção <selecione>), pré-selecionar automaticamente
        if (filiais.length == 2) {
          // 1 opção <selecione> + 1 filial
          _filialSelecionadaId = filiais[1]['id'];
          _filialSelecionadaNome = filiais[1]['nome'];
        } else {
          _filialSelecionadaId = '';
          _filialSelecionadaNome = null;
        }
      });
    } catch (e) {
      debugPrint('❌ Erro ao carregar filial por terminal: $e');
      setState(() {
        _filiaisDisponiveis = [
          {'id': '', 'nome': '<erro ao carregar filiais>'},
        ];
        _filialSelecionadaId = '';
        _filialSelecionadaNome = null;
      });
    } finally {
      setState(() => _carregandoFiliais = false);
    }
  }

  Future<void> _carregarTerminaisDisponiveis() async {
    // Se usuário já tem terminal vinculado, não precisa carregar lista
    if (_terminalVinculado) {
      setState(() {
        _terminaisDisponiveis = [
          {'id': _terminalSelecionadoId!, 'nome': _terminalSelecionadoNome!},
        ];
      });
      return;
    }

    setState(() => _carregandoTerminais = true);

    try {
      final usuario = UsuarioAtual.instance;
      if (usuario == null) {
        setState(() {
          _terminaisDisponiveis = [
            {'id': '', 'nome': '<usuário não logado>'},
          ];
        });
        return;
      }

      // Buscar empresa_id do usuário
      String? empresaId = usuario.empresaId;

      // Se não tiver empresa_id no usuário, tentar usar o do parâmetro
      if (empresaId == null || empresaId.isEmpty) {
        empresaId = widget.empresaId;
      }

      if (empresaId == null || empresaId.isEmpty) {
        setState(() {
          _terminaisDisponiveis = [
            {'id': '', 'nome': '<empresa não identificada>'},
          ];
        });
        return;
      }

      // Buscar terminais através da tabela relacoes_terminais
      final relacoes = await _supabase
          .from('relacoes_terminais')
          .select('''
            terminal_id,
            terminais!inner (
              id,
              nome
            )
          ''')
          .eq('empresa_id', empresaId);

      final Map<String, Map<String, dynamic>> terminaisUnicos = {};

      for (var relacao in relacoes) {
        if (relacao['terminais'] != null) {
          final terminal = relacao['terminais'] as Map<String, dynamic>;
          final terminalId = terminal['id']?.toString();

          if (terminalId != null && !terminaisUnicos.containsKey(terminalId)) {
            terminaisUnicos[terminalId] = {
              'id': terminalId,
              'nome': terminal['nome']?.toString() ?? 'Terminal sem nome',
            };
          }
        }
      }

      List<Map<String, dynamic>> terminais = terminaisUnicos.values.toList()
        ..sort((a, b) => (a['nome'] ?? '').compareTo(b['nome'] ?? ''));

      final List<Map<String, dynamic>> listaFinal = [];
      listaFinal.add({'id': '', 'nome': '<selecione>'});
      listaFinal.addAll(terminais);

      setState(() {
        _terminaisDisponiveis = listaFinal;
        // Se só tiver um terminal disponível, pré-selecionar automaticamente
        if (terminais.length == 1) {
          _terminalSelecionadoId = terminais.first['id'];
          _terminalSelecionadoNome = terminais.first['nome'];
          // Carregar filiais e produtos para este terminal pré-selecionado
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _carregarFilialPorTerminal(_terminalSelecionadoId!);
            _carregarProdutosPorTerminal(_terminalSelecionadoId!);
          });
        } else {
          _terminalSelecionadoId = '';
          _terminalSelecionadoNome = null;
          // Limpar filiais se não tiver terminal selecionado
          setState(() {
            _filiaisDisponiveis = [];
            _filialSelecionadaId = '';
            _filialSelecionadaNome = null;
          });
        }
      });
    } catch (e) {
      debugPrint('❌ Erro ao carregar terminais: $e');
      setState(() {
        _terminaisDisponiveis = [
          {'id': '', 'nome': '<erro ao carregar terminais>'},
        ];
        _terminalSelecionadoId = '';
      });
    } finally {
      setState(() => _carregandoTerminais = false);
    }
  }

  Future<void> _carregarProdutosPorTerminal(String terminalId) async {
    setState(() => _carregandoProdutos = true);

    try {
      // Buscar produtos dos tanques do terminal selecionado
      final response = await _supabase
          .from('tanques')
          .select('''
            id_produto,
            produtos!tanques_id_produto_fkey (
              id,
              nome,
              nome_dois
            )
          ''')
          .eq('terminal_id', terminalId)
          .not('id_produto', 'is', null); // Ignorar tanques sem produto

      // Usar um Map para evitar produtos duplicados
      final Map<String, Map<String, dynamic>> produtosUnicos = {};

      for (var tanque in response) {
        if (tanque['produtos'] != null) {
          final produto = tanque['produtos'] as Map<String, dynamic>;
          final produtoId = produto['id']?.toString();

          if (produtoId != null && !produtosUnicos.containsKey(produtoId)) {
            final nome =
                produto['nome_dois'] ?? produto['nome'] ?? 'Produto sem nome';
            produtosUnicos[produtoId] = {
              'id': produtoId,
              'nome': nome.toString(),
            };
          }
        }
      }

      // Converter o Map para lista e ordenar por nome
      List<Map<String, dynamic>> produtos = produtosUnicos.values.toList()
        ..sort((a, b) => (a['nome'] ?? '').compareTo(b['nome'] ?? ''));

      // Montar lista final com opção "selecione"
      final List<Map<String, dynamic>> listaFinal = [];
      listaFinal.add({'id': '', 'nome': '<selecione>'});
      listaFinal.addAll(produtos);

      setState(() {
        _produtosDisponiveis = listaFinal;
        _produtoSelecionadoId = '';
        _produtoSelecionadoNome = null;
      });
    } catch (e) {
      debugPrint('❌ Erro ao carregar produtos por terminal: $e');
      setState(() {
        _produtosDisponiveis = [
          {'id': '', 'nome': '<erro ao carregar produtos>'},
        ];
        _produtoSelecionadoId = '';
      });
    } finally {
      setState(() => _carregandoProdutos = false);
    }
  }

  Future<void> _selecionarDataInicial(BuildContext context) async {
    DateTime tempDate = _dataInicial;
    final DateTime? selecionado = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
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
                        const Icon(
                          Icons.calendar_today,
                          color: Color(0xFF0D47A1),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Data inicial',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                          color: Colors.grey,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.chevron_left,
                              color: Color(0xFF0D47A1),
                            ),
                            onPressed: () {
                              setStateDialog(() {
                                tempDate = DateTime(
                                  tempDate.year,
                                  tempDate.month - 1,
                                  tempDate.day,
                                );
                              });
                            },
                          ),
                          Text(
                            '${_getMonthName(tempDate.month)} ${tempDate.year}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0D47A1),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.chevron_right,
                              color: Color(0xFF0D47A1),
                            ),
                            onPressed: () {
                              setStateDialog(() {
                                tempDate = DateTime(
                                  tempDate.year,
                                  tempDate.month + 1,
                                  tempDate.day,
                                );
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: 7,
                      childAspectRatio: 1.0,
                      children: ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'].map((day) {
                        return Center(
                          child: Text(
                            day,
                            style: const TextStyle(
                              color: Color(0xFF0D47A1),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: 7,
                      childAspectRatio: 1.0,
                      children: _getDaysInMonth(tempDate).map((day) {
                        final isSelected = day != null && day == tempDate.day;
                        final isToday =
                            day != null &&
                            day == DateTime.now().day &&
                            tempDate.month == DateTime.now().month &&
                            tempDate.year == DateTime.now().year;
                        return StatefulBuilder(
                          builder: (context, setDayState) {
                            return MouseRegion(
                              cursor: day != null
                                  ? SystemMouseCursors.click
                                  : SystemMouseCursors.basic,
                              onEnter: (_) {
                                if (day != null) {
                                  setDayState(() => hoveredDay = day);
                                }
                              },
                              onExit: (_) {
                                if (day != null) {
                                  setDayState(() => hoveredDay = null);
                                }
                              },
                              child: GestureDetector(
                                onTap: day != null
                                    ? () {
                                        setStateDialog(() {
                                          tempDate = DateTime(
                                            tempDate.year,
                                            tempDate.month,
                                            day,
                                          );
                                        });
                                      }
                                    : null,
                                child: Container(
                                  margin: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF0D47A1)
                                        : (day != null && hoveredDay == day)
                                        ? const Color(
                                            0xFF0D47A1,
                                          ).withOpacity(0.1)
                                        : isToday
                                        ? const Color(0x220D47A1)
                                        : Colors.transparent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      day != null ? day.toString() : '',
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : isToday ||
                                                  (day != null &&
                                                      hoveredDay == day)
                                            ? const Color(0xFF0D47A1)
                                            : Colors.black87,
                                        fontWeight:
                                            isSelected ||
                                                isToday ||
                                                (day != null &&
                                                    hoveredDay == day)
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
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
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: const Text('CANCELAR'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(tempDate),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D47A1),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'SELECIONAR',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
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

    if (selecionado != null) {
      setState(() {
        _dataInicial = selecionado;
        if (_dataInicial.isAfter(_dataFinal)) {
          _dataFinal = _dataInicial;
        }
      });
    }
  }

  Future<void> _selecionarDataFinal(BuildContext context) async {
    DateTime tempDate = _dataFinal;
    final DateTime? selecionado = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
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
                        const Icon(
                          Icons.calendar_today,
                          color: Color(0xFF0D47A1),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Data final',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                          color: Colors.grey,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.chevron_left,
                              color: Color(0xFF0D47A1),
                            ),
                            onPressed: () {
                              setStateDialog(() {
                                tempDate = DateTime(
                                  tempDate.year,
                                  tempDate.month - 1,
                                  tempDate.day,
                                );
                              });
                            },
                          ),
                          Text(
                            '${_getMonthName(tempDate.month)} ${tempDate.year}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0D47A1),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.chevron_right,
                              color: Color(0xFF0D47A1),
                            ),
                            onPressed: () {
                              setStateDialog(() {
                                tempDate = DateTime(
                                  tempDate.year,
                                  tempDate.month + 1,
                                  tempDate.day,
                                );
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: 7,
                      childAspectRatio: 1.0,
                      children: ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'].map((day) {
                        return Center(
                          child: Text(
                            day,
                            style: const TextStyle(
                              color: Color(0xFF0D47A1),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: 7,
                      childAspectRatio: 1.0,
                      children: _getDaysInMonth(tempDate).map((day) {
                        final isSelected = day != null && day == tempDate.day;
                        final isToday =
                            day != null &&
                            day == DateTime.now().day &&
                            tempDate.month == DateTime.now().month &&
                            tempDate.year == DateTime.now().year;
                        return StatefulBuilder(
                          builder: (context, setDayState) {
                            return MouseRegion(
                              cursor: day != null
                                  ? SystemMouseCursors.click
                                  : SystemMouseCursors.basic,
                              onEnter: (_) {
                                if (day != null) {
                                  setDayState(() => hoveredDay = day);
                                }
                              },
                              onExit: (_) {
                                if (day != null) {
                                  setDayState(() => hoveredDay = null);
                                }
                              },
                              child: GestureDetector(
                                onTap: day != null
                                    ? () {
                                        setStateDialog(() {
                                          tempDate = DateTime(
                                            tempDate.year,
                                            tempDate.month,
                                            day,
                                          );
                                        });
                                      }
                                    : null,
                                child: Container(
                                  margin: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF0D47A1)
                                        : (day != null && hoveredDay == day)
                                        ? const Color(
                                            0xFF0D47A1,
                                          ).withOpacity(0.1)
                                        : isToday
                                        ? const Color(0x220D47A1)
                                        : Colors.transparent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      day != null ? day.toString() : '',
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : isToday ||
                                                  (day != null &&
                                                      hoveredDay == day)
                                            ? const Color(0xFF0D47A1)
                                            : Colors.black87,
                                        fontWeight:
                                            isSelected ||
                                                isToday ||
                                                (day != null &&
                                                    hoveredDay == day)
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
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
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: const Text('CANCELAR'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(tempDate),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D47A1),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'SELECIONAR',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
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

    if (selecionado != null) {
      setState(() {
        _dataFinal = selecionado;
        if (_dataFinal.isBefore(_dataInicial)) {
          _dataInicial = _dataFinal;
        }
      });
    }
  }

  void _irParaEstoqueProduto() {
    // Validar campos obrigatórios
    if (_dataInicial.isAfter(_dataFinal)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A data inicial não pode ser posterior à data final.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_produtoSelecionadoId == null || _produtoSelecionadoId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecione um produto.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validar terminal
    if (_terminalSelecionadoId == null || _terminalSelecionadoId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecione um terminal.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Obter nome do produto selecionado
    final produtoSelecionado = _produtosDisponiveis.firstWhere(
      (p) => p['id'] == _produtoSelecionadoId,
      orElse: () => {'id': '', 'nome': ''},
    );
    _produtoSelecionadoNome = produtoSelecionado['nome'];

    final String? filialToPass =
        (_filialSelecionadaId != null && _filialSelecionadaId!.isNotEmpty)
        ? _filialSelecionadaId
        : null;

    widget.onConsultarEstoqueProduto(
      filialId: filialToPass,
      terminalId: _terminalSelecionadoId,
      nomeFilial:
          _terminalSelecionadoNome ??
          _filialSelecionadaNome ??
          'Terminal não selecionado',
      empresaId: widget.empresaId,
      dataInicial: _dataInicial,
      dataFinal: _dataFinal,
      produtoId: _produtoSelecionadoId!,
      produtoNome: _produtoSelecionadoNome!,
      tipoRelatorio: _tipoRelatorio,
    );
  }

  void _resetarFiltros() {
    final agora = DateTime.now();
    setState(() {
      _dataInicial = agora;
      _dataFinal = agora;
      _tipoRelatorio = 'sintetico';
      _produtoSelecionadoId = '';
      _produtoSelecionadoNome = null;

      // Se não tiver terminal vinculado, resetar também
      if (!_terminalVinculado) {
        _terminalSelecionadoId = '';
        _terminalSelecionadoNome = null;
        _filiaisDisponiveis = [];
        _filialSelecionadaId = '';
        _filialSelecionadaNome = null;
        _produtosDisponiveis = []; // Limpar produtos
      }
    });

    // Se tiver terminal vinculado, recarregar os produtos dele
    if (_terminalVinculado && _terminalSelecionadoId != null) {
      _carregarProdutosPorTerminal(_terminalSelecionadoId!);
    }
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
              'Estoque por Produto',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              widget.nomeFilial,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onVoltar,
        ),
      ),
      body: Padding(padding: const EdgeInsets.all(20), child: _buildConteudo()),
    );
  }

  Widget _buildConteudo() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardFiltros(),
          const SizedBox(height: 20),
          _buildCardResumo(),
          const SizedBox(height: 20),
          _buildBotoes(),
          const SizedBox(height: 20),
          _buildNotas(),
        ],
      ),
    );
  }

  Widget _buildCardFiltros() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header do card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.filter_alt,
                  color: const Color(0xFF0D47A1),
                  size: 20,
                ),
                const SizedBox(width: 10),
                const Text(
                  'Filtros de Consulta',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0D47A1),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Linha de filtros: Terminal, Filial, Produto, Data inicial e Data final
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1 - Campo Terminal
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Terminal *',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                        if (_terminalVinculado) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.lock, size: 14, color: Colors.grey),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    SizedBox(height: 50, child: _buildCampoTerminal()),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // 2 - Campo Filial
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filial',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(height: 50, child: _buildCampoFilial()),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // 3 - Campo Produto
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Produto *',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(height: 50, child: _buildCampoProduto()),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // 4 - Campo Data inicial
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Data inicial *',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => _selecionarDataInicial(context),
                      child: Container(
                        width: double.infinity,
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color: Colors.grey.shade400,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_dataInicial.day.toString().padLeft(2, '0')}/${_dataInicial.month.toString().padLeft(2, '0')}/${_dataInicial.year}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black,
                              ),
                            ),
                            Icon(
                              Icons.calendar_today,
                              color: Colors.grey.shade600,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // 5 - Campo Data final
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Data final *',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => _selecionarDataFinal(context),
                      child: Container(
                        width: double.infinity,
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color: Colors.grey.shade400,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_dataFinal.day.toString().padLeft(2, '0')}/${_dataFinal.month.toString().padLeft(2, '0')}/${_dataFinal.year}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black,
                              ),
                            ),
                            Icon(
                              Icons.calendar_today,
                              color: Colors.grey.shade600,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // 6 - Campo Tipo de Relatório
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tipo de relatório',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: Colors.grey.shade400,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _tipoRelatorio,
                          isExpanded: true,
                          itemHeight: 50,
                          icon: const Icon(Icons.arrow_drop_down, size: 20),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black,
                          ),
                          onChanged: (String? novoValor) {
                            setState(() {
                              _tipoRelatorio = novoValor!;
                            });
                          },
                          items: const [
                            DropdownMenuItem<String>(
                              value: 'sintetico',
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text('Sintético'),
                              ),
                            ),
                            DropdownMenuItem<String>(
                              value: 'analitico',
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text('Analítico'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCampoTerminal() {
    if (_carregandoTerminais) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade400, width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              color: Color(0xFF0D47A1),
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade400, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _terminalSelecionadoId,
          isExpanded: true,
          itemHeight: 50,
          icon: const Icon(Icons.arrow_drop_down, size: 20),
          style: const TextStyle(fontSize: 13, color: Colors.black),
          onChanged: _terminalVinculado
              ? null
              : (String? novoValor) async {
                  setState(() {
                    _terminalSelecionadoId = novoValor;
                    if (novoValor != null && novoValor.isNotEmpty) {
                      final terminal = _terminaisDisponiveis.firstWhere(
                        (t) => t['id'] == novoValor,
                        orElse: () => {'id': '', 'nome': ''},
                      );
                      _terminalSelecionadoNome = terminal['nome'];

                      // Limpar produto selecionado ao mudar de terminal
                      _produtoSelecionadoId = '';
                      _produtoSelecionadoNome = null;
                    } else {
                      _terminalSelecionadoNome = null;
                      // Se limpou o terminal, limpa também as filiais e produtos
                      _filiaisDisponiveis = [];
                      _filialSelecionadaId = '';
                      _filialSelecionadaNome = null;
                      _produtosDisponiveis = [];
                      _produtoSelecionadoId = '';
                      _produtoSelecionadoNome = null;
                    }
                  });

                  // Se selecionou um terminal válido, busca as filiais e produtos
                  if (novoValor != null && novoValor.isNotEmpty) {
                    await _carregarFilialPorTerminal(novoValor);
                    await _carregarProdutosPorTerminal(novoValor);
                  }
                },
          items: _terminaisDisponiveis.map<DropdownMenuItem<String>>((
            terminal,
          ) {
            return DropdownMenuItem<String>(
              value: terminal['id']!,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  terminal['nome']!,
                  style: TextStyle(
                    color: terminal['id']!.isEmpty
                        ? Colors.grey.shade600
                        : Colors.black,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCampoFilial() {
    // Carregando filiais
    if (_carregandoFiliais) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade400, width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              color: Color(0xFF0D47A1),
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    // Terminal não selecionado
    if (_terminalSelecionadoId == null || _terminalSelecionadoId!.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          border: Border.all(color: Colors.grey.shade400, width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Selecione um terminal primeiro',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Nenhuma filial disponível
    if (_filiaisDisponiveis.isEmpty ||
        (_filiaisDisponiveis.length == 1 &&
            _filiaisDisponiveis.first['id'] == '')) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          border: Border.all(color: Colors.grey.shade400, width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Nenhuma filial disponível',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Dropdown normal com filiais
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade400, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _filialSelecionadaId,
          isExpanded: true,
          itemHeight: 50,
          icon: const Icon(Icons.arrow_drop_down, size: 20),
          style: const TextStyle(fontSize: 13, color: Colors.black),
          onChanged: (String? novoValor) {
            setState(() {
              _filialSelecionadaId = novoValor;
              if (novoValor != null && novoValor.isNotEmpty) {
                final filial = _filiaisDisponiveis.firstWhere(
                  (f) => f['id'] == novoValor,
                  orElse: () => {'id': '', 'nome': ''},
                );
                _filialSelecionadaNome = filial['nome'];
              } else {
                _filialSelecionadaNome = null;
              }
            });
          },
          items: _filiaisDisponiveis.map<DropdownMenuItem<String>>((filial) {
            return DropdownMenuItem<String>(
              value: filial['id']!,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  filial['nome']!,
                  style: TextStyle(
                    color: filial['id']!.isEmpty
                        ? Colors.grey.shade600
                        : Colors.black,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCampoProduto() {
    // Carregando produtos
    if (_carregandoProdutos) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade400, width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              color: Color(0xFF0D47A1),
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    // Terminal não selecionado
    if (_terminalSelecionadoId == null || _terminalSelecionadoId!.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          border: Border.all(color: Colors.grey.shade400, width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Selecione um terminal primeiro',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Nenhum produto disponível
    if (_produtosDisponiveis.isEmpty ||
        (_produtosDisponiveis.length == 1 &&
            _produtosDisponiveis.first['id'] == '')) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          border: Border.all(color: Colors.grey.shade400, width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Nenhum produto disponível',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Dropdown normal com produtos
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade400, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _produtoSelecionadoId,
          isExpanded: true,
          itemHeight: 50,
          icon: const Icon(Icons.arrow_drop_down, size: 20),
          style: const TextStyle(fontSize: 13, color: Colors.black),
          onChanged: (String? novoValor) {
            setState(() {
              _produtoSelecionadoId = novoValor;
            });
          },
          items: _produtosDisponiveis.map<DropdownMenuItem<String>>((produto) {
            return DropdownMenuItem<String>(
              value: produto['id']!,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  produto['nome']!,
                  style: TextStyle(
                    color: produto['id']!.isEmpty
                        ? Colors.grey.shade600
                        : Colors.black,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCardResumo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.summarize, color: const Color(0xFF0D47A1), size: 18),
              const SizedBox(width: 8),
              const Text(
                'Resumo dos Filtros',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0D47A1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Grid de itens do resumo
          Wrap(
            spacing: 24,
            runSpacing: 16,
            children: [
              _buildItemResumo(
                icon: Icons.store,
                label: 'Filial',
                value: _filialSelecionadaNome ?? 'Não selecionada',
              ),
              _buildItemResumo(
                icon: Icons.settings_input_component,
                label: 'Terminal',
                value: _terminalSelecionadoNome ?? 'Não selecionado',
              ),
              if (widget.empresaNome != null)
                _buildItemResumo(
                  icon: Icons.business,
                  label: 'Empresa',
                  value: widget.empresaNome!,
                ),
              _buildItemResumo(
                icon: Icons.calendar_today,
                label: 'Data inicial',
                value:
                    '${_dataInicial.day.toString().padLeft(2, '0')}/${_dataInicial.month.toString().padLeft(2, '0')}/${_dataInicial.year}',
              ),
              _buildItemResumo(
                icon: Icons.calendar_today,
                label: 'Data final',
                value:
                    '${_dataFinal.day.toString().padLeft(2, '0')}/${_dataFinal.month.toString().padLeft(2, '0')}/${_dataFinal.year}',
              ),
              _buildItemResumo(
                icon: Icons.inventory_2,
                label: 'Produto',
                value:
                    _produtoSelecionadoId != null &&
                        _produtoSelecionadoId!.isNotEmpty
                    ? _produtosDisponiveis.firstWhere(
                        (prod) => prod['id'] == _produtoSelecionadoId,
                        orElse: () => {'id': '', 'nome': 'Não selecionado'},
                      )['nome']!
                    : 'Não selecionado',
              ),
              _buildItemResumo(
                icon: Icons.assessment,
                label: 'Tipo de relatório',
                value: _tipoRelatorio == 'sintetico' ? 'Sintético' : 'Analítico',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemResumo({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return SizedBox(
      width: 200,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotoes() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Botão Redefinir
          SizedBox(
            width: 140,
            height: 36,
            child: OutlinedButton(
              onPressed: _resetarFiltros,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                side: BorderSide(color: Colors.grey.shade400, width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.refresh, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Redefinir',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color.fromARGB(255, 95, 95, 95),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Botão Consultar
          SizedBox(
            width: 140,
            height: 36,
            child: ElevatedButton(
              onPressed: _irParaEstoqueProduto,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D47A1),
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Consultar',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotas() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.orange.shade200, width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.info, color: Colors.orange.shade700, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Campos obrigatórios: Terminal, Data inicial, Data final e Produto',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _terminalVinculado
                      ? 'Terminal vinculado ao seu usuário (não pode ser alterado).'
                      : 'Mostra o estoque do produto no terminal selecionado no período informado.',
                  style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
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
