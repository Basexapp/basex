import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_page.dart';

class FiltroControleAditivoPage extends StatefulWidget {
  final String? terminalId;
  final String? empresaId;
  final String nomeTerminal;
  final String? empresaNome;
  final DateTime? dataInicial;
  final DateTime? dataFinal;
  final String? tipoRelatorio;
  final Function({
    required String? terminalId,
    required String? empresaId,
    required String nomeTerminal,
    String? empresaNome,
    required DateTime dataInicial,
    required DateTime dataFinal,
    required String tipoRelatorio,
  }) onConsultar;
  final VoidCallback onVoltar;

  const FiltroControleAditivoPage({
    super.key,
    this.terminalId,
    this.empresaId,
    required this.nomeTerminal,
    this.empresaNome,
    this.dataInicial,
    this.dataFinal,
    this.tipoRelatorio,
    required this.onConsultar,
    required this.onVoltar,
  });

  @override
  State<FiltroControleAditivoPage> createState() =>
      _FiltroControleAditivoPageState();
}

class _FiltroControleAditivoPageState extends State<FiltroControleAditivoPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  late DateTime _dataInicial;
  late DateTime _dataFinal;
  String? _terminalSelecionadoId;
  String? _terminalSelecionadoNome;
  String? _empresaSelecionadaId;
  String? _empresaSelecionadaNome;
  late String _tipoRelatorio;
  List<Map<String, dynamic>> _terminaisDisponiveis = [];
  List<Map<String, dynamic>> _empresasDisponiveis = [];
  bool _carregandoTerminais = false;
  bool _carregandoEmpresas = false;
  bool _carregando = false;
  bool _terminalVinculado = false;

  @override
  void initState() {
    super.initState();
    _dataInicial = widget.dataInicial ?? DateTime(DateTime.now().year, DateTime.now().month, 1);
    _dataFinal = widget.dataFinal ?? DateTime.now();
    _tipoRelatorio = widget.tipoRelatorio ?? 'sintetico';
    _inicializarFiltros();
  }

  Future<void> _inicializarFiltros() async {
    setState(() => _carregando = true);

    final usuario = UsuarioAtual.instance;

    // Verificar se usuário tem terminal vinculado no login (mesma lógica do filtro estoque)
    if (usuario?.terminalId != null && usuario!.terminalId!.isNotEmpty) {
      _terminalVinculado = true;
      _terminalSelecionadoId = usuario.terminalId;
      _terminalSelecionadoNome = usuario.terminalNome ?? 'Terminal vinculado';
    }

    await _carregarTerminaisDisponiveis();

    final terminalIdInicial =
        widget.terminalId ?? usuario?.terminalId ?? '';

    if (_terminalVinculado) {
      // Já definido no bloco acima
    } else if (terminalIdInicial.isNotEmpty) {
      final encontrado = _terminaisDisponiveis.firstWhere(
        (t) => t['id'] == terminalIdInicial,
        orElse: () => <String, dynamic>{'id': '', 'nome': ''},
      );
      if (encontrado['id'] != '') {
        _terminalSelecionadoId = encontrado['id'];
        _terminalSelecionadoNome = encontrado['nome'];
      } else {
        _selecionarPrimeiroTerminal();
      }
    } else {
      _selecionarPrimeiroTerminal();
    }

    await _carregarEmpresasDisponiveis();

    setState(() => _carregando = false);
  }

  void _selecionarPrimeiroTerminal() {
    final primeiro = _terminaisDisponiveis.firstWhere(
      (t) => t['id'] != '',
      orElse: () => <String, dynamic>{'id': '', 'nome': ''},
    );
    if (primeiro['id'] != '') {
      _terminalSelecionadoId = primeiro['id'];
      _terminalSelecionadoNome = primeiro['nome'];
    } else {
      _terminalSelecionadoId = '';
      _terminalSelecionadoNome = null;
    }
  }

  Future<void> _carregarTerminaisDisponiveis() async {
    // Se usuário já tem terminal vinculado, não precisa carregar lista (Lógica copiada do filtro estoque)
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
      final nivelUsuario = usuario?.nivel ?? 0;
      final empresaIdEfetivo =
          (widget.empresaId ?? usuario?.empresaId ?? '').trim();
      List<Map<String, dynamic>> terminais = [];

      if (nivelUsuario == 4) {
        final terminalId =
            (widget.terminalId ?? usuario?.terminalId ?? '').trim();
        if (terminalId.isNotEmpty) {
          final dados = await _supabase
              .from('terminais')
              .select('id, nome')
              .eq('id', terminalId)
              .limit(1);
          if (dados.isNotEmpty) {
            terminais = dados.map<Map<String, dynamic>>((t) => {
              'id': t['id'].toString(),
              'nome': t['nome'].toString(),
            }).toList();
          }
        }
        setState(() {
          _terminaisDisponiveis = terminais.isNotEmpty
              ? terminais
              : <Map<String, dynamic>>[{'id': '', 'nome': '<selecione>'}];
        });
        return;
      }

      if (empresaIdEfetivo.isNotEmpty) {
        final relacoes = await _supabase
            .from('relacoes_terminais')
            .select('terminal_id')
            .eq('empresa_id', empresaIdEfetivo);

        final terminaisIds = relacoes
            .map((r) => r['terminal_id']?.toString())
            .where((id) => id != null && id.isNotEmpty)
            .toSet()
            .toList();

        if (terminaisIds.isNotEmpty) {
          final dados = await _supabase
              .from('terminais')
              .select('id, nome')
              .filter('id', 'in', terminaisIds)
              .order('nome');

          terminais = dados.map<Map<String, dynamic>>((t) => {
            'id': t['id'].toString(),
            'nome': t['nome'].toString(),
          }).toList();
        }
      } else {
        final dados = await _supabase
            .from('terminais')
            .select('id, nome')
            .order('nome');

        terminais = dados
            .map<Map<String, dynamic>>((t) => {
              'id': t['id'].toString(),
              'nome': t['nome'].toString(),
            })
            .toList();
      }

      setState(() {
        _terminaisDisponiveis = <Map<String, dynamic>>[
          {'id': '', 'nome': '<selecione>'}
        ];
        _terminaisDisponiveis.addAll(terminais);
      });
    } catch (e) {
      debugPrint('❌ Erro ao carregar terminais: $e');
      setState(() {
        _terminaisDisponiveis = <Map<String, dynamic>>[
          {'id': '', 'nome': '<selecione>'}
        ];
      });
    } finally {
      setState(() => _carregandoTerminais = false);
    }
  }

  Future<void> _carregarEmpresasDisponiveis() async {
    setState(() => _carregandoEmpresas = true);

    try {
      final usuario = UsuarioAtual.instance;
      final nivelUsuario = usuario?.nivel ?? 0;
      
      // Se já temos a empresa no objeto do usuário, evitamos nova busca no banco
      if (usuario?.empresaId != null && usuario!.empresaId!.isNotEmpty) {
        final empresaId = usuario.empresaId!;
        final nomeEmpresa = usuario.empresaNome ?? 'Empresa vinculada';
        setState(() {
          _empresaSelecionadaId = empresaId;
          _empresaSelecionadaNome = nomeEmpresa;
          _empresasDisponiveis = [{'id': empresaId, 'nome': nomeEmpresa}];
        });
        return;
      }

      final temEmpresaFixa = (nivelUsuario == 1 || nivelUsuario == 2 || nivelUsuario == 3) && 
                            usuario?.empresaId?.isNotEmpty == true;

      if (temEmpresaFixa) {
        final empresaId = usuario?.empresaId ?? '';
        
        final dados = await _supabase
            .from('empresas')
            .select('id, nome_dois')
            .eq('id', empresaId)
            .limit(1);

        if (dados.isNotEmpty) {
          final e = dados.first;
          final nome = (e['nome_dois'] ?? '').toString();
          setState(() {
            _empresaSelecionadaId = empresaId;
            _empresaSelecionadaNome = nome;
            _empresasDisponiveis = [{'id': empresaId, 'nome': nome}];
          });
        }
        return;
      }

      List<Map<String, dynamic>> empresas = [];

      if (nivelUsuario == 4) {
        final terminalId = widget.terminalId ?? usuario?.terminalId ?? '';

        if (terminalId.isNotEmpty) {
          final relacoes = await _supabase
              .from('relacoes_terminais')
              .select('empresa_id')
              .eq('terminal_id', terminalId);

          final empresasIds = relacoes
              .map((r) => r['empresa_id']?.toString())
              .where((id) => id != null && id.isNotEmpty)
              .toSet()
              .toList();

          if (empresasIds.isNotEmpty) {
            final dados = await _supabase
                .from('empresas')
                .select('id, nome_dois')
                .filter('id', 'in', empresasIds)
                .order('nome_dois');

            empresas = dados.map<Map<String, dynamic>>((e) => {
              'id': e['id'].toString(),
              'nome': e['nome_dois'].toString(),
            }).toList();
          }
        }
      } else {
        final dados = await _supabase
            .from('empresas')
            .select('id, nome_dois')
            .order('nome_dois');

        empresas = dados
            .map<Map<String, dynamic>>((e) => {
              'id': e['id'].toString(),
              'nome': e['nome_dois'].toString(),
            })
            .toList();
      }

      setState(() {
        _empresasDisponiveis = <Map<String, dynamic>>[
          {'id': '', 'nome': '<selecione>'}
        ];
        _empresasDisponiveis.addAll(empresas);
        
        if (widget.empresaId != null && widget.empresaId!.isNotEmpty) {
          final encontrada = empresas.firstWhere(
            (e) => e['id'] == widget.empresaId,
            orElse: () => <String, dynamic>{},
          );
          if (encontrada.isNotEmpty) {
            _empresaSelecionadaId = encontrada['id'];
            _empresaSelecionadaNome = encontrada['nome'];
          }
        }
      });

    } catch (e) {
      debugPrint('❌ Erro ao carregar empresas: $e');
      setState(() {
        _empresasDisponiveis = <Map<String, dynamic>>[
          {'id': '', 'nome': '<selecione>'}
        ];
        _empresaSelecionadaId = null;
        _empresaSelecionadaNome = null;
      });
    } finally {
      setState(() => _carregandoEmpresas = false);
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
    if (selecionado != null && selecionado != _dataInicial) {
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
    if (selecionado != null && selecionado != _dataFinal) {
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

  void _consultar() {
    if (_dataInicial.isAfter(_dataFinal)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A data inicial não pode ser posterior à data final.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_terminalSelecionadoId == null || _terminalSelecionadoId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecione um terminal.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_empresaSelecionadaId == null || _empresaSelecionadaId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecione uma empresa.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    widget.onConsultar(
      terminalId: _terminalSelecionadoId,
      empresaId: _empresaSelecionadaId,
      nomeTerminal: _terminalSelecionadoNome ?? 'Terminal não selecionado',
      empresaNome: _empresaSelecionadaNome,
      dataInicial: _dataInicial,
      dataFinal: _dataFinal,
      tipoRelatorio: _tipoRelatorio,
    );
  }

  void _resetarFiltros() {
    final agora = DateTime.now();
    setState(() {
      _dataInicial = DateTime(agora.year, agora.month, 1);
      _dataFinal = agora;
      _tipoRelatorio = 'sintetico';

      // Se não tiver terminal vinculado, volta para o primeiro da lista
      if (!_terminalVinculado) {
        _selecionarPrimeiroTerminal();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final usuario = UsuarioAtual.instance;
    final nivelUsuario = usuario?.nivel ?? 0;
    final temEmpresaFixa = (nivelUsuario == 1 || nivelUsuario == 2 || nivelUsuario == 3) && 
                          usuario?.empresaId?.isNotEmpty == true;
    final temTerminalFixo = nivelUsuario == 4;

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
              'Consulta - Controle de Aditivos',
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
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _carregando
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D47A1)))
            : _buildConteudo(temEmpresaFixa, temTerminalFixo),
      ),
    );
  }

  Widget _buildConteudo(bool temEmpresaFixa, bool temTerminalFixo) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardFiltros(temEmpresaFixa, temTerminalFixo),
          const SizedBox(height: 20),
          _buildCardResumo(),
          const SizedBox(height: 20),
          _buildBotoes(),
        ],
      ),
    );
  }

  Widget _buildCardFiltros(bool temEmpresaFixa, bool temTerminalFixo) {
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
                const Icon(
                  Icons.filter_alt,
                  color: Color(0xFF0D47A1),
                  size: 20,
                ),
                const SizedBox(width: 10),
                const Text(
                  'Filtros de Pesquisa',
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

          // Linha de filtros: Terminal, Empresa, Tipo de relatório, Data inicial e Data final
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
                          const SizedBox(width: 4),
                          const Icon(Icons.lock, size: 14, color: Colors.grey),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    SizedBox(height: 50, child: _buildDropdownTerminal(temTerminalFixo)),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // 2 - Campo Empresa
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Empresa *',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(height: 50, child: _buildDropdownEmpresa(temEmpresaFixa)),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // 3 - Campo Tipo de Relatório
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Relatório',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(height: 50, child: _buildDropdownTipoRelatorio()),
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
                    _buildDataPicker(
                      '${_dataInicial.day.toString().padLeft(2, '0')}/${_dataInicial.month.toString().padLeft(2, '0')}/${_dataInicial.year}',
                      () => _selecionarDataInicial(context),
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
                    _buildDataPicker(
                      '${_dataFinal.day.toString().padLeft(2, '0')}/${_dataFinal.month.toString().padLeft(2, '0')}/${_dataFinal.year}',
                      () => _selecionarDataFinal(context),
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
  
  Widget _buildDropdownTerminal(bool temTerminalFixo) {
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
        color: (temTerminalFixo || _terminalVinculado) ? Colors.grey.shade100 : Colors.white,
        border: Border.all(color: Colors.grey.shade400, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _terminalSelecionadoId,
          isExpanded: true,
          itemHeight: 50,
          onChanged: (temTerminalFixo || _terminalVinculado) ? null : (String? novoValor) {
            setState(() {
              _terminalSelecionadoId = novoValor;
              final terminal = _terminaisDisponiveis.firstWhere((t) => t['id'] == novoValor, orElse: () => <String, dynamic>{'id': '', 'nome': ''});
              _terminalSelecionadoNome = terminal['nome'];
            });
          },
          style: const TextStyle(fontSize: 13, color: Colors.black),
          items: _terminaisDisponiveis.map<DropdownMenuItem<String>>((terminal) {
            return DropdownMenuItem<String>(
              value: terminal['id'],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  terminal['nome'],
                  style: TextStyle(
                    color: terminal['id'].isEmpty ? Colors.grey.shade600 : Colors.black,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDropdownEmpresa(bool temEmpresaFixa) {
    if (_carregandoEmpresas) {
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
        color: temEmpresaFixa ? Colors.grey.shade100 : Colors.white,
        border: Border.all(color: Colors.grey.shade400, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _empresaSelecionadaId,
          isExpanded: true,
          itemHeight: 50,
          onChanged: temEmpresaFixa ? null : (String? novoValor) {
            setState(() {
              _empresaSelecionadaId = novoValor;
              final empresa = _empresasDisponiveis.firstWhere((e) => e['id'] == novoValor, orElse: () => <String, dynamic>{'id': '', 'nome': ''});
              _empresaSelecionadaNome = empresa['nome'];
            });
          },
          style: const TextStyle(fontSize: 13, color: Colors.black),
          items: _empresasDisponiveis.map<DropdownMenuItem<String>>((empresa) {
            return DropdownMenuItem<String>(
              value: empresa['id'],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  empresa['nome'],
                  style: TextStyle(
                    color: empresa['id'].isEmpty ? Colors.grey.shade600 : Colors.black,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDropdownTipoRelatorio() {
    return Container(
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
          onChanged: (String? novoValor) => setState(() => _tipoRelatorio = novoValor!),
          items: const [
            DropdownMenuItem(
              value: 'sintetico',
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('Sintético'),
              ),
            ),
            DropdownMenuItem(
              value: 'analitico',
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('Analítico'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataPicker(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade400, width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13)),
            Icon(Icons.calendar_today, color: Colors.grey.shade600, size: 16),
          ],
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
          const Row(
            children: [
              Icon(Icons.summarize, color: Color(0xFF0D47A1), size: 18),
              SizedBox(width: 8),
              Text(
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
          Wrap(
            spacing: 24,
            runSpacing: 16,
            children: [
              _buildItemResumo(Icons.store, 'Terminal', _terminalSelecionadoNome ?? 'Não selecionado'),
              _buildItemResumo(Icons.business, 'Empresa', _empresaSelecionadaNome ?? 'Não selecionada'),
              _buildItemResumo(Icons.calendar_today, 'Período', '${_dataInicial.day.toString().padLeft(2, '0')}/${_dataInicial.month.toString().padLeft(2, '0')}/${_dataInicial.year} a ${_dataFinal.day.toString().padLeft(2, '0')}/${_dataFinal.month.toString().padLeft(2, '0')}/${_dataFinal.year}'),
              _buildItemResumo(Icons.assessment, 'Tipo', _tipoRelatorio == 'sintetico' ? 'Sintético' : 'Analítico'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemResumo(IconData icon, String label, String value) {
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
                Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotoes() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 140,
          height: 36,
          child: OutlinedButton(
            onPressed: _resetarFiltros,
            style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.refresh, size: 16), SizedBox(width: 6), Text('Redefinir')]),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 140,
          height: 36,
          child: ElevatedButton(
            onPressed: _consultar,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.search, size: 16), SizedBox(width: 6), Text('Consultar')]),
          ),
        ),
      ],
    );
  }
}
