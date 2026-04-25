import "package:flutter/material.dart";
import "dart:math" as math;
import "package:supabase_flutter/supabase_flutter.dart";
import "../../login_page.dart";

class RadarPage extends StatefulWidget {
  final VoidCallback onVoltar;

  const RadarPage({super.key, required this.onVoltar});

  @override
  State<RadarPage> createState() => _RadarPageState();
}

class _RadarPageState extends State<RadarPage> {
  final supabase = Supabase.instance.client;
  final PageController _pageController = PageController();
  double _currentPage = 0.0;

  bool _carregando = true;
  List<Map<String, dynamic>> _terminais = [];
  List<String> produtos = [];
  
  // filtros
  String? produtoSelecionado;
  String? tipoOperacaoSelecionada; // "Carga" ou "Descarga"
  DateTime? dataFiltro;
  final TextEditingController dataFiltroCtrl = TextEditingController();
  final TextEditingController terminalController = TextEditingController();
  String? _terminalSelecionado;
  String _busca = '';
  int? _nivel;
  Map<String, dynamic>? _usuarioData;

  final List<Map<String, dynamic>> _estagios = [
    {
      "titulo": "Programado",
      "cor": const Color(0xFF2196F3),
      "icone": Icons.calendar_today,
      "descricao": "Veículos agendados para chegada.",
      "qtd": 12,
    },
    {
      "titulo": "Em fila",
      "cor": const Color(0xFFFF9800),
      "icone": Icons.hourglass_empty,
      "descricao": "Veículos aguardando entrada no terminal.",
      "qtd": 5,
    },
    {
      "titulo": "Em operação",
      "cor": const Color(0xFF4CAF50),
      "icone": Icons.local_shipping,
      "descricao": "Veículos em processo de carga/descarga.",
      "qtd": 8,
    },
    {
      "titulo": "Liberados",
      "cor": const Color(0xFF9E9E9E),
      "icone": Icons.check_circle_outline,
      "descricao": "Veículos que já concluíram a operação.",
      "qtd": 24,
    },
  ];

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page ?? 0.0;
      });
    });
    _carregarDadosIniciais();
  }

  @override
  void dispose() {
    _pageController.dispose();
    dataFiltroCtrl.dispose();
    terminalController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _obterDadosUsuario() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return null;
      return await supabase
          .from('usuarios')
          .select('id, nome, nivel, id_filial, terminal_id')
          .eq('id', user.id)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }

  Future<void> _carregarDadosIniciais() async {
    setState(() => _carregando = true);
    try {
      _usuarioData = await _obterDadosUsuario();
      if (_usuarioData == null) return;
      
      _nivel = _usuarioData!['nivel'] as int?;
      await _carregarProdutos();
      
      final terminalId = UsuarioAtual.instance?.terminalId ?? _usuarioData!['terminal_id'];
      if (_nivel == 3) {
        await _carregarTerminais();
      }
      
      dataFiltro = DateTime.now();
      dataFiltroCtrl.text = _formatarData(dataFiltro!.toIso8601String());
      
      if (_nivel != 3) {
        _terminalSelecionado = terminalId;
        await _carregarNomeTerminal(_terminalSelecionado);
      }
    } catch (e) {
      debugPrint('Erro ao carregar dados: $e');
    } finally {
      setState(() => _carregando = false);
    }
  }

  Future<void> _carregarProdutos() async {
    try {
      final dados = await supabase.from('produtos').select('nome').order('nome');
      setState(() {
        produtos = List<Map<String, dynamic>>.from(dados).map((p) => p['nome'].toString()).toList();
      });
    } catch (_) {}
  }

  Future<void> _carregarNomeTerminal(String? terminalId) async {
    if (terminalId == null) {
      terminalController.clear();
      return;
    }
    try {
      final r = await supabase.from('terminais').select('nome').eq('id', terminalId).maybeSingle();
      setState(() {
        terminalController.text = r != null ? (r['nome']?.toString() ?? terminalId) : terminalId;
      });
    } catch (_) {
      setState(() => terminalController.text = terminalId);
    }
  }

  Future<void> _carregarTerminais() async {
    try {
      final dados = await supabase.from('terminais').select('id, nome').order('nome');
      setState(() {
        _terminais = List<Map<String, dynamic>>.from(dados);
      });
    } catch (_) {}
  }

  String _formatarData(String? d) {
    if (d == null) return '-';
    final dt = DateTime.parse(d);
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  Future<void> _refreshData() async {
    // Implementar lógica de atualização baseada nos filtros se necessário
    // Por enquanto, apenas simulando recarga
    setState(() => _carregando = true);
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() => _carregando = false);
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

  Widget _buildCardFiltros() {
    if (_usuarioData == null) return const SizedBox();
    final isAdmin = _nivel == 3;
    
    return Card(
      color: const Color(0xFFFAFAFA),
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filtros de Busca',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D47A1),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Produto
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: produtoSelecionado,
                    decoration: const InputDecoration(
                      labelText: 'Produto',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.local_gas_station, size: 18),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Todos os produtos', style: TextStyle(fontSize: 13)),
                      ),
                      ...produtos.map((p) => DropdownMenuItem(
                        value: p,
                        child: Text(p, style: const TextStyle(fontSize: 13)),
                      )).toList(),
                    ],
                    onChanged: (value) {
                      setState(() => produtoSelecionado = value);
                      _refreshData();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Tipo de Operação (Carga/Descarga)
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: tipoOperacaoSelecionada,
                    decoration: const InputDecoration(
                      labelText: 'Operação',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.swap_horiz, size: 18),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Todas', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 'Carga', child: Text('Carga', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 'Descarga', child: Text('Descarga', style: TextStyle(fontSize: 13))),
                    ],
                    onChanged: (value) {
                      setState(() => tipoOperacaoSelecionada = value);
                      _refreshData();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Terminal
                Expanded(
                  child: isAdmin
                      ? DropdownButtonFormField<String>(
                          value: _terminalSelecionado,
                          decoration: const InputDecoration(
                            labelText: 'Terminal',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.business, size: 18),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            isDense: true,
                          ),
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Todos os terminais', style: TextStyle(fontSize: 13)),
                            ),
                            ..._terminais.map((terminal) => DropdownMenuItem(
                              value: terminal['id'].toString(),
                              child: Text(terminal['nome'].toString(), style: const TextStyle(fontSize: 13)),
                            )).toList(),
                          ],
                          onChanged: (value) {
                            setState(() => _terminalSelecionado = value);
                            _refreshData();
                          },
                        )
                      : TextFormField(
                          controller: terminalController,
                          decoration: const InputDecoration(
                            labelText: 'Terminal',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.business, size: 18),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            isDense: true,
                          ),
                          readOnly: true,
                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                        ),
                ),
                const SizedBox(width: 8),
                // Data
                Expanded(
                  child: Builder(builder: (context) {
                    final textoData = dataFiltro != null
                        ? '${dataFiltro!.day.toString().padLeft(2, '0')}/${dataFiltro!.month.toString().padLeft(2, '0')}/${dataFiltro!.year}'
                        : 'Data';

                    return InkWell(
                      onTap: () async {
                        DateTime tempDate = dataFiltro ?? DateTime.now();
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
                                            const Text('Filtrar por data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF0D47A1))),
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
                            dataFiltro = DateTime(
                              dataSelecionada.year,
                              dataSelecionada.month,
                              dataSelecionada.day,
                            );
                            dataFiltroCtrl.text = _formatarData(dataFiltro!.toIso8601String());
                          });
                          _refreshData();
                        }
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.centerLeft,
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
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                textoData,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF0D47A1),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(width: 8),
                // Buscar
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Buscar',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search, size: 18),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                      hintText: 'Placa...',
                    ),
                    onChanged: (value) => setState(() => _busca = value),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0D47A1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onVoltar,
        ),
        title: const Text(
          "Radar de Operações",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          widget.onVoltar();
        },
        child: Column(
          children: [
            _buildCardFiltros(),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: _carregando 
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        itemCount: _estagios.length,
                        itemBuilder: (context, index) {
                          final estagio = _estagios[index];
                          final bool isLast = index == _estagios.length - 1;

                          return IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Timeline Axis
                                Column(
                                  children: [
                                    // Círculo do Estágio
                                    MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _currentPage = index.toDouble();
                                          });
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 100),
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: _currentPage.round() == index
                                                ? estagio["cor"]
                                                : Colors.grey.shade100,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: _currentPage.round() == index
                                                  ? estagio["cor"]
                                                  : Colors.grey.shade300,
                                              width: 2,
                                            ),
                                          ),
                                          child: Icon(
                                            estagio["icone"],
                                            size: 20,
                                            color: _currentPage.round() == index
                                                ? Colors.white
                                                : Colors.grey.shade400,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Linha Conectora
                                    if (!isLast)
                                      Expanded(
                                        child: Container(
                                          width: 2,
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                // Conteúdo do Card
                                Expanded(
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _currentPage = index.toDouble();
                                        });
                                      },
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 4),
                                          Text(
                                            estagio["titulo"],
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: _currentPage.round() == index
                                                  ? estagio["cor"]
                                                  : Colors.grey.shade700,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            estagio["descricao"],
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: estagio["cor"].withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              "${estagio["qtd"]} veículos",
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: estagio["cor"],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

