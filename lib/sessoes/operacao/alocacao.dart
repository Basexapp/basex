import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AlocacaoPage extends StatefulWidget {
  final VoidCallback onVoltar;

  const AlocacaoPage({
    super.key,
    required this.onVoltar,
  });

  @override
  State<AlocacaoPage> createState() => _AlocacaoPageState();
}

class _AlocacaoPageState extends State<AlocacaoPage> with WidgetsBindingObserver {
  bool carregando = true;
  bool buscando = false;
  List<Map<String, dynamic>> cacles = [];
  List<Map<String, dynamic>> terminais = [];
  List<Map<String, dynamic>> tanquesDisponiveis = [];
  List<Map<String, dynamic>> produtosDisponiveis = [];
  
  // Lista fictícia de vendas
  List<Venda> vendas = [];
  
  int paginaAtual = 1;
  int totalPaginas = 1;
  int totalRegistros = 0;
  final int limitePorPagina = 15;
  
  DateTime? dataInicial;
  DateTime? dataFinal;
  String? terminalSelecionadoId;
  String? tanqueSelecionadoId;
  String? produtoSelecionado;
  int? _hoverIndex;
  
  final TextEditingController dataInicialController = TextEditingController();
  final TextEditingController dataFinalController = TextEditingController();
  final TextEditingController pesquisaController = TextEditingController();

  Map<String, dynamic>? _usuarioData;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Definir data final como hoje
    dataFinal = DateTime.now();
    dataFinalController.text = _formatarData(dataFinal);

    // Definir data inicial como hoje - 2 dias úteis
    DateTime hoje = DateTime.now();
    int subtrairDias = 2;

    if (hoje.weekday == DateTime.monday) {
      subtrairDias = 4;
    } else if (hoje.weekday == DateTime.tuesday) {
      subtrairDias = 4;
    } else if (hoje.weekday == DateTime.sunday) {
      subtrairDias = 3;
    } else if (hoje.weekday == DateTime.saturday) {
      subtrairDias = 2;
    }

    dataInicial = hoje.subtract(Duration(days: subtrairDias));
    dataInicialController.text = _formatarData(dataInicial);
    
    _carregarDadosIniciais();
    _gerarVendasFicticias();

    pesquisaController.addListener(() {
      _aplicarFiltros(resetarPagina: true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    dataInicialController.dispose();
    dataFinalController.dispose();
    pesquisaController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshData();
    }
  }

  void _gerarVendasFicticias() {
    final produtos = ['Gasolina Comum', 'Gasolina Aditivada', 'Etanol', 'Diesel S10', 'Diesel S500'];
    final tanques = ['TQ-01', 'TQ-02', 'TQ-03', 'TQ-04', 'TQ-05'];
    final clientes = ['Posto Shell', 'Posto Ipiranga', 'Posto BR', 'Posto Ale', 'Posto Petrobras'];
    final placas = ['ABC-1234', 'DEF-5678', 'GHI-9012', 'JKL-3456', 'MNO-7890'];
    final nomesMotoristas = ['João Silva', 'Carlos Santos', 'Maria Oliveira', 'Pedro Costa', 'Ana Paula'];
    
    vendas = [];
    final hoje = DateTime.now();
    
    for (int i = 1; i <= 10; i++) {
      final produto = produtos[i % produtos.length];
      final tanque = tanques[i % tanques.length];
      final cliente = clientes[i % clientes.length];
      final placa = placas[i % placas.length];
      final motorista = nomesMotoristas[i % nomesMotoristas.length];
      final volume = (100 + (i * 50) + (i * 3.7)).toDouble();
      final valorUnitario = produto.contains('Diesel') ? 5.89 : 
                           produto.contains('Etanol') ? 4.25 : 6.45;
      final valorTotal = volume * valorUnitario;
      
      vendas.add(Venda(
        id: i.toString(),
        produto: produto,
        tanqueAtual: tanque,
        cliente: cliente,
        placa: placa,
        motorista: motorista,
        volume: volume,
        valorUnitario: valorUnitario,
        valorTotal: valorTotal,
        data: DateTime(hoje.year, hoje.month, hoje.day, 
                      8 + (i % 8), (i * 7) % 60),
        status: i % 3 == 0 ? 'Concluída' : 'Pendente',
        numeroNota: 'NF-${20260000 + i}',
        tanquesDisponiveis: tanques.where((t) => t != tanque).toList(),
      ));
    }
  }

  Future<Map<String, dynamic>?> _obterDadosUsuario() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        print('DEBUG: Supabase auth user is null');
        return null;
      }

