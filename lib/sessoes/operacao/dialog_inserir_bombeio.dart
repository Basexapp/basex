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
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
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
  const DialogInserirBombeio({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const DialogInserirBombeio(),
    );
  }

  @override
  State<DialogInserirBombeio> createState() => _DialogInserirBombeioState();
}

class _DialogInserirBombeioState extends State<DialogInserirBombeio> {
  final NumberFormat _fmt = NumberFormat.decimalPattern('pt_BR');
  
  UsuarioAtual? get user => UsuarioAtual.instance;

  // Variáveis globais baseadas no usuário
  String? terminalId;
  String? empresaId;
  String? empresaNome;

  List<Map<String, dynamic>> _tanques = [];
  Map<String, dynamic>? _selectedTanque;
  String _produtoNome = '';
  final TextEditingController _produtoCtrl = TextEditingController();

  final List<String> _distribuidorasFixas = [
    'Zema', 'Raízen', 'Sim Distr.', 'Larco Distr.'
  ];

  late final Map<String, bool> selecionadas;
  late final Map<String, TextEditingController> controllers;
  final TextEditingController dataCtrl = TextEditingController();
  final TextEditingController horarioCtrl = TextEditingController();
  String valorAntigoHorario = '';
  String valorAntigoData = '';
  bool dataInvalida = false;
  Map<String, dynamic>? _medicaoInicialSalva;

  @override
  void initState() {
    super.initState();
    // Inicializa variáveis globais do usuário
    if (user != null) {
      terminalId = user!.terminalId;
      empresaId = user!.empresaId;
      empresaNome = user!.empresaNome;
    }
    selecionadas = {for (var d in _distribuidorasFixas) d: false};
    controllers = {for (var d in _distribuidorasFixas) d: TextEditingController()};
    _fetchTanques();
  }

