import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_page.dart';

class PresetsPage extends StatefulWidget {
  final VoidCallback onVoltar;

  const PresetsPage({super.key, required this.onVoltar});

  @override
  State<PresetsPage> createState() => _PresetsPageState();
}

class TerminalData {
  final String id;
  final String presetRef;
  final String produtoNome;
  final String produtoId;
  double saldoInicial;
  double saldoFinal;
  double saidaTotal;

  TerminalData({
    required this.id,
    required this.presetRef,
    required this.produtoNome,
    required this.produtoId,
    this.saldoInicial = 0,
    this.saldoFinal = 0,
    this.saidaTotal = 0,
  });
}

class ProdutoAgrupado {
  final String nome;
  final List<TerminalData> presets;

  ProdutoAgrupado({
    required this.nome,
    required this.presets,
  });
}

class ThousandSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.selection.baseOffset == 0) return newValue;

    String cleanText = newValue.text.replaceAll('.', '');
    if (cleanText.isEmpty) return newValue;

    double? value = double.tryParse(cleanText);
    if (value == null) return oldValue;

    final formatter = NumberFormat('#,###', 'pt_BR');
    String newText = formatter.format(value).replaceAll(',', '.');

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

class _PresetsPageState extends State<PresetsPage> {
  List<ProdutoAgrupado> _produtosAgrupados = [];
  int _produtoSelecionadoIndex = 0;
  String _abaSelecionada = 'terminal';
  DateTime _dataSelecionada = DateTime.now();
  bool _carregando = true;

  // Controllers para até 3 presets por produto
  final List<TextEditingController> _saldoInicialControllers = List.generate(3, (_) => TextEditingController(text: '0'));
  final List<TextEditingController> _saldoFinalControllers = List.generate(3, (_) => TextEditingController(text: '0'));
  final List<TextEditingController> _saidaTotalControllers = List.generate(3, (_) => TextEditingController(text: '0'));

  late TextEditingController _totalORPController;
  late TextEditingController _complCargaController;
  late TextEditingController _complDescargaController;
  late TextEditingController _consumoController;
  late TextEditingController _afericaoController;

  @override
  void initState() {
    super.initState();

    _totalORPController = TextEditingController();
    _complCargaController = TextEditingController();
    _complDescargaController = TextEditingController();
    _consumoController = TextEditingController();
    _afericaoController = TextEditingController();

    _buscarPresets();
  }

