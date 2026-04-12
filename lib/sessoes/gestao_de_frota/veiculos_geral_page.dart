// veiculos_geral_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ==============================
// FORMATTER PARA PLACA
// ==============================
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

// ==============================
// DIALOG DE EDIÇÃO PARA VEÍCULOS GERAIS
// ==============================
class DialogEditarVeiculoGeral extends StatefulWidget {
  final Map<String, dynamic> veiculo;
  final VoidCallback onAtualizado;

  const DialogEditarVeiculoGeral({
    super.key,
    required this.veiculo,
    required this.onAtualizado,
  });

  @override
  State<DialogEditarVeiculoGeral> createState() => _DialogEditarVeiculoGeralState();
}

class _DialogEditarVeiculoGeralState extends State<DialogEditarVeiculoGeral> {
  late TextEditingController _placaController;
  late TextEditingController _renavamController;
  late TextEditingController _transportadoraController;
  late TextEditingController _transportadoraIdController;
  late List<TextEditingController> _tanqueControllers;
  List<int> _tanques = [];
  String? _selectedTransportadoraId;
  List<Map<String, dynamic>> _transportadoras = [];
  bool _carregandoTransportadoras = false;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _placaController = TextEditingController(text: widget.veiculo['placa'] ?? '');
    _renavamController = TextEditingController(text: widget.veiculo['renavam'] ?? '');
    _transportadoraController = TextEditingController(text: _getNomeTransportadora(widget.veiculo));
    _transportadoraIdController = TextEditingController();
    _selectedTransportadoraId = widget.veiculo['transportadora_id']?.toString();
    _tanques = List<int>.from(widget.veiculo['tanques'] ?? []);
    _tanqueControllers = _tanques
        .map((t) => TextEditingController(text: t.toString()))
        .toList();
    _carregarTransportadoras();
  }

  String _getNomeTransportadora(Map<String, dynamic> v) {
    final t = v['transportadoras'];
    if (t is Map) {
      return t['nome']?.toString() ?? '--';
    }
    return '--';
  }

  @override
  void dispose() {
    _placaController.dispose();
    _renavamController.dispose();
    _transportadoraController.dispose();
    _transportadoraIdController.dispose();
    for (var controller in _tanqueControllers) {
      controller.dispose();
    }
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

  void _adicionarTanque() {
    setState(() {
      _tanques.add(0);
      _tanqueControllers.add(TextEditingController(text: '0'));
    });
  }

  void _removerTanque(int index) {
    setState(() {
      _tanques.removeAt(index);
      _tanqueControllers[index].dispose();
      _tanqueControllers.removeAt(index);
    });
  }

  void _atualizarTanque(int index, String valor) {
    final numero = int.tryParse(valor);
    if (numero != null) {
      _tanques[index] = numero;
    }
  }

  Future<void> _salvar() async {
    if (_placaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Placa é obrigatória'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _salvando = true);

    try {
      final dados = {
        'placa': _placaController.text.toUpperCase(),
        'tanques': _tanques,
        'transportadora_id': _selectedTransportadoraId,
        'renavam': _renavamController.text.isNotEmpty ? _renavamController.text : null,
      };

      await Supabase.instance.client
          .from('veiculos_geral')
          .update(dados)
          .eq('id', widget.veiculo['id']);

      if (mounted) {
        Navigator.of(context).pop();
        widget.onAtualizado();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Veículo atualizado com sucesso'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _salvando = false);
      }
    }
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
                    'Editar Veículo',
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
                    // Transportadora principal
                    Text(
                      'Transportadora Responsável',
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
                              dropdownColor: Colors.white,
                              menuMaxHeight: 500,
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
                                setState(() {
                                  _selectedTransportadoraId = value;
                                });
                              },
                            ),
                    ),

                    const SizedBox(height: 16),

                    // Dados da placa
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
                            'Dados do Veículo',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[900],
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // Placa
                          TextField(
                            controller: _placaController,
                            style: const TextStyle(fontSize: 13),
                            inputFormatters: [PlacaMascaraFormatter()],
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
                            ),
                            textCapitalization: TextCapitalization.characters,
                          ),
                          const SizedBox(height: 12),
                          
                          // Documentos
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
                                  controller: _renavamController,
                                  style: const TextStyle(fontSize: 13),
                                  keyboardType: TextInputType.number,
                                  maxLength: 15,
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
                                  controller: _transportadoraController,
                                  style: const TextStyle(fontSize: 13),
                                  maxLength: 50,
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
                                onPressed: _adicionarTanque,
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

                          if (_tanques.isEmpty)
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
                              _tanques.length,
                              (index) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _tanqueControllers[index],
                                          style: const TextStyle(fontSize: 13),
                                          decoration: InputDecoration(
                                            label: Text('Compartimento ${index + 1} (m³)', 
                                                style: TextStyle(fontSize: 11, color: Colors.grey[700])),
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
                                          ),
                                          keyboardType: TextInputType.number,
                                          onChanged: (value) => _atualizarTanque(index, value),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.close, size: 16),
                                        onPressed: () => _removerTanque(index),
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
              ),
            ),

            // Footer
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

