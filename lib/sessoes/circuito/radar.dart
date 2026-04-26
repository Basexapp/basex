import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../../login_page.dart";
import "detalhes_estagio.dart";

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

  List<Map<String, dynamic>> _terminais = [];
  List<String> produtos = [];
  
  // filtros
  String? produtoSelecionado;
  String? tipoOperacaoSelecionada; // "Carga" ou "Descarga"
  DateTime? dataFiltro;
  final TextEditingController dataFiltroCtrl = TextEditingController();
  final TextEditingController terminalController = TextEditingController();
  String? _terminalSelecionado;
  int? _nivel;
  Map<String, dynamic>? _usuarioData;
  int? _hoverIndex;
  bool _tabelaHover = false;

  final List<Map<String, dynamic>> _estagios = [
    {
      "titulo": "Programados",
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
      "cor": const Color(0xFF673AB7), // Roxo em vez de cinza
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
            const Spacer(flex: 2),
            LayoutBuilder(
              builder: (context, constraints) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_estagios.length, (index) {
                    final estagio = _estagios[index];
                    final bool isLast = index == _estagios.length - 1;
                    final double itemWidth = (constraints.maxWidth - 64) / _estagios.length;

                    return SizedBox(
                      width: itemWidth,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 2,
                                  color: index == 0 ? Colors.transparent : Colors.grey.shade300,
                                ),
                              ),
                              SizedBox(
                                width: 70, // Tamanho fixo para conter o ícone e seu efeito de hover
                                height: 70, // sem deslocar os elementos abaixo
                                child: Center(
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    onEnter: (_) => setState(() => _hoverIndex = index),
                                    onExit: (_) => setState(() => _hoverIndex = null),
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() => _currentPage = index.toDouble());
                                        showDialog(
                                          context: context,
                                          builder: (context) => Dialog(
                                            backgroundColor: Colors.white,
                                            surfaceTintColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16),
                                              side: BorderSide(
                                                color: estagio["cor"],
                                                width: 1,
                                              ),
                                            ),
                                            child: Container(
                                              width: 1100,
                                              height: MediaQuery.of(context).size.height * 0.8,
                                              padding: const EdgeInsets.all(16),
                                              child: DetalhesEstagioPage(
                                                estagio: estagio,
                                                produtos: produtos,
                                                terminais: _terminais,
                                                nivel: _nivel,
                                                dataInicial: dataFiltro,
                                                apenasTabela: true,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        padding: EdgeInsets.all(_hoverIndex == index ? 16 : 12),
                                        decoration: BoxDecoration(
                                          color: estagio["cor"],
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: estagio["cor"].withOpacity(0.5),
                                            width: 2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: estagio["cor"].withOpacity(0.4),
                                              blurRadius: _hoverIndex == index ? 15 : 8,
                                              offset: const Offset(0, 4),
                                            )
                                          ],
                                        ),
                                        child: Icon(
                                          estagio["icone"],
                                          size: _hoverIndex == index ? 30 : 24,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  height: 2,
                                  color: isLast ? Colors.transparent : Colors.grey.shade300,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            estagio["titulo"],
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: estagio["cor"],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            decoration: BoxDecoration(
                              color: estagio["cor"].withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "${estagio["qtd"]} veíc.",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: estagio["cor"],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                );
              },
            ),
            const SizedBox(height: 160),
            Center(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _tabelaHover = true),
                onExit: (_) => setState(() => _tabelaHover = false),
                child: GestureDetector(
                  onTap: () {
                    final estagioAtual = _estagios[_currentPage.round()];
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DetalhesEstagioPage(
                          estagio: estagioAtual,
                          produtos: produtos,
                          terminais: _terminais,
                          nivel: _nivel,
                          dataInicial: dataFiltro,
                        ),
                      ),
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: EdgeInsets.all(_tabelaHover ? 20 : 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D47A1),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: _tabelaHover ? 12 : 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.table_chart_outlined,
                              color: Colors.white,
                              size: _tabelaHover ? 38 : 32,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Ver em tabela",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0D47A1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

