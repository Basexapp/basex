import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import '../../login_page.dart';
import 'dialog_medicoes_gasol.dart';
import 'dialog_medicoes_alcool.dart';
import 'rateio_payload.dart';

class ThousandSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.selection.baseOffset == 0) return newValue;
    String newText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (newText.isEmpty) return newValue.copyWith(text: '');

    final int value = int.parse(newText);
    final formatter = NumberFormat.decimalPattern('pt_BR');
    final String formattedText = formatter.format(value);

    return newValue.copyWith(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}

class DialogInserirBombeio extends StatefulWidget {
  final Map<String, dynamic>? bombeio;
  const DialogInserirBombeio({super.key, this.bombeio});

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    Map<String, dynamic>? bombeio,
  }) {
    return showDialog(
      context: context,
      builder: (context) => DialogInserirBombeio(bombeio: bombeio),
    );
  }

  @override
  State<DialogInserirBombeio> createState() => _DialogInserirBombeioState();
}

class _DialogInserirBombeioState extends State<DialogInserirBombeio> {
  final NumberFormat _fmt = NumberFormat.decimalPattern('pt_BR');

  UsuarioAtual? get user => UsuarioAtual.instance;

  Map<String, dynamic>? _bombeioLocal;
  double _totalVolumesNoInicio = 0;

  // Variáveis globais baseadas no usuário
  String? terminalId;
  String? empresaId;
  String? empresaNome;

  List<Map<String, dynamic>> _tanques = [];
  Map<String, dynamic>? _selectedTanque;
  String _produtoNome = '';
  final TextEditingController _produtoCtrl = TextEditingController();
  // Distribuidoras carregadas do banco (empresa.id + empresas.nome_dois)
  List<Map<String, dynamic>> _distribuidoras = [];
  Map<String, bool> selecionadas = {};
  Map<String, TextEditingController> controllers = {};
  // Controllers para quantidades faturadas por distribuidora
  Map<String, TextEditingController> faturadoControllers = {};
  final TextEditingController dataCtrl = TextEditingController();
  final TextEditingController horarioCtrl = TextEditingController();
  final TextEditingController _qtdFaturadaCtrl = TextEditingController();
  final TextEditingController _recebidaAmbCtrl = TextEditingController();
  final TextEditingController _recebida20Ctrl = TextEditingController();
  final TextEditingController _difFaturadoCtrl = TextEditingController();
  final FocusNode _dataFocusNode = FocusNode();
  String valorAntigoHorario = '';
  String valorAntigoData = '';
  bool dataInvalida = false;
  bool salvando = false;
  Map<String, dynamic>? _medicaoInicialSalva;
  Map<String, dynamic>? _medicaoFinalSalva;
  Color _difColor = const Color(0xFF0D47A1);

  bool get _temMedicoes =>
      _medicaoInicialSalva != null || _medicaoFinalSalva != null;

  bool get _temQuantidadesSalvas => _totalVolumesNoInicio > 0;

  bool get _isReadOnly =>
      user?.empresaId != null && user!.empresaId!.isNotEmpty;

  bool get _validarBasico {
    // 1. Data válida
    if (!_isDataValida(dataCtrl.text)) return false;

    // 2. Horário válido no formato "HH:mm h"
    final horarioValido = RegExp(r'^\d{2}:\d{2} h$').hasMatch(horarioCtrl.text);
    if (!horarioValido) return false;

    // 3. Pelo menos 1 distribuidora com volume > 0
    bool temVolumeSolicitado = false;
    for (var d in _distribuidoras) {
      final nome = d['nome']?.toString() ?? '';
      if (selecionadas[nome] == true) {
        final double val =
            double.tryParse(
              (controllers[nome]?.text ?? '')
                  .replaceAll('.', '')
                  .replaceAll(',', '.'),
            ) ??
            0;
        if (val > 0) {
          temVolumeSolicitado = true;
          break;
        }
      }
    }
    return temVolumeSolicitado;
  }

  bool get _podeSalvar {
    // Permite salvar em qualquer situação, exceto quando o diálogo é somente leitura
    // (usuário com empresaId). Mantemos a proteção contra múltiplos salvamentos
    // verificando a flag `salvando`.
    if (_isReadOnly) return false;
    if (salvando) return false;
    return true;
  }

  @override
  void initState() {
    super.initState();
    _bombeioLocal = widget.bombeio;
    // Inicializa variáveis globais do usuário
    if (user != null) {
      terminalId = user!.terminalId;
      empresaId = user!.empresaId;
      empresaNome = user!.empresaNome;
    }

    if (_bombeioLocal != null) {
      final b = _bombeioLocal!;
      if (b['data'] != null) {
        if (b['data'] is DateTime) {
          dataCtrl.text = DateFormat('dd/MM/yyyy').format(b['data']);
        } else {
          dataCtrl.text = _formatarDataIso(b['data'].toString());
        }
      }
      if (b['horario_inicial'] != null) {
        horarioCtrl.text = '${b['horario_inicial']} h';
      } else if (b['horario'] != null) {
        horarioCtrl.text = '${b['horario'].toString().substring(0, 5)} h';
      }

      _medicaoInicialSalva = b['medicao_inicial'];
      _medicaoFinalSalva = b['medicao_final'];
      _atualizarCalculos();

      if (b['qtd_faturada'] != null) {
        _qtdFaturadaCtrl.text = _fmt.format((b['qtd_faturada'] as num).toInt());
      }

      // Se ambas as medições existem, manter valores carregados e cálculos
      if (_medicaoInicialSalva != null && _medicaoFinalSalva != null) {
        // flags removidas — nada extra necessário aqui
      }
    }

    // Se não há data preenchida (novo bombeio ou sem data), preenche com a data atual
    if (dataCtrl.text.isEmpty) {
      dataCtrl.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
    }

    _fetchTanques().whenComplete(() {
      // Após carregar tanques, tenta buscar medições completas caso falte tanque_id
      _fetchMedicaoFullIfNeeded(_medicaoInicialSalva, false);
      _fetchMedicaoFullIfNeeded(_medicaoFinalSalva, true);
    });
    _fetchDistribuidoras();
    _qtdFaturadaCtrl.addListener(_atualizarCalculos);
    _dataFocusNode.addListener(() {
      if (!_dataFocusNode.hasFocus) {
        _validarData(dataCtrl.text);
      }
    });
  }

