import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_page.dart';
import '../../main.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dialog_inserir_bombeio.dart';
import '../operacao/rateio_payload.dart';
import '../operacao/cacl_bombeio.dart';

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

class _DetalhesBombeioPageState extends State<DetalhesBombeioPage>
    with RouteAware {
  final NumberFormat _fmt = NumberFormat.decimalPattern('pt_BR');
  bool? _rateioRealizado;
  late Map<String, dynamic> _bombeio;
  bool _isLoadingBombeio = false;
  String? _lastFetchId;

  UsuarioAtual? get user => UsuarioAtual.instance;

  bool get _isReadOnly => user?.empresaId?.isNotEmpty ?? false;

  // Helper seguro para extrair double de um mapa
  double _getDoubleSafe(Map<String, dynamic> map, String key, {double defaultValue = 0.0}) {
    final value = map[key];
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(',', '.')) ?? defaultValue;
    }
    return defaultValue;
  }

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

  @override
  void initState() {
    super.initState();
    _bombeio = Map<String, dynamic>.from(widget.bombeio);
    
    _verificarRateioExistente();
    // ensure we load fresh data (and trigger post-fetch debug prints)
    final id = _bombeio['id']?.toString() ?? _bombeio['bombeio_id']?.toString();
    if (id != null && id.isNotEmpty) {
      _carregarBombeioPorId(id);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route as ModalRoute<dynamic>);
    }
  }

  @override
  void dispose() {
    try {
      routeObserver.unsubscribe(this);
    } catch (_) {}
    super.dispose();
  }

  Future<void> _verificarRateioExistente() async {
    try {
      final supabase = Supabase.instance.client;
      final String? bombeioId =
          _bombeio['id']?.toString() ?? _bombeio['bombeio_id']?.toString();
      if (bombeioId?.isNotEmpty == true) {
        final bom = await supabase
            .from('bombeios')
            .select('rateio')
            .eq('id', bombeioId!)
            .maybeSingle();
        final exists = bom?['rateio'] == true;
        if (mounted) setState(() => _rateioRealizado = exists);
        return;
      }
      

      final String? tanqueId = _bombeio['tanque_id']?.toString();
      if (tanqueId?.isEmpty ?? true) {
        if (mounted) setState(() => _rateioRealizado = false);
        return;
      }

      final dynamic rawData = _bombeio['data'];
      DateTime dia;
      if (rawData is DateTime) {
        dia = rawData;
      } else {
        dia = DateTime.tryParse(rawData?.toString() ?? '') ?? DateTime.now();
      }
      final dataInicio = DateTime(dia.year, dia.month, dia.day);
      final dataFim = DateTime(dia.year, dia.month, dia.day, 23, 59, 59);

      final inicioIso = dataInicio.toIso8601String();
      final fimIso = dataFim.toIso8601String();

      final resp = await supabase
          .from('movimentacoes_tanque')
          .select('id')
          .eq('tanque_id', tanqueId!)
          .gte('data_mov', inicioIso)
          .lte('data_mov', fimIso)
          .limit(1);

      final exists = resp.isNotEmpty;
      if (mounted) setState(() => _rateioRealizado = exists);
    } catch (e) {
      debugPrint('Erro ao verificar rateio existente: $e');
    }
  }

  Future<void> _carregarBombeioPorId(dynamic id) async {
    if (id == null) return;
    // guard para evitar chamadas concorrentes/duplicadas
    _lastFetchId ??= '';
    if (_isLoadingBombeio == true && _lastFetchId == id.toString()) {
      return;
    }
    _isLoadingBombeio = true;
    _lastFetchId = id.toString();
    
    try {
      final supabase = Supabase.instance.client;
      final resp = await supabase
          .from('bombeios')
          .select('''
        id,
        rateio,
        num_controle,
        data,
        horario,
        medicao_inicial_id,
        medicao_final_id,
        volumes_solicitados,
        total_bombeio,
        tanque_id,
        qtd_total_faturada,
        quantidades_faturadas,
        tanques!bombeios_tanque_id_fkey (
          referencia,
          produto_id,
          produtos (
            nome
          )
        ),
        medicao_inicial:medicoes!bombeios_medicao_inicial_id_fkey (
          id,
          num_controle,
          data,
          horario,
          volume_ambiente,
          volume_20
        ),
        medicao_final:medicoes!bombeios_medicao_final_id_fkey (
          id,
          num_controle,
          data,
          horario,
          volume_ambiente,
          volume_20
        )
      ''')
          .eq('id', id)
          .maybeSingle();

      if (resp == null) return;
      
      final item = resp;
      // immediate post-fetch debug: show raw quantidades_faturadas value
      
      final tanquesArr = item['tanques!bombeios_tanque_id_fkey'] ?? item['tanques'];
      final tanques = tanquesArr is List
          ? (tanquesArr.isNotEmpty ? tanquesArr[0] : null)
          : tanquesArr;
      final produto = tanques?['produtos']?['nome'] ?? 'S/ Produto';
      final tanqueNome = tanques?['referencia'] ?? 'S/ Tanque';

      double totalSolicitado = 0;
      List<Map<String, dynamic>> participantes = [];
      final rawVols = item['volumes_solicitados'];
      if (rawVols != null) {
        if (rawVols is Map) {
          rawVols.forEach((key, value) {
            double sol = double.tryParse(value.toString()) ?? 0;
            totalSolicitado += sol;
            participantes.add({'nome': key?.toString() ?? '', 'solicitado': sol});
          });
        } else if (rawVols is List) {
          for (var v in rawVols) {
            if (v is Map) {
              double sol = double.tryParse(v['solicitado']?.toString() ?? '0') ?? 0;
              participantes.add({'nome': v['nome'] ?? '', 'solicitado': sol});
              totalSolicitado += sol;
            }
          }
        }
      }
      // parse quantidades_faturadas (jsonb) into Map<String,double>
      Map<String, double> quantidadesFaturadasMap = {};
      final rawFaturado = item['quantidades_faturadas'];
      if (rawFaturado != null) {
        try {
          if (rawFaturado is Map) {
            rawFaturado.forEach((k, v) {
              final double val = double.tryParse(v?.toString() ?? '0') ?? 0;
              if (val != 0) quantidadesFaturadasMap[k?.toString() ?? ''] = val;
            });
          } else if (rawFaturado is String) {
            final parsed = jsonDecode(rawFaturado);
            if (parsed is Map) {
              parsed.forEach((k, v) {
                final double val = double.tryParse(v?.toString() ?? '0') ?? 0;
                if (val != 0) quantidadesFaturadasMap[k?.toString() ?? ''] = val;
              });
            }
          } else if (rawFaturado is List) {
            for (var v in rawFaturado) {
              if (v is Map) {
                final nome = v['nome']?.toString() ?? '';
                final double val = double.tryParse(v['faturado']?.toString() ?? v['quantidade']?.toString() ?? '0') ?? 0;
                if (val != 0) quantidadesFaturadasMap[nome] = val;
              }
            }
          }
        } catch (e) {
          debugPrint('Erro ao parsear quantidades_faturadas: $e');
        }
      }

      final medFinalArr = item['medicao_final'];
      final medFinal = medFinalArr is List
          ? (medFinalArr.isNotEmpty ? medFinalArr[0] : null)
          : medFinalArr;
      final hFinal = medFinal?['horario']?.toString().substring(0, 5) ?? '--:--';

      final medIniArr = item['medicao_inicial'];
      final medIni = medIniArr is List
          ? (medIniArr.isNotEmpty ? medIniArr[0] : null)
          : medIniArr;

      double volAmbIni =
          double.tryParse(medIni?['volume_ambiente']?.toString() ?? '0') ?? 0;
      double vol20Ini =
          double.tryParse(medIni?['volume_20']?.toString() ?? '0') ?? 0;
      double volAmbFin =
          double.tryParse(medFinal?['volume_ambiente']?.toString() ?? '0') ?? 0;
      double vol20Fin =
          double.tryParse(medFinal?['volume_20']?.toString() ?? '0') ?? 0;

      double recebidoAmb = (volAmbFin > 0) ? (volAmbFin - volAmbIni) : 0;
      double recebido20 = (vol20Fin > 0) ? (vol20Fin - vol20Ini) : 0;

      final Map<String, dynamic> bombeioParaDetalhes = {
        'id': item['id'],
        'bombeio_id': item['id'],
        'rateio': item['rateio'],
        'tanque_id': item['tanque_id'],
        'data': DateTime.tryParse(item['data'] ?? '') ?? DateTime.now(),
        'produto': produto,
        'tanque': tanqueNome,
        'horario_inicial':
            item['horario']?.toString().substring(0, 5) ?? '--:--',
        'horario_final': hFinal,
        'numero_controle': item['num_controle'] ?? 'S/N',
        'status': '',
        'volume_total':
            double.tryParse(item['total_bombeio']?.toString() ?? '0') ?? 0,
        'volume_solicitado': totalSolicitado,
        'participantes': participantes,
        'quantidades_faturadas': quantidadesFaturadasMap,
        'recebido_amb': recebidoAmb,
        'recebido_20': recebido20,
        'qtd_total_faturada': item['qtd_total_faturada'],
        'medicao_inicial': medIni,
        'medicao_final': medFinal,
      };

      if (!mounted) return;
      setState(() {
        _bombeio = bombeioParaDetalhes;
      });
      await _verificarRateioExistente();
      
    } catch (e) {
      debugPrint('Erro ao recarregar bombeio: $e');
    }
    _isLoadingBombeio = false;
  }

  Future<void> _showMessageDialog(String message, {String? title}) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFF0D47A1), width: 1),
        ),
        child: SizedBox(
          width: 420,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 65, 54, 49),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  message,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      height: 40,
                      width: 140,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ButtonStyle(
                          backgroundColor:
                              WidgetStateProperty.resolveWith<Color?>((states) {
                                if (states.contains(WidgetState.hovered)) {
                                  return const Color.fromARGB(255, 65, 54, 49);
                                }
                                return Colors.black;
                              }),
                          foregroundColor: WidgetStateProperty.all<Color>(
                            Colors.white,
                          ),
                          padding: WidgetStateProperty.all(
                            const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 12,
                            ),
                          ),
                          shape: WidgetStateProperty.all(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          side: WidgetStateProperty.all(
                            const BorderSide(
                              color: Color(0xFFFFB341),
                              width: 1.6,
                            ),
                          ),
                          elevation: WidgetStateProperty.all(1),
                        ),
                        child: const Text(
                          'OK',
                          style: TextStyle(fontWeight: FontWeight.w700),
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
    );
  }

  Future<void> _showRateioAutomaticoDialog() async {
    final confirmado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFF0D47A1), width: 1),
        ),
        child: SizedBox(
          width: 480,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'Concluir com rateio automático?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color.fromARGB(255, 65, 54, 49),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      height: 40,
                      width: 140,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: ButtonStyle(
                          backgroundColor:
                              WidgetStateProperty.resolveWith<Color?>((states) {
                                if (states.contains(WidgetState.hovered)) {
                                  return const Color.fromARGB(255, 65, 54, 49);
                                }
                                return Colors.black;
                              }),
                          foregroundColor: WidgetStateProperty.all<Color>(
                            Colors.white,
                          ),
                          padding: WidgetStateProperty.all(
                            const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 12,
                            ),
                          ),
                          shape: WidgetStateProperty.all(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          side: WidgetStateProperty.all(
                            const BorderSide(
                              color: Color(0xFFFFB341),
                              width: 1.6,
                            ),
                          ),
                          elevation: WidgetStateProperty.all(1),
                        ),
                        child: const Text(
                          'Voltar',
                          style: TextStyle(fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 40,
                      width: 180,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ButtonStyle(
                          backgroundColor:
                              WidgetStateProperty.resolveWith<Color?>((states) {
                                if (states.contains(WidgetState.hovered)) {
                                  return const Color.fromARGB(255, 65, 54, 49);
                                }
                                return Colors.black;
                              }),
                          foregroundColor: WidgetStateProperty.all<Color>(
                            Colors.white,
                          ),
                          padding: WidgetStateProperty.all(
                            const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 12,
                            ),
                          ),
                          shape: WidgetStateProperty.all(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          side: WidgetStateProperty.all(
                            const BorderSide(
                              color: Color(0xFFFFB341),
                              width: 1.6,
                            ),
                          ),
                          elevation: WidgetStateProperty.all(1),
                        ),
                        child: const Text(
                          'Sim, realizar rateio',
                          style: TextStyle(fontWeight: FontWeight.w800),
                          overflow: TextOverflow.ellipsis,
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
    );

    if (confirmado == true) {
      // Mostrar diálogo de carregamento enquanto processa o rateio automático
      if (mounted) {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Dialog(
            backgroundColor: Colors.transparent,
            child: Center(child: CircularProgressIndicator()),
          ),
        );
      }
      try {
        final supabase = Supabase.instance.client;

        final String? tanqueId = _bombeio['tanque_id']?.toString();
        if (tanqueId?.isEmpty ?? true) {
          throw Exception('tanque_id ausente no bombeio');
        }

        String? produtoId = _bombeio['produto_id']?.toString();
        if (produtoId?.isEmpty ?? true) {
          final tanq = await supabase
              .from('tanques')
              .select('produto_id')
              .eq('id', tanqueId!)
              .maybeSingle();
          produtoId = tanq?['produto_id']?.toString();
        }

        final dataMov = _bombeio['data'] is DateTime
            ? (_bombeio['data'] as DateTime).toIso8601String()
            : (_bombeio['data']?.toString() ??
                  DateTime.now().toIso8601String());

        final recebidoAmb = _getDoubleSafe(_bombeio, 'recebido_amb');
        final recebido20 = _getDoubleSafe(_bombeio, 'recebido_20');

        final participantes = (_bombeio['participantes'] is List)
            ? List<Map<String, dynamic>>.from(_bombeio['participantes'])
            : <Map<String, dynamic>>[];

        double totalSolicitado = 0;
        for (var p in participantes) {
          totalSolicitado += _getDoubleSafe(p, 'solicitado');
        }

        final usuario = UsuarioAtual.instance;
        final terminalId = usuario?.terminalId;
        final bombeioId =
            _bombeio['id']?.toString() ?? _bombeio['bombeio_id']?.toString();

        final List<Map<String, dynamic>> inserts = [];

        for (var p in participantes) {
          final solicit = _getDoubleSafe(p, 'solicitado');
          final peso = totalSolicitado > 0 ? (solicit / totalSolicitado) : 0;
          final entradaAmb = (recebidoAmb * peso).round();
          final entradaVinte = (recebido20 * peso).round();

          String? empresaId;
          final nomeRaw = p['nome']?.toString() ?? '';
          final looksLikeUuid = nomeRaw.length == 36 && nomeRaw.contains('-');
          if (looksLikeUuid) {
            empresaId = nomeRaw;
          } else if (nomeRaw.isNotEmpty) {
            var emp = await supabase
                .from('empresas')
                .select('id')
                .eq('nome', nomeRaw)
                .maybeSingle();
            emp ??= await supabase
                .from('empresas')
                .select('id')
                .eq('nome_dois', nomeRaw)
                .maybeSingle();
            emp ??= await supabase
                .from('empresas')
                .select('id')
                .eq('nome_abrev', nomeRaw)
                .maybeSingle();
            empresaId = emp?['id']?.toString();
          }

          final row = buildRateioMovimentacaoRow(
            tanqueId: tanqueId,
            produtoId: produtoId,
            bombeioId: bombeioId,
            dataMov: dataMov,
            entradaAmb: entradaAmb,
            entradaVinte: entradaVinte,
            empresaId: empresaId,
            terminalId: terminalId,
          );

          inserts.add(row);
        }

        if (inserts.isNotEmpty) {
          int updatedCount = 0;
          for (var row in inserts) {
            try {
              final empresaId = row['empresa_id']?.toString();
              final entradaVinte = row['entrada_vinte'] as int? ?? 0;
              bool didUpdate = false;

              if (bombeioId?.isNotEmpty == true) {
                if (empresaId?.isNotEmpty == true) {
                  final resp = await supabase
                      .from('movimentacoes_tanque')
                      .update({'entrada_vinte': entradaVinte})
                      .eq('bombeio_id', bombeioId!)
                      .eq('empresa_id', empresaId!)
                      .select();
                  if (resp.isNotEmpty) {
                    didUpdate = true;
                    updatedCount += resp.length;
                  }
                } else {
                  final found = await supabase
                      .from('movimentacoes_tanque')
                      .select('id')
                      .eq('bombeio_id', bombeioId!)
                      .filter('empresa_id', 'is', 'null')
                      .limit(1);
                  if (found.isNotEmpty) {
                    final id = found[0]['id'];
                    final resp2 = await supabase
                        .from('movimentacoes_tanque')
                        .update({'entrada_vinte': entradaVinte})
                        .eq('id', id)
                        .select();
                    if (resp2.isNotEmpty) {
                      didUpdate = true;
                      updatedCount += resp2.length;
                    }
                  }
                }
              }

              if (!didUpdate) {
                debugPrint('Nenhuma movimentacao encontrada para atualizar (bombeio:${bombeioId}, empresa:${empresaId})');
              }
            } catch (e) {
              debugPrint('Erro ao atualizar movimentacoes_tanque: $e');
            }
          }

            if (updatedCount > 0) {
              if (bombeioId?.isNotEmpty == true) {
                try {
                  await supabase
                      .from('bombeios')
                      .update({'rateio': true})
                      .eq('id', bombeioId!);
                } catch (e) {
                  debugPrint('Erro ao marcar bombeio.rateio: $e');
                }
              }

              // Fechar spinner antes de mostrar o diálogo de sucesso
              try {
                if (mounted) Navigator.of(context, rootNavigator: true).pop();
              } catch (_) {}

              if (mounted) {
                setState(() => _rateioRealizado = true);
                await _showMessageDialog('Rateio automático realizado');
              }
            } else {
            if (mounted) {
              // Fechar spinner antes de mostrar aviso
              try {
                if (mounted) Navigator.of(context, rootNavigator: true).pop();
              } catch (_) {}

              await _showMessageDialog(
                'Nenhum participante para atualizar',
                title: 'Aviso',
              );
            }
          }
          } else {
            if (mounted) {
              // Fechar spinner antes de mostrar aviso
              try {
                if (mounted) Navigator.of(context, rootNavigator: true).pop();
              } catch (_) {}

              await _showMessageDialog(
                'Nenhum participante para inserir',
                title: 'Aviso',
              );
            }
          }
      } catch (e) {
        // Fechar spinner em caso de erro
        try {
          if (mounted) Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {}

        if (mounted) {
          await _showMessageDialog('Erro ao inserir rateio: $e', title: 'Erro');
        }
      }
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
    Map<String, dynamic> medicao,
    String label,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 0.5),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 55,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.straighten, size: 14, color: color),
                const SizedBox(height: 2),
                Text(
                  label.replaceFirst('MEDIÇÃO ', ''),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: color,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(height: 24, width: 1, color: color.withOpacity(0.2)),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _buildInfoColumn(
                    'Controle',
                    medicao['num_controle'] ?? '-',
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: _buildInfoColumn(
                    'Data',
                    _formatarDataIso(medicao['data']),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: _buildInfoColumn(
                    'Horário',
                    _formatarHorario(medicao['horario']),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: _buildInfoColumn(
                    'Vol. Amb.',
                    '${_fmt.format((medicao['volume_ambiente'] as num?)?.toInt() ?? 0)} L',
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: _buildInfoColumn(
                    'Vol. 20ºC',
                    '${_fmt.format((medicao['volume_20'] as num?)?.toInt() ?? 0)} L',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderMicroItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0D47A1),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Extração segura dos valores
    final double totalSolicitado = _getDoubleSafe(_bombeio, 'volume_solicitado');
    final double recebidoAmb = _getDoubleSafe(_bombeio, 'recebido_amb');
    final double recebido20 = _getDoubleSafe(_bombeio, 'recebido_20');
    
    final List<Map<String, dynamic>> participantes =
        List<Map<String, dynamic>>.from(_bombeio['participantes'] ?? []);

    participantes.sort(
      (a, b) =>
          (_getDoubleSafe(b, 'solicitado')).compareTo(_getDoubleSafe(a, 'solicitado')),
    );

    // compute totals for the table (used by totals row and percent column)
    double totalFaturado = 0;
    final qmapGlobal = _bombeio['quantidades_faturadas'];
    for (var p in participantes) {
      // faturado lookup
      double faturadoTmp = 0;
      final nomeKeyTmp = p['nome']?.toString() ?? '';
      if (qmapGlobal is Map) {
        if (qmapGlobal.containsKey(nomeKeyTmp)) {
          faturadoTmp = double.tryParse(qmapGlobal[nomeKeyTmp]?.toString() ?? '0') ?? 0;
        } else {
          for (var k in qmapGlobal.keys) {
            if (k.toString().toLowerCase() == nomeKeyTmp.toLowerCase()) {
              faturadoTmp = double.tryParse(qmapGlobal[k]?.toString() ?? '0') ?? 0;
              break;
            }
          }
        }
      }
      totalFaturado += faturadoTmp;
    }

    // calcular total de sobra/perda (rec20Part - faturado) por participante
    double totalSobraPerda = 0;
    for (var p in participantes) {
      final solicitado = _getDoubleSafe(p, 'solicitado');
      double peso = totalSolicitado > 0 ? (solicitado / totalSolicitado) : 0;
      double rec20Part = recebido20 * peso;

      double faturadoVal = 0;
      final qmap = _bombeio['quantidades_faturadas'];
      final nomeKey = p['nome']?.toString() ?? '';
      if (qmap is Map) {
        if (qmap.containsKey(nomeKey)) {
          faturadoVal = double.tryParse(qmap[nomeKey]?.toString() ?? '0') ?? 0;
        } else {
          for (var k in qmap.keys) {
            if (k.toString() == nomeKey) {
              faturadoVal = double.tryParse(qmap[k]?.toString() ?? '0') ?? 0;
              break;
            }
            if (faturadoVal == 0 && k.toString().toLowerCase() == nomeKey.toLowerCase()) {
              faturadoVal = double.tryParse(qmap[k]?.toString() ?? '0') ?? 0;
              break;
            }
          }
        }
      }
      final sobra = rec20Part - faturadoVal;
      if (faturadoVal > 0) totalSobraPerda += sobra;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'DETALHES DO BOMBEIO',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0D47A1),
            letterSpacing: 1.2,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
          onPressed: widget.onVoltar,
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const Divider(height: 1),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 80, 10),
            color: const Color(0xFFFBFBFB),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildHeaderMicroItem('CONTROLE', _bombeio['numero_controle']?.toString() ?? '-'),
                _buildHeaderMicroItem('PRODUTO', _bombeio['produto']?.toString() ?? '-'),
                _buildHeaderMicroItem('DATA', _formatarData(_bombeio['data'])),
                _buildHeaderMicroItem(
                  'HORÁRIO',
                  '${_bombeio['horario_inicial'] ?? '-'} - ${_bombeio['horario_final'] ?? '-'}',
                ),
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
                  const Text(
                    'Medições',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D47A1),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_bombeio['medicao_inicial'] != null)
                    _buildMedicaoDisplay(
                      _bombeio['medicao_inicial'],
                      'MEDIÇÃO INICIAL',
                      const Color(0xFF0D47A1),
                    ),
                  if (_bombeio['medicao_inicial'] != null)
                    const SizedBox(height: 8),
                  if (_bombeio['medicao_final'] != null)
                    _buildMedicaoDisplay(
                      _bombeio['medicao_final'],
                      'MEDIÇÃO FINAL',
                      Colors.green.shade700,
                    ),
                  const SizedBox(height: 80),

                  const Center(
                    child: Text(
                      'DISTRIBUIÇÃO E RATEIO',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D47A1),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Text(
                                    'TOTAL SOLICITADO',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_fmt.format(totalSolicitado.toInt())} L',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF455A64),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'TOTAL RECEBIDO (AMB)',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_fmt.format(recebidoAmb.toInt())} L',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF0D47A1),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'TOTAL RECEBIDO (20ºC)',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_fmt.format(recebido20.toInt())} L',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF388E3C),
                                    ),
                                  ),
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
                                    sections: List.generate(
                                      participantes.length,
                                      (i) {
                                        final p = participantes[i];
                                        final colors = [
                                          const Color(0xFF0D47A1),
                                          const Color(0xFFD32F2F),
                                          const Color(0xFF388E3C),
                                          const Color(0xFFFBC02D),
                                        ];
                                        final solicitado = _getDoubleSafe(p, 'solicitado');
                                        return PieChartSectionData(
                                          color: colors[i % colors.length],
                                          value: solicitado,
                                          title:
                                              '${p['nome'].toString().split(' ')[0]}\n${totalSolicitado > 0 ? ((solicitado / totalSolicitado) * 100).toStringAsFixed(0) : '0'}%',
                                          radius: 50,
                                          titleStyle: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            shadows: [
                                              Shadow(
                                                color: Colors.black45,
                                                blurRadius: 2,
                                              ),
                                            ],
                                          ),
                                          titlePositionPercentageOffset: 0.55,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(width: 40),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'DISTRIBUIDORA',
                                      textAlign: TextAlign.left,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      'Qtd. solicitada',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'RECEB. (AMB)',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'RECEB. (20ºC)',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'FATURADO',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      '%',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'SOBRA/PERDA',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            ...participantes.asMap().entries.map((entry) {
                              final index = entry.key;
                              final p = entry.value;
                              final solicitado = _getDoubleSafe(p, 'solicitado');
                              double peso = totalSolicitado > 0
                                  ? (solicitado / totalSolicitado)
                                  : 0;
                              double recAmbPart = recebidoAmb * peso;
                              double rec20Part = recebido20 * peso;

                              final colors = [
                                const Color(0xFF0D47A1),
                                const Color(0xFFD32F2F),
                                const Color(0xFF388E3C),
                                const Color(0xFFFBC02D),
                              ];

                              return Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    child: Row(
                                      children: [
                                          Expanded(
                                            flex: 2,
                                            child: Row(
                                            children: [
                                              Container(
                                                width: 8,
                                                height: 8,
                                                margin: const EdgeInsets.only(
                                                  right: 12,
                                                ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      colors[index %
                                                          colors.length],
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      p['nome']
                                                          .toString()
                                                          .toUpperCase(),
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Color(
                                                          0xFF263238,
                                                        ),
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 6),
                                                    ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            2,
                                                          ),
                                                      child: LinearProgressIndicator(
                                                        value: peso,
                                                        backgroundColor:
                                                            Colors.grey[100],
                                                        valueColor:
                                                            AlwaysStoppedAnimation<
                                                              Color
                                                            >(
                                                              colors[index %
                                                                  colors
                                                                      .length],
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
                                            '${_fmt.format(solicitado.toInt())} L',
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
                                              color:
                                                  colors[index % colors.length],
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Builder(builder: (context) {
                                            double faturadoVal = 0;
                                            final qmap = _bombeio['quantidades_faturadas'];
                                            final nomeKey = p['nome']?.toString() ?? '';
                                            if (qmap is Map) {
                                              if (qmap.containsKey(nomeKey)) {
                                                faturadoVal = double.tryParse(qmap[nomeKey]?.toString() ?? '0') ?? 0;
                                              } else {
                                                for (var k in qmap.keys) {
                                                  if (k.toString() == nomeKey) {
                                                    faturadoVal = double.tryParse(qmap[k]?.toString() ?? '0') ?? 0;
                                                    break;
                                                  }
                                                }
                                              }
                                            }
                                            final sobraTotal = recebido20 - totalFaturado;
                                            final perc = (totalFaturado > 0) ? (faturadoVal / totalFaturado) : 0;
                                            final sobra = (sobraTotal * perc).roundToDouble();
                                            final exibido = (faturadoVal + sobra).roundToDouble();
                                            return Text(
                                              faturadoVal > 0 ? '${_fmt.format(exibido.toInt())} L' : '-',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w900,
                                                color: colors[index % colors.length],
                                              ),
                                            );
                                          }),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Builder(builder: (context) {
                                            double faturadoVal = 0;
                                            final qmap = _bombeio['quantidades_faturadas'];
                                            final nomeKey = p['nome']?.toString() ?? '';
                                            // lookup quantidades_faturadas for this participante
                                            if (qmap is Map) {
                                              // direct key
                                              if (qmap.containsKey(nomeKey)) {
                                                faturadoVal = double.tryParse(qmap[nomeKey]?.toString() ?? '0') ?? 0;
                                              } else {
                                                // try exact string keys
                                                for (var k in qmap.keys) {
                                                    if (k.toString() == nomeKey) {
                                                    faturadoVal = double.tryParse(qmap[k]?.toString() ?? '0') ?? 0;
                                                    break;
                                                  }
                                                }
                                                // try case-insensitive
                                                if (faturadoVal == 0) {
                                                  for (var k in qmap.keys) {
                                                    if (k.toString().toLowerCase() == nomeKey.toLowerCase()) {
                                                      faturadoVal = double.tryParse(qmap[k]?.toString() ?? '0') ?? 0;
                                                      break;
                                                    }
                                                  }
                                                }
                                                // try numeric keys (id) mapping
                                                if (faturadoVal == 0) {
                                                  for (var k in qmap.keys) {
                                                    final ks = k.toString();
                                                    if (ks.length == 36 && ks.contains('-')) {
                                                      // possible uuid-like key found; value available in qmap[k]
                                                    }
                                                  }
                                                }
                                              }
                                            }
                                            
                                            return Text(
                                              faturadoVal > 0 ? '${_fmt.format(faturadoVal.toInt())} L' : '-',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF455A64),
                                              ),
                                            );
                                          }),
                                        ),
                                        // percentual sobre total faturado
                                        Expanded(
                                          flex: 1,
                                          child: Builder(builder: (context) {
                                            double faturadoVal = 0;
                                            final qmap = _bombeio['quantidades_faturadas'];
                                            final nomeKey = p['nome']?.toString() ?? '';
                                            if (qmap is Map) {
                                              if (qmap.containsKey(nomeKey)) {
                                                faturadoVal = double.tryParse(qmap[nomeKey]?.toString() ?? '0') ?? 0;
                                              } else {
                                                for (var k in qmap.keys) {
                                                  if (k.toString() == nomeKey) {
                                                    faturadoVal = double.tryParse(qmap[k]?.toString() ?? '0') ?? 0;
                                                    break;
                                                  }
                                                }
                                              }
                                            }
                                            final perc = totalFaturado > 0 ? ((faturadoVal / totalFaturado) * 100) : 0;
                                            return Text(
                                              faturadoVal > 0 ? '${perc.toStringAsFixed(1)}%' : '-',
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF455A64),
                                              ),
                                            );
                                          }),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Builder(builder: (context) {
                                            double faturadoVal = 0;
                                            final qmap = _bombeio['quantidades_faturadas'];
                                            final nomeKey = p['nome']?.toString() ?? '';
                                            if (qmap is Map) {
                                              if (qmap.containsKey(nomeKey)) {
                                                faturadoVal = double.tryParse(qmap[nomeKey]?.toString() ?? '0') ?? 0;
                                              } else {
                                                for (var k in qmap.keys) {
                                                  if (k.toString() == nomeKey) {
                                                    faturadoVal = double.tryParse(qmap[k]?.toString() ?? '0') ?? 0;
                                                    break;
                                                  }
                                                }
                                              }
                                            }
                                            // nova lógica: sobra total = recebido20 - totalFaturado
                                            final sobraTotal = recebido20 - totalFaturado;
                                            final perc = (totalFaturado > 0) ? (faturadoVal / totalFaturado) : 0;
                                            final sobra = (sobraTotal * perc).roundToDouble();
                                            final sobraColor = sobra < 0 ? Colors.red : Colors.green[700];
                                            return Text(
                                              faturadoVal > 0 ? '${_fmt.format(sobra.toInt())} L' : '-',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: sobraColor,
                                              ),
                                            );
                                          }),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Divider(height: 1),
                                ],
                              );
                            }),

                            const Divider(height: 2, thickness: 1, color: Colors.black),

                            const SizedBox(height: 10),
                            // Totals row
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                children: [
                                  const Expanded(
                                    flex: 2,
                                    child: Text(
                                      'TOTAL',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF263238),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      '${_fmt.format(totalSolicitado.toInt())} L',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF455A64),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      '${_fmt.format(recebidoAmb.toInt())} L',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF0D47A1),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      '${_fmt.format(recebido20.toInt())} L',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF388E3C),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      '${_fmt.format(totalFaturado.toInt())} L',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF455A64),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      totalFaturado > 0 ? '100%' : '-',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF455A64),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      totalSobraPerda != 0 ? '${_fmt.format(totalSobraPerda.toInt())} L' : '-',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.green[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Espaço de 50px entre a linha de totalizadores e os botões
                            const SizedBox(height: 50),
                            // Botões de comando
                            if (_rateioRealizado == null)
                              const Center(
                                child: SizedBox(width: 200, height: 40),
                              )
                            else if (_rateioRealizado == true)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    height: 40,
                                    width: 200,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: const Color(0xFFFFB341),
                                        width: 1.6,
                                      ),
                                    ),
                                    child: const Text(
                                      'Rateio realizado',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: Color.fromARGB(255, 65, 54, 49),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 150,
                                    height: 40,
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        final id = _bombeio['id']?.toString();
                                        if (id == null || id.isEmpty) return;
                                        await CaclBombeioDialog.showById(context, id);
                                      },
                                      icon: const Icon(Icons.calculate, size: 18),
                                      label: const Text('CACL'),
                                      style: ButtonStyle(
                                        backgroundColor:
                                            WidgetStateProperty.all<Color>(
                                              Colors.blue[50]!,
                                            ),
                                        foregroundColor:
                                            WidgetStateProperty.all<Color>(
                                              const Color(0xFF0D47A1),
                                            ),
                                        padding: WidgetStateProperty.all(
                                          const EdgeInsets.symmetric(
                                            vertical: 8,
                                            horizontal: 12,
                                          ),
                                        ),
                                        shape: WidgetStateProperty.all(
                                          RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(6),
                                            side: const BorderSide(
                                              color: Color(0xFF0D47A1),
                                              width: 1.2,
                                            ),
                                          ),
                                        ),
                                        elevation: WidgetStateProperty.all(0),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 150,
                                    height: 40,
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        try {
                                          final result = await DialogInserirBombeio.show(
                                            context,
                                            bombeio: _bombeio,
                                          );
                                          if (result is Map<String, dynamic>) {
                                            final id = result['id'] ?? result['bombeio_id'];
                                            if (id != null) {
                                              await _carregarBombeioPorId(id);
                                            } else if (mounted) {
                                              setState(() {
                                                _bombeio = Map<String, dynamic>.from(result);
                                                _rateioRealizado = result['rateio'] == true;
                                              });
                                            }
                                          }
                                        } catch (e) {
                                          await _showMessageDialog('Erro ao abrir editor: $e', title: 'Erro');
                                        }
                                      },
                                      icon: const Icon(Icons.edit, size: 18),
                                      label: const Text('Editar bombeio'),
                                      style: ButtonStyle(
                                        backgroundColor:
                                            WidgetStateProperty.all<Color>(
                                              Colors.orange[50]!,
                                            ),
                                        foregroundColor:
                                            WidgetStateProperty.all<Color>(
                                              const Color(0xFFE65100),
                                            ),
                                        padding: WidgetStateProperty.all(
                                          const EdgeInsets.symmetric(
                                            vertical: 8,
                                            horizontal: 12,
                                          ),
                                        ),
                                        shape: WidgetStateProperty.all(
                                          RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(6),
                                            side: const BorderSide(
                                              color: Color(0xFFE65100),
                                              width: 1.2,
                                            ),
                                          ),
                                        ),
                                        elevation: WidgetStateProperty.all(0),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else if (!_isReadOnly)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 180,
                                    height: 40,
                                    child: ElevatedButton(
                                      onPressed: () =>
                                          _showRateioAutomaticoDialog(),
                                      style: ButtonStyle(
                                        backgroundColor:
                                            WidgetStateProperty.resolveWith<
                                              Color?
                                            >((states) {
                                              if (states.contains(
                                                WidgetState.hovered,
                                              )) {
                                                return const Color.fromARGB(
                                                  255,
                                                  65,
                                                  54,
                                                  49,
                                                );
                                              }
                                              return Colors.black;
                                            }),
                                        foregroundColor:
                                            WidgetStateProperty.all<Color>(
                                              Colors.white,
                                            ),
                                        padding: WidgetStateProperty.all(
                                          const EdgeInsets.symmetric(
                                            vertical: 8,
                                            horizontal: 12,
                                          ),
                                        ),
                                        shape: WidgetStateProperty.all(
                                          RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                        ),
                                        side: WidgetStateProperty.all(
                                          const BorderSide(
                                            color: Color(0xFFFFBD59),
                                            width: 1.6,
                                          ),
                                        ),
                                        elevation: WidgetStateProperty.all(1),
                                      ),
                                      child: const Text(
                                        'RATEIO AUTOMÁTICO',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 180,
                                    height: 40,
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        await _showMessageDialog(
                                          'Não disponível',
                                        );
                                      },
                                      style: ButtonStyle(
                                        backgroundColor:
                                            WidgetStateProperty.resolveWith<
                                              Color?
                                            >((states) {
                                              if (states.contains(
                                                WidgetState.hovered,
                                              )) {
                                                return const Color.fromARGB(
                                                  255,
                                                  65,
                                                  54,
                                                  49,
                                                );
                                              }
                                              return Colors.black;
                                            }),
                                        foregroundColor:
                                            WidgetStateProperty.all<Color>(
                                              Colors.white,
                                            ),
                                        padding: WidgetStateProperty.all(
                                          const EdgeInsets.symmetric(
                                            vertical: 8,
                                            horizontal: 12,
                                          ),
                                        ),
                                        shape: WidgetStateProperty.all(
                                          RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                        ),
                                        side: WidgetStateProperty.all(
                                          const BorderSide(
                                            color: Color.fromARGB(
                                              255,
                                              255,
                                              179,
                                              65,
                                            ),
                                            width: 1.6,
                                          ),
                                        ),
                                        elevation: WidgetStateProperty.all(1),
                                      ),
                                      child: const Text(
                                        'RATEIO MANUAL',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 150,
                                    height: 40,
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        final id = _bombeio['id']?.toString();
                                        if (id == null || id.isEmpty) return;
                                        await CaclBombeioDialog.showById(context, id);
                                      },
                                      icon: const Icon(Icons.calculate, size: 18),
                                      label: const Text('CACL'),
                                      style: ButtonStyle(
                                        backgroundColor:
                                            WidgetStateProperty.all<Color>(
                                              Colors.blue[50]!,
                                            ),
                                        foregroundColor:
                                            WidgetStateProperty.all<Color>(
                                              const Color(0xFF0D47A1),
                                            ),
                                        padding: WidgetStateProperty.all(
                                          const EdgeInsets.symmetric(
                                            vertical: 8,
                                            horizontal: 12,
                                          ),
                                        ),
                                        shape: WidgetStateProperty.all(
                                          RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(6),
                                            side: const BorderSide(
                                              color: Color(0xFF0D47A1),
                                              width: 1.2,
                                            ),
                                          ),
                                        ),
                                        elevation: WidgetStateProperty.all(0),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 150,
                                    height: 40,
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        try {
                                          final result = await DialogInserirBombeio.show(
                                            context,
                                            bombeio: _bombeio,
                                          );
                                          if (result is Map<String, dynamic>) {
                                            final id = result['id'] ?? result['bombeio_id'];
                                            if (id != null) {
                                              await _carregarBombeioPorId(id);
                                            } else if (mounted) {
                                              setState(() {
                                                _bombeio = Map<String, dynamic>.from(result);
                                                _rateioRealizado = result['rateio'] == true;
                                              });
                                            }
                                          }
                                        } catch (e) {
                                          await _showMessageDialog('Erro ao abrir editor: $e', title: 'Erro');
                                        }
                                      },
                                      icon: const Icon(Icons.edit, size: 18),
                                      label: const Text('Editar bombeio'),
                                      style: ButtonStyle(
                                        backgroundColor:
                                            WidgetStateProperty.all<Color>(
                                              Colors.orange[50]!,
                                            ),
                                        foregroundColor:
                                            WidgetStateProperty.all<Color>(
                                              const Color(0xFFE65100),
                                            ),
                                        padding: WidgetStateProperty.all(
                                          const EdgeInsets.symmetric(
                                            vertical: 8,
                                            horizontal: 12,
                                          ),
                                        ),
                                        shape: WidgetStateProperty.all(
                                          RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(6),
                                            side: const BorderSide(
                                              color: Color(0xFFE65100),
                                              width: 1.2,
                                            ),
                                          ),
                                        ),
                                        elevation: WidgetStateProperty.all(0),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 16),
                          ],
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
    );
  }
}