  Future<void> _buscarPresets() async {
    final terminalId = UsuarioAtual.instance?.terminalId;
    if (terminalId == null) {
      if (mounted) setState(() => _carregando = false);
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('presets')
          .select('id, preset_ref, produto_id, produtos(nome_dois)')
          .eq('terminal_id', terminalId);

      final List<dynamic> data = response as List<dynamic>;
      
      final Map<String, List<TerminalData>> mapaAgrupado = {};

      for (var item in data) {
        final prodNome = item['produtos']['nome_dois']?.toString() ?? 'Sem Nome';
        final terminal = TerminalData(
          id: item['id'].toString(),
          presetRef: item['preset_ref']?.toString() ?? '',
          produtoNome: prodNome,
          produtoId: item['produto_id'].toString(),
        );

        if (!mapaAgrupado.containsKey(prodNome)) {
          mapaAgrupado[prodNome] = [];
        }
        mapaAgrupado[prodNome]!.add(terminal);
      }

      final novosProdutos = mapaAgrupado.entries.map((e) => ProdutoAgrupado(nome: e.key, presets: e.value)).toList();

      if (mounted) {
        setState(() {
          _produtosAgrupados = novosProdutos;
          _carregando = false;
          if (_produtosAgrupados.isNotEmpty) {
            _carregarDadosProduto(0);
          }
        });
      }
    } catch (e) {
      debugPrint('Erro ao buscar presets: $e');
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _carregarDadosProduto(int index) {
    final produto = _produtosAgrupados[index];
    for (int i = 0; i < 3; i++) {
      if (i < produto.presets.length) {
        final preset = produto.presets[i];
        _saldoInicialControllers[i].text = _formatarNumero(preset.saldoInicial);
        _saldoFinalControllers[i].text = _formatarNumero(preset.saldoFinal);
        _saidaTotalControllers[i].text = _formatarNumero(preset.saidaTotal);
      } else {
        _saldoInicialControllers[i].text = '0';
        _saldoFinalControllers[i].text = '0';
        _saidaTotalControllers[i].text = '0';
      }
    }
    // Hardcoded ou vindo de outro lugar futuramente
    _totalORPController.text = '0';
    _complCargaController.text = '0';
    _complDescargaController.text = '0';
    _consumoController.text = '0';
    _afericaoController.text = '0';
  }

  String _formatarNumero(double valor) {
    return NumberFormat('#,###', 'pt_BR').format(valor).replaceAll(',', '.');
  }

  double _parseTexto(String texto) {
    final semMilhar = texto.replaceAll('.', '');
    return double.tryParse(semMilhar) ?? 0;
  }

  void _atualizarTerminal() {
    setState(() {
      if (_produtosAgrupados.isNotEmpty) {
        final atual = _produtosAgrupados[_produtoSelecionadoIndex];
        for (int i = 0; i < atual.presets.length && i < 3; i++) {
          atual.presets[i].saldoInicial = _parseTexto(_saldoInicialControllers[i].text);
          atual.presets[i].saldoFinal = _parseTexto(_saldoFinalControllers[i].text);
          atual.presets[i].saidaTotal = _parseTexto(_saidaTotalControllers[i].text);
        }
      }
    });
  }

  String _formatarSomaSaidas() {
    double soma = 0;
    for (int i = 0; i < 3; i++) {
      soma += _parseTexto(_saidaTotalControllers[i].text);
    }
    return _formatarNumero(soma);
  }

  @override
  void dispose() {
    for (var c in _saldoInicialControllers) {
      c.dispose();
    }
    for (var c in _saldoFinalControllers) {
      c.dispose();
    }
    for (var c in _saidaTotalControllers) {
      c.dispose();
    }
    _totalORPController.dispose();
    _complCargaController.dispose();
    _complDescargaController.dispose();
    _consumoController.dispose();
    _afericaoController.dispose();
    super.dispose();
  }

  Widget _buildAppBar() {
    return Container(
      height: kToolbarHeight + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
        left: 16,
        right: 16,
      ),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: widget.onVoltar,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Presets - Terminais de Saída',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
          // Botão de configurações removido conforme solicitação
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildAppBar(),
          Container(height: 1, color: Colors.grey.shade200),
          // Abas (sempre fixas no topo) sem limitação de largura
          if (_carregando)
            const LinearProgressIndicator(minHeight: 2, color: Color(0xFF1565C0))
          else
            _buildNavegacaoAbas(),
          const Divider(height: 1, color: Color.fromARGB(255, 236, 236, 236)),
          
          Expanded(
            child: _carregando 
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      // Coluna de Medições
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_abaSelecionada == 'resumo')
                            _buildResumoPage()
                          else if (_produtosAgrupados.isNotEmpty) ...[
                            ...List.generate(_produtosAgrupados[_produtoSelecionadoIndex].presets.length, (index) {
                              return Column(
                                children: [
                                  _buildCardMedicoes(index),
                                  if (index < _produtosAgrupados[_produtoSelecionadoIndex].presets.length - 1)
                                    const SizedBox(height: 24),
                                ],
                              );
                            }),
                          ]
                        ],
                      ),

                      const SizedBox(width: 32),

                      // Coluna de Informações (Agora dentro do scroll junto com as medições)
                      if (_abaSelecionada != 'resumo' && _produtosAgrupados.isNotEmpty)
                        _buildCardComplementar(),
                    ],
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavegacaoAbas() {
    final textoData = '${_dataSelecionada.day.toString().padLeft(2, '0')}/${_dataSelecionada.month.toString().padLeft(2, '0')}/${_dataSelecionada.year}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Abas alinhadas à ESQUERDA
          Expanded(
            child: Wrap(
              alignment: WrapAlignment.start,
              spacing: 12,
              runSpacing: 12,
              children: [
                // Botão Resumo
                _buildAbaItem(
                  label: 'RESUMO',
                  isSelected: _abaSelecionada == 'resumo',
                  onTap: () {
                    setState(() => _abaSelecionada = 'resumo');
                  },
                ),
                // Botões dos Produtos Agrupados
                ...List.generate(_produtosAgrupados.length, (index) {
                  final prod = _produtosAgrupados[index];
                  final isSelected = _abaSelecionada == 'terminal' && _produtoSelecionadoIndex == index;
                  return _buildAbaItem(
                    label: prod.nome,
                    isSelected: isSelected,
                    onTap: () {
                      setState(() {
                        _abaSelecionada = 'terminal';
                        _produtoSelecionadoIndex = index;
                        _carregarDadosProduto(index);
                      });
                    },
                  );
                }),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Botão de DATA alinhado à DIREITA
          InkWell(
            onTap: () => _abrirCalendario(context),
            borderRadius: BorderRadius.circular(8),
            hoverColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: Color(0xFF1565C0)),
                  const SizedBox(width: 12),
                  Text(
                    textoData,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  void _abrirCalendario(BuildContext context) async {
    DateTime tempDate = _dataSelecionada;
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
                        const Text(
                          'Selecionar Data',
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
                            icon: const Icon(Icons.chevron_left, color: Color(0xFF0D47A1)),
                            onPressed: () {
                              setStateDialog(() {
                                tempDate = DateTime(tempDate.year, tempDate.month - 1, tempDate.day);
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
                            icon: const Icon(Icons.chevron_right, color: Color(0xFF0D47A1)),
                            onPressed: () {
                              setStateDialog(() {
                                tempDate = DateTime(tempDate.year, tempDate.month + 1, tempDate.day);
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
                        final isToday = day != null &&
                            day == DateTime.now().day &&
                            tempDate.month == DateTime.now().month &&
                            tempDate.year == DateTime.now().year;
                        return StatefulBuilder(
                          builder: (context, setDayState) {
                            return MouseRegion(
                              cursor: day != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
                              onEnter: (_) {
                                if (day != null) {
                                  setDayState(() => hoveredDay = day);
                                }
                              },
                              onExit: (_) {
                                if (day != null) {
                                  setDayState(() => hoveredDay = null);
                                }
                              },
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
                                    color: isSelected
                                        ? const Color(0xFF0D47A1)
                                        : (day != null && hoveredDay == day)
                                            ? const Color(0xFF0D47A1).withOpacity(0.1)
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
                                            : isToday || (day != null && hoveredDay == day)
                                                ? const Color(0xFF0D47A1)
                                                : Colors.black87,
                                        fontWeight: isSelected || isToday || (day != null && hoveredDay == day)
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
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text(
                            'SELECIONAR',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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

    if (data != null) {
      setState(() {
        _dataSelecionada = data;
      });
    }
  }

  String _getMonthName(int month) {
    const months = [
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
      'Dezembro'
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

  Widget _buildAbaItem({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 100, // Largura fixa de 100px
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1565C0) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF1565C0) : Colors.grey.shade300,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildResumoPage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assessment, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Resumo em desenvolvimento',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardMedicoes(int index) {
    if (_produtosAgrupados.isEmpty) return const SizedBox();
    final preset = _produtosAgrupados[_produtoSelecionadoIndex].presets[index];

    return SizedBox(
      width: 420,
      height: 245,
      child: Card(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF1A237E), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: Color.fromARGB(255, 255, 221, 0),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.speed, color: Colors.black, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'Registro - ${preset.presetRef} - ${preset.produtoNome}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color.fromARGB(255, 0, 0, 0),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildCampoInput(
                    titulo: 'SALDO INICIAL',
                    controller: _saldoInicialControllers[index],
                    icone: Icons.play_arrow,
                    cor: Colors.green,
                    onChanged: (val) => _atualizarTerminal(),
                  ),
                  const SizedBox(height: 10),
                  _buildCampoInput(
                    titulo: 'SALDO FINAL',
                    controller: _saldoFinalControllers[index],
                    icone: Icons.stop,
                    cor: Colors.blue,
                    onChanged: (val) => _atualizarTerminal(),
                    onAddPressed: () => _abrirDialogSaldoFinalIndependente(index),
                    hasValue: _saldoFinalControllers[index].text.isNotEmpty && _saldoFinalControllers[index].text != '0',
                  ),
                  const SizedBox(height: 10),
                  _buildCampoInput(
                    titulo: 'SAÍDA REGISTRADA',
                    controller: _saidaTotalControllers[index],
                    icone: Icons.local_gas_station,
                    cor: Colors.orange,
                    onChanged: (val) => _atualizarTerminal(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirDialogSaldoFinalIndependente(int index) {
    if (_produtosAgrupados.isEmpty) return;
    final preset = _produtosAgrupados[_produtoSelecionadoIndex].presets[index];
    final String tituloPreset = preset.presetRef;
    final TextEditingController dialogController = TextEditingController(
      text: _saldoFinalControllers[index].text,
    );

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF1A237E), width: 1),
        ),
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Saldo Final - $tituloPreset',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A237E),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: dialogController,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  ThousandSeparatorInputFormatter(),
                ],
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                ),
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('CANCELAR'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      _saldoFinalControllers[index].text = dialogController.text;
                      _atualizarTerminal();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A237E),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('SALVAR'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Componente de input padronizado com altura fixa de 35px para a linha e para o input
  Widget _buildCampoInput({
    required String titulo,
    required TextEditingController controller,
    required IconData icone,
    required Color cor,
    required Function(String) onChanged,
    VoidCallback? onAddPressed,
    bool hasValue = false,
  }) {
    return Container(
      height: 35, // Altura única para a linha inteira
      margin: const EdgeInsets.symmetric(vertical: 2), // Reduzido de 4 para 2
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center, // Centraliza todos horizontalmente NA MESMA LINHA
        children: [
          // Ícone
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icone, color: cor, size: 16),
          ),
          const SizedBox(width: 12),
          
          // Título
          Expanded(
            flex: 2,
            child: Text(
              titulo,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700,
              ),
            ),
          ),

          // Botão de Adição/Edição
          if (onAddPressed != null) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 24,
              height: 24,
              child: ElevatedButton(
                onPressed: onAddPressed,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: Icon(
                  hasValue ? Icons.edit : Icons.add,
                  size: 12,
                ),
              ),
            ),
          ],
          
          const SizedBox(width: 12),

          // Input
          SizedBox(
            width: 160,
            height: 32, // Um pouco menor que o Container pai para garantir centralização
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                ThousandSeparatorInputFormatter(),
              ],
              textAlign: TextAlign.center,
              textAlignVertical: TextAlignVertical.center, // Garante que o texto dentro do input esteja centralizado
              decoration: InputDecoration(
                isCollapsed: true, // Remove paddings internos padrões que causam desalinhamento
                contentPadding: const EdgeInsets.symmetric(vertical: 10), // Centraliza o texto verticalmente no campo
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.5),
                ),
              ),
              keyboardType: TextInputType.number,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardComplementar() {
    return SizedBox(
      width: 420,
      height: 520, // Altura ajustada
      child: Card(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF1A237E), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: Color.fromARGB(255, 180, 123, 0),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Text(
                    'Informações Complementares',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildCampoTextoFixo(
                      titulo: 'TOTAL SAÍDA PRESETS',
                      valor: _formatarSomaSaidas(),
                      icone: Icons.assessment,
                      cor: Colors.blueAccent,
                    ),
                    _buildCampoInput(
                      titulo: 'TOTAL EM ORP',
                      controller: _totalORPController,
                      icone: Icons.trending_up,
                      cor: Colors.purple,
                      onChanged: (_) => _atualizarTerminal(),
                    ),
                    _buildCampoDiferenca(),
                    const Center(
                      child: SizedBox(
                        width: 380,
                        child: Divider(
                          color: Color.fromARGB(255, 230, 230, 230),
                          thickness: 1,
                        ),
                      ),
                    ),
                    _buildCampoInput(
                      titulo: 'COMPL. DE CARGA',
                      controller: _complCargaController,
                      icone: Icons.arrow_upward,
                      cor: Colors.teal,
                      onChanged: (_) => _atualizarTerminal(),
                    ),
                    _buildCampoInput(
                      titulo: 'COMPL. DE DESCARGA',
                      controller: _complDescargaController,
                      icone: Icons.arrow_downward,
                      cor: Colors.indigo,
                      onChanged: (_) => _atualizarTerminal(),
                    ),
                    _buildCampoInput(
                      titulo: 'CONSUMO',
                      controller: _consumoController,
                      icone: Icons.speed,
                      cor: Colors.red,
                      onChanged: (_) => _atualizarTerminal(),
                    ),
                    _buildCampoInput(
                      titulo: 'AFERIÇÃO',
                      controller: _afericaoController,
                      icone: Icons.check_circle,
                      cor: Colors.green,
                      onChanged: (_) => _atualizarTerminal(),
                    ),
                    _buildCampoDiferencaReal(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Componente para exibir valor fixo (não editável) com o mesmo layout do input
  Widget _buildCampoTextoFixo({
    required String titulo,
    required String valor,
    required IconData icone,
    required Color cor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: SizedBox(
        height: 35,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: cor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icone, color: cor, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Text(
                titulo,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 160,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Center(
                child: Text(
                  valor,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Campo de diferença real com altura fixa de 35px
  Widget _buildCampoDiferencaReal() {
    return SizedBox(
      height: 35,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.blueGrey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.calculate_outlined, color: Colors.blueGrey, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              'DIFERENÇA REAL',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 160,
            height: 35,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    '82',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                      color: Colors.black87,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('|', style: TextStyle(color: Colors.grey)),
                  ),
                  Text(
                    '0,04%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  // Campo de diferença com altura fixa de 35px
  Widget _buildCampoDiferenca() {
    return SizedBox(
      height: 35,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.compare_arrows, color: Colors.orange, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              'DIFERENÇA',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 160,
            height: 35,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    '82',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}