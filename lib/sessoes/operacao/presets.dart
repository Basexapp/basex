import 'package:flutter/material.dart';

class PresetsPage extends StatefulWidget {
  final VoidCallback onVoltar;

  const PresetsPage({super.key, required this.onVoltar});

  @override
  State<PresetsPage> createState() => _PresetsPageState();
}

class _PresetsPageState extends State<PresetsPage> {
  // Controladores dos campos
  final TextEditingController _saldoInicialController = TextEditingController();
  final TextEditingController _saldoFinalController = TextEditingController();

  // Variáveis para armazenar os registros do dia
  double? _saldoInicial;
  double? _saldoFinal;
  double? _totalAbastecido;
  final List<Map<String, dynamic>> _registros = [];

  // Valores fictícios para demonstração dos presets do dia
  final List<Map<String, dynamic>> _presetsDemonstracao = [
    {'veiculo': 'Caminhão SC-101', 'litros': 450.5, 'hora': '08:32'},
    {'veiculo': 'Ônibus 07 - Linha 200', 'litros': 320.0, 'hora': '09:15'},
    {'veiculo': 'Caminhão SC-102', 'litros': 580.3, 'hora': '10:45'},
    {'veiculo': 'Trator AG-05', 'litros': 210.8, 'hora': '11:20'},
    {'veiculo': 'Caminhão SC-103', 'litros': 495.2, 'hora': '13:30'},
    {'veiculo': 'Ônibus 12 - Linha 305', 'litros': 298.7, 'hora': '14:50'},
    {'veiculo': 'Caminhão SC-104', 'litros': 623.1, 'hora': '16:10'},
  ];

  @override
  void initState() {
    super.initState();
    // Adiciona alguns registros de exemplo
    _registros.addAll([
      {'tipo': 'Inicial', 'valor': 146258.0, 'data': '05/04/2026 06:00'},
      {'tipo': 'Final', 'valor': 148195.6, 'data': '05/04/2026 18:30'},
    ]);
  }

