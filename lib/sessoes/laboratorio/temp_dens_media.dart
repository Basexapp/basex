import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_page.dart';

class PlacaMascaraFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var texto = newValue.text.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();

    // Limitar a 7 caracteres alfanuméricos (ABC1234)
    if (texto.length > 7) {
      texto = texto.substring(0, 7);
    }

    String resultado = '';
    for (int i = 0; i < texto.length; i++) {
      if (i < 3) {
        // Primeiros 3 devem ser letras
        if (RegExp(r'[A-Z]').hasMatch(texto[i])) {
          resultado += texto[i];
        }
      } else {
        // Restantes podem ser letras ou números
        resultado += texto[i];
      }
    }

    // Adicionar hífen automático após o 3º caractere
    if (resultado.length > 3) {
      resultado = '${resultado.substring(0, 3)}-${resultado.substring(3)}';
    }

    return TextEditingValue(
      text: resultado,
      selection: TextSelection.collapsed(offset: resultado.length),
    );
  }
}

class VirgulaAutomaticaFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Permitir apenas números
    var texto = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (texto.isEmpty) return newValue.copyWith(text: '');

    String resultado = texto;
    // Adicionar vírgula após o segundo dígito
    if (texto.length > 2) {
      resultado = '${texto.substring(0, 2)},${texto.substring(2)}';
    }

    return TextEditingValue(
      text: resultado,
      selection: TextSelection.collapsed(offset: resultado.length),
    );
  }
}

class TemperaturaDensidadeMediaPage extends StatefulWidget {
  final VoidCallback? onVoltar;

  const TemperaturaDensidadeMediaPage({super.key, this.onVoltar});

  @override
  State<TemperaturaDensidadeMediaPage> createState() =>
      _TemperaturaDensidadeMediaPageState();
}

