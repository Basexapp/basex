import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ControleDescargasPage extends StatefulWidget {
  final VoidCallback onVoltar;

  const ControleDescargasPage({
    super.key,
    required this.onVoltar,
  });

  @override
  State<ControleDescargasPage> createState() => _ControleDescargasPageState();
}

class _ControleDescargasPageState extends State<ControleDescargasPage> with WidgetsBindingObserver {
  bool carregando = true;
  bool buscando = false;
  List<Map<String, dynamic>> descargas = [];
  List<Map<String, dynamic>> descargasFiltradas = [];
  List<Map<String, dynamic>> terminais = [];
  List<Map<String, dynamic>> produtosDisponiveis = [];
  
  int paginaAtual = 1;
  int totalPaginas = 1;
  int totalRegistros = 0;
  final int limitePorPagina = 10;
  
  DateTime? dataInicialEmissao;
  DateTime? dataFinalEmissao;
  DateTime? dataInicialDescarga;
  DateTime? dataFinalDescarga;
  String? terminalSelecionadoId;
  String? produtoSelecionado;
  int? _hoverIndex;
  
  final TextEditingController dataInicialEmissaoController = TextEditingController();
  final TextEditingController dataFinalEmissaoController = TextEditingController();
  final TextEditingController dataInicialDescargaController = TextEditingController();
  final TextEditingController dataFinalDescargaController = TextEditingController();
  final TextEditingController buscaGeralController = TextEditingController();

  Map<String, dynamic>? _usuarioData;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Definir data final como hoje
    dataFinalEmissao = DateTime.now();
    dataFinalEmissaoController.text = _formatarData(dataFinalEmissao);

    // Definir data inicial como hoje - 30 dias corridos
    dataInicialEmissao = DateTime.now().subtract(const Duration(days: 30));
    dataInicialEmissaoController.text = _formatarData(dataInicialEmissao);
    
