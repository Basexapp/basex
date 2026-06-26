import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_page.dart';

/// ===============================
/// MODELO DE DADOS DO ESTOQUE
/// ===============================
class EstoqueProduto {
  final String nome;
  final String produtoId;
  final double saldoInicial;
  final double entradaDescarga;
  final double entradaBombeio;
  final double saida;
  final double transito;
  final double capacidadeTotal;
  final int posicao;

  EstoqueProduto({
    required this.nome,
    required this.produtoId,
    required this.saldoInicial,
    required this.entradaDescarga,
    required this.entradaBombeio,
    required this.saida,
    required this.transito,
    required this.capacidadeTotal,
    required this.posicao,
  });

  double get entradasTotais => entradaDescarga + entradaBombeio;
  double get tanque => saldoInicial + entradasTotais - saida;
  double get finalDoDia => tanque + transito;
  double get espaco => capacidadeTotal - finalDoDia;
}

/// ===============================
/// LINHA COMPACTA DE ESTOQUE
/// ===============================
class EstoqueLinha extends StatelessWidget {
  final EstoqueProduto produto;
  final String unidadeMedida;
  final bool mostrarTransito;

  const EstoqueLinha({
    super.key,
    required this.produto,
    required this.unidadeMedida,
    required this.mostrarTransito,
  });

  double _formatValue(double value) {
    if (unidadeMedida == 'metros') {
      return value / 1000;
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        height: 55,
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // PRODUTO
            SizedBox(
              width: 130,
              child: Text(
                produto.nome,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D47A1),
                ),
              ),
            ),

