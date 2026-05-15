import 'package:flutter/material.dart';

class MedicoesPage extends StatefulWidget {
  final VoidCallback onVoltar;
  final String? produtoNome;

  const MedicoesPage({
    super.key,
    required this.onVoltar,
    this.produtoNome,
  });

  @override
  State<MedicoesPage> createState() => _MedicoesPageState();
}

class _MedicoesPageState extends State<MedicoesPage> {
  int? _hoverIndex;

  // Dados fictícios para teste de layout
  final List<Map<String, dynamic>> _medicoesFicticias = [
    {
      'tanque': 'TQ-01',
      'data': '15/05/2026',
      'altura_cm': '500',
      'altura_mm': '5',
      'volume_amb': '50.000',
      'temp_tanque': '25,5',
      'densidade': '0,850',
      'temp_amostra': '24,0',
      'volume_20': '49.850',
      'massa': '42.372',
    },
    {
      'tanque': 'TQ-02',
      'data': '15/05/2026',
      'altura_cm': '320',
      'altura_mm': '2',
      'volume_amb': '32.000',
      'temp_tanque': '26,0',
      'densidade': '0,845',
      'temp_amostra': '25,0',
      'volume_20': '31.840',
      'massa': '26.905',
    },
    {
      'tanque': 'TQ-03',
      'data': '14/05/2026',
      'altura_cm': '450',
      'altura_mm': '0',
      'volume_amb': '45.000',
      'temp_tanque': '24,8',
      'densidade': '0,852',
      'temp_amostra': '24,5',
      'volume_20': '44.910',
      'massa': '38.263',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15.0),
        child: Column(
          children: [
            // Cabeçalho similar ao HistoricoCaclPage
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(0, 8, 16, 8),
              decoration: const BoxDecoration(
                color: Color(0xFFF8F9FA),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
                    onPressed: widget.onVoltar,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.produtoNome != null 
                              ? 'Medições - ${widget.produtoNome}'
                              : 'Medições',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                        const Text(
                          'Lista de todas as medições realizadas',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Cabeçalho da Tabela
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Container(width: 4), // Espaço para barra colorida
                  const SizedBox(width: 12),
                  _buildHeaderCell('Tanque', flex: 2),
                  _buildHeaderCell('Data', flex: 2),
                  _buildHeaderCell('Alt. cm', flex: 2),
                  _buildHeaderCell('Alt. mm', flex: 2),
                  _buildHeaderCell('Vol. Amb', flex: 3),
                  _buildHeaderCell('Temp. Tq', flex: 2),
                  _buildHeaderCell('Dens. Obs', flex: 2),
                  _buildHeaderCell('Temp. Am', flex: 2),
                  _buildHeaderCell('Vol. 20°C', flex: 3),
                  _buildHeaderCell('Massa', flex: 3),
                  const SizedBox(width: 24), // Espaço para o ícone
                ],
              ),
            ),

            const Divider(height: 1),

            // Lista de Medições
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: _medicoesFicticias.length,
                itemBuilder: (context, index) {
                  final medicao = _medicoesFicticias[index];
                  return MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) => setState(() => _hoverIndex = index),
                    onExit: (_) => setState(() => _hoverIndex = null),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      color: _hoverIndex == index 
                          ? Colors.grey.shade200 
                          : (index.isEven ? Colors.white : Colors.grey.shade50),
                      child: Row(
                        children: [
                          // Indicador de status (decorativo)
                          Container(
                            width: 4,
                            height: 24,
                            color: const Color(0xFF0D47A1).withOpacity(0.5),
                          ),
                          const SizedBox(width: 12),
                          
                          _buildDataCell(medicao['tanque'], flex: 2),
                          _buildDataCell(medicao['data'], flex: 2),
                          _buildDataCell(medicao['altura_cm'], flex: 2),
                          _buildDataCell(medicao['altura_mm'], flex: 2),
                          _buildDataCell(medicao['volume_amb'], flex: 3),
                          _buildDataCell(medicao['temp_tanque'], flex: 2),
                          _buildDataCell(medicao['densidade'], flex: 2),
                          _buildDataCell(medicao['temp_amostra'], flex: 2),
                          _buildDataCell(medicao['volume_20'], flex: 3),
                          _buildDataCell(medicao['massa'], flex: 3),
                          
                          const SizedBox(width: 24), // Espaço para manter alinhamento
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String label, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildDataCell(String? value, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        value ?? '-',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
