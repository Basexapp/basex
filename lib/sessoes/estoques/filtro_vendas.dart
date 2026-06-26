import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_page.dart';
import 'relatorio_vendas.dart';

class FiltroVendasPage extends StatefulWidget {
  final String? terminalId;
  final String nomeTerminal;
  final String? empresaId;
  final String? empresaNome;
  final VoidCallback onVoltar;

  const FiltroVendasPage({
    super.key,
    this.terminalId,
    required this.nomeTerminal,
    this.empresaId,
    this.empresaNome,
    required this.onVoltar,
  });

  @override
  State<FiltroVendasPage> createState() => _FiltroVendasPageState();
}

class _FiltroVendasPageState extends State<FiltroVendasPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  DateTime _dataInicial = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _dataFinal = DateTime.now();
  String? _produtoSelecionado;
  String? _terminalSelecionadoId;
  String? _terminalSelecionadoNome;
  String? _empresaSelecionadaId;
  String? _empresaSelecionadaNome;
  String _tipoRelatorio = 'sintetico';
  List<Map<String, dynamic>> _produtosDisponiveis = [];
  List<Map<String, dynamic>> _terminaisDisponiveis = [];
  List<Map<String, dynamic>> _empresasDisponiveis = [];
  bool _carregandoProdutos = false;
  bool _carregandoTerminais = false;
  bool _carregandoEmpresas = false;
  bool _terminalVinculado = false;
  bool _empresaVinculada = false;
  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    final usuario = UsuarioAtual.instance;

    // Verificar se usuário tem terminal vinculado no login
    if (usuario?.terminalId != null && usuario!.terminalId!.isNotEmpty) {
      _terminalVinculado = true;
      _terminalSelecionadoId = usuario.terminalId;
      _terminalSelecionadoNome = usuario.terminalNome ?? 'Terminal vinculado';

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _carregarEmpresasPorTerminal(_terminalSelecionadoId!);
      });
    }

    // Verificar se usuário tem empresa vinculada no login
    if (usuario?.empresaId != null && usuario!.empresaId!.isNotEmpty) {
      _empresaVinculada = true;
      _empresaSelecionadaId = usuario.empresaId;
      _empresaSelecionadaNome = usuario.empresaNome ?? 'Empresa vinculada';
      _empresasDisponiveis = [
        {'id': _empresaSelecionadaId!, 'nome': _empresaSelecionadaNome!},
      ];
    } else {
      _empresaVinculada = false;
      _empresaSelecionadaId = '';
      _empresaSelecionadaNome = null;
      _empresasDisponiveis = [];
    }

    _carregarTerminaisDisponiveis();
    _carregarProdutosDisponiveis();
  }

  Future<void> _carregarEmpresasPorTerminal(String terminalId) async {
    setState(() {
      _carregandoEmpresas = true;
    });

    try {
      final usuario = UsuarioAtual.instance;
      if (usuario == null) return;

      if (_empresaVinculada) {
        setState(() {
          _empresasDisponiveis = [
            {'id': _empresaSelecionadaId!, 'nome': _empresaSelecionadaNome!},
          ];
        });
        return;
      }

      final response = await _supabase
          .from('relacoes_terminais')
          .select('''
            empresa_id,
            empresas!inner (
              id,
              nome_dois
            )
          ''')
          .eq('terminal_id', terminalId);

      List<Map<String, dynamic>> empresas = [];
      empresas.add({'id': '', 'nome': '<selecione>'});

      final Map<String, String> empresasUnicas = {};

      for (var item in response) {
        final empData = item['empresas'] as Map<String, dynamic>?;
        if (empData != null) {
          final id = empData['id']?.toString();
          final nome = empData['nome_dois']?.toString() ?? 'Empresa sem nome';
          if (id != null && !empresasUnicas.containsKey(id)) {
            empresasUnicas[id] = nome;
            empresas.add({'id': id, 'nome': nome});
          }
        }
      }

      setState(() {
        _empresasDisponiveis = empresas;

        if (empresas.length == 2) {
          _empresaSelecionadaId = empresas[1]['id'];
          _empresaSelecionadaNome = empresas[1]['nome'];
        } else {
          _empresaSelecionadaId = '';
          _empresaSelecionadaNome = null;
        }
      });
    } catch (e) {
      debugPrint('❌ Erro ao carregar empresas por terminal: $e');
      setState(() {
        _empresasDisponiveis = [
          {'id': '', 'nome': '<erro ao carregar empresas>'},
        ];
        _empresaSelecionadaId = '';
        _empresaSelecionadaNome = null;
      });
    } finally {
      setState(() => _carregandoEmpresas = false);
    }
  }

  Future<void> _carregarTerminaisDisponiveis() async {
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

      String? empresaId = usuario.empresaId;
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
        if (terminais.length == 1) {
          _terminalSelecionadoId = terminais.first['id'];
          _terminalSelecionadoNome = terminais.first['nome'];
        } else {
          _terminalSelecionadoId = '';
          _terminalSelecionadoNome = null;
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

  Future<void> _carregarProdutosDisponiveis() async {
    setState(() => _carregandoProdutos = true);
    
    try {
      // Buscar apenas produtos dos grupos 2 e 3
      final dados = await _supabase
          .from('produtos')
          .select('id, nome')
          .or('grupo.eq.1,grupo.eq.3')
          .order('nome');

      final List<Map<String, dynamic>> produtos = [];

      produtos.add({'id': 'todos', 'nome': 'Todos os produtos'});
      produtos.add({'id': '', 'nome': '<selecione>'});
      
      for (var produto in dados) {
        produtos.add({
          'id': produto['id'].toString(),
          'nome': produto['nome'].toString(),
        });
      }

      setState(() {
        _produtosDisponiveis = produtos;
        _produtoSelecionado = '';
      });
      
    } catch (e) {
      debugPrint("❌ Erro ao carregar produtos: $e");
      setState(() {
        _produtosDisponiveis = [
          {'id': '', 'nome': '<selecione>'}
        ];
        _produtoSelecionado = '';
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
                    // Header
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

                    // Mês e Ano
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

                    // Dias da semana
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

                    // Dias do mês
                    GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: 7,
                      childAspectRatio: 1.0,
                      children: _getDaysInMonth(tempDate).map((day) {
                        final isSelected = day != null && day == tempDate.day;
                        final isToday = day != null &&
                            day == DateTime.now().day &&
                            tempDate.month == DateTime.now().month &&
                            tempDate.year == DateTime.now().year;

                        return StatefulBuilder(
                          builder: (context, setDayState) {
                            return MouseRegion(
                              cursor: day != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
                              onEnter: (_) { if (day != null) { setDayState(() => hoveredDay = day); } },
                              onExit: (_) { if (day != null) { setDayState(() => hoveredDay = null); } },
                              child: GestureDetector(
                                onTap: day != null
                              ? () {
                                  setStateDialog(() {
                                    tempDate = DateTime(tempDate.year, tempDate.month, day);
                                  });
                                }
                              : null,
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

                    // Botões
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
                    // Header
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

                    // Mês e Ano
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

                    // Dias da semana
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

                    // Dias do mês
                    GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: 7,
                      childAspectRatio: 1.0,
                      children: _getDaysInMonth(tempDate).map((day) {
                        final isSelected = day != null && day == tempDate.day;
                        final isToday = day != null &&
                            day == DateTime.now().day &&
                            tempDate.month == DateTime.now().month &&
                            tempDate.year == DateTime.now().year;

                        return StatefulBuilder(
                          builder: (context, setDayState) {
                            return MouseRegion(
                              cursor: day != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
                              onEnter: (_) { if (day != null) { setDayState(() => hoveredDay = day); } },
                              onExit: (_) { if (day != null) { setDayState(() => hoveredDay = null); } },
                              child: GestureDetector(
                                onTap: day != null
                              ? () {
                                  setStateDialog(() {
                                    tempDate = DateTime(tempDate.year, tempDate.month, day);
                                  });
                                }
                              : null,
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

                    // Botões
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

  void _irParaEstoqueMes() {
    if (_dataInicial.isAfter(_dataFinal)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A data inicial não pode ser posterior à data final.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_produtoSelecionado == null || _produtoSelecionado!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecione um produto.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final String? terminalToPass = (_terminalSelecionadoId != null && _terminalSelecionadoId!.isNotEmpty)
        ? _terminalSelecionadoId
        : null;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RelatorioVendasPage(
          terminalId: terminalToPass,
          nomeTerminal: _terminalSelecionadoNome ?? 'Terminal não selecionado',
          empresaId: (_empresaSelecionadaId != null && _empresaSelecionadaId!.isNotEmpty)
              ? _empresaSelecionadaId
              : widget.empresaId,
          dataInicial: _dataInicial,
          dataFinal: _dataFinal,
          produtoFiltro: _produtoSelecionado,
          tipoRelatorio: _tipoRelatorio,
        ),
      ),
    );
  }

  void _resetarFiltros() {
    final agora = DateTime.now();
    setState(() {
      _dataInicial = DateTime(agora.year, agora.month, 1);
      _dataFinal = agora;
      _produtoSelecionado = '';
      _tipoRelatorio = 'sintetico';
    });
    _carregarProdutosDisponiveis();
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
              'Filtros de Vendas',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              widget.nomeTerminal,
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
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _carregando
            ? _buildCarregando()
            : _buildConteudo(),
      ),
    );
  }

  Widget _buildCarregando() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF0D47A1)),
          SizedBox(height: 20),
          Text(
            'Carregando filtros...',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
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
                Icon(Icons.filter_alt, color: const Color(0xFF0D47A1), size: 20),
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

          // Linha com os filtros
          Row(
            children: [
              // Campo Mês de Referência ou Data Específica
              // Campo Terminal
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Terminal',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (_carregandoTerminais)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade400, width: 1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: const Color(0xFF0D47A1),
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
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
                                      } else {
                                        _terminalSelecionadoNome = null;
                                      }
                                      _empresaSelecionadaId = '';
                                      _empresaSelecionadaNome = null;
                                      _empresasDisponiveis = [];
                                    });

                                    if (novoValor != null && novoValor.isNotEmpty) {
                                      await _carregarEmpresasPorTerminal(novoValor);
                                    }
                                  },
                            items: _terminaisDisponiveis.map<DropdownMenuItem<String>>((terminal) {
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
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Campo Empresa
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Empresa',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (_empresaVinculada)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          border: Border.all(color: Colors.grey.shade400, width: 1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _empresaSelecionadaId,
                            isExpanded: true,
                            itemHeight: 50,
                            icon: const SizedBox.shrink(),
                            style: const TextStyle(fontSize: 13, color: Colors.black),
                            onChanged: null,
                            items: _empresasDisponiveis.map<DropdownMenuItem<String>>((empresa) {
                              return DropdownMenuItem<String>(
                                value: empresa['id']!,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    empresa['nome']!,
                                    style: const TextStyle(color: Colors.black),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      )
                    else if (_carregandoEmpresas)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade400, width: 1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: const Color(0xFF0D47A1),
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      )
                    else if (_terminalSelecionadoId == null || _terminalSelecionadoId!.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          border: Border.all(color: Colors.grey.shade400, width: 1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Selecione um terminal primeiro',
                          style: TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                      )
                    else if (_empresasDisponiveis.isEmpty ||
                        (_empresasDisponiveis.length == 1 && _empresasDisponiveis.first['id'] == ''))
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          border: Border.all(color: Colors.grey.shade400, width: 1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Nenhuma empresa disponível',
                          style: TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade400, width: 1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _empresaSelecionadaId,
                            isExpanded: true,
                            itemHeight: 50,
                            icon: const Icon(Icons.arrow_drop_down, size: 20),
                            style: const TextStyle(fontSize: 13, color: Colors.black),
                            onChanged: (String? novoValor) {
                              setState(() {
                                _empresaSelecionadaId = novoValor;
                                if (novoValor != null && novoValor.isNotEmpty) {
                                  final empresa = _empresasDisponiveis.firstWhere(
                                    (e) => e['id'] == novoValor,
                                    orElse: () => {'id': '', 'nome': ''},
                                  );
                                  _empresaSelecionadaNome = empresa['nome'];
                                } else {
                                  _empresaSelecionadaNome = null;
                                }
                              });
                            },
                            items: _empresasDisponiveis.map<DropdownMenuItem<String>>((empresa) {
                              return DropdownMenuItem<String>(
                                value: empresa['id']!,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    empresa['nome']!,
                                    style: TextStyle(
                                      color: empresa['id']!.isEmpty
                                          ? Colors.grey.shade600
                                          : Colors.black,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Campo Data Inicial
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade400, width: 1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_dataInicial.day.toString().padLeft(2, '0')}/${_dataInicial.month.toString().padLeft(2, '0')}/${_dataInicial.year}',
                              style: const TextStyle(fontSize: 13, color: Colors.black),
                            ),
                            Icon(Icons.calendar_today, color: Colors.grey.shade600, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Campo Data Final
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade400, width: 1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_dataFinal.day.toString().padLeft(2, '0')}/${_dataFinal.month.toString().padLeft(2, '0')}/${_dataFinal.year}',
                              style: const TextStyle(fontSize: 13, color: Colors.black),
                            ),
                            Icon(Icons.calendar_today, color: Colors.grey.shade600, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Campo Produto
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
                    if (_carregandoProdutos)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade400, width: 1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: const Color(0xFF0D47A1),
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade400, width: 1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _produtoSelecionado,
                            isExpanded: true,
                            itemHeight: 50,
                            icon: const Icon(Icons.arrow_drop_down, size: 20),
                            style: const TextStyle(fontSize: 13, color: Colors.black),
                            onChanged: (String? novoValor) {
                              setState(() {
                                _produtoSelecionado = novoValor;
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
                      ),
                  ],
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Campo Tipo de Relatório
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
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade400, width: 1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _tipoRelatorio,
                          isExpanded: true,
                          itemHeight: 50,
                          icon: const Icon(Icons.arrow_drop_down, size: 20),
                          style: const TextStyle(fontSize: 13, color: Colors.black),
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
                label: 'Terminal',
                value: _terminalSelecionadoNome ?? 'Não selecionado',
              ),
              _buildItemResumo(
                icon: Icons.business,
                label: 'Empresa',
                value: _empresaSelecionadaNome ?? widget.empresaNome ?? 'Não selecionada',
              ),
              _buildItemResumo(
                icon: Icons.calendar_today,
                label: 'Período',
                value: '${_dataInicial.day.toString().padLeft(2, '0')}/${_dataInicial.month.toString().padLeft(2, '0')}/${_dataInicial.year} a ${_dataFinal.day.toString().padLeft(2, '0')}/${_dataFinal.month.toString().padLeft(2, '0')}/${_dataFinal.year}',
              ),
              _buildItemResumo(
                icon: Icons.inventory_2,
                label: 'Produto',
                value: _produtoSelecionado != null && _produtoSelecionado!.isNotEmpty
                  ? _produtosDisponiveis
                      .firstWhere(
                        (prod) => prod['id'] == _produtoSelecionado,
                        orElse: () => {'id': '', 'nome': 'Não selecionado'}
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
          Icon(
            icon,
            size: 14,
            color: Colors.grey.shade600,
          ),
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
          
          // Botão Consultar Estoque
          SizedBox(
            width: 140,
            height: 36,
            child: ElevatedButton(
              onPressed: _irParaEstoqueMes,
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
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
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
                  'Campos obrigatórios: Data inicial, Data final e Produto',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'O tipo de relatório determina o nível de detalhamento da consulta.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.orange.shade700,
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