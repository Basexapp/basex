import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'cacl_pdf_duplo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CaclBombeioDialog extends StatelessWidget {
  final Map<String, dynamic>? bombeio;
  const CaclBombeioDialog({super.key, this.bombeio});

  /// Busca um `bombeio` completo no banco (Supabase) e abre o diálogo.
  static Future<void> showById(BuildContext context, String bombeioId) async {
    try {
      // Mostrar diálogo de carregamento central enquanto busca os dados
      if (context.mounted) {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Dialog(
            backgroundColor: Colors.transparent,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        );
      }
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

      // 2) Buscar medições inicial e final (se existirem) - TANQUE 1
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

      // 3) Buscar medições inicial e final - TANQUE 2
      Map<String, dynamic>? medIni2;
      Map<String, dynamic>? medFin2;
      if (b['medicao_inicial_id_2'] != null) {
        final m = await supabase.from('medicoes').select().eq('id', b['medicao_inicial_id_2']).maybeSingle();
        if (m != null) medIni2 = Map<String, dynamic>.from(m);
      }
      if (b['medicao_final_id_2'] != null) {
        final m = await supabase.from('medicoes').select().eq('id', b['medicao_final_id_2']).maybeSingle();
        if (m != null) medFin2 = Map<String, dynamic>.from(m);
      }

      // 4) Buscar tanque 1 (+ produto)
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

      // 5) Buscar tanque 2 (+ produto)
      Map<String, dynamic>? tanque2;
      Map<String, dynamic>? produto2;
      if (b['tanque_id_2'] != null) {
        final t = await supabase.from('tanques').select('*, produtos(id, nome, nome_dois)').eq('id', b['tanque_id_2']).maybeSingle();
        if (t != null) {
          tanque2 = Map<String, dynamic>.from(t);
          final p = t['produtos'];
          if (p is List) {
            produto2 = p.isNotEmpty ? Map<String, dynamic>.from(p[0]) : null;
          } else if (p is Map) {
            produto2 = Map<String, dynamic>.from(p);
          }
        }
      }

      // 6) Terminal e empresa
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

      // 7) Montar mapa no formato esperado pelo diálogo / PDF
      final Map<String, dynamic> combined = Map<String, dynamic>.from(b);
      
      // Tanque 1
      combined['medicao_inicial'] = medIni;
      combined['medicao_final'] = medFin;
      combined['tanque'] = tanque;
      combined['produto'] = produto ?? tankProdutoFromMap(tanque);
      
      // Tanque 2
      combined['medicao_inicial_2'] = medIni2;
      combined['medicao_final_2'] = medFin2;
      combined['tanque_2'] = tanque2;
      combined['produto_2'] = produto2 ?? tankProdutoFromMap(tanque2);
      
      combined['terminal'] = terminal;
      combined['empresa'] = empresa;

      // Montar também um submap 'medicoes' compatível com o que o PDF espera
      final medicoes = <String, dynamic>{};
      
      // TANQUE 1 - Inicial
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
      
      // TANQUE 1 - Final
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

      // TANQUE 2 - Inicial
      if (medIni2 != null) {
        medicoes['cmInicial2'] = medIni2['altura_total_cm']?.toString();
        medicoes['mmInicial2'] = medIni2['altura_total_mm']?.toString();
        medicoes['volumeTotalLiquidoInicial2'] = medIni2['volume_total_liquido'] ?? medIni2['volume_ambiente'];
        medicoes['alturaAguaInicial2'] = medIni2['agua_cm']?.toString();
        medicoes['volumeAguaInicial2'] = medIni2['vol_agua'] ?? medIni2['vol_agua'];
        medicoes['alturaProdutoInicial2'] = (medIni2['altura_total_cm'] != null) ? ((medIni2['altura_total_cm'] - (medIni2['agua_cm'] ?? 0)).toString()) : null;
        medicoes['volumeProdutoInicial2'] = medIni2['volume_ambiente'] ?? medIni2['volume_total_liquido'];
        medicoes['tempTanqueInicial2'] = medIni2['temperatura_tanque']?.toString();
        medicoes['densidadeInicial2'] = medIni2['densidade_observada']?.toString();
        medicoes['tempAmostraInicial2'] = medIni2['temperatura_amostra']?.toString();
        medicoes['densidade20Inicial2'] = medIni2['densidade_20']?.toString();
        medicoes['fatorCorrecaoInicial2'] = medIni2['fcv']?.toString();
        medicoes['volume20Inicial2'] = medIni2['volume_20'];
        medicoes['massaInicial2'] = medIni2['massa'];
      }

      // TANQUE 2 - Final
      if (medFin2 != null) {
        medicoes['cmFinal2'] = medFin2['altura_total_cm']?.toString();
        medicoes['mmFinal2'] = medFin2['altura_total_mm']?.toString();
        medicoes['volumeTotalLiquidoFinal2'] = medFin2['volume_total_liquido'] ?? medFin2['volume_ambiente'];
        medicoes['alturaAguaFinal2'] = medFin2['agua_cm']?.toString();
        medicoes['volumeAguaFinal2'] = medFin2['vol_agua'] ?? medFin2['vol_agua'];
        medicoes['alturaProdutoFinal2'] = (medFin2['altura_total_cm'] != null) ? ((medFin2['altura_total_cm'] - (medFin2['agua_cm'] ?? 0)).toString()) : null;
        medicoes['volumeProdutoFinal2'] = medFin2['volume_ambiente'] ?? medFin2['volume_total_liquido'];
        medicoes['tempTanqueFinal2'] = medFin2['temperatura_tanque']?.toString();
        medicoes['densidadeFinal2'] = medFin2['densidade_observada']?.toString();
        medicoes['tempAmostraFinal2'] = medFin2['temperatura_amostra']?.toString();
        medicoes['densidade20Final2'] = medFin2['densidade_20']?.toString();
        medicoes['fatorCorrecaoFinal2'] = medFin2['fcv']?.toString();
        medicoes['volume20Final2'] = medFin2['volume_20'];
        medicoes['massaFinal2'] = medFin2['massa'];
      }

      // Totais combinados dos dois tanques
      final double volProdIni1 = (medIni != null) ? (medIni['volume_ambiente'] ?? medIni['volume_total_liquido'] ?? 0).toDouble() : 0;
      final double volProdFin1 = (medFin != null) ? (medFin['volume_ambiente'] ?? medFin['volume_total_liquido'] ?? 0).toDouble() : 0;
      final double volProdIni2 = (medIni2 != null) ? (medIni2['volume_ambiente'] ?? medIni2['volume_total_liquido'] ?? 0).toDouble() : 0;
      final double volProdFin2 = (medFin2 != null) ? (medFin2['volume_ambiente'] ?? medFin2['volume_total_liquido'] ?? 0).toDouble() : 0;
      
      final double vol20Ini1 = (medIni != null) ? (medIni['volume_20'] ?? 0).toDouble() : 0;
      final double vol20Fin1 = (medFin != null) ? (medFin['volume_20'] ?? 0).toDouble() : 0;
      final double vol20Ini2 = (medIni2 != null) ? (medIni2['volume_20'] ?? 0).toDouble() : 0;
      final double vol20Fin2 = (medFin2 != null) ? (medFin2['volume_20'] ?? 0).toDouble() : 0;
      
      medicoes['volumeProdutoInicialTotal'] = volProdIni1 + volProdIni2;
      medicoes['volumeProdutoFinalTotal'] = volProdFin1 + volProdFin2;
      medicoes['volume20InicialTotal'] = vol20Ini1 + vol20Ini2;
      medicoes['volume20FinalTotal'] = vol20Fin1 + vol20Fin2;
      
      combined['medicoes'] = medicoes;

      // Garantir que exista um campo 'qtd_faturada' — some quantidades_faturadas se necessário
      double totalFaturadoSum = 0.0;
      final rawFaturado = b['quantidades_faturadas'];
      if (rawFaturado != null) {
        try {
          if (rawFaturado is Map) {
            rawFaturado.forEach((k, v) {
              totalFaturadoSum += double.tryParse(v?.toString() ?? '0') ?? 0.0;
            });
          } else if (rawFaturado is String) {
            final parsed = jsonDecode(rawFaturado);
            if (parsed is Map) {
              parsed.forEach((k, v) {
                totalFaturadoSum += double.tryParse(v?.toString() ?? '0') ?? 0.0;
              });
            }
          } else if (rawFaturado is List) {
            for (var v in rawFaturado) {
              if (v is Map) {
                final double val = double.tryParse(v['faturado']?.toString() ?? v['quantidade']?.toString() ?? '0') ?? 0;
                totalFaturadoSum += val;
              }
            }
          }
        } catch (_) {}
      }
      combined['qtd_faturada'] = b['qtd_total_faturada'] ?? totalFaturadoSum;

      // 8) Finalmente abre o diálogo com dados completos
      if (!context.mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {}
        return;
      }

      try {
        Navigator.of(context, rootNavigator: true).pop();
      } catch (_) {}

      return show(context, bombeio: combined);
    } catch (e) {
      try {
        if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      } catch (_) {}

      if (!context.mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Erro'),
          content: Text('Erro ao carregar bombeio: $e'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))
          ],
        ),
      );
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

  TableRow _linhaMedicaoDupla(String descricao, String valorIni1, String valorFin1, String valorIni2, String valorFin2) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Text(descricao, style: const TextStyle(fontSize: 10)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Text(
            valorIni1,
            style: const TextStyle(fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Text(
            valorFin1,
            style: const TextStyle(fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Text(
            valorIni2,
            style: const TextStyle(fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Text(
            valorFin2,
            style: const TextStyle(fontSize: 10),
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
    final medicoes = Map<String, dynamic>.from(dados['medicoes'] ?? {});

    // Se não houver 'medicoes' tente construir a partir de medicao_inicial/final
    if (medicoes.isEmpty) {
      final medIni = dados['medicao_inicial'];
      final medFin = dados['medicao_final'];
      final medIni2 = dados['medicao_inicial_2'];
      final medFin2 = dados['medicao_final_2'];
      
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
      
      // TANQUE 2
      if (medIni2 is Map) {
        medicoes['cmInicial2'] = medIni2['altura_total_cm']?.toString();
        medicoes['mmInicial2'] = medIni2['altura_total_mm']?.toString();
        medicoes['volumeTotalLiquidoInicial2'] = medIni2['volume_total_liquido'] ?? medIni2['volume_ambiente'];
        medicoes['alturaAguaInicial2'] = medIni2['agua_cm']?.toString();
        medicoes['volumeAguaInicial2'] = medIni2['vol_agua'] ?? medIni2['vol_agua'];
        medicoes['alturaProdutoInicial2'] = (medIni2['altura_total_cm'] != null) ? ((medIni2['altura_total_cm'] - (medIni2['agua_cm'] ?? 0)).toString()) : null;
        medicoes['volumeProdutoInicial2'] = medIni2['volume_ambiente'] ?? medIni2['volume_total_liquido'];
        medicoes['tempTanqueInicial2'] = medIni2['temperatura_tanque']?.toString();
        medicoes['densidadeInicial2'] = medIni2['densidade_observada']?.toString();
        medicoes['tempAmostraInicial2'] = medIni2['temperatura_amostra']?.toString();
        medicoes['densidade20Inicial2'] = medIni2['densidade_20']?.toString();
        medicoes['fatorCorrecaoInicial2'] = medIni2['fcv']?.toString();
        medicoes['volume20Inicial2'] = medIni2['volume_20'];
        medicoes['massaInicial2'] = medIni2['massa'];
      }
      if (medFin2 is Map) {
        medicoes['cmFinal2'] = medFin2['altura_total_cm']?.toString();
        medicoes['mmFinal2'] = medFin2['altura_total_mm']?.toString();
        medicoes['volumeTotalLiquidoFinal2'] = medFin2['volume_total_liquido'] ?? medFin2['volume_ambiente'];
        medicoes['alturaAguaFinal2'] = medFin2['agua_cm']?.toString();
        medicoes['volumeAguaFinal2'] = medFin2['vol_agua'] ?? medFin2['vol_agua'];
        medicoes['alturaProdutoFinal2'] = (medFin2['altura_total_cm'] != null) ? ((medFin2['altura_total_cm'] - (medFin2['agua_cm'] ?? 0)).toString()) : null;
        medicoes['volumeProdutoFinal2'] = medFin2['volume_ambiente'] ?? medFin2['volume_total_liquido'];
        medicoes['tempTanqueFinal2'] = medFin2['temperatura_tanque']?.toString();
        medicoes['densidadeFinal2'] = medFin2['densidade_observada']?.toString();
        medicoes['tempAmostraFinal2'] = medFin2['temperatura_amostra']?.toString();
        medicoes['densidade20Final2'] = medFin2['densidade_20']?.toString();
        medicoes['fatorCorrecaoFinal2'] = medFin2['fcv']?.toString();
        medicoes['volume20Final2'] = medFin2['volume_20'];
        medicoes['massaFinal2'] = medFin2['massa'];
      }
      
      // Totais combinados
      final double volProdIni1 = (medIni is Map) ? (medIni['volume_ambiente'] ?? medIni['volume_total_liquido'] ?? 0).toDouble() : 0;
      final double volProdFin1 = (medFin is Map) ? (medFin['volume_ambiente'] ?? medFin['volume_total_liquido'] ?? 0).toDouble() : 0;
      final double volProdIni2 = (medIni2 is Map) ? (medIni2['volume_ambiente'] ?? medIni2['volume_total_liquido'] ?? 0).toDouble() : 0;
      final double volProdFin2 = (medFin2 is Map) ? (medFin2['volume_ambiente'] ?? medFin2['volume_total_liquido'] ?? 0).toDouble() : 0;
      
      final double vol20Ini1 = (medIni is Map) ? (medIni['volume_20'] ?? 0).toDouble() : 0;
      final double vol20Fin1 = (medFin is Map) ? (medFin['volume_20'] ?? 0).toDouble() : 0;
      final double vol20Ini2 = (medIni2 is Map) ? (medIni2['volume_20'] ?? 0).toDouble() : 0;
      final double vol20Fin2 = (medFin2 is Map) ? (medFin2['volume_20'] ?? 0).toDouble() : 0;
      
      medicoes['volumeProdutoInicialTotal'] = volProdIni1 + volProdIni2;
      medicoes['volumeProdutoFinalTotal'] = volProdFin1 + volProdFin2;
      medicoes['volume20InicialTotal'] = vol20Ini1 + vol20Ini2;
      medicoes['volume20FinalTotal'] = vol20Fin1 + vol20Fin2;
    }

    final data = _formatarDataDisplay(dados['data']?.toString() ?? '');
    final base = (dados['terminal'] is Map) ? (dados['terminal']['nome'] ?? dados['terminal']['referencia'])?.toString() : (dados['base']?.toString() ?? '');
    final produto = (dados['produto'] is Map) ? (dados['produto']['nome'] ?? dados['produto']['nome_dois'])?.toString() : (dados['produto']?.toString() ?? '');
    final produto2 = (dados['produto_2'] is Map) ? ((dados['produto_2']['nome'] ?? dados['produto_2']['nome_dois'])?.toString() ?? '') : (dados['produto_2']?.toString() ?? '');
    final tanque = (dados['tanque'] is Map) ? (dados['tanque']['referencia'] ?? dados['tanque']['id'])?.toString() : (dados['tanque']?.toString() ?? '');
    final tanque2 = (dados['tanque_2'] is Map) ? (dados['tanque_2']['referencia'] ?? dados['tanque_2']['id'])?.toString() : (dados['tanque_2']?.toString() ?? '');
    final horarioInicial = (dados['medicao_inicial'] is Map)
      ? (dados['medicao_inicial']['horario']?.toString() ?? '')
      : (dados['horario_inicial']?.toString() ?? '');
    final horarioFinal = (dados['medicao_final'] is Map)
      ? (dados['medicao_final']['horario']?.toString() ?? '')
      : (dados['horario_final']?.toString() ?? '');
    final horarioInicial2 = (dados['medicao_inicial_2'] is Map)
      ? (dados['medicao_inicial_2']['horario']?.toString() ?? '')
      : '';
    final horarioFinal2 = (dados['medicao_final_2'] is Map)
      ? (dados['medicao_final_2']['horario']?.toString() ?? '')
      : '';

    // TANQUE 1
    final volumeTotalInicial = (medicoes['volumeTotalLiquidoInicial'] ?? 0).toDouble();
    final volumeTotalFinal = (medicoes['volumeTotalLiquidoFinal'] ?? 0).toDouble();
    final volumeProdutoInicial = (medicoes['volumeProdutoInicial'] ?? 0).toDouble();
    final volumeProdutoFinal = (medicoes['volumeProdutoFinal'] ?? 0).toDouble();
    final volume20Inicial = (medicoes['volume20Inicial'] ?? 0).toDouble();
    final volume20Final = (medicoes['volume20Final'] ?? 0).toDouble();

    // TANQUE 2
    final volumeTotalInicial2 = (medicoes['volumeTotalLiquidoInicial2'] ?? 0).toDouble();
    final volumeTotalFinal2 = (medicoes['volumeTotalLiquidoFinal2'] ?? 0).toDouble();
    final volumeProdutoInicial2 = (medicoes['volumeProdutoInicial2'] ?? 0).toDouble();
    final volumeProdutoFinal2 = (medicoes['volumeProdutoFinal2'] ?? 0).toDouble();
    final volume20Inicial2 = (medicoes['volume20Inicial2'] ?? 0).toDouble();
    final volume20Final2 = (medicoes['volume20Final2'] ?? 0).toDouble();

    // Totais combinados
    final volumeProdutoInicialTotal = (medicoes['volumeProdutoInicialTotal'] ?? volumeProdutoInicial + volumeProdutoInicial2).toDouble();
    final volumeProdutoFinalTotal = (medicoes['volumeProdutoFinalTotal'] ?? volumeProdutoFinal + volumeProdutoFinal2).toDouble();
    final volume20InicialTotal = (medicoes['volume20InicialTotal'] ?? volume20Inicial + volume20Inicial2).toDouble();
    final volume20FinalTotal = (medicoes['volume20FinalTotal'] ?? volume20Final + volume20Final2).toDouble();

    // Vol. apurado a 20ºC deve ser a diferença entre as medições a 20ºC (soma dos dois tanques)
    final volApurado20 = (volume20FinalTotal - volume20InicialTotal);

    // O volume faturado vem do campo 'qtd_faturada' do bombeio
    final faturado = (dados['qtd_faturada'] ?? medicoes['faturadoFinal'] ?? 0).toDouble();

    // Sobra/Perda = Vol. apurado a 20ºC - Vol. faturado
    final sobraPerda = (volApurado20 - faturado);

    final estoqueFinalCalculado = (dados['estoque_final_calculado'] ?? 0).toDouble();

    // Verifica se tem segundo tanque (proteger contra null)
    final temTanque2 = (tanque2 != null && tanque2.isNotEmpty && tanque2 != '-');

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFF0D47A1), width: 1),
      ),
      contentPadding: const EdgeInsets.all(24),
      content: SizedBox(
        width: temTanque2 ? 900 : 670,
        height: 650,
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
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: temTanque2 ? 120 : 140,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Center(child: _secaoTitulo("DATA:")),
                          _linhaValor(data.isEmpty ? '-' : data),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: temTanque2 ? 100 : 120,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Center(child: _secaoTitulo("HORÁRIO:")),
                          _linhaValor(horarioInicial.isEmpty ? '-' : horarioInicial),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: temTanque2 ? 160 : 180,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Center(child: _secaoTitulo("TERMINAL:")),
                          _linhaValor(base ?? '-'),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: temTanque2 ? 140 : 160,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Center(child: _secaoTitulo("TANQUE 1:")),
                          _linhaValor(tanque ?? '-'),
                        ],
                      ),
                    ),
                    if (temTanque2)
                      SizedBox(
                        width: 140,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Center(child: _secaoTitulo("TANQUE 2:")),
                            _linhaValor(tanque2),
                          ],
                        ),
                      ),
                    SizedBox(
                      width: temTanque2 ? 180 : 200,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Center(child: _secaoTitulo("PRODUTO:")),
                          _linhaValor(produto ?? '-'),
                        ],
                      ),
                    ),
                    // Removido campo PRODUTO 2 — usar apenas PRODUTO (tanque 1)
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // SEÇÃO DE MEDIÇÕES
              _subtitulo("VOLUME RECEBIDO NOS TANQUES DE TERRA E CANALIZAÇÃO RESPECTIVA"),
              const SizedBox(height: 12),

              // Tabela com colunas para cada tanque
              Table(
                border: TableBorder.all(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                columnWidths: temTanque2 
                    ? const {
                        0: FlexColumnWidth(2.5),
                        1: FlexColumnWidth(1.0),
                        2: FlexColumnWidth(1.0),
                        3: FlexColumnWidth(1.0),
                        4: FlexColumnWidth(1.0),
                      }
                    : const {
                        0: FlexColumnWidth(3.0),
                        1: FlexColumnWidth(1.0),
                        2: FlexColumnWidth(1.0),
                      },
                children: [
                  // Cabeçalho
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey[200]),
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        child: Text(
                          "DESCRIÇÃO",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        child: Text(
                          "T1 INÍCIO\n$horarioInicial",
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        child: Text(
                          "T1 FINAL\n$horarioFinal",
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (temTanque2) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          child: Text(
                            "T2 INÍCIO\n$horarioInicial2",
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          child: Text(
                            "T2 FINAL\n$horarioFinal2",
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ],
                  ),
                  // Linhas de medição
                  if (temTanque2)
                    _linhaMedicaoDupla(
                      "Altura total de líquido:",
                      _formatarAlturaTotal(medicoes['cmInicial']?.toString(), medicoes['mmInicial']?.toString()),
                      _formatarAlturaTotal(medicoes['cmFinal']?.toString(), medicoes['mmFinal']?.toString()),
                      _formatarAlturaTotal(medicoes['cmInicial2']?.toString(), medicoes['mmInicial2']?.toString()),
                      _formatarAlturaTotal(medicoes['cmFinal2']?.toString(), medicoes['mmFinal2']?.toString()),
                    )
                  else
                    _linhaMedicaoDupla(
                      "Altura total de líquido:",
                      _formatarAlturaTotal(medicoes['cmInicial']?.toString(), medicoes['mmInicial']?.toString()),
                      _formatarAlturaTotal(medicoes['cmFinal']?.toString(), medicoes['mmFinal']?.toString()),
                      "-",
                      "-",
                    ),
                  if (temTanque2)
                    _linhaMedicaoDupla(
                      "Volume total líquido (amb.):",
                      _formatarVolumeLitros(volumeTotalInicial),
                      _formatarVolumeLitros(volumeTotalFinal),
                      _formatarVolumeLitros(volumeTotalInicial2),
                      _formatarVolumeLitros(volumeTotalFinal2),
                    )
                  else
                    _linhaMedicaoDupla(
                      "Volume total líquido (amb.):",
                      _formatarVolumeLitros(volumeTotalInicial),
                      _formatarVolumeLitros(volumeTotalFinal),
                      "-",
                      "-",
                    ),
                  if (temTanque2)
                    _linhaMedicaoDupla(
                      "Altura da água:",
                      _obterValorMedicao(medicoes['alturaAguaInicial']),
                      _obterValorMedicao(medicoes['alturaAguaFinal']),
                      _obterValorMedicao(medicoes['alturaAguaInicial2']),
                      _obterValorMedicao(medicoes['alturaAguaFinal2']),
                    )
                  else
                    _linhaMedicaoDupla(
                      "Altura da água:",
                      _obterValorMedicao(medicoes['alturaAguaInicial']),
                      _obterValorMedicao(medicoes['alturaAguaFinal']),
                      "-",
                      "-",
                    ),
                  if (temTanque2)
                    _linhaMedicaoDupla(
                      "Volume correspondente água:",
                      _obterValorMedicao(medicoes['volumeAguaInicial']),
                      _obterValorMedicao(medicoes['volumeAguaFinal']),
                      _obterValorMedicao(medicoes['volumeAguaInicial2']),
                      _obterValorMedicao(medicoes['volumeAguaFinal2']),
                    )
                  else
                    _linhaMedicaoDupla(
                      "Volume correspondente água:",
                      _obterValorMedicao(medicoes['volumeAguaInicial']),
                      _obterValorMedicao(medicoes['volumeAguaFinal']),
                      "-",
                      "-",
                    ),
                  if (temTanque2)
                    _linhaMedicaoDupla(
                      "Altura do produto:",
                      _obterValorMedicao(medicoes['alturaProdutoInicial']),
                      _obterValorMedicao(medicoes['alturaProdutoFinal']),
                      _obterValorMedicao(medicoes['alturaProdutoInicial2']),
                      _obterValorMedicao(medicoes['alturaProdutoFinal2']),
                    )
                  else
                    _linhaMedicaoDupla(
                      "Altura do produto:",
                      _obterValorMedicao(medicoes['alturaProdutoInicial']),
                      _obterValorMedicao(medicoes['alturaProdutoFinal']),
                      "-",
                      "-",
                    ),
                  if (temTanque2)
                    _linhaMedicaoDupla(
                      "Volume produto (amb.):",
                      _formatarVolumeLitros(volumeProdutoInicial),
                      _formatarVolumeLitros(volumeProdutoFinal),
                      _formatarVolumeLitros(volumeProdutoInicial2),
                      _formatarVolumeLitros(volumeProdutoFinal2),
                    )
                  else
                    _linhaMedicaoDupla(
                      "Volume produto (amb.):",
                      _formatarVolumeLitros(volumeProdutoInicial),
                      _formatarVolumeLitros(volumeProdutoFinal),
                      "-",
                      "-",
                    ),
                  if (temTanque2)
                    _linhaMedicaoDupla(
                      "Temperatura do produto:",
                      _formatarTemperatura(medicoes['tempTanqueInicial']),
                      _formatarTemperatura(medicoes['tempTanqueFinal']),
                      _formatarTemperatura(medicoes['tempTanqueInicial2']),
                      _formatarTemperatura(medicoes['tempTanqueFinal2']),
                    )
                  else
                    _linhaMedicaoDupla(
                      "Temperatura do produto:",
                      _formatarTemperatura(medicoes['tempTanqueInicial']),
                      _formatarTemperatura(medicoes['tempTanqueFinal']),
                      "-",
                      "-",
                    ),
                  if (temTanque2)
                    _linhaMedicaoDupla(
                      "Densidade observada:",
                      _obterValorMedicao(medicoes['densidadeInicial']),
                      _obterValorMedicao(medicoes['densidadeFinal']),
                      _obterValorMedicao(medicoes['densidadeInicial2']),
                      _obterValorMedicao(medicoes['densidadeFinal2']),
                    )
                  else
                    _linhaMedicaoDupla(
                      "Densidade observada:",
                      _obterValorMedicao(medicoes['densidadeInicial']),
                      _obterValorMedicao(medicoes['densidadeFinal']),
                      "-",
                      "-",
                    ),
                  if (temTanque2)
                    _linhaMedicaoDupla(
                      "Temp. da amostra:",
                      _formatarTemperatura(medicoes['tempAmostraInicial']),
                      _formatarTemperatura(medicoes['tempAmostraFinal']),
                      _formatarTemperatura(medicoes['tempAmostraInicial2']),
                      _formatarTemperatura(medicoes['tempAmostraFinal2']),
                    )
                  else
                    _linhaMedicaoDupla(
                      "Temp. da amostra:",
                      _formatarTemperatura(medicoes['tempAmostraInicial']),
                      _formatarTemperatura(medicoes['tempAmostraFinal']),
                      "-",
                      "-",
                    ),
                  if (temTanque2)
                    _linhaMedicaoDupla(
                      "Densidade a 20ºC:",
                      _obterValorMedicao(medicoes['densidade20Inicial']),
                      _obterValorMedicao(medicoes['densidade20Final']),
                      _obterValorMedicao(medicoes['densidade20Inicial2']),
                      _obterValorMedicao(medicoes['densidade20Final2']),
                    )
                  else
                    _linhaMedicaoDupla(
                      "Densidade a 20ºC:",
                      _obterValorMedicao(medicoes['densidade20Inicial']),
                      _obterValorMedicao(medicoes['densidade20Final']),
                      "-",
                      "-",
                    ),
                  if (temTanque2)
                    _linhaMedicaoDupla(
                      "Fator Correção (FCV):",
                      _obterValorMedicao(medicoes['fatorCorrecaoInicial']),
                      _obterValorMedicao(medicoes['fatorCorrecaoFinal']),
                      _obterValorMedicao(medicoes['fatorCorrecaoInicial2']),
                      _obterValorMedicao(medicoes['fatorCorrecaoFinal2']),
                    )
                  else
                    _linhaMedicaoDupla(
                      "Fator Correção (FCV):",
                      _obterValorMedicao(medicoes['fatorCorrecaoInicial']),
                      _obterValorMedicao(medicoes['fatorCorrecaoFinal']),
                      "-",
                      "-",
                    ),
                  if (temTanque2)
                    _linhaMedicaoDupla(
                      "Massa do produto:",
                      _obterValorMedicao(medicoes['massaInicial']),
                      _obterValorMedicao(medicoes['massaFinal']),
                      _obterValorMedicao(medicoes['massaInicial2']),
                      _obterValorMedicao(medicoes['massaFinal2']),
                    )
                  else
                    _linhaMedicaoDupla(
                      "Massa do produto:",
                      _obterValorMedicao(medicoes['massaInicial']),
                      _obterValorMedicao(medicoes['massaFinal']),
                      "-",
                      "-",
                    ),
                  if (temTanque2)
                    _linhaMedicaoDupla(
                      "Volume a 20ºC:",
                      _formatarVolumeLitros(volume20Inicial),
                      _formatarVolumeLitros(volume20Final),
                      _formatarVolumeLitros(volume20Inicial2),
                      _formatarVolumeLitros(volume20Final2),
                    )
                  else
                    _linhaMedicaoDupla(
                      "Volume a 20ºC:",
                      _formatarVolumeLitros(volume20Inicial),
                      _formatarVolumeLitros(volume20Final),
                      "-",
                      "-",
                    ),
                ],
              ),

              const SizedBox(height: 25),

              // COMPARAÇÃO DE RESULTADOS - TOTAIS COMBINADOS
              _subtitulo("COMPARAÇÃO DE RESULTADOS (TOTAIS COMBINADOS)"),
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
                  // Linha Volume Ambiente (Total)
                  TableRow(
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
                        child: Text("Volume ambiente (total)", style: TextStyle(fontSize: 10)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
                        child: Text(
                          _formatarVolumeLitros(volumeProdutoInicialTotal),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
                        child: Text(
                          _formatarVolumeLitros(volumeProdutoFinalTotal),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
                        child: Text(
                          _formatarVolumeLitros(volumeProdutoFinalTotal - volumeProdutoInicialTotal),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                  // Linha Volume a 20ºC (Total)
                  TableRow(
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
                        child: Text("Volume a 20 ºC (total)", style: TextStyle(fontSize: 10)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
                        child: Text(
                          _formatarVolumeLitros(volume20InicialTotal),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
                        child: Text(
                          _formatarVolumeLitros(volume20FinalTotal),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
                        child: Text(
                          _formatarVolumeLitros(volume20FinalTotal - volume20InicialTotal),
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
              Align(
                alignment: Alignment.centerRight,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black54),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Table(
                      columnWidths: const {0: FixedColumnWidth(140), 1: FixedColumnWidth(140)},
                      border: TableBorder.all(color: Colors.black54),
                      children: [
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
              final dadosParaPdf = Map<String, dynamic>.from(dados);
              dadosParaPdf['tanque'] = tanque ?? dadosParaPdf['tanque']?.toString();
              dadosParaPdf['tanque_2'] = tanque2 ?? dadosParaPdf['tanque_2']?.toString();
              dadosParaPdf['produto'] = produto;
              dadosParaPdf['produto_2'] = produto2;

              if (dadosParaPdf['terminal'] is Map) {
                final t = dadosParaPdf['terminal'] as Map<String, dynamic>;
                dadosParaPdf['terminal'] = (t['nome'] ?? t['referencia'] ?? t['nome_dois'])?.toString() ?? '';
              } else {
                dadosParaPdf['terminal'] = dadosParaPdf['terminal']?.toString() ?? '';
              }
              dadosParaPdf['numero_controle'] = dadosParaPdf['num_controle']?.toString() ?? dadosParaPdf['numero_controle']?.toString() ?? '';

              // Fecha o diálogo atual e navega para a página de pré-visualização
              Navigator.of(context).pop();
              await Future.delayed(Duration.zero);
              if (!context.mounted) return;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => CaclPdfDuploPage(dadosFormulario: dadosParaPdf),
                ),
              );
            } catch (e) {
              final errorText = 'Erro ao abrir pré-visualização do PDF:\n${e.toString()}';

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