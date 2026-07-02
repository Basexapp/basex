import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'cacl_pdf.dart';

class CaclBombeioDialog extends StatelessWidget {
  final Map<String, dynamic>? bombeio;
  const CaclBombeioDialog({super.key, this.bombeio});

  static Future<void> show(BuildContext context, {Map<String, dynamic>? bombeio}) {
    return showDialog<void>(
      context: context,
      builder: (context) => CaclBombeioDialog(bombeio: bombeio),
    );
  }

  // Dados fictícios para teste do layout
  Map<String, dynamic> _getDadosFicticios() {
    return {
      'data': '01/07/2026',
      'horario_inicial': '08:00 h',
      'horario_final': '12:00 h',
      'base': 'FILIAL CENTRO',
      'produto': 'Gasolina Aditivada',
      'tanque': 'TQ-01-JN',
      'medicoes': {
        'cmInicial': '150,5',
        'cmFinal': '155,3',
        'volumeTotalLiquidoInicial': 10000,
        'volumeTotalLiquidoFinal': 10500,
        'alturaAguaInicial': '5,0',
        'alturaAguaFinal': '5,0',
        'volumeAguaInicial': 150,
        'volumeAguaFinal': 150,
        'alturaProdutoInicial': '145,5',
        'alturaProdutoFinal': '150,3',
        'volumeProdutoInicial': 9850,
        'volumeProdutoFinal': 10350,
        'tempTanqueInicial': '28,5',
        'tempTanqueFinal': '29,0',
        'densidadeInicial': '0,7450',
        'densidadeFinal': '0,7445',
        'tempAmostraInicial': '26,0',
        'tempAmostraFinal': '26,5',
        'densidade20Inicial': '0,7520',
        'densidade20Final': '0,7515',
        'fatorCorrecaoInicial': '0,9825',
        'fatorCorrecaoFinal': '0,9820',
        'volume20Inicial': 9680,
        'volume20Final': 10165,
        'massaInicial': 7279.4,
        'massaFinal': 7638.0,
        'totalEntradasPeriodo': 500,
        'totalSaidasPeriodo': 15,
        'faturadoFinal': 490,
      },
      'entrada_saida_ambiente': 500,
      'entrada_saida_20': 485,
      'sobra_perda': 10,
      'estoque_final_calculado': 10165,
      'observacoes': 'Bombeio realizado conforme procedimento padrão.',
    };
  }

  String _formatarVolumeLitros(double volume) {
    final volumeInteiro = volume.round();
    String inteiroFormatado = volumeInteiro.toString();

    if (inteiroFormatado.length > 3) {
      final buffer = StringBuffer();
      int contador = 0;
      for (int i = inteiroFormatado.length - 1; i >= 0; i--) {
        buffer.write(inteiroFormatado[i]);
        contador++;
        if (contador == 3 && i > 0) {
          buffer.write('.');
          contador = 0;
        }
      }
      final chars = buffer.toString().split('').reversed.toList();
      inteiroFormatado = chars.join('');
    }
    return '$inteiroFormatado L';
  }

  String _formatarAlturaTotal(String? cm, String? mm) {
    if (cm == null || cm.isEmpty) return "-";
    final mmValue = (mm == null || mm.isEmpty) ? "0" : mm;
    return "$cm,$mmValue cm";
  }

  String _formatarTemperatura(dynamic valor) {
    if (valor == null) return "-";
    final strValor = valor.toString().trim();
    if (strValor.isEmpty) return "-";
    return '$strValor ºC';
  }

  String _formatarDataDisplay(String? dataRaw) {
    if (dataRaw == null || dataRaw.isEmpty) return '';
    try {
      String s = dataRaw.trim();
      if (s.contains('T')) s = s.split('T')[0];
      if (s.contains(' ')) s = s.split(' ')[0];

      final isoMatch = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
      if (isoMatch != null) {
        final y = isoMatch.group(1)!;
        final m = isoMatch.group(2)!;
        final d = isoMatch.group(3)!;
        return '${d}/${m}/${y}';
      }

      final brMatch = RegExp(r'^(\d{2})/(\d{2})/(\d{4})').firstMatch(s);
      if (brMatch != null) return s;

      return s;
    } catch (_) {
      return dataRaw;
    }
  }