  void _salvarSaldoInicial() {
    if (_saldoInicialController.text.isNotEmpty) {
      setState(() {
        _saldoInicial = double.tryParse(_saldoInicialController.text);
        _registros.insert(0, {
          'tipo': 'Inicial',
          'valor': _saldoInicial,
          'data': _formatarDataHora(),
        });
        _saldoInicialController.clear();
        _calcularTotalAbastecido();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saldo inicial registrado com sucesso!')),
      );
    }
  }

  void _salvarSaldoFinal() {
    if (_saldoFinalController.text.isNotEmpty) {
      setState(() {
        _saldoFinal = double.tryParse(_saldoFinalController.text);
        _registros.insert(0, {
          'tipo': 'Final',
          'valor': _saldoFinal,
          'data': _formatarDataHora(),
        });
        _saldoFinalController.clear();
        _calcularTotalAbastecido();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saldo final registrado com sucesso!')),
      );
    }
  }

  void _calcularTotalAbastecido() {
    if (_saldoInicial != null && _saldoFinal != null) {
      _totalAbastecido = _saldoFinal! - _saldoInicial!;
    } else {
      _totalAbastecido = null;
    }
  }

  String _formatarDataHora() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(30, 20, 30, 30),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
                onPressed: widget.onVoltar,
                tooltip: 'Voltar',
              ),
              const SizedBox(width: 10),
              const Icon(Icons.speed, color: Color(0xFF0D47A1), size: 28),
              const SizedBox(width: 10),
              const Text(
                'Registro de Presets',
                style: TextStyle(
                  fontSize: 24,
                  color: Color(0xFF0D47A1),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: Colors.grey),
          const SizedBox(height: 20),

          // Layout principal com scroll
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Seção: Mostradores de Saldo
                  _buildMostradoresSection(),
                  const SizedBox(height: 30),

                  // Seção: Formulário de Registro
                  _buildFormularioSection(),
                  const SizedBox(height: 30),

                  // Seção: Presets do Dia (Tabela)
                  _buildPresetsDoDia(),
                  const SizedBox(height: 30),

                  // Seção: Histórico de Registros
                  _buildHistoricoRegistros(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMostradoresSection() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.grey.shade50, Colors.grey.shade100],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.dashboard, color: Color(0xFF0D47A1), size: 28),
                SizedBox(width: 10),
                Text(
                  'Medidores Físicos',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildMostradorDigital(
                    titulo: 'SALDO INICIAL',
                    valor: _saldoInicial != null ? _saldoInicial! : 0,
                    corFundo: Colors.green.shade50,
                    corDisplay: Colors.green.shade900,
                    icone: Icons.play_arrow,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildMostradorDigital(
                    titulo: 'SALDO FINAL',
                    valor: _saldoFinal != null ? _saldoFinal! : 0,
                    corFundo: Colors.blue.shade50,
                    corDisplay: Colors.blue.shade900,
                    icone: Icons.stop,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildMostradorDigital(
                    titulo: 'TOTAL ABASTECIDO',
                    valor: _totalAbastecido ?? 0,
                    corFundo: Colors.orange.shade50,
                    corDisplay: Colors.orange.shade900,
                    icone: Icons.local_gas_station,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMostradorDigital({
    required String titulo,
    required double valor,
    required Color corFundo,
    required Color corDisplay,
    required IconData icone,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: corFundo,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icone, color: corDisplay, size: 20),
              const SizedBox(width: 8),
              Text(
                titulo,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: corDisplay,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(2, 2),
                ),
              ],
            ),
            child: Text(
              valor.toStringAsFixed(3),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: Colors.green.shade300,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Litros',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildFormularioSection() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.edit_note, color: Color(0xFF0D47A1), size: 24),
                const SizedBox(width: 10),
                Text(
                  'Registrar Leitura do Medidor',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _saldoInicialController,
                    decoration: InputDecoration(
                      labelText: 'Saldo Inicial (Litros)',
                      hintText: 'Ex: 146258',
                      prefixIcon: Icon(Icons.start, color: Colors.green),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      suffixText: 'L',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 15),
                ElevatedButton.icon(
                  onPressed: _salvarSaldoInicial,
                  icon: const Icon(Icons.save),
                  label: const Text('Registrar Inicial'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _saldoFinalController,
                    decoration: InputDecoration(
                      labelText: 'Saldo Final (Litros)',
                      hintText: 'Ex: 148195',
                      prefixIcon: Icon(Icons.stop, color: Colors.blue),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      suffixText: 'L',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 15),
                ElevatedButton.icon(
                  onPressed: _salvarSaldoFinal,
                  icon: const Icon(Icons.save),
                  label: const Text('Registrar Final'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
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

  Widget _buildPresetsDoDia() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_gas_station, color: Color(0xFF0D47A1), size: 24),
                const SizedBox(width: 10),
                Text(
                  'Presets Realizados Hoje',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Color(0xFF0D47A1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_presetsDemonstracao.length} abastecimentos',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0D47A1),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 20,
                    headingRowColor: WidgetStateProperty.resolveWith(
                      (states) => Color(0xFF0D47A1).withOpacity(0.1),
                    ),
                    columns: const [
                      DataColumn(label: Text('Hora', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Veículo', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Litros', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: _presetsDemonstracao.map((preset) {
                      return DataRow(cells: [
                        DataCell(Text(preset['hora'])),
                        DataCell(Text(preset['veiculo'])),
                        DataCell(
                          Text(
                            '${preset['litros']} L',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoricoRegistros() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: Color(0xFF0D47A1), size: 24),
                const SizedBox(width: 10),
                Text(
                  'Histórico de Registros',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _registros.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Text(
                        'Nenhum registro ainda',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 20,
                          headingRowColor: WidgetStateProperty.resolveWith(
                            (states) => Colors.grey.shade200,
                          ),
                          columns: const [
                            DataColumn(label: Text('Data/Hora', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Tipo', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Valor (Litros)', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: _registros.map((registro) {
                            Color tipoColor = registro['tipo'] == 'Inicial'
                                ? Colors.green
                                : Colors.blue;
                            return DataRow(cells: [
                              DataCell(Text(registro['data'])),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: tipoColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    registro['tipo'],
                                    style: TextStyle(
                                      color: tipoColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  registro['valor'].toStringAsFixed(3),
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}