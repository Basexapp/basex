import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'cacl_pdf.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CaclBombeioDialog extends StatelessWidget {
  final Map<String, dynamic>? bombeio;
  const CaclBombeioDialog({super.key, this.bombeio});

  /// Busca um `bombeio` completo no banco (Supabase) e abre o diálogo.
  static Future<void> showById(BuildContext context, String bombeioId) async {
    try {
      final supabase = Supabase.instance.client;

      // 1) Buscar o bombeio
      final b = await supabase.from('bombeios').select().eq('id', bombeioId).maybeSingle();
      if (b == null) {
        if (!context.mounted) {
          return;
        }
        await showDialog<void>(context: context, builder: (_) => AlertDialog(title: const Text('Erro'), content: const Text('Bombeio não encontrado.'), actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))]));
        return;
      }

      // 2) Buscar medições inicial e final (se existirem)
      Map<String, dynamic>? medIni;
      Map<String, dynamic>? medFin;
      if (b['medicao_inicial_id'] != null) {
        final m = await supabase.from('medicoes').select().eq('id', b['medicao_inicial_id']).maybeSingle();
        if (m != null) medIni = Map<String, dynamic>.from(m);
      }
      if (b['medicao_final_id'] != null) {
        final m = await supabase.from('medicoes').select().eq('id', b['medicao_final_id']).maybeSingle();
        if (m != null) medFin = Map<String, dynamic>.from(m);
      }

      // 3) Buscar tanque (+ produto)
      Map<String, dynamic>? tanque;
      Map<String, dynamic>? produto;
      if (b['tanque_id'] != null) {
        final t = await supabase.from('tanques').select('*, produtos(id, nome, nome_dois)').eq('id', b['tanque_id']).maybeSingle();
        if (t != null) {
          tanque = Map<String, dynamic>.from(t);
          final p = t['produtos'];
          if (p is List) {
            produto = p.isNotEmpty ? Map<String, dynamic>.from(p[0]) : null;
          } else if (p is Map) {
            produto = Map<String, dynamic>.from(p);
          }
        }
      }

      // 4) Terminal e empresa
      Map<String, dynamic>? terminal;
      Map<String, dynamic>? empresa;
      if (b['terminal_id'] != null) {
        final t = await supabase.from('terminais').select().eq('id', b['terminal_id']).maybeSingle();
        if (t != null) terminal = Map<String, dynamic>.from(t);
      }
      if (b['empresa_id'] != null) {
        final e = await supabase.from('empresas').select().eq('id', b['empresa_id']).maybeSingle();
        if (e != null) empresa = Map<String, dynamic>.from(e);
      }

      // 5) Montar mapa no formato esperado pelo diálogo / PDF
      final Map<String, dynamic> combined = Map<String, dynamic>.from(b);
      combined['medicao_inicial'] = medIni;
      combined['medicao_final'] = medFin;
      combined['tanque'] = tanque;
      combined['produto'] = produto ?? tankProdutoFromMap(tanque);
      combined['terminal'] = terminal;
      combined['empresa'] = empresa;

      // Montar também um submap 'medicoes' compatível com o que o PDF espera
      final medicoes = <String, dynamic>{};
      if (medIni != null) {
        medicoes['cmInicial'] = medIni['altura_total_cm']?.toString();
        medicoes['mmInicial'] = medIni['altura_total_mm']?.toString();
        medicoes['volumeTotalLiquidoInicial'] = medIni['volume_total_liquido'] ?? medIni['volume_ambiente'];
        medicoes['alturaAguaInicial'] = medIni['agua_cm']?.toString();
        medicoes['volumeAguaInicial'] = medIni['vol_agua'] ?? medIni['vol_agua'];
        medicoes['alturaProdutoInicial'] = (medIni['altura_total_cm'] != null) ? ((medIni['altura_total_cm'] - (medIni['agua_cm'] ?? 0)).toString()) : null;
        medicoes['volumeProdutoInicial'] = medIni['volume_ambiente'] ?? medIni['volume_total_liquido'];
        medicoes['tempTanqueInicial'] = medIni['temperatura_tanque']?.toString();
        medicoes['densidadeInicial'] = medIni['densidade_observada']?.toString();
        medicoes['tempAmostraInicial'] = medIni['temperatura_amostra']?.toString();
        medicoes['densidade20Inicial'] = medIni['densidade_20']?.toString();
        medicoes['fatorCorrecaoInicial'] = medIni['fcv']?.toString();
        medicoes['volume20Inicial'] = medIni['volume_20'];
        medicoes['massaInicial'] = medIni['massa'];
      }
      if (medFin != null) {
        medicoes['cmFinal'] = medFin['altura_total_cm']?.toString();
        medicoes['mmFinal'] = medFin['altura_total_mm']?.toString();
        medicoes['volumeTotalLiquidoFinal'] = medFin['volume_total_liquido'] ?? medFin['volume_ambiente'];
        medicoes['alturaAguaFinal'] = medFin['agua_cm']?.toString();
        medicoes['volumeAguaFinal'] = medFin['vol_agua'] ?? medFin['vol_agua'];
        medicoes['alturaProdutoFinal'] = (medFin['altura_total_cm'] != null) ? ((medFin['altura_total_cm'] - (medFin['agua_cm'] ?? 0)).toString()) : null;
        medicoes['volumeProdutoFinal'] = medFin['volume_ambiente'] ?? medFin['volume_total_liquido'];
        medicoes['tempTanqueFinal'] = medFin['temperatura_tanque']?.toString();
        medicoes['densidadeFinal'] = medFin['densidade_observada']?.toString();
        medicoes['tempAmostraFinal'] = medFin['temperatura_amostra']?.toString();
        medicoes['densidade20Final'] = medFin['densidade_20']?.toString();
        medicoes['fatorCorrecaoFinal'] = medFin['fcv']?.toString();
        medicoes['volume20Final'] = medFin['volume_20'];
        medicoes['massaFinal'] = medFin['massa'];
      }
      combined['medicoes'] = medicoes;

      // 6) Finalmente abre o diálogo com dados completos
      if (!context.mounted) {
        return;
      }
      return show(context, bombeio: combined);
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      await showDialog<void>(context: context, builder: (_) => AlertDialog(title: const Text('Erro'), content: Text('Erro ao carregar bombeio: $e'), actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))]));
    }
  }

  static Map<String,dynamic>? tankProdutoFromMap(Map<String,dynamic>? tanqueMap) {
    if (tanqueMap == null) return null;
    final p = tanqueMap['produtos'];
    if (p == null) return null;
    if (p is List && p.isNotEmpty) return Map<String,dynamic>.from(p[0]);
    if (p is Map) return Map<String,dynamic>.from(p);
    return null;
  }

  static Future<void> show(BuildContext context, {Map<String, dynamic>? bombeio}) {
    return showDialog<void>(
      context: context,
      builder: (context) => CaclBombeioDialog(bombeio: bombeio),
    );
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
        return '$d/$m/$y';
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
      child: Center(
        child: Text(
          valor,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11),
        ),
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
    final dados = bombeio ?? <String, dynamic>{};
    // medicoes pode vir já populado por showById ou pelo dialog de edição
    final medicoes = Map<String, dynamic>.from(dados['medicoes'] ?? {});

    // Se não houver 'medicoes' tente construir a partir de medicao_inicial/final
    if (medicoes.isEmpty) {
      final medIni = dados['medicao_inicial'];
      final medFin = dados['medicao_final'];
      if (medIni is Map || medFin is Map) {
        if (medIni is Map) {
          medicoes['cmInicial'] = medIni['altura_total_cm']?.toString();
          medicoes['mmInicial'] = medIni['altura_total_mm']?.toString();
          medicoes['volumeTotalLiquidoInicial'] = medIni['volume_total_liquido'] ?? medIni['volume_ambiente'];
          medicoes['alturaAguaInicial'] = medIni['agua_cm']?.toString();
          medicoes['volumeAguaInicial'] = medIni['vol_agua'] ?? medIni['vol_agua'];
          medicoes['alturaProdutoInicial'] = (medIni['altura_total_cm'] != null) ? ((medIni['altura_total_cm'] - (medIni['agua_cm'] ?? 0)).toString()) : null;
          medicoes['volumeProdutoInicial'] = medIni['volume_ambiente'] ?? medIni['volume_total_liquido'];
          medicoes['tempTanqueInicial'] = medIni['temperatura_tanque']?.toString();
          medicoes['densidadeInicial'] = medIni['densidade_observada']?.toString();
          medicoes['tempAmostraInicial'] = medIni['temperatura_amostra']?.toString();
          medicoes['densidade20Inicial'] = medIni['densidade_20']?.toString();
          medicoes['fatorCorrecaoInicial'] = medIni['fcv']?.toString();
          medicoes['volume20Inicial'] = medIni['volume_20'];
          medicoes['massaInicial'] = medIni['massa'];
        }
        if (medFin is Map) {
          medicoes['cmFinal'] = medFin['altura_total_cm']?.toString();
          medicoes['mmFinal'] = medFin['altura_total_mm']?.toString();
          medicoes['volumeTotalLiquidoFinal'] = medFin['volume_total_liquido'] ?? medFin['volume_ambiente'];
          medicoes['alturaAguaFinal'] = medFin['agua_cm']?.toString();
          medicoes['volumeAguaFinal'] = medFin['vol_agua'] ?? medFin['vol_agua'];
          medicoes['alturaProdutoFinal'] = (medFin['altura_total_cm'] != null) ? ((medFin['altura_total_cm'] - (medFin['agua_cm'] ?? 0)).toString()) : null;
          medicoes['volumeProdutoFinal'] = medFin['volume_ambiente'] ?? medFin['volume_total_liquido'];
          medicoes['tempTanqueFinal'] = medFin['temperatura_tanque']?.toString();
          medicoes['densidadeFinal'] = medFin['densidade_observada']?.toString();
          medicoes['tempAmostraFinal'] = medFin['temperatura_amostra']?.toString();
          medicoes['densidade20Final'] = medFin['densidade_20']?.toString();
          medicoes['fatorCorrecaoFinal'] = medFin['fcv']?.toString();
          medicoes['volume20Final'] = medFin['volume_20'];
          medicoes['massaFinal'] = medFin['massa'];
        }
      }
    }

    final data = _formatarDataDisplay(dados['data']?.toString() ?? '');
    final base = (dados['terminal'] is Map) ? (dados['terminal']['nome'] ?? dados['terminal']['referencia'])?.toString() : (dados['base']?.toString() ?? '');
    final produto = (dados['produto'] is Map) ? (dados['produto']['nome'] ?? dados['produto']['nome_dois'])?.toString() : (dados['produto']?.toString() ?? '');
    final tanque = (dados['tanque'] is Map) ? (dados['tanque']['referencia'] ?? dados['tanque']['id'])?.toString() : (dados['tanque']?.toString() ?? '');
    final horarioInicial = (dados['medicao_inicial'] is Map)
      ? (dados['medicao_inicial']['horario']?.toString() ?? '')
      : (dados['horario_inicial']?.toString() ?? '');
    final horarioFinal = '';

    final volumeTotalInicial = (medicoes['volumeTotalLiquidoInicial'] ?? 0).toDouble();
    final volumeTotalFinal = (medicoes['volumeTotalLiquidoFinal'] ?? 0).toDouble();
    final volumeProdutoInicial = (medicoes['volumeProdutoInicial'] ?? 0).toDouble();
    final volumeProdutoFinal = (medicoes['volumeProdutoFinal'] ?? 0).toDouble();
    final volume20Inicial = (medicoes['volume20Inicial'] ?? 0).toDouble();
    final volume20Final = (medicoes['volume20Final'] ?? 0).toDouble();

    // Vol. apurado a 20ºC deve ser a diferença entre as medições a 20ºC
    final volApurado20 = (volume20Final - volume20Inicial);

    // O volume faturado vem do campo 'qtd_faturada' do bombeio (DialogInserirBombeio)
    final faturado = (dados['qtd_faturada'] ?? medicoes['faturadoFinal'] ?? 0).toDouble();

    // Sobra/Perda = Vol. apurado a 20ºC - Vol. faturado
    final sobraPerda = (volApurado20 - faturado);

    final estoqueFinalCalculado = (dados['estoque_final_calculado'] ?? 0).toDouble();

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
                    "CACL - PRÉ-VISUALIZAÇÃO",
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
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Center(child: _secaoTitulo("DATA:")),
                          _linhaValor(data.isEmpty ? '-' : data),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                              Center(child: _secaoTitulo("HORÁRIO:")),
                              _linhaValor(horarioInicial.isEmpty ? '-' : horarioInicial),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 28,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Center(child: _secaoTitulo("TERMINAL:")),
                          _linhaValor(base ?? '-'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Center(child: _secaoTitulo("TANQUE Nº:")),
                          _linhaValor(tanque ?? '-'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Center(child: _secaoTitulo("PRODUTO:")),
                          _linhaValor(produto ?? '-'),
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

              // BLOCO FATURADO / SOBRA E PERDA (alinhado à direita)
              Align(
                alignment: Alignment.centerRight,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black54),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Table(
                      // segunda coluna terá largura proporcional igual à última coluna da tabela de comparação
                      columnWidths: const {0: FixedColumnWidth(121), 1: FixedColumnWidth(121)},
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
                                    "Vol. apurado a 20ºC:",
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
                                    _formatarVolumeLitros(volApurado20),
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
                                    "Vol. faturado:",
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
              // Normalizar campos que podem ser mapas para evitar imprimir o map inteiro
              final dadosParaPdf = Map<String, dynamic>.from(dados);
              // `tanque` no PDF deve ser a referência do tanque, não o objeto inteiro
              dadosParaPdf['tanque'] = tanque ?? dadosParaPdf['tanque']?.toString();
              // `produto` no PDF deve ser o nome do produto
              dadosParaPdf['produto'] = produto ?? dadosParaPdf['produto']?.toString();

              final doc = await CACLPdf.gerar(dadosFormulario: dadosParaPdf);
              final bytes = await doc.save();
              await Printing.sharePdf(bytes: bytes, filename: 'cacl_bombeio.pdf');

              // Mostrar diálogo de sucesso
              if (!context.mounted) {
                return;
              }
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
            } catch (e) {
              final errorText = 'Erro ao gerar PDF:\n${e.toString()}';

              // Mostrar diálogo de erro centralizado com texto selecionável e botão de copiar
              if (!context.mounted) {
                return;
              }
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
                        if (!context.mounted) {
                          return;
                        }
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