  String _obterValorMedicao(dynamic valor) {
    if (valor == null) return "-";
    if (valor is String) {
      final v = valor.trim();
      if (v.isEmpty) return "-";
      return v;
    }
    if (valor is double) {
      if (valor == 0) return "-";
      if (valor > 100) {
        return _formatarVolumeLitros(valor);
      }
      return valor.toString().replaceAll('.', ',');
    }
    return valor.toString();
  }

  Widget _secaoTitulo(String texto) {
    return Text(
      texto,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _linhaValor(String valor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black26),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        valor,
        style: const TextStyle(fontSize: 11),
      ),
    );
  }

  Widget _subtitulo(String texto) {
    return Text(
      texto,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  TableRow _linhaMedicao(String descricao, String valorInicial, String valorFinal) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Text(descricao, style: const TextStyle(fontSize: 11)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Text(
            valorInicial,
            style: const TextStyle(fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Text(
            valorFinal,
            style: const TextStyle(fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  String _formatarSobraPerdaComSinal(double valor) {
    final sinal = valor >= 0 ? '+' : '-';
    final valorFormatado = _formatarVolumeLitros(valor.abs());
    return '$sinal$valorFormatado';
  }

  @override
  Widget build(BuildContext context) {
    final dados = bombeio ?? _getDadosFicticios();
    final medicoes = dados['medicoes'] ?? {};

    final data = _formatarDataDisplay(dados['data']?.toString() ?? '01/07/2026');
    final base = dados['base']?.toString() ?? 'FILIAL CENTRO';
    final produto = dados['produto']?.toString() ?? 'Gasolina Aditivada';
    final tanque = dados['tanque']?.toString() ?? 'TQ-01-JN';
    final horarioInicial = dados['horario_inicial']?.toString() ?? '08:00 h';
    final horarioFinal = dados['horario_final']?.toString() ?? '12:00 h';

    final volumeTotalInicial = (medicoes['volumeTotalLiquidoInicial'] ?? 0).toDouble();
    final volumeTotalFinal = (medicoes['volumeTotalLiquidoFinal'] ?? 0).toDouble();
    final volumeProdutoInicial = (medicoes['volumeProdutoInicial'] ?? 0).toDouble();
    final volumeProdutoFinal = (medicoes['volumeProdutoFinal'] ?? 0).toDouble();
    final volume20Inicial = (medicoes['volume20Inicial'] ?? 0).toDouble();
    final volume20Final = (medicoes['volume20Final'] ?? 0).toDouble();

    final entradaSaidaAmbiente = (dados['entrada_saida_ambiente'] ?? 0).toDouble();
    final entradaSaida20 = (dados['entrada_saida_20'] ?? 0).toDouble();
    final sobraPerda = (dados['sobra_perda'] ?? 0).toDouble();
    final estoqueFinalCalculado = (dados['estoque_final_calculado'] ?? 0).toDouble();

    final faturado = (medicoes['faturadoFinal'] ?? 0).toDouble();

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFF0D47A1), width: 1),
      ),
      contentPadding: const EdgeInsets.all(24),
      content: SizedBox(
        width: 670,
        height: 600,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // CABEÇALHO
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  border: Border.all(color: Colors.black, width: 1.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Center(
                  child: Text(
                    "CACL - BOMBEIO",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // DADOS PRINCIPAIS
              SizedBox(
                width: double.infinity,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _secaoTitulo("DATA:"),
                          _linhaValor(data),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _secaoTitulo("HORÁRIO:"),
                          _linhaValor("$horarioInicial — $horarioFinal"),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 28,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _secaoTitulo("TERMINAL:"),
                          _linhaValor(base),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _secaoTitulo("TANQUE Nº:"),
                          _linhaValor(tanque),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _secaoTitulo("PRODUTO:"),
                          _linhaValor(produto),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // SEÇÃO DE MEDIÇÕES
              _subtitulo("VOLUME RECEBIDO NOS TANQUES DE TERRA E CANALIZAÇÃO RESPECTIVA"),
              const SizedBox(height: 12),

              Table(
                border: TableBorder.all(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                columnWidths: const {
                  0: FlexColumnWidth(2.5),
                  1: FlexColumnWidth(1.0),
                  2: FlexColumnWidth(1.0),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey[200]),
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        child: Text(
                          "DESCRIÇÃO",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        child: Text(
                          "INÍCIO — $horarioInicial",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        child: Text(
                          "FINAL — $horarioFinal",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  _linhaMedicao(
                    "Altura total de líquido no tanque:",
                    _formatarAlturaTotal(
                      medicoes['cmInicial']?.toString(),
                      medicoes['mmInicial']?.toString(),
                    ),
                    _formatarAlturaTotal(
                      medicoes['cmFinal']?.toString(),
                      medicoes['mmFinal']?.toString(),
                    ),
                  ),
                  _linhaMedicao(
                    "Volume total de líquido no tanque (temp. ambiente):",
                    _formatarVolumeLitros(volumeTotalInicial),
                    _formatarVolumeLitros(volumeTotalFinal),
                  ),
                  _linhaMedicao(
                    "Altura da água aferida no tanque:",
                    _obterValorMedicao(medicoes['alturaAguaInicial']),
                    _obterValorMedicao(medicoes['alturaAguaFinal']),
                  ),
                  _linhaMedicao(
                    "Volume correspondente à água:",
                    _obterValorMedicao(medicoes['volumeAguaInicial']),
                    _obterValorMedicao(medicoes['volumeAguaFinal']),
                  ),
                  _linhaMedicao(
                    "Altura do produto aferido no tanque:",
                    _obterValorMedicao(medicoes['alturaProdutoInicial']),
                    _obterValorMedicao(medicoes['alturaProdutoFinal']),
                  ),
                  _linhaMedicao(
                    "Volume correspondente ao produto (temp. ambiente):",
                    _formatarVolumeLitros(volumeProdutoInicial),
                    _formatarVolumeLitros(volumeProdutoFinal),
                  ),
                  _linhaMedicao(
                    "Temperatura do produto no tanque:",
                    _formatarTemperatura(medicoes['tempTanqueInicial']),
                    _formatarTemperatura(medicoes['tempTanqueFinal']),
                  ),
                  _linhaMedicao(
                    "Densidade observada na amostra:",
                    _obterValorMedicao(medicoes['densidadeInicial']),
                    _obterValorMedicao(medicoes['densidadeFinal']),
                  ),
                  _linhaMedicao(
                    "Temperatura da amostra:",
                    _formatarTemperatura(medicoes['tempAmostraInicial']),
                    _formatarTemperatura(medicoes['tempAmostraFinal']),
                  ),
                  _linhaMedicao(
                    "Densidade da amostra, considerada à temperatura padrão (20 ºC):",
                    _obterValorMedicao(medicoes['densidade20Inicial']),
                    _obterValorMedicao(medicoes['densidade20Final']),
                  ),
                  _linhaMedicao(
                    "Fator de correção de volume do produto (FCV):",
                    _obterValorMedicao(medicoes['fatorCorrecaoInicial']),
                    _obterValorMedicao(medicoes['fatorCorrecaoFinal']),
                  ),
                  _linhaMedicao(
                    "Massa do produto (Volume a 20 ºC × Densidade a 20 ºC):",
                    _obterValorMedicao(medicoes['massaInicial']),
                    _obterValorMedicao(medicoes['massaFinal']),
                  ),
                  _linhaMedicao(
                    "Volume total do produto, considerada a temperatura padrão (20 ºC):",
                    _formatarVolumeLitros(volume20Inicial),
                    _formatarVolumeLitros(volume20Final),
                  ),
                ],
              ),

              const SizedBox(height: 25),

              // COMPARAÇÃO DE RESULTADOS - SEM COLUNA "ENTRADA"
              _subtitulo("COMPARAÇÃO DE RESULTADOS"),
              const SizedBox(height: 8),

              Table(
                border: TableBorder.all(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                columnWidths: const {
                  0: FlexColumnWidth(2.5),
                  1: FlexColumnWidth(1.0),
                  2: FlexColumnWidth(1.0),
                  3: FlexColumnWidth(1.0),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: const Color(0xFFE0E0E0)),
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(6.0),
                        child: Text(
                          "DESCRIÇÃO",
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.all(6.0),
                        child: Text(
                          "Vol. Inicial",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.all(6.0),
                        child: Text(
                          "Vol. Final",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.all(6.0),
                        child: Text(
                          "DIFERENÇA",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  // Linha Volume Ambiente
                  TableRow(
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
                        child: Text("Volume ambiente", style: TextStyle(fontSize: 10)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
                        child: Text(
                          _formatarVolumeLitros(volumeProdutoInicial),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
                        child: Text(
                          _formatarVolumeLitros(volumeProdutoFinal),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
                        child: Text(
                          _formatarVolumeLitros(volumeProdutoFinal - volumeProdutoInicial),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                  // Linha Volume a 20ºC
                  TableRow(
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
                        child: Text("Volume a 20 ºC", style: TextStyle(fontSize: 10)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
                        child: Text(
                          _formatarVolumeLitros(volume20Inicial),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
                        child: Text(
                          _formatarVolumeLitros(volume20Final),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
                        child: Text(
                          _formatarVolumeLitros(volume20Final - volume20Inicial),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // BLOCO FATURADO / SOBRA E PERDA
              Row(
                children: [
                  Expanded(flex: 7, child: Container()),
                  Expanded(
                    flex: 3,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black54),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Table(
                        defaultColumnWidth: const IntrinsicColumnWidth(),
                        border: TableBorder.all(color: Colors.black54),
                        children: [
                          // Entrada/Saída Líquida
                          TableRow(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                color: const Color(0xFFF5F5F5),
                                child: const Center(
                                  child: Text(
                                    "Entrada/Saída",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                color: Colors.white,
                                child: Center(
                                  child: Text(
                                    _formatarVolumeLitros(entradaSaida20),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // Faturado
                          TableRow(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                color: const Color(0xFFF5F5F5),
                                child: const Center(
                                  child: Text(
                                    "Faturado",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                color: Colors.white,
                                child: Center(
                                  child: Text(
                                    faturado > 0 ? _formatarVolumeLitros(faturado) : "-",
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // Sobra/Perda
                          TableRow(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                color: const Color(0xFFF5F5F5),
                                child: const Center(
                                  child: Text(
                                    "Sobra / Perda",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                color: Colors.white,
                                child: Center(
                                  child: Text(
                                    _formatarSobraPerdaComSinal(sobraPerda),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: sobraPerda >= 0 ? Colors.blue[700] : Colors.red[700],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 15),

              // ESTOQUE FINAL CALCULADO
              if (estoqueFinalCalculado > 0) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    border: Border.all(color: const Color(0xFF2196F3)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Color(0xFF2196F3),
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "Estoque final calculado: ${_formatarVolumeLitros(estoqueFinalCalculado)}",
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D47A1),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 15),

              // OBSERVAÇÕES
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Observações",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      dados['observacoes']?.toString() ?? "Bombeio realizado conforme procedimento padrão.",
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'FECHAR',
            style: TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            try {
              final doc = await CACLPdf.gerar(dadosFormulario: dados);
              final bytes = await doc.save();
              await Printing.sharePdf(bytes: bytes, filename: 'cacl_bombeio.pdf');

              // Mostrar diálogo de sucesso
              showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('PDF gerado'),
                  content: const Text('PDF do CACL Bombeio gerado com sucesso.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            } catch (e, st) {
              final errorText = 'Erro ao gerar PDF:\n${e.toString()}';

              // Mostrar diálogo de erro centralizado com texto selecionável e botão de copiar
              showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Erro'),
                  content: SingleChildScrollView(
                    child: SelectableText(errorText),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: errorText));
                        // confirmação simples
                        showDialog<void>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            content: const Text('Mensagem copiada para a área de transferência.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: const Text('COPIAR'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            }
          },
          icon: const Icon(Icons.picture_as_pdf, size: 18),
          label: const Text('Gerar PDF'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0D47A1),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ],
    );
  }
}