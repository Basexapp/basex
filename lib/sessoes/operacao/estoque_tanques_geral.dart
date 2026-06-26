import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'estoque_tanque_dia.dart';
import 'estoque_tanque_mensal.dart';
import '../../main.dart';

class DadosTanque {
  final String id;
  final String nome;
  final double capacidadeTotal;
  final double lastro;
  final List<DetalheTanque> detalhes;

  DadosTanque({
    required this.id,
    required this.nome,
    required this.capacidadeTotal,
    required this.lastro,
    required this.detalhes,
  });

  double get estoqueAtual {
    if (detalhes.isEmpty) return 0;
    return detalhes.first.litros.clamp(0, capacidadeTotal);
  }

  double get percentualPreenchimento => capacidadeTotal > 0
      ? (estoqueAtual / capacidadeTotal * 100).clamp(0, 100)
      : 0;
}

class DetalheTanque {
  final String produto;
  final double litros;
  final String data;
  final String tipo;

  DetalheTanque({
    required this.produto,
    required this.litros,
    required this.data,
    required this.tipo,
  });
}

class EstoquePorTanquePage extends StatefulWidget {
  final VoidCallback? onVoltar;
  final String? terminalSelecionadoId;

  const EstoquePorTanquePage({
    super.key,
    this.onVoltar,
    this.terminalSelecionadoId,
  });

  @override
  State<EstoquePorTanquePage> createState() => _EstoquePorTanquePageState();
}

