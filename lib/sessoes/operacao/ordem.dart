import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'dart:typed_data';
import 'dart:convert' show base64Encode;
import 'dart:js' as js;
import 'ordem_pdf.dart';
import '../../login_page.dart';

// ================= COMPONENTE PLACA AUTOCOMPLETE =================
class PlacaAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final FocusNode? focusNode;
  final void Function(String)? onChanged;

  const PlacaAutocompleteField({
    super.key,
    required this.controller,
    required this.label,
    this.focusNode,
    this.onChanged,
  });

  @override
  State<PlacaAutocompleteField> createState() => _PlacaAutocompleteFieldState();
}

class _PlacaAutocompleteFieldState extends State<PlacaAutocompleteField> {
  final List<String> _sugestoes = [];
  bool _carregando = false;
  Timer? _debounceTimer;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  final FocusNode _internalFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _internalFocusNode.addListener(_onFocusChanged);
    
    // Se um focusNode externo foi fornecido, sincronize com o interno
    if (widget.focusNode != null) {
      widget.focusNode!.addListener(_onExternalFocusChanged);
    }
  }

  void _onExternalFocusChanged() {
    if (widget.focusNode!.hasFocus && !_internalFocusNode.hasFocus) {
      _internalFocusNode.requestFocus();
    } else if (!widget.focusNode!.hasFocus && _internalFocusNode.hasFocus) {
      _internalFocusNode.unfocus();
    }
  }

  void _onFocusChanged() {
    if (_internalFocusNode.hasFocus) {
      _mostrarOverlay();
    } else {
      // Pequeno delay para permitir clique nos itens
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!_internalFocusNode.hasFocus) {
          _fecharOverlay();
        }
      });
    }
  }

  Future<void> _buscarPlacas(String texto) async {
    if (texto.length < 3) {
      setState(() {
        _sugestoes.clear();
      });
      _fecharOverlay();
      return;
    }

    setState(() {
      _carregando = true;
    });

    try {
      final res = await Supabase.instance.client
          .from('vw_placas')
          .select('placa')
          .ilike('placa', '$texto%')
          .order('placa')
          .limit(10);

      final sugestoes = res.map<String>((p) => p['placa'].toString()).toList();

      setState(() {
        _sugestoes.clear();
        _sugestoes.addAll(sugestoes);
        _carregando = false;
      });

      if (_sugestoes.isNotEmpty && _internalFocusNode.hasFocus) {
        _mostrarOverlay();
      } else {
        _fecharOverlay();
      }
    } catch (e) {
      print('Erro ao buscar placas: $e');
      setState(() {
        _sugestoes.clear();
        _carregando = false;
      });
      _fecharOverlay();
    }
  }

  void _onTextChanged(String texto) {
    // Cancelar timer anterior
    _debounceTimer?.cancel();
    
    // Limpar sugestões imediatamente se texto muito curto
    if (texto.length < 3) {
      setState(() {
        _sugestoes.clear();
      });
      _fecharOverlay();
      return;
    }

    // Configurar novo timer de debounce
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _buscarPlacas(texto);
      }
    });

    // Chamar callback externo se fornecido
    if (widget.onChanged != null) {
      widget.onChanged!(texto);
    }
  }

  void _onPlacaSelecionada(String placa) {
    widget.controller.text = placa;
    setState(() {
      _sugestoes.clear();
    });
    _fecharOverlay();
    _internalFocusNode.unfocus();
    
    // Mover cursor para o final
    widget.controller.selection = TextSelection.fromPosition(
      TextPosition(offset: placa.length),
    );
  }

  void _mostrarOverlay() {
    if (_sugestoes.isEmpty || _overlayEntry != null) return;

    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: offset.dx,
        top: offset.dy + size.height + 4,
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.3,
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _sugestoes.length,
                itemBuilder: (context, index) {
                  final placa = _sugestoes[index];
                  return ListTile(
                    title: Text(
                      placa,
                      style: const TextStyle(fontSize: 14),
                    ),
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    onTap: () => _onPlacaSelecionada(placa),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _fecharOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _fecharOverlay();
    _internalFocusNode.removeListener(_onFocusChanged);
    _internalFocusNode.dispose();
    
    if (widget.focusNode != null) {
      widget.focusNode!.removeListener(_onExternalFocusChanged);
    }
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: widget.controller,
            focusNode: _internalFocusNode,
            maxLength: 8,
            textCapitalization: TextCapitalization.characters,
            onChanged: _onTextChanged,
            decoration: InputDecoration(
              labelText: widget.label,
              counterText: '',
              hintText: '',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              suffixIcon: _carregando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ================= PÁGINA PRINCIPAL (COM AS ALTERAÇÕES) =================
class EmitirOrdemPage extends StatefulWidget {
  final VoidCallback onVoltar;

  const EmitirOrdemPage({
    super.key,
    required this.onVoltar,
  });

  @override
  State<EmitirOrdemPage> createState() =>
      _EmitirOrdemPageState();
}

class _EmitirOrdemPageState extends State<EmitirOrdemPage> {
  final _formKey = GlobalKey<FormState>();
  String? tipoOperacao;
  bool _analiseConcluida = false;
  // ================= CONTROLLERS =================
  final TextEditingController dataCtrl = TextEditingController();
  final TextEditingController horaCtrl = TextEditingController();
  final FocusNode _focusTempCT = FocusNode();

  final FocusNode _focusDestinoAmb = FocusNode();
  final FocusNode _focusDestino20 = FocusNode();
  final FocusNode _focusOrigem20 = FocusNode();

  final Map<String, TextEditingController?> campos = {
    // Cabeçalho
    'numeroControle': TextEditingController(),
    'transportadora': TextEditingController(),
    'motorista': TextEditingController(),
    'notas': TextEditingController(),

    'placaCavalo': TextEditingController(),
    'carreta1': TextEditingController(),
    'carreta2': TextEditingController(),

    // Coletas (usuário)
    'tempAmostra': TextEditingController(),
    'densidadeAmostra': TextEditingController(),
    'tempCT': TextEditingController(),

    // Resultados (automáticos)
    'densidade20': TextEditingController(),
    'fatorCorrecao': TextEditingController(),

    // Volumes – Ambiente
    'origemAmb': TextEditingController(),
    'destinoAmb': TextEditingController(),
    'difAmb': TextEditingController(),

    // Volumes – 20°C
    'origem20': TextEditingController(),
    'destino20': TextEditingController(),
    'dif20': TextEditingController(),
  };

  // ================= PRODUTOS =================
  List<String> produtos = [];
  String? produtoSelecionado;
  bool carregandoProdutos = true;

  @override
  void initState() {
    super.initState();
    _setarDataHoraAtual();
    _carregarProdutos();
    _focusTempCT.addListener(() {
      if (!_focusTempCT.hasFocus) {
        _calcularResultadosObtidos();
      }
    });

    _focusDestinoAmb.addListener(() {
      if (!_focusDestinoAmb.hasFocus) {
        _calcularDiferencaAmbiente();
        _calcularDestino20CAutomatico();
      }
    });
  
    _focusDestino20.addListener(() {
      if (!_focusDestino20.hasFocus) {
        _calcularDiferenca20C();
      }
    });
    _focusOrigem20.addListener(() {
      if (!_focusOrigem20.hasFocus) {
        _calcularDestino20CAutomatico();
      }
    });
  }

  void _setarDataHoraAtual() {
    final agora = DateTime.now();
    dataCtrl.text =
        '${agora.day.toString().padLeft(2, '0')}/${agora.month.toString().padLeft(2, '0')}/${agora.year}';
    horaCtrl.text =
        '${agora.hour.toString().padLeft(2, '0')}:${agora.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _carregarProdutos() async {
    try {
      final dados = await Supabase.instance.client
          .from('produtos')
          .select('nome')
          .order('nome');

      setState(() {
        produtos =
            dados.map<String>((p) => p['nome'].toString()).toList();
        carregandoProdutos = false;
      });
    } catch (_) {
      carregandoProdutos = false;
    }
  }

  // ================= CÁLCULOS =================
  Future<void> _calcularResultadosObtidos() async {
    if (produtoSelecionado == null) {
      return;
    }

    final tempAmostra = campos['tempAmostra']!.text;
    final densObs = campos['densidadeAmostra']!.text;
    final tempCT = campos['tempCT']!.text;
    final fcvAtual = campos['fatorCorrecao']!.text;

    // Limpar campos antes de buscar
    campos['densidade20']!.text = '';
    campos['fatorCorrecao']!.text = '';

    final dens20 = await _buscarDensidade20C(
      temperaturaAmostra: tempAmostra,
      densidadeObservada: densObs,
      produtoNome: produtoSelecionado!,
    );

    campos['densidade20']!.text = dens20;

    final fcv = dens20 != '-'
        ? await _buscarFCV(
            temperaturaTanque: tempCT,
            densidade20C: dens20,
            produtoNome: produtoSelecionado!,
          )
        : '-';

    if (fcv != '-' && fcv.isNotEmpty) {
      campos['fatorCorrecao']!.text = fcv;
      // ADICIONE ESTA LINHA ↓
      _calcularDestino20CAutomatico(); // Recalcular quando FCV mudar
    } else {
      if (fcvAtual.isEmpty || fcvAtual == '-') {
        campos['fatorCorrecao']!.text = '-';
      }
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ================= HEADER =================
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
              onPressed: widget.onVoltar,
            ),
            const Text(
              'Ordem de Carga / Descarga',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D47A1),
              ),
            ),
          ],
        ),
        const Divider(),

        // ================= CONTEÚDO =================
        Expanded(
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // ================= TIPO DE OPERAÇÃO =================
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 10),
                            const Text(
                              'TIPO DE OPERAÇÃO',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0D47A1),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(6),
                                color: Colors.white,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Radio<String>(
                                          value: 'Carga',
                                          groupValue: tipoOperacao,
                                          onChanged: (value) {
                                            setState(() {
                                              tipoOperacao = value;
                                            });
                                          },
                                          activeColor: const Color(0xFF0D47A1),
                                        ),
                                        const Text('Carga'),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Radio<String>(
                                          value: 'Descarga',
                                          groupValue: tipoOperacao,
                                          onChanged: (value) {
                                            setState(() {
                                              tipoOperacao = value;
                                            });
                                          },
                                          activeColor: const Color(0xFF0D47A1),
                                        ),
                                        const Text('Descarga'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),

                        // ================= FORMULÁRIO =================
                        Opacity(
                          opacity: tipoOperacao == null ? 0.3 : 1.0,
                          child: AbsorbPointer(
                            absorbing: tipoOperacao == null || _analiseConcluida, 
                            child: Column(
                              children: [
                              // ================= NÚMERO DE CONTROLE =================
                                _linha([
                                  TextFormField(
                                    controller: campos['numeroControle'],
                                    enabled: false, // Será preenchido automaticamente pelo backend
                                    decoration: _decoration('Nº Controle do Certificado').copyWith(
                                      hintText: 'A ser gerado automaticamente',
                                      filled: true,
                                      fillColor: Colors.grey[200],
                                    ),
                                    style: const TextStyle(
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ]),
                                const SizedBox(height: 12),
                                _linhaFlexivel([
                                  {
                                    'flex': 5,
                                    'widget': TextFormField(
                                                controller: campos['notas'],
                                                keyboardType: TextInputType.number,
                                                onChanged: (value) {
                                                  final cursorPosition = campos['notas']!.selection.baseOffset;
                                                  final maskedValue = _aplicarMascaraNotasFiscais(value);

                                                  if (maskedValue != value) {
                                                    campos['notas']!.value = TextEditingValue(
                                                      text: maskedValue,
                                                      selection: TextSelection.collapsed(
                                                        offset: cursorPosition + (maskedValue.length - value.length),
                                                      ),
                                                    );
                                                  }
                                                },
                                                decoration: _decoration('Notas Fiscais').copyWith(
                                                  hintText: '',
                                                ),
                                              ),
                                  },
                                  {
                                    'flex': 5,
                                    'widget': carregandoProdutos
                                        ? const Center(
                                            child: SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                color: Color(0xFF0D47A1),
                                              ),
                                            ),
                                          )
                                        : DropdownButtonFormField<String>(
                                            value: produtoSelecionado,
                                            items: produtos
                                                .map(
                                                  (p) => DropdownMenuItem(
                                                    value: p,
                                                    child: Text(p),
                                                  ),
                                                )
                                                .toList(),
                                            onChanged: (valor) {
                                              setState(() {
                                                produtoSelecionado = valor;
                                              });
                                              _calcularResultadosObtidos();
                                            },
                                            decoration: _decoration('Produto'),
                                          ),
                                  },
                                  {
                                    'flex': 3,
                                    'widget': _campo('Data', dataCtrl, enabled: false),
                                  },
                                  {
                                    'flex': 2,
                                    'widget': _campo('Hora', horaCtrl, enabled: false),
                                  },
                                ]),
                                const SizedBox(height: 12),
                                
                                _linhaFlexivel([
                                  {
                                    'flex': 10, // Motorista - 50% (10/20)
                                    'widget': TextFormField(
                                      controller: campos['motorista'],
                                      maxLength: 50,
                                      decoration: _decoration('Motorista').copyWith(
                                        counterText: '',
                                      ),
                                    ),
                                  },
                                  {
                                    'flex': 10, // Transportadora - 50% (10/20)
                                    'widget': TextFormField(
                                      controller: campos['transportadora'],
                                      maxLength: 50,
                                      decoration: _decoration('Transportadora').copyWith(
                                        counterText: '',
                                      ),
                                    ),
                                  },
                                ]),
                                const SizedBox(height: 12),                                
                                // LINHA COM OS 3 CAMPOS DE PLACA - COM AUTOCOMPLETE
                                _linhaFlexivel([
                                  {
                                    'flex': 4, // Placa do cavalo
                                    'widget': PlacaAutocompleteField(
                                      controller: campos['placaCavalo']!,
                                      label: 'Placa do cavalo',
                                    ),
                                  },
                                  {
                                    'flex': 4, // Carreta 1
                                    'widget': PlacaAutocompleteField(
                                      controller: campos['carreta1']!,
                                      label: 'Carreta 1',
                                    ),
                                  },
                                  {
                                    'flex': 4, // Carreta 2
                                    'widget': PlacaAutocompleteField(
                                      controller: campos['carreta2']!,
                                      label: 'Carreta 2',
                                    ),
                                  },
                                ]),
                                const SizedBox(height: 20),
                                _secao('Coletas na presença do motorista'),
                                _linha([
                                  TextFormField(
                                    controller: campos['tempAmostra'],
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) {
                                      final masked = _aplicarMascaraTemperatura(value);

                                      if (masked != value) {
                                        campos['tempAmostra']!.value = TextEditingValue(
                                          text: masked,
                                          selection: TextSelection.collapsed(offset: masked.length),
                                        );
                                      }
                                    },
                                    decoration: _decoration('Temperatura da amostra (°C)').copyWith(
                                      hintText: '00,0',
                                    ),
                                  ),

                                  TextFormField(
                                    controller: campos['densidadeAmostra'],
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) {
                                      final masked = _aplicarMascaraDensidade(value);

                                      if (masked != value) {
                                        campos['densidadeAmostra']!.value = TextEditingValue(
                                          text: masked,
                                          selection: TextSelection.collapsed(offset: masked.length),
                                        );
                                      }
                                    },
                                    decoration: _decoration('Densidade observada').copyWith(
                                      hintText: '0,0000',
                                    ),
                                  ),

                                  TextFormField(
                                    controller: campos['tempCT'],
                                    focusNode: _focusTempCT,
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) {
                                      final masked = _aplicarMascaraTemperatura(value);

                                      if (masked != value) {
                                        campos['tempCT']!.value = TextEditingValue(
                                          text: masked,
                                          selection: TextSelection.collapsed(offset: masked.length),
                                        );
                                      }
                                      //_calcularResultadosObtidos();
                                    },
                                    decoration: _decoration('Temperatura do CT (°C)').copyWith(
                                      hintText: '00,0',
                                    ),
                                  ),

                                ]),
                                const SizedBox(height: 20),
                                _secao('Resultados obtidos'),
                                _linha([
                                  _campo('Densidade a 20 ºC', campos['densidade20']!, enabled: false),
                                  _campo('Fator de correção (FCV)', campos['fatorCorrecao']!, enabled: false),
                                ]),
                                const SizedBox(height: 20),
                                _secao('Volumes apurados - Ambiente'),
                                _linha([
                                  TextFormField(
                                    controller: campos['origemAmb'],
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) {
                                      final ctrl = campos['origemAmb']!;
                                      final masked = _aplicarMascaraNotasFiscais(value);

                                      if (masked != value) {
                                        ctrl.value = TextEditingValue(
                                          text: masked,
                                          selection: TextSelection.collapsed(offset: masked.length),
                                        );
                                      }
                                      _calcularDiferencaAmbiente();
                                    },
                                    decoration: _decoration('Quantidade de origem'),
                                  ),
                                  TextFormField(
                                    controller: campos['destinoAmb'],
                                    focusNode: _focusDestinoAmb,
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) {
                                      final ctrl = campos['destinoAmb']!;
                                      final masked = _aplicarMascaraNotasFiscais(value);

                                      if (masked != value) {
                                        ctrl.value = TextEditingValue(
                                          text: masked,
                                          selection: TextSelection.collapsed(offset: masked.length),
                                        );
                                      }
                                    },
                                    decoration: _decoration('Quantidade de destino'),
                                  ),
                                  TextFormField(
                                    controller: campos['difAmb'],
                                    enabled: false,
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) {
                                      final ctrl = campos['difAmb']!;
                                      final masked = _aplicarMascaraNotasFiscais(value);

                                      if (masked != value) {
                                        ctrl.value = TextEditingValue(
                                          text: masked,
                                          selection: TextSelection.collapsed(offset: masked.length),
                                        );
                                      }
                                    },
                                    decoration: _decoration('Complemento/Retirada'),
                                  ),
                                ]),
                                const SizedBox(height: 20),
                                _secao('Volumes apurados a 20 ºC'),
                                _linha([
                                  TextFormField(
                                    controller: campos['origem20'],
                                    focusNode: _focusOrigem20,
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) {
                                      final ctrl = campos['origem20']!;
                                      final masked = _aplicarMascaraNotasFiscais(value);

                                      if (masked != value) {
                                        ctrl.value = TextEditingValue(
                                          text: masked,
                                          selection: TextSelection.collapsed(offset: masked.length),
                                        );
                                      }
                                      _calcularDiferenca20C();
                                    },
                                    decoration: _decoration('Quantidade de origem'),
                                  ),
                                  TextFormField(
                                    controller: campos['destino20'],
                                    style: TextStyle(color: const Color.fromARGB(255, 0, 81, 255)),
                                    enabled: false,
                                    focusNode: _focusDestino20,
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) {
                                      final ctrl = campos['destino20']!;
                                      final masked = _aplicarMascaraNotasFiscais(value);

                                      if (masked != value) {
                                        ctrl.value = TextEditingValue(
                                          text: masked,
                                          selection: TextSelection.collapsed(offset: masked.length),
                                        );
                                      }
                                    },
                                    decoration: _decoration('Quantidade de destino'),
                                  ),
                                  TextFormField(
                                    controller: campos['dif20'],
                                    enabled: false,
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) {
                                      final ctrl = campos['dif20']!;
                                      final masked = _aplicarMascaraNotasFiscais(value);

                                      if (masked != value) {
                                        ctrl.value = TextEditingValue(
                                          text: masked,
                                          selection: TextSelection.collapsed(offset: masked.length),
                                        );
                                      }
                                    },
                                    decoration: _decoration('Diferença'),
                                  ),
                                ]),
                                const SizedBox(height: 40),


                                // ================= BOTÕES DE AÇÃO =================
                                const SizedBox(height: 40),
                                
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ElevatedButton.icon(
                              onPressed: (!_analiseConcluida && tipoOperacao != null) ? _confirmarConclusao : null,
                              icon: Icon(_analiseConcluida ? Icons.check_circle_outline : Icons.check_circle, size: 24),
                              label: Text(
                                _analiseConcluida ? 'Ordem emitida' : 'Emitir ordem',
                                style: const TextStyle(fontSize: 16),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _analiseConcluida ? Colors.grey[400] : Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            
                            // BOTÃO GERAR PDF (CENTRO) - AGORA NO MEIO
                            ElevatedButton.icon(
                              onPressed: (_analiseConcluida && tipoOperacao != null) ? _baixarPDF : null,
                              icon: Icon(
                                Icons.picture_as_pdf, 
                                size: 24,
                                color: _analiseConcluida ? Colors.white : Colors.grey[600],
                              ),
                              label: Text(
                                'Gerar Certificado PDF',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: _analiseConcluida ? Colors.white : Colors.grey[600],
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _analiseConcluida 
                                    ? const Color(0xFF0D47A1) // Azul quando disponível
                                    : Colors.grey[300], // Cinza claro quando indisponível
                                foregroundColor: _analiseConcluida ? Colors.white : Colors.grey[600],
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                    color: _analiseConcluida 
                                        ? const Color(0xFF0D47A1)
                                        : Colors.grey[400]!,
                                    width: 1,
                                  ),
                                ),
                                elevation: _analiseConcluida ? 2 : 0, // Sombra só quando ativo
                                shadowColor: _analiseConcluida ? const Color(0xFF0D47A1).withOpacity(0.3) : Colors.transparent,
                              ),
                            ),
                            
                            // BOTÃO NOVO DOCUMENTO (DIREITA) - AGORA NA DIREITA
                            ElevatedButton.icon(
                              onPressed: _novoDocumento,
                              icon: const Icon(Icons.add, size: 24),
                              label: const Text(
                                'Novo documento',
                                style: TextStyle(fontSize: 16),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange, // Laranja para destacar
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
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
            ),
          ),
        ),
      ],
    );
  }

  // ================= UI HELPERS =================
  Widget _linha(List<Widget> campos) => Row(
        children: campos
            .map((c) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: c,
                  ),
                ))
            .toList(),
      );

  // NOVO MÉTODO: Para linhas com controle flexível de tamanho
  Widget _linhaFlexivel(List<Map<String, dynamic>> camposConfig) => Row(
        children: camposConfig
            .map((config) => Expanded(
                  flex: config['flex'] ?? 1, // flex padrão é 1
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: config['widget'],
                  ),
                ))
            .toList(),
      );

  Widget _campo(String label, TextEditingController c,
      {bool enabled = true}) {
    return TextFormField(
      controller: c,
      enabled: enabled,
      decoration: _decoration(label, disabled: !enabled),
    );
  }

  InputDecoration _decoration(String label,
          {bool disabled = false}) =>
      InputDecoration(
        labelText: label,
        filled: true,
        fillColor:
            disabled ? Colors.grey.shade200 : Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6)),
      );

  Widget _secao(String t) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const SizedBox(height: 6),
          Text(
            t.toUpperCase(),
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D47A1)),
          ),
          const SizedBox(height: 10),
        ],
      );

  // ================= CÁLCULOS - CÓPIA FIÉL DO CACL =================
  Future<String> _buscarDensidade20C({
    required String temperaturaAmostra,
    required String densidadeObservada,
    required String produtoNome,
  }) async {
    final supabase = Supabase.instance.client;
    
    try {
      if (temperaturaAmostra.isEmpty || densidadeObservada.isEmpty) {
        return '-';
      }
      
      final nomeProdutoLower = produtoNome.toLowerCase().trim();
      final bool usarViewAnidroHidratado = 
          nomeProdutoLower.contains('anidro') || 
          nomeProdutoLower.contains('hidratado');
      
      // Formata temperatura igual ao CACL
      String temperaturaFormatada = temperaturaAmostra
          .replaceAll(' ºC', '')
          .replaceAll('°C', '')
          .replaceAll('ºC', '')
          .replaceAll('°', '')
          .replaceAll('C', '')
          .trim();
      
      temperaturaFormatada = temperaturaFormatada.replaceAll('.', ',');
      
      // Formata densidade igual ao CACL
      String densidadeFormatada = densidadeObservada
          .replaceAll(' ', '')
          .replaceAll('°C', '')
          .replaceAll('ºC', '')
          .replaceAll('°', '')
          .trim();
      
      densidadeFormatada = densidadeFormatada.replaceAll('.', ',');
      
      if (!densidadeFormatada.contains(',')) {
        if (densidadeFormatada.length == 4) {
          densidadeFormatada = '0,${densidadeFormatada.substring(0, 3)}';
        } else {
          densidadeFormatada = '0,$densidadeFormatada';
        }
      }
      
      String nomeColuna;
      if (densidadeFormatada.contains(',')) {
        final partes = densidadeFormatada.split(',');
        if (partes.length == 2) {
          String parteInteira = partes[0];
          String parteDecimal = partes[1];
          
          parteDecimal = parteDecimal.padRight(4, '0');
          
          if (parteDecimal.length > 4) {
            parteDecimal = parteDecimal.substring(0, 4);
          }
          
          String densidade5Digitos = '${parteInteira}${parteDecimal}'.padLeft(5, '0');
          
          if (densidade5Digitos.length > 5) {
            densidade5Digitos = densidade5Digitos.substring(0, 5);
          }
          
          nomeColuna = 'd_$densidade5Digitos';
        } else {
          return '-';
        }
      } else {
        return '-';
      }
      
      final nomeView = usarViewAnidroHidratado 
          ? 'tcd_anidro_hidratado_vw' 
          : 'tcd_gasolina_diesel_vw';
      
      String _formatarResultado(String valorBruto) {
        String valorLimpo = valorBruto.trim();
        valorLimpo = valorLimpo.replaceAll('.', ',');
        
        if (!valorLimpo.contains(',')) {
          valorLimpo = '$valorLimpo,0';
        }
        
        final partes = valorLimpo.split(',');
        if (partes.length == 2) {
          String parteInteira = partes[0];
          String parteDecimal = partes[1];
          
          parteDecimal = parteDecimal.padRight(4, '0');
          
          if (parteDecimal.length > 4) {
            parteDecimal = parteDecimal.substring(0, 4);
          }
          
          return '$parteInteira,$parteDecimal';
        }
        
        return valorLimpo;
      }
      
      // Busca inicial
      final resultado = await supabase
          .from(nomeView)
          .select(nomeColuna)
          .eq('temperatura_obs', temperaturaFormatada)
          .maybeSingle();
      
      if (resultado != null && resultado[nomeColuna] != null) {
        String valorBruto = resultado[nomeColuna].toString();
        return _formatarResultado(valorBruto);
      }
      
      // Fallback para formatos alternativos de temperatura (igual ao CACL)
      List<String> formatosParaTentar = [];
      
      if (temperaturaFormatada.contains(',')) {
        final partes = temperaturaFormatada.split(',');
        if (partes.length == 2) {
          String parteInteira = partes[0];
          String parteDecimal = partes[1];
          
          if (usarViewAnidroHidratado) {
            formatosParaTentar.addAll([
              '$parteInteira,$parteDecimal',
              '$parteInteira,${parteDecimal}0',
              '$parteInteira,${parteDecimal.padLeft(2, '0')}',
              '$parteInteira,0$parteDecimal',
            ]);
            
            if (parteDecimal.length == 1) {
              formatosParaTentar.add('$parteInteira,${parteDecimal}0');
            }
            
            if (parteDecimal.length == 2) {
              formatosParaTentar.add('$parteInteira,${parteDecimal.substring(0, 1)}');
            }
          } else {
            formatosParaTentar.addAll([
              '$parteInteira,$parteDecimal',
              '$parteInteira,${parteDecimal}0',
              '$parteInteira,0',
            ]);
          }
        }
      } else {
        if (usarViewAnidroHidratado) {
          formatosParaTentar.addAll([
            '$temperaturaFormatada,00',
            '$temperaturaFormatada,0',
            temperaturaFormatada,
          ]);
        } else {
          formatosParaTentar.addAll([
            '$temperaturaFormatada,0',
            temperaturaFormatada,
            '$temperaturaFormatada,00',
          ]);
        }
      }
      
      final formatosComPonto = formatosParaTentar.map((f) => f.replaceAll(',', '.')).toList();
      formatosParaTentar.addAll(formatosComPonto);
      formatosParaTentar = formatosParaTentar.toSet().toList();
      
      for (final formatoTemp in formatosParaTentar) {
        try {
          final resultado = await supabase
              .from(nomeView)
              .select(nomeColuna)
              .eq('temperatura_obs', formatoTemp)
              .maybeSingle();
          
          if (resultado != null && resultado[nomeColuna] != null) {
            String valorBruto = resultado[nomeColuna].toString();
            return _formatarResultado(valorBruto);
          }
        } catch (e) {
          continue;
        }
      }
      
      return '-';
      
    } catch (e) {
      return '-';
    }
  }

  Future<String> _buscarFCV({
    required String temperaturaTanque,
    required String densidade20C,
    required String produtoNome,
  }) async {
    final supabase = Supabase.instance.client;

    try {
      if (temperaturaTanque.isEmpty ||
          temperaturaTanque == '-' ||
          densidade20C.isEmpty ||
          densidade20C == '-') {
        return '-';
      }

      // ================= VIEW =================
      final nomeProdutoLower = produtoNome.toLowerCase().trim();
      final nomeView = (nomeProdutoLower.contains('anidro') ||
              nomeProdutoLower.contains('hidratado'))
          ? 'tcv_anidro_hidratado_vw'
          : 'tcv_gasolina_diesel_vw';

      // ================= TEMPERATURA =================
      String temperaturaFormatada = temperaturaTanque
          .replaceAll('°C', '')
          .replaceAll('ºC', '')
          .replaceAll('°', '')
          .replaceAll('C', '')
          .trim()
          .replaceAll('.', ',');

      // ================= DENSIDADE =================
      String densidadeFormatada =
          densidade20C.trim().replaceAll('.', ',');

      final densidadeNum =
          double.tryParse(densidadeFormatada.replaceAll(',', '.'));

      if (densidadeNum == null) {
        return '-';
      }

      // ================= FORMATADOR FCV =================
      String _formatarFCV(String valor) {
        String v = valor.replaceAll('.', ',').trim();

        if (!v.contains(',')) {
          return '$v,0000';
        }

        final partes = v.split(',');
        String inteiro = partes[0];
        String decimal = partes[1];

        decimal = decimal.padRight(4, '0');
        if (decimal.length > 4) {
          decimal = decimal.substring(0, 4);
        }

        return '$inteiro,$decimal';
      }

      // ================= CONVERTE DENSIDADE EM CÓDIGO =================
      String _densidadeParaCodigo(String densidade) {
        final partes = densidade.split(',');
        if (partes.length != 2) return '';
        final codigo =
            '${partes[0]}${partes[1].padRight(4, '0')}'.padLeft(5, '0');
        return codigo.length > 5 ? codigo.substring(0, 5) : codigo;
      }

      final codigoOriginal = _densidadeParaCodigo(densidadeFormatada);

      // ================= BUSCA FCV DIRETA =================
      Future<String?> _buscarFCVPorCodigo(String codigo) async {
        final coluna = 'v_$codigo';

        try {
          final r = await supabase
              .from(nomeView)
              .select(coluna)
              .eq('temperatura_obs', temperaturaFormatada)
              .maybeSingle();

          if (r != null && r[coluna] != null) {
            return _formatarFCV(r[coluna].toString());
          }
        } catch (_) {}
        return null;
      }

      // 1️⃣ Tentativa direta com a densidade original
      final direto = await _buscarFCVPorCodigo(codigoOriginal);
      if (direto != null) return direto;

      // ================= BUSCA DENSIDADE MAIS PRÓXIMA =================
      // Busca todas as densidades disponíveis na view
      final sampleRow = await supabase
          .from(nomeView)
          .select()
          .limit(1)
          .maybeSingle();

      if (sampleRow == null) {
        return '-';
      }

      // Extrai todas as densidades disponíveis da view
      final densidadesDisponiveis = sampleRow.keys
          .where((k) => k.startsWith('v_'))
          .map((k) {
            final codigo = k.replaceFirst('v_', '');
            if (codigo.length == 5) {
              final valor =
                  double.tryParse('${codigo[0]}.${codigo.substring(1)}');
              if (valor != null) {
                return {
                  'codigo': codigo,
                  'valor': valor,
                  'diferenca': (valor - densidadeNum).abs()
                };
              }
            }
            return null;
          })
          .whereType<Map<String, dynamic>>()
          .toList();

      if (densidadesDisponiveis.isEmpty) {
        return '-';
      }

      // Ordena por proximidade (menor diferença primeiro)
      densidadesDisponiveis.sort((a, b) {
        final da = a['diferenca'] as double;
        final db = b['diferenca'] as double;
        return da.compareTo(db);
      });

      // Pega a densidade mais próxima
      final densidadeMaisProxima = densidadesDisponiveis.first;
      final codigoMaisProximo = densidadeMaisProxima['codigo'] as String;
      final diferenca = densidadeMaisProxima['diferenca'] as double;

      // 2️⃣ Tenta buscar FCV com a densidade mais próxima
      final aproximado = await _buscarFCVPorCodigo(codigoMaisProximo);
      
      if (aproximado != null) {
        // Mostra alerta informando que usou valor aproximado
        if (context.mounted && diferenca > 0.0001) { // Só mostra se houver diferença significativa
          WidgetsBinding.instance.addPostFrameCallback((_) {
            
          });
        }
        return aproximado;
      }

      // 3️⃣ Fallback: tenta buscar com valores de temperatura alternativos
      final temperaturaAlternativas = [
        temperaturaFormatada,
        temperaturaFormatada.replaceAll(',', '.'),
        ..._gerarVariacoesTemperatura(temperaturaFormatada),
      ];

      for (final tempAlt in temperaturaAlternativas) {
        try {
          final r = await supabase
              .from(nomeView)
              .select('v_$codigoMaisProximo')
              .eq('temperatura_obs', tempAlt)
              .maybeSingle();

          if (r != null && r['v_$codigoMaisProximo'] != null) {
            if (context.mounted && diferenca > 0.0001) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                
              });
            }
            return _formatarFCV(r['v_$codigoMaisProximo'].toString());
          }
        } catch (_) {
          continue;
        }
      }

      return '-';
    } catch (_) {
      return '-';
    }
  }

  // Função auxiliar para gerar variações de temperatura
  List<String> _gerarVariacoesTemperatura(String temperatura) {
    final List<String> variacoes = [];
    
    if (temperatura.contains(',')) {
      final partes = temperatura.split(',');
      final inteiro = partes[0];
      final decimal = partes[1];
      
      // Para anidro/hidratado
      variacoes.addAll([
        '$inteiro,${decimal.padRight(2, '0')}', // Completa com zeros
        '$inteiro,${decimal.substring(0, decimal.length - 1)}', // Remove último dígito
      ]);
      
      // Para gasolina/diesel
      if (decimal.length > 1) {
        variacoes.add('$inteiro,${decimal.substring(0, 1)}');
      }
      
      // Versão com ponto
      final temperaturaComPonto = temperatura.replaceAll(',', '.');
      variacoes.addAll([
        temperaturaComPonto,
        '$inteiro.${decimal.padRight(2, '0')}',
      ]);
    } else {
      // Temperatura sem decimal
      variacoes.addAll([
        '$temperatura,0',
        '$temperatura,00',
        '$temperatura.0',
        '$temperatura.00',
      ]);
    }
    
    return variacoes.toSet().toList(); // Remove duplicatas
  }


  @override
  void dispose() {
    _focusTempCT.dispose();
    _focusDestinoAmb.dispose();
    _focusDestino20.dispose();
    _focusOrigem20.dispose();
    super.dispose();
  }

  // ================= DOWNLOAD PDF =================
  Future<void> _baixarPDF() async {
    // 1. Validações
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha todos os campos obrigatórios!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_analiseConcluida) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conclua a análise primeiro para gerar o PDF!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (tipoOperacao == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione o tipo de operação!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    if (produtoSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione um produto!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // 2. Mostra loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
    
    try {
      // 3. Prepara os dados para o PDF
      final dadosPDF = {
        'numeroControle': campos['numeroControle']!.text,
        'transportadora': campos['transportadora']!.text,
        'motorista': campos['motorista']!.text,
        'placaCavalo': campos['placaCavalo']!.text,
        'carreta1': campos['carreta1']!.text,
        'carreta2': campos['carreta2']!.text,
        'notas': campos['notas']!.text,
        'tempAmostra': campos['tempAmostra']!.text,
        'densidadeAmostra': campos['densidadeAmostra']!.text,
        'tempCT': campos['tempCT']!.text,
        'densidade20': campos['densidade20']!.text,
        'fatorCorrecao': campos['fatorCorrecao']!.text,
        'origemAmb': campos['origemAmb']!.text,
        'destinoAmb': campos['destinoAmb']!.text,
        'difAmb': campos['difAmb']!.text,
        'origem20': campos['origem20']!.text,
        'destino20': campos['destino20']!.text,
        'dif20': campos['dif20']!.text,
      };
      
      // 4. Gera o PDF usando a classe separada
      final pdfDocument = await CertificadoPDF.gerar(
        data: dataCtrl.text,
        hora: horaCtrl.text,
        produto: produtoSelecionado,
        tipoOperacao: tipoOperacao,
        campos: dadosPDF,
      );
      
      // 5. Converte o documento para bytes
      final pdfBytes = await pdfDocument.save();
      
      // 6. Fecha loading
      if (context.mounted) Navigator.of(context).pop();
      
      // 7. Faz download
      if (kIsWeb) {
        await _downloadForWeb(pdfBytes);
      } else {
        print('PDF gerado (${pdfBytes.length} bytes) - Plataforma não web');
        _showMobileMessage();
      }
      
      // 8. Mensagem de sucesso
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Certificado baixado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
    } catch (e) {
      // 9. Tratamento de erro
      print('ERRO no _baixarPDF: $e');
      
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao gerar PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Função SIMPLES para download Web
  
  Future<void> _downloadForWeb(Uint8List bytes) async {
    try {
      // Converte bytes para Base64
      final base64 = base64Encode(bytes);
      
      // Cria URL de dados
      final dataUrl = 'data:application/pdf;base64,$base64';
      
      // Cria nome do arquivo
      final fileName = 'Certificado_${produtoSelecionado ?? "Analise"}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      
      // JavaScript para fazer o download
      final jsCode = '''
        try {
          // Cria elemento de link
          const link = document.createElement('a');
          link.href = '$dataUrl';
          link.download = '$fileName';
          link.style.display = 'none';
          
          // Adiciona à página
          document.body.appendChild(link);
          
          // Clica no link para iniciar download
          link.click();
          
          // Remove o link depois de um tempo
          setTimeout(() => {
            document.body.removeChild(link);
          }, 100);
          
          console.log('Download iniciado: ' + '$fileName');
        } catch (error) {
          console.error('Erro no download automático:', error);
          // Fallback: abre em nova aba
          window.open('$dataUrl', '_blank');
        }
      ''';
      
      // Executa o JavaScript
      js.context.callMethod('eval', [jsCode]);
      
    } catch (e) {
      print('Erro no download Web: $e');
      
      // Fallback: instruções manuais
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Como baixar manualmente'),
            content: const Text(
              '1. O PDF foi gerado com sucesso\n'
              '2. Se não baixou automaticamente:\n'
              '3. Clique com botão direito na tela\n'
              '4. Selecione "Salvar página como"\n'
              '5. Salve como arquivo PDF',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  // Função auxiliar para mobile
  void _showMobileMessage() {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF gerado! Em breve disponível para download no mobile.'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  String _aplicarMascaraNotasFiscais(String texto) {
    // Remove tudo que não é número
    String apenasNumeros = texto.replaceAll(RegExp(r'[^\d]'), '');

    // Limita a 6 dígitos
    if (apenasNumeros.length > 6) {
      apenasNumeros = apenasNumeros.substring(0, 6);
    }

    if (apenasNumeros.isEmpty) return '';

    // Aplica máscara 999.999
    if (apenasNumeros.length > 3) {
      String parteMilhar = apenasNumeros.substring(0, apenasNumeros.length - 3);
      String parteCentena = apenasNumeros.substring(apenasNumeros.length - 3);
      return '$parteMilhar.$parteCentena';
    }

    return apenasNumeros;
  }

  String _aplicarMascaraTemperatura(String texto) {
    // Remove tudo que não for número
    String apenasNumeros = texto.replaceAll(RegExp(r'[^\d]'), '');

    // Limita a 3 dígitos numéricos
    if (apenasNumeros.length > 3) {
      apenasNumeros = apenasNumeros.substring(0, 3);
    }

    if (apenasNumeros.isEmpty) return '';

    // Insere vírgula antes do 3º dígito
    if (apenasNumeros.length > 2) {
      return '${apenasNumeros.substring(0, 2)},${apenasNumeros.substring(2)}';
    }

    return apenasNumeros;
  }

  String _aplicarMascaraDensidade(String texto) {
    // Remove tudo que não for número
    String apenasNumeros = texto.replaceAll(RegExp(r'[^\d]'), '');

    if (apenasNumeros.isEmpty) return '';

    // Limita a 5 caracteres no total (ex: 0,7456)
    if (apenasNumeros.length > 5) {
      apenasNumeros = apenasNumeros.substring(0, 5);
    }

    // Primeiro dígito é parte inteira, resto é decimal
    String parteInteira = apenasNumeros.substring(0, 1);
    String parteDecimal =
        apenasNumeros.length > 1 ? apenasNumeros.substring(1) : '';

    return parteDecimal.isEmpty
        ? '$parteInteira,'
        : '$parteInteira,$parteDecimal';
  }

  // Função para calcular diferença dos volumes ambiente
  void _calcularDiferencaAmbiente() {
    try {
      final origemText = campos['origemAmb']!.text;
      final destinoText = campos['destinoAmb']!.text;
      
      if (origemText.isEmpty || destinoText.isEmpty) {
        campos['difAmb']!.text = '';
        return;
      }
      
      // Remove pontos de separação de milhar
      final origemLimpa = origemText.replaceAll('.', '');
      final destinoLimpa = destinoText.replaceAll('.', '');
      
      // Converte para double
      final origem = double.tryParse(origemLimpa);
      final destino = double.tryParse(destinoLimpa);
      
      if (origem != null && destino != null) {
        final diferenca = destino - origem;
        
        // Formata o resultado COM SINAL
        final resultadoFormatado = _formatarDiferencaComSinal(diferenca);
        
        // Atualiza o campo de diferença
        campos['difAmb']!.text = resultadoFormatado;
      } else {
        campos['difAmb']!.text = '';
      }
    } catch (e) {
      print('Erro ao calcular diferença ambiente: $e');
      campos['difAmb']!.text = '';
    }
  }

  // Função para calcular diferença dos volumes a 20°C
    void _calcularDiferenca20C() {
    try {
      final origemText = campos['origem20']!.text;
      final destinoText = campos['destino20']!.text;
      
      if (origemText.isEmpty || destinoText.isEmpty) {
        campos['dif20']!.text = '';
        return;
      }
      
      // Remove pontos de separação de milhar
      final origemLimpa = origemText.replaceAll('.', '');
      final destinoLimpa = destinoText.replaceAll('.', '');
      
      // Converte para double
      final origem = double.tryParse(origemLimpa);
      final destino = double.tryParse(destinoLimpa);
      
      if (origem != null && destino != null) {
        final diferenca = destino - origem;
        
        // Formata o resultado COM SINAL
        final resultadoFormatado = _formatarDiferencaComSinal(diferenca);
        
        // Atualiza o campo de diferença
        campos['dif20']!.text = resultadoFormatado;
      } else {
        campos['dif20']!.text = '';
      }
    } catch (e) {
      print('Erro ao calcular diferença 20°C: $e');
      campos['dif20']!.text = '';
    }
  }

  // Função para formatar diferenças COM SINAL (+/-)
  String _formatarDiferencaComSinal(double valor) {
    if (valor.isNaN || valor.isInfinite) {
      return '';
    }
    
    // Determina o sinal
    String sinal = '';
    if (valor > 0) {
      sinal = '+';
    } else if (valor < 0) {
      sinal = '-';
    }
    // Para valor = 0, não coloca sinal
    
    // Pega o valor absoluto para formatação
    double valorAbs = valor.abs();
    
    // Converte para número inteiro (arredondar para baixo)
    int valorInteiro = valorAbs.floor();
    
    // Converte para string
    String valorFormatado = valorInteiro.toString();
    
    // Aplica máscara de milhar
    valorFormatado = _aplicarMascaraMilhar(valorFormatado);
    
    // Retorna com sinal
    return sinal + valorFormatado;
  }

  // Função auxiliar para aplicar máscara de milhar
  String _aplicarMascaraMilhar(String texto) {
    // Remove tudo que não é número
    String apenasNumeros = texto.replaceAll(RegExp(r'[^\d]'), '');
    
    if (apenasNumeros.isEmpty || apenasNumeros == '0') {
      return '0';
    }
    
    // Aplica máscara de milhar
    String resultado = '';
    for (int i = apenasNumeros.length - 1, count = 0; i >= 0; i--, count++) {
      if (count > 0 && count % 3 == 0) {
        resultado = '.$resultado';
      }
      resultado = apenasNumeros[i] + resultado;
    }
    
    return resultado;
  }

  // Função para calcular destino a 20°C automaticamente
  void _calcularDestino20CAutomatico() {
    try {
      // 1. Verificar se o FCV está disponível
      final fcvText = campos['fatorCorrecao']!.text;
      if (fcvText.isEmpty || fcvText == '-') {
        print('FCV não disponível para cálculo');
        return; // Não calcula se não tiver FCV
      }
      
      // 2. Pegar o valor de destino ambiente
      final destinoAmbText = campos['destinoAmb']!.text;
      if (destinoAmbText.isEmpty) {
        // Se destino ambiente estiver vazio, limpa o destino 20°C
        campos['destino20']!.text = '';
        _calcularDiferenca20C();
        return;
      }
      
      // 3. Limpar os valores para conversão
      // Remover ponto de milhar e substituir vírgula por ponto para cálculo
      final destinoAmbLimpo = destinoAmbText.replaceAll('.', '');
      final fcvLimpo = fcvText.replaceAll(',', '.');
      
      // 4. Converter para números
      final destinoAmb = double.tryParse(destinoAmbLimpo);
      final fcv = double.tryParse(fcvLimpo);
      
      if (destinoAmb == null || fcv == null) {
        return; // Se não conseguir converter, sai
      }
      
      // 5. Calcular: destino (20°C) = destino (ambiente) × FCV
      final destino20C = destinoAmb * fcv;
      
      // 6. Formatar o resultado SEM casas decimais
      String destino20CFormatado = _formatarNumeroParaCampo(destino20C);
      
      // 7. Atualizar o campo destino20
      campos['destino20']!.text = destino20CFormatado;
      
      // 8. Recalcular a diferença a 20°C
      _calcularDiferenca20C();
                  
    } catch (e) {
      print('Erro ao calcular destino 20°C automático: $e');
    }
  }
  
  // Função para formatar número para o campo (COM arredondamento, SEM casas decimais)
  String _formatarNumeroParaCampo(double valor) {
    if (valor.isNaN || valor.isInfinite) {
      return '';
    }
    
    // 1. Arredondar para o número inteiro mais próximo
    int valorInteiro = valor.round(); // round() arredonda (0.5 para cima)
    
    // 2. Converter para string
    String valorStr = valorInteiro.toString();
    
    // 3. Aplicar máscara de milhar
    valorStr = _aplicarMascaraMilhar(valorStr);
    
    return valorStr;
  }

  // Método para confirmar conclusão da análise
  void _confirmarConclusao() {
    // Validações básicas antes de mostrar o diálogo
    if (tipoOperacao == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione o tipo de operação!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (produtoSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione um produto!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Mostra o diálogo personalizado
    showDialog(
      context: context,
      barrierDismissible: false, // Não fecha ao clicar fora
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
            side: const BorderSide(
              color: Color(0xFF0D47A1),
              width: 2.0,
            ),
          ),
          backgroundColor: Colors.white,
          title: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0D47A1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.white, size: 28),
                SizedBox(width: 12),
                Text(
                  'Confirmação',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          content: SizedBox(
            width: 400, // Largura fixa
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                const Text(
                  'Tem certeza que deseja emitir a ordem?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber[200]!),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Após a emissão, qualquer edição ou correção no documento só poderá ser realizada por um supervisor nível 3.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color.fromARGB(255, 239, 108, 0),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          actions: [
            // BOTÃO CANCELAR
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Fecha o diálogo
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[700],
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey[400]!),
                ),
              ),
              child: const Text(
                'Cancelar',
                style: TextStyle(fontSize: 16),
              ),
            ),

            // BOTÃO CONFIRMAR
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Fecha o diálogo
                _processarConclusao(); // Processa a conclusão
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Confirmar Emissão',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        );
      },
    );
  }
  
  // Método para processar a conclusão da análise
  Future<void> _processarConclusao() async {
    // Mostra um loading enquanto processa
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0D47A1)),
        ),
      ),
    );

    try {
      final supabase = Supabase.instance.client;
      
      // 1. Obter o usuário autenticado
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Usuário não autenticado');
      }

      final usuario = UsuarioAtual.instance;
      if (usuario == null || usuario.filialId == null) {
        throw Exception('Usuário sem filial vinculada.');
      }
      
      // 2. Formatar os dados para o banco
      final Map<String, dynamic> dadosParaBanco = {
        'data_analise': _formatarDataParaBanco(dataCtrl.text),
        'hora_analise': horaCtrl.text,
        'tipo_operacao': tipoOperacao!,
        'produto_nome': produtoSelecionado!,
        'transportadora': campos['transportadora']!.text,
        'motorista': campos['motorista']!.text,
        'notas_fiscais': campos['notas']!.text,
        'placa_cavalo': campos['placaCavalo']!.text,
        'carreta1': campos['carreta1']!.text,
        'carreta2': campos['carreta2']!.text,
        'temperatura_amostra': _converterParaDecimal(campos['tempAmostra']!.text),
        'densidade_observada': _converterParaDecimal(campos['densidadeAmostra']!.text),
        'temperatura_ct': _converterParaDecimal(campos['tempCT']!.text),
        'densidade_20c': _converterParaDecimal(campos['densidade20']!.text),
        'fator_correcao': _converterParaDecimal(campos['fatorCorrecao']!.text),
        'origem_ambiente': _converterParaInteiro(campos['origemAmb']!.text),
        'destino_ambiente': _converterParaInteiro(campos['destinoAmb']!.text),
        'origem_20c': _converterParaInteiro(campos['origem20']!.text),
        'destino_20c': _converterParaInteiro(campos['destino20']!.text),
        'analise_concluida': true,
        'data_conclusao': DateTime.now().toIso8601String(),
        'usuario_id': user.id,
        'filial_id': usuario.filialId,
        'status': 'concluida',
      };
      
      // 3. Se tiver o produto_id, adicionar também
      final produtoResult = await supabase
          .from('produtos')
          .select('id')
          .eq('nome', produtoSelecionado!)
          .maybeSingle();
      
      if (produtoResult != null) {
        dadosParaBanco['produto_id'] = produtoResult['id'];
      }
      
      // 4. Inserir no banco de dados (ordens_analises)
      final response = await supabase
          .from('ordens_analises')
          .insert(dadosParaBanco)
          .select('id, numero_controle')
          .single();
      
      // 5. Atualizar o número de controle no campo
      campos['numeroControle']!.text = response['numero_controle'].toString();
      
      // 6. Salvar também na tabela de movimentações
      dadosParaBanco['id'] = response['id']; // Adicionar ID da análise
      await _salvarMovimentacao(dadosParaBanco);
      
      // 7. Fechar loading
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      
      // 8. ATUALIZAR O ESTADO - Análise concluída!
      setState(() {
        _analiseConcluida = true;
      });
      
      // 9. Mostrar mensagem de sucesso
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '✓ Ordem ${response['numero_controle']} emitida com sucesso! O PDF agora está disponível.',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      
    } catch (e) {
      // Fecha o loading em caso de erro
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      
      // Mostra mensagem de erro
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Erro ao emitir ordem: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      
      print('Erro ao emitir ordem: $e');
    }
  }

  // Método para salvar na tabela de movimentações
  Future<void> _salvarMovimentacao(Map<String, dynamic> dadosOrdem) async {
    try {
      final supabase = Supabase.instance.client;
      
      final user = supabase.auth.currentUser;
      if (user == null) return;
      
      String? filialId;
      String? empresaId;
      
      final usuarioData = await supabase
          .from('usuarios')
          .select('id_filial, empresa_id')
          .eq('id', user.id)
          .maybeSingle();
      
      if (usuarioData != null) {
        filialId = usuarioData['id_filial']?.toString();
        empresaId = usuarioData['empresa_id']?.toString();
      }
      
      if (filialId == null) {
        final primeiraFilial = await supabase
            .from('filiais')
            .select('id')
            .limit(1)
            .maybeSingle();
        filialId = primeiraFilial?['id']?.toString();
      }
      
      if (empresaId == null) {
        final primeiraEmpresa = await supabase
            .from('empresas')
            .select('id')
            .limit(1)
            .maybeSingle();
        empresaId = primeiraEmpresa?['id']?.toString();
      }
      
      if (filialId == null || empresaId == null) {
        return;
      }
      
      final List<String> placasArray = [];
      
      void adicionarPlacaSePreenchida(String placa) {
        final placaLimpa = placa.trim();
        if (placaLimpa.isNotEmpty && placaLimpa != '-') {
          placasArray.add(placaLimpa);
        }
      }
      
      adicionarPlacaSePreenchida(campos['placaCavalo']!.text);
      adicionarPlacaSePreenchida(campos['carreta1']!.text);
      adicionarPlacaSePreenchida(campos['carreta2']!.text);
      
      final isCarga = tipoOperacao == 'Carga';
      
      final saidaAmb = isCarga ? dadosOrdem['origem_ambiente'] : null;
      final saidaVinte = isCarga ? dadosOrdem['origem_20c'] : null;
      final entradaAmb = isCarga ? null : dadosOrdem['origem_ambiente'];
      final entradaVinte = isCarga ? null : dadosOrdem['destino_20c'];
      
      final Map<String, dynamic> camposProduto = _mapearCamposProduto();
      
      final Map<String, dynamic> dadosMovimentacao = {
        'filial_id': filialId,
        'empresa_id': empresaId,
        'descricao': null,
        'cliente': null,
        'anp': false,
        'entrada_amb': entradaAmb,
        'entrada_vinte': entradaVinte,
        'saida_amb': saidaAmb,
        'saida_vinte': saidaVinte,
        'produto_id': dadosOrdem['produto_id'],
        'placa': placasArray.isNotEmpty ? '{${placasArray.join(',')}}' : null,
        'codigo': null,
        'cacl_id': null,
        'uf': null,
        'forma_pagamento': null,
        'observacoes': null,
        'quantidade': null,
        'usuario_id': dadosOrdem['usuario_id'],
        'created_at': _obterTimestampBrasilia(),
        'data_mov': _obterTimestampBrasilia(),
        'updated_at': _obterTimestampBrasilia(),
        ...camposProduto,
      };
      
      await supabase
          .from('movimentacoes')
          .insert(dadosMovimentacao);
      
    } catch (e) {
      // Não lançar exceção
    }
  }

  Map<String, dynamic> _mapearCamposProduto() {
    final produto = produtoSelecionado?.toLowerCase() ?? '';
    final quantidade = _converterParaInteiro(campos['origemAmb']!.text) ?? 0;
    
    final camposProduto = {
      'g_comum': 0,
      'g_aditivada': 0,
      'd_s10': 0,
      'd_s500': 0,
      'etanol': 0,
      'anidro': 0,
      'b100': 0,
      'gasolina_a': 0,
      's500_a': 0,
      's10_a': 0,
    };
    
    if (produto.contains('gasolina')) {
      if (produto.contains('comum')) {
        camposProduto['g_comum'] = quantidade;
      } else if (produto.contains('aditivada')) {
        camposProduto['g_aditivada'] = quantidade;
      } else {
        camposProduto['gasolina_a'] = quantidade;
      }
    } else if (produto.contains('diesel')) {
      if (produto.contains('s10')) {
        camposProduto['d_s10'] = quantidade;
      } else if (produto.contains('s500')) {
        camposProduto['d_s500'] = quantidade;
      }
    } else if (produto.contains('etanol')) {
      if (produto.contains('anidro')) {
        camposProduto['anidro'] = quantidade;
      } else if (produto.contains('hidratado')) {
        camposProduto['etanol'] = quantidade;
      }
    } else if (produto.contains('b100')) {
      camposProduto['b100'] = quantidade;
    }
    
    return camposProduto;
  }  

  // Método para limpar/reiniciar o formulário
  void _novoDocumento() {
    // VERIFICAÇÃO: Se a análise estiver concluída, NÃO mostra o diálogo
    if (_analiseConcluida) {
      // Apenas limpa o formulário sem mostrar diálogo
      _limparFormulario();
      return;
    }
    
    // Se a análise NÃO estiver concluída, mostra o diálogo normal
    // Confirmação antes de limpar
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
            side: const BorderSide(
              color: Color(0xFF0D47A1),
              width: 2.0,
            ),
          ),
          backgroundColor: Colors.white,
          title: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0D47A1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.white, size: 28),
                SizedBox(width: 12),
                Text(
                  'Novo Documento',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          content: const SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 8),
                Text(
                  'Tem certeza que deseja criar um novo documento?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Todos os dados preenchidos serão perdidos e o formulário será reiniciado.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            // BOTÃO CANCELAR
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Fecha o diálogo
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[700],
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey[400]!),
                ),
              ),
              child: const Text(
                'Cancelar',
                style: TextStyle(fontSize: 16),
              ),
            ),

            // BOTÃO CONFIRMAR
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Fecha o diálogo
                _limparFormulario(); // Limpa o formulário
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D47A1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Novo Documento',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        );
      },
    );
  }

  // Método que realmente limpa o formulário
  void _limparFormulario() {
    setState(() {
      // 1. Limpa o tipo de operação
      tipoOperacao = null;
      
      // 2. Reseta a flag de análise concluída
      _analiseConcluida = false;
      
      // 3. Limpa todos os controllers
      for (var controller in campos.values) {
        controller?.clear();
      }
      
      // 4. Limpa o produto selecionado
      produtoSelecionado = null;
      
      // 5. Atualiza data e hora para o momento atual
      _setarDataHoraAtual();
      
      // 6. Limpa campos calculados automaticamente
      campos['densidade20']!.text = '';
      campos['fatorCorrecao']!.text = '';
      campos['difAmb']!.text = '';
      campos['dif20']!.text = '';
      
      // 7. Reseta o foco
      _focusTempCT.unfocus();
      _focusDestinoAmb.unfocus();
      _focusDestino20.unfocus();
      _focusOrigem20.unfocus();
    });
    
    // Mostra mensagem de sucesso
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.refresh, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text('✓ Formulário limpo! Preencha os dados para um novo certificado.'),
            ),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 3),
      ),
    );
  }

  // Função para formatar data DD/MM/YYYY para YYYY-MM-DD
  String _formatarDataParaBanco(String data) {
    if (data.isEmpty) return '';
    
    try {
      final partes = data.split('/');
      if (partes.length == 3) {
        return '${partes[2]}-${partes[1]}-${partes[0]}';
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  // Função para converter campo de texto para decimal (NUMERIC)
  double? _converterParaDecimal(String texto) {
    if (texto.isEmpty || texto == '-') return null;
    
    try {
      // Substituir vírgula por ponto para o PostgreSQL
      final textoLimpo = texto.replaceAll('.', '').replaceAll(',', '.');
      return double.tryParse(textoLimpo);
    } catch (e) {
      return null;
    }
  }

  // Função para converter campo de texto para inteiro
  // Função auxiliar para obter timestamp no horário de Brasília (UTC-3)
  String _obterTimestampBrasilia() {
    final agora = DateTime.now().toUtc();
    final brasilia = agora.subtract(const Duration(hours: 3));
    return brasilia.toIso8601String();
  }

  int? _converterParaInteiro(String texto) {
    if (texto.isEmpty) return null;
    
    try {
      // Remover pontos de milhar
      final textoLimpo = texto.replaceAll('.', '');
      return int.tryParse(textoLimpo);
    } catch (e) {
      return null;
    }
  }
}