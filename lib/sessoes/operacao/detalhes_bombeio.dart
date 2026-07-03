import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_page.dart';
import '../../main.dart';
import 'package:fl_chart/fl_chart.dart';
import 'rateio_payload.dart';
import 'cacl_bombeio.dart';

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

  UsuarioAtual? get user => UsuarioAtual.instance;

  bool get _isReadOnly => user?.empresaId?.isNotEmpty ?? false;

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
    // mantém uma cópia local que podemos atualizar ao retornar para a rota
    _bombeio = Map<String, dynamic>.from(widget.bombeio);
    _verificarRateioExistente();
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

  @override
  void didPopNext() {
    // Voltou para esta página — recarrega informações do bombeio
    _reloadBombeio();
  }

  Future<void> _reloadBombeio() async {
    try {
      final supabase = Supabase.instance.client;
        final String? bombeioId =
          _bombeio['id']?.toString() ?? _bombeio['bombeio_id']?.toString();
        if (bombeioId?.isEmpty ?? true) return;

      final resp = await supabase
          .from('bombeios')
          .select('''
        id,
        num_controle,
        data,
        horario,
        medicao_inicial_id,
        medicao_final_id,
        volumes_solicitados,
        total_bombeio,
        tanque_id,
        qtd_faturada,
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
        ),
        rateio
      ''')
          .eq('id', bombeioId!)
          .maybeSingle();

      if (resp == null) return;

      // Reconstrói mapa local similar ao que o parent monta
      final tanquesArr =
          resp['tanques!bombeios_tanque_id_fkey'] ?? resp['tanques'];
      final tanques = tanquesArr is List
          ? (tanquesArr.isNotEmpty ? tanquesArr[0] : null)
          : tanquesArr;
      final produto = tanques?['produtos']?['nome'] ?? 'S/ Produto';
      final tanqueNome = tanques?['referencia'] ?? 'S/ Tanque';

      double totalSolicitado = 0;
      List<Map<String, dynamic>> participantes = [];
      final rawVols = resp['volumes_solicitados'];
      if (rawVols != null) {
        if (rawVols is Map) {
          rawVols.forEach((key, value) {
            double sol = double.tryParse(value.toString()) ?? 0;
            totalSolicitado += sol;
            participantes.add({
              'nome': key?.toString() ?? '',
              'solicitado': sol,
            });
          });
        } else if (rawVols is List) {
          for (var v in rawVols) {
            if (v is Map) {
              double sol =
                  double.tryParse(v['solicitado']?.toString() ?? '0') ?? 0;
              participantes.add({'nome': v['nome'] ?? '', 'solicitado': sol});
              totalSolicitado += sol;
            }
          }
        }
      }

      final medFinalArr = resp['medicao_final'];
      final medFinal = medFinalArr is List
          ? (medFinalArr.isNotEmpty ? medFinalArr[0] : null)
          : medFinalArr;
      final medIniArr = resp['medicao_inicial'];
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

      final novo = {
        'id': resp['id'],
        'tanque_id': resp['tanque_id'],
        'data': DateTime.tryParse(resp['data'] ?? '') ?? DateTime.now(),
        'produto': produto,
        'tanque': tanqueNome,
        'horario_inicial':
            resp['horario']?.toString().substring(0, 5) ?? '--:--',
        'horario_final':
            medFinal?['horario']?.toString().substring(0, 5) ?? '--:--',
        'numero_controle': resp['num_controle'] ?? 'S/N',
        'volume_total':
            double.tryParse(resp['total_bombeio']?.toString() ?? '0') ?? 0,
        'volume_solicitado': totalSolicitado,
        'participantes': participantes,
        'recebido_amb': recebidoAmb,
        'recebido_20': recebido20,
        'qtd_faturada': resp['qtd_faturada'],
        'medicao_inicial': medIni,
        'medicao_final': medFinal,
        'rateio': resp['rateio'],
      };

      if (mounted) {
        setState(() {
          _bombeio = novo;
        });
        // também atualiza flag de rateio
        await _verificarRateioExistente();
      }
    } catch (e) {
      debugPrint('Erro ao recarregar bombeio: $e');
    }
  }

  Future<void> _verificarRateioExistente() async {
    try {
      final supabase = Supabase.instance.client;
      // Preferência: verificar pelo próprio bombeio — se existir campo `rateio` não-nulo,
      // considera-se rateio realizado.
      final String? bombeioId =
          _bombeio['id']?.toString() ?? _bombeio['bombeio_id']?.toString();
      if (bombeioId?.isNotEmpty == true) {
        final bom = await supabase
            .from('bombeios')
            .select('rateio')
            .eq('id', bombeioId!)
            .maybeSingle();
        // Considera rateio realizado apenas se o valor for estritamente boolean true
        final exists = bom?['rateio'] == true;
        if (mounted) setState(() => _rateioRealizado = exists);
        return;
      }

      // Fallback (compatibilidade): caso não haja id do bombeio, verifica por tanque+data
      final String? tanqueId = _bombeio['tanque_id']?.toString();
      if (tanqueId?.isEmpty ?? true) {
        if (mounted) setState(() => _rateioRealizado = false);
        return;
      }

      // determina intervalo do dia da data do bombeio
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
      // falhar silent; não bloquear interface
      debugPrint('Erro ao verificar rateio existente: $e');
    }
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
      // Executa inserts na tabela movimentacoes_tanque para cada participante
      try {
        final supabase = Supabase.instance.client;

        final String? tanqueId = _bombeio['tanque_id']?.toString();
        if (tanqueId?.isEmpty ?? true) {
          throw Exception('tanque_id ausente no bombeio');
        }

        // Obter produto_id: pode estar presente em widget.bombeio['produto_id']
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

        final recebidoAmb =
            double.tryParse(_bombeio['recebido_amb']?.toString() ?? '0') ?? 0;
        final recebido20 =
            double.tryParse(_bombeio['recebido_20']?.toString() ?? '0') ?? 0;

        final participantes = (_bombeio['participantes'] is List)
            ? List<Map<String, dynamic>>.from(_bombeio['participantes'])
            : <Map<String, dynamic>>[];

        double totalSolicitado = 0;
        for (var p in participantes) {
          totalSolicitado +=
              double.tryParse(p['solicitado']?.toString() ?? '0') ?? 0;
        }

        final usuario = UsuarioAtual.instance;
        final terminalId = usuario?.terminalId;
        final bombeioId =
            _bombeio['id']?.toString() ?? _bombeio['bombeio_id']?.toString();

        final List<Map<String, dynamic>> inserts = [];

        for (var p in participantes) {
          final solicit =
              double.tryParse(p['solicitado']?.toString() ?? '0') ?? 0;
          final peso = totalSolicitado > 0 ? (solicit / totalSolicitado) : 0;
          final entradaAmb = (recebidoAmb * peso).round();
          final entradaVinte = (recebido20 * peso).round();

          // Resolve empresa_id: se nome parecer UUID, usa direto; senão busca por nome
          String? empresaId;
          final nomeRaw = p['nome']?.toString() ?? '';
          // Simpler UUID check: verifica comprimento 36 e hífens
          final looksLikeUuid = nomeRaw.length == 36 && nomeRaw.contains('-');
          if (looksLikeUuid) {
            empresaId = nomeRaw;
          } else if (nomeRaw.isNotEmpty) {
            // tenta achar pela coluna nome, nome_dois ou nome_abrev
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
          // Atualiza apenas a coluna `entrada_vinte` das movimentações já existentes
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
                  // empresa_id não informado: procura movimentação com bombeio_id e empresa_id IS NULL
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
            // Marca o bombeio como rateado se tivermos o id do bombeio
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

            if (mounted) {
              setState(() => _rateioRealizado = true);
              await _showMessageDialog('Rateio automático realizado');
            }
          } else {
            if (mounted) {
              await _showMessageDialog(
                'Nenhum participante para atualizar',
                title: 'Aviso',
              );
            }
          }
        } else {
          if (mounted) {
            await _showMessageDialog(
              'Nenhum participante para inserir',
              title: 'Aviso',
            );
          }
        }
      } catch (e) {
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
          // Título reduzido e ícone
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
          // Informações na mesma linha
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
    final double totalSolicitado = _bombeio['volume_solicitado'];
    final double recebidoAmb = (_bombeio['recebido_amb'] ?? 0).toDouble();
    final double recebido20 = (_bombeio['recebido_20'] ?? 0).toDouble();
    final List<Map<String, dynamic>> participantes =
        List<Map<String, dynamic>>.from(_bombeio['participantes']);

    // Ordenando da que mais participou para a que menos participou (pelo volume solicitado)
    participantes.sort(
      (a, b) =>
          (b['solicitado'] as double).compareTo(a['solicitado'] as double),
    );

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
                _buildHeaderMicroItem('CONTROLE', _bombeio['numero_controle']),
                _buildHeaderMicroItem('PRODUTO', _bombeio['produto']),
                _buildHeaderMicroItem('DATA', _formatarData(_bombeio['data'])),
                _buildHeaderMicroItem(
                  'HORÁRIO',
                  '${_bombeio['horario_inicial']} - ${_bombeio['horario_final']}',
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
                  // --- MEDIÇÕES ---
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

                  // --- SEÇÃO INFERIOR: DISTRIBUIÇÃO E RATEIO LADO A LADO ---
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
                      // LADO ESQUERDO: RESUMO E GRÁFICO
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
                                          const Color(
                                            0xFF0D47A1,
                                          ), // Azul Escuro
                                          const Color(0xFFD32F2F), // Vermelho
                                          const Color(0xFF388E3C), // Verde
                                          const Color(
                                            0xFFFBC02D,
                                          ), // Amarelo/Dourado
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

                      // LADO DIREITO: TABELA DE RATEIO
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Tabela de distribuição fixa
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 3,
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
                                      'SOLICITADO',
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
                              double percent =
                                  peso; // O percentual do rateio é baseado no solicitado

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
                                          flex: 3,
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
                                                        value: percent,
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
                                              color:
                                                  colors[index % colors.length],
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
                                              color:
                                                  colors[index % colors.length],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Divider(height: 1),
                                ],
                              );
                            }),

                            // Botões de rateio adicionados abaixo da tabela
                            const SizedBox(height: 24),
                            // Enquanto não sabemos se o rateio foi realizado, não renderiza nenhum botão
                            if (_rateioRealizado == null)
                              const Center(
                                child: SizedBox(width: 200, height: 40),
                              )
                            else if (_rateioRealizado == true)
                              Center(
                                child: Container(
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
