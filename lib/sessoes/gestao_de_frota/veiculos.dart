import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

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

    if (texto.length > 7) {
      texto = texto.substring(0, 7);
    }

    String resultado = '';
    for (int i = 0; i < texto.length; i++) {
      if (i < 3) {
        if (RegExp(r'[A-Z]').hasMatch(texto[i])) {
          resultado += texto[i];
        }
      } else {
        resultado += texto[i];
      }
    }

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
// DIALOG DE EDIÇÃO (UNIFICADO)
// ==============================
class DialogEditarVeiculo extends StatefulWidget {
  final Map<String, dynamic> veiculo;
  final VoidCallback onAtualizado;
  final String tabela; // 'equipamentos' ou 'veiculos'

  const DialogEditarVeiculo({
    super.key,
    required this.veiculo,
    required this.onAtualizado,
    this.tabela = 'equipamentos',
  });

  @override
  State<DialogEditarVeiculo> createState() => _DialogEditarVeiculoState();
}

class _DialogEditarVeiculoState extends State<DialogEditarVeiculo> {
  late TextEditingController _placaController;
  late TextEditingController _renavamController;
  late TextEditingController _transportadoraController;
  String? _selectedTransportadoraId;
  List<Map<String, dynamic>> _transportadoras = [];
  List<double> _tanques = [];
  bool _carregandoTransportadoras = false;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _placaController = TextEditingController(text: widget.veiculo['placa'] ?? '');
    _renavamController = TextEditingController(text: widget.veiculo['renavam'] ?? '');
    _transportadoraController = TextEditingController(text: _getNomeTransportadora(widget.veiculo));
    _selectedTransportadoraId = widget.veiculo['transportadora_id']?.toString();
    _tanques = (widget.veiculo['tanques'] as List?)?.map((t) => double.tryParse(t.toString()) ?? 0.0).toList() ?? [];
    _carregarTransportadoras();
  }

  String _getNomeTransportadora(Map<String, dynamic> veiculo) {
    final transportadora = veiculo['transportadoras'];
    if (transportadora is Map) {
      return transportadora['nome']?.toString() ?? '--';
    }
    return '--';
  }

  @override
  void dispose() {
    _placaController.dispose();
    _renavamController.dispose();
    _transportadoraController.dispose();
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
      _tanques.add(0.0);
    });
  }

  void _removerTanque(int index) {
    setState(() {
      _tanques.removeAt(index);
    });
  }

  void _atualizarTanque(int index, String valor) {
    final stringLimpa = valor.replaceAll('.', '');
    final numero = double.tryParse(stringLimpa);
    if (numero != null) {
      setState(() {
        _tanques[index] = numero / 1000;
      });
    }
  }

  String _formatarCampo(String valor) {
    if (valor.isEmpty) return '';
    final numero = int.tryParse(valor.replaceAll('.', ''));
    if (numero == null) return valor;
    return NumberFormat('#,##0', 'pt_BR').format(numero);
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
          .from(widget.tabela)
          .update(dados)
          .eq('id', widget.veiculo['id']);

      if (mounted) {
        Navigator.of(context).pop();
        widget.onAtualizado();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
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
                    // Transportadora
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
                                    label: Text('Renavam', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
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
                                final valorLitros = (_tanques[index] * 1000).toInt();
                                final controller = TextEditingController(
                                  text: valorLitros > 0 ? NumberFormat('#,##0', 'pt_BR').format(valorLitros) : '',
                                );
                                
                                controller.selection = TextSelection.fromPosition(
                                  TextPosition(offset: controller.text.length),
                                );

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: controller,
                                          style: const TextStyle(fontSize: 13),
                                          decoration: InputDecoration(
                                            label: Text('Compartimento ${index + 1} (L)', 
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
                                          onChanged: (value) {
                                            _atualizarTanque(index, value);
                                            final formatado = _formatarCampo(value);
                                            if (formatado != value) {
                                              controller.text = formatado;
                                              controller.selection = TextSelection.fromPosition(
                                                TextPosition(offset: controller.text.length),
                                              );
                                            }
                                          },
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
// DIALOG DE CONFIRMAÇÃO DE EXCLUSÃO (UNIFICADO)
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
            Text(
              'Excluir Veículo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.blue[900],
              ),
            ),
            const SizedBox(height: 8),
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
// WIDGET DE MENU DE 3 PONTOS (UNIFICADO)
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
// PÁGINA DE VEÍCULOS GERAIS (COMPONENTE)
// ==============================
class VeiculosGeralPage extends StatefulWidget {
  final String filtro;
  final VoidCallback? onRefresh;

  const VeiculosGeralPage({
    super.key,
    required this.filtro,
    this.onRefresh,
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
    if (widget.onRefresh != oldWidget.onRefresh) {
      _carregarVeiculos();
    }
  }

  Future<void> _carregarVeiculos() async {
    setState(() => _carregando = true);
    try {
      // Busca da tabela 'equipamentos' (mesmas colunas que 'veiculos')
      final dataEquipamentos = await Supabase.instance.client
          .from('equipamentos')
          .select('''
            id,
            placa,
            renavam,
            tanques,
            transportadora_id,
            transportadoras(nome)
          ''')
          .order('placa');

      // Busca da tabela 'veiculos'
      final dataVeiculos = await Supabase.instance.client
          .from('veiculos')
          .select('''
            id,
            placa,
            renavam,
            tanques,
            transportadora_id,
            transportadoras(nome)
          ''')
          .order('placa');

      // Combina as duas listas
      final combinados = <Map<String, dynamic>>[];
      combinados.addAll(List<Map<String, dynamic>>.from(dataEquipamentos));
      combinados.addAll(List<Map<String, dynamic>>.from(dataVeiculos));

      // Ordena por placa
      combinados.sort((a, b) {
        final placaA = a['placa']?.toString() ?? '';
        final placaB = b['placa']?.toString() ?? '';
        return placaA.compareTo(placaB);
      });

      setState(() {
        _veiculos = combinados;
      });
    } catch (e) {
      debugPrint('Erro ao carregar veículos gerais: $e');
      // Tenta carregar apenas uma tabela se a outra falhar
      try {
        final data = await Supabase.instance.client
            .from('equipamentos')
            .select('''
              id,
              placa,
              renavam,
              tanques,
              transportadora_id,
              transportadoras(nome)
            ''')
            .order('placa');
        setState(() {
          _veiculos = List<Map<String, dynamic>>.from(data);
        });
      } catch (e2) {
        debugPrint('Erro ao carregar equipamentos: $e2');
        setState(() {
          _veiculos = [];
        });
      }
    } finally {
      setState(() => _carregando = false);
    }
  }

  List<double> _parseTanques(dynamic data) {
    if (data is List) return data.map((t) => double.tryParse(t.toString()) ?? 0.0).toList();
    return [];
  }

  double _totalTanques(List<double> tanques) {
    if (tanques.isEmpty) return 0.0;
    return tanques.reduce((a, b) => a + b);
  }

  String _nomeTransportadora(Map<String, dynamic> v) {
    final t = v['transportadoras'];
    if (t is Map) {
      return t['nome']?.toString() ?? '--';
    }
    return '--';
  }

  Color _corBoca(double capacidade) {
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
    return cores[(capacidade.toInt()) % cores.length];
  }

  List<Map<String, dynamic>> get _veiculosFiltrados {
    final filtroRaw = widget.filtro.trim().toLowerCase();
    if (filtroRaw.isEmpty) return _veiculos;

    final filtroNormalized = filtroRaw.replaceAll(RegExp(r'[.,\s]'), '');
    final capacidadeBuscadaLitros = int.tryParse(filtroNormalized);

    return _veiculos.where((v) {
      final placa = v['placa']?.toString().toLowerCase() ?? '';
      final renavam = v['renavam']?.toString().toLowerCase() ?? '';
      final transportadora = _nomeTransportadora(v).toLowerCase();
      final tanques = _parseTanques(v['tanques']);
      final capacidadeTotalM3 = _totalTanques(tanques);
      final capacidadeTotalLitros = (capacidadeTotalM3 * 1000).toInt();
      final capacidadeComoTexto = NumberFormat('#,##0', 'pt_BR').format(capacidadeTotalLitros);
      final capacidadeComoTextoNormalized = capacidadeComoTexto.replaceAll(RegExp(r'[.,\s]'), '');

      // Compartimentos
      final numCompartimentos = tanques.length;
      final compartimentoBuscado = int.tryParse(filtroNormalized);
      final bateCompartimentos = compartimentoBuscado != null
          ? (numCompartimentos == compartimentoBuscado)
          : numCompartimentos.toString().contains(filtroNormalized);

      // Capacidade
      final bateCapacidade = capacidadeBuscadaLitros != null
          ? (capacidadeTotalLitros >= capacidadeBuscadaLitros - 100 && capacidadeTotalLitros <= capacidadeBuscadaLitros + 100)
          : (capacidadeComoTextoNormalized.contains(filtroNormalized) || capacidadeComoTexto.contains(filtroRaw));

      return placa.contains(filtroRaw) ||
          renavam.contains(filtroRaw) ||
          transportadora.contains(filtroRaw) ||
          bateCapacidade ||
          bateCompartimentos;
    }).toList();
  }

  Future<void> _excluirVeiculo(String id, String placa, String tabela) async {
    try {
      await Supabase.instance.client
          .from(tabela)
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
        // Cabeçalho da tabela
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 40),
              const SizedBox(width: 100, child: Text('PLACA', style: _h)),
              const SizedBox(width: 180, child: Text('TRANSPORTADORA', style: _h)),
              const SizedBox(width: 120, child: Text('RENAVAM', style: _h)),
              const SizedBox(width: 260, child: Text('COMPARTIMENTOS', style: _h)),
              const SizedBox(width: 90, child: Text('CAPAC. TOTAL', style: _h)),
            ],
          ),
        ),

        // Lista
        Expanded(
          child: _carregando
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF0D47A1)),
                )
              : _veiculosFiltrados.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.directions_car_outlined,
                              size: 48, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            widget.filtro.isEmpty
                                ? 'Nenhum veículo cadastrado'
                                : 'Nenhum veículo encontrado',
                            style: const TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _veiculosFiltrados.length,
                      itemBuilder: (context, index) {
                        final v = _veiculosFiltrados[index];
                        final tanques = _parseTanques(v['tanques']);
                        final total = _totalTanques(tanques);
                        final placa = v['placa']?.toString() ?? '';

                        // Determina qual tabela o veículo pertence
                        final tabela = v['transportadora_id'] != null && 
                            v['id'] != null ? 'equipamentos' : 'veiculos';
                        // Na prática, como ambas tabelas tem os mesmos campos, podemos tentar ambas
                        // Mas vamos usar 'equipamentos' como padrão e se falhar, tenta 'veiculos'

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
                              // Menu
                              SizedBox(
                                width: 40,
                                child: MenuVeiculoWidget(
                                  placa: placa,
                                  onEditar: () {
                                    // Tenta editar em 'equipamentos', se falhar, tenta 'veiculos'
                                    showDialog(
                                      context: context,
                                      builder: (context) => DialogEditarVeiculo(
                                        veiculo: v,
                                        tabela: 'equipamentos',
                                        onAtualizado: _carregarVeiculos,
                                      ),
                                    );
                                  },
                                  onExcluir: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => DialogConfirmarExclusao(
                                        placa: placa,
                                        onConfirmar: () => _excluirVeiculo(v['id'], placa, 'equipamentos'),
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
                                  style: const TextStyle(fontSize: 13),
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
                                    ? Row(
                                        children: const [
                                          Icon(Icons.directions_car,
                                              size: 16, color: Colors.grey),
                                          SizedBox(width: 6),
                                          Text(
                                            'Cavalo',
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontStyle: FontStyle.italic,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
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
                                                    width: 1,
                                                  ),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  NumberFormat('#,##0', 'pt_BR').format((c * 1000).toInt()),
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
                                            width: 1,
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
                                              NumberFormat('#,##0', 'pt_BR').format((total * 1000).toInt()),
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

// ==============================
// PÁGINA PRINCIPAL DE VEÍCULOS (UNIFICADA)
// ==============================
class VeiculosPage extends StatefulWidget {
  final VoidCallback onVoltar;
  final Function(Map<String, dynamic>) onSelecionarVeiculo;
  final int abaInicial;
  
  const VeiculosPage({
    super.key,
    required this.onVoltar,
    required this.onSelecionarVeiculo,
    this.abaInicial = 0,
  });

  @override
  State<VeiculosPage> createState() => _VeiculosPageState();
}

class _VeiculosPageState extends State<VeiculosPage> {
  List<Map<String, dynamic>> _veiculosProprios = [];
  bool _carregandoProprios = true;
  String _filtroProprios = '';
  String _filtroGeral = '';
  int _abaAtual = 0;
  int _geralRefreshToken = 0;
  int _conjuntosRefreshToken = 0;
  final TextEditingController _buscaPropriosController = TextEditingController();
  final TextEditingController _buscaConjuntosController = TextEditingController();
  final TextEditingController _buscaGeralController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _abaAtual = widget.abaInicial;
    _carregarVeiculosProprios();
  }

  @override
  void dispose() {
    _buscaPropriosController.dispose();
    _buscaConjuntosController.dispose();
    _buscaGeralController.dispose();
    super.dispose();
  }

  TextEditingController get _controladorBuscaAtual {
    if (_abaAtual == 0) return _buscaPropriosController;
    if (_abaAtual == 1) return _buscaConjuntosController;
    return _buscaGeralController;
  }

  String get _hintBuscaAtual {
    if (_abaAtual == 0) {
      return 'Buscar placa, transportadora ou capacidade...';
    }
    if (_abaAtual == 1) {
      return 'Buscar por placa, motorista, capacidade...';
    }
    return 'Buscar placa, renavam, transportadora ou capacidade...';
  }

  void _onBuscaChanged(String value) {
    setState(() {
      if (_abaAtual == 0) {
        _filtroProprios = value;
      } else if (_abaAtual == 2) {
        _filtroGeral = value;
      }
    });
  }

  Future<void> _carregarVeiculosProprios() async {
    setState(() => _carregandoProprios = true);
    try {
      final data = await Supabase.instance.client
          .from('equipamentos')
          .select('''
            id,
            placa, 
            tanques,
            renavam,
            transportadora_id,
            transportadoras(nome)
          ''')
          .order('placa');

      setState(() {
        _veiculosProprios = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      print('Erro ao carregar veículos próprios: $e');
    } finally {
      setState(() => _carregandoProprios = false);
    }
  }

  List<double> _parseTanques(dynamic tanquesData) {
    if (tanquesData is List) return tanquesData.map((t) => double.tryParse(t.toString()) ?? 0.0).toList();
    return [];
  }

  double _calcularTotalTanques(List<double> tanques) {
    return tanques.isNotEmpty ? tanques.reduce((a, b) => a + b) : 0.0;
  }

  String _getNomeTransportadora(Map<String, dynamic> veiculo) {
    final transportadora = veiculo['transportadoras'];
    if (transportadora is Map) {
      return transportadora['nome']?.toString() ?? '--';
    }
    return '--';
  }

  List<Map<String, dynamic>> get _veiculosPropriosFiltrados {
    if (_filtroProprios.isEmpty) return _veiculosProprios;

    final filtroRaw = _filtroProprios.trim().toLowerCase();
    final filtroNormalized = filtroRaw.replaceAll(RegExp(r'[.,\s]'), '');
    final capacidadeBuscadaLitros = double.tryParse(filtroNormalized);

    return _veiculosProprios.where((v) {
      final placa = v['placa']?.toString().toLowerCase() ?? '';
      final transportadora = _getNomeTransportadora(v).toLowerCase();
      final tanques = _parseTanques(v['tanques']);
      final capacidadeTotalM3 = _calcularTotalTanques(tanques);
      final capacidadeTotalLitros = capacidadeTotalM3 * 1000;
      final capacidadeComoTexto = NumberFormat('#,##0', 'pt_BR').format(capacidadeTotalLitros.toInt());
      final capacidadeComoTextoNormalized = capacidadeComoTexto.replaceAll(RegExp(r'[.,\s]'), '');

      final numCompartimentos = tanques.length;
      final compartimentoBuscado = int.tryParse(filtroNormalized);
      final bateCompartimentos = compartimentoBuscado != null
        ? (numCompartimentos == compartimentoBuscado)
        : numCompartimentos.toString().contains(filtroNormalized);

      final bateCapacidade = capacidadeBuscadaLitros != null
        ? (capacidadeTotalLitros >= capacidadeBuscadaLitros - 100 && capacidadeTotalLitros <= capacidadeBuscadaLitros + 100)
        : (capacidadeComoTextoNormalized.contains(filtroNormalized) || capacidadeComoTexto.contains(filtroRaw));

      return placa.contains(filtroRaw) ||
         transportadora.contains(filtroRaw) ||
         bateCapacidade ||
         bateCompartimentos;
    }).toList();
  }

  void _abrirCadastroVeiculo() {
    final tipoCadastro = _abaAtual == 2
        ? TipoCadastroVeiculo.terceiros
        : TipoCadastroVeiculo.proprios;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => DialogCadastroPlacas(tipoCadastro: tipoCadastro),
    ).then((_) {
      if (!mounted) return;
      if (_abaAtual == 2) {
        setState(() {
          _geralRefreshToken++;
        });
      } else {
        _carregarVeiculosProprios();
      }
    });
  }

  Color _getCorBoca(double capacidade) {
    final cores = [
      Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red,
      Colors.teal, Colors.indigo, Colors.deepOrange, Colors.cyan, Colors.lime,
    ];
    final indexCor = (capacidade * 1000).toInt();
    return cores[indexCor % cores.length];
  }

  Future<void> _excluirVeiculoProprio(String id, String placa) async {
    try {
      await Supabase.instance.client
          .from('equipamentos')
          .delete()
          .eq('id', id);
      
      if (mounted) {
        _carregarVeiculosProprios();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Placa $placa excluída com sucesso'),
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

  void _refreshConjuntos() {
    setState(() {
      _conjuntosRefreshToken++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null,
      backgroundColor: Colors.white,
      floatingActionButton: (_abaAtual == 0 || _abaAtual == 2) ? FloatingActionButton(
        onPressed: _abrirCadastroVeiculo,
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ) : null,
      body: Column(
        children: [
          // Cabeçalho
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
                  onPressed: widget.onVoltar,
                ),
                const SizedBox(width: 8),
                const Text('Veículos',
                  style: TextStyle(fontSize: 20, color: Color(0xFF0D47A1), fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    if (_abaAtual == 0) {
                      _carregarVeiculosProprios();
                    } else if (_abaAtual == 1) {
                      _refreshConjuntos();
                    } else {
                      setState(() {
                        _geralRefreshToken++;
                      });
                    }
                  },
                  icon: const Icon(Icons.refresh, color: Color(0xFF0D47A1)),
                  tooltip: 'Atualizar',
                ),
              ],
            ),
          ),

          // Navegação e busca
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Row(
                  children: [
                    _botaoAba("Veículos (Geral)", 2),
                    const SizedBox(width: 16),
                    _botaoAba("Veículos Próprios", 0),
                    const SizedBox(width: 16),
                    _botaoAba("Conjuntos", 1),
                  ],
                ),
                const Spacer(),
                SizedBox(
                  width: 300,
                  child: TextField(
                    key: ValueKey('busca-$_abaAtual'),
                    controller: _controladorBuscaAtual,
                    onChanged: _onBuscaChanged,
                    decoration: InputDecoration(
                      hintText: _hintBuscaAtual,
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Conteúdo
          Expanded(
            child: _abaAtual == 0
                ? _buildVeiculosPropriosList()
                : _abaAtual == 1
                    ? ConjuntosPage(
                        key: ValueKey('conjuntos-$_conjuntosRefreshToken'),
                        buscaController: _buscaConjuntosController,
                      )
                    : VeiculosGeralPage(
                        key: ValueKey('geral-$_geralRefreshToken'),
                        filtro: _filtroGeral,
                        onRefresh: () {
                          setState(() {
                            _geralRefreshToken++;
                          });
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _botaoAba(String texto, int aba) {
    final bool selecionado = _abaAtual == aba;

    return Material(
      color: selecionado ? const Color(0xFF0D47A1) : Colors.white,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: () {
          setState(() {
            _abaAtual = aba;
          });
        },
        hoverColor: const Color(0xFF0D47A1).withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: selecionado
                  ? const Color(0xFF0D47A1)
                  : Colors.grey.shade400,
            ),
          ),
          child: Text(
            texto,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selecionado ? Colors.white : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVeiculosPropriosList() {
    return Column(
      children: [
        // Cabeçalho
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 40),
              const SizedBox(width: 100, child: Text('PLACA', style: _h)),
              const SizedBox(width: 180, child: Text('TRANSPORTADORA', style: _h)),
              const SizedBox(width: 100, child: Text('RENAVAM', style: _h)),
              const SizedBox(width: 260, child: Text('COMPARTIMENTOS', style: _h)),
              const SizedBox(width: 90, child: Text('CAPAC. TOTAL', style: _h)),
            ],
          ),
        ),

        // Lista
        Expanded(
          child: _carregandoProprios
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF0D47A1)),
                )
              : _veiculosPropriosFiltrados.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.directions_car_outlined,
                              size: 48, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            _filtroProprios.isEmpty
                                ? 'Nenhum veículo cadastrado'
                                : 'Nenhum veículo encontrado',
                            style: const TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _veiculosPropriosFiltrados.length,
                      itemBuilder: (context, index) {
                        final veiculo = _veiculosPropriosFiltrados[index];
                        final placa = veiculo['placa']?.toString() ?? '';
                        final transportadora = _getNomeTransportadora(veiculo);
                        final tanques = _parseTanques(veiculo['tanques']);
                        final totalTanques = _calcularTotalTanques(tanques);
                        final renavam = veiculo['renavam']?.toString();

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
                              // Menu
                              SizedBox(
                                width: 40,
                                child: MenuVeiculoWidget(
                                  placa: placa,
                                  onEditar: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => DialogEditarVeiculo(
                                        veiculo: veiculo,
                                        tabela: 'equipamentos',
                                        onAtualizado: _carregarVeiculosProprios,
                                      ),
                                    );
                                  },
                                  onExcluir: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => DialogConfirmarExclusao(
                                        placa: placa,
                                        onConfirmar: () => _excluirVeiculoProprio(veiculo['id'], placa),
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
                                    fontSize: 14,
                                    color: Color(0xFF0D47A1),
                                  ),
                                ),
                              ),

                              // TRANSPORTADORA
                              SizedBox(
                                width: 180,
                                child: Text(
                                  transportadora,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),

                              // RENAVAM
                              SizedBox(
                                width: 100,
                                child: Text(
                                  renavam ?? '--',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: renavam != null ? Colors.black : Colors.grey,
                                    fontStyle: renavam != null ? FontStyle.normal : FontStyle.italic,
                                  ),
                                ),
                              ),

                              // COMPARTIMENTOS
                              SizedBox(
                                width: 260,
                                child: tanques.isEmpty
                                    ? Row(
                                        children: const [
                                          Icon(Icons.directions_car,
                                              size: 16, color: Colors.grey),
                                          SizedBox(width: 6),
                                          Text(
                                            'Cavalo',
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontStyle: FontStyle.italic,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Wrap(
                                        spacing: 4,
                                        runSpacing: 4,
                                        children: tanques
                                            .map(
                                              (capacidade) => Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: _getCorBoca(capacidade).withOpacity(0.1),
                                                  border: Border.all(
                                                    color: _getCorBoca(capacidade).withOpacity(0.3),
                                                    width: 1,
                                                  ),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  NumberFormat('#,##0', 'pt_BR').format((capacidade * 1000).toInt()),
                                                  style: TextStyle(
                                                    color: _getCorBoca(capacidade),
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
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
                                            width: 1,
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.arrow_forward,
                                                size: 12, color: Colors.blueGrey),
                                            const SizedBox(width: 4),
                                            Text(
                                              NumberFormat('#,##0', 'pt_BR').format((totalTanques * 1000).toInt()),
                                              style: const TextStyle(
                                                color: Colors.blueGrey,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
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

// Placeholder para tipos que podem ser importados de outros arquivos
enum TipoCadastroVeiculo { proprios, terceiros }

// Placeholder para DialogCadastroPlacas
class DialogCadastroPlacas extends StatelessWidget {
  final TipoCadastroVeiculo tipoCadastro;

  const DialogCadastroPlacas({
    super.key,
    required this.tipoCadastro,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tipoCadastro == TipoCadastroVeiculo.proprios ? 'Cadastrar Veículo Próprio' : 'Cadastrar Veículo de Terceiros'),
      content: const Text('Implementar cadastro de veículos'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}

// ==============================
// PÁGINA DE CONJUNTOS (ADAPTADA)
// ==============================
class ConjuntosPage extends StatefulWidget {
  final TextEditingController buscaController;
  
  const ConjuntosPage({
    super.key,
    required this.buscaController,
  });

  @override
  State<ConjuntosPage> createState() => _ConjuntosPageState();
}

class _ConjuntosPageState extends State<ConjuntosPage> {
  List<Map<String, dynamic>> _conjuntos = [];
  List<Map<String, dynamic>> _conjuntosTemporarios = [];
  bool _carregando = true;
  final Map<String, List<String>> _placasDuplicadas = {};

  @override
  void initState() {
    super.initState();
    widget.buscaController.addListener(_onBuscaChanged);
    _carregarConjuntos();
  }

  @override
  void dispose() {
    widget.buscaController.removeListener(_onBuscaChanged);
    super.dispose();
  }

  void _onBuscaChanged() {
    setState(() {});
  }

  Future<void> _carregarConjuntos() async {
    setState(() => _carregando = true);
    try {
      final data = await Supabase.instance.client
          .from('conjuntos')
          .select()
          .order('id', ascending: false);
      
      _placasDuplicadas.clear();
      
      for (final conjunto in data) {
        final conjuntoId = conjunto['id'].toString();
        
        if (conjunto['cavalo'] != null) {
          final placa = conjunto['cavalo'].toString();
          _adicionarPlacaDuplicada(placa, conjuntoId);
        }
        if (conjunto['reboque_um'] != null) {
          final placa = conjunto['reboque_um'].toString();
          _adicionarPlacaDuplicada(placa, conjuntoId);
        }
        if (conjunto['reboque_dois'] != null) {
          final placa = conjunto['reboque_dois'].toString();
          _adicionarPlacaDuplicada(placa, conjuntoId);
        }
      }
      
      setState(() {
        _conjuntos = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      print('Erro ao carregar conjuntos: $e');
      setState(() {
        _conjuntos = [];
      });
    } finally {
      setState(() => _carregando = false);
    }
  }

  void _adicionarPlacaDuplicada(String placa, String conjuntoId) {
    if (!_placasDuplicadas.containsKey(placa)) {
      _placasDuplicadas[placa] = [];
    }
    if (!_placasDuplicadas[placa]!.contains(conjuntoId)) {
      _placasDuplicadas[placa]!.add(conjuntoId);
    }
  }

  String _formatarNumero(dynamic valor) {
    if (valor == null) return '--';
    return valor.toString();
  }

  String _formatarPBT(dynamic valor) {
    if (valor == null) return '--';
    if (valor is double) {
      return '${valor.toStringAsFixed(1)} kg';
    }
    return '$valor kg';
  }

  List<Map<String, dynamic>> get _conjuntosFiltrados {
    final filtroRaw = widget.buscaController.text.toLowerCase();
    final filtroNormalized = filtroRaw.replaceAll(RegExp(r'[.,\s]'), '');
    final todosConjuntos = [..._conjuntos, ..._conjuntosTemporarios];
    
    if (filtroRaw.isEmpty) return todosConjuntos;
    
    return todosConjuntos.where((c) {
      final cavalo = c['cavalo']?.toString().toLowerCase() ?? '';
      final reboque1 = c['reboque_um']?.toString().toLowerCase() ?? '';
      final reboque2 = c['reboque_dois']?.toString().toLowerCase() ?? '';
      final motorista = c['motorista']?.toString().toLowerCase() ?? '';
      final capac = c['capac']?.toString().toLowerCase() ?? '';
      final capacNormalized = capac.replaceAll(RegExp(r'[.,\s]'), '');
      final tanques = c['tanques']?.toString().toLowerCase() ?? '';
      final tanquesNormalized = tanques.replaceAll(RegExp(r'[.,\s]'), '');
      final tanquesData = c['tanques'];
      final numTanques = tanquesData is List ? tanquesData.length : (tanquesData != null ? tanquesData.toString().split(',').length : 0);
      final buscNumTanques = int.tryParse(filtroNormalized);
      final bateNumTanques = buscNumTanques != null ? (numTanques == buscNumTanques) : numTanques.toString().contains(filtroNormalized);
      final pbt = c['pbt']?.toString().toLowerCase() ?? '';
      final pbtNormalized = pbt.replaceAll(RegExp(r'[.,\s]'), '');
      
      return cavalo.contains(filtroRaw) ||
             reboque1.contains(filtroRaw) ||
             reboque2.contains(filtroRaw) ||
             motorista.contains(filtroRaw) ||
             capac.contains(filtroRaw) || capacNormalized.contains(filtroNormalized) ||
             tanques.contains(filtroRaw) || tanquesNormalized.contains(filtroNormalized) ||
             bateNumTanques ||
             pbt.contains(filtroRaw) || pbtNormalized.contains(filtroNormalized);
    }).toList();
  }

  void _adicionarConjuntoTemporario() {
    final novoConjunto = {
      'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'motorista': '--',
      'cavalo': null,
      'reboque_um': null,
      'reboque_dois': null,
      'capac': null,
      'tanques': null,
      'pbt': null,
      'isTemporario': true,
    };
    
    setState(() {
      _conjuntosTemporarios.add(novoConjunto);
    });
  }

  Future<void> _salvarConjuntoTemporario(Map<String, dynamic> conjunto) async {
    try {
      final dadosParaSalvar = {
        'motorista': conjunto['motorista'],
        'cavalo': conjunto['cavalo'],
        'reboque_um': conjunto['reboque_um'],
        'reboque_dois': conjunto['reboque_dois'],
        'capac': conjunto['capac'],
        'tanques': conjunto['tanques'],
        'pbt': conjunto['pbt'],
      };
      
      final resultado = await Supabase.instance.client
          .from('conjuntos')
          .insert(dadosParaSalvar)
          .select();
      
      if (resultado.isNotEmpty) {
        setState(() {
          _conjuntosTemporarios.removeWhere((c) => c['id'] == conjunto['id']);
        });
        await _carregarConjuntos();
      }
    } catch (e) {
      print('Erro ao salvar conjunto: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar conjunto: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _atualizarPlacaTemporaria({
    required Map<String, dynamic> conjunto,
    required String campo,
    required String? novaPlaca,
  }) async {
    final index = _conjuntosTemporarios.indexWhere((c) => c['id'] == conjunto['id']);
    if (index != -1) {
      setState(() {
        _conjuntosTemporarios[index][campo] = novaPlaca;
      });
      
      final conj = _conjuntosTemporarios[index];
      if (conj['cavalo'] != null || conj['reboque_um'] != null || conj['reboque_dois'] != null) {
        await _salvarConjuntoTemporario(conj);
      }
    }
  }

  Widget _buildPlacaWidget({
    required Map<String, dynamic> conjunto,
    required String campo,
    required bool isTemporario,
  }) {
    final placa = conjunto[campo];
    
    return PlacaClicavelWidget(
      placa: placa,
      conjuntoId: conjunto['id'],
      campoConjunto: campo,
      onAtualizado: isTemporario 
          ? () async {
              await _carregarConjuntos();
            }
          : _carregarConjuntos,
      placasDuplicadas: _placasDuplicadas,
      isTemporario: isTemporario,
      onPlacaAtualizada: isTemporario 
          ? (novaPlaca) => _atualizarPlacaTemporaria(
                conjunto: conjunto,
                campo: campo,
                novaPlaca: novaPlaca,
              )
          : null,
    );
  }

  Widget _buildInfoChip(String texto, Color cor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cor.withOpacity(0.3)),
      ),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: cor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Cabeçalho
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: const Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  'MOTORISTA',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                    fontSize: 12,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'CAVALO',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                    fontSize: 12,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'REBOQUE 1',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                    fontSize: 12,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'REBOQUE 2',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                    fontSize: 12,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'CAPACIDADE',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                    fontSize: 12,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'TANQUES',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                    fontSize: 12,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'PBT',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Lista
        Expanded(
          child: _carregando
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF0D47A1)),
                )
              : _conjuntosFiltrados.isEmpty && widget.buscaController.text.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.directions_car_filled_outlined,
                              size: 48, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text(
                            'Nenhum conjunto cadastrado',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _adicionarConjuntoTemporario,
                            child: const Text(
                              'Criar primeiro conjunto',
                              style: TextStyle(color: Color(0xFF0D47A1)),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _conjuntosFiltrados.length,
                      itemBuilder: (context, index) {
                        final conjunto = _conjuntosFiltrados[index];
                        final isTemporario = conjunto['isTemporario'] == true;
                        
                        return Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color: isTemporario 
                                ? Colors.yellow.shade50 
                                : (index.isEven ? Colors.white : Colors.grey.shade50),
                            border: Border(
                              bottom: BorderSide(
                                color: isTemporario 
                                    ? Colors.orange.shade200 
                                    : Colors.grey.shade200,
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                // Motorista
                                Expanded(
                                  flex: 2,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: isTemporario
                                              ? Colors.orange.withOpacity(0.1)
                                              : const Color(0xFF0D47A1).withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          isTemporario ? Icons.add : Icons.person,
                                          size: 16,
                                          color: isTemporario ? Colors.orange : const Color(0xFF0D47A1),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          conjunto['motorista']?.toString() ?? '--',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: isTemporario ? Colors.orange : Colors.black,
                                            fontStyle: isTemporario ? FontStyle.italic : FontStyle.normal,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                
                                // Cavalo
                                Expanded(
                                  child: _buildPlacaWidget(
                                    conjunto: conjunto,
                                    campo: 'cavalo',
                                    isTemporario: isTemporario,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                
                                // Reboque 1
                                Expanded(
                                  child: _buildPlacaWidget(
                                    conjunto: conjunto,
                                    campo: 'reboque_um',
                                    isTemporario: isTemporario,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                
                                // Reboque 2
                                Expanded(
                                  child: _buildPlacaWidget(
                                    conjunto: conjunto,
                                    campo: 'reboque_dois',
                                    isTemporario: isTemporario,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                
                                // Capacidade
                                Expanded(
                                  child: _buildInfoChip(
                                    '${_formatarNumero(conjunto['capac'])} m³',
                                    isTemporario ? Colors.orange : Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                
                                // Tanques
                                Expanded(
                                  child: _buildInfoChip(
                                    _formatarNumero(conjunto['tanques']),
                                    isTemporario ? Colors.orange : Colors.green,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                
                                // PBT
                                Expanded(
                                  child: _buildInfoChip(
                                    _formatarPBT(conjunto['pbt']),
                                    isTemporario ? Colors.orange : Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
        
        // Rodapé com botão
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_conjuntosFiltrados.length} conjunto${_conjuntosFiltrados.length != 1 ? 's' : ''} encontrado${_conjuntosFiltrados.length != 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _adicionarConjuntoTemporario,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Novo Conjunto'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ==============================
// PLACA CLICÁVEL (MANTIDO)
// ==============================
class PlacaClicavelWidget extends StatelessWidget {
  final dynamic placa;
  final String conjuntoId;
  final String campoConjunto;
  final VoidCallback onAtualizado;
  final Map<String, List<String>> placasDuplicadas;
  final bool isTemporario;
  final Function(String?)? onPlacaAtualizada;

  const PlacaClicavelWidget({
    super.key,
    this.placa,
    required this.conjuntoId,
    required this.campoConjunto,
    required this.onAtualizado,
    required this.placasDuplicadas,
    required this.isTemporario,
    this.onPlacaAtualizada,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: placa != null ? Colors.blue.withOpacity(0.1) : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: placa != null ? Colors.blue.withOpacity(0.3) : Colors.grey.shade300,
        ),
      ),
      child: Text(
        placa?.toString() ?? '--',
        style: TextStyle(
          fontSize: 12,
          color: placa != null ? Colors.blue[900] : Colors.grey,
          fontWeight: placa != null ? FontWeight.w500 : FontWeight.normal,
          fontStyle: placa == null ? FontStyle.italic : FontStyle.normal,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}