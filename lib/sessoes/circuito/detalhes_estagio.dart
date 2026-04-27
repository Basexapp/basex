import 'package:flutter/material.dart';

class DetalhesEstagioPage extends StatefulWidget {
  final Map<String, dynamic> estagio;
  final List<String> produtos;
  final List<Map<String, dynamic>> terminais;
  final int? nivel;
  final DateTime? dataInicial;
  final bool apenasTabela;

  const DetalhesEstagioPage({
    super.key,
    required this.estagio,
    required this.produtos,
    required this.terminais,
    this.nivel,
    this.dataInicial,
    this.apenasTabela = false,
  });

  @override
  State<DetalhesEstagioPage> createState() => _DetalhesEstagioPageState();
}

class _DetalhesEstagioPageState extends State<DetalhesEstagioPage> {
  String? statusSelecionado;
  String? produtoSelecionado;
  String? tipoOperacaoSelecionada;
  String? _terminalSelecionado;
  DateTime? dataFiltro;
  final TextEditingController dataFiltroCtrl = TextEditingController();
  final TextEditingController terminalController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  int? _hoverIndex;
  late final List<Map<String, dynamic>> _dadosExibicao;
  List<Map<String, dynamic>> _dadosFiltrados = [];

  @override
  void initState() {
    super.initState();
    statusSelecionado = widget.estagio['titulo'];
    dataFiltro = widget.dataInicial ?? DateTime.now();
    dataFiltroCtrl.text = _formatarData(dataFiltro!.toIso8601String());
    
    final rawData = [
      {
        'tipo': 'Carga',
        'placa': ['BRA2E45', 'KML8901'],
        'transportadora': 'Logistica Veloz LTDA',
        'motorista': 'Ricardo Oliveira',
        'nota_fiscal': 'NF-8821',
        'entrada_amb': 42500,
        'produto': 'Oleo Diesel S10',
        'origem': 'Terminal Mataripe',
        'ps': 120,
        'obs': 'Aguardando pesagem'
      },
      {
        'tipo': 'Descarga',
        'placa': ['GHT3F67', 'POQ1234'],
        'transportadora': 'Nacional Trans S.A.',
        'motorista': 'Marcos Souza',
        'nota_fiscal': 'NF-4512',
        'entrada_amb': 38000,
        'produto': 'Etanol Hidratado',
        'origem': 'Usina Boa Vista',
        'ps': -45,
        'obs': 'Conferencia de lacres'
      },
      {
        'tipo': 'Carga',
        'placa': ['JUI4G89', 'XCS5678'],
        'transportadora': 'Expresso Rapido',
        'motorista': 'Andre Lima',
        'nota_fiscal': 'NF-1290',
        'entrada_amb': 45000,
        'produto': 'Gasolina Aditivada',
        'origem': 'Base de Distribuicao A',
        'ps': 0,
        'obs': 'Iniciando carregamento'
      },
      {
        'tipo': 'Descarga',
        'placa': ['LPO5H12', 'VBN9012'],
        'transportadora': 'Rodoviario Ideal',
        'motorista': 'Paulo Santos',
        'nota_fiscal': 'NF-7634',
        'entrada_amb': 41200,
        'produto': 'Gasolina Comum',
        'origem': 'Refinaria Planalto',
        'ps': 210,
        'obs': 'Em descarga - Baia 02'
      },
      {
        'tipo': 'Carga',
        'placa': ['MNB6J34', 'ZQX3456'],
        'transportadora': 'TransGlobal S.A.',
        'motorista': 'Bruno Ferreira',
        'nota_fiscal': 'NF-5541',
        'entrada_amb': 44000,
        'produto': 'Biodiesel B100',
        'origem': 'Terminal Porto Sul',
        'ps': -15,
        'obs': 'Documentacao ok'
      },
      {
        'tipo': 'Descarga',
        'placa': ['VFR7K56', 'ASD6789'],
        'transportadora': 'Sul Logistica',
        'motorista': 'Fernando Costa',
        'nota_fiscal': 'NF-3322',
        'entrada_amb': 39500,
        'produto': 'Querosene de Aviacao',
        'origem': 'Polo Petroquimico 1',
        'ps': 85,
        'obs': 'Amostra coletada'
      },
      {
        'tipo': 'Carga',
        'placa': ['KIU8L78', 'WER4512'],
        'transportadora': 'EcoTrans Brasil',
        'motorista': 'Sergio Mendes',
        'nota_fiscal': 'NF-9901',
        'entrada_amb': 43000,
        'produto': 'Oleo Diesel S500',
        'origem': 'Terminal Central 2',
        'ps': -110,
        'obs': 'Aguardando manobra'
      },
      {
        'tipo': 'Descarga',
        'placa': ['OIP9M90', 'TYU2345'],
        'transportadora': 'Delta Transportes',
        'motorista': 'Tiago Rocha',
        'nota_fiscal': 'NF-6678',
        'entrada_amb': 40000,
        'produto': 'Etanol Anidro',
        'origem': 'Destilaria Sao Jose',
        'ps': 30,
        'obs': 'Afericao de temperatura'
      },
      {
        'tipo': 'Carga',
        'placa': ['NBV0N12', 'GHJ7890'],
        'transportadora': 'Rota Oeste Log',
        'motorista': 'Claudio Duarte',
        'nota_fiscal': 'NF-4432',
        'entrada_amb': 46000,
        'produto': 'Gasolina Comum',
        'origem': 'Base de Apoio Norte',
        'ps': 55,
        'obs': 'Finalizando lacracao'
      },
      {
        'tipo': 'Descarga',
        'placa': ['POW1Q23', 'XCV4567'],
        'transportadora': 'Carga Nobre',
        'motorista': 'Gabriel Nunes',
        'nota_fiscal': 'NF-2210',
        'entrada_amb': 37500,
        'produto': 'Lubrificantes',
        'origem': 'Fabrica Sao Paulo',
        'ps': -200,
        'obs': 'Divergencia de lacre'
      },
      {
        'tipo': 'Carga',
        'placa': ['XSD2W34', 'BNM5678'],
        'transportadora': 'Pioneira Trans',
        'motorista': 'Felipe Martins',
        'nota_fiscal': 'NF-1109',
        'entrada_amb': 42000,
        'produto': 'Diesel Marinho',
        'origem': 'Terminal Oceanico',
        'ps': 140,
        'obs': 'Checklist aprovado'
      },
      {
        'tipo': 'Descarga',
        'placa': ['CDS3E45', 'IUY2390'],
        'transportadora': 'InterModal Log',
        'motorista': 'Jorge Silva',
        'nota_fiscal': 'NF-7786',
        'entrada_amb': 39000,
        'produto': 'Gas Natural (GLP)',
        'origem': 'Refinaria Leste',
        'ps': 10,
        'obs': 'Conectando mangotes'
      },
    ]..shuffle();

    if (widget.estagio['titulo'] == 'Em fila') {
      final descargas = rawData.where((item) => item['tipo'] == 'Descarga').toList();
      final cargas = rawData.where((item) => item['tipo'] == 'Carga').toList();
      
      for (int i = 0; i < descargas.length; i++) {
        descargas[i]['posicao'] = '${i + 1}o';
      }
      for (int i = 0; i < cargas.length; i++) {
        cargas[i]['posicao'] = '${i + 1}o';
      }
      
      _dadosExibicao = [...descargas, ...cargas];
    } else {
      _dadosExibicao = rawData;
    }
    _dadosFiltrados = List.from(_dadosExibicao);
  }

