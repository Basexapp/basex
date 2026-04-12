import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:universal_html/html.dart' as html;

class RelatoriosDownloadsPage extends StatefulWidget {
  final VoidCallback onVoltar;

  const RelatoriosDownloadsPage({
    super.key,
    required this.onVoltar,
  });

  @override
  State<RelatoriosDownloadsPage> createState() =>
      _RelatoriosDownloadsPageState();
}

class _RelatoriosDownloadsPageState extends State<RelatoriosDownloadsPage> {
  bool showTabelaVolume = false;
  bool showTabelaDensidade = false;
  bool baixando = false;
  int? _hoverIndex;

  final TextEditingController pesquisaController = TextEditingController();
  String _pesquisa = '';

  final List<Map<String, dynamic>> _todosItens = [
    {
      'titulo': 'Tabela de Conversão de Volume',
      'icon': Icons.stacked_bar_chart,
      'iconColor': Colors.green,
      'tipo': 'volume',
    },
    {
      'titulo': 'Tabela de Conversão de Densidade',
      'icon': Icons.science,
      'iconColor': Colors.blue,
      'tipo': 'densidade',
    },
  ];

  @override
  void initState() {
    super.initState();
    pesquisaController.addListener(() {
      setState(() {
        _pesquisa = pesquisaController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    pesquisaController.dispose();
    super.dispose();
  }

  Future<void> baixarTabela(
      BuildContext context, String titulo, String url) async {
    setState(() => baixando = true);
    try {
      if (kIsWeb) {
        html.AnchorElement(href: url)
          ..download = '${titulo.replaceAll(' ', '_')}.xlsx'
          ..target = '_blank'
          ..click();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('📥 Download iniciado: $titulo')),
        );
      } else {
        final dio = Dio();
        final dir = await getApplicationDocumentsDirectory();
        final nomeArquivo =
            '${titulo.replaceAll(' ', '_').toLowerCase()}.xlsx';
        final caminho = '${dir.path}/$nomeArquivo';
        await dio.download(url, caminho);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('📥 Download concluído: $nomeArquivo')),
        );
        await OpenFilex.open(caminho);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Erro ao baixar: $e')),
      );
    } finally {
      if (mounted) setState(() => baixando = false);
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
              children: [
                Expanded(
                  child: TextField(
                    controller: pesquisaController,
                    decoration: const InputDecoration(
                      labelText: 'Pesquisa',
                      prefixIcon: Icon(Icons.search, size: 18),
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

  List<Widget> _buildSubItensVolume() {
    return [
      ListTile(
        title: const Text('TCV Anidro e Hidratado'),
        leading: const Icon(Icons.insert_drive_file_outlined),
        onTap: () => baixarTabela(
          context,
          'TCV Anidro e Hidratado',
          'https://ikaxzlpaihdkqyjqrxyw.supabase.co/storage/v1/object/public/tcv_anidro_hidratado/tcv_anidro_hidratado.xlsx',
        ),
      ),
      ListTile(
        title: const Text('TCV Gasolina e Diesel'),
        leading: const Icon(Icons.insert_drive_file_outlined),
        onTap: () => baixarTabela(
          context,
          'TCV Gasolina e Diesel',
          'https://ikaxzlpaihdkqyjqrxyw.supabase.co/storage/v1/object/public/tcv_gasolina_diesel/tcv_gasolina_diesel.xlsx',
        ),
      ),
    ];
  }

  List<Widget> _buildSubItensDensidade() {
    return [
      ListTile(
        title: const Text('TCD Anidro e Hidratado'),
        leading: const Icon(Icons.insert_drive_file_outlined),
        onTap: () => baixarTabela(
          context,
          'TCD Anidro e Hidratado',
          'https://ikaxzlpaihdkqyjqrxyw.supabase.co/storage/v1/object/public/tcd_anidro_hidratado/TCD%20Anidro%20e%20Hidratado.xlsx',
        ),
      ),
      ListTile(
        title: const Text('TCD Gasolina e Diesel'),
        leading: const Icon(Icons.insert_drive_file_outlined),
        onTap: () => baixarTabela(
          context,
          'TCD Gasolina e Diesel',
          'https://ikaxzlpaihdkqyjqrxyw.supabase.co/storage/v1/object/public/tcd_gasolina_diesel/tcd_gasolia_diesel.xlsx',
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final itensFiltrados = _todosItens.where((item) {
      if (_pesquisa.isEmpty) return true;
      return item['titulo'].toString().toLowerCase().contains(_pesquisa);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Stack(
        children: [
          Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8F9FA),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: Color(0xFF0D47A1)),
                      onPressed: widget.onVoltar,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Downloads',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D47A1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              _buildCardFiltros(),

              // Cabeçalho da tabela
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    const SizedBox(width: 16), // margem esquerda
                    Expanded(
                      flex: 6,
                      child: Text(
                        'Nome',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Tipo',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    const SizedBox(width: 40), // espaço para ícone expand
                  ],
                ),
              ),

              const Divider(height: 1),

              // Lista
              Expanded(
                child: itensFiltrados.isEmpty
                    ? const Center(
                        child: Text(
                          'Nenhum item encontrado',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: itensFiltrados.length,
                        itemBuilder: (context, index) {
                          final item = itensFiltrados[index];
                          final bool isVolume = item['tipo'] == 'volume';
                          final bool isExpanded =
                              isVolume ? showTabelaVolume : showTabelaDensidade;

                          return Column(
                            children: [
                              MouseRegion(
                                cursor: SystemMouseCursors.click,
                                onEnter: (_) =>
                                    setState(() => _hoverIndex = index),
                                onExit: (_) =>
                                    setState(() => _hoverIndex = null),
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      if (isVolume) {
                                        showTabelaVolume = !showTabelaVolume;
                                        showTabelaDensidade = false;
                                      } else {
                                        showTabelaDensidade =
                                            !showTabelaDensidade;
                                        showTabelaVolume = false;
                                      }
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10, horizontal: 16),
                                    color: _hoverIndex == index
                                        ? Colors.grey.shade200
                                        : (index.isEven
                                            ? Colors.white
                                            : Colors.grey.shade50),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 4,
                                          height: 24,
                                          color:
                                              item['iconColor'] as Color,
                                        ),
                                        const SizedBox(width: 12),
                                        Icon(
                                          item['icon'] as IconData,
                                          color: item['iconColor'] as Color,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          flex: 6,
                                          child: Text(
                                            item['titulo'],
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            'Excel (.xlsx)',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          isExpanded
                                              ? Icons.expand_less
                                              : Icons.expand_more,
                                          color: Colors.grey,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                child: isExpanded
                                    ? Padding(
                                        padding:
                                            const EdgeInsets.only(left: 40),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: isVolume
                                              ? _buildSubItensVolume()
                                              : _buildSubItensDensidade(),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              const Divider(height: 1),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),

          // Indicador de download
          if (baixando)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