class _EstoquePorTanquePageState extends State<EstoquePorTanquePage>
  with RouteAware {
  List<DadosTanque> tanques = [];
  bool _carregando = true;
  int tanqueSelecionadoIndex = -1; // -1 significa "Todos"
  int? _hoverIndex;
  String? _nomeTerminal;
  bool _mostrarPrevisto = false;
  bool _usarMetrosCubicos = true;
  String? _hoverSwitchOption;
  String? _hoverUnitOption;

  final ScrollController _menuScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _carregarDadosTanques();
    _carregarNomeTerminal();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route as ModalRoute<dynamic>);
    }
  }

  @override
  void dispose() {
    try {
      routeObserver.unsubscribe(this);
    } catch (_) {}
    _menuScrollController.dispose();
    super.dispose();
  }

  @override
  void didPush() {
    // Página foi empurrada para a pilha — atualizar sempre ao abrir
    _carregarDadosTanques();
    _carregarNomeTerminal();
  }

  @override
  void didPopNext() {
    // Voltou para esta página a partir de outra — atualizar incondicionalmente
    _carregarDadosTanques();
    _carregarNomeTerminal();
  }

  Future<void> _carregarNomeTerminal() async {
    if (widget.terminalSelecionadoId == null) return;
    try {
      final resp = await Supabase.instance.client
          .from('terminais')
          .select('nome')
          .eq('id', widget.terminalSelecionadoId!)
          .maybeSingle();
      if (resp != null && mounted) {
        setState(() {
          _nomeTerminal = resp['nome']?.toString();
        });
      }
    } catch (_) {}
  }

  Future<void> _carregarDadosTanques() async {
    setState(() => _carregando = true);

    if (widget.terminalSelecionadoId == null) {
      setState(() {
        tanques = [];
        _carregando = false;
      });
      return;
    }

    final supabase = Supabase.instance.client;

    try {
      final resp = await supabase
          .from('tanques')
          .select('id, referencia, capacidade, lastro, produtos(nome)')
          .eq('terminal_id', widget.terminalSelecionadoId!)
          .order('referencia');

      final List<DadosTanque> lista = [];
      final now = DateTime.now();
      final dataStr = DateFormat('yyyy-MM-dd').format(now);

      for (final t in List<Map<String, dynamic>>.from(resp)) {
        final id = t['id'].toString();
        final referencia = t['referencia']?.toString() ?? 'Tanque';
        final produtoNome = t['produtos']?['nome']?.toString();
        final nomeCompleto = produtoNome != null
            ? '$referencia - $produtoNome'
            : referencia;
        final capacidadeVal = (t['capacidade'] as num).toDouble();

        double estoqueInicial = 0.0;

        try {
          final rpc = await supabase.rpc(
            'saldo_inicial_estoque_tanques_geral',
            params: {'p_tanque_id': id, 'p_data': dataStr},
          );

          if (rpc is Map) {
            estoqueInicial = (rpc['estoque_inicial'] ?? 0).toDouble();
          } else {
            estoqueInicial = (rpc ?? 0).toDouble();
          }
        } catch (e) {
          estoqueInicial = 0.0;
        }

        double estoqueAtual = estoqueInicial;

        try {
          final movs = await supabase
              .from('movimentacoes_tanque')
              .select('entrada_vinte, saida_vinte')
              .eq('tanque_id', id)
              .gte('data_mov', '$dataStr 00:00:00')
              .lte('data_mov', '$dataStr 23:59:59');

          for (final m in List<Map<String, dynamic>>.from(movs)) {
            final entrada = (m['entrada_vinte'] ?? 0) as num;
            final saida = (m['saida_vinte'] ?? 0) as num;
            estoqueAtual += (entrada - saida).toDouble();
          }
        } catch (e) {
          // mantém estoqueAtual = estoqueInicial em caso de erro
        }

        final detalhes = [
          DetalheTanque(
            produto: "Saldo Atual",
            litros: estoqueAtual,
            data: DateFormat('dd/MM/yyyy HH:mm').format(now),
            tipo: estoqueAtual >= 0 ? 'entrada' : 'saida',
          ),
        ];

        final lastroVal = (t['lastro'] as num?)?.toDouble() ?? 0.0;

        lista.add(
          DadosTanque(
            id: id,
            nome: nomeCompleto,
            capacidadeTotal: capacidadeVal,
            lastro: lastroVal,
            detalhes: detalhes,
          ),
        );
      }

      setState(() {
        tanques = lista;
        tanqueSelecionadoIndex = -1; // Começa por padrão em "Todos"
        _carregando = false;
      });
    } catch (e) {
      setState(() {
        tanques = [];
        _carregando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Estoque por Tanque',
          style: TextStyle(
            color: Color(0xFF222B45),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF222B45)),
          onPressed: () {
            if (widget.onVoltar != null) {
              widget.onVoltar!();
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: _carregando
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(),
              ),
            )
          : (tanques.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.storage,
                            size: 64,
                            color: Color(0xFF8F9BB3),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Nenhum tanque encontrado',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF222B45),
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Verifique a seleção do terminal ou tente recarregar.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF8F9BB3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: [
                      _construirMenuTanques(),
                      Expanded(child: _construirDetalheTanque()),
                    ],
                  )),
    );
  }

  Widget _construirMenuTanques() {
    final tanquesInvertidos = tanques.reversed.toList();

    return Container(
      color: const Color(0xFFF8F9FA),
      child: Column(
        children: [
          Row(
            children: [
              _buildScrollButton(Icons.chevron_left, -200),
              Expanded(
                child: SingleChildScrollView(
                  controller: _menuScrollController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      // Adicionando o botão "Todos" na primeira posição
                      Padding(
                        padding: const EdgeInsets.only(right: 12, left: 4),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          onEnter: (_) {
                            setState(() {
                              _hoverIndex = -1;
                            });
                          },
                          onExit: (_) {
                            setState(() {
                              _hoverIndex = null;
                            });
                          },
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                tanqueSelecionadoIndex = -1;
                              });
                            },
                            child: SizedBox(
                              height: 70,
                              width: 110,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOut,
                                alignment: Alignment.center,
                                transform:
                                    _hoverIndex == -1 && tanqueSelecionadoIndex != -1
                                    ? (Matrix4.identity()..scale(1.0, 1.08, 1.0))
                                    : Matrix4.identity(),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: tanqueSelecionadoIndex == -1
                                      ? const Color(0xFF0D47A1)
                                      : (_hoverIndex == -1
                                            ? const Color(0xFFE8EAF2)
                                            : const Color(0xFFF0F1F6)),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: tanqueSelecionadoIndex == -1
                                        ? const Color(0xFF0D47A1)
                                        : (_hoverIndex == -1
                                              ? const Color(0xFF3366FF)
                                              : const Color(0xFFE0E3EB)),
                                    width:
                                        _hoverIndex == -1 &&
                                            tanqueSelecionadoIndex != -1
                                        ? 2.0
                                        : 1.5,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Visão Geral',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: tanqueSelecionadoIndex == -1
                                            ? const Color(0xFFF8F9FA)
                                            : const Color(0xFF0D47A1),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      ...List.generate(tanquesInvertidos.length, (index) {
                        final tanque = tanquesInvertidos[index];
                        final realIndex = tanques.length - 1 - index;
                        final isSelected = tanqueSelecionadoIndex == realIndex;
                        final isHovered = _hoverIndex == realIndex;

                        return Padding(
                          padding: EdgeInsets.only(
                            right: index < tanquesInvertidos.length - 1 ? 12 : 0,
                          ),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            onEnter: (_) {
                              setState(() {
                                _hoverIndex = realIndex;
                              });
                            },
                            onExit: (_) {
                              setState(() {
                                _hoverIndex = null;
                              });
                            },
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  tanqueSelecionadoIndex = realIndex;
                                });
                              },
                              child: SizedBox(
                                height: 70, // Aumentado para acomodar quebras de linha
                                width: 110, // Aumentado levemente para dar mais espaço lateral
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOut,
                                  alignment: Alignment.center, // Centraliza o conteúdo internally
                                  transform: isHovered && !isSelected
                                      ? (Matrix4.identity()..scale(1.0, 1.08, 1.0))
                                      : Matrix4.identity(),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8, // Reduzido o padding horizontal para favorecer o texto
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF0D47A1)
                                        : (isHovered
                                              ? const Color(0xFFE8EAF2)
                                              : const Color(0xFFF0F1F6)),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF0D47A1)
                                          : (isHovered
                                                ? const Color(0xFF3366FF)
                                                : const Color(0xFFE0E3EB)),
                                      width: isHovered && !isSelected ? 2.0 : 1.5,
                                    ),
                                    boxShadow: isHovered && !isSelected
                                        ? [
                                            BoxShadow(
                                              color: const Color(
                                                0xFF3366FF,
                                              ).withOpacity(0.2),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        tanque.nome.split(' - ').first,
                                        textAlign: TextAlign.center, // Centraliza o texto
                                        style: TextStyle(
                                          color: isSelected
                                              ? const Color(0xFFF8F9FA)
                                              : const Color(0xFF0D47A1),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (tanque.nome.contains(' - ')) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          tanque.nome.split(' - ').last,
                                          textAlign: TextAlign.center, // Alinhamento central para quebra de linha
                                          maxLines: 2, // Permite quebra em até 2 linhas para o nome do produto
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: isSelected
                                                ? const Color(0xFFBFC8E6)
                                                : (isHovered
                                                      ? const Color(0xFF3366FF)
                                                      : const Color(0xFF5A6275)),
                                            fontSize: 10,
                                            fontWeight: isHovered
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              _buildScrollButton(Icons.chevron_right, 200),
            ],
          ),
          const SizedBox(height: 8),
          Container(height: 1, color: const Color(0xFFE0E3EB)),
        ],
      ),
    );
  }

  Widget _buildScrollButton(IconData icon, double offset) {
    return IconButton(
      icon: Icon(icon, color: const Color(0xFF0D47A1), size: 24),
      onPressed: () {
        if (_menuScrollController.hasClients) {
          _menuScrollController.animateTo(
            (_menuScrollController.offset + offset).clamp(
              0.0,
              _menuScrollController.position.maxScrollExtent,
            ),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      },
    );
  }

  Widget _construirDetalheTanque() {
    if (tanqueSelecionadoIndex == -1) {
      return _construirVisualizacaoTodosTanques();
    }

    final tanque = tanques[tanqueSelecionadoIndex];
    final percentual = tanque.percentualPreenchimento;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _construirIndicadorNivelIlustrativo(tanque, percentual),
          const SizedBox(height: 20),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final tanque = tanques[tanqueSelecionadoIndex];
                    final terminalId = widget.terminalSelecionadoId ?? '';
                    final nomeTerminal = _nomeTerminal ?? '';

                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      isDismissible: true,
                      enableDrag: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) =>
                          _SelecaoTipoVisualizacaoEstoqueBottomSheet(
                            tanqueId: tanque.id,
                            referenciaTanque: tanque.nome.split(' - ').first,
                            terminalId: terminalId,
                            nomeTerminal: nomeTerminal,
                            onVoltar: () {
                              // Não recarrega tudo se apenas fechou o modal
                            },
                          ),
                    );
                  },
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text(
                    'Ver movimentação do tanque',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D47A1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirVisualizacaoTodosTanques() {
    return Column(
      children: [
        // Linha de switches posicionada imediatamente abaixo da divisória
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                // Switch de Estoque Previsto / Atual
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) =>
                      setState(() => _hoverSwitchOption = 'previsto'),
                  onExit: (_) => setState(() => _hoverSwitchOption = null),
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _mostrarPrevisto = !_mostrarPrevisto),
                    child: Container(
                      width: 170,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildSwitchOption(
                              'Previsto',
                              _mostrarPrevisto,
                              _hoverSwitchOption == 'previsto' &&
                                  !_mostrarPrevisto,
                            ),
                          ),
                          Expanded(
                            child: _buildSwitchOption(
                              'Atual',
                              !_mostrarPrevisto,
                              _hoverSwitchOption == 'previsto' &&
                                  _mostrarPrevisto,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Switch de Unidade (m³ / L)
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => setState(() => _hoverUnitOption = 'unit'),
                  onExit: (_) => setState(() => _hoverUnitOption = null),
                  child: GestureDetector(
                    onTap: () => setState(
                        () => _usarMetrosCubicos = !_usarMetrosCubicos),
                    child: Container(
                      width: 170,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildSwitchOption(
                              'm³',
                              _usarMetrosCubicos,
                              _hoverUnitOption == 'unit' && !_usarMetrosCubicos,
                            ),
                          ),
                          Expanded(
                            child: _buildSwitchOption(
                              'Litros',
                              !_usarMetrosCubicos,
                              _hoverUnitOption == 'unit' && _usarMetrosCubicos,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Conteúdo rolável para os tanques
        Expanded(
          child: SingleChildScrollView(
            child: Center(
              child: Column(
                children: [
                  const SizedBox(height: 60), // Aumentado de 12 para 60 para afastar os tanques (aprox. 50px extras)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final int totalTanques = tanques.length;
                      final availableWidth = constraints.maxWidth;
                      const int tanksPerRow = 6;
                      final int tanksInThisCalculation =
                          totalTanques < tanksPerRow
                              ? totalTanques
                              : tanksPerRow;

                      // Calcula o tamanho base para que caibam até 6 por linha.
                      const double spacing = 16.0;
                      double dynamicBaseWidth = (((availableWidth -
                                      (spacing * (tanksInThisCalculation - 1))) /
                                  tanksInThisCalculation) *
                              0.85)
                          .clamp(50.0, 240.0);
                      double dynamicBaseHeight = dynamicBaseWidth * 1.15;
                      double dynamicScale = dynamicBaseWidth / 280.0;

                      final reversedTanques = tanques.reversed.toList();
                      final List<Widget> rows = [];

                      for (int i = 0; i < reversedTanques.length; i += tanksPerRow) {
                        final chunk = reversedTanques.sublist(
                          i,
                          (i + tanksPerRow > reversedTanques.length)
                              ? reversedTanques.length
                              : i + tanksPerRow,
                        );

                        rows.add(
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: chunk.map((tanque) {
                              final percentual = tanque.percentualPreenchimento;

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: spacing / 2,
                                ),
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        tanqueSelecionadoIndex =
                                            tanques.indexOf(tanque);
                                      });
                                    },
                                    child: Tooltip(
                                        message:
                                          'Estoque total: ${_formatarValor(tanque.estoqueAtual)}\nEstoque disponível: ${_formatarValor((tanque.estoqueAtual - tanque.lastro).clamp(0, tanque.capacidadeTotal))}\n───────────────\nCapacidade total: ${_formatarValor(tanque.capacidadeTotal)}\nEspaço disponível: ${_formatarValor((tanque.capacidadeTotal - tanque.estoqueAtual).clamp(0, tanque.capacidadeTotal))}',
                                      preferBelow: false,
                                      verticalOffset:
                                          (dynamicBaseHeight / 2) + 30,
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF222B45)
                                            .withOpacity(0.9),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      textStyle: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _formatarValor(tanque.estoqueAtual),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF00796B),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          SizedBox(
                                            width: dynamicBaseWidth,
                                            height: dynamicBaseHeight,
                                            child: TankIllustration(
                                              percentual: percentual / 100,
                                              lastroPercentual:
                                                  tanque.capacidadeTotal > 0
                                                      ? (tanque.lastro /
                                                          tanque.capacidadeTotal)
                                                      : 0,
                                              estoqueAtual: tanque.estoqueAtual,
                                              capacidade:
                                                  tanque.capacidadeTotal,
                                              produtoDisponivel:
                                                  (tanque.estoqueAtual -
                                                          tanque.lastro)
                                                      .clamp(
                                                          0,
                                                          tanque
                                                              .capacidadeTotal),
                                              espacoLivre: (tanque.capacidadeTotal -
                                                      tanque.estoqueAtual)
                                                  .clamp(
                                                      0,
                                                      tanque
                                                          .capacidadeTotal),
                                              hideDetails: dynamicScale < 0.35,
                                              scale: dynamicScale,
                                            ),
                                          ),
                                          const SizedBox(height: 0),
                                          Transform.translate(
                                            offset: Offset(0, -12 * dynamicScale),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  tanque.nome.split(' - ').first,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12.0,
                                                    color: Color(0xFF222B45),
                                                  ),
                                                ),
                                                if (tanque.nome.contains(' - ')) ...[
                                                  const SizedBox(height: 1),
                                                  Text(
                                                    tanque.nome.split(' - ').last,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 11.0,
                                                      color: Color(0xFF5A6275),
                                                    ),
                                                    textAlign: TextAlign.center,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        );

                        if (i + tanksPerRow < reversedTanques.length) {
                          rows.add(const SizedBox(height: 48));
                        }
                      }

                      return Column(
                        children: rows,
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _legendaItem(const Color(0xFFE0E3EB), "Espaço Livre"),
                      const SizedBox(width: 24),
                      _legendaItem(const Color(0xFF00B686), "Estoque"),
                      const SizedBox(width: 24),
                      _legendaItem(const Color(0xFFFF3D71), "Lastro"),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatarValor(double valor) {
    if (_usarMetrosCubicos) {
      final metros = valor / 1000.0;
      return '${_fmtUmaCasa.format(metros)} m³';
    }
    return '${formatNumber(valor)} L';
  }

  // Novo widget com tanque ilustrativo
  Widget _construirIndicadorNivelIlustrativo(
    DadosTanque tanque,
    double percentual,
  ) {
    final double capacidade = tanque.capacidadeTotal;
    final double estoque = tanque.estoqueAtual.clamp(0, capacidade);
    final double lastro = tanque.lastro.clamp(0, capacidade);
    final double produtoDisponivel = (estoque - lastro).clamp(0, capacidade);
    final double espacoLivre = (capacidade - estoque).clamp(0, capacidade);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFBFC8E6).withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: 6,
                  ), // Alinhamento com o topo do primeiro switch
                  child: RichText(
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      children: [
                        const TextSpan(text: 'Nível do Tanque'),
                        TextSpan(text: ' - ${tanque.nome}'),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 170, // Largura fixa para ambos os switches
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _mostrarPrevisto = !_mostrarPrevisto;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDF1F7),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE4E9F2)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: MouseRegion(
                                  onEnter: (_) => setState(
                                    () => _hoverSwitchOption = "atual",
                                  ),
                                  onExit: (_) =>
                                      setState(() => _hoverSwitchOption = null),
                                  child: GestureDetector(
                                    onTap: () => setState(
                                      () => _mostrarPrevisto = false,
                                    ),
                                    child: _buildSwitchOption(
                                      "Nível atual",
                                      !_mostrarPrevisto,
                                      _hoverSwitchOption == "atual",
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: MouseRegion(
                                  onEnter: (_) => setState(
                                    () => _hoverSwitchOption = "previsto",
                                  ),
                                  onExit: (_) =>
                                      setState(() => _hoverSwitchOption = null),
                                  child: GestureDetector(
                                    onTap: () =>
                                        setState(() => _mostrarPrevisto = true),
                                    child: _buildSwitchOption(
                                      "Previsto",
                                      _mostrarPrevisto,
                                      _hoverSwitchOption == "previsto",
                                      isPrevistoSide: true,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _usarMetrosCubicos = !_usarMetrosCubicos;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDF1F7),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE4E9F2)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: MouseRegion(
                                  onEnter: (_) =>
                                      setState(() => _hoverUnitOption = "m3"),
                                  onExit: (_) =>
                                      setState(() => _hoverUnitOption = null),
                                  child: GestureDetector(
                                    onTap: () => setState(
                                      () => _usarMetrosCubicos = true,
                                    ),
                                    child: _buildSwitchOption(
                                      "metros³",
                                      _usarMetrosCubicos,
                                      _hoverUnitOption == "m3",
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: MouseRegion(
                                  onEnter: (_) => setState(
                                    () => _hoverUnitOption = "litros",
                                  ),
                                  onExit: (_) =>
                                      setState(() => _hoverUnitOption = null),
                                  child: GestureDetector(
                                    onTap: () => setState(
                                      () => _usarMetrosCubicos = false,
                                    ),
                                    child: _buildSwitchOption(
                                      "Litros",
                                      !_usarMetrosCubicos,
                                      _hoverUnitOption == "litros",
                                      isPrevistoSide: true,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tanque ilustrativo com informações ao lado
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Legenda de cores à esquerda
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _legendaItem(const Color(0xFFE0E3EB), "Espaço Livre"),
                  const SizedBox(height: 12),
                  _legendaItem(const Color(0xFF00B686), "Estoque"),
                  const SizedBox(height: 12),
                  _legendaItem(const Color(0xFFFF3D71), "Lastro"),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 200, // Reduzido bruscamente (era 400)
                      maxHeight: 220, // Reduzido bruscamente (era 450)
                      minWidth: 100,
                      minHeight: 120,
                    ),
                    child: TankIllustration(
                      percentual: percentual / 100,
                      lastroPercentual: capacidade > 0
                          ? (lastro / capacidade).clamp(0, 1)
                          : 0,
                      estoqueAtual: estoque,
                      capacidade: capacidade,
                      produtoDisponivel: produtoDisponivel,
                      espacoLivre: espacoLivre,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _construirInfoMiniLateral(
                      'Estoque Atual',
                      _formatarValor(estoque),
                      const Color(0xFF00B686),
                    ),
                    const SizedBox(height: 16),
                    _construirInfoMiniLateral(
                      'Estoque Disponível',
                      _formatarValor(produtoDisponivel),
                      const Color(0xFF6A1B9A),
                    ),
                    const SizedBox(height: 16),
                    _construirInfoMiniLateral(
                      'Espaço Livre',
                      _formatarValor(espacoLivre),
                      const Color(0xFF424242),
                    ),
                    const SizedBox(height: 16),
                    _construirInfoMiniLateral(
                      'Capacidade',
                      _formatarValor(capacidade),
                      const Color.fromARGB(255, 69, 69, 69),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _legendaItem(Color cor, String texto) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: cor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          texto,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF8F9BB3),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _construirInfoMiniLateral(String label, String valor, Color cor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF8F9BB3),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          valor,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: cor,
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchOption(
    String text,
    bool isSelected,
    bool isHovered, {
    bool isPrevistoSide = false,
  }) {
    Color activeBlue = const Color(0xFF3366FF);

    Color activeColor = activeBlue;
    Color textColor = isSelected ? Colors.white : const Color(0xFF8F9BB3);

    Color hoverColor = activeBlue.withOpacity(0.1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? activeColor
            : (isHovered ? hoverColor : Colors.transparent),
        borderRadius: BorderRadius.circular(16),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: activeBlue.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : [],
      ),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

final NumberFormat _fmtInteiro = NumberFormat('#,##0', 'pt_BR');
final NumberFormat _fmtUmaCasa = NumberFormat('#,##0.0', 'pt_BR');

String formatNumber(num value) => _fmtInteiro.format(value);
String formatPercent(double value) => _fmtUmaCasa.format(value);

// Widget do Tanque Ilustrativo
class TankIllustration extends StatefulWidget {
  final double percentual;
  final double lastroPercentual;
  final double estoqueAtual;
  final double capacidade;
  final double produtoDisponivel;
  final double espacoLivre;
  final bool hideDetails;
  final double scale;

  const TankIllustration({
    super.key,
    required this.percentual,
    required this.lastroPercentual,
    required this.estoqueAtual,
    required this.capacidade,
    required this.produtoDisponivel,
    required this.espacoLivre,
    this.hideDetails = false,
    this.scale = 1.0,
  });

  @override
  State<TankIllustration> createState() => _TankIllustrationState();
}

class _TankIllustrationState extends State<TankIllustration>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _liquidAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _liquidAnimation = Tween<double>(begin: 0, end: widget.percentual).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();
  }

  @override
  void didUpdateWidget(TankIllustration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.percentual != widget.percentual) {
      _liquidAnimation =
          Tween<double>(
            begin: _liquidAnimation.value,
            end: widget.percentual,
          ).animate(
            CurvedAnimation(
              parent: _animationController,
              curve: Curves.easeOutCubic,
            ),
          );
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _liquidAnimation,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final double maxWidth = constraints.maxWidth;
            final double maxHeight = constraints.maxHeight;

            // Define um tamanho base padrão se não houver restrições
            final double sizeFactorWidth = maxWidth.isFinite ? maxWidth : 280.0;
            final double sizeFactorHeight =
                maxHeight.isFinite ? maxHeight : 320.0;

            // Mantém a proporção aproximada de 280/320 (0.875)
            double finalWidth = sizeFactorWidth;
            double finalHeight = sizeFactorHeight;

            if (finalWidth / finalHeight > 0.875) {
              finalWidth = finalHeight * 0.875;
            } else {
              finalHeight = finalWidth / 0.875;
            }

            // O scale agora é dinâmico baseado no tamanho final vs base
            final double dynamicScale = (finalWidth / 280.0).clamp(0.1, 5.0);

            return CustomPaint(
              painter: TankPainter(
                percentual: _liquidAnimation.value,
                lastroPercentual: widget.lastroPercentual,
                estoqueAtual: widget.estoqueAtual,
                capacidade: widget.capacidade,
                produtoDisponivel: widget.produtoDisponivel,
                espacoLivre: widget.espacoLivre,
                hideDetails: widget.hideDetails,
                scale: widget.scale * dynamicScale,
              ),
              size: Size(finalWidth, finalHeight),
            );
          },
        );
      },
    );
  }
}

class TankPainter extends CustomPainter {
  final double percentual;
  final double lastroPercentual;
  final double estoqueAtual;
  final double capacidade;
  final double produtoDisponivel;
  final double espacoLivre;
  final bool hideDetails;
  final double scale;

  TankPainter({
    required this.percentual,
    required this.lastroPercentual,
    required this.estoqueAtual,
    required this.capacidade,
    required this.produtoDisponivel,
    required this.espacoLivre,
    this.hideDetails = false,
    this.scale = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Proporções para um tanque cilíndrico vertical (atmosférico)
    final tankWidth = size.width * 0.55;
    final tankHeight = size.height * 0.8;
    final tankX = (size.width - tankWidth) / 2;
    final tankY = (size.height - tankHeight) / 2;

    // 1. Corpo cilíndrico (com base plana)
    final tankRect = Rect.fromLTWH(tankX, tankY, tankWidth, tankHeight);

    // Gradiente metálico horizontal para simular volume cilíndrico
    final bodyGradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        Colors.grey.shade400,
        Colors.grey.shade100,
        Colors.grey.shade300,
        Colors.grey.shade500,
      ],
      stops: const [0.0, 0.3, 0.6, 1.0],
    ).createShader(tankRect);

    final bodyPaint = Paint()..shader = bodyGradient;
    final borderPaint = Paint()
      ..color = Colors.grey.shade600
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * scale;

    // Desenha o retângulo do corpo (cilindro visto de frente)
    canvas.drawRect(tankRect, bodyPaint);

    // 2. Teto cônico (leve inclinação comum em tanques atmosféricos)
    final roofPath = Path()
      ..moveTo(tankX - 2 * scale, tankY)
      ..lineTo(tankX + tankWidth / 2, tankY - 15 * scale)
      ..lineTo(tankX + tankWidth + 2 * scale, tankY)
      ..close();

    final roofPaint = Paint()
      ..color = Colors.grey.shade400
      ..style = PaintingStyle.fill;

    canvas.drawPath(roofPath, roofPaint);
    canvas.drawPath(roofPath, borderPaint);

    // 3. Nível do líquido
    if (percentual > 0) {
      final liquidHeight = tankHeight * percentual;
      final liquidRect = Rect.fromLTWH(
        tankX,
        tankY + tankHeight - liquidHeight,
        tankWidth,
        liquidHeight,
      );

      final liquidColor = _getLiquidColor(percentual);
      final liquidPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            liquidColor.withOpacity(0.9),
            liquidColor.withOpacity(0.7),
            liquidColor,
          ],
        ).createShader(liquidRect);

      canvas.drawRect(liquidRect, liquidPaint);

      // Linha superior do líquido
      final surfacePaint = Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * scale;
      canvas.drawLine(
        Offset(tankX, tankY + tankHeight - liquidHeight),
        Offset(tankX + tankWidth, tankY + tankHeight - liquidHeight),
        surfacePaint,
      );
    }

    // Bordas laterais e base plana
    canvas.drawRect(tankRect, borderPaint);

    // 4. Detalhes Técnicos: Escada lateral
    final detailPaint = Paint()
      ..color = Colors.grey.shade700
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 * scale;

    final ladderX = tankX + tankWidth - 10 * scale;
    canvas.drawLine(
      Offset(ladderX, tankY),
      Offset(ladderX, tankY + tankHeight),
      detailPaint,
    );
    canvas.drawLine(
      Offset(ladderX + 8 * scale, tankY),
      Offset(ladderX + 8 * scale, tankY + tankHeight),
      detailPaint,
    );

    for (double i = 0; i <= tankHeight; i += 20 * scale) {
      canvas.drawLine(
        Offset(ladderX, tankY + i),
        Offset(ladderX + 8 * scale, tankY + i),
        detailPaint,
      );
    }

    // Boca de visita (base)
    canvas.drawRect(
      Rect.fromLTWH(
        tankX + 15 * scale,
        tankY + tankHeight - 25 * scale,
        15 * scale,
        12 * scale,
      ),
      Paint()..color = Colors.grey.shade600,
    );

    // 5. Linha do Lastro
    if (lastroPercentual > 0 && lastroPercentual < 1) {
      final lastroY = tankY + tankHeight - (tankHeight * lastroPercentual);
      final lastroPaint = Paint()
        ..color = const Color(0xFFFF3D71)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 * scale
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(tankX, lastroY),
        Offset(tankX + tankWidth, lastroY),
        lastroPaint,
      );
    }

    // 6. Indicadores e Textos
    if (!hideDetails) {
      _drawFloatingPercent(
        canvas,
        tankX,
        tankY,
        tankWidth,
        tankHeight,
        percentual,
      );
    }
  }

  Color _getLiquidColor(double percentual) {
    if (percentual >= 0.3) return const Color(0xFF00B686);
    if (percentual >= 0.15) return const Color(0xFFFFA000);
    return const Color(0xFFFF3D71);
  }

  void _drawFloatingPercent(
    Canvas canvas,
    double tankX,
    double tankY,
    double tankWidth,
    double tankHeight,
    double percentual,
  ) {
    final liquidY = tankY + tankHeight - (tankHeight * percentual);
    final percentText = '${(percentual * 100).toInt()}%';
    final textStyle = TextStyle(
      fontSize: 12.0, // Reduzido de 16.0 para 14.0 para diminuir levemente
      fontWeight: FontWeight.bold,
      color: _getLiquidColor(percentual),
    );

    final textSpan = TextSpan(text: percentText, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: ui.TextDirection.ltr,
    );
    textPainter.layout();

    textPainter.paint(
      canvas,
      Offset(
        tankX + tankWidth + 6, // Reduzido de 12 para 6 para aproximar levemente do tanque
        liquidY - (textPainter.height / 2),
      ),
    );

    final linePaint = Paint()
      ..color = _getLiquidColor(percentual).withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(tankX + tankWidth, liquidY),
      Offset(tankX + tankWidth + 10 * scale, liquidY),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant TankPainter oldDelegate) {
    return oldDelegate.percentual != percentual ||
        oldDelegate.lastroPercentual != lastroPercentual;
  }
}

class _SelecaoTipoVisualizacaoEstoqueBottomSheet extends StatefulWidget {
  final String tanqueId;
  final String referenciaTanque;
  final String terminalId;
  final String nomeTerminal;
  final VoidCallback onVoltar;

  const _SelecaoTipoVisualizacaoEstoqueBottomSheet({
    required this.tanqueId,
    required this.referenciaTanque,
    required this.terminalId,
    required this.nomeTerminal,
    required this.onVoltar,
  });

  @override
  State<_SelecaoTipoVisualizacaoEstoqueBottomSheet> createState() =>
      _SelecaoTipoVisualizacaoEstoqueBottomSheetState();
}

class _SelecaoTipoVisualizacaoEstoqueBottomSheetState
    extends State<_SelecaoTipoVisualizacaoEstoqueBottomSheet> {
  bool _tipoDataEspecifica = true;
  bool _tipoMensal = false;
  bool _mostrarDetalhado = true;

  DateTime _dataSelecionada = DateTime.now();
  int _mesSelecionado = DateTime.now().month;
  int _anoSelecionado = DateTime.now().year;

  final TextEditingController _dataController = TextEditingController();
  final TextEditingController _mesAnoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _atualizarDataController();
    _atualizarMesAnoController();
  }

  void _atualizarDataController() {
    _dataController.text = DateFormat('dd/MM/yyyy').format(_dataSelecionada);
  }

  void _atualizarMesAnoController() {
    _mesAnoController.text =
        '${_mesSelecionado.toString().padLeft(2, '0')}/${_anoSelecionado}';
  }

  Future<void> _selecionarData() async {
    DateTime tempDate = _dataSelecionada;
    final DateTime? picked = await showDialog<DateTime>(
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
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          color: Color(0xFF0D47A1),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Selecionar data',
                          style: TextStyle(
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
                            '${_getNomeMes(tempDate.month)} ${tempDate.year}',
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
                    GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: 7,
                      childAspectRatio: 1.0,
                      children: _getDaysInMonth(tempDate).map((day) {
                        final isSelected = day != null && day == tempDate.day;
                        final isToday =
                            day != null &&
                            day == DateTime.now().day &&
                            tempDate.month == DateTime.now().month &&
                            tempDate.year == DateTime.now().year;
                        return StatefulBuilder(
                          builder: (context, setDayState) {
                            return MouseRegion(
                              cursor: day != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
                              child: GestureDetector(
                                onTap: day != null
                                    ? () {
                                        setStateDialog(() {
                                          tempDate = DateTime(
                                            tempDate.year,
                                            tempDate.month,
                                            day,
                                          );
                                        });
                                      }
                                    : null,
                                child: Container(
                                  margin: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF0D47A1)
                                        : isToday
                                        ? const Color(0x220D47A1)
                                        : Colors.transparent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      day != null ? day.toString() : '',
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : isToday
                                            ? const Color(0xFF0D47A1)
                                            : Colors.black87,
                                        fontWeight: isSelected || isToday
                                            ? FontWeight.bold
                                            : FontWeight.normal,
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

    if (picked != null) {
      setState(() {
        _dataSelecionada = picked;
        _tipoDataEspecifica = true;
        _tipoMensal = false;
        _atualizarDataController();
      });
    }
  }

  String _getNomeMes(int mes) {
    const meses = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];
    return meses[mes - 1];
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

  Future<void> _selecionarMesAno() async {
    int tempMes = _mesSelecionado;
    int tempAno = _anoSelecionado;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: Text(
                          'Selecionar Mês/Ano',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: tempMes,
                                  isExpanded: true,
                                  icon: const Icon(
                                    Icons.arrow_drop_down,
                                    color: Color(0xFF0D47A1),
                                  ),
                                  items: List.generate(12, (index) {
                                    final mes = index + 1;
                                    return DropdownMenuItem(
                                      value: mes,
                                      child: Text(
                                        _getNomeMes(mes),
                                        style: const TextStyle(fontSize: 15),
                                      ),
                                    );
                                  }),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setStateDialog(() => tempMes = value);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              initialValue: tempAno.toString(),
                              decoration: InputDecoration(
                                labelText: 'Ano',
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                final ano = int.tryParse(value);
                                if (ano != null && ano >= 2000 && ano <= 2100) {
                                  setStateDialog(() => tempAno = ano);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      InkWell(
                        onTap: () {
                          setState(
                            () => _mostrarDetalhado = !_mostrarDetalhado,
                          );
                          setStateDialog(() {});
                        },
                        child: Row(
                          children: [
                            Checkbox(
                              value: _mostrarDetalhado,
                              onChanged: (val) {
                                setState(() => _mostrarDetalhado = val ?? true);
                                setStateDialog(() {});
                              },
                              activeColor: const Color(0xFF0D47A1),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            const Text(
                              'Mostrar detalhado',
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                side: const BorderSide(
                                  color: Color(0xFF0D47A1),
                                ),
                                foregroundColor: const Color(0xFF0D47A1),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Cancelar'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.pop(context);

                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (ctx) => EstoqueTanqueMensalPage(
                                      tanqueId: widget.tanqueId,
                                      referenciaTanque: widget.referenciaTanque,
                                      terminalId: widget.terminalId,
                                      nomeTerminal: widget.nomeTerminal,
                                      mes: tempMes,
                                      ano: tempAno,
                                      mostrarDetalhado: _mostrarDetalhado,
                                      onVoltar: () {
                                        Navigator.of(ctx).pop();
                                        widget.onVoltar();
                                      },
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                backgroundColor: const Color(0xFF0D47A1),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                              child: const Text('Confirmar'),
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

  void _visualizar() {
    if (!_tipoDataEspecifica && !_tipoMensal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione um tipo de visualização'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.pop(context);

    if (_tipoDataEspecifica) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => EstoqueTanquePage(
            tanqueId: widget.tanqueId,
            referenciaTanque: widget.referenciaTanque,
            data: _dataSelecionada,
            onVoltar: () {
              Navigator.of(ctx).pop();
              widget.onVoltar();
            },
          ),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => EstoqueTanqueMensalPage(
            tanqueId: widget.tanqueId,
            referenciaTanque: widget.referenciaTanque,
            terminalId: widget.terminalId,
            nomeTerminal: widget.nomeTerminal,
            mes: _mesSelecionado,
            ano: _anoSelecionado,
            mostrarDetalhado: _mostrarDetalhado,
            onVoltar: () {
              Navigator.of(ctx).pop();
              widget.onVoltar();
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      behavior: HitTestBehavior.opaque,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onTap: () {},
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: Text(
                      'Selecionar Período',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  InkWell(
                    onTap: _selecionarData,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _tipoDataEspecifica
                              ? const Color(0xFF0D47A1)
                              : Colors.grey.shade300,
                          width: _tipoDataEspecifica ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: _tipoDataEspecifica
                            ? const Color(0xFF0D47A1).withOpacity(0.05)
                            : Colors.white,
                      ),
                      child: Row(
                        children: [
                          Radio<bool>(
                            value: true,
                            groupValue: _tipoDataEspecifica,
                            onChanged: (value) {
                              setState(() {
                                _tipoDataEspecifica = true;
                                _tipoMensal = false;
                              });
                            },
                            activeColor: const Color(0xFF0D47A1),
                          ),
                          const Expanded(
                            child: Text(
                              'Data específica',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _dataController.text,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  InkWell(
                    onTap: _selecionarMesAno,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _tipoMensal
                              ? const Color(0xFF0D47A1)
                              : Colors.grey.shade300,
                          width: _tipoMensal ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: _tipoMensal
                            ? const Color(0xFF0D47A1).withOpacity(0.05)
                            : Colors.white,
                      ),
                      child: Row(
                        children: [
                          Radio<bool>(
                            value: true,
                            groupValue: _tipoMensal,
                            onChanged: (value) {
                              setState(() {
                                _tipoMensal = true;
                                _tipoDataEspecifica = false;
                              });
                            },
                            activeColor: const Color(0xFF0D47A1),
                          ),
                          const Expanded(
                            child: Text(
                              'Estoque mensal',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _mesAnoController.text,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_tipoMensal)
                    InkWell(
                      onTap: () => setState(
                        () => _mostrarDetalhado = !_mostrarDetalhado,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10, left: 4),
                        child: Row(
                          children: [
                            Checkbox(
                              value: _mostrarDetalhado,
                              onChanged: (val) => setState(
                                () => _mostrarDetalhado = val ?? true,
                              ),
                              activeColor: const Color(0xFF0D47A1),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            const Text(
                              'Mostrar detalhado',
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: Color(0xFF0D47A1)),
                            foregroundColor: const Color(0xFF0D47A1),
                          ),
                          child: const Text('Voltar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _visualizar,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: const Color(0xFF0D47A1),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Visualizar'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _dataController.dispose();
    _mesAnoController.dispose();
    super.dispose();
  }
}