import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cacl_pdf.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert' show base64Encode;
import 'dart:js' as js;

class CaclMovVisualizPage extends StatefulWidget {
  final String caclId;

  const CaclMovVisualizPage({
    super.key,
    required this.caclId,
  });

  @override
  State<CaclMovVisualizPage> createState() => _CaclMovVisualizPageState();
}

class _CaclMovVisualizPageState extends State<CaclMovVisualizPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _carregando = true;
  String? _erro;
  Map<String, dynamic> _dadosCacl = {};
  Map<String, dynamic> _medicoes = {};
  
  // Variáveis de volume extraídas
  double volumeInicial = 0;
  double volumeFinal = 0;
  double volumeTotalLiquidoInicial = 0;
  double volumeTotalLiquidoFinal = 0;
  double totalSaidasAmbienteReal = 0;
  double totalEntradasAmbienteReal = 0;
  double totalSaidas20Real = 0;
  double totalEntradas20Real = 0;
  String? _numeroControle;
  bool _isGeneratingPDF = false;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    try {
      final resultado = await _supabase
          .from('cacl')
          .select('*, tanques(referencia)')
          .eq('id', widget.caclId)
          .maybeSingle();

      if (resultado == null) {
        setState(() {
          _erro = 'CACL não encontrado.';
          _carregando = false;
        });
        return;
      }

      setState(() {
        _dadosCacl = resultado;
        _numeroControle = resultado['numero_controle']?.toString();
        
        _medicoes = {
          'horarioInicial': _formatarHorarioDisplay(resultado['horario_inicial']),
          'cmInicial': resultado['altura_total_cm_inicial']?.toString(),
          'mmInicial': resultado['altura_total_mm_inicial']?.toString(),
          'horarioFinal': _formatarHorarioDisplay(resultado['horario_final']),
          'cmFinal': resultado['altura_total_cm_final']?.toString(),
          'mmFinal': resultado['altura_total_mm_final']?.toString(),
          'volume20Inicial': _formatarVolumeLitros(resultado['volume_20_inicial']?.toDouble() ?? 0.0),
          'volume20Final': _formatarVolumeLitros(resultado['volume_20_final']?.toDouble() ?? 0.0),
        };

        volumeInicial = resultado['volume_produto_inicial']?.toDouble() ?? 0.0;
        volumeFinal = resultado['volume_produto_final']?.toDouble() ?? 0.0;
        volumeTotalLiquidoInicial = resultado['volume_total_liquido_inicial']?.toDouble() ?? 0.0;
        volumeTotalLiquidoFinal = resultado['volume_total_liquido_final']?.toDouble() ?? 0.0;
        
        totalSaidas20Real = resultado['total_saidas']?.toDouble() ?? 0.0;
        totalEntradas20Real = resultado['total_entradas']?.toDouble() ?? 0.0;
        
        totalSaidasAmbienteReal = resultado['total_saidas_ambiente']?.toDouble() ?? 0.0;
        totalEntradasAmbienteReal = resultado['total_entradas_ambiente']?.toDouble() ?? 0.0;

        _carregando = false;
      });
    } catch (e) {
      setState(() {
        _erro = 'Erro ao carregar dados: $e';
        _carregando = false;
      });
    }
  }

  String _formatarHorarioDisplay(String? timeString) {
    if (timeString == null || timeString.isEmpty) return '-';
    try {
      if (timeString.contains('T')) {
        final dt = DateTime.parse(timeString);
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} h';
      }
      final partes = timeString.split(':');
      if (partes.length >= 2) return '${partes[0]}:${partes[1]} h';
    } catch (_) {}
    return timeString;
  }

  String _formatarVolumeLitros(double volume) {
    if (volume.isNaN) return "-";
    final volumeInteiro = volume.round();
    final isNegativo = volumeInteiro < 0;
    String inteiroFormatado = volumeInteiro.abs().toString();
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
      inteiroFormatado = buffer.toString().split('').reversed.join();
    }
    final sinal = isNegativo ? '-' : '';
    return '$sinal$inteiroFormatado L';
  }

  String _formatarTemperatura(dynamic valor) {
    if (valor == null) return "-";
    if (valor is String && valor.isEmpty) return "-";
    final strValor = valor.toString().trim();
    final valorSemUnidade = strValor
        .replaceAll(' ºC', '')
        .replaceAll('°C', '')
        .replaceAll('ºC', '')
        .trim();
    if (valorSemUnidade.isEmpty) return "-";
    return '$valorSemUnidade ºC';
  }

  String _obterValorMedicao(dynamic valor) {
    if (valor == null) return "-";
    if (valor is String) {
      final v = valor.trim();
      if (v.isEmpty) return "-";
      final semUnidade = v.replaceAll(" cm", "").trim();
      if (semUnidade == "," ||
          semUnidade == "0,0" ||
          semUnidade == "0,00" ||
          semUnidade == "0,000" ||
          semUnidade == "0,0000") {
        return "-";
      }
      if (semUnidade == "0,") return "-";
      if (semUnidade.startsWith("0,") &&
          semUnidade.substring(2).replaceAll("0", "").isEmpty) {
        return "-";
      }
      return v;
    }
    return valor.toString();
  }

  String _obterValorMassa(dynamic valor) {
    if (valor == null) return "-";
    double? v = double.tryParse(valor.toString().replaceAll(',', '.'));
    if (v == null || v == 0) return "-";
    
    String s = v.toStringAsFixed(1).replaceAll('.', ',');
    final partes = s.split(',');
    String inteira = partes[0];
    if (inteira.length > 3) {
      final buffer = StringBuffer();
      int contador = 0;
      for (int i = inteira.length - 1; i >= 0; i--) {
        buffer.write(inteira[i]);
        contador++;
        if (contador == 3 && i > 0) {
          buffer.write('.');
          contador = 0;
        }
      }
      inteira = buffer.toString().split('').reversed.join();
    }
    return "$inteira,${partes[1]}";
  }

  String _formatarAlturaTotal(dynamic cm, dynamic mm) {
    if (cm == null || cm.toString().isEmpty) return "-";
    final mmValue = (mm == null || mm.toString().isEmpty) ? "0" : mm.toString();
    return "${cm.toString()},$mmValue cm";
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_erro != null) return Scaffold(body: Center(child: Text(_erro!)));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Visualização CACL - $_numeroControle'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Center(
          child: SizedBox(
            width: 670,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCabecalho(),
                const SizedBox(height: 20),
                _buildIdentificacao(),
                const SizedBox(height: 25),
                const Text(
                  "VOLUME RECEBIDO NOS TANQUES DE TERRA E CANALIZAÇÃO RESPECTIVA",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                _buildMedicoesTabela(),
                const SizedBox(height: 25),
                const Text(
                  "COMPARAÇÃO DE RESULTADOS",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                _buildComparacao(),
                const SizedBox(height: 30),
                _buildBotoes(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCabecalho() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE0E0E0),
        border: Border.all(color: Colors.black, width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Center(
        child: Text(
          "CACL - VISUALIZAÇÃO",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildIdentificacao() {
    final dataSql = _dadosCacl['data']?.toString() ?? '';
    final dataFormatada = dataSql.contains('-') 
        ? dataSql.split('-').reversed.join('/') 
        : dataSql;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 16,
          child: _campoInfo("Nº DE CONTROLE:", _numeroControle ?? "-"),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 16,
          child: _campoInfo("DATA:", dataFormatada),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 28,
          child: _campoInfo("BASE:", _dadosCacl['base'] ?? "POLO DE COMBUSTÍVEL"),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 20,
          child: _campoInfo("PRODUTO:", _dadosCacl['produto'] ?? "-"),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 20,
          child: _campoInfo("TANQUE Nº:", _dadosCacl['tanques']?['referencia'] ?? "-"),
        ),
      ],
    );
  }

  Widget _campoInfo(String label, String valor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black26),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(valor, style: const TextStyle(fontSize: 11)),
        ),
      ],
    );
  }

  Widget _buildMedicoesTabela() {
    return Table(
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
        _headerRow(),
        _dataRow("Altura total de líquido no tanque:", _formatarAlturaTotal(_dadosCacl['altura_total_cm_inicial'], _dadosCacl['altura_total_mm_inicial']), _formatarAlturaTotal(_dadosCacl['altura_total_cm_final'], _dadosCacl['altura_total_mm_final'])),
        _dataRow("Volume total de líquido no tanque (temp. ambiente):", _formatarVolumeLitros(volumeTotalLiquidoInicial), _formatarVolumeLitros(volumeTotalLiquidoFinal)),
        _dataRow("Altura da água aferida no tanque:", _obterValorMedicao(_dadosCacl['altura_agua_inicial']), _obterValorMedicao(_dadosCacl['altura_agua_final'])),
        _dataRow("Volume correspondente à água:", _obterValorMedicao(_dadosCacl['volume_agua_inicial']), _obterValorMedicao(_dadosCacl['volume_agua_final'])),
        _dataRow("Altura do produto aferido no tanque:", _obterValorMedicao(_dadosCacl['altura_produto_inicial']), _obterValorMedicao(_dadosCacl['altura_produto_final'])),
        _dataRow("Volume correspondente ao produto (temp. ambiente):", _formatarVolumeLitros(volumeInicial), _formatarVolumeLitros(volumeFinal)),
        _dataRow("Temperatura do produto no tanque:", _formatarTemperatura(_dadosCacl['temperatura_tanque_inicial']), _formatarTemperatura(_dadosCacl['temperatura_tanque_final'])),
        _dataRow("Densidade observada na amostra:", _obterValorMedicao(_dadosCacl['densidade_observada_inicial']), _obterValorMedicao(_dadosCacl['densidade_observada_final'])),
        _dataRow("Temperatura da amostra:", _formatarTemperatura(_dadosCacl['temperatura_amostra_inicial']), _formatarTemperatura(_dadosCacl['temperatura_amostra_final'])),
        _dataRow("Densidade da amostra, considerada à temperatura padrão (20 ºC):", _obterValorMedicao(_dadosCacl['densidade_20_inicial']), _obterValorMedicao(_dadosCacl['densidade_20_final'])),
        _dataRow("Fator de correção de volume do produto (FCV):", _obterValorMedicao(_dadosCacl['fator_correcao_inicial']), _obterValorMedicao(_dadosCacl['fator_correcao_final'])),
        _dataRow("Massa do produto (Volume a 20 ºC × Densidade  a 20 ºC):", _obterValorMassa(_dadosCacl['massa_inicial']), _obterValorMassa(_dadosCacl['massa_final'])),
        _dataRow("Volume total do produto, considerada a temperatura padrão (20 ºC):", _formatarVolumeLitros(_dadosCacl['volume_20_inicial']?.toDouble() ?? 0.0), _formatarVolumeLitros(_dadosCacl['volume_20_final']?.toDouble() ?? 0.0)),
      ],
    );
  }

  TableRow _headerRow() {
    return TableRow(
      decoration: const BoxDecoration(color: Color(0xFFE0E0E0)),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Text("DESCRIÇÃO", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Text("1ª MEDIÇÃO, ${_medicoes['horarioInicial']}", textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue[700])),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Text("2ª MEDIÇÃO, ${_medicoes['horarioFinal']}", textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue[700])),
        ),
      ],
    );
  }

  TableRow _dataRow(String desc, String val1, String val2) {
    return TableRow(
      children: [
        Padding(padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8), child: Text(desc, style: const TextStyle(fontSize: 11))),
        Padding(padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8), child: Text(val1, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11))),
        Padding(padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8), child: Text(val2, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11))),
      ],
    );
  }

  Widget _buildComparacao() {
    double entSaida20 = totalEntradas20Real - totalSaidas20Real;
    double entSaidaAmb = totalEntradasAmbienteReal - totalSaidasAmbienteReal;

    return Table(
      border: TableBorder.all(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
      columnWidths: const {
        0: FlexColumnWidth(2.5),
        1: FlexColumnWidth(1.0),
        2: FlexColumnWidth(1.1),
        3: FlexColumnWidth(1.0),
        4: FlexColumnWidth(1.0)
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFFE0E0E0)),
          children: ["DESCRIÇÃO", "1ª MEDIÇÃO", "ENTRADA/SAÍDA", "2ª MEDIÇÃO", "DIFERENÇA"].map((e) => Padding(padding: const EdgeInsets.all(6), child: Text(e, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)))).toList(),
        ),
        _rowComp("Volume ambiente", volumeInicial, entSaidaAmb, volumeFinal),
        _rowComp("Volume a 20 ºC", _extrairNum(_medicoes['volume20Inicial']), entSaida20, _extrairNum(_medicoes['volume20Final'])),
      ],
    );
  }

  double _extrairNum(String? s) {
    if (s == null) return 0;
    return double.tryParse(s.replaceAll(' L', '').replaceAll('.', '').replaceAll(',', '.')) ?? 0;
  }

  TableRow _rowComp(String desc, double m1, double es, double m2) {
    double dif = m2 - es - m1;
    return TableRow(
      children: [
        Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6), child: Text(desc, style: const TextStyle(fontSize: 10))),
        Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6), child: Text(_formatarVolumeLitros(m1), textAlign: TextAlign.center, style: const TextStyle(fontSize: 10))),
        Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6), child: Text(_formatarVolumeLitros(es), textAlign: TextAlign.center, style: const TextStyle(fontSize: 10))),
        Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6), child: Text(_formatarVolumeLitros(m2), textAlign: TextAlign.center, style: const TextStyle(fontSize: 10))),
        Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6), child: Text(_formatarVolumeLitros(dif), textAlign: TextAlign.center, style: const TextStyle(fontSize: 10))),
      ],
    );
  }

  Widget _buildBotoes() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text("Voltar"),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0D47A1),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
        const SizedBox(width: 20),
        ElevatedButton.icon(
          onPressed: _isGeneratingPDF ? null : _baixarPDF,
          icon: _isGeneratingPDF 
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
            : const Icon(Icons.picture_as_pdf, size: 18),
          label: Text(_isGeneratingPDF ? "Gerando..." : "Gerar PDF"),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0D47A1),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
      ],
    );
  }

  Future<void> _baixarPDF() async {
    setState(() => _isGeneratingPDF = true);
    try {
      // Mapear dados para o formato esperado pelo CACLPdf.gerar
      final Map<String, dynamic> dadosParaPdf = {
        'id': _dadosCacl['id'],
        'numero_controle': _dadosCacl['numero_controle'],
        'data': _dadosCacl['data'],
        'horario_inicial': _dadosCacl['horario_inicial'],
        'base': _dadosCacl['base'] ?? "POLO DE COMBUSTÍVEL",
        'produto': _dadosCacl['produto'],
        'tanque': _dadosCacl['tanques']?['referencia'],
        'medicoes': {
          'horarioInicial': _medicoes['horarioInicial'],
          'cmInicial': _dadosCacl['altura_total_cm_inicial'],
          'mmInicial': _dadosCacl['altura_total_mm_inicial'],
          'horarioFinal': _medicoes['horarioFinal'],
          'cmFinal': _dadosCacl['altura_total_cm_final'],
          'mmFinal': _dadosCacl['altura_total_mm_final'],
          'volume20Inicial': _dadosCacl['volume_20_inicial'],
          'volume20Final': _dadosCacl['volume_20_final'],
          'volumeTotalLiquidoInicial': _dadosCacl['volume_total_liquido_inicial'],
          'volumeTotalLiquidoFinal': _dadosCacl['volume_total_liquido_final'],
          'alturaAguaInicial': _dadosCacl['altura_agua_inicial'],
          'alturaAguaFinal': _dadosCacl['altura_agua_final'],
          'volumeAguaInicial': _dadosCacl['volume_agua_inicial'],
          'volumeAguaFinal': _dadosCacl['volume_agua_final'],
          'alturaProdutoInicial': _dadosCacl['altura_produto_inicial'],
          'alturaProdutoFinal': _dadosCacl['altura_produto_final'],
          'volumeProdutoInicial': _dadosCacl['volume_produto_inicial'],
          'volumeProdutoFinal': _dadosCacl['volume_produto_final'],
          'tempTanqueInicial': _dadosCacl['temperatura_tanque_inicial'],
          'tempTanqueFinal': _dadosCacl['temperatura_tanque_final'],
          'densidadeObsInicial': _dadosCacl['densidade_observada_inicial'],
          'densidadeObsFinal': _dadosCacl['densidade_observada_final'],
          'tempAmostraInicial': _dadosCacl['temperatura_amostra_inicial'],
          'tempAmostraFinal': _dadosCacl['temperatura_amostra_final'],
          'densidade20Inicial': _dadosCacl['densidade_20_inicial'],
          'densidade20Final': _dadosCacl['densidade_20_final'],
          'fatorCorrecaoInicial': _dadosCacl['fator_correcao_inicial'],
          'fatorCorrecaoFinal': _dadosCacl['fator_correcao_final'],
          'massaInicial': _dadosCacl['massa_inicial'],
          'massaFinal': _dadosCacl['massa_final'],
        },
        'total_entradas_ambiente': totalEntradasAmbienteReal,
        'total_saidas_ambiente': totalSaidasAmbienteReal,
        'total_entradas': totalEntradas20Real,
        'total_saidas': totalSaidas20Real,
      };

      final pdfDocument = await CACLPdf.gerar(dadosFormulario: dadosParaPdf);
      final pdfBytes = await pdfDocument.save();
      
      if (kIsWeb) {
        final base64 = base64Encode(pdfBytes);
        final dataUrl = 'data:application/pdf;base64,$base64';
        js.context.callMethod('eval', ["const a = document.createElement('a'); a.href = '$dataUrl'; a.download = 'CACL_MOV_$_numeroControle.pdf'; a.click();"]);
      } else {
        // Para mobile/desktop, você precisaria de um salvamento de arquivo (path_provider e dart:io)
        // Como o foco parece ser Web, mantive o JS call.
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Download não disponível nesta plataforma.")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao gerar PDF: $e")));
    } finally {
      setState(() => _isGeneratingPDF = false);
    }
  }
}