    _carregarDadosIniciais();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    dataInicialEmissaoController.dispose();
    dataFinalEmissaoController.dispose();
    dataInicialDescargaController.dispose();
    dataFinalDescargaController.dispose();
    buscaGeralController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshData();
    }
  }

  Future<Map<String, dynamic>?> _obterDadosUsuario() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) return null;

      return await supabase
          .from('usuarios')
          .select('id, nome, nivel, id_filial, senha_temporaria, Nome_apelido')
          .eq('id', user.id)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }

  Future<void> _refreshData() async {
    await _aplicarFiltros(resetarPagina: true);
  }

  Future<void> _carregarDadosIniciais() async {
    setState(() => carregando = true);
    
    try {
      final supabase = Supabase.instance.client;
      _usuarioData = await _obterDadosUsuario();
      
      if (_usuarioData == null) {
        setState(() => carregando = false);
        return;
      }
      
      // Carregar terminais reais para o filtro
      final terminaisResponse = await supabase
          .from('terminais')
          .select('id, nome_dois')
          .order('nome_dois');
      
      // Carregar produtos reais para o filtro
      final produtosResponse = await supabase
          .from('produtos')
          .select('id, nome')
          .order('nome');

      setState(() {
        terminais = List<Map<String, dynamic>>.from(terminaisResponse);
        produtosDisponiveis = List<Map<String, dynamic>>.from(produtosResponse);
      });

      await _aplicarFiltros();
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar dados: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => carregando = false);
    }
  }

  Future<void> _aplicarFiltros({bool resetarPagina = true}) async {
    if (resetarPagina) {
      paginaAtual = 1;
    }

    setState(() => buscando = true);

    try {
      final supabase = Supabase.instance.client;
      
      // Iniciar a query SEM .order() para manter o tipo PostgrestFilterBuilder
      // e poder encadear filtros antes de executar
      var query = supabase
          .from('movimentacoes')
          .select('''
            *,
            motoristas!motorista_id(nome),
            produtos!produto_id(nome),
            transportadoras!transportadora_id(nome_dois),
            terminal_orig:terminais!terminal_orig_id(nome_dois),
            terminal_dest:terminais!terminal_dest_id(nome_dois)
          ''')
          .eq('tipo_mov_dest', 'entrada');

      // Filtros de Data de Emissão (usando data_mov como emissão/data do movimento)
      if (dataInicialEmissao != null) {
        query = query.gte('data_mov', dataInicialEmissao!.toIso8601String());
      }
      if (dataFinalEmissao != null) {
        final fimDia = DateTime(dataFinalEmissao!.year, dataFinalEmissao!.month, dataFinalEmissao!.day, 23, 59, 59);
        query = query.lte('data_mov', fimDia.toIso8601String());
      }

      // Filtros de Data de Descarga
      if (dataInicialDescarga != null) {
        query = query.gte('data_descarga', dataInicialDescarga!.toIso8601String());
      }
      if (dataFinalDescarga != null) {
        final fimDia = DateTime(dataFinalDescarga!.year, dataFinalDescarga!.month, dataFinalDescarga!.day, 23, 59, 59);
        query = query.lte('data_descarga', fimDia.toIso8601String());
      }

      // Filtro de Terminal (Destino, onde ocorre a descarga)
      if (terminalSelecionadoId != null) {
        query = query.eq('terminal_dest_id', terminalSelecionadoId!);
      }

      // Filtro de Produto
      if (produtoSelecionado != null) {
        final produtoObj = produtosDisponiveis.firstWhere(
          (p) => p['nome'] == produtoSelecionado,
          orElse: () => {},
        );
        if (produtoObj.isNotEmpty) {
          query = query.eq('produto_id', produtoObj['id']);
        }
      }

      // .order() aplicado no final, após todos os filtros
      final response = await query.order('data_descarga', ascending: true);

      setState(() {
        descargas = List<Map<String, dynamic>>.from(response);
        _filtrarResultadosLocais();
      });

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro na busca: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => buscando = false);
    }
  }

  void _filtrarResultadosLocais() {
    final search = buscaGeralController.text.toLowerCase().trim();
    
    descargasFiltradas = descargas.where((item) {
      // Nota: Os filtros de data, terminal e produto já foram aplicados na query do Supabase.
      // Aqui aplicamos apenas a Pesquisa Geral sobre os dados retornados e mapeados.

      if (search.isEmpty) return true;

      // Mapeamento dos campos para busca textual (seguindo a estrutura do Supabase)
      final dataEmissaoText = _formatarData(item['data_mov']).toLowerCase();
      final notaFiscal = (item['nota_fiscal'] ?? '').toString().toLowerCase();
      final qtdAmb = (item['entrada_amb'] ?? '').toString().toLowerCase();
      final qtd20 = (item['entrada_vinte'] ?? '').toString().toLowerCase();
      final produto = (item['produtos']?['nome'] ?? '').toString().toLowerCase();
      final motorista = (item['motoristas']?['nome'] ?? '').toString().toLowerCase();
      final transportadora = (item['transportadoras']?['nome_dois'] ?? '').toString().toLowerCase();
      final placas = (item['placa']?.toString() ?? '').toLowerCase();
      
      // Capturar valor da coluna Origem conforme lógica exibida na tabela
      final origemValor = item['tipo_op'] == 'compra' 
          ? (item['cliente'] ?? '') 
          : (item['terminal_orig']?['nome_dois'] ?? '');
      final origem = origemValor.toString().toLowerCase();
      
      final dataDescargaText = _formatarData(item['data_descarga']).toLowerCase();
      final obs = (item['observacoes'] ?? '').toString().toLowerCase();

      return dataEmissaoText.contains(search) ||
             notaFiscal.contains(search) ||
             qtdAmb.contains(search) ||
             qtd20.contains(search) ||
             produto.contains(search) ||
             motorista.contains(search) ||
             transportadora.contains(search) ||
             placas.contains(search) ||
             origem.contains(search) ||
             dataDescargaText.contains(search) ||
             obs.contains(search);
    }).toList();

    setState(() {
      totalRegistros = descargasFiltradas.length;
      totalPaginas = (totalRegistros / limitePorPagina).ceil();
      if (totalPaginas == 0) totalPaginas = 1;
    });
  }

  String _formatarData(dynamic data) {
    if (data == null) return '-';
    try {
      final d = DateTime.parse(data.toString());
      return '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/'
          '${d.year}';
    } catch (_) {
      return data.toString();
    }
  }

  String _formatarNumero(dynamic valor) {
    if (valor == null) return '0';
    try {
      double numero = double.parse(valor.toString());
      // Formata com ponto de milhar e remove decimais (arredondando para inteiro conforme solicitação "123.456")
      String parteInteira = numero.round().toString();
      final RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
      return parteInteira.replaceAllMapped(reg, (Match m) => '${m[1]}.');
    } catch (_) {
      return valor.toString();
    }
  }

  Widget _buildCardFiltros() {
    return Card(
      color: const Color(0xFFFAFAFA),
      elevation: 2,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: terminalSelecionadoId,
                    decoration: InputDecoration(
                      labelText: 'Terminal',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.business, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Todos os terminais', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13)),
                      ),
                      ...terminais.map((terminal) {
                        return DropdownMenuItem(
                          value: terminal['id']?.toString(),
                          child: Text(
                            terminal['nome_dois']?.toString() ?? '',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) {
                      setState(() {
                        terminalSelecionadoId = value;
                      });
                      _aplicarFiltros();
                    },
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: produtoSelecionado,
                    decoration: InputDecoration(
                      labelText: 'Produto',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.local_gas_station, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Todos os produtos', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13)),
                      ),
                      ...produtosDisponiveis.map((produto) {
                        return DropdownMenuItem(
                          value: produto['nome']?.toString(),
                          child: Text(
                            produto['nome']?.toString() ?? '',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) {
                      setState(() {
                        produtoSelecionado = value;
                      });
                      _aplicarFiltros();
                    },
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: _buildDatePicker(
                    label: 'Data inicial (emissão)',
                    value: dataInicialEmissao,
                    borderColor: Colors.blue.shade700,
                    borderWidth: 1.5,
                    onChanged: (data) {
                      setState(() {
                        dataInicialEmissao = data;
                        dataInicialEmissaoController.text = _formatarData(data);
                      });
                      _aplicarFiltros();
                    },
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: _buildDatePicker(
                    label: 'Data final (emissão)',
                    value: dataFinalEmissao,
                    borderColor: Colors.blue.shade700,
                    borderWidth: 1.5,
                    onChanged: (data) {
                      setState(() {
                        dataFinalEmissao = data;
                        dataFinalEmissaoController.text = _formatarData(data);
                      });
                      _aplicarFiltros();
                    },
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: _buildDatePicker(
                    label: 'Data inicial (descarga)',
                    value: dataInicialDescarga,
                    borderColor: Colors.brown.shade700,
                    borderWidth: 1.5,
                    onChanged: (data) {
                      setState(() {
                        dataInicialDescarga = data;
                        dataInicialDescargaController.text = _formatarData(data);
                      });
                      _aplicarFiltros();
                    },
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: _buildDatePicker(
                    label: 'Data final (descarga)',
                    value: dataFinalDescarga,
                    borderColor: Colors.brown.shade700,
                    borderWidth: 1.5,
                    onChanged: (data) {
                      setState(() {
                        dataFinalDescarga = data;
                        dataFinalDescargaController.text = _formatarData(data);
                      });
                      _aplicarFiltros();
                    },
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: buscaGeralController,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Pesquisa Geral',
                      labelStyle: const TextStyle(fontSize: 13),
                      hintText: 'Pesquise por qualquer dado...',
                      hintStyle: const TextStyle(fontSize: 13),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      _filtrarResultadosLocais();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime? value,
    required Function(DateTime) onChanged,
    Color? borderColor,
    double borderWidth = 1.0,
  }) {
    final texto = value != null ? _formatarData(value) : '';

    return InkWell(
      onTap: () async {
        DateTime tempDate = value ?? DateTime.now();
        final data = await showDialog<DateTime>(
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
                            Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF0D47A1))),
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

        if (data != null) {
          onChanged(data);
        }
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          border: Border.all(color: borderColor ?? Colors.grey.shade400, width: borderWidth),
          borderRadius: BorderRadius.circular(4),
          color: Colors.white,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -27,
              left: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: Text(
                    texto,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginacao() {
    return Card(
      color: const Color(0xFFFAFAFA),
      elevation: 1,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 16),
              onPressed: paginaAtual > 1
                  ? () {
                      setState(() => paginaAtual--);
                      _aplicarFiltros(resetarPagina: false);
                    }
                  : null,
              color: paginaAtual > 1 ? const Color(0xFF0D47A1) : Colors.grey,
            ),
            const SizedBox(width: 12),
            Text(
              'Página $paginaAtual de $totalPaginas',
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
            const SizedBox(width: 12),
            Text(
              '($totalRegistros registros)',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 16),
              onPressed: paginaAtual < totalPaginas
                  ? () {
                      setState(() => paginaAtual++);
                      _aplicarFiltros(resetarPagina: false);
                    }
                  : null,
              color: paginaAtual < totalPaginas ? const Color(0xFF0D47A1) : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF8F9FA),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
                  onPressed: widget.onVoltar,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Controle de Descargas',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D47A1),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!carregando)
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Color(0xFF0D47A1)),
                    onPressed: _refreshData,
                  ),
              ],
            ),
          ),

          _buildCardFiltros(),

          // Cabeçalho da lista
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                const SizedBox(width: 1),
                _buildHeaderCell('Emissão', 1),
                _buildHeaderCell('Nota Fiscal', 1),
                _buildHeaderCell('Qtd (Amb)', 1),
                _buildHeaderCell('Qtd (20°C)', 1),
                _buildHeaderCell('Produto', 1),
                _buildHeaderCell('Motorista', 1),
                _buildHeaderCell('Transp.', 1),
                _buildHeaderCell('Placas', 1),
                _buildHeaderCell('Origem', 1),
                _buildHeaderCell('Descarga', 1),
                _buildHeaderCell('P/S', 1),
                _buildHeaderCell('Obs', 1),
              ],
            ),
          ),
          
          const Divider(height: 1),

          Expanded(
            child: carregando
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF0D47A1),
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: descargasFiltradas.isEmpty
                            ? const Center(
                                child: Text('Nenhum registro encontrado'),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                itemCount: descargasFiltradas.length,
                                itemBuilder: (context, index) {
                                  final item = descargasFiltradas[index];
                                  
                                  // Cálculo de perda/sobra (opcional conforme estrutura)
                                  final double entAmb = double.tryParse(item['entrada_amb']?.toString() ?? '0') ?? 0;
                                  final double saiAmb = double.tryParse(item['saida_amb']?.toString() ?? '0') ?? 0;
                                  final double diff = entAmb - saiAmb;
                                  
                                  return MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    onEnter: (_) => setState(() => _hoverIndex = index),
                                    onExit: (_) => setState(() => _hoverIndex = null),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 150),
                                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                      decoration: BoxDecoration(
                                        color: _hoverIndex == index 
                                            ? const Color(0xFFE3F2FD) // Azul claro ao passar o mouse
                                            : (index.isEven ? Colors.white : const Color(0xFFFDFDFD)),
                                        border: Border(
                                          bottom: BorderSide(
                                            color: _hoverIndex == index ? const Color(0xFF90CAF9) : Colors.grey.shade200,
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          _buildDataCell(_formatarData(item['data_mov']), 1),
                                          _buildDataCell(item['nota_fiscal'] ?? '-', 1),
                                          _buildDataCell(_formatarNumero(item['entrada_amb']), 1),
                                          _buildDataCell(_formatarNumero(item['entrada_vinte']), 1),
                                          _buildDataCell(item['produtos']?['nome'] ?? '-', 1),
                                          _buildDataCell(item['motoristas']?['nome'] ?? '-', 1),
                                          _buildDataCell(item['transportadoras']?['nome_dois'] ?? '-', 1),
                                          _buildDataCell((item['placa'] as List?)?.join(' / ') ?? '-', 1),
                                          _buildDataCell(
                                            item['tipo_op'] == 'compra' 
                                              ? (item['cliente'] ?? '-') 
                                              : (item['terminal_orig']?['nome_dois'] ?? '-'), 
                                            1
                                          ),
                                          _buildDataCell(_formatarData(item['data_descarga']), 1),
                                          _buildDataCell(
                                            diff == 0 ? '0' : _formatarNumero(diff), 
                                            1, 
                                            color: diff < 0 ? Colors.red : (diff > 0 ? Colors.green : Colors.black87),
                                            weight: FontWeight.bold,
                                          ),
                                          _buildDataCell(item['observacoes'] ?? '-', 1),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      _buildPaginacao(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String label, int flex) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[700]),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildDataCell(String value, int flex, {Color? color, FontWeight? weight}) {
    return Expanded(
      flex: flex,
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10, 
          color: color ?? Colors.black87,
          fontWeight: weight ?? FontWeight.normal,
        ),
        overflow: TextOverflow.ellipsis,
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
