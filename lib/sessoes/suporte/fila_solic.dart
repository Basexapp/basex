import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'desenvolvedor.dart';
import 'detalhe_solic.dart';

class FilaSolicitacoesPage extends StatefulWidget {
  final VoidCallback onVoltar;

  const FilaSolicitacoesPage({
    super.key,
    required this.onVoltar,
  });

  @override
  State<FilaSolicitacoesPage> createState() => _FilaSolicitacoesPageState();
}

class _FilaSolicitacoesPageState extends State<FilaSolicitacoesPage> {
  bool carregando = true;
  Map<String, dynamic>? solicitacaoSelecionada;
  List<Map<String, dynamic>> solicitacoes = [];

  @override
  void initState() {
    super.initState();
    _buscarSolicitacoes();
  }

  Future<void> _buscarSolicitacoes() async {
    setState(() => carregando = true);
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('ajuda')
          .select('*, usuarios!ajuda_usuario_id_fkey(Nome_apelido)')
          .order('data_criacao', ascending: false);

      setState(() {
        solicitacoes = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('Erro ao buscar solicitacoes: $e');
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

  String _formatarData(String? data) {
    if (data == null) return '-';
    try {
      final d = DateTime.parse(data);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return data;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'concluido':
        return Colors.green;
      case 'em analise':
      case 'desenvolvimento':
        return Colors.blue;
      case 'pendente':
        return Colors.orange;
      case 'cancelado':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (solicitacaoSelecionada != null) {
      return DetalheSolicitacaoPage(
        solicitacao: solicitacaoSelecionada!,
        onVoltar: () {
          setState(() {
            solicitacaoSelecionada = null;
          });
        },
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent, // Remove o tom de azul do Flutter no AppBar do Material 3
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF263238)),
          onPressed: widget.onVoltar,
        ),
        title: const Text(
          'Fila de Solicitações',
          style: TextStyle(color: Color(0xFF263238), fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: const Color(0xFFEEEEEE), height: 1.0),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DesenvolvedorPage(),
            ),
          );
        },
        backgroundColor: const Color(0xFF263238),
        tooltip: 'Nova solicitação',
        elevation: 2,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: const Text(
              'Acompanhe as solicitações de melhoria e novas funcionalidades.',
              style: TextStyle(color: Colors.blueGrey, fontSize: 13),
            ),
          ),
          // LINHA DE TÍTULOS
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF8F9FA),
              border: Border(
                top: BorderSide(color: Color(0xFFEEEEEE)),
                bottom: BorderSide(color: Color(0xFFEEEEEE)),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    'DATA CRIAÇÃO',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey[700]),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 120,
                  child: Text(
                    'SOLICITANTE',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey[700]),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: Text(
                    'TÍTULO',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey[700]),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 130,
                  child: Text(
                    'Nº CONTROLE',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey[700]),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 130,
                  child: Text(
                    'PREVISÃO',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey[700]),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 100,
                  child: Align(
                    alignment: Alignment.center,
                    child: Text(
                      'STATUS',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey[700]),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: carregando
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF263238)))
                : solicitacoes.isEmpty
                    ? const Center(
                        child: Text(
                          'Nenhuma solicitação encontrada.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: solicitacoes.length,
                        itemBuilder: (context, index) {
                          final item = solicitacoes[index];
                          final usuario = item['usuarios']?['Nome_apelido'] ?? 'Anônimo';

                          return Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    solicitacaoSelecionada = item;
                                  });
                                },
                                splashColor: const Color(0xFFF5F5F5),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(
                                    children: [
                                      // Data Criação
                                      SizedBox(
                                        width: 100,
                                        child: Text(
                                          _formatarData(item['data_criacao']),
                                          style: const TextStyle(fontSize: 13, color: Color(0xFF263238)),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      
                                      // Solicitante
                                      SizedBox(
                                        width: 120,
                                        child: Text(
                                          usuario,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 13, color: Color(0xFF263238)),
                                        ),
                                      ),
                                      const SizedBox(width: 8),

                                      // Título
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          item['titulo'] ?? '',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF263238),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),

                                      // Nº Controle
                                      SizedBox(
                                        width: 130,
                                        child: Text(
                                          item['n_controle']?.toString() ?? '-',
                                          style: TextStyle(fontSize: 12, color: Colors.blueGrey[600], fontFamily: 'monospace'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),

                                      // Previsão
                                      SizedBox(
                                        width: 130,
                                        child: Text(
                                          _formatarData(item['previsao']),
                                          style: const TextStyle(fontSize: 13, color: Color(0xFF263238)),
                                        ),
                                      ),
                                      const SizedBox(width: 8),

                                      // Status
                                      SizedBox(
                                        width: 100,
                                        child: Center(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(item['status']).withOpacity(0.1),
                                              border: Border.all(
                                                color: _getStatusColor(item['status']).withOpacity(0.5),
                                              ),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              item['status']?.toUpperCase() ?? '',
                                              style: TextStyle(
                                                color: _getStatusColor(item['status']),
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