  void _atualizarCalculos() {
    if (_medicaoInicialSalva != null && _medicaoFinalSalva != null) {
      final double ambIni =
          (_medicaoInicialSalva!['volume_ambiente'] as num?)?.toDouble() ?? 0;
      final double ambFin =
          (_medicaoFinalSalva!['volume_ambiente'] as num?)?.toDouble() ?? 0;
      final double v20Ini =
          (_medicaoInicialSalva!['volume_20'] as num?)?.toDouble() ?? 0;
      final double v20Fin =
          (_medicaoFinalSalva!['volume_20'] as num?)?.toDouble() ?? 0;

      final double recebidoAmb = ambFin - ambIni;
      final double recebido20 = v20Fin - v20Ini;

      _recebidaAmbCtrl.text = _fmt.format(recebidoAmb.toInt());
      _recebida20Ctrl.text = _fmt.format(recebido20.toInt());

      // Cálculo da diferença faturado/recebido
      final double faturado =
          double.tryParse(
            _qtdFaturadaCtrl.text.replaceAll('.', '').replaceAll(',', '.'),
          ) ??
          0;

      if (faturado > 0 && _qtdFaturadaCtrl.text.isNotEmpty) {
        final double dif = recebido20 - faturado;
        final double percentual = (dif / faturado) * 100;

        _difFaturadoCtrl.text =
            '${_fmt.format(dif.toInt())} L | ${percentual.toStringAsFixed(2).replaceAll('.', ',')}%';
        _difColor = dif < 0 ? Colors.red : const Color(0xFF0D47A1);
      } else {
        _difFaturadoCtrl.text = '';
        _difColor = const Color(0xFF0D47A1);
      }

      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _fetchMedicaoFullIfNeeded(Map<String, dynamic>? med, bool isFinal) async {
    if (med == null) return;
    try {
      final id = med['id']?.toString();
        if (id == null || id.isEmpty) return;        
        if (med['tanque_id'] != null && med['tanque_id'].toString().trim().isNotEmpty) return;        
      final supabase = Supabase.instance.client;
      final full = await supabase.from('medicoes').select().eq('id', id).maybeSingle();
      if (full != null) {
        if (isFinal) {
          setState(() {
            _medicaoFinalSalva = Map<String, dynamic>.from(full);
          });
        } else {
          setState(() {
            _medicaoInicialSalva = Map<String, dynamic>.from(full);
          });
        }
        _atualizarCalculos();
      } else {
      }
    } catch (e) {
      // swallow error silently to avoid noisy logs in production
    }
  }

  Future<void> _fetchTanques() async {
    if (terminalId == null) return;
    try {
      final List<dynamic> data = await Supabase.instance.client
          .from('tanques')
          // traz também produtos.nome_dois para exibir na lista
          .select('id, referencia, produto_id, produtos(nome_dois, nome)')
          .eq('terminal_id', terminalId as Object)
          // incluir qualquer tipo, exceto os que contenham explicitamente 'ltc'
          .not('tipo_abastecimento', 'ilike', '%lct%');

      if (mounted) {
        final List<Map<String, dynamic>> tanquesList =
            List<Map<String, dynamic>>.from(data);

        // Ordenação customizada pelo número do tanque (ex: TQ-01-JN)
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

        setState(() {
          _tanques = tanquesList;
          if (_bombeioLocal != null && _bombeioLocal!['tanque_id'] != null) {
            try {
              _selectedTanque = _tanques.firstWhere(
                (t) => t['id'] == _bombeioLocal!['tanque_id'],
              );
              var prod = _selectedTanque?['produtos'];
              if (prod is List) prod = prod.isNotEmpty ? prod[0] : null;
              _produtoNome = (prod is Map)
                  ? (prod['nome_dois'] ?? prod['nome'] ?? '')
                  : '';
              _produtoCtrl.text = _produtoNome;
            } catch (_) {}
          }
        });
      }
    } catch (e) {
      debugPrint('Erro ao buscar tanques: $e');
    }
  }

  Future<void> _fetchDistribuidoras() async {
    if (terminalId == null) return;
    try {
      final List<dynamic> data = await Supabase.instance.client
          .from('relacoes_terminais')
          .select('empresa_id, empresas(id, nome_dois, nome, nome_abrev)')
          .eq('terminal_id', terminalId as Object);

      final Map<String, Map<String, dynamic>> empresasMap = {};
      for (var r in data) {
        var emp = r['empresas'];
        if (emp is List) emp = emp.isNotEmpty ? emp[0] : null;
        if (emp != null) {
          final id = (emp['id'] ?? r['empresa_id']).toString();
          final nome =
              emp['nome_dois'] ?? emp['nome'] ?? emp['nome_abrev'] ?? id;
          empresasMap[id] = {'id': id, 'nome': nome};
        } else if (r['empresa_id'] != null) {
          final id = r['empresa_id'].toString();
          empresasMap[id] = {'id': id, 'nome': id};
        }
      }

      final List<Map<String, dynamic>> list = empresasMap.values.toList()
        ..sort(
          (a, b) => (a['nome'] ?? '').toString().compareTo(
            (b['nome'] ?? '').toString(),
          ),
        );

      setState(() {
        _distribuidoras = list;
        // Inicializa seleções e controllers para cada distribuidora (chave pelo nome)
        selecionadas = {
          for (var e in _distribuidoras) (e['nome'] as String): false,
        };
        controllers = {
          for (var e in _distribuidoras)
            (e['nome'] as String): TextEditingController(),
        };
        faturadoControllers = {
          for (var e in _distribuidoras)
            (e['nome'] as String): TextEditingController(),
        };
      });

      // Se abriu com um bombeio existente, aplica volumes/participantes carregados
        if (_bombeioLocal != null) {
          final b = _bombeioLocal!;
          final vsol = b['volumes_solicitados'];
        if (vsol != null && vsol is Map) {
          vsol.forEach((key, value) {
            final String keyStr = key?.toString() ?? '';
            final int idx = _distribuidoras.indexWhere(
              (d) =>
                  (d['id']?.toString() == keyStr) ||
                  (d['nome']?.toString() == keyStr),
            );
            if (idx != -1) {
              final nome = _distribuidoras[idx]['nome'] as String;
              selecionadas[nome] = true;
              controllers[nome]!.text = _fmt.format((value as num).toDouble());
            }
          });
        }

        if (b['participantes'] is List) {
          for (var p in b['participantes']) {
            final nomeRaw = p['nome']?.toString() ?? '';
            final solicit = p['solicitado'];
            final int idx = _distribuidoras.indexWhere(
              (d) =>
                  (d['id']?.toString() == nomeRaw) ||
                  (d['nome']?.toString() == nomeRaw),
            );
            if (idx != -1) {
              final nome = _distribuidoras[idx]['nome'] as String;
              selecionadas[nome] = true;
              controllers[nome]!.text = _fmt.format((solicit as num).toInt());
            }
          }
        }

        // Se existe quantidades_faturadas salvas, aplica nos controllers de faturado
        final qf = b['quantidades_faturadas'];
        if (qf != null) {
          try {
            Map<String, dynamic> qmap = {};
                if (qf is String) {
                  try {
                    final parsed = jsonDecode(qf);
                    if (parsed is Map) {
                      qmap = Map<String, dynamic>.from(parsed);
                    }
                  } catch (_) {
                    // ignore malformed JSON
                  }
                } else if (qf is Map) {
                  qmap = Map<String, dynamic>.from(qf);
                }
            qmap.forEach((key, value) {
              final String keyStr = key.toString();
              final int idx = _distribuidoras.indexWhere(
                (d) => (d['id']?.toString() == keyStr) || (d['nome']?.toString() == keyStr),
              );
              if (idx != -1) {
                final nome = _distribuidoras[idx]['nome'] as String;
                faturadoControllers.putIfAbsent(nome, () => TextEditingController());
                faturadoControllers[nome]!.text = _fmt.format((value as num).toInt());
              }
            });
          } catch (_) {}
        }

        // Calcula o total inicial a partir do que foi carregado nos campos da UI
        double totalInicialCalc = 0;
        for (var e in _distribuidoras) {
          final nome = e['nome'] as String;
          if (selecionadas[nome] == true) {
            final text = (controllers[nome]?.text ?? '')
                .replaceAll('.', '')
                .replaceAll(',', '.');
            totalInicialCalc += double.tryParse(text) ?? 0;
          }
        }
        setState(() {
          _totalVolumesNoInicio = totalInicialCalc;
        });

        _atualizarCalculos();
      }
    } catch (e) {
      debugPrint('Erro ao buscar distribuidoras: $e');
    }
  }

  Future<void> _excluirMedicao(
    Map<String, dynamic> medicao,
    bool isFinal,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF0D47A1), width: 1),
        ),
        titlePadding: const EdgeInsets.all(0),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
          ),
          child: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
              SizedBox(width: 10),
              Text(
                'Confirmar Exclusão',
                style: TextStyle(
                  color: Color(0xFF0D47A1),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            'Deseja realmente excluir esta medição ${isFinal ? "final" : "inicial"}?\nEsta ação não poderá ser desfeita.',
            style: const TextStyle(color: Colors.black87, fontSize: 15),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text(
              'CANCELAR',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text('EXCLUIR'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final supabase = Supabase.instance.client;
    final medId = medicao['id'];
    if (medId == null) return;

    try {
      final field = isFinal ? 'medicao_final_id' : 'medicao_inicial_id';
      await supabase
          .from('bombeios')
          .update({field: null})
          .eq('id', _bombeioLocal!['id']);

      // 2. Deleta a medição
      await supabase.from('medicoes').delete().eq('id', medId);

      setState(() {
        if (isFinal) {
          _medicaoFinalSalva = null;
        } else {
          _medicaoInicialSalva = null;
        }
        _atualizarCalculos();
      });
        // swallow error silently to avoid noisy logs in production
      if (mounted) {
        await _showStyledDialog(
          title: 'Medição excluída',
          message: 'Medição excluída com sucesso!',
        );
      }
    } catch (e) {
      if (mounted) {
        await _showStyledDialog(
          title: 'Erro',
          message: 'Erro ao excluir medição: $e',
          headerColor: Colors.red,
          icon: Icons.error,
        );
      }
    }
  }

  void _abrirDialogOInserirMedicao({bool isFinal = false}) async {
    if (_bombeioLocal == null) return;

    final supabase = Supabase.instance.client;
    bool usarTabelaAlcool = false;
    final produtoNome = _produtoCtrl.text;
    final tanqueRef = _selectedTanque?['referencia'];
    final produtoId =
        (_selectedTanque?['produto_id'] ?? _bombeioLocal?['produto_id'])
            ?.toString();

    if (produtoNome.isNotEmpty) {
      try {
        final prodRes = await supabase
            .from('produtos')
            .select('tabela_alcool')
            .eq('nome', produtoNome)
            .maybeSingle();
        if (prodRes != null && prodRes['tabela_alcool'] == true) {
          usarTabelaAlcool = true;
        }
      } catch (e) {
        debugPrint('Erro ao verificar tabela_alcool: $e');
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => usarTabelaAlcool
          ? DialogMedicoesAlcool(
              produtoNome: produtoNome,
              produtoId: produtoId,
              tanqueReferencia: tanqueRef,
              data: dataCtrl.text,
              horario: horarioCtrl.text,
              exibirCamposAgua: false,
              bombeioId: _bombeioLocal!['id'],
              bombeioField: isFinal ? 'medicao_final_id' : 'medicao_inicial_id',
              onSaved: (map) {
                setState(() {
                  if (isFinal) {
                    _medicaoFinalSalva = map;
                    _bombeioLocal!['medicao_final_id'] = map['id'];
                  } else {
                    _medicaoInicialSalva = map;
                    _bombeioLocal!['medicao_inicial_id'] = map['id'];
                  }
                  _atualizarCalculos();
                });
              },
            )
          : DialogMedicoesGasol(
              produtoNome: produtoNome,
              produtoId: produtoId,
              tanqueReferencia: tanqueRef,
              data: dataCtrl.text,
              horario: horarioCtrl.text,
              exibirCamposAgua: false,
              bombeioId: _bombeioLocal!['id'],
              bombeioField: isFinal ? 'medicao_final_id' : 'medicao_inicial_id',
              onSaved: (map) {
                setState(() {
                  if (isFinal) {
                    _medicaoFinalSalva = map;
                    _bombeioLocal!['medicao_final_id'] = map['id'];
                  } else {
                    _medicaoInicialSalva = map;
                    _bombeioLocal!['medicao_inicial_id'] = map['id'];
                  }
                  _atualizarCalculos();
                });
              },
            ),
    );
  }

  @override
  void dispose() {
    dataCtrl.dispose();
    horarioCtrl.dispose();
    _recebidaAmbCtrl.dispose();
    _recebida20Ctrl.dispose();
    _difFaturadoCtrl.dispose();
    _produtoCtrl.dispose();
    _qtdFaturadaCtrl.dispose();
    _dataFocusNode.dispose();
    for (var c in controllers.values) {
      c.dispose();
    }
    for (var c in faturadoControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _abrirDialogFaturadoDistribuidoras() async {
    // lista apenas as distribuidoras selecionadas
    final participantes = _distribuidoras.where((d) => selecionadas[d['nome']] == true).toList();
    // garante controllers para cada participante
    for (var d in participantes) {
      final nome = d['nome']?.toString() ?? '';
      faturadoControllers.putIfAbsent(nome, () => TextEditingController());
    }

    // Tentar ler do banco a coluna quantidades_faturadas mais atualizada
    try {
      final supabase = Supabase.instance.client;
      final bombeioId = _bombeioLocal?['id']?.toString();
      if (bombeioId != null && bombeioId.isNotEmpty) {
        final resp = await supabase.from('bombeios').select('quantidades_faturadas').eq('id', bombeioId).maybeSingle();
        final qf = resp != null ? resp['quantidades_faturadas'] : null;
        if (qf != null) {
          Map<String, dynamic> qmap = {};
          if (qf is String) {
            try {
              final parsed = jsonDecode(qf);
              if (parsed is Map) qmap = Map<String, dynamic>.from(parsed);
            } catch (_) {}
          } else if (qf is Map) {
            qmap = Map<String, dynamic>.from(qf);
          }
          qmap.forEach((key, value) {
            final keyStr = key.toString();
            final idx = _distribuidoras.indexWhere((d) => (d['id']?.toString() == keyStr) || (d['nome']?.toString() == keyStr));
            if (idx != -1) {
              final nome = _distribuidoras[idx]['nome'] as String;
              faturadoControllers.putIfAbsent(nome, () => TextEditingController());
              faturadoControllers[nome]!.text = _fmt.format((value as num).toInt());
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Erro ao buscar quantidades_faturadas no banco: $e');
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Quantidade faturada por distribuidora', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      ...participantes.map((d) {
                        final nome = d['nome']?.toString() ?? '';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: faturadoControllers[nome],
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [ FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7), ThousandSeparatorInputFormatter() ],
                                  decoration: InputDecoration(labelText: nome, border: const OutlineInputBorder(), isDense: true, floatingLabelBehavior: FloatingLabelBehavior.always),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 36,
                                height: 36,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  tooltip: 'Zerar',
                                  onPressed: () {
                                    faturadoControllers[nome]?.text = '';
                                  },
                                  icon: const Icon(Icons.delete_outline, size: 20),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('CANCELAR')),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          // soma valores e atualiza campo principal
                          double total = 0;
                          for (var d in participantes) {
                            final nome = d['nome']?.toString() ?? '';
                            final text = faturadoControllers[nome]?.text ?? '';
                            final val = double.tryParse(text.replaceAll('.', '').replaceAll(',', '.')) ?? 0;
                            total += val;
                          }
                          setState(() {
                            _qtdFaturadaCtrl.text = _fmt.format(total.toInt());
                            _atualizarCalculos();
                          });
                          // Se já existe um bombeio salvo, persiste quantidades_faturadas imediatamente
                          if (_bombeioLocal != null) {
                            final Map<String, double> qm = {};
                            for (var d in participantes) {
                              final nome = d['nome']?.toString() ?? '';
                              final text = faturadoControllers[nome]?.text ?? '';
                              final val = double.tryParse(text.replaceAll('.', '').replaceAll(',', '.')) ?? 0;
                              if (val != 0) qm[nome] = val;
                            }
                            try {
                              final supabase = Supabase.instance.client;
                              await supabase
                                  .from('bombeios')
                                  .update({'quantidades_faturadas': qm.isNotEmpty ? qm : null})
                                  .eq('id', _bombeioLocal!['id']);
                              // Atualiza o objeto local com a nova propriedade
                              setState(() {
                                if (qm.isNotEmpty) {
                                  _bombeioLocal!['quantidades_faturadas'] = qm;
                                } else {
                                  _bombeioLocal!.remove('quantidades_faturadas');
                                }
                              });
                            } catch (e) {
                              debugPrint('Erro ao salvar quantidades_faturadas: $e');
                            }
                          }
                          Navigator.of(context).pop(true);
                        },
                        child: const Text('SALVAR'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result == true) {
      // opcional: marcar que há faturamento preenchido
    }
  }

  Future<void> _salvarBombeio({
    bool fecharDialog = true,
    bool showMessage = true,
  }) async {
    if (_selectedTanque == null || dataCtrl.text.isEmpty) {
      await _showStyledDialog(
        title: 'Campos obrigatórios',
        message: 'Preencha os campos obrigatórios (Data e Tanque)',
        headerColor: Colors.red,
        icon: Icons.error,
        barrierDismissible: true,
      );
      return;
    }

    setState(() => salvando = true);

    try {
      final supabase = Supabase.instance.client;

      // Formatar data (dd/MM/yyyy -> yyyy-MM-dd)
      String dataIso = '';
      if (dataCtrl.text.length == 10) {
        final d = dataCtrl.text.split('/');
        dataIso = '${d[2]}-${d[1]}-${d[0]}';
      }

      // Formatar horário (HH:mm h -> HH:mm)
      String horarioIso = horarioCtrl.text.replaceAll(' h', '');

      // Coletar volumes solicitados
      final Map<String, double> volumes = {};
      double total = 0;
      for (var d in _distribuidoras) {
        final nome = d['nome']?.toString() ?? '';
        if (selecionadas[nome] == true) {
          final val = double.tryParse(
                (controllers[nome]?.text ?? '')
                    .replaceAll('.', '')
                    .replaceAll(',', '.'),
              ) ??
              0;
          // Não incluir participantes com quantidade zero — zero significa
          // que não participa do bombeio.
          if (val != 0) {
            volumes[nome] = val;
            total += val;
          }
        }
      }

      final double? parsedQtdFaturada = double.tryParse(
        _qtdFaturadaCtrl.text.replaceAll('.', '').replaceAll(',', '.'),
      );
      final double? qtdFaturadaFinal =
          (parsedQtdFaturada != null && parsedQtdFaturada > 0)
          ? parsedQtdFaturada
          : null;

      final payload = {
        'terminal_id': terminalId,
        'empresa_id': empresaId,
        'tanque_id': _selectedTanque!['id'],
        'data': dataIso.isNotEmpty ? dataIso : null,
        'horario': horarioIso.isNotEmpty ? horarioIso : null,
        'medicao_inicial_id': _medicaoInicialSalva?['id'],
        'medicao_final_id': _medicaoFinalSalva?['id'],
        'volumes_solicitados': volumes,
        'total_bombeio': total,
        'qtd_faturada': qtdFaturadaFinal,
        'quantidades_faturadas': ((){
          final Map<String, double> qm = {};
          for (var d in _distribuidoras) {
            final nome = d['nome']?.toString() ?? '';
            if (selecionadas[nome] == true) {
              final text = faturadoControllers[nome]?.text ?? '';
              final val = double.tryParse(text.replaceAll('.', '').replaceAll(',', '.')) ?? 0;
              if (val != 0) qm[nome] = val;
            }
          }
          return qm.isNotEmpty ? qm : null;
        })(),
      };

      if (_bombeioLocal != null) {
        final response = await supabase
            .from('bombeios')
            .update(payload)
            .eq('id', _bombeioLocal!['id'])
            .select()
            .single();
        setState(() {
          _bombeioLocal = response;
        });
      } else {
        final response = await supabase
            .from('bombeios')
            .insert(payload)
            .select()
            .single();
        setState(() {
          _bombeioLocal = response;
        });
      }

      // Atualiza o total de referência para o novo valor salvo
      _totalVolumesNoInicio = total;

      // Inserir registros em movimentacoes_tanque correspondentes aos volumes solicitados
      try {
        if (volumes.isNotEmpty) {
          final tanqueId = _selectedTanque?['id']?.toString() ?? _bombeioLocal?['tanque_id']?.toString();
          String? produtoId = _selectedTanque?['produto_id']?.toString() ?? _bombeioLocal?['produto_id']?.toString();

          final String dataMov = _bombeioLocal?['data'] is DateTime
              ? (_bombeioLocal!['data'] as DateTime).toIso8601String()
              : (DateTime.tryParse(_bombeioLocal?['data']?.toString() ?? '')?.toIso8601String() ?? DateTime.now().toIso8601String());

          final List<Map<String, dynamic>> inserts = [];
          for (var e in volumes.entries) {
            final nomeRaw = e.key.toString();
            final solicit = (e.value as double?) ?? 0.0;

            String? empresaIdResolved;
            final looksLikeUuid = nomeRaw.length == 36 && nomeRaw.contains('-');
            if (looksLikeUuid) {
              empresaIdResolved = nomeRaw;
            } else if (nomeRaw.isNotEmpty) {
              try {
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
                empresaIdResolved = emp?['id']?.toString();
              } catch (_) {
                empresaIdResolved = null;
              }
            }

            final row = buildRateioMovimentacaoRow(
              tanqueId: tanqueId,
              produtoId: produtoId,
              bombeioId: _bombeioLocal?['id']?.toString(),
              dataMov: dataMov,
              entradaAmb: solicit.round(),
              entradaVinte: 0,
              empresaId: empresaIdResolved,
              terminalId: terminalId,
            );

            // Tenta atualizar registro existente por bombeio_id + empresa_id
            bool updated = false;
            try {
              final bombeioId = _bombeioLocal?['id']?.toString();
              if (bombeioId != null && bombeioId.isNotEmpty) {
                if (empresaIdResolved != null && empresaIdResolved.isNotEmpty) {
                  final resp = await supabase
                      .from('movimentacoes_tanque')
                      .update(row)
                      .eq('bombeio_id', bombeioId)
                      .eq('empresa_id', empresaIdResolved)
                      .select();
                  if (resp.isNotEmpty) {
                    updated = true;
                  }
                } else {
                  // empresa_id não resolvida: tenta achar registro existente com bombeio_id e empresa_id NULL
                    final found = await supabase
                      .from('movimentacoes_tanque')
                      .select('id')
                      .eq('bombeio_id', bombeioId)
                      .filter('empresa_id', 'is', 'null')
                      .limit(1);
                  if (found.isNotEmpty) {
                    final id = found[0]['id'];
                    await supabase
                        .from('movimentacoes_tanque')
                        .update(row)
                        .eq('id', id);
                    updated = true;
                  }
                }
              }
            } catch (_) {
              updated = false;
            }

            if (!updated) {
              inserts.add(row);
            }
          }

          if (inserts.isNotEmpty) {
            await supabase.from('movimentacoes_tanque').insert(inserts);
          }
        }
      } catch (e) {
        debugPrint('Erro ao inserir movimentacoes_tanque ao salvar bombeio: $e');
      }

      if (mounted) {
        // Quando pediram para exibir mensagem e não fechar o diálogo,
        // mantemos o comportamento existente (mostrando um diálogo de confirmação).
        if (showMessage && !fecharDialog) {
          // Mostra o diálogo já existente para "Salvar quantidades"
          await showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (context) => Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFF0D47A1), width: 1),
              ),
              child: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFF0D47A1),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(9),
                        ),
                      ),
                      child: Row(
                        children: const [
                          Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Bombeio salvo',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Quantidades salvas!',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade800,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(9),
                        ),
                        border: Border(
                          top: BorderSide(
                            color: Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 150,
                            child: ElevatedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0D47A1),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              child: const Text(
                                'OK',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Se o diálogo precisa ser fechado, retornamos um resultado ao chamador
        // indicando se devemos abrir a tela de detalhes (o chamador fará a navegação
        // usando o contexto correto).
        if (fecharDialog) {
          final qtdFaturada = _bombeioLocal?['qtd_faturada'];
          final bool temQtdFaturada =
              qtdFaturada != null &&
              qtdFaturada.toString().trim().isNotEmpty &&
              qtdFaturada != 0;
          final bool temMedicaoInicial =
              _bombeioLocal?['medicao_inicial_id'] != null &&
              _bombeioLocal!['medicao_inicial_id'].toString().trim().isNotEmpty;
          final bool temMedicaoFinal =
              _bombeioLocal?['medicao_final_id'] != null &&
              _bombeioLocal!['medicao_final_id'].toString().trim().isNotEmpty;
          final bool abrirDetalhes =
              _bombeioLocal != null &&
              temQtdFaturada &&
              temMedicaoInicial &&
              temMedicaoFinal;

          Navigator.pop(context, {
            'abrirDetalhes': abrirDetalhes,
            'id': _bombeioLocal != null ? _bombeioLocal!['id'] : null,
            'bombeio_id': _bombeioLocal != null ? _bombeioLocal!['id'] : null,
          });
        }
      }
    } catch (e) {
      if (mounted) {
        await _showStyledDialog(
          title: 'Erro ao salvar bombeio',
          message: 'Erro ao salvar bombeio: $e',
          headerColor: Colors.red,
          icon: Icons.error,
        );
      }
    } finally {
      if (mounted) setState(() => salvando = false);
    }
  }

  Future<void> _showStyledDialog({
    required String title,
    required String message,
    Color headerColor = const Color(0xFF0D47A1),
    IconData icon = Icons.check_circle,
    bool barrierDismissible = true,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: headerColor, width: 1),
        ),
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: headerColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(9),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(icon, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade800,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(9),
                  ),
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade300, width: 1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 150,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: headerColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text(
                          'OK',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _validarData(String v) {
    setState(() {
      if (v.isEmpty) {
        dataInvalida = false;
      } else {
        dataInvalida = !_isDataValida(v);
      }
    });
  }

  bool _isDataValida(String v) {
    if (v.length != 10) return false;
    final dateRegExp = RegExp(r'^\d{2}/\d{2}/\d{4}$');
    if (!dateRegExp.hasMatch(v)) return false;

    try {
      // Usar parseStrict para garantir que a data existe (ex: não aceita 31/02)
      DateTime dataDigitada = DateFormat('dd/MM/yyyy').parseStrict(v);
      DateTime hoje = DateTime.now();
      DateTime hojeMeiaNoite = DateTime(hoje.year, hoje.month, hoje.day);
      DateTime limitePassado = hojeMeiaNoite.subtract(const Duration(days: 2));
      DateTime limiteFuturo = hojeMeiaNoite.add(const Duration(days: 7));
      return !dataDigitada.isBefore(limitePassado) &&
          !dataDigitada.isAfter(limiteFuturo);
    } catch (_) {
      return false;
    }
  }

  String _aplicarMascaraHorario(String texto, String valorAntigo) {
    String apenasNumeros = texto.replaceAll(RegExp(r'[^\d]'), '');
    if (apenasNumeros.length > 4) apenasNumeros = apenasNumeros.substring(0, 4);
    if (apenasNumeros.isEmpty) return '';

    String resultado = '';
    for (int i = 0; i < apenasNumeros.length; i++) {
      if (i == 2) resultado += ':';
      resultado += apenasNumeros[i];
    }
    return '$resultado h';
  }

  String _aplicarMascaraData(String texto, String valorAntigo) {
    if (texto.length < valorAntigo.length) return texto;
    String apenasNumeros = texto.replaceAll(RegExp(r'[^\d]'), '');
    if (apenasNumeros.length > 8) apenasNumeros = apenasNumeros.substring(0, 8);
    String resultado = '';
    for (int i = 0; i < apenasNumeros.length; i++) {
      if (i == 2 || i == 4) resultado += '/';
      resultado += apenasNumeros[i];
    }
    return resultado;
  }

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

  Widget _buildMedicaoDisplay(
    Map<String, dynamic> medicao,
    Color color, {
    bool isFinal = false,
  }) {
    final bool podeEditar = !_isReadOnly && _bombeioLocal?['qtd_faturada'] == null;

    // Resolve referência do tanque para exibição (lógica simples e leve):
    String tanqueDisplay = '-';
    var ref = medicao['tanques']?['referencia'] ?? medicao['tanque_referencia'] ?? medicao['tanque'];
    if (ref == null || ref.toString().trim().isEmpty) {
      // tenta obter id/uuid do tanque e buscar na lista _tanques
      var idVal = medicao['tanque_id'] ?? medicao['tanques']?['id'] ?? medicao['tanque'];
      if (idVal != null && _tanques.isNotEmpty) {
        final match = _tanques.firstWhere(
          (t) => t['id']?.toString() == idVal.toString(),
          orElse: () => <String, dynamic>{},
        );
        if (match.isNotEmpty) ref = match['referencia'];
      }
    }
    tanqueDisplay = (ref?.toString() ?? '-');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (podeEditar)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 22, color: color),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onSelected: (val) {
                if (val == 'delete') {
                  _excluirMedicao(medicao, isFinal);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text(
                        'Excluir medição',
                        style: TextStyle(fontSize: 13, color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ],
            )
          else
            const SizedBox(width: 32),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildColumnInfo('Cód.', medicao['num_controle'] ?? '-'),
                _buildColumnInfo('Tanque', tanqueDisplay),
                _buildColumnInfo('Data', _formatarDataIso(medicao['data'])),
                _buildColumnInfo('Hora', _formatarHorario(medicao['horario'])),
                _buildColumnInfo(
                  'Vol. Amb.',
                  '${_fmt.format((medicao['volume_ambiente'] as num?)?.toInt() ?? 0)} L',
                ),
                _buildColumnInfo(
                  'Vol. 20ºC',
                  '${_fmt.format((medicao['volume_20'] as num?)?.toInt() ?? 0)} L',
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  Widget _buildColumnInfo(String label, String value) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF0D47A1),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double totalGeral = 0;
    for (var d in _distribuidoras) {
      final nome = d['nome']?.toString() ?? '';
      if (selecionadas[nome] == true) {
        final text = (controllers[nome]?.text ?? '')
            .replaceAll('.', '')
            .replaceAll(',', '.');
        totalGeral += double.tryParse(text) ?? 0;
      }
    }

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF0D47A1), width: 1),
      ),
      title: Column(
        children: [
          const Text(
            'Inserir dados do bombeio',
            style: TextStyle(
              color: Color(0xFF0D47A1),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFE0E0E0)),
        ],
      ),
      content: SizedBox(
        width: 700,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Row(
                children: [
                  SizedBox(
                    width: 125,
                    child: TextField(
                      controller: dataCtrl,
                      focusNode: _dataFocusNode,
                      keyboardType: TextInputType.number,
                      readOnly: _temMedicoes || _isReadOnly,
                      style: TextStyle(
                        color: dataInvalida ? Colors.red : Colors.black87,
                      ),
                      onTap: _temMedicoes
                          ? null
                          : () {
                              // Preserve existing content so the user can edit it.
                              // Initialize the previous-value tracker to current text
                              // so the masking logic behaves correctly while editing.
                              valorAntigoData = dataCtrl.text;
                            },
                      onChanged: (v) {
                        String formatado = _aplicarMascaraData(
                          v,
                          valorAntigoData,
                        );
                        valorAntigoData = formatado;
                        dataCtrl.value = TextEditingValue(
                          text: formatado,
                          selection: TextSelection.collapsed(
                            offset: formatado.length,
                          ),
                        );
                        setState(() {});
                      },
                      decoration: InputDecoration(
                        labelText: 'Data',
                        labelStyle: TextStyle(
                          color: dataInvalida ? Colors.red : null,
                        ),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: dataInvalida ? Colors.red : Colors.grey,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: dataInvalida ? Colors.red : Colors.grey,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: dataInvalida
                                ? Colors.red
                                : const Color(0xFF0D47A1),
                            width: 2,
                          ),
                        ),
                        isDense: true,
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: horarioCtrl,
                      keyboardType: TextInputType.number,
                      readOnly: _temMedicoes || _isReadOnly,
                      onChanged: (v) {
                        String formatado = _aplicarMascaraHorario(
                          v,
                          valorAntigoHorario,
                        );
                        if (v != formatado) {
                          int offset = formatado.indexOf(' h');
                          if (offset == -1) offset = formatado.length;
                          horarioCtrl.value = TextEditingValue(
                            text: formatado,
                            selection: TextSelection.collapsed(offset: offset),
                          );
                        }
                        valorAntigoHorario = formatado;
                        setState(() {});
                      },
                      decoration: const InputDecoration(
                        labelText: 'Horário',
                        border: OutlineInputBorder(),
                        isDense: true,
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<Map<String, dynamic>>(
                      value: _selectedTanque,
                      isExpanded: true,
                      // limita a altura do menu para permitir rolagem quando muitos itens
                      menuMaxHeight: 300,
                      decoration: const InputDecoration(
                        labelText: 'Tanque',
                        border: OutlineInputBorder(),
                        isDense: true,
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      items: _tanques.map((t) {
                        var prod = t['produtos'];
                        if (prod is List)
                          prod = prod.isNotEmpty ? prod[0] : null;
                        final prodName = (prod is Map)
                            ? (prod['nome_dois'] ?? prod['nome'] ?? '')
                            : '';
                        final display =
                            '${t['referencia'] ?? ''}${prodName.isNotEmpty ? ' - $prodName' : ''}';
                        return DropdownMenuItem<Map<String, dynamic>>(
                          value: t,
                          child: Text(
                            display,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (_temMedicoes || _isReadOnly)
                          ? null
                          : (val) {
                              setState(() {
                                _selectedTanque = val;
                                var prod = val?['produtos'];
                                if (prod is List)
                                  prod = prod.isNotEmpty ? prod[0] : null;
                                _produtoNome = (prod is Map)
                                    ? (prod['nome_dois'] ??
                                          prod['nome'] ??
                                          'Sem produto')
                                    : 'Sem produto';
                                _produtoCtrl.text = _produtoNome;
                              });
                            },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _produtoCtrl,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Produto',
                        border: OutlineInputBorder(),
                        isDense: true,
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Selecione as distribuidoras participantes:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _distribuidoras.map((d) {
                  final String nome = d['nome']?.toString() ?? '';
                  final bool isSelected = selecionadas[nome] == true;
                  return FilterChip(
                    label: Text(
                      nome,
                      style: TextStyle(
                        fontSize: 13,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: const Color(0xFF0D47A1),
                    checkmarkColor: Colors.white,
                    onSelected: (_temMedicoes || _isReadOnly)
                        ? null
                        : (val) {
                            setState(() {
                              selecionadas[nome] = val;
                            });
                          },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              if (selecionadas.values.any((v) => v)) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Volumes solicitados (L):',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ..._distribuidoras
                              .where((d) => selecionadas[d['nome']] == true)
                              .map((d) {
                                final String nome = d['nome']?.toString() ?? '';
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: SizedBox(
                                    width: 200,
                                    child: TextField(
                                      controller: controllers[nome],
                                      keyboardType: TextInputType.number,
                                      readOnly: _temMedicoes || _isReadOnly,
                                      onChanged: (_) => setState(() {}),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(7),
                                        ThousandSeparatorInputFormatter(),
                                      ],
                                      decoration: InputDecoration(
                                        labelText: nome,
                                        border: const OutlineInputBorder(),
                                        isDense: true,
                                        floatingLabelBehavior:
                                            FloatingLabelBehavior.always,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 12,
                                            ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          const Text(
                            'Distribuição de Volume',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 180,
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 30,
                                sections: _distribuidoras
                                    .where(
                                      (d) => selecionadas[d['nome']] == true,
                                    )
                                    .map((d) {
                                      final String nome =
                                          d['nome']?.toString() ?? '';
                                      final text =
                                          (controllers[nome]?.text ?? '')
                                              .replaceAll('.', '')
                                              .replaceAll(',', '.');
                                      final double val =
                                          double.tryParse(text) ?? 0;
                                      final double percent = totalGeral > 0
                                          ? (val / totalGeral) * 100
                                          : 0;
                                      final int idx = _distribuidoras.indexOf(
                                        d,
                                      );
                                      final colors = [
                                        const Color(0xFF0D47A1),
                                        const Color(0xFFD32F2F),
                                        const Color(0xFF388E3C),
                                        const Color(0xFFFBC02D),
                                      ];
                                      return PieChartSectionData(
                                        color: colors[idx % colors.length],
                                        value: val > 0 ? val : 1,
                                        title: val > 0
                                            ? '${_fmt.format(val.toInt())}\n${percent.toStringAsFixed(0)}%'
                                            : '',
                                        radius: 60,
                                        titleStyle: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          height: 1.2,
                                        ),
                                        titlePositionPercentageOffset: 0.55,
                                      );
                                    })
                                    .toList(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            children: _distribuidoras
                                .where((d) => selecionadas[d['nome']] == true)
                                .map((d) {
                                  final int idx = _distribuidoras.indexOf(d);
                                  final colors = [
                                    const Color(0xFF0D47A1),
                                    const Color(0xFFD32F2F),
                                    const Color(0xFF388E3C),
                                    const Color(0xFFFBC02D),
                                  ];
                                  final String nome =
                                      d['nome']?.toString() ?? '';
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: colors[idx % colors.length],
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        nome,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  );
                                })
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Quantidade total do bombeio: ${_fmt.format(totalGeral.toInt())} litros',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                  ),
                ),
                const SizedBox(height: 12),
                if (selecionadas.values.any((v) => v))
                  ElevatedButton.icon(
                    onPressed: _isReadOnly
                        ? null
                        : (_validarBasico &&
                              totalGeral.round() !=
                                  _totalVolumesNoInicio.round())
                        ? () => _salvarBombeio(fecharDialog: false)
                        : null,
                    icon: const Icon(Icons.save, size: 18),
                    label: const Text('Salvar quantidades'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isReadOnly
                          ? Colors.grey[300]
                          : Colors.blue[50],
                      foregroundColor: _isReadOnly
                          ? Colors.grey[600]
                          : const Color(0xFF0D47A1),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: _isReadOnly
                              ? Colors.grey[400]!
                              : const Color(0xFF0D47A1),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                const Divider(height: 1, color: Color(0xFFBDBDBD)),
                const SizedBox(height: 16),
                if (_medicaoInicialSalva == null)
                  ElevatedButton.icon(
                    onPressed: (_temQuantidadesSalvas && !_isReadOnly)
                        ? () => _abrirDialogOInserirMedicao(isFinal: false)
                        : null,
                    icon: const Icon(Icons.straighten, size: 18),
                    label: const Text('Inserir medição inicial'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (_isReadOnly || !_temQuantidadesSalvas)
                          ? Colors.grey[300]
                          : Colors.grey[200],
                      foregroundColor: (_isReadOnly || !_temQuantidadesSalvas)
                          ? Colors.grey[600]
                          : const Color(0xFF0D47A1),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: (_isReadOnly || !_temQuantidadesSalvas)
                              ? Colors.grey[400]!
                              : const Color(0xFF0D47A1),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                if (_medicaoInicialSalva != null) ...[
                  const Text(
                    'MEDIÇÃO INICIAL',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D47A1),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildMedicaoDisplay(
                    _medicaoInicialSalva!,
                    const Color(0xFF0D47A1),
                    isFinal: false,
                  ),
                  if (_medicaoFinalSalva == null) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isReadOnly
                          ? null
                          : () => _abrirDialogOInserirMedicao(isFinal: true),
                      icon: const Icon(Icons.straighten, size: 18),
                      label: const Text('Inserir medição final'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isReadOnly
                            ? Colors.grey[300]
                            : Colors.orange[50],
                        foregroundColor: _isReadOnly
                            ? Colors.grey[600]
                            : Colors.orange[900],
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: _isReadOnly
                                ? Colors.grey[400]!
                                : Colors.orange[900]!,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ],
                if (_medicaoFinalSalva != null) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'MEDIÇÃO FINAL',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE65100),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildMedicaoDisplay(
                    _medicaoFinalSalva!,
                    Colors.orange[900]!,
                    isFinal: true,
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFBDBDBD)),
                  const SizedBox(height: 12),
                  const Text(
                    'Análise de Recebimento e Faturamento:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _recebidaAmbCtrl,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Rcb. (amb)',
                            border: OutlineInputBorder(),
                            isDense: true,
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D47A1),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _recebida20Ctrl,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Rcb. (20ºC)',
                            border: OutlineInputBorder(),
                            isDense: true,
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D47A1),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _qtdFaturadaCtrl,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: 'Faturado (L)',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  floatingLabelBehavior: FloatingLabelBehavior.always,
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 38,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                onPressed: _isReadOnly
                                    ? null
                                    : () => _abrirDialogFaturadoDistribuidoras(),
                                icon: const Icon(Icons.edit, size: 20),
                                tooltip: 'Editar faturado por distribuidora',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _difFaturadoCtrl,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Dif. fat/rcb (20º)',
                            border: OutlineInputBorder(),
                            isDense: true,
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                          ),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _difColor,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: salvando ? null : () => Navigator.pop(context),
          child: const Text(
            'VOLTAR',
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
          ),
        ),
        ElevatedButton(
          onPressed: (_podeSalvar && !_isReadOnly) ? _salvarBombeio : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: (_isReadOnly)
                ? Colors.grey[400]
                : const Color(0xFF0D47A1),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: salvando
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  'SALVAR',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }
}

extension DoublePrecision on double {
  double roundToDouble() => (this * 100).round() / 100;
}