// ==============================
// DIALOG DE CONFIRMAÇÃO DE EXCLUSÃO
// ==============================
class DialogConfirmarExclusao extends StatelessWidget {
  final String placa;
  final VoidCallback onConfirmar;

  const DialogConfirmarExclusao({
    super.key,
    required this.placa,
    required this.onConfirmar,
  });

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
        width: 400,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ícone de alerta
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.red[100]!),
              ),
              child: Icon(
                Icons.warning_rounded,
                color: Colors.red[700],
                size: 24,
              ),
            ),
            const SizedBox(height: 16),
            
            // Título
            Text(
              'Excluir Veículo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.blue[900],
              ),
            ),
            const SizedBox(height: 8),
            
            // Mensagem
            Text(
              'Tem certeza que deseja excluir a placa $placa?',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Esta ação é irreversível',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            
            // Botões
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    child: const Text('Voltar', style: TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onConfirmar();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: const Text('Sim, excluir', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ==============================
// WIDGET DE MENU DE 3 PONTOS
// ==============================
class MenuVeiculoWidget extends StatelessWidget {
  final String placa;
  final VoidCallback onEditar;
  final VoidCallback onExcluir;

  const MenuVeiculoWidget({
    super.key,
    required this.placa,
    required this.onEditar,
    required this.onExcluir,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, size: 18, color: Colors.grey[600]),
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'editar',
          height: 32,
          child: Row(
            children: [
              Icon(Icons.edit, size: 16, color: Colors.blue[900]),
              const SizedBox(width: 8),
              Text('Editar veículo', style: TextStyle(fontSize: 13, color: Colors.grey[800])),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'excluir',
          height: 32,
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 16, color: Colors.red[700]),
              const SizedBox(width: 8),
              Text('Excluir veículo', style: TextStyle(fontSize: 13, color: Colors.grey[800])),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        if (value == 'editar') {
          onEditar();
        } else if (value == 'excluir') {
          onExcluir();
        }
      },
    );
  }
}

// ==============================
// PÁGINA PRINCIPAL
// ==============================
class VeiculosGeralPage extends StatefulWidget {
  final String filtro;

  const VeiculosGeralPage({
    super.key,
    required this.filtro,
  });

  @override
  State<VeiculosGeralPage> createState() => _VeiculosGeralPageState();
}

class _VeiculosGeralPageState extends State<VeiculosGeralPage> {
  List<Map<String, dynamic>> _veiculos = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarVeiculos();
  }

  @override
  void didUpdateWidget(VeiculosGeralPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filtro != oldWidget.filtro) {
      setState(() {});
    }
  }

  Future<void> _carregarVeiculos() async {
    setState(() => _carregando = true);
    try {
      final data = await Supabase.instance.client
          .from('veiculos_geral')
          .select('''
            id,
            placa,
            renavam,
            status,
            tanques,
            transportadora_id,
            transportadoras(nome)
          ''')
          .order('placa');

      setState(() {
        _veiculos = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      debugPrint('Erro ao carregar veículos de terceiros: $e');
    } finally {
      setState(() => _carregando = false);
    }
  }

  List<int> _parseTanques(dynamic data) {
    if (data is List) return data.cast<int>();
    return [];
  }

  int _totalTanques(List<int> tanques) {
    if (tanques.isEmpty) return 0;
    return tanques.reduce((a, b) => a + b);
  }

  String _nomeTransportadora(Map<String, dynamic> v) {
    final t = v['transportadoras'];
    if (t is Map) {
      return t['nome']?.toString() ?? '--';
    }
    return '--';
  }

  Color _corBoca(int capacidade) {
    final cores = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.deepOrange,
      Colors.cyan,
      Colors.lime,
    ];
    return cores[capacidade % cores.length];
  }

  List<Map<String, dynamic>> get _veiculosFiltrados {
    final filtro = widget.filtro.trim().toLowerCase();
    if (filtro.isEmpty) return _veiculos;

    final capacidadeBuscada = int.tryParse(filtro);

    return _veiculos.where((v) {
      final placa = v['placa']?.toString().toLowerCase() ?? '';
      final renavam = v['renavam']?.toString().toLowerCase() ?? '';
      final transportadora = _nomeTransportadora(v).toLowerCase();
      final tanques = _parseTanques(v['tanques']);
      final capacidadeTotal = _totalTanques(tanques);
      final capacidadeComoTexto = capacidadeTotal.toString();

      final bateCapacidade = capacidadeBuscada != null
          ? capacidadeTotal == capacidadeBuscada
          : capacidadeComoTexto.contains(filtro);

      return placa.contains(filtro) ||
          renavam.contains(filtro) ||
          transportadora.contains(filtro) ||
          bateCapacidade;
    }).toList();
  }

  Future<void> _excluirVeiculo(String id, String placa) async {
    try {
      await Supabase.instance.client
          .from('veiculos_geral')
          .delete()
          .eq('id', id);
      
      if (mounted) {
        _carregarVeiculos();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Veículo $placa excluído com sucesso'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // =========================
        // CABEÇALHO DA TABELA
        // =========================
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 40), // Espaço para o menu
              const SizedBox(width: 100, child: Text('Placa', style: _h)),
              const SizedBox(width: 180, child: Text('Transportadora', style: _h)),
              const SizedBox(width: 120, child: Text('Renavam', style: _h)),
              const SizedBox(width: 260, child: Text('Compartimentos', style: _h)),
              const SizedBox(width: 90, child: Text('Capacidade', style: _h)),
            ],
          ),
        ),

        // =========================
        // LISTA
        // =========================
        Expanded(
          child: _carregando
              ? const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFF0D47A1)),
                )
              : _veiculosFiltrados.isEmpty
                  ? const Center(
                      child: Text(
                        'Nenhum veículo encontrado',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _veiculosFiltrados.length,
                      itemBuilder: (context, index) {
                        final v = _veiculosFiltrados[index];
                        final tanques = _parseTanques(v['tanques']);
                        final total = _totalTanques(tanques);
                        final placa = v['placa']?.toString() ?? '';

                        return Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: index.isEven
                                ? Colors.white
                                : Colors.grey.shade50,
                            border: Border(
                              bottom: BorderSide(color: Colors.grey.shade200),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              // Menu de 3 pontos
                              SizedBox(
                                width: 40,
                                child: MenuVeiculoWidget(
                                  placa: placa,
                                  onEditar: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => DialogEditarVeiculoGeral(
                                        veiculo: v,
                                        onAtualizado: _carregarVeiculos,
                                      ),
                                    );
                                  },
                                  onExcluir: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => DialogConfirmarExclusao(
                                        placa: placa,
                                        onConfirmar: () => _excluirVeiculo(v['id'], placa),
                                      ),
                                    );
                                  },
                                ),
                              ),

                              // PLACA
                              SizedBox(
                                width: 100,
                                child: Text(
                                  placa,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0D47A1),
                                  ),
                                ),
                              ),

                              // TRANSPORTADORA
                              SizedBox(
                                width: 180,
                                child: Text(
                                  _nomeTransportadora(v),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),

                              // RENAVAM
                              SizedBox(
                                width: 120,
                                child: Text(
                                  v['renavam'] ?? '--',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: v['renavam'] != null ? Colors.black : Colors.grey,
                                    fontStyle: v['renavam'] != null ? FontStyle.normal : FontStyle.italic,
                                  ),
                                ),
                              ),

                              // COMPARTIMENTOS
                              SizedBox(
                                width: 260,
                                child: tanques.isEmpty
                                    ? const Text(
                                        'Cavalo',
                                        style: TextStyle(
                                          fontStyle: FontStyle.italic,
                                          color: Colors.grey,
                                        ),
                                      )
                                    : Wrap(
                                        spacing: 4,
                                        runSpacing: 4,
                                        children: tanques
                                            .map(
                                              (c) => Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: _corBoca(c).withOpacity(0.1),
                                                  border: Border.all(
                                                    color: _corBoca(c).withOpacity(0.3),
                                                  ),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  '$c',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: _corBoca(c),
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                      ),
                              ),

                              // CAPAC. TOTAL
                              SizedBox(
                                width: 90,
                                child: tanques.isEmpty
                                    ? const SizedBox()
                                    : Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.blueGrey.withOpacity(0.1),
                                          border: Border.all(
                                            color: Colors.blueGrey.withOpacity(0.3),
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.arrow_forward,
                                              size: 12,
                                              color: Colors.blueGrey,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '$total',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blueGrey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

const _h = TextStyle(
  fontWeight: FontWeight.bold,
  color: Color(0xFF0D47A1),
  fontSize: 12,
);