            _miniBox("Sd Inicial", _formatValue(produto.saldoInicial), const Color.fromARGB(255, 87, 87, 87)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text("+", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
            _miniBox("Entradas", _formatValue(produto.entradasTotais), Colors.indigo),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text("-", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
            _miniBox("Saídas", _formatValue(produto.saida), Colors.red),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text("=", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
            _miniBox("Sd Final", _formatValue(produto.finalDoDia), const Color.fromARGB(255, 87, 87, 87)),
            
            if (mostrarTransito) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text("+", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
              _miniBox("Trânsito", _formatValue(produto.transito), Colors.orange.shade800),
            ],

            const SizedBox(width: 30),
            // LINHA DIVISORA SUTIL
            Container(
              height: 30,
              width: 1,
              color: Colors.grey.withOpacity(0.3),
            ),
            const SizedBox(width: 30),

            _miniBox(
              "Espaço Disp.",
              _formatValue(produto.espaco),
              produto.espaco >= 0 ? Colors.grey.shade800 : Colors.red.shade900,
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniBox(String label, double value, Color color) {
    return Container(
      width: 90,
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color, width: 0.8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              unidadeMedida == 'metros' 
                  ? NumberFormat.decimalPattern('pt_BR').format(value.round())
                  : NumberFormat.decimalPattern('pt_BR').format(value),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ===============================
/// PÁGINA DE ESTOQUE GERAL (COMPACTA)
/// ===============================
class EstoqueGeralPage extends StatefulWidget {
  const EstoqueGeralPage({super.key});

  @override
  State<EstoqueGeralPage> createState() => _EstoqueGeralPageState();
}

class _EstoqueGeralPageState extends State<EstoqueGeralPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _terminais = [];
  String? _terminalSelecionadoId;
  bool _carregando = true;
  bool _carregandoDados = false;
  List<EstoqueProduto> _produtos = [];

  // Unidade de medida: 'litros' ou 'metros'
  String _unidadeMedida = 'metros';

  bool _mostrarTransito = false;

  // Filtros de Data
  DateTime _dataInicial = DateTime.now();
  DateTime _dataFinal = DateTime.now();
  
  // Empresa ID do usuário logado (pode ser null)
  String? _empresaId;

  @override
  void initState() {
    super.initState();
    _carregarDadosIniciais();
  }

  /// Carrega dados iniciais do usuário e terminais
  Future<void> _carregarDadosIniciais() async {
    final usuario = UsuarioAtual.instance;

    // Verificar se usuário está logado
    if (usuario == null) {
      debugPrint('❌ Usuário não logado');
      if (mounted) {
        setState(() {
          _carregando = false;
        });
      }
      return;
    }

    // Carregar empresa_id do usuário (pode ser null)
    _empresaId = usuario.empresaId;

    // Se o usuário tiver um `terminalId` definido, mostrar APENAS esse terminal
    final userTerminalId = usuario.terminalId;
    final userTerminalNome = usuario.terminalNome;

    if (userTerminalId != null && userTerminalId.isNotEmpty) {
      if (mounted) {
        setState(() {
          _terminais = [
            {
              'id': userTerminalId,
              'nome': userTerminalNome ?? userTerminalId,
            }
          ];
          _terminalSelecionadoId = userTerminalId;
          _carregando = false;
        });
      }

      // Carregar produtos apenas do terminal do usuário
      await _carregarProdutosDoTerminal();
      return;
    }

    // Sem terminal no usuário: carregar terminais normalmente
    await _carregarTerminais();
  }

  /// Carrega os terminais disponíveis para o usuário
  Future<void> _carregarTerminais() async {
    try {
      List<Map<String, dynamic>> lista = [];

      // Se o usuário tem empresa_id, busca apenas os terminais da empresa
      if (_empresaId != null && _empresaId!.isNotEmpty) {
        final resp = await _supabase
            .from('relacoes_terminais')
            .select('''
              terminal_id,
              terminais (
                id,
                nome
              )
            ''')
            .eq('empresa_id', _empresaId!)
            .not('terminal_id', 'is', null);

        final vistos = <String>{};

        for (final row in List<Map<String, dynamic>>.from(resp)) {
          final terminal = row['terminais'] as Map<String, dynamic>?;
          if (terminal == null) {
            continue;
          }
          
          final id = terminal['id']?.toString() ?? '';
          if (id.isEmpty || vistos.contains(id)) {
            continue;
          }
          
          vistos.add(id);
          lista.add({
            'id': id, 
            'nome': terminal['nome']?.toString() ?? id
          });
        }
      } else {
        // Se NÃO tem empresa_id, busca TODOS os terminais
        final resp = await _supabase
            .from('terminais')
            .select('id, nome')
            .order('nome');

        for (final terminal in List<Map<String, dynamic>>.from(resp)) {
          final id = terminal['id']?.toString() ?? '';
          final nome = terminal['nome']?.toString() ?? id;
          
          if (id.isNotEmpty) {
            lista.add({
              'id': id,
              'nome': nome,
            });
          }
        }
      }

      // Ordenar por nome
      lista.sort((a, b) => a['nome'].compareTo(b['nome']));

      if (mounted) {
        setState(() {
          _terminais = lista;
          // Selecionar o primeiro terminal automaticamente se houver
          _terminalSelecionadoId = lista.isNotEmpty ? lista.first['id'] : null;
          _carregando = false;
        });
        
        // Carregar produtos do terminal selecionado
        if (_terminalSelecionadoId != null) {
          await _carregarProdutosDoTerminal();
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Erro ao carregar terminais: $e');
      debugPrint('📚 Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _carregando = false;
        });
      }
    }
  }

  /// Busca o saldo inicial de um produto usando a função estoque_geral
  Future<double> _buscarSaldoInicialProduto(String produtoId) async {
    try {
      // Prepara os parâmetros
      final Map<String, dynamic> params = {
        'p_terminal_id': _terminalSelecionadoId!,
        'p_produto_id': produtoId,
      };
      
      // Adiciona empresa_id APENAS se existir
      if (_empresaId != null && _empresaId!.isNotEmpty) {
        params['p_empresa_id'] = _empresaId;
      }
      
      final response = await _supabase.rpc(
        'estoque_geral',
        params: params,
      );

      // A função retorna JSONB com estoque_inicial e debug
      if (response is Map<String, dynamic>) {
        final num saldo = response['estoque_inicial'] as num? ?? 0;
        return saldo.toDouble();
      }

      return 0.0;
      
    } catch (e) {
      debugPrint('❌ Erro ao buscar saldo inicial do produto $produtoId: $e');
      return 0.0;
    }
  }

  /// Busca as movimentações (entradas e saídas) de um produto no período
  Future<Map<String, double>> _buscarMovimentacoesProduto(
    String produtoId,
    DateTime dataInicial,
    DateTime dataFinal,
  ) async {
    try {
      final dataInicioStr = DateFormat('yyyy-MM-dd').format(dataInicial);
      final dataFimStr = DateFormat('yyyy-MM-dd').format(dataFinal);
      
      // Buscar movimentações do período
      final movimentacoes = await _supabase
          .from('movimentacoes_tanque')
          .select('''
            entrada_amb,
            entrada_vinte,
            saida_amb,
            saida_vinte,
            descricao,
            tanques!inner (
              produto_id
            )
          ''')
          .eq('tanques.produto_id', produtoId)
          .eq('tanques.terminal_id', _terminalSelecionadoId!)
          .gte('data_mov', '$dataInicioStr 00:00:00')
          .lte('data_mov', '$dataFimStr 23:59:59');

      double entradaDescarga = 0.0;
      double entradaBombeio = 0.0;
      double saida = 0.0;

      for (final mov in movimentacoes) {
        final entradaVinte = (mov['entrada_vinte'] as num?)?.toDouble() ?? 0.0;
        final saidaVinte = (mov['saida_vinte'] as num?)?.toDouble() ?? 0.0;
        
        // Classificar entrada baseado na descrição
        if (entradaVinte > 0) {
          final descricao = (mov['descricao']?.toString() ?? '').toLowerCase();
          if (descricao.contains('bombeio') || descricao.contains('bombeamento')) {
            entradaBombeio += entradaVinte;
          } else {
            entradaDescarga += entradaVinte;
          }
        }
        
        // Saídas
        if (saidaVinte > 0) {
          saida += saidaVinte;
        }
      }

      return {
        'entradaDescarga': entradaDescarga,
        'entradaBombeio': entradaBombeio,
        'saida': saida,
      };
      
    } catch (e) {
      debugPrint('❌ Erro ao buscar movimentações do produto $produtoId: $e');
      return {
        'entradaDescarga': 0.0,
        'entradaBombeio': 0.0,
        'saida': 0.0,
      };
    }
  }

  /// Busca o trânsito de um produto (diferença entre o que saiu da origem e chegou no destino)
  Future<double> _buscarTransitoProduto(
    String produtoId,
    DateTime dataInicial,
    DateTime dataFinal,
  ) async {
    try {
      // Se não tiver empresaId, NÃO busca trânsito (pois não sabe qual empresa)
      if (_empresaId == null || _empresaId!.isEmpty) {
        return 0.0;
      }
      
      final dataInicioStr = DateFormat('yyyy-MM-dd').format(dataInicial);
      final dataFimStr = DateFormat('yyyy-MM-dd').format(dataFinal);
      
      // Buscar transferências em trânsito
      final transferencias = await _supabase
          .from('movimentacoes')
          .select('''
            saida_vinte,
            entrada_vinte
          ''')
          .eq('produto_id', produtoId)
          .eq('tipo_op', 'transf')
          .eq('empresa_id', _empresaId!)
          .gte('data_mov', '$dataInicioStr 00:00:00')
          .lte('data_mov', '$dataFimStr 23:59:59');

      double transito = 0.0;
      
      for (final transf in transferencias) {
        final saidaVinte = (transf['saida_vinte'] as num?)?.toDouble() ?? 0.0;
        final entradaVinte = (transf['entrada_vinte'] as num?)?.toDouble() ?? 0.0;
        
        // Trânsito = o que saiu mas ainda não deu entrada
        transito += saidaVinte - entradaVinte;
      }

      return transito > 0 ? transito : 0.0;
      
    } catch (e) {
      debugPrint('❌ Erro ao buscar trânsito do produto $produtoId: $e');
      return 0.0;
    }
  }

  Future<void> _carregarProdutosDoTerminal() async {
    if (_terminalSelecionadoId == null) {
      return;
    }

    setState(() {
      _carregandoDados = true;
      _produtos = [];
    });

    try {
      // Buscar tanques do terminal selecionado
      final tanques = await _supabase
          .from('tanques')
          .select('''
            id,
            referencia,
            capacidade,
            produto_id,
            status,
            terminal_id
          ''')
          .eq('terminal_id', _terminalSelecionadoId!)
          .eq('status', 'Em operação');

      if (tanques.isEmpty) {
        setState(() {
          _produtos = [];
          _carregandoDados = false;
        });
        return;
      }

      // Coletar IDs dos produtos únicos
      final Set<String> produtosIds = {};
      for (final tanque in tanques) {
        final produtoId = tanque['produto_id'];
        if (produtoId != null) {
          produtosIds.add(produtoId.toString());
        }
      }

      if (produtosIds.isEmpty) {
        setState(() {
          _produtos = [];
          _carregandoDados = false;
        });
        return;
      }

      // Buscar dados dos produtos
      final produtos = await _supabase
          .from('produtos')
          .select('id, nome, posicao')
          .inFilter('id', produtosIds.toList());

      // Criar um mapa para fácil acesso aos dados do produto
      final Map<String, Map<String, dynamic>> produtosMap = {};
      for (final produto in produtos) {
        produtosMap[produto['id'].toString()] = produto;
      }

      // Agrupar tanques por produto e calcular capacidade total por produto
      final Map<String, double> capacidadePorProduto = {};

      for (final tanque in tanques) {
        final produtoId = tanque['produto_id']?.toString();
        if (produtoId == null) continue;

        final capacidade = (tanque['capacidade'] as num?)?.toDouble() ?? 0.0;

        capacidadePorProduto[produtoId] = 
            (capacidadePorProduto[produtoId] ?? 0.0) + capacidade;
      }

      // Para cada produto, buscar os dados reais
      final List<EstoqueProduto> produtosEstoque = [];

      for (final entry in capacidadePorProduto.entries) {
        final produtoId = entry.key;
        final capacidadeTotal = entry.value;
        final produtoData = produtosMap[produtoId];
        
        if (produtoData == null) {
          continue;
        }

        final nomeProduto = produtoData['nome']?.toString() ?? 'Produto Desconhecido';
        final posicao = int.tryParse(produtoData['posicao']?.toString() ?? '0') ?? 0;
        
        // Buscar saldo inicial usando a função estoque_geral
        final saldoInicial = await _buscarSaldoInicialProduto(produtoId);
        
        // Buscar movimentações no período
        final movimentacoes = await _buscarMovimentacoesProduto(
          produtoId,
          _dataInicial,
          _dataFinal,
        );
        
        // Buscar trânsito no período (só se tiver empresaId)
        double transito = 0.0;
        if (_empresaId != null && _empresaId!.isNotEmpty) {
          transito = await _buscarTransitoProduto(
            produtoId,
            _dataInicial,
            _dataFinal,
          );
        }
        
        produtosEstoque.add(EstoqueProduto(
          nome: nomeProduto,
          produtoId: produtoId,
          saldoInicial: saldoInicial,
          entradaDescarga: movimentacoes['entradaDescarga'] ?? 0.0,
          entradaBombeio: movimentacoes['entradaBombeio'] ?? 0.0,
          saida: movimentacoes['saida'] ?? 0.0,
          transito: transito,
          capacidadeTotal: capacidadeTotal,
          posicao: posicao,
        ));
      }

      // Ordenar produtos por posição de forma ascendente
      produtosEstoque.sort((a, b) => a.posicao.compareTo(b.posicao));

      setState(() {
        _produtos = produtosEstoque;
        _carregandoDados = false;
      });

    } catch (e, stackTrace) {
      debugPrint('❌ ERRO ao carregar produtos do terminal: $e');
      debugPrint('📚 Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _produtos = [];
          _carregandoDados = false;
        });
      }
    }
  }

  Future<void> _selecionarData(BuildContext context, bool isInicial) async {
    DateTime tempDate = isInicial ? _dataInicial : _dataFinal;

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
                    // Header
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          color: Color(0xFF0D47A1),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          isInicial ? 'Data inicial' : 'Data final',
                          style: const TextStyle(
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

                    // Mês e Ano
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

                    // Dias da semana
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

                    // Dias do mês
                    GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: 7,
                      childAspectRatio: 1.0,
                      children: _getDaysInMonth(tempDate).map((day) {
                        final isSelected = day != null && day == tempDate.day;
                        final isToday = day != null &&
                            day == DateTime.now().day &&
                            tempDate.month == DateTime.now().month &&
                            tempDate.year == DateTime.now().year;

                        return StatefulBuilder(
                          builder: (context, setDayState) {
                            return MouseRegion(
                              cursor: day != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
                              onEnter: (_) { if (day != null) { setDayState(() => hoveredDay = day); } },
                              onExit: (_) { if (day != null) { setDayState(() => hoveredDay = null); } },
                              child: GestureDetector(
                                onTap: day != null
                              ? () {
                                  setStateDialog(() {
                                    tempDate = DateTime(tempDate.year, tempDate.month, day);
                                  });
                                }
                              : null,
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

                    // Botões
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

    if (selecionado != null) {
      setState(() {
        if (isInicial) {
          _dataInicial = selecionado;
          if (_dataInicial.isAfter(_dataFinal)) {
            _dataFinal = _dataInicial;
          }
        } else {
          _dataFinal = selecionado;
          if (_dataFinal.isBefore(_dataInicial)) {
            _dataInicial = _dataFinal;
          }
        }
      });
      // Recarregar dados com as novas datas
      await _carregarProdutosDoTerminal();
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

  Widget _buildCampoData({
    required String label,
    required DateTime data,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF0D47A1), width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_today, size: 12, color: Color(0xFF0D47A1)),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0D47A1),
                    ),
                  ),
                  Text(
                    DateFormat('dd/MM/yyyy').format(data),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D47A1),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CABEÇALHO
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Estoque Geral',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // NAVEGAÇÃO POR TERMINAIS
            if (_carregando && _terminais.isEmpty)
              const SizedBox(
                height: 36,
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (_terminais.isNotEmpty)
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _terminais.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final terminal = _terminais[index];
                    final selecionado = terminal['id'] == _terminalSelecionadoId;
                    return MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () async {
                          setState(() => _terminalSelecionadoId = terminal['id']);
                          await _carregarProdutosDoTerminal();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: selecionado
                                ? Colors.green.withOpacity(0.1)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selecionado ? Colors.green.shade700 : const Color(0xFF0D47A1),
                              width: selecionado ? 1.5 : 0.8,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              terminal['nome'],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: selecionado
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: selecionado ? Colors.green.shade700 : const Color(0xFF0D47A1),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              )
            else
              const SizedBox(height: 36),

            const SizedBox(height: 12),

            // FILTROS DE DATA
            Row(
              children: [
                // Botão Hoje
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () async {
                      final hoje = DateTime.now();
                      setState(() {
                        _dataInicial = hoje;
                        _dataFinal = hoje;
                      });
                      await _carregarProdutosDoTerminal();
                    },
                    child: Builder(
                      builder: (context) {
                        final hoje = DateTime.now();
                        final isHoje = DateUtils.isSameDay(_dataInicial, hoje) && 
                                      DateUtils.isSameDay(_dataFinal, hoje);
                        
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isHoje ? Colors.green.withOpacity(0.1) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isHoje ? Colors.green.shade700 : const Color(0xFF0D47A1), 
                              width: isHoje ? 1.5 : 0.8
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Hoje',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isHoje ? FontWeight.bold : FontWeight.w600,
                                color: isHoje ? Colors.green.shade700 : const Color(0xFF0D47A1),
                              ),
                            ),
                          ),
                        );
                      }
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Botão Ontem
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () async {
                      final ontem = DateTime.now().subtract(const Duration(days: 1));
                      setState(() {
                        _dataInicial = ontem;
                        _dataFinal = ontem;
                      });
                      await _carregarProdutosDoTerminal();
                    },
                    child: Builder(
                      builder: (context) {
                        final ontem = DateTime.now().subtract(const Duration(days: 1));
                        final isOntem = DateUtils.isSameDay(_dataInicial, ontem) && 
                                       DateUtils.isSameDay(_dataFinal, ontem);
                        
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isOntem ? Colors.green.withOpacity(0.1) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isOntem ? Colors.green.shade700 : const Color(0xFF0D47A1), 
                              width: isOntem ? 1.5 : 0.8
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Ontem',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isOntem ? FontWeight.bold : FontWeight.w600,
                                color: isOntem ? Colors.green.shade700 : const Color(0xFF0D47A1),
                              ),
                            ),
                          ),
                        );
                      }
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _buildCampoData(
                  label: 'Data Inicial',
                  data: _dataInicial,
                  onTap: () => _selecionarData(context, true),
                ),
                const SizedBox(width: 12),
                _buildCampoData(
                  label: 'Data Final',
                  data: _dataFinal,
                  onTap: () => _selecionarData(context, false),
                ),
                const SizedBox(width: 12),
                // Dropdown de Unidade de Medida
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF0D47A1), width: 0.8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isDense: true,
                      value: _unidadeMedida,
                      icon: const Icon(Icons.tune, size: 16, color: Color(0xFF0D47A1)),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0D47A1),
                      ),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _unidadeMedida = newValue;
                          });
                        }
                      },
                      items: const [
                        DropdownMenuItem(
                          value: 'litros',
                          child: Text('litros (l)'),
                        ),
                        DropdownMenuItem(
                          value: 'metros',
                          child: Text('metros (m³)'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Botão Em Trânsito
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _mostrarTransito = !_mostrarTransito;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: _mostrarTransito ? Colors.green.withOpacity(0.1) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _mostrarTransito ? Colors.green.shade700 : const Color(0xFF0D47A1),
                          width: _mostrarTransito ? 1.5 : 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.local_shipping_outlined,
                            size: 16,
                            color: _mostrarTransito ? Colors.green.shade700 : const Color(0xFF0D47A1),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Em Trânsito',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _mostrarTransito ? FontWeight.bold : FontWeight.w600,
                              color: _mostrarTransito ? Colors.green.shade700 : const Color(0xFF0D47A1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_carregandoDados)
                  const Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),

            // LISTA DE PRODUTOS
            if (_carregandoDados && _produtos.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Carregando dados dos produtos...',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else if (_produtos.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text(
                    'Nenhum produto encontrado para este terminal',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _produtos.length,
                  itemBuilder: (context, index) => EstoqueLinha(
                    produto: _produtos[index],
                    unidadeMedida: _unidadeMedida,
                    mostrarTransito: _mostrarTransito,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}