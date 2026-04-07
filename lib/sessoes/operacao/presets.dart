import 'package:flutter/material.dart';

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

class _PresetsPageState extends State<PresetsPage> {
  late List<TerminalData> _terminais;
  late int _terminalSelecionado;
  String _abaSelecionada = 'terminal';
  
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
    
    final produtos = ['Gasolina A', 'Diesel S10', 'Etanol', 'Diesel S500', 'Gasolina Adit.'];
    
    _terminais = List.generate(14, (index) {
      return TerminalData(
        id: index + 1,
        bico: 'Bico ${index + 1}',
        produto: produtos[index % produtos.length],
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
    return valor.toStringAsFixed(3);
  }

  void _atualizarTerminal() {
    setState(() {
      final terminal = _terminais[_terminalSelecionado];
      terminal.saldoInicial = double.tryParse(_saldoInicialController.text) ?? 0;
      terminal.saldoFinal = double.tryParse(_saldoFinalController.text) ?? 0;
      terminal.saidaTotal = double.tryParse(_saidaTotalController.text) ?? 0;
      terminal.totalORP = double.tryParse(_totalORPController.text) ?? 0;
      terminal.complCarga = double.tryParse(_complCargaController.text) ?? 0;
      terminal.complDescarga = double.tryParse(_complDescargaController.text) ?? 0;
      terminal.consumo = double.tryParse(_consumoController.text) ?? 0;
      terminal.afericao = double.tryParse(_afericaoController.text) ?? 0;
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
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Navegação de abas
                  Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 1000),
                      child: _buildNavegacaoAbas(),
                    ),
                  ),
                  const Divider(height: 1, color: Color.fromARGB(255, 236, 236, 236)),
                  
                  // Conteúdo principal à esquerda
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: _abaSelecionada == 'resumo'
                        ? _buildResumoPage()
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildCardMedicoes(),
                              const SizedBox(height: 24),
                              _buildCardComplementar(),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildNavegacaoAbas() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          // Botão Resumo
          _buildAbaItem(
            label: 'RESUMO',
            sublabel: 'Geral',
            isSelected: _abaSelecionada == 'resumo',
            onTap: () {
              setState(() => _abaSelecionada = 'resumo');
            },
          ),
          // Botões dos Terminais
          ..._terminais.map((t) {
            final isSelected = _abaSelecionada == 'terminal' && _terminalSelecionado == t.id - 1;
            return _buildAbaItem(
              label: t.bico,
              sublabel: t.produto,
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
    );
  }

  Widget _buildAbaItem({
    required String label,
    required String sublabel,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 100, // Largura fixa de 100px
        padding: const EdgeInsets.symmetric(vertical: 8),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              sublabel,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white.withOpacity(0.9) : Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
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
  
  Widget _buildCardMedicoes() {
    return SizedBox(
      width: 420, // Reduzido em 30px (era 450)
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
                color: Color(0xFF1565C0),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.speed, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  const Text(
                    'Medições do Terminal',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _terminais[_terminalSelecionado].bico,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
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
                  _buildCampoLimited(
                    titulo: 'SALDO INICIAL',
                    controller: _saldoInicialController,
                    icone: Icons.play_arrow,
                    cor: Colors.green,
                    onChanged: (_) => _atualizarTerminal(),
                  ),
                  const SizedBox(height: 16),
                  _buildCampoLimited(
                    titulo: 'SALDO FINAL',
                    controller: _saldoFinalController,
                    icone: Icons.stop,
                    cor: Colors.blue,
                    onChanged: (_) => _atualizarTerminal(),
                  ),
                  const SizedBox(height: 16),
                  _buildCampoLimited(
                    titulo: 'SAÍDA TOTAL',
                    controller: _saidaTotalController,
                    icone: Icons.local_gas_station,
                    cor: Colors.orange,
                    onChanged: (_) => _atualizarTerminal(),
                  ),
                  const SizedBox(height: 16),
                  _buildCampoLimited(
                    titulo: 'TOTAL EM ORP',
                    controller: _totalORPController,
                    icone: Icons.trending_up,
                    cor: Colors.purple,
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

  Widget _buildCampoLimited({
    required String titulo,
    required TextEditingController controller,
    required IconData icone,
    required Color cor,
    required Function(String) onChanged,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
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
          child: TextField(
            controller: controller,
            onChanged: onChanged,
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildCardComplementar() {
    return SizedBox(
      width: 420, // Reduzido em 30px (era 450)
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
                color: Color(0xFF1565C0),
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
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.white,
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
                  _buildCampoComplementarLimitado(
                    titulo: 'COMPL. DE CARGA',
                    controller: _complCargaController,
                    icone: Icons.arrow_upward,
                    cor: Colors.teal,
                    onChanged: (_) => _atualizarTerminal(),
                  ),
                  const SizedBox(height: 16),
                  _buildCampoComplementarLimitado(
                    titulo: 'COMPL. DE DESCARGA',
                    controller: _complDescargaController,
                    icone: Icons.arrow_downward,
                    cor: Colors.indigo,
                    onChanged: (_) => _atualizarTerminal(),
                  ),
                  const SizedBox(height: 16),
                  _buildCampoComplementarLimitado(
                    titulo: 'CONSUMO',
                    controller: _consumoController,
                    icone: Icons.speed,
                    cor: Colors.red,
                    onChanged: (_) => _atualizarTerminal(),
                  ),
                  const SizedBox(height: 16),
                  _buildCampoComplementarLimitado(
                    titulo: 'AFERIÇÃO',
                    controller: _afericaoController,
                    icone: Icons.check_circle,
                    cor: Colors.green,
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

  Widget _buildCampoComplementarLimitado({
    required String titulo,
    required TextEditingController controller,
    required IconData icone,
    required Color cor,
    required Function(String) onChanged,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
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
          child: TextField(
            controller: controller,
            onChanged: (value) {
              if (value.length > 10) {
                controller.text = value.substring(0, 10);
                controller.selection = TextSelection.fromPosition(
                  TextPosition(offset: controller.text.length),
                );
              }
              onChanged(value);
            },
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}