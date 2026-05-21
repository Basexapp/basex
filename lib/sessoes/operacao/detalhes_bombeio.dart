import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class DetalhesBombeioPage extends StatefulWidget {
  final Map<String, dynamic> bombeio;
  final VoidCallback onVoltar;

  const DetalhesBombeioPage({
    super.key,
    required this.bombeio,
    required this.onVoltar,
  });

  @override
  State<DetalhesBombeioPage> createState() => _DetalhesBombeioPageState();
}

class _DetalhesBombeioPageState extends State<DetalhesBombeioPage> {
  final NumberFormat _fmt = NumberFormat.decimalPattern('pt_BR');

  String _formatarData(DateTime? data) => data == null
      ? '-'
      : "${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}";

  String _formatarDataIso(String? dataIso) {
    if (dataIso == null) return '-';
    try {
      DateTime dt = DateTime.parse(dataIso);
      return DateFormat('dd/MM/yyyy').format(dt);
    } catch (e) {
      return dataIso;
    }
  }

  String _formatarHorario(dynamic horario) {
    if (horario == null) return '-';
    String s = horario.toString();
    if (s.length >= 5) return s.substring(0, 5);
    return s;
  }

  Widget _buildInfoColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF0D47A1),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildMedicaoDisplay(
      Map<String, dynamic> medicao, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.straighten, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoColumn('Nº Controle', medicao['num_controle'] ?? '-'),
              _buildInfoColumn('Data', _formatarDataIso(medicao['data'])),
              _buildInfoColumn('Horário', _formatarHorario(medicao['horario'])),
              _buildInfoColumn('Vol. Amb.',
                  '${_fmt.format((medicao['volume_ambiente'] as num?)?.toInt() ?? 0)} L'),
              _buildInfoColumn('Vol. 20ºC',
                  '${_fmt.format((medicao['volume_20'] as num?)?.toInt() ?? 0)} L'),
            ],
          ),
        ],
      ), // informações centraliz
    );
  }

  Widget _buildHeaderMicroItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0D47A1))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final double totalSolicitado = widget.bombeio['volume_solicitado'];
    final double recebidoAmb = (widget.bombeio['recebido_amb'] ?? 0).toDouble();
    final double recebido20 = (widget.bombeio['recebido_20'] ?? 0).toDouble();
    final List<Map<String, dynamic>> participantes =
        List<Map<String, dynamic>>.from(widget.bombeio['participantes']);

    // Ordenando da que mais participou para a que menos participou (pelo volume solicitado)
    participantes.sort((a, b) =>
        (b['solicitado'] as double).compareTo(a['solicitado'] as double));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('DETALHES DO BOMBEIO',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0D47A1),
                letterSpacing: 1.2)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
            onPressed: widget.onVoltar),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const Divider(height: 1),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
            color: const Color(0xFFFBFBFB),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildHeaderMicroItem(
                    'CONTROLE', widget.bombeio['numero_controle']),
                _buildHeaderMicroItem(
                    'DATA', _formatarData(widget.bombeio['data'])),
                _buildHeaderMicroItem('HORÁRIO',
                    '${widget.bombeio['horario_inicial']} - ${widget.bombeio['horario_final']}'),
                _buildHeaderMicroItem('PRODUTO', widget.bombeio['produto']),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- MEDIÇÕES ---
                  const Text(
                    'MEDIÇÕES DO BOMBEIO',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D47A1),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (widget.bombeio['medicao_inicial'] != null)
                    _buildMedicaoDisplay(
                      widget.bombeio['medicao_inicial'],
                      'MEDIÇÃO INICIAL',
                      const Color(0xFF0D47A1),
                    ),
                  if (widget.bombeio['medicao_inicial'] != null)
                    const SizedBox(height: 12),
                  if (widget.bombeio['medicao_final'] != null)
                    _buildMedicaoDisplay(
                      widget.bombeio['medicao_final'],
                      'MEDIÇÃO FINAL',
                      Colors.green.shade700,
                    ),
                  const SizedBox(height: 24),

                  // --- RESUMO E GRÁFICO ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text('TOTAL SOLICITADO',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey)),
                          const SizedBox(height: 2),
                          Text('${_fmt.format(totalSolicitado.toInt())} L',
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF455A64))),
                          const SizedBox(height: 16),
                          const Text('TOTAL RECEBIDO (AMB)',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey)),
                          const SizedBox(height: 2),
                          Text('${_fmt.format(recebidoAmb.toInt())} L',
                              style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0D47A1))),
                          const SizedBox(height: 16),
                          const Text('TOTAL RECEBIDO (20ºC)',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey)),
                          const SizedBox(height: 2),
                          Text('${_fmt.format(recebido20.toInt())} L',
                                style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF388E3C))),
                        ],
                      ),
                      const SizedBox(width: 30),
                      SizedBox(
                        width: 180,
                        height: 180,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 40,
                            sections: List.generate(participantes.length, (i) {
                              final p = participantes[i];
                              final colors = [
                                const Color(0xFF0D47A1), // Azul Escuro
                                const Color(0xFFD32F2F), // Vermelho
                                const Color(0xFF388E3C), // Verde
                                const Color(0xFFFBC02D), // Amarelo/Dourado
                              ];
                              return PieChartSectionData(
                                color: colors[i % colors.length],
                                value: p['solicitado'],
                                title:
                                    '${p['nome'].toString().split(' ')[0]}\n${totalSolicitado > 0 ? ((p['solicitado'] / totalSolicitado) * 100).toStringAsFixed(0) : '0'}%',
                                radius: 50,
                                titleStyle: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(color: Colors.black45, blurRadius: 2)
                                  ],
                                ),
                                titlePositionPercentageOffset: 0.55,
                              );
                            }),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  const Text(
                    'DISTRIBUIÇÃO E RATEIO',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D47A1),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tabela de distribuição fixa
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        const SizedBox(width: 8),
                        Expanded(
                            flex: 3,
                            child: Text('DISTRIBUIDORA',
                                textAlign: TextAlign.left,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[700]))),
                        Expanded(
                            flex: 1,
                            child: Text('%',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[700]))),
                        Expanded(
                            flex: 2,
                            child: Text('SOLICITADO',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[700]))),
                        Expanded(
                            flex: 2,
                            child: Text('RECEB. (AMB)',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[700]))),
                        Expanded(
                            flex: 2,
                            child: Text('RECEB. (20ºC)',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[700]))),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  ...participantes.asMap().entries.map((entry) {
                    final index = entry.key;
                    final p = entry.value;
                    double peso = totalSolicitado > 0
                        ? (p['solicitado'] / totalSolicitado)
                        : 0;
                    double recAmbPart = recebidoAmb * peso;
                    double rec20Part = recebido20 * peso;
                    double percent = peso; // O percentual do rateio é baseado no solicitado

                    final colors = [
                      const Color(0xFF0D47A1),
                      const Color(0xFFD32F2F),
                      const Color(0xFF388E3C),
                      const Color(0xFFFBC02D),
                    ];

                    return Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      margin: const EdgeInsets.only(right: 12),
                                      decoration: BoxDecoration(
                                        color: colors[index % colors.length],
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p['nome'].toString().toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF263238),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 6),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(2),
                                            child: LinearProgressIndicator(
                                              value: percent,
                                              backgroundColor: Colors.grey[100],
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                colors[index % colors.length]
                                              ),
                                              minHeight: 3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  '${(percent * 100).toStringAsFixed(1)}%',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF455A64),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '${_fmt.format(p['solicitado'].toInt())} L',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF455A64),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '${_fmt.format(recAmbPart.toInt())} L',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: colors[index % colors.length],
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '${_fmt.format(rec20Part.toInt())} L',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: colors[index % colors.length],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                      ],
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