  void _filtrarDados(String query) {
    setState(() {
      if (query.isEmpty) {
        _dadosFiltrados = List.from(_dadosExibicao);
      } else {
        final lowerQuery = query.toLowerCase();
        _dadosFiltrados = _dadosExibicao.where((item) {
          final placa = (item['placa'] as List).join(' ').toLowerCase();
          final transportadora = item['transportadora'].toString().toLowerCase();
          final motorista = item['motorista'].toString().toLowerCase();
          final nf = item['nota_fiscal'].toString().toLowerCase();
          final produto = item['produto'].toString().toLowerCase();
          final origem = item['origem'].toString().toLowerCase();
          final obs = item['obs'].toString().toLowerCase();
          final tipo = item['tipo'].toString().toLowerCase();

          return placa.contains(lowerQuery) ||
              transportadora.contains(lowerQuery) ||
              motorista.contains(lowerQuery) ||
              nf.contains(lowerQuery) ||
              produto.contains(lowerQuery) ||
              origem.contains(lowerQuery) ||
              obs.contains(lowerQuery) ||
              tipo.contains(lowerQuery);
        }).toList();
      }
    });
  }

  String _formatarData(String? d) {
    if (d == null) return '-';
    final dt = DateTime.parse(d);
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  String _formatarNumero(dynamic valor) {
    if (valor == null) return '0';
    try {
      double numero = double.parse(valor.toString());
      String parteInteira = numero.round().toString();
      final RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
      return parteInteira.replaceAllMapped(reg, (Match m) => '${m[1]}.');
    } catch (_) {
      return valor.toString();
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
    for (int i = 0; i < startOffset; i++) days.add(null);
    for (int i = 1; i <= lastDay.day; i++) days.add(i);
    while (days.length < 42) days.add(null);
    return days;
  }

  Widget _buildCardFiltros() {
    final isAdmin = widget.nivel == 3;
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
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: statusSelecionado,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.info_outline, size: 18),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Todos', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 'Programados', child: Text('Programados', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 'Em fila', child: Text('Em fila', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 'Em operação', child: Text('Em operação', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 'Liberados', child: Text('Liberados', style: TextStyle(fontSize: 13))),
                    ],
                    onChanged: (value) => setState(() => statusSelecionado = value),
                  ),
                ),
                const SizedBox(width: 8),
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
                      const DropdownMenuItem(value: null, child: Text('Todos os produtos', style: TextStyle(fontSize: 13))),
                      ...widget.produtos.map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 13)))),
                    ],
                    onChanged: (value) => setState(() => produtoSelecionado = value),
                  ),
                ),
                const SizedBox(width: 8),
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
                    onChanged: (value) => setState(() => tipoOperacaoSelecionada = value),
                  ),
                ),
                const SizedBox(width: 8),
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
                            const DropdownMenuItem(value: null, child: Text('Todos os terminais', style: TextStyle(fontSize: 13))),
                            ...widget.terminais.map((t) => DropdownMenuItem(value: t['id'].toString(), child: Text(t['nome'].toString(), style: const TextStyle(fontSize: 13)))),
                          ],
                          onChanged: (value) => setState(() => _terminalSelecionado = value),
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
                Expanded(
                  child: _buildDatePicker(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _searchController,
                    onChanged: _filtrarDados,
                    decoration: const InputDecoration(
                      labelText: 'Buscar',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search, size: 18),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                      hintText: 'Placa, motorista...',
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

  Widget _buildDatePicker() {
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
            dataFiltro = dataSelecionada;
            dataFiltroCtrl.text = _formatarData(dataFiltro!.toIso8601String());
          });
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
            const Icon(Icons.calendar_today, size: 14, color: Color(0xFF0D47A1)),
            const SizedBox(width: 8),
            Expanded(child: Text(textoData, style: const TextStyle(fontSize: 13, color: Color(0xFF0D47A1), fontWeight: FontWeight.w500))),
          ],
        ),
      ),
    );
  }

  Widget _buildTabela() {
    return Expanded(
      child: Column(
        children: [
          if (widget.apenasTabela)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 200,
                    height: 32,
                    child: TextFormField(
                      controller: _searchController,
                      onChanged: _filtrarDados,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Buscar na tabela...',
                        hintStyle: const TextStyle(fontSize: 12),
                        prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF0D47A1)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                if (widget.estagio['titulo'] == 'Programados') const SizedBox(width: 32),
                if (widget.estagio['titulo'] == 'Em fila') _buildHeaderCell('Posição', 1),
                _buildHeaderCell('Tipo', 1),
                _buildHeaderCell('Placas', 1),
                _buildHeaderCell('Transportadora', 2),
                _buildHeaderCell('Motorista', 2),
                _buildHeaderCell('Nota Fiscal', 1),
                _buildHeaderCell('Qtd (amb)', 1),
                _buildHeaderCell('Produto', 1),
                _buildHeaderCell('Origem', 2),
                if (widget.estagio['titulo'] == 'Liberados') _buildHeaderCell('P/S', 1),
                _buildHeaderCell('Obs', 2),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _dadosFiltrados.length,
              itemBuilder: (context, index) {
                final item = _dadosFiltrados[index];
                final double diff = (item['ps'] as num).toDouble();

                // Verifica se deve exibir divisor entre Descarga e Carga no estágio 'Em fila'
                bool mostrarDivisorCarga = false;
                bool mostrarDivisorDescarga = false;
                
                if (widget.estagio['titulo'] == 'Em fila') {
                  if (index == 0 && item['tipo'] == 'Descarga') {
                    mostrarDivisorDescarga = true;
                  } else if (index > 0) {
                    final itemAnterior = _dadosFiltrados[index - 1];
                    if (itemAnterior['tipo'] == 'Descarga' && item['tipo'] == 'Carga') {
                      mostrarDivisorCarga = true;
                    }
                  }
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (mostrarDivisorDescarga)
                      _buildSecaoDivisor('VEÍCULOS AGUARDANDO DESCARGA'),
                    if (mostrarDivisorCarga)
                      _buildSecaoDivisor('VEÍCULOS AGUARDANDO CARGA'),
                    MouseRegion(
                      onEnter: (_) => setState(() => _hoverIndex = index),
                      onExit: (_) => setState(() => _hoverIndex = null),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        decoration: BoxDecoration(
                          color: _hoverIndex == index ? const Color(0xFFE3F2FD) : (index.isEven ? Colors.white : const Color(0xFFFDFDFD)),
                          border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
                        ),
                        child: Row(
                          children: [
                            if (widget.estagio['titulo'] == 'Programados')
                              SizedBox(
                                width: 32,
                                height: 24,
                                child: PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, size: 16, color: Color(0xFF0D47A1)),
                                  padding: EdgeInsets.zero,
                                  tooltip: 'Ações',
                                  onSelected: (value) {
                                    // Ações futuras aqui
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'fila',
                                      child: Row(
                                        children: [
                                          Icon(Icons.queue, size: 18, color: Colors.green),
                                          SizedBox(width: 8),
                                          Text('Enviar para fila', style: TextStyle(fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'bloquear',
                                      child: Row(
                                        children: [
                                          Icon(Icons.block, size: 18, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Bloquear veículo', style: TextStyle(fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (widget.estagio['titulo'] == 'Em fila')
                              _buildDataCell(item['posicao'] ?? '-', 1, weight: FontWeight.bold, color: const Color(0xFF0D47A1)),
                            _buildDataCell(item['tipo'], 1, color: item['tipo'] == 'Carga' ? Colors.blue : Colors.orange, weight: FontWeight.bold),
                            _buildDataCell((item['placa'] as List).join(' / '), 1),
                            _buildDataCell(item['transportadora'], 2),
                            _buildDataCell(item['motorista'], 2),
                            _buildDataCell(item['nota_fiscal'], 1),
                            _buildDataCell(_formatarNumero(item['entrada_amb']), 1),
                            _buildDataCell(item['produto'], 1),
                            _buildDataCell(item['origem'], 2),
                            if (widget.estagio['titulo'] == 'Liberados')
                              _buildDataCell(
                                item['tipo'] == 'Descarga' ? _formatarNumero(diff) : '-',
                                1,
                                color: item['tipo'] == 'Descarga' ? (diff < 0 ? Colors.red : Colors.green) : Colors.grey,
                                weight: item['tipo'] == 'Descarga' ? FontWeight.bold : FontWeight.normal,
                              ),
                            _buildDataCell(item['obs'], 2),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String label, int flex) => Expanded(flex: flex, child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[700]), overflow: TextOverflow.ellipsis));
  Widget _buildDataCell(String value, int flex, {Color? color, FontWeight? weight}) => Expanded(flex: flex, child: Text(value, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: color ?? Colors.black87, fontWeight: weight ?? FontWeight.normal), overflow: TextOverflow.ellipsis));

  Widget _buildSecaoDivisor(String titulo) {
    return Container(
      color: const Color(0xFFF5F5F5),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          const Expanded(child: Divider(thickness: 1.5, color: Colors.blueGrey)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              titulo,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey[700],
                letterSpacing: 1.2,
              ),
            ),
          ),
          const Expanded(child: Divider(thickness: 1.5, color: Colors.blueGrey)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.apenasTabela) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(widget.estagio['icone'], color: widget.estagio['cor'], size: 28),
                const SizedBox(width: 12),
                Text(
                  "Veículos: ${widget.estagio['titulo']}",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: widget.estagio['cor'],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          _buildTabela(),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0D47A1),
        title: Text(widget.estagio['titulo'], style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          _buildCardFiltros(),
          _buildTabela(),
        ],
      ),
    );
  }
}
