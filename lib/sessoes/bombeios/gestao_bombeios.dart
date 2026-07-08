import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../../login_page.dart';
import '../../main.dart';
import 'dialog_inserir_bombeio.dart';
import 'detalhes_bombeio.dart';

class FiltroGestaoBombeiosPage extends StatefulWidget {
  final String? terminalId;
  final String? empresaId;
  final String? empresaNome;
  final Function({
    String? terminalId,
    DateTime? dataInicial,
    DateTime? dataFinal,
    String? produtoId,
    String? produtoNome,
    String? pesquisa,
  })
  onConsultar;
  final VoidCallback onVoltar;

  const FiltroGestaoBombeiosPage({
    super.key,
    this.terminalId,
    this.empresaId,
    this.empresaNome,
    required this.onConsultar,
    required this.onVoltar,
  });

  @override
  State<FiltroGestaoBombeiosPage> createState() =>
      _FiltroGestaoBombeiosPageState();
}

class _FiltroGestaoBombeiosPageState extends State<FiltroGestaoBombeiosPage>
    with RouteAware {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Variáveis globais baseadas no usuário
  String? terminalId;
  String? empresaId;
  String? empresaNome;
  bool _terminalVinculado = false;
  String? terminalSelecionadoNome;

  DateTime? dataInicial;
  DateTime? dataFinal;
  String? terminalSelecionadoId;
  String? produtoSelecionado;
  String? produtoSelecionadoId;
  String? tanqueSelecionadoId;
  String? statusSelecionado;

  // RECOLOCANDO AS VARIÁVEIS QUE FORAM REMOVIDAS ACIDENTALMENTE
  List<Map<String, dynamic>> produtosDisponiveis = [];
  List<Map<String, dynamic>> tanquesDisponiveis = [];
  List<Map<String, dynamic>> terminais = [];

  bool carregando = true;
  final TextEditingController pesquisaController = TextEditingController();

  Map<String, dynamic>? _bombeioSelecionado;
  bool _mostrarRateio = false;

  UsuarioAtual? get user => UsuarioAtual.instance;

  List<Map<String, dynamic>> _todosRegistros = [];
  List<Map<String, dynamic>> registrosExibidos = [];

  int paginaAtual = 0;
  final int itensPorPagina = 20;
  bool temMaisRegistros = true;

  @override
  void initState() {
    super.initState();
    dataFinal = null;
    dataInicial = null;

    // Inicializa variáveis globais do usuário
    if (user != null) {
      terminalId = user!.terminalId;
      empresaId = user!.empresaId;
      empresaNome = user!.empresaNome;
      if (terminalId != null && terminalId!.isNotEmpty) {
        _terminalVinculado = true;
        terminalSelecionadoId = terminalId;
        terminalSelecionadoNome = user!.terminalNome ?? 'Terminal vinculado';
      }
    }

    _carregarDadosIniciais();
    pesquisaController.addListener(_aplicarFiltrosLocal);
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
    pesquisaController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    // Voltou para esta página a partir de outra rota — recarrega registros
    _carregarBombeios(resetPagina: true);
  }

  void _carregarDadosIniciais() async {
    setState(() => carregando = true);
    try {
      await _carregarTerminaisDisponiveis();
      await _carregarBombeios(resetPagina: true);
    } catch (e) {
      debugPrint('Erro: $e');
    } finally {
      setState(() => carregando = false);
    }
  }

  Future<void> _carregarTerminaisDisponiveis() async {
    if (_terminalVinculado &&
        terminalSelecionadoId != null &&
        terminalSelecionadoId!.isNotEmpty) {
      setState(() {
        terminais = [
          {
            'id': terminalSelecionadoId!,
            'nome': terminalSelecionadoNome ?? 'Terminal vinculado',
          },
        ];
      });
      await _carregarTanquesPorTerminal(terminalSelecionadoId!);
      return;
    }

    try {
      final usuario = UsuarioAtual.instance;
      if (usuario == null) {
        setState(() {
          terminais = [
            {'id': '', 'nome': '<usuário não logado>'},
          ];
        });
        return;
      }

      String? empresaIdLocal = usuario.empresaId;
      if (empresaIdLocal == null || empresaIdLocal.isEmpty) {
        empresaIdLocal = widget.empresaId;
      }

      if (empresaIdLocal == null || empresaIdLocal.isEmpty) {
        setState(() {
          terminais = [
            {'id': '', 'nome': '<empresa não identificada>'},
          ];
        });
        return;
      }

      var relacoesQuery = _supabase.from('relacoes_terminais').select('''
            terminal_id,
            terminais!inner (
              id,
              nome
            )
          ''');
      relacoesQuery = relacoesQuery.eq('empresa_id', empresaIdLocal);
      final relacoes = await relacoesQuery;

      final Map<String, Map<String, dynamic>> terminaisUnicos = {};
      for (var relacao in relacoes) {
        if (relacao['terminais'] != null) {
          final terminal = relacao['terminais'] as Map<String, dynamic>;
          final terminalId = terminal['id']?.toString();

          if (terminalId != null && !terminaisUnicos.containsKey(terminalId)) {
            terminaisUnicos[terminalId] = {
              'id': terminalId,
              'nome': terminal['nome']?.toString() ?? 'Terminal sem nome',
            };
          }
        }
      }

      List<Map<String, dynamic>> terminaisLista =
          terminaisUnicos.values.toList()
            ..sort((a, b) => (a['nome'] ?? '').compareTo(b['nome'] ?? ''));

      setState(() {
        terminais = terminaisLista;
        if (terminaisLista.length == 1) {
          terminalSelecionadoId = terminaisLista[0]['id'];
          terminalSelecionadoNome = terminaisLista[0]['nome'];
        } else {
          terminalSelecionadoId = null;
          terminalSelecionadoNome = null;
        }
      });

      if (terminalSelecionadoId != null && terminalSelecionadoId!.isNotEmpty) {
        await _carregarTanquesPorTerminal(terminalSelecionadoId!);
      }
    } catch (e) {
      debugPrint('Erro ao carregar terminais: $e');
      setState(() {
        terminais = [
          {'id': '', 'nome': '<erro ao carregar terminais>'},
        ];
        terminalSelecionadoId = null;
      });
    }
  }

  Future<void> _carregarBombeios({
    bool resetPagina = true,
    int? novaPagina,
  }) async {
    if (resetPagina) {
      paginaAtual = 0;
    } else if (novaPagina != null) {
      paginaAtual = novaPagina;
    }

    setState(() => carregando = true);
    try {
      var query = _supabase.from('bombeios').select('''
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
      ''');

      if (terminalSelecionadoId != null && terminalSelecionadoId!.isNotEmpty) {
        query = query.eq('terminal_id', terminalSelecionadoId!);
      } else if (terminalId != null && terminalId!.isNotEmpty) {
        query = query.eq('terminal_id', terminalId!);
      } else if (empresaId != null && empresaId!.trim().isNotEmpty) {
        query = query.eq('empresa_id', empresaId!.trim());
      }

      if (tanqueSelecionadoId != null) {
        query = query.eq('tanque_id', tanqueSelecionadoId!);
      }

      if (dataInicial != null) {
        query = query.gte('data', dataInicial!.toIso8601String().split('T')[0]);
      }
      if (dataFinal != null) {
        query = query.lte('data', dataFinal!.toIso8601String().split('T')[0]);
      }

      final int from = paginaAtual * itensPorPagina;
      final int to = from + itensPorPagina - 1;

      final response = await query
          .order('data', ascending: false)
          .range(from, to);

      temMaisRegistros = response.length == itensPorPagina;

      final List<Map<String, dynamic>> dadosTransformados = [];
      for (var item in response) {
        // Tenta buscar pela chave com o hint ou pela chave simples 'tanques'
        final tanquesArr =
            item['tanques!bombeios_tanque_id_fkey'] ?? item['tanques'];

        // No Supabase, se for relationship many-to-one, pode vir como Map ou List
        final tanques = tanquesArr is List
            ? (tanquesArr.isNotEmpty ? tanquesArr[0] : null)
            : tanquesArr;

        final produto = tanques?['produtos']?['nome'] ?? 'S/ Produto';
        final tanqueNome = tanques?['referencia'] ?? 'S/ Tanque';

        // Lógica de status baseada na presença de medições e faturamento
        String status = '';
        if (item['medicao_inicial_id'] == null &&
            item['medicao_final_id'] == null) {
          status = 'Definindo quantidades';
        } else if (item['medicao_final_id'] == null) {
          status = 'Em andamento';
        } else if (item['qtd_total_faturada'] == null) {
          status = 'Concluído, aguardando informações';
        } else {
          // Antes era 'Concluído' — agora distingue se houve rateio
          // Considera rateio realizado apenas se o valor for estritamente boolean true
          final bool hasRateio = item['rateio'] == true;
          status = hasRateio ? 'Finalizado com rateio' : 'Aguardando rateio';
        }

        double totalSolicitado = 0;
        List<Map<String, dynamic>> participantes = [];
        final rawVols = item['volumes_solicitados'];

        if (rawVols != null) {
          if (rawVols is Map) {
            rawVols.forEach((key, value) {
              double sol = double.tryParse(value.toString()) ?? 0;
              totalSolicitado += sol;
              participantes.add({'nome': key, 'solicitado': sol});
            });
          } else if (rawVols is List) {
            for (var v in rawVols) {
              if (v is Map) {
                double sol =
                    double.tryParse(v['solicitado']?.toString() ?? '0') ?? 0;
                totalSolicitado += sol;
                participantes.add({
                  'nome': v['nome'] ?? 'S/ Distribuidora',
                  'solicitado': sol,
                });
              }
            }
          }
        }

        final medFinalArr = item['medicao_final'];
        final medFinal = medFinalArr is List
            ? (medFinalArr.isNotEmpty ? medFinalArr[0] : null)
            : medFinalArr;
        final hFinal =
            medFinal?['horario']?.toString().substring(0, 5) ?? '--:--';

        final medIniArr = item['medicao_inicial'];
        final medIni = medIniArr is List
            ? (medIniArr.isNotEmpty ? medIniArr[0] : null)
            : medIniArr;

        double volAmbIni =
            double.tryParse(medIni?['volume_ambiente']?.toString() ?? '0') ?? 0;
        double vol20Ini =
            double.tryParse(medIni?['volume_20']?.toString() ?? '0') ?? 0;
        double volAmbFin =
            double.tryParse(medFinal?['volume_ambiente']?.toString() ?? '0') ??
            0;
        double vol20Fin =
            double.tryParse(medFinal?['volume_20']?.toString() ?? '0') ?? 0;

        double recebidoAmb = (volAmbFin > 0) ? (volAmbFin - volAmbIni) : 0;
        double recebido20 = (vol20Fin > 0) ? (vol20Fin - vol20Ini) : 0;

        dadosTransformados.add({
          'id': item['id'],
          'tanque_id': item['tanque_id'],
          'rateio': item['rateio'],
          'data': DateTime.tryParse(item['data'] ?? '') ?? DateTime.now(),
          'produto': produto,
          'tanque': tanqueNome,
          'horario_inicial':
              item['horario']?.toString().substring(0, 5) ?? '--:--',
          'horario_final': hFinal,
          'numero_controle': item['num_controle'] ?? 'S/N',
          'status': status,
          'volume_total':
              double.tryParse(item['total_bombeio']?.toString() ?? '0') ?? 0,
          'volume_solicitado': totalSolicitado,
          'participantes': participantes,
          'recebido_amb': recebidoAmb,
          'recebido_20': recebido20,
          'qtd_total_faturada': item['qtd_total_faturada'],
          'medicao_inicial_id': item['medicao_inicial_id'],
          'medicao_final_id': item['medicao_final_id'],
          'medicao_inicial': medIni,
          'medicao_final': medFinal,
        });
      }

      setState(() {
        _todosRegistros = dadosTransformados;
        _aplicarFiltrosLocal();
        carregando = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar bombeios: $e');
      setState(() => carregando = false);
    }
  }

  Future<void> _carregarTanquesPorTerminal(String terminalId) async {
    try {
      final List<dynamic> data = await _supabase
          .from('tanques')
          .select('id, referencia, produto_id, produtos(nome_dois, nome)')
          .eq('terminal_id', terminalId)
          .not('tipo_abastecimento', 'ilike', '%lct%');

      final List<Map<String, dynamic>> tanquesList =
          List<Map<String, dynamic>>.from(data);

      tanquesList.sort((a, b) {
        int getNum(String ref) {
          final parts = ref.split('-');
          if (parts.length >= 2) {
            return int.tryParse(parts[1]) ?? 0;
          }
          return 0;
        }

        return getNum(
          a['referencia'] ?? '',
        ).compareTo(getNum(b['referencia'] ?? ''));
      });

      final List<Map<String, dynamic>> produtosLista = [];
      final List<dynamic> produtosData = await _supabase
          .from('produtos')
          .select('id, nome, nome_dois')
          .eq('lista_exa', true)
          .order('nome', ascending: true);

      for (var produto in produtosData) {
        final produtoId = produto['id']?.toString();
        if (produtoId == null || produtoId.isEmpty) continue;

        final nome = produto['nome_dois'] ?? produto['nome'] ?? 'Sem nome';
        produtosLista.add({'id': produtoId, 'nome': nome.toString()});
      }

      setState(() {
        tanquesDisponiveis = tanquesList;
        produtosDisponiveis = produtosLista;
      });
    } catch (e) {
      debugPrint('Erro ao buscar tanques/produtos: $e');
      setState(() {
        tanquesDisponiveis = [];
        produtosDisponiveis = [];
      });
    }
  }

  Future<void> _abrirDetalhesPorId(dynamic id) async {
    if (id == null) return;
    try {
      final resp = await _supabase
          .from('bombeios')
          .select('''
          id,
          rateio,
          num_controle,
          data,
          horario,
          medicao_inicial_id,
          medicao_final_id,
          medicao_inicial_id_2,
          medicao_final_id_2,
          tanque_id_2,
          volumes_solicitados,
          total_bombeio,
          quantidades_faturadas,
          tanque_id,
          qtd_total_faturada,
          tanques!bombeios_tanque_id_fkey (
            referencia,
            produto_id,
            produtos (
              nome
            )
          ),
          tanque2:tanques!bombeios_tanque_id_2_fkey (
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
          medicao_inicial_2:medicoes!bombeios_medicao_inicial_id_2_fkey (
            id,
            num_controle,
            data,
            horario,
            volume_ambiente,
            volume_20
          ),
          medicao_final_2:medicoes!bombeios_medicao_final_id_2_fkey (
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
      
      // Tanque 1
      final tanquesArr = item['tanques!bombeios_tanque_id_fkey'] ?? item['tanques'];
      final tanques = tanquesArr is List
          ? (tanquesArr.isNotEmpty ? tanquesArr[0] : null)
          : tanquesArr;
      final produto = tanques?['produtos']?['nome'] ?? 'S/ Produto';
      final tanqueNome = tanques?['referencia'] ?? 'S/ Tanque';
      
      // Tanque 2
      final tanque2Arr = item['tanque2'] ?? item['tanques!bombeios_tanque_id_2_fkey'];
      final tanque2 = tanque2Arr is List
          ? (tanque2Arr.isNotEmpty ? tanque2Arr[0] : null)
          : tanque2Arr;
      final produto2 = tanque2?['produtos']?['nome'] ?? '';
      final tanqueNome2 = tanque2?['referencia'] ?? '';

      double totalSolicitado = 0;
      List<Map<String, dynamic>> participantes = [];
      final rawVols = item['volumes_solicitados'];
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

      // Medições do tanque 1
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

      // Medições do tanque 2
      final medFinal2Arr = item['medicao_final_2'];
      final medFinal2 = medFinal2Arr is List
          ? (medFinal2Arr.isNotEmpty ? medFinal2Arr[0] : null)
          : medFinal2Arr;
      final hFinal2 = medFinal2?['horario']?.toString().substring(0, 5) ?? '--:--';

      final medIni2Arr = item['medicao_inicial_2'];
      final medIni2 = medIni2Arr is List
          ? (medIni2Arr.isNotEmpty ? medIni2Arr[0] : null)
          : medIni2Arr;

      final Map<String, dynamic> bombeioParaDetalhes = {
        'id': item['id'],
        'bombeio_id': item['id'],
        'rateio': item['rateio'],
        'tanque_id': item['tanque_id'],
        'tanque_id_2': item['tanque_id_2'],
        'data': DateTime.tryParse(item['data'] ?? '') ?? DateTime.now(),
        'produto': produto,
        'produto_2': produto2,
        'tanque': tanqueNome,
        'tanque_2': tanqueNome2,
        'horario_inicial': item['horario']?.toString().substring(0, 5) ?? '--:--',
        'horario_final': hFinal,
        'horario_final_2': hFinal2,
        'numero_controle': item['num_controle'] ?? 'S/N',
        'status': '',
        'volume_total': double.tryParse(item['total_bombeio']?.toString() ?? '0') ?? 0,
        'volume_solicitado': totalSolicitado,
        'participantes': participantes,
        'recebido_amb': recebidoAmb,
        'recebido_20': recebido20,
        'quantidades_faturadas': {},
        'qtd_total_faturada': item['qtd_total_faturada'],
        'medicao_inicial': medIni,
        'medicao_final': medFinal,
        'medicao_inicial_2': medIni2,
        'medicao_final_2': medFinal2,
        'medicao_inicial_id': item['medicao_inicial_id'],
        'medicao_final_id': item['medicao_final_id'],
        'medicao_inicial_id_2': item['medicao_inicial_id_2'],
        'medicao_final_id_2': item['medicao_final_id_2'],
      };

      // parse quantidades_faturadas if present
      try {
        final rawFaturado = item['quantidades_faturadas'];
        if (rawFaturado != null) {
          Map<String, double> qmap = {};
          if (rawFaturado is Map) {
            rawFaturado.forEach((k, v) {
              final double val = double.tryParse(v?.toString() ?? '0') ?? 0;
              if (val != 0) qmap[k?.toString() ?? ''] = val;
            });
          } else if (rawFaturado is String) {
            final parsed = jsonDecode(rawFaturado);
            if (parsed is Map) {
              parsed.forEach((k, v) {
                final double val = double.tryParse(v?.toString() ?? '0') ?? 0;
                if (val != 0) qmap[k?.toString() ?? ''] = val;
              });
            }
          }
          bombeioParaDetalhes['quantidades_faturadas'] = qmap;
        }
      } catch (e) {
        debugPrint('Erro ao parsear quantidades_faturadas (prefetch): $e');
      }

      if (!mounted) return;
      setState(() {
        _bombeioSelecionado = bombeioParaDetalhes;
        _mostrarRateio = true;
      });
    } catch (e) {
      debugPrint('Erro ao abrir detalhes: $e');
    }
  }

  void _aplicarFiltrosLocal() {
    setState(() {
      registrosExibidos = _todosRegistros.where((item) {
        final DateTime dt = item['data'] as DateTime;
        final String pesquisa = pesquisaController.text.toLowerCase();
        if (dataInicial != null && dt.isBefore(dataInicial!)) {
          return false;
        }
        if (dataFinal != null &&
            dt.isAfter(dataFinal!.add(const Duration(days: 1)))) {
          return false;
        }
        if (produtoSelecionado != null &&
            item['produto'] != produtoSelecionado) {
          return false;
        }
        if (tanqueSelecionadoId != null &&
            item['tanque_id'] != tanqueSelecionadoId) {
          return false;
        }
        if (statusSelecionado != null &&
            statusSelecionado!.isNotEmpty &&
            item['status'] != statusSelecionado) {
          return false;
        }
        if (pesquisa.isNotEmpty) {
          final String dataStr = _formatarData(dt).toLowerCase();
          final String status = (item['status'] as String).toLowerCase();
          final String tanque = (item['tanque'] as String).toLowerCase();
          final String numControle = (item['numero_controle'] as String)
              .toLowerCase();
          final String produto = (item['produto'] as String).toLowerCase();

          if (!produto.contains(pesquisa) &&
              !numControle.contains(pesquisa) &&
              !dataStr.contains(pesquisa) &&
              !status.contains(pesquisa) &&
              !tanque.contains(pesquisa)) {
            return false;
          }
        }
        return true;
      }).toList();
    });
  }

  String _formatarData(DateTime? data) => data == null
      ? '-'
      : "${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}";

  Color _getStatusColor(String? status) {
    if (status == 'Finalizado com rateio') return Colors.green;
    if (status == 'Aguardando rateio') return Colors.orange;
    if (status == 'Em andamento') return Colors.orange;
    if (status == 'Concluído, aguardando informações') return Colors.purple;
    if (status == 'Definindo quantidades') return Colors.blue;
    return Colors.grey;
  }

  bool _podeAbrirDetalhes(Map<String, dynamic> item) {
    final qtdFaturada = item['qtd_total_faturada'];
    final bool temQtdFaturada =
        qtdFaturada != null &&
        qtdFaturada.toString().trim().isNotEmpty &&
        qtdFaturada != 0;
    final bool temMedicaoInicial =
        item['medicao_inicial_id'] != null &&
        item['medicao_inicial_id'].toString().trim().isNotEmpty;
    final bool temMedicaoFinal =
        item['medicao_final_id'] != null &&
        item['medicao_final_id'].toString().trim().isNotEmpty;
    return temQtdFaturada && temMedicaoInicial && temMedicaoFinal;
  }

  Future<void> _cancelarBombeio(Map<String, dynamic> item) async {
    final bombeioId = item['id']?.toString();
    if (bombeioId == null || bombeioId.isEmpty) return;

    final confirmar = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFF0D47A1), width: 1),
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        title: const Text(
          'Cancelar bombeio',
          style: TextStyle(color: Color.fromARGB(255, 65, 54, 49)),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tem certeza que quer prosseguir com o cancelamento do bombeio?'),
            SizedBox(height: 8),
            Text(
              'Essa ação também cancelará as medições realizadas, atreladas a este bombeio.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text('Voltar'),
          ),
          SizedBox(
            height: 40,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                  if (states.contains(WidgetState.hovered)) {
                    return const Color.fromARGB(255, 65, 54, 49);
                  }
                  return Colors.black;
                }),
                foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                side: WidgetStateProperty.all(
                  const BorderSide(color: Color(0xFFFFB341), width: 1.6),
                ),
                elevation: WidgetStateProperty.all(1),
              ),
              child: const Text('Sim, cancelar.'),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await _supabase.from('bombeios').delete().eq('id', bombeioId);

      if (!mounted) return;
      setState(() {
        _bombeioSelecionado = null;
        _mostrarRateio = false;
      });
      await _carregarBombeios(resetPagina: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao cancelar bombeio: $e')),
      );
    }
  }

  Widget _buildListaBombeios() {
    return Column(
      children: [
        _buildCardFiltros(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              const SizedBox(width: 56),
              Expanded(
                flex: 1,
                child: Text(
                  'Data',
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
                  'Produto',
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
                  'Tanque',
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
                  'H.Inicial',
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
                  'H.Final',
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
                  'Vol. Amb.',
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
                  'Vol. 20ºC',
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
                  'Nº Controle',
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
                  'Status',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              const SizedBox(width: 24),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: registrosExibidos.length,
            itemBuilder: (context, index) {
              final item = registrosExibidos[index];
              final fmt = NumberFormat.decimalPattern('pt_BR');
              return InkWell(
                onTap: () async {
                  // Busca os dados completos do bombeio antes de abrir o diálogo
                  final bombeioCompleto = await _buscarBombeioCompleto(item['id']);
                  if (bombeioCompleto == null) return;
                  
                  if (_podeAbrirDetalhes(bombeioCompleto)) {
                    await _abrirDetalhesPorId(item['id']);
                  } else {
                    final result = await DialogInserirBombeio.show(
                      context,
                      bombeio: bombeioCompleto,
                    );
                    if (result is Map<String, dynamic> &&
                        result['abrirDetalhes'] == true) {
                      await _abrirDetalhesPorId(result['id']);
                      await _carregarBombeios(resetPagina: true);
                    } else {
                      await _carregarBombeios(resetPagina: true);
                    }
                  }
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          decoration: BoxDecoration(
                            color: _getStatusColor(item['status']),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              bottomLeft: Radius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Padding(
                          padding: const EdgeInsets.only(left: 4.0),
                          child: PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.more_vert,
                              size: 20,
                              color: Colors.grey,
                            ),
                            onSelected: (value) async {
                              if (value == 'cancelar') {
                                await _cancelarBombeio(item);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'cancelar',
                                child: Text('Cancelar bombeio'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              _formatarData(item['data']),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            item['produto'],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            item['tanque'],
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            item['horario_inicial'],
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            item['horario_final'],
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            item['recebido_amb'] > 0
                                ? fmt.format(item['recebido_amb'].toInt())
                                : '-',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            item['recebido_20'] > 0
                                ? fmt.format(item['recebido_20'].toInt())
                                : '-',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0D47A1),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            item['numero_controle'],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(
                                  item['status'],
                                ).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                item['status'],
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _getStatusColor(item['status']),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        _buildPaginacao(),
      ],
    );
  }

  Future<Map<String, dynamic>?> _buscarBombeioCompleto(dynamic id) async {
    if (id == null) return null;
    try {
      final resp = await _supabase
          .from('bombeios')
          .select('''
            id,
            rateio,
            num_controle,
            data,
            horario,
            medicao_inicial_id,
            medicao_final_id,
            medicao_inicial_id_2,
            medicao_final_id_2,
            tanque_id_2,
            volumes_solicitados,
            total_bombeio,
            quantidades_faturadas,
            tanque_id,
            qtd_total_faturada,
            tanques!bombeios_tanque_id_fkey (
              referencia,
              produto_id,
              produtos (
                nome
              )
            ),
            tanque2:tanques!bombeios_tanque_id_2_fkey (
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
            medicao_inicial_2:medicoes!bombeios_medicao_inicial_id_2_fkey (
              id,
              num_controle,
              data,
              horario,
              volume_ambiente,
              volume_20
            ),
            medicao_final_2:medicoes!bombeios_medicao_final_id_2_fkey (
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

      if (resp == null) return null;
      
      final item = resp;
      
      // Tanque 1
      final tanquesArr = item['tanques!bombeios_tanque_id_fkey'] ?? item['tanques'];
      final tanques = tanquesArr is List
          ? (tanquesArr.isNotEmpty ? tanquesArr[0] : null)
          : tanquesArr;
      final produto = tanques?['produtos']?['nome'] ?? 'S/ Produto';
      final tanqueNome = tanques?['referencia'] ?? 'S/ Tanque';
      
      // Tanque 2
      final tanque2Arr = item['tanque2'] ?? item['tanques!bombeios_tanque_id_2_fkey'];
      final tanque2 = tanque2Arr is List
          ? (tanque2Arr.isNotEmpty ? tanque2Arr[0] : null)
          : tanque2Arr;
      final produto2 = tanque2?['produtos']?['nome'] ?? '';
      final tanqueNome2 = tanque2?['referencia'] ?? '';

      double totalSolicitado = 0;
      List<Map<String, dynamic>> participantes = [];
      final rawVols = item['volumes_solicitados'];
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

      // Medições do tanque 1
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

      // Medições do tanque 2
      final medFinal2Arr = item['medicao_final_2'];
      final medFinal2 = medFinal2Arr is List
          ? (medFinal2Arr.isNotEmpty ? medFinal2Arr[0] : null)
          : medFinal2Arr;
      final hFinal2 = medFinal2?['horario']?.toString().substring(0, 5) ?? '--:--';

      final medIni2Arr = item['medicao_inicial_2'];
      final medIni2 = medIni2Arr is List
          ? (medIni2Arr.isNotEmpty ? medIni2Arr[0] : null)
          : medIni2Arr;

      return {
        'id': item['id'],
        'bombeio_id': item['id'],
        'rateio': item['rateio'],
        'tanque_id': item['tanque_id'],
        'tanque_id_2': item['tanque_id_2'],
        'data': DateTime.tryParse(item['data'] ?? '') ?? DateTime.now(),
        'produto': produto,
        'produto_2': produto2,
        'tanque': tanqueNome,
        'tanque_2': tanqueNome2,
        'horario_inicial': item['horario']?.toString().substring(0, 5) ?? '--:--',
        'horario_final': hFinal,
        'horario_final_2': hFinal2,
        'numero_controle': item['num_controle'] ?? 'S/N',
        'status': '',
        'volume_total': double.tryParse(item['total_bombeio']?.toString() ?? '0') ?? 0,
        'volume_solicitado': totalSolicitado,
        'participantes': participantes,
        'recebido_amb': recebidoAmb,
        'recebido_20': recebido20,
        'quantidades_faturadas': {},
        'qtd_total_faturada': item['qtd_total_faturada'],
        'medicao_inicial': medIni,
        'medicao_final': medFinal,
        'medicao_inicial_2': medIni2,
        'medicao_final_2': medFinal2,
        'medicao_inicial_id': item['medicao_inicial_id'],
        'medicao_final_id': item['medicao_final_id'],
        'medicao_inicial_id_2': item['medicao_inicial_id_2'],
        'medicao_final_id_2': item['medicao_final_id_2'],
      };
    } catch (e) {
      debugPrint('Erro ao buscar bombeio completo: $e');
      return null;
    }
  }

  Widget _buildCardFiltros() {
    return Card(
      color: const Color(0xFFFAFAFA),
      elevation: 2,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filtros de Busca',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D47A1),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 250,
                  child: DropdownButtonFormField<String>(
                    value: terminalSelecionadoId,
                    dropdownColor: Colors.white,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Terminal',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.business, size: 18),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      isDense: true,
                      fillColor: (user?.terminalId != null)
                          ? Colors.grey[200]
                          : null,
                      filled: (user?.terminalId != null),
                    ),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text(
                          'Todos',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ...terminais.map(
                        (t) => DropdownMenuItem(
                          value: t['id'],
                          child: Text(
                            t['nome'] ?? '',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (user?.terminalId != null)
                        ? null
                        : (val) async {
                            setState(() {
                              terminalSelecionadoId = val;
                              produtoSelecionadoId = null;
                              produtoSelecionado = null;
                              tanqueSelecionadoId = null;
                              if (val == null) {
                                tanquesDisponiveis = [];
                                produtosDisponiveis = [];
                              }
                            });
                            if (val != null) {
                              await _carregarTanquesPorTerminal(val);
                            }
                            _carregarBombeios(resetPagina: true);
                          },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: tanqueSelecionadoId,
                    dropdownColor: Colors.white,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Tanque',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.storage, size: 18),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      isDense: true,
                    ),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text(
                          'Todos',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ...tanquesDisponiveis.map(
                        (t) => DropdownMenuItem(
                          value: t['id'],
                          child: Text(
                            t['referencia'] ?? '',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() {
                        tanqueSelecionadoId = val;
                      });
                      _carregarBombeios(resetPagina: true);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: produtoSelecionadoId,
                    dropdownColor: Colors.white,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Produto',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.local_gas_station, size: 18),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      isDense: true,
                    ),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text(
                          'Todos',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ...produtosDisponiveis.map(
                        (p) => DropdownMenuItem(
                          value: p['id'],
                          child: Text(
                            p['nome'] ?? '',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() {
                        produtoSelecionadoId = val;
                        produtoSelecionado = val != null
                            ? produtosDisponiveis.firstWhere(
                                (p) => p['id'] == val,
                              )['nome']
                            : null;
                      });
                      _carregarBombeios(resetPagina: true);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: statusSelecionado,
                    dropdownColor: Colors.white,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.flag, size: 18),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      isDense: true,
                    ),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text(
                          'Todos',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ...const [
                        'Definindo quantidades',
                        'Em andamento',
                        'Concluído, aguardando informações',
                        'Aguardando rateio',
                        'Finalizado com rateio',
                      ].map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(
                            status,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() {
                        statusSelecionado = val;
                      });
                      _aplicarFiltrosLocal();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 140,
                  child: _buildDatePicker('Data inicial', dataInicial, (d) {
                    setState(() => dataInicial = d);
                    _carregarBombeios(resetPagina: true);
                  }),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 140,
                  child: _buildDatePicker('Data final', dataFinal, (d) {
                    setState(() => dataFinal = d);
                    _carregarBombeios(resetPagina: true);
                  }),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 190,
                  child: TextField(
                    controller: pesquisaController,
                    decoration: const InputDecoration(
                      labelText: 'Pesquisa geral',
                      prefixIcon: Icon(Icons.search, size: 18),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginacao() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: paginaAtual > 0
                ? () => _carregarBombeios(
                    resetPagina: false,
                    novaPagina: paginaAtual - 1,
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Text(
            'Página ${paginaAtual + 1}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: temMaisRegistros
                ? () => _carregarBombeios(
                    resetPagina: false,
                    novaPagina: paginaAtual + 1,
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker(
    String label,
    DateTime? value,
    Function(DateTime) onSelect,
  ) {
    final txt = value != null
        ? "${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}"
        : label;
    return InkWell(
      onTap: () async {
        DateTime tempDate = value ?? DateTime.now();
        final DateTime? selecionado = await showDialog<DateTime>(
          context: context,
          builder: (BuildContext context) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFF0D47A1), width: 1),
              ),
              child: Container(
                width: 350,
                padding: const EdgeInsets.all(20),
                child: StatefulBuilder(
                  builder: (context, setStateDialog) {
                    int? hoveredDay;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              color: Colors.black,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              label,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.of(context).pop(),
                              color: Colors.black,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.chevron_left,
                                  color: Colors.black,
                                ),
                                onPressed: () => setStateDialog(
                                  () => tempDate = DateTime(
                                    tempDate.year,
                                    tempDate.month - 1,
                                    tempDate.day,
                                  ),
                                ),
                              ),
                              Text(
                                '${_getMonthName(tempDate.month)} ${tempDate.year}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.chevron_right,
                                  color: Colors.black,
                                ),
                                onPressed: () => setStateDialog(
                                  () => tempDate = DateTime(
                                    tempDate.year,
                                    tempDate.month + 1,
                                    tempDate.day,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        GridView.count(
                          shrinkWrap: true,
                          crossAxisCount: 7,
                          childAspectRatio: 1.0,
                          children: ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'].map((
                            day,
                          ) {
                            return Center(
                              child: Text(
                                day,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        GridView.count(
                          shrinkWrap: true,
                          crossAxisCount: 7,
                          childAspectRatio: 1.0,
                          children: _getDaysInMonth(tempDate).map((day) {
                            final isSelected =
                                day != null && day == tempDate.day;
                            final isToday =
                                day != null &&
                                day == DateTime.now().day &&
                                tempDate.month == DateTime.now().month &&
                                tempDate.year == DateTime.now().year;
                            return StatefulBuilder(
                              builder: (context, setDayState) {
                                return MouseRegion(
                                  cursor: day != null
                                      ? SystemMouseCursors.click
                                      : SystemMouseCursors.basic,
                                  onEnter: (_) => day != null
                                      ? setDayState(() => hoveredDay = day)
                                      : null,
                                  onExit: (_) => day != null
                                      ? setDayState(() => hoveredDay = null)
                                      : null,
                                  child: GestureDetector(
                                    onTap: day != null
                                        ? () {
                                            Navigator.of(context).pop(
                                              DateTime(
                                                tempDate.year,
                                                tempDate.month,
                                                day,
                                              ),
                                            );
                                          }
                                        : null,
                                    child: Container(
                                      margin: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.black
                                            : (day != null && hoveredDay == day)
                                            ? Colors.black.withOpacity(0.1)
                                            : isToday
                                            ? Colors.black.withOpacity(0.13)
                                            : Colors.transparent,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          day != null ? day.toString() : '',
                                          style: TextStyle(
                                            color: isSelected
                                                ? Colors.white
                                                : isToday ||
                                                      (day != null &&
                                                          hoveredDay == day)
                                                ? Colors.black
                                                : Colors.black87,
                                            fontWeight:
                                                isSelected ||
                                                    isToday ||
                                                    (day != null &&
                                                        hoveredDay == day)
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              child: const Text(
                                'CANCELAR',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        );
        if (selecionado != null) onSelect(selecionado);
      },
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(4),
          color: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(txt, style: const TextStyle(fontSize: 13)),
            const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];
    return months[month - 1];
  }

  List<int?> _getDaysInMonth(DateTime date) {
    final firstDay = DateTime(date.year, date.month, 1);
    final lastDay = DateTime(date.year, date.month + 1, 0);
    final firstWeekday = firstDay.weekday;
    final startOffset = firstWeekday == 7 ? 0 : firstWeekday;
    List<int?> days = [];
    for (int i = 0; i < startOffset; i++) days.add(null);
    for (int i = 1; i <= lastDay.day; i++) days.add(i);
    while (days.length < 42) days.add(null);
    return days;
  }

  @override
  Widget build(BuildContext context) {
    if (_mostrarRateio && _bombeioSelecionado != null) {
      return DetalhesBombeioPage(
        bombeio: _bombeioSelecionado!,
        onVoltar: () => setState(() {
          _mostrarRateio = false;
          _carregarBombeios(resetPagina: true);
        }),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
                  onPressed: widget.onVoltar,
                ),
                const Text(
                  'Gestão de Bombeios',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                  ),
                ),
                const Spacer(),
                if (!carregando)
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Color(0xFF0D47A1)),
                    onPressed: _carregarBombeios,
                  ),
              ],
            ),
          ),
          Expanded(
            child: carregando
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF0D47A1)),
                  )
                : _buildListaBombeios(),
          ),
        ],
      ),
      floatingActionButton:
          (user?.empresaId == null || user!.empresaId!.trim().isEmpty)
          ? FloatingActionButton(
              onPressed: () async {
                final result = await DialogInserirBombeio.show(context);
                if (result is Map<String, dynamic> &&
                    result['abrirDetalhes'] == true) {
                  await _abrirDetalhesPorId(result['id']);
                  await _carregarBombeios();
                } else {
                  await _carregarBombeios();
                }
              },
              backgroundColor: const Color(0xFF0D47A1),
              tooltip: 'Novo Bombeio',
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}
