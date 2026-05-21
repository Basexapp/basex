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
    final double totalRecebido = widget.bombeio['volume_total'];
    final double totalSolicitado = widget.bombeio['volume_solicitado'];
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
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('VOLUME TOTAL SOLICITADO',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey)),
                    const SizedBox(height: 2),
                    Text('${_fmt.format(totalSolicitado.toInt())} L',
                        style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF455A64))),
                    const SizedBox(height: 20),
                    const Text('VOLUME TOTAL RECEBIDO',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey)),
                    const SizedBox(height: 2),
                    Text('${_fmt.format(totalRecebido.toInt())} L',
                        style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0D47A1))),
                  ],
                ),
                const SizedBox(width: 60),
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
                          radius: 60,
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
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const SizedBox(width: 8),
                Expanded(
                    flex: 3,
                    child: Text('DISTRIBUIDORA',
                        textAlign: TextAlign.left,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700]))),
                Expanded(
                    flex: 1,
                    child: Text('%',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700]))),
                Expanded(
                    flex: 2,
                    child: Text('SOLICITADO',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700]))),
                Expanded(
                    flex: 2,
                    child: Text('RECEBIDO',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700]))),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: participantes.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                final p = participantes[index];
                double peso = totalSolicitado > 0
                    ? (p['solicitado'] / totalSolicitado)
                    : 0;
                double recebido = totalRecebido * peso;
                double percent =
                    totalRecebido > 0 ? (recebido / totalRecebido) : 0;

                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                                shape: BoxShape.circle,
                                color: const [
                                  Color(0xFF0D47A1), // Azul Escuro
                                  Color(0xFFD32F2F), // Vermelho
                                  Color(0xFF388E3C), // Verde
                                  Color(0xFFFBC02D), // Amarelo/Dourado
                                ][index % 4],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p['nome'],
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF333333))),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: LinearProgressIndicator(
                                      value: percent,
                                      backgroundColor: Colors.grey[100],
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          const [
                                        Color(0xFF0D47A1),
                                        Color(0xFFD32F2F),
                                        Color(0xFF388E3C),
                                        Color(0xFFFBC02D)
                                      ][index % 4]),
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
                        child: Text('${(percent * 100).toStringAsFixed(1)}%',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(_fmt.format(p['solicitado'].toInt()),
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(_fmt.format(recebido.toInt()),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: const [
                                Color(0xFF0D47A1),
                                Color(0xFFD32F2F),
                                Color(0xFF388E3C),
                                Color(0xFFFBC02D)
                              ][index % 4],
                            )),
                      ),
                    ],
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
