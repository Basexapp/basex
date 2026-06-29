import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../login_page.dart';
import 'dialog_medicoes_gasol.dart';
import 'dialog_medicoes_alcool.dart';

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
  bool _initialQtdFaturadaEmpty = true;
  bool _initialBothMedicoesExist = false;
  Map<String, dynamic>? _medicaoInicialSalva;
  Map<String, dynamic>? _medicaoFinalSalva;
  Color _difColor = const Color(0xFF0D47A1);

  bool get _temMedicoes =>
      _medicaoInicialSalva != null || _medicaoFinalSalva != null;

  bool get _temQuantidadesSalvas => _totalVolumesNoInicio > 0;

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
        final double val = double.tryParse((controllers[nome]?.text ?? '').replaceAll('.', '').replaceAll(',', '.')) ?? 0;
        if (val > 0) {
          temVolumeSolicitado = true;
          break;
        }
      }
    }
    return temVolumeSolicitado;
  }

  bool get _podeSalvar {
    if (salvando) return false;
    if (!_validarBasico) return false;

    // Se tem inicial mas não tem final -> Desabilita
    if (_medicaoInicialSalva != null && _medicaoFinalSalva == null) {
      return false;
    }

    // Se tem as duas
    if (_medicaoInicialSalva != null && _medicaoFinalSalva != null) {
      // Se já abriu com as duas
      if (_initialBothMedicoesExist) {
        if (_initialQtdFaturadaEmpty) {
          // Abriu vazia -> habilita se preencher agora
          return _qtdFaturadaCtrl.text.isNotEmpty;
        } else {
          // Abriu preenchida -> desabilita (não há o que salvar)
          return false;
        }
      }
      // Se acabou de lançar a segunda medição nesta sessão (ou abriu com faturada vazia e preencheu)
      return true;
    }

    // Caso não tenha nenhuma medição ainda (está criando ou editando dados básicos)
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
        _initialQtdFaturadaEmpty = false;
      }

      if (_medicaoInicialSalva != null && _medicaoFinalSalva != null) {
        _initialBothMedicoesExist = true;
      }
    }

    // Se não há data preenchida (novo bombeio ou sem data), preenche com a data atual
    if (dataCtrl.text.isEmpty) {
      dataCtrl.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
    }

    _fetchTanques();
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

  Future<void> _fetchTanques() async {
    if (terminalId == null) return;
    try {
        final List<dynamic> data = await Supabase.instance.client
          .from('tanques')
          .select('id, referencia, produto_id, produtos(nome)')
          .eq('terminal_id', terminalId as Object)
          .eq('tipo_abastecimento', 'exa');

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
              _produtoNome = _selectedTanque?['produtos']?['nome'] ?? '';
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
          final nome = emp['nome_dois'] ?? emp['nome'] ?? emp['nome_abrev'] ?? id;
          empresasMap[id] = {'id': id, 'nome': nome};
        } else if (r['empresa_id'] != null) {
          final id = r['empresa_id'].toString();
          empresasMap[id] = {'id': id, 'nome': id};
        }
      }

      final List<Map<String, dynamic>> list = empresasMap.values.toList()
        ..sort((a, b) => (a['nome'] ?? '').toString().compareTo((b['nome'] ?? '').toString()));

      setState(() {
        _distribuidoras = list;
        // Inicializa seleções e controllers para cada distribuidora (chave pelo nome)
        selecionadas = {for (var e in _distribuidoras) (e['nome'] as String): false};
        controllers = {for (var e in _distribuidoras) (e['nome'] as String): TextEditingController()};
      });

      // Se abriu com um bombeio existente, aplica volumes/participantes carregados
      if (_bombeioLocal != null) {
        final b = _bombeioLocal!;
        final vsol = b['volumes_solicitados'];
        if (vsol != null && vsol is Map) {
          vsol.forEach((key, value) {
            final String keyStr = key?.toString() ?? '';
            final int idx = _distribuidoras.indexWhere((d) => (d['id']?.toString() == keyStr) || (d['nome']?.toString() == keyStr));
            if (idx != -1) {
              final nome = _distribuidoras[idx]['nome'] as String;
              selecionadas[nome] = true;
              controllers[nome]!.text = _fmt.format((value as num).toDouble());
            }
          });
        }

        if (b['participantes'] != null && b['participantes'] is List) {
          for (var p in b['participantes']) {
            final nomeRaw = p['nome']?.toString() ?? '';
            final solicit = p['solicitado'];
            final int idx = _distribuidoras.indexWhere((d) => (d['id']?.toString() == nomeRaw) || (d['nome']?.toString() == nomeRaw));
            if (idx != -1) {
              final nome = _distribuidoras[idx]['nome'] as String;
              selecionadas[nome] = true;
              controllers[nome]!.text = _fmt.format((solicit as num).toInt());
            }
          }
        }

        // Calcula o total inicial a partir do que foi carregado nos campos da UI
        double totalInicialCalc = 0;
        for (var e in _distribuidoras) {
          final nome = e['nome'] as String;
          if (selecionadas[nome] == true) {
            final text = (controllers[nome]?.text ?? '').replaceAll('.', '').replaceAll(',', '.');
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

  Future<void> _excluirMedicao(Map<String, dynamic> medicao, bool isFinal) async {
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
              style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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
      // 1. Remove o vínculo no bombeio
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

  void _abrirDialogOInserirMedicao({
    bool isFinal = false,
  }) async {
    if (_bombeioLocal == null) return;

    final supabase = Supabase.instance.client;
    bool usarTabelaAlcool = false;
    final produtoNome = _produtoCtrl.text;
    final tanqueRef = _selectedTanque?['referencia'];

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
    for (var c in controllers.values) c.dispose();
    super.dispose();
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
          final val = double.tryParse((controllers[nome]?.text ?? '').replaceAll('.', '').replaceAll(',', '.')) ?? 0;
          volumes[nome] = val;
          total += val;
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
        'num_controle': _bombeioLocal?['num_controle'],
        'data': dataIso.isNotEmpty ? dataIso : null,
        'horario': horarioIso.isNotEmpty ? horarioIso : null,
        'medicao_inicial_id': _medicaoInicialSalva?['id'],
        'medicao_final_id': _medicaoFinalSalva?['id'],
        'volumes_solicitados': volumes,
        'total_bombeio': total,
        'qtd_faturada': qtdFaturadaFinal,
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: const BoxDecoration(
                        color: Color(0xFF0D47A1),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.check_circle, color: Colors.white, size: 20),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(9)),
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
                                backgroundColor: const Color(0xFF0D47A1),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              child: const Text(
                                'OK',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
          final bool abrirDetalhes = _bombeioLocal != null &&
              _bombeioLocal!['medicao_inicial_id'] != null &&
              _bombeioLocal!['medicao_final_id'] != null &&
              _bombeioLocal!['qtd_faturada'] != null;

          Navigator.pop(context, {
            'abrirDetalhes': abrirDetalhes,
            'id': _bombeioLocal != null ? _bombeioLocal!['id'] : null,
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: headerColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(9)),
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
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
    final bool podeEditar = _bombeioLocal?['qtd_faturada'] == null;

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
                      Text('Excluir medição', style: TextStyle(fontSize: 13, color: Colors.red)),
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
        final text = (controllers[nome]?.text ?? '').replaceAll('.', '').replaceAll(',', '.');
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
                      readOnly: _temMedicoes,
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
                      readOnly: _temMedicoes,
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
                        return DropdownMenuItem<Map<String, dynamic>>(
                          value: t,
                          child: Text(
                            t['referencia'] ?? '',
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: _temMedicoes
                          ? null
                          : (val) {
                              setState(() {
                                _selectedTanque = val;
                                _produtoNome =
                                    val?['produtos']?['nome'] ?? 'Sem produto';
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
                    onSelected: _temMedicoes
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
                                      readOnly: _temMedicoes,
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
                                    .where((d) => selecionadas[d['nome']] == true)
                                    .map((d) {
                                      final String nome = d['nome']?.toString() ?? '';
                                      final text = (controllers[nome]?.text ?? '').replaceAll('.', '').replaceAll(',', '.');
                                      final double val = double.tryParse(text) ?? 0;
                                      final double percent = totalGeral > 0 ? (val / totalGeral) * 100 : 0;
                                      final int idx = _distribuidoras.indexOf(d);
                                      final colors = [
                                        const Color(0xFF0D47A1),
                                        const Color(0xFFD32F2F),
                                        const Color(0xFF388E3C),
                                        const Color(0xFFFBC02D),
                                      ];
                                      return PieChartSectionData(
                                        color: colors[idx % colors.length],
                                        value: val > 0 ? val : 1,
                                        title: val > 0 ? '${_fmt.format(val.toInt())}\n${percent.toStringAsFixed(0)}%' : '',
                                        radius: 60,
                                        titleStyle: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          height: 1.2,
                                        ),
                                        titlePositionPercentageOffset: 0.55,
                                      );
                                    }).toList(),
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
                                  final String nome = d['nome']?.toString() ?? '';
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
                                }).toList(),
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
                    onPressed:
                        (_validarBasico &&
                            totalGeral.round() != _totalVolumesNoInicio.round())
                        ? () => _salvarBombeio(fecharDialog: false)
                        : null,
                    icon: const Icon(Icons.save, size: 18),
                    label: const Text('Salvar quantidades'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[50],
                      foregroundColor: const Color(0xFF0D47A1),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Color(0xFF0D47A1)),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                const Divider(height: 1, color: Color(0xFFE0E0E0)),
                const SizedBox(height: 16),
                if (_medicaoInicialSalva == null)
                  ElevatedButton.icon(
                    onPressed: _temQuantidadesSalvas
                        ? () => _abrirDialogOInserirMedicao(isFinal: false)
                        : null,
                    icon: const Icon(Icons.straighten, size: 18),
                    label: const Text('Inserir medição inicial'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _temQuantidadesSalvas
                          ? Colors.grey[200]
                          : Colors.grey[100],
                      foregroundColor: _temQuantidadesSalvas
                          ? const Color(0xFF0D47A1)
                          : Colors.grey,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: _temQuantidadesSalvas
                              ? const Color(0xFF0D47A1)
                              : Colors.grey[300]!,
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
                      onPressed: () =>
                          _abrirDialogOInserirMedicao(isFinal: true),
                      icon: const Icon(Icons.straighten, size: 18),
                      label: const Text('Inserir medição final'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[50],
                        foregroundColor: Colors.orange[900],
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.orange[900]!),
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
                  const SizedBox(height: 24),
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
                        child: TextField(
                          controller: _qtdFaturadaCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) =>
                              setState(() => _atualizarCalculos()),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(7),
                            ThousandSeparatorInputFormatter(),
                          ],
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
          onPressed: _podeSalvar ? _salvarBombeio : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0D47A1),
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