      print('DEBUG: Supabase auth user id: ${user.id}');

      final data = await supabase
          .from('usuarios')
          .select('id, nome, nivel, id_filial, senha_temporaria, Nome_apelido, terminal_id, empresa_id')
          .eq('id', user.id)
          .maybeSingle();
      
      if (data == null) {
        print('DEBUG: No user data found in "usuarios" table for id: ${user.id}');
      } else {
        print('DEBUG: User data found: $data');
      }

      return data;
    } catch (e) {
      print('DEBUG: Error in _obterDadosUsuario: $e');
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
        print('DEBUG: _usuarioData is null after _obterDadosUsuario');
        if (mounted) {
          setState(() => carregando = false);
        }
        return;
      }
      
      final produtosResponse = await supabase
          .from('produtos')
          .select('id, nome')
          .order('nome');
      setState(() {
        produtosDisponiveis = List<Map<String, dynamic>>.from(produtosResponse);
      });

      if (_usuarioData!['terminal_id'] != null) {
        terminalSelecionadoId = _usuarioData!['terminal_id'].toString();
        final terminalResponse = await supabase
            .from('terminais')
            .select('id, nome')
            .eq('id', terminalSelecionadoId!)
            .single();
        setState(() {
          terminais = [terminalResponse];
        });
      } 
      else if (_usuarioData!['empresa_id'] != null) {
        final relacoesResponse = await supabase
            .from('relacoes_terminais')
            .select('terminal_id')
            .eq('empresa_id', _usuarioData!['empresa_id']);
        
        final listTerminalIds = (relacoesResponse as List)
            .map((r) => r['terminal_id'].toString())
            .toList();

        if (listTerminalIds.isNotEmpty) {
          final terminaisResponse = await supabase
              .from('terminais')
              .select('id, nome')
              .filter('id', 'in', listTerminalIds)
              .order('nome');
          setState(() {
            terminais = List<Map<String, dynamic>>.from(terminaisResponse);
          });
        } else {
          setState(() {
            terminais = [];
          });
        }
      } 
      else {
        final terminaisResponse = await supabase
            .from('terminais')
            .select('id, nome')
            .order('nome');
        setState(() {
          terminais = List<Map<String, dynamic>>.from(terminaisResponse);
        });
      }

      final tanquesResponse = await supabase
          .from('tanques')
          .select('id, referencia, terminal_id')
          .order('referencia');
      tanquesDisponiveis = List<Map<String, dynamic>>.from(tanquesResponse);

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
      if (mounted) {
        setState(() => carregando = false);
      }
    }
  }

  Future<void> _aplicarFiltros({bool resetarPagina = true}) async {
    if (resetarPagina) {
      paginaAtual = 1;
    }

    setState(() => buscando = true);

    try {
      final supabase = Supabase.instance.client;

      _usuarioData ??= await _obterDadosUsuario();

      if (_usuarioData == null) {
        return;
      }

      var query = supabase.from('cacl').select('''
        id,
        tipo,
        data,
        tanque_id,
        terminal_id,
        terminais:terminal_id (nome),
        created_at,
        status,
        horario_inicial,
        horario_final,
        volume_produto_inicial,
        volume_produto_final,
        volume_total_liquido_inicial,
        volume_total_liquido_final,
        tanques:tanque_id (referencia),
        produto_id,
        produtos:produto_id (nome),
        entrada_saida_20,
        faturado_final,
        diferenca_faturado,
        porcentagem_diferenca,
        numero_controle,
        sobra_perda
      ''');

      if (pesquisaController.text.isNotEmpty) {
        final search = pesquisaController.text;
        query = query.or('numero_controle.ilike.%$search%,status.ilike.%$search%');
      }

      if (dataInicial == null && dataFinal == null) {
        final hoje = DateTime.now().toIso8601String().split('T')[0];
        query = query.eq('data', hoje);
      } else if (dataInicial != null && dataFinal != null) {
        final inicio = dataInicial!.toIso8601String().split('T')[0];
        final fim = dataFinal!.toIso8601String().split('T')[0];
        query = query.gte('data', inicio).lte('data', fim);
      } else if (dataInicial != null) {
        query = query.eq('data', dataInicial!.toIso8601String().split('T')[0]);
      } else if (dataFinal != null) {
        query = query.eq('data', dataFinal!.toIso8601String().split('T')[0]);
      }

      if (terminalSelecionadoId != null) {
        query = query.eq('terminal_id', terminalSelecionadoId!);
      }

      if (tanqueSelecionadoId != null && tanqueSelecionadoId!.isNotEmpty) {
        query = query.eq('tanque_id', tanqueSelecionadoId!);
      }

      if (produtoSelecionado != null && produtoSelecionado!.isNotEmpty) {
        query = query.eq('produto_id', produtoSelecionado!);
      }

      final countResponse = await query;

      final response = await query
          .order('data', ascending: false)
          .order('created_at', ascending: false)
          .range(
            (paginaAtual - 1) * limitePorPagina,
            (paginaAtual * limitePorPagina) - 1,
          );

      setState(() {
        cacles = List<Map<String, dynamic>>.from(response);
        totalRegistros = countResponse.length;
        totalPaginas = (totalRegistros / limitePorPagina).ceil();
        if (totalPaginas == 0) totalPaginas = 1;
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro na busca: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => buscando = false);
    }
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

  String _formatarHora(DateTime data) {
    return '${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildCardFiltros() {
    if (_usuarioData == null) return const SizedBox();
    
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
                      if (_usuarioData!['terminal_id'] == null)
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Todos os terminais', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13)),
                        ),
                      ...terminais.map((terminal) {
                        return DropdownMenuItem(
                          value: terminal['id']?.toString(),
                          child: Text(
                            terminal['nome']?.toString() ?? '',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                    ],
                    onChanged: _usuarioData!['terminal_id'] != null
                        ? null
                        : (value) {
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
                    value: tanqueSelecionadoId,
                    decoration: InputDecoration(
                      labelText: 'Tanque',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.storage, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Todos os tanques', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13)),
                      ),
                      ...tanquesDisponiveis
                          .where((tanque) =>
                              terminalSelecionadoId == null ||
                              tanque['terminal_id']?.toString() == terminalSelecionadoId)
                          .map((tanque) {
                        return DropdownMenuItem(
                          value: tanque['id']?.toString(),
                          child: Text(
                            tanque['referencia']?.toString() ?? '',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) {
                      setState(() {
                        tanqueSelecionadoId = value;
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
                  child: Builder(builder: (context) {
                    final textoInicial = dataInicial != null
                        ? '${dataInicial!.day.toString().padLeft(2, '0')}/${dataInicial!.month.toString().padLeft(2, '0')}/${dataInicial!.year}'
                        : 'Data inicial';

                    return InkWell(
                      onTap: () async {
                        DateTime tempDate = dataInicial ?? DateTime.now();
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
                                            const Text('Data inicial', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF0D47A1))),
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
                          setState(() {
                            dataInicial = data;
                            dataInicialController.text = _formatarData(data);
                          });
                          _aplicarFiltros();
                        }
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
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
                                  'Data inicial',
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
                                    textoInicial,
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
                  }),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: Builder(builder: (context) {
                    final textoFinal = dataFinal != null
                        ? '${dataFinal!.day.toString().padLeft(2, '0')}/${dataFinal!.month.toString().padLeft(2, '0')}/${dataFinal!.year}'
                        : 'Data final';

                    return InkWell(
                      onTap: () async {
                        DateTime tempDate = dataFinal ?? DateTime.now();
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
                                            const Text('Data final', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF0D47A1))),
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
                          setState(() {
                            dataFinal = data;
                            dataFinalController.text = _formatarData(data);
                          });
                          _aplicarFiltros();
                        }
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
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
                                  'Data final',
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
                                    textoFinal,
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
                  }),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: TextField(
                    controller: pesquisaController,
                    decoration: InputDecoration(
                      labelText: 'Pesquisa geral',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _alterarTanque(Venda venda, String novoTanque) async {
    setState(() {
      venda.tanqueAtual = novoTanque;
    });
    
    // Aqui será implementada a lógica de atualização no banco posteriormente
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tanque alterado para $novoTanque na venda ${venda.numeroNota}'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showDialogAlterarTanque(Venda venda) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String? tanqueSelecionado = venda.tanqueAtual;
        
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF0D47A1), width: 1),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.swap_horiz, color: Color(0xFF0D47A1), size: 24),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Alterar Tanque',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0D47A1),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Venda: ${venda.numeroNota}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Produto: ${venda.produto}',
                              style: const TextStyle(fontSize: 13),
                            ),
                            Text(
                              'Cliente: ${venda.cliente}',
                              style: const TextStyle(fontSize: 13),
                            ),
                            Text(
                              'Volume: ${venda.volume.toStringAsFixed(1)} L',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      DropdownButtonFormField<String>(
                        value: tanqueSelecionado,
                        decoration: const InputDecoration(
                          labelText: 'Selecione o novo tanque',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.storage, size: 18),
                        ),
                        items: [
                          // Inclui todas as opções de tanques disponíveis
                          ...venda.tanquesDisponiveis.map((tanque) {
                            return DropdownMenuItem(
                              value: tanque,
                              child: Text(tanque),
                            );
                          }).toList(),
                          // Adiciona o tanque atual também, caso não esteja na lista
                          if (!venda.tanquesDisponiveis.contains(venda.tanqueAtual))
                            DropdownMenuItem(
                              value: venda.tanqueAtual,
                              child: Text('${venda.tanqueAtual} (atual)'),
                            ),
                        ],
                        onChanged: (value) {
                          setStateDialog(() {
                            tanqueSelecionado = value;
                          });
                        },
                      ),
                      
                      const SizedBox(height: 24),
                      
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
                            ),
                            child: const Text(
                              'Cancelar',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: tanqueSelecionado != null && tanqueSelecionado != venda.tanqueAtual
                                ? () {
                                    Navigator.pop(context);
                                    _alterarTanque(venda, tanqueSelecionado!);
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D47A1),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Alterar Tanque',
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_usuarioData == null && !carregando) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Usuário não autenticado'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Voltar'),
              ),
            ],
          ),
        ),
      );
    }
    
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'Alocação de saídas',
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

          // Cabeçalho da lista de vendas
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text('Produto', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Cliente', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                ),
                Expanded(
                  flex: 1,
                  child: Text('Volume', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Tanque Atual', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                ),
                Expanded(
                  flex: 1,
                  child: Text('Hora', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                ),
                Expanded(
                  flex: 1,
                  child: Text('Status', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                ),
                const SizedBox(width: 40), // Espaço para o botão de ação
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
                : vendas.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shopping_cart_outlined,
                              size: 40,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Nenhuma venda encontrada',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _refreshData,
                        color: const Color(0xFF0D47A1),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: vendas.length,
                          itemBuilder: (context, index) {
                            final venda = vendas[index];
                            final isPendente = venda.status == 'Pendente';
                            
                            return MouseRegion(
                              cursor: SystemMouseCursors.click,
                              onEnter: (_) => setState(() => _hoverIndex = index),
                              onExit: (_) => setState(() => _hoverIndex = null),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                color: _hoverIndex == index 
                                    ? Colors.grey.shade200 
                                    : (index.isEven ? Colors.white : Colors.grey.shade50),
                                child: Row(
                                  children: [
                                    // Produto
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        venda.produto,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    
                                    // Cliente
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        venda.cliente,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    
                                    // Volume
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        '${venda.volume.toStringAsFixed(1)} L',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    
                                    // Tanque Atual
                                    Expanded(
                                      flex: 2,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0D47A1).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          venda.tanqueAtual,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0D47A1),
                                          ),
                                        ),
                                      ),
                                    ),
                                    
                                    // Hora
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        _formatarHora(venda.data),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    
                                    // Status
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isPendente 
                                              ? Colors.orange.withOpacity(0.15)
                                              : Colors.green.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          venda.status,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: isPendente ? Colors.orange : Colors.green,
                                          ),
                                        ),
                                      ),
                                    ),
                                    
                                    // Botão para alterar tanque
                                    Container(
                                      width: 40,
                                      alignment: Alignment.center,
                                      child: IconButton(
                                        icon: const Icon(Icons.swap_horiz, size: 18, color: Color(0xFF0D47A1)),
                                        onPressed: () => _showDialogAlterarTanque(venda),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        tooltip: 'Alterar tanque',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
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

// Modelo de Venda
class Venda {
  final String id;
  final String produto;
  String tanqueAtual;
  final String cliente;
  final String placa;
  final String motorista;
  final double volume;
  final double valorUnitario;
  final double valorTotal;
  final DateTime data;
  final String status;
  final String numeroNota;
  final List<String> tanquesDisponiveis;

  Venda({
    required this.id,
    required this.produto,
    required this.tanqueAtual,
    required this.cliente,
    required this.placa,
    required this.motorista,
    required this.volume,
    required this.valorUnitario,
    required this.valorTotal,
    required this.data,
    required this.status,
    required this.numeroNota,
    required this.tanquesDisponiveis,
  });
}