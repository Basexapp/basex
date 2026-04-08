import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class PresetsPage extends StatefulWidget {
  final VoidCallback onVoltar;

  const PresetsPage({super.key, required this.onVoltar});

  @override
  State<PresetsPage> createState() => _PresetsPageState();
}

class TerminalData {
  final int id;
  final String bico;
  final String produto;
  double saldoInicial;
  double saldoFinal;
  double saidaTotal;
  double totalORP;
  double complCarga;
  double complDescarga;
  double consumo;
  double afericao;

  TerminalData({
    required this.id,
    required this.bico,
    required this.produto,
    this.saldoInicial = 0,
    this.saldoFinal = 0,
    this.saidaTotal = 0,
    this.totalORP = 0,
    this.complCarga = 0,
    this.complDescarga = 0,
    this.consumo = 0,
    this.afericao = 0,
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
  late List<TerminalData> _terminais;
  late int _terminalSelecionado;
  String _abaSelecionada = 'terminal';
  DateTime _dataSelecionada = DateTime.now();

  late TextEditingController _saldoInicialController;
  late TextEditingController _saldoFinalController;
  late TextEditingController _saidaTotalController;
  late TextEditingController _totalORPController;
  late TextEditingController _complCargaController;
  late TextEditingController _complDescargaController;
  late TextEditingController _consumoController;
  late TextEditingController _afericaoController;

  @override
  void initState() {
    super.initState();

    final produtos = ['Gasolina C', 'S500', 'S10', 'HIDRATADO'];

    _terminais = List.generate(produtos.length, (index) {
      return TerminalData(
        id: index + 1,
        bico: 'Bico ${index + 1}',
        produto: produtos[index],
        saldoInicial: 1250.500 + (index * 100),
        saldoFinal: 1875.300 + (index * 100),
        saidaTotal: 624.800,
        totalORP: 312.400 + (index * 50),
        complCarga: 98.5,
        complDescarga: 95.2,
        consumo: 624.8,
        afericao: 99.8,
      );
    });

    _terminalSelecionado = 0;

    _saldoInicialController = TextEditingController();
    _saldoFinalController = TextEditingController();
    _saidaTotalController = TextEditingController();
    _totalORPController = TextEditingController();
    _complCargaController = TextEditingController();
    _complDescargaController = TextEditingController();
    _consumoController = TextEditingController();
    _afericaoController = TextEditingController();

    _carregarDadosTerminal();
  }

  void _carregarDadosTerminal() {
    final terminal = _terminais[_terminalSelecionado];
    _saldoInicialController.text = _formatarNumero(terminal.saldoInicial);
    _saldoFinalController.text = _formatarNumero(terminal.saldoFinal);
    _saidaTotalController.text = _formatarNumero(terminal.saidaTotal);
    _totalORPController.text = _formatarNumero(terminal.totalORP);
    _complCargaController.text = _formatarNumero(terminal.complCarga);
    _complDescargaController.text = _formatarNumero(terminal.complDescarga);
    _consumoController.text = _formatarNumero(terminal.consumo);
    _afericaoController.text = _formatarNumero(terminal.afericao);
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
      final terminal = _terminais[_terminalSelecionado];
      terminal.saldoInicial = _parseTexto(_saldoInicialController.text);
      terminal.saldoFinal = _parseTexto(_saldoFinalController.text);
      terminal.saidaTotal = _parseTexto(_saidaTotalController.text);
      terminal.totalORP = _parseTexto(_totalORPController.text);
      terminal.complCarga = _parseTexto(_complCargaController.text);
      terminal.complDescarga = _parseTexto(_complDescargaController.text);
      terminal.consumo = _parseTexto(_consumoController.text);
      terminal.afericao = _parseTexto(_afericaoController.text);
    });
  }

  @override
  void dispose() {
    _saldoInicialController.dispose();
    _saldoFinalController.dispose();
    _saidaTotalController.dispose();
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
          _buildNavegacaoAbas(),
          const Divider(height: 1, color: Color.fromARGB(255, 236, 236, 236)),

          Expanded(
            child: SingleChildScrollView(
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
                      else ...[
                        _buildCardMedicoes(1),
                        const SizedBox(height: 24),
                        _buildCardMedicoes(2),
                      ]
                    ],
                  ),

                  const SizedBox(width: 32),

                  // Coluna de Informações (Agora dentro do scroll junto com as medições)
                  if (_abaSelecionada != 'resumo')
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
                // Botões dos Terminais
                ..._terminais.map((t) {
                  final isSelected = _abaSelecionada == 'terminal' && _terminalSelecionado == t.id - 1;
                  return _buildAbaItem(
                    label: t.produto,
                    isSelected: isSelected,
                    onTap: () {
                      setState(() {
                        _abaSelecionada = 'terminal';
                        _terminalSelecionado = t.id - 1;
                        _carregarDadosTerminal();
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

  Widget _buildCardMedicoes(int numeroTerminal) {
    return SizedBox(
      width: 420,
      height: 225, // Altura fixa para os cards da esquerda
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
                  const Icon(Icons.speed, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'Registro - Terminal $numeroTerminal',
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
                    controller: _saldoInicialController,
                    icone: Icons.play_arrow,
                    cor: Colors.green,
                    onChanged: (_) => _atualizarTerminal(),
                  ),
                  const SizedBox(height: 10),
                  _buildCampoInput(
                    titulo: 'SALDO FINAL',
                    controller: _saldoFinalController,
                    icone: Icons.stop,
                    cor: Colors.blue,
                    onChanged: (_) => _atualizarTerminal(),
                  ),
                  const SizedBox(height: 10),
                  _buildCampoInput(
                    titulo: 'SAÍDA REGISTRADA',
                    controller: _saidaTotalController,
                    icone: Icons.local_gas_station,
                    cor: Colors.orange,
                    onChanged: (_) => _atualizarTerminal(),
                  ),
                ],
              ),
            ),
          ],
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
  }) {
    return SizedBox(
      height: 35, // Altura fixa da linha
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
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
          SizedBox(
            width: 160,
            height: 35, // Altura fixa do input
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                ThousandSeparatorInputFormatter(),
              ],
              textAlign: TextAlign.center,
              textAlignVertical: TextAlignVertical.center,
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
          ),
        ],
      ),
    );
  }

  Widget _buildCardComplementar() {
    return SizedBox(
      width: 420,
      height: (225 * 2) + 24, // Altura somada de dois cards + espaçamento + 20px extra
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
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
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