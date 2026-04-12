// dialog_cadastro_placas.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum TipoCadastroVeiculo { proprios, terceiros }

class PlacaInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var texto = newValue.text.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();

    if (texto.length > 7) {
      texto = texto.substring(0, 7);
    }

    if (texto.length > 3) {
      texto = '${texto.substring(0, 3)}-${texto.substring(3)}';
    }

    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

class DialogCadastroPlacas extends StatefulWidget {
  final TipoCadastroVeiculo tipoCadastro;

  const DialogCadastroPlacas({
    super.key,
    required this.tipoCadastro,
  });

  @override
  State<DialogCadastroPlacas> createState() => _DialogCadastroPlacasState();
}

class _DialogCadastroPlacasState extends State<DialogCadastroPlacas>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final List<Map<String, dynamic>> _placas = [];
  final List<TextEditingController> _placaControllers = [];
  final List<TextEditingController> _renavamControllers = [];
  final List<TextEditingController> _transportadoraControllers = [];
  final _transportadoraIdController = TextEditingController();
  bool _carregandoTransportadoras = false;
  List<Map<String, dynamic>> _transportadoras = [];
  String? _selectedTransportadoraId;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    _adicionarPlaca();
    if (widget.tipoCadastro == TipoCadastroVeiculo.proprios) {
      _carregarTransportadoraPropria();
    } else {
      _carregarTransportadoras();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (var controller in _placaControllers) {
      controller.dispose();
    }
    for (var controller in _renavamControllers) {
      controller.dispose();
    }
    for (var controller in _transportadoraControllers) {
      controller.dispose();
    }
    _transportadoraIdController.dispose();
    super.dispose();
  }

  Future<void> _carregarTransportadoras() async {
    setState(() => _carregandoTransportadoras = true);
    try {
      final data = await Supabase.instance.client
          .from('transportadoras')
          .select('id, nome')
          .order('nome');
      
      setState(() {
        _transportadoras = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      print('Erro ao carregar transportadoras: $e');
    } finally {
      setState(() => _carregandoTransportadoras = false);
    }
  }

  Future<void> _carregarTransportadoraPropria() async {
    setState(() => _carregandoTransportadoras = true);
    try {
      final propria = await Supabase.instance.client
          .from('transportadoras')
          .select('id, nome')
          .eq('tipo', 'propria')
          .order('nome')
          .limit(1)
          .maybeSingle();

      if (propria == null) {
        if (!mounted) return;
        setState(() {
          _selectedTransportadoraId = null;
          _carregandoTransportadoras = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nenhuma transportadora própria encontrada (tipo = propria).'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      if (!mounted) return;
      final nomePropria = (propria['nome'] ?? '').toString();
      setState(() {
        _selectedTransportadoraId = propria['id'].toString();
        for (final controller in _transportadoraControllers) {
          controller.text = nomePropria;
        }
        _carregandoTransportadoras = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregandoTransportadoras = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao carregar transportadora própria: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _adicionarPlaca() {
    if (widget.tipoCadastro == TipoCadastroVeiculo.proprios && _placas.length >= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No cadastro de veículos, apenas 1 placa por vez.'),
          backgroundColor: Colors.orange[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      );
      return;
    }

    if (_placas.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Limite máximo de 3 placas por veículo'),
          backgroundColor: Colors.orange[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      );
      return;
    }

    setState(() {
      final novaPlaca = {
        'placa': '',
        'renavam': '',
        'transportadora': '',
        'tanques': <int>[],
      };
      _placas.add(novaPlaca);
      _placaControllers.add(TextEditingController());
      _renavamControllers.add(TextEditingController());
      _transportadoraControllers.add(TextEditingController());

      if (widget.tipoCadastro == TipoCadastroVeiculo.proprios) {
        final nomeAtual = _transportadoraControllers.isNotEmpty
            ? (_transportadoraControllers.first.text)
            : '';
        if (nomeAtual.isNotEmpty) {
          _transportadoraControllers.last.text = nomeAtual;
        }
      }
      
      _tabController = TabController(
        length: _placas.length,
        vsync: this,
      );
      _tabController.animateTo(_placas.length - 1);
    });
  }

  void _removerPlaca(int index) {
    if (_placas.length <= 1) return;
    
    setState(() {
      _placaControllers[index].dispose();
      _renavamControllers[index].dispose();
      _transportadoraControllers[index].dispose();
      
      _placaControllers.removeAt(index);
      _renavamControllers.removeAt(index);
      _transportadoraControllers.removeAt(index);
      _placas.removeAt(index);
      
      _tabController = TabController(
        length: _placas.length,
        vsync: this,
      );
    });
  }

  Future<void> _salvarPlacas() async {
    // Validação básica
    for (var i = 0; i < _placas.length; i++) {
      if (_placaControllers[i].text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Placa ${i + 1} é obrigatória'),
            backgroundColor: Colors.orange[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        );
        return;
      }

      final tanques = List<int>.from(_placas[i]['tanques'] ?? []);
      final possuiCompartimentoPreenchido = tanques.any((valor) => valor > 0);

      if (!possuiCompartimentoPreenchido) {
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (context) => Dialog(
            backgroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.blue[900]!, width: 1),
            ),
            child: Container(
              width: 360,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 36,
                    color: Colors.orange[700],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Compartimento não informado',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[900],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Placa ${i + 1}: preencha pelo menos 1 compartimento.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[900],
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: const Text('Ok', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        return;
      }

    }

    setState(() => _salvando = true);

    try {
      final precisaTransportadora = widget.tipoCadastro == TipoCadastroVeiculo.proprios;

      if (precisaTransportadora &&
          (_selectedTransportadoraId == null || _selectedTransportadoraId!.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transportadora não definida para o cadastro.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _salvando = false);
        return;
      }

      final tabelaDestino = widget.tipoCadastro == TipoCadastroVeiculo.proprios
          ? 'equipamentos'
          : 'veiculos_geral';

      for (var i = 0; i < _placas.length; i++) {
        final dados = {
          'placa': _placaControllers[i].text.toUpperCase(),
          'tanques': _placas[i]['tanques'] ?? [],
          'transportadora_id': _selectedTransportadoraId,
          'renavam': _renavamControllers[i].text.isNotEmpty 
              ? _renavamControllers[i].text 
              : null,
        };

        await Supabase.instance.client
      .from(tabelaDestino)
      .insert(dados)
      .select('id')
      .single();
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_placas.length} veículo(s) cadastrado(s) com sucesso'),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _salvando = false);
      }
    }
  }

  void _adicionarTanque(int placaIndex) {
    setState(() {
      if (_placas[placaIndex]['tanques'] == null) {
        _placas[placaIndex]['tanques'] = <int>[];
      }
      (_placas[placaIndex]['tanques'] as List).add(0);
    });
  }

  void _removerTanque(int placaIndex, int tanqueIndex) {
    setState(() {
      (_placas[placaIndex]['tanques'] as List).removeAt(tanqueIndex);
    });
  }

  void _atualizarTanque(int placaIndex, int tanqueIndex, String valor) {
    final numero = int.tryParse(valor);
    if (numero != null) {
      setState(() {
        _placas[placaIndex]['tanques'][tanqueIndex] = numero;
      });
    }
  }

  void _abrirCadastroTransportadora() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => DialogCadastroTransportadora(
        onSalvar: (novoId) async {
          await _carregarTransportadoras();
          setState(() {
            _selectedTransportadoraId = novoId;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool ehProprios = widget.tipoCadastro == TipoCadastroVeiculo.proprios;

    return Dialog(
      backgroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.blue[900]!, width: 1),
      ),
      child: Container(
        width: 800,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                children: [
                  Text(
                    ehProprios ? 'Cadastrar Veículo Próprio' : 'Cadastrar Veículo de Terceiro',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[900],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(30, 30),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),

            if (!ehProprios)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Transportadora Responsável',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _abrirCadastroTransportadora,
                          icon: const Icon(Icons.add, size: 14),
                          label: const Text('Transportadora', style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.blue[900],
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: _carregandoTransportadoras
                          ? const Padding(
                              padding: EdgeInsets.all(10),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  SizedBox(width: 8),
                                  Text('Carregando...', style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            )
                          : DropdownButtonFormField<String>(
                              value: _selectedTransportadoraId,
                              hint: const Text('Selecionar transportadora', style: TextStyle(fontSize: 13)),
                              isExpanded: true,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              items: _transportadoras.map((t) {
                                return DropdownMenuItem<String>(
                                  value: t['id'].toString(),
                                  child: Text(
                                    t['nome'] ?? '--',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                final nomeSelecionado = _transportadoras
                                    .firstWhere(
                                      (t) => t['id'].toString() == value,
                                      orElse: () => {'nome': ''},
                                    )['nome']
                                    .toString();

                                setState(() {
                                  _selectedTransportadoraId = value;
                                  for (final controller in _transportadoraControllers) {
                                    controller.text = nomeSelecionado;
                                  }
                                });
                              },
                            ),
                    ),
                  ],
                ),
              ),

            // Tabs de placas
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      labelColor: Colors.blue[900],
                      unselectedLabelColor: Colors.grey[600],
                      indicatorColor: Colors.blue[900],
                      indicatorSize: TabBarIndicatorSize.label,
                      tabs: List.generate(_placas.length, (index) {
                        return Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Placa ${index + 1}'),
                              if (_placas.length > 1)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: GestureDetector(
                                    onTap: () => _removerPlaca(index),
                                    child: Icon(
                                      Icons.close,
                                      size: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                  if (!ehProprios)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: TextButton.icon(
                        onPressed: _placas.length < 3 ? _adicionarPlaca : null,
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('Placa', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.blue[900],
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Conteúdo das tabs
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: List.generate(_placas.length, (index) {
                  return _buildPlacaTab(index, ehProprios: ehProprios);
                }),
              ),
            ),

            // Footer com botões
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _salvando ? null : () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Cancelar', style: TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _salvando ? null : _salvarPlacas,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[900],
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: _salvando
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Text('Salvar', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlacaTab(int index, {required bool ehProprios}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Campos da placa
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dados da Placa ${index + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[900],
                  ),
                ),
                const SizedBox(height: 12),
                
                // Placa
                TextField(
                  controller: _placaControllers[index],
                  style: const TextStyle(fontSize: 13),
                  maxLength: 8,
                  inputFormatters: [PlacaInputFormatter()],
                  decoration: InputDecoration(
                    label: Text('Placa *', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: Colors.blue[900]!),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    isDense: true,
                    counterText: '',
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 12),
                
                // Documentos - Renavan e Transportadora específica
                Text(
                  'Documentos',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _renavamControllers[index],
                        style: const TextStyle(fontSize: 13),
                        keyboardType: TextInputType.number,
                        maxLength: 15,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          label: Text('Renavan', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(color: Colors.blue[900]!),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          isDense: true,
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _transportadoraControllers[index],
                        style: const TextStyle(fontSize: 13),
                        maxLength: 50,
                        readOnly: true,
                        enabled: false,
                        decoration: InputDecoration(
                          label: Text('Transportadora', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(color: Colors.blue[900]!),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          isDense: true,
                          counterText: '',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Compartimentos
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Compartimentos',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[900],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _adicionarTanque(index),
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text('Compartimento', style: TextStyle(fontSize: 11)),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue[900],
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (_placas[index]['tanques']?.isEmpty ?? true)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Cavalo (sem compartimentos)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  )
                else
                  ...List.generate(
                    (_placas[index]['tanques'] as List).length,
                    (tanqueIndex) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                style: const TextStyle(fontSize: 13),
                                keyboardType: TextInputType.number,
                                maxLength: 2,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                onChanged: (value) => _atualizarTanque(index, tanqueIndex, value),
                                decoration: InputDecoration(
                                  label: Text(
                                    'Compartimento ${tanqueIndex + 1} (m³)',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide: BorderSide(color: Colors.grey[300]!),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide: BorderSide(color: Colors.grey[300]!),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide: BorderSide(color: Colors.blue[900]!),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  isDense: true,
                                  counterText: '',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () => _removerTanque(index, tanqueIndex),
                              style: IconButton.styleFrom(
                                foregroundColor: Colors.grey[600],
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(30, 30),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==============================
// DIALOG DE CADASTRO DE TRANSPORTADORA
// ==============================
class DialogCadastroTransportadora extends StatefulWidget {
  final Function(String) onSalvar;

  const DialogCadastroTransportadora({
    super.key,
    required this.onSalvar,
  });

  @override
  State<DialogCadastroTransportadora> createState() => _DialogCadastroTransportadoraState();
}

class _DialogCadastroTransportadoraState extends State<DialogCadastroTransportadora> {
  final _nomeController = TextEditingController();
  final _cnpjController = TextEditingController();
  final _inscricaoEstadualController = TextEditingController();
  final _telefoneUmController = TextEditingController();
  final _telefoneDoisController = TextEditingController();
  final _nomeDoisController = TextEditingController();
  String? _situacaoSelecionada;
  bool _salvando = false;

  @override
  void dispose() {
    _nomeController.dispose();
    _cnpjController.dispose();
    _inscricaoEstadualController.dispose();
    _telefoneUmController.dispose();
    _telefoneDoisController.dispose();
    _nomeDoisController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_nomeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Nome da transportadora é obrigatório'),
          backgroundColor: Colors.orange[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      );
      return;
    }

    setState(() => _salvando = true);

    try {
      final dados = {
        'nome': _nomeController.text.trim(),
        'cnpj': _cnpjController.text.trim().isNotEmpty ? _cnpjController.text.trim() : null,
        'inscricao_estadual': _inscricaoEstadualController.text.trim().isNotEmpty ? _inscricaoEstadualController.text.trim() : null,
        'telefone_um': _telefoneUmController.text.trim().isNotEmpty ? _telefoneUmController.text.trim() : null,
        'telefone_dois': _telefoneDoisController.text.trim().isNotEmpty ? _telefoneDoisController.text.trim() : null,
        'situacao': _situacaoSelecionada,
        'nome_dois': _nomeDoisController.text.trim().isNotEmpty ? _nomeDoisController.text.trim() : null,
      };

      final resultado = await Supabase.instance.client
          .from('transportadoras')
          .insert(dados)
          .select('id')
          .single();

      if (mounted) {
        Navigator.of(context).pop();
        widget.onSalvar(resultado['id'].toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Transportadora cadastrada com sucesso'),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _salvando = false);
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool obrigatorio = false,
    TextInputType? keyboardType,
    int? maxLength,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 13),
      keyboardType: keyboardType,
      maxLength: maxLength,
      decoration: InputDecoration(
        label: Text(
          obrigatorio ? '$label *' : label,
          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: Colors.blue[900]!),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        isDense: true,
        counterText: '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.blue[900]!, width: 1),
      ),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 550),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                children: [
                  Text(
                    'Nova Transportadora',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[900],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(30, 30),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),

            // Conteúdo
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nome (obrigatório)
                    _buildTextField(
                      controller: _nomeController,
                      label: 'Nome',
                      obrigatorio: true,
                    ),
                    const SizedBox(height: 12),

                    // Nome secundário
                    _buildTextField(
                      controller: _nomeDoisController,
                      label: 'Nome Secundário',
                    ),
                    const SizedBox(height: 12),

                    // CNPJ e Inscrição Estadual
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _cnpjController,
                            label: 'CNPJ',
                            maxLength: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _inscricaoEstadualController,
                            label: 'Inscrição Estadual',
                            maxLength: 20,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Telefones
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _telefoneUmController,
                            label: 'Telefone 1',
                            keyboardType: TextInputType.phone,
                            maxLength: 15,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _telefoneDoisController,
                            label: 'Telefone 2',
                            keyboardType: TextInputType.phone,
                            maxLength: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Situação
                    Text(
                      'Situação',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _situacaoSelecionada,
                        hint: const Text('Selecionar situação', style: TextStyle(fontSize: 13)),
                        isExpanded: true,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Ativa', child: Text('Ativa', style: TextStyle(fontSize: 13))),
                          DropdownMenuItem(value: 'Inativa', child: Text('Inativa', style: TextStyle(fontSize: 13))),
                          DropdownMenuItem(value: 'Suspensa', child: Text('Suspensa', style: TextStyle(fontSize: 13))),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _situacaoSelecionada = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer com botões
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _salvando ? null : () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Voltar', style: TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _salvando ? null : _salvar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[900],
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: _salvando
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Text('Salvar', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}