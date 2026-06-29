import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DownloadsPage extends StatefulWidget {
  final VoidCallback onVoltar;

  const DownloadsPage({
    super.key,
    required this.onVoltar,
  });

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  bool carregando = false;
  List<Map<String, dynamic>> arquivos = [];

  @override
  void initState() {
    super.initState();
    _carregarArquivos();
  }

  Future<void> _carregarArquivos() async {
    setState(() => carregando = true);
    final supabase = Supabase.instance.client;
    
    try {
      final dados = await supabase
          .from('arquivos_download') // Você precisará criar esta tabela no Supabase
          .select('*')
          .order('data_criacao', ascending: false);
      
      setState(() {
        arquivos = dados.map((arquivo) {
          return {
            'id': arquivo['id'],
            'nome': arquivo['nome'] ?? 'Arquivo sem nome',
            'descricao': arquivo['descricao'] ?? '',
            'tamanho': arquivo['tamanho'] ?? '',
            'tipo': arquivo['tipo'] ?? 'outro',
            'url': arquivo['url'] ?? '',
            'data': arquivo['data_criacao'] != null
                ? DateTime.parse(arquivo['data_criacao']).toLocal()
                : DateTime.now(),
          };
        }).toList();
      });
    } catch (e) {
      debugPrint("❌ Erro ao carregar arquivos: $e");
      // Fallback com dados de exemplo
      _carregarDadosExemplo();
    } finally {
      setState(() => carregando = false);
    }
  }

  void _carregarDadosExemplo() {
    setState(() {
      arquivos = [
        {
          'id': '1',
          'nome': 'Relatório de Estoque Mensal',
          'descricao': 'Relatório consolidado do mês anterior',
          'tamanho': '2.4 MB',
          'tipo': 'pdf',
          'data': DateTime.now().subtract(const Duration(days: 2)),
        },
        {
          'id': '2',
          'nome': 'Planilha de Movimentações',
          'descricao': 'Exportação em Excel de todas as movimentações',
          'tamanho': '1.8 MB',
          'tipo': 'excel',
          'data': DateTime.now().subtract(const Duration(days: 5)),
        },
        {
          'id': '3',
          'nome': 'Manual do Sistema',
          'descricao': 'Guia completo de utilização do Base-X',
          'tamanho': '5.2 MB',
          'tipo': 'pdf',
          'data': DateTime.now().subtract(const Duration(days: 10)),
        },
        {
          'id': '4',
          'nome': 'Template de Importação',
          'descricao': 'Modelo para importação de dados',
          'tamanho': '350 KB',
          'tipo': 'excel',
          'data': DateTime.now().subtract(const Duration(days: 15)),
        },
        {
          'id': '5',
          'nome': 'Relatório de Alertas',
          'descricao': 'Alertas e inconsistências do sistema',
          'tamanho': '1.1 MB',
          'tipo': 'pdf',
          'data': DateTime.now().subtract(const Duration(days: 1)),
        },
      ];
    });
  }

  IconData _getIconByType(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'excel':
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'word':
      case 'doc':
      case 'docx':
        return Icons.article;
      case 'image':
      case 'jpg':
      case 'png':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getColorByType(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'pdf':
        return Colors.red;
      case 'excel':
      case 'xls':
      case 'xlsx':
        return Colors.green;
      case 'word':
      case 'doc':
      case 'docx':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  void _simularDownload(int index) {
    final arquivo = arquivos[index];
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Iniciando download: ${arquivo['nome']}'),
        backgroundColor: const Color(0xFF0D47A1),
      ),
    );
    
    // Aqui você implementaria a lógica real de download
    // usando a URL do arquivo no Supabase Storage
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // CABEÇALHO COM BOTÃO VOLTAR
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
              onPressed: widget.onVoltar,
            ),
            const SizedBox(width: 10),
            const Text(
              'Downloads',
              style: TextStyle(
                fontSize: 24,
                color: Color(0xFF047A1),
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF0D47A1)),
              onPressed: _carregarArquivos,
              tooltip: 'Atualizar lista',
            ),
          ],
        ),
        
        const SizedBox(height: 10),
        const Divider(color: Colors.grey),
        const SizedBox(height: 20),
        
        // MENSAGEM INFORMATIVA
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[100]!),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Aqui você encontra arquivos para download como relatórios, templates e manuais do sistema.',
                  style: TextStyle(
                    color: Color.fromARGB(255, 22, 102, 194),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 25),
        
        // LISTA DE ARQUIVOS
        Expanded(
          child: carregando
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF0D47A1)),
                )
              : arquivos.isEmpty
                  ? const Center(
                      child: Text(
                        'Nenhum arquivo disponível para download.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: arquivos.length,
                      itemBuilder: (context, index) {
                        final arquivo = arquivos[index];
                        final data = arquivo['data'] as DateTime;
                        
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: ListTile(
                            leading: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: _getColorByType(arquivo['tipo']).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _getIconByType(arquivo['tipo']),
                                color: _getColorByType(arquivo['tipo']),
                                size: 30,
                              ),
                            ),
                            title: Text(
                              arquivo['nome'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0D47A1),
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(arquivo['descricao']),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      arquivo['tamanho'],
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      '${data.day}/${data.month}/${data.year}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.download,
                                color: Color(0xFF0D47A1),
                              ),
                              onPressed: () => _simularDownload(index),
                              tooltip: 'Baixar arquivo',
                            ),
                            onTap: () => _simularDownload(index),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}