class _TemperaturaDensidadeMediaPageState
    extends State<TemperaturaDensidadeMediaPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _registros = [];
  bool _carregando = true;
  bool _erro = false;
  String _mensagemErro = '';

  // Variáveis para Paginação
  int _paginaAtual = 0;
  final int _itensPorPagina = 15;

  final TextEditingController _placaController = TextEditingController();
  final ScrollController _verticalScrollController = ScrollController();

  // Controllers para o diálogo
  final TextEditingController _tempAmostraController = TextEditingController();
  final TextEditingController _densidadeObsController = TextEditingController();
  final TextEditingController _tempCtController = TextEditingController();
  final TextEditingController _placaDialogController = TextEditingController();
  final TextEditingController _horarioController = TextEditingController();
  final TextEditingController _dataController = TextEditingController();
  
  // Variáveis para os dropdowns do diálogo
  String? _selectedProdutoId;
  List<Map<String, dynamic>> _produtos = [];
  bool _carregandoProdutos = false;

  @override
  void initState() {
    super.initState();
    _carregarDados();
    _carregarProdutos();
  }

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _placaController.dispose();
    _tempAmostraController.dispose();
    _densidadeObsController.dispose();
    _tempCtController.dispose();
    _placaDialogController.dispose();
    _horarioController.dispose();
    _dataController.dispose();
    super.dispose();
  }

  Future<void> _carregarProdutos() async {
    setState(() {
      _carregandoProdutos = true;
    });

    try {
      final response = await _supabase
          .from('produtos')
          .select('id, nome')
          .order('nome');

      setState(() {
        _produtos = List<Map<String, dynamic>>.from(response);
        _carregandoProdutos = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar produtos: $e');
      setState(() {
        _carregandoProdutos = false;
      });
    }
  }

  Future<void> _carregarDados() async {
    setState(() {
      _carregando = true;
      _erro = false;
      _registros = [];
    });

    try {
      var query = _supabase
          .from('temp_e_dens')
          .select('''
            id,
            data_hora_medicao,
            temp_amostra,
            densid_obs,
            temp_ct,
            placa,
            terminal_id,
            produto_id,
            produtos(nome),
            terminais(nome)
          ''');

      // Aplicar filtro por terminal baseado no usuário logado
      if (UsuarioAtual.instance != null &&
          UsuarioAtual.instance!.nivel < 3 &&
          UsuarioAtual.instance!.terminalId != null) {
        query = query.eq('terminal_id', UsuarioAtual.instance!.terminalId!);
      }

      final resp = await query.order('data_hora_medicao', ascending: false).limit(1000);

      final List<dynamic> lista = resp;

      final registrosTransformados =
          lista.map<Map<String, dynamic>>((row) {
        String produtoNome = '';
        final produto = row['produtos'];
        if (produto is Map<String, dynamic>) {
          produtoNome = produto['nome']?.toString() ?? '';
        }

        String terminalNome = '';
        final terminal = row['terminais'];
        if (terminal is Map<String, dynamic>) {
          terminalNome = terminal['nome']?.toString() ?? '';
        }

        return {
          'id': row['id'],
          'created_at': row['data_hora_medicao'],
          'temp_amostra': row['temp_amostra'],
          'densid_obs': row['densid_obs'],
          'temp_ct': row['temp_ct'],
          'placa': row['placa'],
          'produto_id': row['produto_id'],
          'produto_nome': produtoNome,
          'terminal_id': row['terminal_id'],
          'terminal_nome': terminalNome,
        };
      }).toList();

      setState(() {
        _registros = registrosTransformados;
        _carregando = false;
      });
    } catch (e, stackTrace) {
      debugPrint('❌ ERRO NA CONSULTA');
      debugPrint(e.toString());
      debugPrint(stackTrace.toString());

      setState(() {
        _erro = true;
        _mensagemErro = e.toString();
        _carregando = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar dados: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _salvarRegistro() async {
    // Validações
    if (_selectedProdutoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione um produto'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_dataController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe a data'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_placaDialogController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe a placa'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_horarioController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe o horário da medição'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final tempAmostra = double.tryParse(_tempAmostraController.text.trim().replaceAll(',', '.'));
    if (tempAmostra == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe uma temperatura da amostra válida'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final densidadeObs = double.tryParse(_densidadeObsController.text.trim().replaceAll(',', '.'));
    if (densidadeObs == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe uma densidade observada válida'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final tempCt = double.tryParse(_tempCtController.text.trim().replaceAll(',', '.'));
    if (tempCt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe uma temperatura do CT válida'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Processar data e hora
      final partesData = _dataController.text.split('/');
      final dia = int.parse(partesData[0]);
      final mes = int.parse(partesData[1]);
      final ano = int.parse(partesData[2]);

      final partesHorario = _horarioController.text.split(':');
      final hora = int.parse(partesHorario[0]);
      final minuto = int.parse(partesHorario[1]);
      
      final dataHoraMedicao = DateTime(
        ano,
        mes,
        dia,
        hora,
        minuto,
      );

      final Map<String, dynamic> dados = {
        'temp_amostra': tempAmostra,
        'densid_obs': densidadeObs,
        'temp_ct': tempCt,
        'placa': _placaDialogController.text.trim().toUpperCase(),
        'produto_id': _selectedProdutoId,
        'data_hora_medicao': dataHoraMedicao.toIso8601String(),
      };

      // Adicionar terminal_id se o usuário não for admin
      if (UsuarioAtual.instance != null &&
          UsuarioAtual.instance!.nivel < 3 &&
          UsuarioAtual.instance!.terminalId != null) {
        dados['terminal_id'] = UsuarioAtual.instance!.terminalId;
      }

      await _supabase.from('temp_e_dens').insert(dados);

      // Limpar campos
      _tempAmostraController.clear();
      _densidadeObsController.clear();
      _tempCtController.clear();
      _placaDialogController.clear();
      _horarioController.clear();
      _dataController.clear();
      _selectedProdutoId = null;

      // Recarregar dados
      await _carregarDados();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registro salvo com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro ao salvar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _excluirRegistro(String id) async {
    final confirmar = await showDialog<bool>(
      context: context,
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
                    Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Confirmar exclusão',
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
                child: RichText(
                  textAlign: TextAlign.center,
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: Colors.black,
                    ),
                    children: [
                      TextSpan(
                        text: 'Deseja realmente excluir este registro?\n',
                      ),
                      TextSpan(
                        text: 'Esta ação é irreversível.',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
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
                      width: 120,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          side: BorderSide(color: Colors.grey.shade400),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text(
                          'Voltar',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 120,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text(
                          'Sim, excluir',
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

    if (confirmar != true) return;

    try {
      await _supabase.from('temp_e_dens').delete().eq('id', id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registro excluído com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        _carregarDados();
      }
    } catch (e) {
      debugPrint('Erro ao excluir: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _abrirDialogCadastro() {
    // Resetar campos do diálogo
    _tempAmostraController.clear();
    _densidadeObsController.clear();
    _tempCtController.clear();
    _placaDialogController.clear();
    final agora = DateTime.now();
    _horarioController.text = "${agora.hour.toString().padLeft(2, '0')}:${agora.minute.toString().padLeft(2, '0')}";
    _dataController.text = "${agora.day.toString().padLeft(2, '0')}/${agora.month.toString().padLeft(2, '0')}/${agora.year}";
    setState(() {
      _selectedProdutoId = null;
    });

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            bool camposPreenchidos() {
              return _selectedProdutoId != null &&
                  _dataController.text.trim().isNotEmpty &&
                  _horarioController.text.trim().isNotEmpty &&
                  _placaDialogController.text.trim().isNotEmpty &&
                  _tempAmostraController.text.trim().isNotEmpty &&
                  _densidadeObsController.text.trim().isNotEmpty &&
                  _tempCtController.text.trim().isNotEmpty;
            }

            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
            width: 600,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF0D47A1), width: 1),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabeçalho
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Novo Registro',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Produto, Data e Horário
                Row(
                  children: [
                    // Campo Produto
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Produto *',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildProdutoDropdown(setStateDialog),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Campo Data
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Data *',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () async {
                              DateTime inicial = DateTime.now();
                              try {
                                final partes = _dataController.text.split('/');
                                if (partes.length == 3) {
                                  inicial = DateTime(
                                    int.parse(partes[2]),
                                    int.parse(partes[1]),
                                    int.parse(partes[0]),
                                  );
                                }
                              } catch (_) {}

                              DateTime tempDate = inicial;

                              final picked = await showDialog<DateTime>(
                                context: context,
                                builder: (BuildContext context) {
                                  return Dialog(
                                    backgroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    child: Container(
                                      width: 350,
                                      padding: const EdgeInsets.all(20),
                                      child: StatefulBuilder(
                                        builder: (context, setStateCalendar) {
                                          int? hoveredDay;
                                          return Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(Icons.calendar_today, color: Color(0xFF0D47A1), size: 24),
                                                  const SizedBox(width: 12),
                                                  const Text('Selecionar data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF0D47A1))),
                                                  const Spacer(),
                                                  IconButton(
                                                    icon: const Icon(Icons.close),
                                                    onPressed: () => Navigator.of(context).pop(),
                                                    color: Colors.grey,
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
                                                      icon: const Icon(Icons.chevron_left, color: Color(0xFF0D47A1)),
                                                      onPressed: () {
                                                        setStateCalendar(() {
                                                          tempDate = DateTime(tempDate.year, tempDate.month - 1, 1);
                                                        });
                                                      },
                                                    ),
                                                    Text(
                                                      '${_getMonthName(tempDate.month)} ${tempDate.year}',
                                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF0D47A1)),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(Icons.chevron_right, color: Color(0xFF0D47A1)),
                                                      onPressed: () {
                                                        setStateCalendar(() {
                                                          tempDate = DateTime(tempDate.year, tempDate.month + 1, 1);
                                                        });
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              GridView.count(
                                                shrinkWrap: true,
                                                crossAxisCount: 7,
                                                childAspectRatio: 1.0,
                                                children: ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'].map((day) {
                                                  return Center(child: Text(day, style: const TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.bold)));
                                                }).toList(),
                                              ),
                                              GridView.count(
                                                shrinkWrap: true,
                                                crossAxisCount: 7,
                                                childAspectRatio: 1.0,
                                                children: _getDaysInMonth(tempDate).map((day) {
                                                  final isSelected = day != null && day == tempDate.day;
                                                  final isToday = day != null && day == DateTime.now().day && tempDate.month == DateTime.now().month && tempDate.year == DateTime.now().year;
                                                  return StatefulBuilder(
                                                    builder: (context, setDayState) {
                                                      return MouseRegion(
                                                        cursor: day != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
                                                        onEnter: (_) { if (day != null) { setDayState(() => hoveredDay = day); } },
                                                        onExit: (_) { if (day != null) { setDayState(() => hoveredDay = null); } },
                                                        child: GestureDetector(
                                                          onTap: day != null ? () { setStateCalendar(() { tempDate = DateTime(tempDate.year, tempDate.month, day); }); } : null,
                                                          child: Container(
                                                            margin: const EdgeInsets.all(2),
                                                            decoration: BoxDecoration(
                                                              color: isSelected ? const Color(0xFF0D47A1)
                                                                  : (day != null && hoveredDay == day) ? const Color(0xFF0D47A1).withOpacity(0.1)
                                                                  : isToday ? const Color(0x220D47A1) : Colors.transparent,
                                                              shape: BoxShape.circle,
                                                            ),
                                                            child: Center(child: Text(
                                                              day != null ? day.toString() : '',
                                                              style: TextStyle(
                                                                color: isSelected ? Colors.white : isToday || (day != null && hoveredDay == day) ? const Color(0xFF0D47A1) : Colors.black87,
                                                                fontWeight: isSelected || isToday || (day != null && hoveredDay == day) ? FontWeight.bold : FontWeight.normal,
                                                              ),
                                                            )),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  );
                                                }).toList(),
                                              ),
                                              const SizedBox(height: 20),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                children: [
                                                  TextButton(
                                                    onPressed: () => Navigator.of(context).pop(),
                                                    style: TextButton.styleFrom(foregroundColor: Colors.black87, padding: const EdgeInsets.symmetric(horizontal: 16)),
                                                    child: const Text('CANCELAR'),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  ElevatedButton(
                                                    onPressed: () => Navigator.of(context).pop(tempDate),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: const Color(0xFF0D47A1),
                                                      foregroundColor: Colors.white,
                                                      elevation: 0,
                                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                    ),
                                                    child: const Text('SELECIONAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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

                              if (picked != null) {
                                setStateDialog(() {
                                  _dataController.text =
                                      "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
                                });
                              }
                            },
                            child: AbsorbPointer(
                              child: TextField(
                                controller: _dataController,
                                decoration: InputDecoration(
                                  hintText: 'DD/MM/AAAA',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 12,
                                  ),
                                  suffixIcon: const Icon(Icons.calendar_today, size: 18),
                                ),
                                style: const TextStyle(fontSize: 13, color: Colors.black87),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Campo Horário da Medição
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Horário *',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () async {
                              final TimeOfDay? picked = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.now(),
                              );
                              if (picked != null) {
                                setStateDialog(() {
                                  _horarioController.text =
                                      "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
                                });
                              }
                            },
                            child: AbsorbPointer(
                              child: TextField(
                                controller: _horarioController,
                                decoration: InputDecoration(
                                  hintText: '00:00',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 12,
                                  ),
                                  suffixIcon: const Icon(Icons.access_time, size: 18),
                                ),
                                style: const TextStyle(fontSize: 13, color: Colors.black87),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Campo Placa
                const Text(
                  'Placa *',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _placaDialogController,
                  inputFormatters: [PlacaMascaraFormatter()],
                  maxLength: 8,
                  onChanged: (_) => setStateDialog(() {}),
                  decoration: InputDecoration(
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  style: const TextStyle(fontSize: 13),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 16),
                
                // Campo Temperatura da Amostra
                const Text(
                  'Temperatura da Amostra (°C) *',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _tempAmostraController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [VirgulaAutomaticaFormatter()],
                  maxLength: 4,
                  onChanged: (_) => setStateDialog(() {}),
                  decoration: InputDecoration(
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                
                // Campo Densidade Observada
                const Text(
                  'Densidade Observada (g/cm³) *',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _densidadeObsController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9,]')),
                  ],
                  maxLength: 6,
                  onChanged: (_) => setStateDialog(() {}),
                  decoration: InputDecoration(
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                
                // Campo Temperatura do CT
                const Text(
                  'Temperatura do CT (°C) *',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _tempCtController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [VirgulaAutomaticaFormatter()],
                  maxLength: 4,
                  onChanged: (_) => setStateDialog(() {}),
                  decoration: InputDecoration(
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 24),
                
                // Botões
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: camposPreenchidos() ? () async {
                        Navigator.of(context).pop();
                        await _salvarRegistro();
                      } : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D47A1),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        disabledForegroundColor: Colors.grey.shade500,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('Salvar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
          },
        );
      },
    );
  }

  Widget _buildProdutoDropdown([StateSetter? rebuildDialog]) {
    if (_carregandoProdutos) {
      return const SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          dropdownColor: Colors.white,
          hint: const Text('Selecione um produto'),
          value: _selectedProdutoId,
          items: _produtos.map((produto) {
            return DropdownMenuItem<String>(
              value: produto['id'].toString(),
              child: Text(produto['nome'].toString()),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedProdutoId = value;
            });
            rebuildDialog?.call(() {});
          },
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _registrosFiltrados {
    final placaFiltro = _placaController.text.trim().toLowerCase();

    final filtrados = _registros.where((r) {
      if (placaFiltro.isNotEmpty) {
        final placa = r['placa']?.toString().toLowerCase() ?? '';
        if (!placa.contains(placaFiltro)) return false;
      }

      return true;
    }).toList();

    return filtrados;
  }

  List<Map<String, dynamic>> get _registrosPaginados {
    final filtrados = _registrosFiltrados;
    final totalRegistros = filtrados.length;
    final totalPaginas = totalRegistros > 0 ? (totalRegistros / _itensPorPagina).ceil() : 1;

    if (_paginaAtual >= totalPaginas) {
      _paginaAtual = totalPaginas - 1;
    }

    final inicio = _paginaAtual * _itensPorPagina;
    final fim = (inicio + _itensPorPagina) < totalRegistros
        ? (inicio + _itensPorPagina)
        : totalRegistros;

    if (inicio >= totalRegistros) return [];

    return filtrados.sublist(inicio, fim);
  }

  Map<String, double> _calcularMedias(List<Map<String, dynamic>> registros) {
    if (registros.isEmpty) {
      return {
        'densidade': 0,
        'temp_amostra': 0,
        'temp_ct': 0,
      };
    }

    double somaDensidade = 0;
    double somaTempAmostra = 0;
    double somaTempCt = 0;
    int countDensidade = 0;
    int countTempAmostra = 0;
    int countTempCt = 0;

    for (var r in registros) {
      final densidade = r['densid_obs'];
      if (densidade != null) {
        final valor = double.tryParse(densidade.toString());
        if (valor != null) {
          somaDensidade += valor;
          countDensidade++;
        }
      }

      final tempAmostra = r['temp_amostra'];
      if (tempAmostra != null) {
        final valor = double.tryParse(tempAmostra.toString());
        if (valor != null) {
          somaTempAmostra += valor;
          countTempAmostra++;
        }
      }

      final tempCt = r['temp_ct'];
      if (tempCt != null) {
        final valor = double.tryParse(tempCt.toString());
        if (valor != null) {
          somaTempCt += valor;
          countTempCt++;
        }
      }
    }

    return {
      'densidade': countDensidade > 0 ? somaDensidade / countDensidade : 0,
      'temp_amostra': countTempAmostra > 0 ? somaTempAmostra / countTempAmostra : 0,
      'temp_ct': countTempCt > 0 ? somaTempCt / countTempCt : 0,
    };
  }

  Widget _buildCarregando() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text(
            'Carregando temperatura e densidade...',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErro() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 60,
          ),
          const SizedBox(height: 20),
          const Text(
            'Erro ao carregar dados',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _mensagemErro,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => _carregarDados(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1),
              foregroundColor: Colors.white,
            ),
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  Widget _buildVazio() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.thermostat_outlined,
              size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text(
            'Nenhum registro encontrado',
            style: TextStyle(
              fontSize: 16,
              color: Color.fromARGB(255, 119, 119, 119),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Clique no botão + para adicionar',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade50,
            ),
          ),
        ],
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
      'Dezembro'
    ];
    return months[month - 1];
  }

  List<int?> _getDaysInMonth(DateTime date) {
    final firstDay = DateTime(date.year, date.month, 1);
    final lastDay = DateTime(date.year, date.month + 1, 0);
    final firstWeekday = firstDay.weekday;
    final startOffset = firstWeekday == 7 ? 0 : firstWeekday;
    List<int?> days = [];
    for (int i = 0; i < startOffset; i++) {
      days.add(null);
    }
    for (int i = 1; i <= lastDay.day; i++) {
      days.add(i);
    }
    while (days.length < 42) {
      days.add(null);
    }
    return days;
  }

  Widget _buildPlacaSearchField() {
    return Container(
      width: 200,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(Icons.directions_car, color: Colors.grey.shade600, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _placaController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Filtrar por placa',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          if (_placaController.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.clear, color: Colors.grey.shade600, size: 20),
              onPressed: () {
                _placaController.clear();
                setState(() {});
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando && _registros.isEmpty) {
      return _buildCarregando();
    }

    if (_erro && _registros.isEmpty) {
      return _buildErro();
    }

    final registrosFiltrados = _registrosFiltrados;
    final totalRegistros = registrosFiltrados.length;
    final totalPaginas = totalRegistros > 0 ? (totalRegistros / _itensPorPagina).ceil() : 1;
    final registrosExibidos = _registrosPaginados;
    final medias = _calcularMedias(registrosFiltrados);

    return Scaffold(
      appBar: null,
      body: Column(
        children: [
          // AppBar personalizada
          Container(
            height: kToolbarHeight + MediaQuery.of(context).padding.top,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top,
              left: 16,
              right: 16,
            ),
            color: Colors.white,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: widget.onVoltar,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Temperatura e Densidade Média',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ),
                // Botão +
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  child: FloatingActionButton(
                    onPressed: _abrirDialogCadastro,
                    mini: true,
                    backgroundColor: const Color(0xFF0D47A1),
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                ),
                // Campo de busca por placa
                Container(
                  width: 200,
                  margin: const EdgeInsets.only(right: 12),
                  child: _buildPlacaSearchField(),
                ),
                // Exibir terminal atual para usuários não-admin
                if (UsuarioAtual.instance != null &&
                    UsuarioAtual.instance!.nivel < 3 &&
                    UsuarioAtual.instance!.terminalNome != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.store, color: Colors.grey.shade600, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          UsuarioAtual.instance!.terminalNome!,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Linha divisória
          Container(
            height: 1,
            color: Colors.grey.shade300,
          ),
          // Conteúdo principal
          Expanded(
            child: registrosFiltrados.isEmpty
                ? _buildVazio()
                : Column(
                    children: [
                      Expanded(
                        child: _buildTable(registrosExibidos, medias),
                      ),
                      // Controle de Paginação
                      if (totalPaginas >= 1)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border(top: BorderSide(color: Colors.grey.shade300)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left),
                                onPressed: _paginaAtual > 0
                                    ? () => setState(() => _paginaAtual--)
                                    : null,
                              ),
                              Text(
                                'Página ${_paginaAtual + 1} de $totalPaginas',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right),
                                onPressed: _paginaAtual < totalPaginas - 1
                                    ? () => setState(() => _paginaAtual++)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(List<Map<String, dynamic>> registros, Map<String, double> medias) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(30, 10, 30, 0),
          child: Column(
            children: [
              // Cabeçalho da tabela
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFF222B45),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: const [
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Data/Hora',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Placa',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Produto',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Densidade Obs.',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Temp. Amostra',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Temp. CT',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(
                      width: 50,
                      child: Text(
                        'Ações',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),

              // Linhas de dados
              Expanded(
                child: SingleChildScrollView(
                  controller: _verticalScrollController,
                  child: Column(
                    children: [
                      ...List.generate(registros.length, (index) {
                        final r = registros[index];
                        final isEven = index.isEven;
                        final dataCriacao = r['created_at'] != null
                            ? DateTime.parse(r['created_at'].toString())
                            : null;
                        final dataFormatada = dataCriacao != null
                            ? '${dataCriacao.day.toString().padLeft(2, '0')}/${dataCriacao.month.toString().padLeft(2, '0')}/${dataCriacao.year} ${dataCriacao.hour.toString().padLeft(2, '0')}:${dataCriacao.minute.toString().padLeft(2, '0')}'
                            : '';

                        return Container(
                          color: isEven ? const Color(0xFFF0F1F6) : const Color(0xFFF8F9FA),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  dataFormatada,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  r['placa']?.toString() ?? '',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  r['produto_nome']?.toString() ?? '',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  r['densid_obs'] != null
                                      ? double.tryParse(r['densid_obs'].toString())
                                              ?.toStringAsFixed(3)
                                              .replaceAll('.', ',') ??
                                          r['densid_obs'].toString()
                                      : '',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  r['temp_amostra'] != null
                                      ? double.tryParse(r['temp_amostra'].toString())
                                              ?.toStringAsFixed(1)
                                              .replaceAll('.', ',') ??
                                          r['temp_amostra'].toString()
                                      : '',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  r['temp_ct'] != null
                                      ? double.tryParse(r['temp_ct'].toString())
                                              ?.toStringAsFixed(1)
                                              .replaceAll('.', ',') ??
                                          r['temp_ct'].toString()
                                      : '',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                              SizedBox(
                                width: 50,
                                child: PopupMenuButton<String>(
                                  color: Colors.white,
                                  icon: const Icon(Icons.more_vert, size: 18),
                                  onSelected: (value) {
                                    if (value == 'excluir') {
                                      _excluirRegistro(r['id'].toString());
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'excluir',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, color: Colors.red, size: 18),
                                          SizedBox(width: 8),
                                          Text('Excluir registro', style: TextStyle(fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      // Linha de médias
                      if (registros.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F2FD),
                            border: Border.all(color: const Color(0xFF0D47A1).withOpacity(0.3)),
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(8),
                              bottomRight: Radius.circular(8),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Expanded(
                                flex: 2,
                                child: Center(
                                  child: Text(
                                    'MÉDIAS',
                                    style: TextStyle(
                                      color: Color(0xFF0D47A1),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                              const Expanded(
                                flex: 2,
                                child: SizedBox(),
                              ),
                              const Expanded(
                                flex: 2,
                                child: SizedBox(),
                              ),
                              Expanded(
                                flex: 2,
                                child: Center(
                                  child: Text(
                                    medias['densidade']?.toStringAsFixed(3).replaceAll('.', ',') ?? '0,000',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFF0D47A1),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Center(
                                  child: Text(
                                    medias['temp_amostra']?.toStringAsFixed(1).replaceAll('.', ',') ?? '0,0',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFF0D47A1),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Center(
                                  child: Text(
                                    medias['temp_ct']?.toStringAsFixed(1).replaceAll('.', ',') ?? '0,0',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFF0D47A1),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 50),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}