  Future<void> _fetchTanques() async {
    if (terminalId == null) return;
    try {
      final List<dynamic> data = await Supabase.instance.client
          .from('tanques')
          .select('id, referencia, id_produto, produtos(nome)')
          .eq('terminal_id', terminalId as Object);
      
      if (mounted) {
        setState(() {
          _tanques = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      debugPrint('Erro ao buscar tanques: $e');
    }
  }

  void _abrirDialogOInserirMedicao() async {
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
              onSaved: (map) {
                setState(() {
                  _medicaoInicialSalva = map;
                });
              },
            )
          : DialogMedicoesGasol(
              produtoNome: produtoNome,
              tanqueReferencia: tanqueRef,
              data: dataCtrl.text,
              horario: horarioCtrl.text,
              onSaved: (map) {
                setState(() {
                  _medicaoInicialSalva = map;
                });
              },
            ),
    );
  }

  @override
  void dispose() {
    dataCtrl.dispose();
    horarioCtrl.dispose();
    _produtoCtrl.dispose();
    for (var c in controllers.values) c.dispose();
    super.dispose();
  }

  void _validarData(String v) {
    if (v.length == 10) {
      try {
        DateTime dataDigitada = DateFormat('dd/MM/yyyy').parse(v);
        DateTime hoje = DateTime.now();
        DateTime hojeMeiaNoite = DateTime(hoje.year, hoje.month, hoje.day);
        DateTime limitePassado = hojeMeiaNoite.subtract(const Duration(days: 2));
        DateTime limiteFuturo = hojeMeiaNoite.add(const Duration(days: 7));
        if (dataDigitada.isBefore(limitePassado) || dataDigitada.isAfter(limiteFuturo)) {
          dataInvalida = true;
        } else {
          dataInvalida = false;
        }
      } catch (e) {
        dataInvalida = true;
      }
    } else {
      dataInvalida = false;
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

  @override
  Widget build(BuildContext context) {
    double totalGeral = 0;
    for (var d in _distribuidorasFixas) {
      if (selecionadas[d]!) {
        final text = controllers[d]!.text.replaceAll('.', '').replaceAll(',', '.');
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
          const Text('Inserir dados do bombeio', style: TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.bold)),
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
              Row(
                children: [
                  SizedBox(
                    width: 125,
                    child: TextField(
                      controller: dataCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: dataInvalida ? Colors.red : Colors.black87),
                      onTap: () {
                        dataCtrl.clear();
                        setState(() {
                          valorAntigoData = '';
                          dataInvalida = false;
                        });
                      },
                      onChanged: (v) {
                        String formatado = _aplicarMascaraData(v, valorAntigoData);
                        valorAntigoData = formatado;
                        _validarData(formatado);
                        dataCtrl.value = TextEditingValue(
                          text: formatado,
                          selection: TextSelection.collapsed(offset: formatado.length),
                        );
                        setState(() {});
                      },
                      decoration: InputDecoration(
                        labelText: 'Data',
                        labelStyle: TextStyle(color: dataInvalida ? Colors.red : null),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: dataInvalida ? Colors.red : Colors.grey),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: dataInvalida ? Colors.red : Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: dataInvalida ? Colors.red : const Color(0xFF0D47A1),
                            width: 2,
                          ),
                        ),
                        isDense: true,
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: horarioCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (v) {
                        String formatado = _aplicarMascaraHorario(v, valorAntigoHorario);
                        if (v != formatado) {
                          int offset = formatado.indexOf(' h');
                          if (offset == -1) offset = formatado.length;
                          horarioCtrl.value = TextEditingValue(
                            text: formatado,
                            selection: TextSelection.collapsed(offset: offset),
                          );
                        }
                        valorAntigoHorario = formatado;
                      },
                      decoration: const InputDecoration(
                        labelText: 'Horário',
                        border: OutlineInputBorder(),
                        isDense: true,
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: _tanques.map((t) {
                        return DropdownMenuItem<Map<String, dynamic>>(
                          value: t,
                          child: Text(t['referencia'] ?? '', style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedTanque = val;
                          _produtoNome = val?['produtos']?['nome'] ?? 'Sem produto';
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
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Selecione as distribuidoras participantes:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _distribuidorasFixas.map((d) {
                  final bool isSelected = selecionadas[d]!;
                  return FilterChip(
                    label: Text(d, style: TextStyle(fontSize: 13, color: isSelected ? Colors.white : Colors.black87)),
                    selected: isSelected,
                    selectedColor: const Color(0xFF0D47A1),
                    checkmarkColor: Colors.white,
                    onSelected: (val) {
                      setState(() => selecionadas[d] = val);
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
                          const Text('Volumes solicitados (L):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                          const SizedBox(height: 12),
                          ..._distribuidorasFixas.where((d) => selecionadas[d]!).map((d) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: SizedBox(
                                width: 200,
                                child: TextField(
                                  controller: controllers[d],
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => setState(() {}),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(7),
                                    ThousandSeparatorInputFormatter(),
                                  ],
                                  decoration: InputDecoration(
                                    labelText: d,
                                    border: const OutlineInputBorder(),
                                    isDense: true,
                                    floatingLabelBehavior: FloatingLabelBehavior.always,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                          const Text('Distribuição de Volume', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 180,
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 30,
                                sections: _distribuidorasFixas.where((d) => selecionadas[d]!).map((d) {
                                  final text = controllers[d]!.text.replaceAll('.', '').replaceAll(',', '.');
                                  final double val = double.tryParse(text) ?? 0;
                                  final double percent = totalGeral > 0 ? (val / totalGeral) * 100 : 0;
                                  final int idx = _distribuidorasFixas.indexOf(d);
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
                            children: _distribuidorasFixas.where((d) => selecionadas[d]!).map((d) {
                              final int idx = _distribuidorasFixas.indexOf(d);
                              final colors = [
                                const Color(0xFF0D47A1),
                                const Color(0xFFD32F2F),
                                const Color(0xFF388E3C),
                                const Color(0xFFFBC02D),
                              ];
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
                                  Text(d, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
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
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1, color: Color(0xFFE0E0E0)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _abrirDialogOInserirMedicao,
                  icon: const Icon(Icons.straighten, size: 18),
                  label: const Text('Inserir medição inicial'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    foregroundColor: const Color(0xFF0D47A1),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Color(0xFF0D47A1)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                if (_medicaoInicialSalva != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF0D47A1), width: 0.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildInfoColumn('Nº Controle', _medicaoInicialSalva!['num_controle'] ?? '-'),
                        _buildInfoColumn('Data', _formatarDataIso(_medicaoInicialSalva!['data'])),
                        _buildInfoColumn('Horário', _formatarHorario(_medicaoInicialSalva!['horario'])),
                        _buildInfoColumn('Vol. Amb.', '${_fmt.format((_medicaoInicialSalva!['volume_ambiente'] as num?)?.toInt() ?? 0)} L'),
                        _buildInfoColumn('Vol. 20ºC', '${_fmt.format((_medicaoInicialSalva!['volume_20'] as num?)?.toInt() ?? 0)} L'),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('VOLTAR', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0D47A1),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: const Text('SALVAR', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
