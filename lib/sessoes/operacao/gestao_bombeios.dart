import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../login_page.dart';

class FiltroGestaoBombeiosPage extends StatefulWidget {
  final String? terminalId;
  final String? empresaId;
  final String? empresaNome;
  final Function({
    String? terminalId,
    DateTime? dataInicial,
    DateTime? dataFinal,
    String? produtoId,
    String? produtoNome,
    String? pesquisa,
  }) onConsultar;
  final VoidCallback onVoltar;

  const FiltroGestaoBombeiosPage({
    super.key,
    this.terminalId,
    this.empresaId,
    this.empresaNome,
    required this.onConsultar,
    required this.onVoltar,
  });

  @override
  State<FiltroGestaoBombeiosPage> createState() => _FiltroGestaoBombeiosPageState();
}

class _FiltroGestaoBombeiosPageState extends State<FiltroGestaoBombeiosPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final NumberFormat _fmt = NumberFormat.decimalPattern('pt_BR');

  DateTime? dataInicial;
  DateTime? dataFinal;
  String? terminalSelecionadoId;
  String? produtoSelecionado;
  String? produtoSelecionadoId;

  // RECOLOCANDO AS VARIÁVEIS QUE FORAM REMOVIDAS ACIDENTALMENTE
  List<Map<String, dynamic>> produtosDisponiveis = [];
  List<Map<String, dynamic>> terminais = [];

  bool carregando = true;
  final TextEditingController pesquisaController = TextEditingController();

  Map<String, dynamic>? _bombeioSelecionado;
  bool _mostrarRateio = false;

  UsuarioAtual? get user => UsuarioAtual.instance;

  List<Map<String, dynamic>> _todosRegistrosFicticios = [];
  List<Map<String, dynamic>> registrosExibidos = [];

  final List<String> _distribuidorasFixas = [
    'Zema', 'Raízen', 'Sim Distr.', 'Larco Distr.'
  ];

  @override
  void initState() {
    super.initState();
    dataFinal = DateTime(2026, 4, 10);
    dataInicial = DateTime(2026, 3, 1);
    _carregarDadosViaUsuario();
    _gerarDadosFicticios();
    pesquisaController.addListener(_aplicarFiltrosLocal);
  }

  @override
  void dispose() {
    pesquisaController.dispose();
    super.dispose();
  }

  void _carregarDadosViaUsuario() async {
    setState(() => carregando = true);
    try {
      if (user == null) return;
      String? empresaId = user!.empresaId;
      if (empresaId != null && empresaId.isNotEmpty) {
        final relacoes = await _supabase
            .from('relacoes_terminais')
            .select('terminal_id, terminais(id, nome_dois)')
            .eq('empresa_id', empresaId);

        final Map<String, Map<String, dynamic>> terminaisUnicos = {};
        for (var relacao in relacoes) {
          if (relacao['terminais'] != null) {
            final t = relacao['terminais'];
            terminaisUnicos[t['id']] = {
              'id': t['id'],
              'nome': t['nome_dois'] ?? 'Sem nome',
            };
          }
        }

        setState(() {
          terminais = terminaisUnicos.values.toList()..sort((a, b) => (a['nome'] ?? '').compareTo(b['nome'] ?? ''));
          if (user!.terminalId != null && user!.terminalId!.isNotEmpty) {
            terminalSelecionadoId = user!.terminalId;
          } else if (terminais.length == 1) {
            terminalSelecionadoId = terminais[0]['id'];
          }
          if (terminalSelecionadoId != null) {
            _carregarProdutosPorTerminal(terminalSelecionadoId!);
          }
        });
      }
    } catch (e) {
      debugPrint('Erro: $e');
    } finally {
      setState(() => carregando = false);
    }
  }

  Future<void> _carregarProdutosPorTerminal(String terminalId) async {
    try {
      final response = await _supabase
          .from('tanques')
          .select('id_produto, produtos(id, nome_dois)')
          .eq('terminal_id', terminalId)
          .not('id_produto', 'is', null);

      final Map<String, Map<String, dynamic>> produtosUnicos = {};
      for (var tanque in response) {
        if (tanque['produtos'] != null) {
          final p = tanque['produtos'];
          produtosUnicos[p['id']] = {
            'id': p['id'].toString(),
            'nome': p['nome_dois'] ?? 'Sem nome',
          };
        }
      }
      setState(() {
        produtosDisponiveis = produtosUnicos.values.toList()..sort((a, b) => (a['nome'] ?? '').compareTo(b['nome'] ?? ''));
      });
    } catch (e) {
      debugPrint('Erro: $e');
    }
  }

  void _gerarDadosFicticios() {
    final Random random = Random();
    final List<String> produtos = ['Gasolina A', 'S500-A', 'S10-A'];
    final List<String> tanques = ['TQ-01', 'TQ-05', 'TQ-10', 'TQ-12', 'TQ-20'];
    
    _todosRegistrosFicticios.clear();
    for (int i = 0; i < 30; i++) {
      final int diasDeDiferenca = random.nextInt(41);
      final DateTime dataBase = DateTime(2026, 3, 1).add(Duration(days: diasDeDiferenca));
      final int horaInicial = 6 + random.nextInt(12);
      final int minutoInicial = random.nextInt(60);
      final int duracaoMinutos = 220 + random.nextInt(40);
      final DateTime dtInicio = DateTime(2026, 3, 1, horaInicial, minutoInicial).add(Duration(days: diasDeDiferenca));
      final DateTime dtFim = dtInicio.add(Duration(minutes: duracaoMinutos));

      String status;
      bool ehHoje = dataBase.day == 10 && dataBase.month == 4 && dataBase.year == 2026;
      if (ehHoje) {
        status = 'Em andamento';
      } else {
        int r = random.nextInt(100);
        if (r < 95) {
          status = 'Concluído';
        } else {
          status = 'Cancelado';
        }
      }

      List<Map<String, dynamic>> participantes = [];
      double totalPedido = 0;
      double porcentagemRecebida = 0.8 + (random.nextDouble() * 0.2);

      for (String nomeDistribuidora in _distribuidorasFixas) {
        // Garantindo que o volume solicitado seja múltiplo de 10.000
        double solicitado = ((1 + random.nextInt(3)) * 10000).toDouble();
        totalPedido += solicitado;
        participantes.add({
          'nome': nomeDistribuidora,
          'solicitado': solicitado,
        });
      }

      double volumeTotalRecebido = totalPedido * porcentagemRecebida;

      _todosRegistrosFicticios.add({
        'id': i,
        'data': dataBase,
        'produto': produtos[random.nextInt(produtos.length)],
        'tanque': tanques[random.nextInt(tanques.length)],
        'horario_inicial': '${dtInicio.hour.toString().padLeft(2, "0")}:${dtInicio.minute.toString().padLeft(2, "0")}',
        'horario_final': '${dtFim.hour.toString().padLeft(2, "0")}:${dtFim.minute.toString().padLeft(2, "0")}',
        'numero_controle': 'BOMB-${1250 + i}',
        'status': status,
        'volume_total': volumeTotalRecebido,
        'volume_solicitado': totalPedido,
        'participantes': participantes,
      });
    }
    _todosRegistrosFicticios.sort((a, b) => (b['data'] as DateTime).compareTo(a['data'] as DateTime));
    _aplicarFiltrosLocal();
  }

  void _aplicarFiltrosLocal() {
    setState(() {
      registrosExibidos = _todosRegistrosFicticios.where((item) {
        final DateTime dt = item['data'] as DateTime;
        final String pesquisa = pesquisaController.text.toLowerCase();
        if (dataInicial != null && dt.isBefore(dataInicial!)) return false;
        if (dataFinal != null && dt.isAfter(dataFinal!.add(const Duration(days: 1)))) return false;
        if (produtoSelecionado != null && item['produto'] != produtoSelecionado) return false;
        if (pesquisa.isNotEmpty) {
          if (!(item['produto'] as String).toLowerCase().contains(pesquisa) && 
              !(item['numero_controle'] as String).toLowerCase().contains(pesquisa)) return false;
        }
        return true;
      }).toList();
    });
  }

  String _formatarData(DateTime? data) => data == null ? '-' : "${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}";

  Color _getStatusColor(String? status) {
    if (status == 'Concluído') return Colors.green;
    if (status == 'Em andamento') return Colors.orange;
    return Colors.red;
  }

  Widget _buildListaBombeios() {
    return Column(
      children: [
        _buildCardFiltros(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              const SizedBox(width: 16),
              Expanded(flex: 1, child: Text('Data', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700]))),
              Expanded(flex: 2, child: Text('Produto', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700]))),
              Expanded(flex: 1, child: Text('Tanque', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700]))),
              Expanded(flex: 1, child: Text('H.Inicial', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700]))),
              Expanded(flex: 1, child: Text('H.Final', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700]))),
              Expanded(flex: 2, child: Text('Nº Controle', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700]))),
              Expanded(flex: 2, child: Text('Status', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700]))),
              const SizedBox(width: 24),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: registrosExibidos.length,
            itemBuilder: (context, index) {
              final item = registrosExibidos[index];
              return InkWell(
                onTap: () => setState(() { _bombeioSelecionado = item; _mostrarRateio = true; }),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1))]),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        Container(width: 4, decoration: BoxDecoration(color: _getStatusColor(item['status']), borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), bottomLeft: Radius.circular(4)))),
                        const SizedBox(width: 12),
                        Expanded(flex: 1, child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(_formatarData(item['data']), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)))),
                        Expanded(flex: 2, child: Text(item['produto'], textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                        Expanded(flex: 1, child: Text(item['tanque'], textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
                        Expanded(flex: 1, child: Text(item['horario_inicial'], textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
                        Expanded(flex: 1, child: Text(item['horario_final'], textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
                        Expanded(flex: 2, child: Text(item['numero_controle'], textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.blue))),
                        Expanded(flex: 2, child: Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: _getStatusColor(item['status']).withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Text(item['status'], style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getStatusColor(item['status'])))))),
                        const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPaginaRateio() {
    final double totalRecebido = _bombeioSelecionado!['volume_total'];
    final double totalSolicitado = _bombeioSelecionado!['volume_solicitado'];
    final List<Map<String, dynamic>> participantes = List<Map<String, dynamic>>.from(_bombeioSelecionado!['participantes']);

    // Ordenando da que mais participou para a que menos participou (pelo volume solicitado)
    participantes.sort((a, b) => (b['solicitado'] as double).compareTo(a['solicitado'] as double));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('DETALHES DO RATEIO', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0D47A1), letterSpacing: 1.2)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)), onPressed: () => setState(() => _mostrarRateio = false)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const Divider(height: 1),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
            color: const Color(0xFFFBFBFB),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildHeaderMicroItem('CONTROLE', _bombeioSelecionado!['numero_controle']),
                _buildHeaderMicroItem('DATA', _formatarData(_bombeioSelecionado!['data'])),
                _buildHeaderMicroItem('HORÁRIO', '${_bombeioSelecionado!['horario_inicial']} - ${_bombeioSelecionado!['horario_final']}'),
                _buildHeaderMicroItem('PRODUTO', _bombeioSelecionado!['produto']),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('VOLUME TOTAL SOLICITADO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey)),
                    const SizedBox(height: 2),
                    Text('${_fmt.format(totalSolicitado.toInt())} L', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF455A64))),
                    const SizedBox(height: 20),
                    const Text('VOLUME TOTAL RECEBIDO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey)),
                    const SizedBox(height: 2),
                    Text('${_fmt.format(totalRecebido.toInt())} L', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Color(0xFF0D47A1))),
                  ],
                ),
                const SizedBox(width: 60),
                SizedBox(
                  width: 180,
                  height: 180,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: List.generate(participantes.length, (i) {
                        final p = participantes[i];
                        final colors = [
                          const Color(0xFF0D47A1), // Azul Escuro
                          const Color(0xFFD32F2F), // Vermelho
                          const Color(0xFF388E3C), // Verde
                          const Color(0xFFFBC02D), // Amarelo/Dourado
                        ];
                        return PieChartSectionData(
                          color: colors[i % colors.length],
                          value: p['solicitado'],
                          title: '${p['nome'].toString().split(' ')[0]}\n${((p['solicitado'] / totalSolicitado) * 100).toStringAsFixed(0)}%',
                          radius: 60,
                          titleStyle: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [Shadow(color: Colors.black45, blurRadius: 2)],
                          ),
                          titlePositionPercentageOffset: 0.55,
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const SizedBox(width: 8),
                Expanded(flex: 3, child: Text('DISTRIBUIDORA', textAlign: TextAlign.left, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[700]))),
                Expanded(flex: 1, child: Text('%', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[700]))),
                Expanded(flex: 2, child: Text('SOLICITADO', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[700]))),
                Expanded(flex: 2, child: Text('RECEBIDO', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[700]))),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: participantes.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                final p = participantes[index];
                double peso = p['solicitado'] / totalSolicitado;
                double recebido = totalRecebido * peso;
                double percent = (recebido / totalRecebido);

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const [
                                  Color(0xFF0D47A1), // Azul Escuro
                                  Color(0xFFD32F2F), // Vermelho
                                  Color(0xFF388E3C), // Verde
                                  Color(0xFFFBC02D), // Amarelo/Dourado
                                ][index % 4],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p['nome'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: LinearProgressIndicator(
                                      value: percent,
                                      backgroundColor: Colors.grey[100],
                                      valueColor: AlwaysStoppedAnimation<Color>(const [
                                        Color(0xFF0D47A1), Color(0xFFD32F2F), Color(0xFF388E3C), Color(0xFFFBC02D)
                                      ][index % 4]),
                                      minHeight: 3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text('${(percent * 100).toStringAsFixed(1)}%', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(_fmt.format(p['solicitado'].toInt()), textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(_fmt.format(recebido.toInt()), textAlign: TextAlign.center, style: TextStyle(
                          fontSize: 12, 
                          fontWeight: FontWeight.bold, 
                          color: const [
                            Color(0xFF0D47A1), Color(0xFFD32F2F), Color(0xFF388E3C), Color(0xFFFBC02D)
                          ][index % 4],
                        )),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            color: const Color(0xFFF9F9F9),
            child: const Text('Layout Slim - Auditoria de Rateio Proporcional', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderMicroItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0D47A1))),
      ],
    );
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
            const Text('Filtros de Busca', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 250,
                  child: DropdownButtonFormField<String>(
                    value: produtoSelecionadoId,
                    decoration: const InputDecoration(labelText: 'Produto', border: OutlineInputBorder(), prefixIcon: Icon(Icons.local_gas_station, size: 18), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), isDense: true),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todos os produtos', style: TextStyle(fontSize: 13))),
                      ...produtosDisponiveis.map((p) => DropdownMenuItem(value: p['id'], child: Text(p['nome'] ?? '', style: const TextStyle(fontSize: 13)))),
                    ],
                    onChanged: (val) {
                      setState(() {
                        produtoSelecionadoId = val;
                        produtoSelecionado = val != null ? produtosDisponiveis.firstWhere((p) => p['id'] == val)['nome'] : null;
                      });
                      _aplicarFiltrosLocal();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: terminalSelecionadoId,
                    decoration: const InputDecoration(labelText: 'Terminal', border: OutlineInputBorder(), prefixIcon: Icon(Icons.business, size: 18), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), isDense: true),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todos os terminais', style: TextStyle(fontSize: 13))),
                      ...terminais.map((t) => DropdownMenuItem(value: t['id'], child: Text(t['nome'] ?? '', style: const TextStyle(fontSize: 13)))),
                    ],
                    onChanged: (val) {
                      setState(() {
                        terminalSelecionadoId = val;
                        produtoSelecionadoId = null;
                        produtoSelecionado = null;
                        if (val != null) _carregarProdutosPorTerminal(val);
                      });
                      _aplicarFiltrosLocal();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(width: 140, child: _buildDatePicker('Data inicial', dataInicial, (d) { setState(() => dataInicial = d); _aplicarFiltrosLocal(); })),
                const SizedBox(width: 8),
                SizedBox(width: 140, child: _buildDatePicker('Data final', dataFinal, (d) { setState(() => dataFinal = d); _aplicarFiltrosLocal(); })),
                const SizedBox(width: 8),
                SizedBox(width: 300, child: TextField(controller: pesquisaController, decoration: const InputDecoration(labelText: 'Pesquisa geral', prefixIcon: Icon(Icons.search, size: 18), border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), isDense: true), style: const TextStyle(fontSize: 13))),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.bar_chart, size: 18),
                  label: const Text('Gráfico'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D47A1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker(String label, DateTime? value, Function(DateTime) onSelect) {
    final txt = value != null ? "${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}" : label;
    return InkWell(
      onTap: () async {
        DateTime tempDate = value ?? DateTime.now();
        final DateTime? selecionado = await showDialog<DateTime>(
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
                                icon: const Icon(Icons.chevron_left, color: Color(0xFF0D47A1)),
                                onPressed: () => setStateDialog(() => tempDate = DateTime(tempDate.year, tempDate.month - 1, tempDate.day)),
                              ),
                              Text('${_getMonthName(tempDate.month)} ${tempDate.year}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF0D47A1))),
                              IconButton(
                                icon: const Icon(Icons.chevron_right, color: Color(0xFF0D47A1)),
                                onPressed: () => setStateDialog(() => tempDate = DateTime(tempDate.year, tempDate.month + 1, tempDate.day)),
                              ),
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
                                  onEnter: (_) => day != null ? setDayState(() => hoveredDay = day) : null,
                                  onExit: (_) => day != null ? setDayState(() => hoveredDay = null) : null,
                                  child: GestureDetector(
                                    onTap: day != null ? () => setStateDialog(() => tempDate = DateTime(tempDate.year, tempDate.month, day)) : null,
                                    child: Container(
                                      margin: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xFF0D47A1) : (day != null && hoveredDay == day) ? const Color(0xFF0D47A1).withOpacity(0.1) : isToday ? const Color(0x220D47A1) : Colors.transparent,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          day != null ? day.toString() : '',
                                          style: TextStyle(
                                            color: isSelected ? Colors.white : isToday || (day != null && hoveredDay == day) ? const Color(0xFF0D47A1) : Colors.black87,
                                            fontWeight: isSelected || isToday || (day != null && hoveredDay == day) ? FontWeight.bold : FontWeight.normal,
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
                            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('CANCELAR', style: TextStyle(color: Colors.black87))),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => Navigator.of(context).pop(tempDate),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                              child: const Text('SELECIONAR', style: TextStyle(fontWeight: FontWeight.bold)),
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
        if (selecionado != null) onSelect(selecionado);
      },
      child: Container(height: 40, padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(4), color: Colors.white), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(txt, style: const TextStyle(fontSize: 13)), const Icon(Icons.calendar_today, size: 16, color: Colors.grey)])),
    );
  }

  String _getMonthName(int month) {
    const months = ['Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'];
    return months[month - 1];
  }

  List<int?> _getDaysInMonth(DateTime date) {
    final firstDay = DateTime(date.year, date.month, 1);
    final lastDay = DateTime(date.year, date.month + 1, 0);
    final firstWeekday = firstDay.weekday;
    final startOffset = firstWeekday == 7 ? 0 : firstWeekday;
    List<int?> days = [];
    for (int i = 0; i < startOffset; i++) days.add(null);
    for (int i = 1; i <= lastDay.day; i++) days.add(i);
    while (days.length < 42) days.add(null);
    return days;
  }

  @override
  Widget build(BuildContext context) {
    if (_mostrarRateio && _bombeioSelecionado != null) return _buildPaginaRateio();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)), onPressed: widget.onVoltar),
                const Text('Gestão de Bombeios', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                const Spacer(),
                if (!carregando) IconButton(icon: const Icon(Icons.refresh, color: Color(0xFF0D47A1)), onPressed: _gerarDadosFicticios),
              ],
            ),
          ),
          Expanded(child: carregando ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D47A1))) : _buildListaBombeios()),
        ],
      ),
    );
  }
}
