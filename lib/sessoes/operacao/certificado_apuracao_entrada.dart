import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'dart:typed_data';
import 'dart:convert' show base64Encode;
import 'dart:js' as js;
import 'certificado_pdf.dart';
import '../../login_page.dart';

class PlacaAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final FocusNode? focusNode;
  final void Function(String)? onChanged;
  final bool enabled;

  const PlacaAutocompleteField({
    super.key,
    required this.controller,
    required this.label,
    this.focusNode,
    this.onChanged,
    this.enabled = true,
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
    if (!widget.enabled) return;
    if (_internalFocusNode.hasFocus) {
      _mostrarOverlay();
    } else {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!_internalFocusNode.hasFocus) {
          _fecharOverlay();
        }
      });
    }
  }

  Future<void> _buscarPlacas(String texto) async {
    if (!widget.enabled) return;
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
      setState(() {
        _sugestoes.clear();
        _carregando = false;
      });
      _fecharOverlay();
    }
  }

  void _onTextChanged(String texto) {
    if (!widget.enabled) return;
    _debounceTimer?.cancel();
    if (texto.length < 3) {
      setState(() {
        _sugestoes.clear();
      });
      _fecharOverlay();
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _buscarPlacas(texto);
      }
    });

    if (widget.onChanged != null) {
      widget.onChanged!(texto);
    }
  }

  void _onPlacaSelecionada(String placa) {
    if (!widget.enabled) return;
    widget.controller.text = placa;
    setState(() {
      _sugestoes.clear();
    });
    _fecharOverlay();
    _internalFocusNode.unfocus();
    widget.controller.selection = TextSelection.fromPosition(
      TextPosition(offset: placa.length),
    );
  }

  void _mostrarOverlay() {
    if (!widget.enabled) return;
    if (_sugestoes.isEmpty || _overlayEntry != null) return;

    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
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
            enabled: widget.enabled,
            decoration: InputDecoration(
              labelText: widget.label,
              counterText: '',
              hintText: '',
              filled: true,
              fillColor: widget.enabled ? Colors.white : Colors.grey[200],
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

class EmitirCertificadoEntrada extends StatefulWidget {
  final VoidCallback onVoltar;
  final String? idMovimentacao;
  final bool modoSomenteVisualizacao;
  final String? idAnaliseExistente;
  final String terminalId;
  final String dataFiltro;

  const EmitirCertificadoEntrada({
    super.key,
    required this.onVoltar,
    required this.terminalId,
    required this.dataFiltro,
    this.idMovimentacao,
    this.modoSomenteVisualizacao = false,
    this.idAnaliseExistente,
  });

  @override
  State<EmitirCertificadoEntrada> createState() =>
      _EmitirCertificadoEntradaState();
}

class _EmitirCertificadoEntradaState extends State<EmitirCertificadoEntrada> {
  final _formKey = GlobalKey<FormState>();
  bool _modoVisualizacao = false;
  bool _carregandoDadosMovimentacao = false;
  bool _salvandoCertificado = false;

  final TextEditingController dataCtrl = TextEditingController();
  final TextEditingController horaCtrl = TextEditingController();
  
  final FocusNode _focusTempObs = FocusNode();
  final FocusNode _focusDensidadeObs = FocusNode();
  final FocusNode _focusDestinoAmb = FocusNode();
  final FocusNode _focusDestino20 = FocusNode();
  final FocusNode _focusOrigem20 = FocusNode();
  final FocusNode _focusQtdFaturada = FocusNode();

  final Map<String, TextEditingController?> campos = {
    'numeroControle': TextEditingController(),
    'transportadora': TextEditingController(),
    'motorista': TextEditingController(),
    'notas': TextEditingController(),
    'placaCavalo': TextEditingController(),
    'carreta1': TextEditingController(),
    'carreta2': TextEditingController(),
    'tempObs': TextEditingController(),
    'densidadeObs': TextEditingController(),
    'densidade20': TextEditingController(),
    'fatorCorrecao': TextEditingController(),
    
    // Volumes Ambiente
    'origemAmb': TextEditingController(),
    'destinoAmb': TextEditingController(),
    'difAmb': TextEditingController(),
    
    // Volumes 20°C
    'origem20': TextEditingController(),
    'destino20': TextEditingController(),
    'dif20': TextEditingController(),
    'qtdFaturada': TextEditingController(),
  };

  List<String> produtos = [];
  String? produtoSelecionado;
  bool carregandoProdutos = true;

  // Variável para controlar se o produto atual é álcool
  bool _isAlcool = false;

  @override
  void initState() {
    super.initState();
    _setarDataHoraAtual();
    _carregarProdutos();

    _focusTempObs.addListener(() {
      if (!_modoVisualizacao && !_focusTempObs.hasFocus) {
        _calcularResultadosObtidos();
      }
    });

    _focusDensidadeObs.addListener(() {
      if (!_modoVisualizacao && !_focusDensidadeObs.hasFocus) {
        _calcularResultadosObtidos();
      }
    });
    
    _focusDestinoAmb.addListener(() {
      if (!_modoVisualizacao && !_focusDestinoAmb.hasFocus) {
        _calcularDiferencaAmbiente();
        _calcularDestino20CAutomatico();
        _calcularDiferenca20C();
      }
    });

    _focusDestino20.addListener(() {
      if (!_modoVisualizacao && !_focusDestino20.hasFocus) {
        _calcularDiferenca20C();
      }
    });
    
    _focusOrigem20.addListener(() {
      if (!_modoVisualizacao && !_focusOrigem20.hasFocus) {
        _calcularDestino20CAutomatico();
      }
    });

    _focusQtdFaturada.addListener(() {
      if (!_modoVisualizacao && !_focusQtdFaturada.hasFocus) {
        _calcularDiferenca20C();
      }
    });

    if (widget.modoSomenteVisualizacao) {
      _modoVisualizacao = true;
      
      if (widget.idAnaliseExistente != null && widget.idAnaliseExistente!.isNotEmpty) {
        _carregarDadosAnaliseExistente(widget.idAnaliseExistente!);
      }
      else if (widget.idMovimentacao != null && widget.idMovimentacao!.isNotEmpty) {
        _buscarAnalisePorMovimentacao(widget.idMovimentacao!);
      }
    } else {
      if (widget.idMovimentacao != null && widget.idMovimentacao!.isNotEmpty) {
        _carregarDadosMovimentacao(widget.idMovimentacao!).then((_) {
          if (mounted) {
            _carregarDadosOrdensAnalises(widget.idMovimentacao!);
          }
        });
      }
    }
  }

  void _verificarSeEAlcool(String produtoNome) {
    final nomeLower = produtoNome.toLowerCase().trim();
    _isAlcool = nomeLower.contains('anidro') || nomeLower.contains('hidratado');
    setState(() {});
  }

  Future<void> _carregarDadosAnaliseExistente(String idAnalise) async {
    try {
      final supabase = Supabase.instance.client;
      
      final analise = await supabase
          .from('ordens_analises')
          .select('''
            *,
            produtos:produto_id(nome),
            movimentacoes:movimentacao_id(qtd_faturada)
          ''')
          .eq('id', idAnalise)
          .maybeSingle();
          
      if (analise != null) {
        campos['numeroControle']!.text = analise['numero_controle']?.toString() ?? '';
        campos['transportadora']!.text = analise['transportadora']?.toString() ?? '';
        campos['motorista']!.text = analise['motorista']?.toString() ?? '';
        campos['notas']!.text = analise['notas_fiscais']?.toString() ?? '';
        
        if (analise['movimentacoes'] != null && analise['movimentacoes']['qtd_faturada'] != null) {
          campos['qtdFaturada']!.text = _formatarInteiroParaTela(analise['movimentacoes']['qtd_faturada']);
        }
        
        campos['placaCavalo']!.text = analise['placa_cavalo']?.toString() ?? '';
        campos['carreta1']!.text = analise['carreta1']?.toString() ?? '';
        campos['carreta2']!.text = analise['carreta2']?.toString() ?? '';
        
        campos['tempObs']!.text = _formatarDecimalParaTela(analise['temperatura_amostra']);
        campos['densidadeObs']!.text = _formatarDecimalParaTela(analise['densidade_observada']);
        campos['densidade20']!.text = _formatarDecimalParaTela(analise['densidade_20c']);
        campos['fatorCorrecao']!.text = _formatarDecimalParaTela(analise['fator_correcao']);
        
        campos['origemAmb']!.text = _formatarInteiroParaTela(analise['origem_ambiente']);
        campos['destinoAmb']!.text = _formatarInteiroParaTela(analise['destino_ambiente']);
        campos['origem20']!.text = _formatarInteiroParaTela(analise['origem_20c']);
        campos['destino20']!.text = _formatarInteiroParaTela(analise['destino_20c']);
        
        _calcularDiferencaAmbiente();
        _calcularDiferenca20C();
        
        if (analise['produtos'] != null && analise['produtos']['nome'] != null) {
          produtoSelecionado = analise['produtos']['nome'].toString();
          _verificarSeEAlcool(produtoSelecionado!);
        }
        
        if (analise['data_criacao'] != null) {
          dataCtrl.text = _formatarDataParaTela(analise['data_criacao'].toString());
        }
        if (analise['hora_analise'] != null) {
          horaCtrl.text = analise['hora_analise'].toString();
        }
        
        setState(() {});
      }
    } catch (e) {
      print('Erro ao carregar análise existente: $e');
    }
  }

  Future<void> _buscarAnalisePorMovimentacao(String movimentacaoId) async {
    try {
      final supabase = Supabase.instance.client;
      
      final analise = await supabase
          .from('ordens_analises')
          .select('id')
          .eq('movimentacao_id', movimentacaoId)
          .eq('tipo_analise', 'destino')
          .maybeSingle();
          
      if (analise != null && analise['id'] != null) {
        await _carregarDadosAnaliseExistente(analise['id'].toString());
      }
    } catch (e) {
      print('Erro ao buscar análise por movimentação: $e');
    }
  }

  Future<void> _carregarDadosMovimentacao(String idMovimentacao) async {
    setState(() {
      _carregandoDadosMovimentacao = true;
    });

    try {
      final supabase = Supabase.instance.client;

      final movimentacao = await supabase
          .from('movimentacoes')
          .select('''
            *,
            produtos:produto_id(nome),
            motoristas:motorista_id(nome),
            transportadoras:transportadora_id(nome),
            nota_fiscal,
            qtd_faturada
          ''')
          .eq('id', idMovimentacao)
          .maybeSingle();

      if (movimentacao == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Movimentação não encontrada: $idMovimentacao'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      if (movimentacao['qtd_faturada'] != null) {
        campos['qtdFaturada']!.text =
            _formatarInteiroParaTela(movimentacao['qtd_faturada']);
      }

      if (movimentacao['nota_fiscal'] != null) {
        campos['notas']!.text = movimentacao['nota_fiscal'].toString();
      }

      if (movimentacao['produtos'] != null &&
          movimentacao['produtos']['nome'] != null) {
        produtoSelecionado = movimentacao['produtos']['nome'].toString();
        _verificarSeEAlcool(produtoSelecionado!);
      }

      if (movimentacao['motoristas'] != null &&
          movimentacao['motoristas']['nome'] != null) {
        campos['motorista']!.text = movimentacao['motoristas']['nome'].toString();
      }

      if (movimentacao['transportadoras'] != null &&
          movimentacao['transportadoras']['nome'] != null) {
        campos['transportadora']!.text = 
            movimentacao['transportadoras']['nome'].toString();
      }

      if (movimentacao['placa'] != null && movimentacao['placa'] is List) {
        final placas = List<String>.from(movimentacao['placa']);
        if (placas.isNotEmpty) {
          campos['placaCavalo']!.text = placas[0];
          if (placas.length > 1) {
            campos['carreta1']!.text = placas[1];
          }
          if (placas.length > 2) {
            campos['carreta2']!.text = placas[2];
          }
        }
      }

      if (movimentacao['seta_carregada'] != null) {
        try {
          campos['origemAmb']!.text =
              _aplicarMascaraMilhar(movimentacao['seta_carregada'].toString());
        } catch (_) {}
      }

      if (movimentacao['saida_vinte'] != null) {
        try {
            campos['origem20']!.text =
              _aplicarMascaraMilhar(movimentacao['saida_vinte'].toString());
        } catch (_) {}
      }

    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar dados: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      setState(() {
        _carregandoDadosMovimentacao = false;
      });
    }
  }

  void _setarDataHoraAtual() {
    final agora = DateTime.now();
    dataCtrl.text = widget.dataFiltro.isNotEmpty
        ? widget.dataFiltro
        : '${agora.day.toString().padLeft(2, '0')}/${agora.month.toString().padLeft(2, '0')}/${agora.year}';
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

  Future<void> _calcularResultadosObtidos() async {
    if (_modoVisualizacao) return;
    if (produtoSelecionado == null) return;

    final tempObs = campos['tempObs']!.text;
    final densObs = campos['densidadeObs']!.text;

    // Para álcool, precisamos de temperatura observada e densidade observada
    if (_isAlcool) {
      if (tempObs.isEmpty || densObs.isEmpty) {
        campos['densidade20']!.text = '';
        campos['fatorCorrecao']!.text = '';
        campos['destino20']!.text = '';
        _calcularDiferenca20C();
        setState(() {});
        return;
      }

      final dens20 = await _buscarDensidade20CAlcool(
        temperaturaAmostra: tempObs,
        densidadeObservada: densObs,
      );

      campos['densidade20']!.text = dens20;

      if (dens20 == '-' || dens20.isEmpty) {
        campos['fatorCorrecao']!.text = '-';
        campos['destino20']!.text = '';
        _calcularDiferenca20C();
        setState(() {});
        return;
      }

      // Para álcool, o FCV é calculado usando a temperatura observada (não temperatura do CT)
      final fcv = await _buscarFCVAlcool(
        temperaturaObs: tempObs,
        densidade20C: dens20,
      );

      if (fcv != '-' && fcv.isNotEmpty) {
        campos['fatorCorrecao']!.text = fcv;
        _calcularDestino20CAutomatico();
      } else {
        campos['fatorCorrecao']!.text = '-';
        campos['destino20']!.text = '';
        _calcularDiferenca20C();
      }

      setState(() {});
      return;
    }

    // Para gasolina/diesel (não álcool) - mantém lógica original
    if (tempObs.isEmpty || densObs.isEmpty) {
      campos['densidade20']!.text = '';
      campos['fatorCorrecao']!.text = '';
      campos['destino20']!.text = '';
      _calcularDiferenca20C();
      setState(() {});
      return;
    }

    final dens20 = await _buscarDensidade20C(
      temperaturaAmostra: tempObs,
      densidadeObservada: densObs,
      produtoNome: produtoSelecionado!,
    );

    campos['densidade20']!.text = dens20;

    if (dens20 == '-' || dens20.isEmpty) {
      campos['fatorCorrecao']!.text = '-';
      campos['destino20']!.text = '';
      _calcularDiferenca20C();
      setState(() {});
      return;
    }

    // Para gasolina/diesel, FCV usa temperatura do CT
    final fcv = await _buscarFCV(
      temperaturaTanque: tempObs, // Usa a mesma temperatura observada
      densidade20C: dens20,
      produtoNome: produtoSelecionado!,
    );

    if (fcv != '-' && fcv.isNotEmpty) {
      campos['fatorCorrecao']!.text = fcv;
      _calcularDestino20CAutomatico();
    } else {
      campos['fatorCorrecao']!.text = '-';
      campos['destino20']!.text = '';
      _calcularDiferenca20C();
    }

    setState(() {});
  }

  String _formatarNumeroParaCampo(double valor) {
    if (valor.isNaN || valor.isInfinite) return '';
    final valorInteiro = valor.round();
    return _aplicarMascaraMilhar(valorInteiro.toString());
  }

  String _aplicarMascaraMilhar(String texto) {
    String apenasNumeros = texto.replaceAll(RegExp(r'[^\d]'), '');
    
    if (apenasNumeros.isEmpty || apenasNumeros == '0') {
      return '0';
    }
    
    while (apenasNumeros.length > 1 && apenasNumeros[0] == '0') {
      apenasNumeros = apenasNumeros.substring(1);
    }
    
    String resultado = '';
    for (int i = apenasNumeros.length - 1, count = 0; i >= 0; i--, count++) {
      if (count > 0 && count % 3 == 0) {
        resultado = '.$resultado';
      }
      resultado = apenasNumeros[i] + resultado;
    }
    
    return resultado;
  }

  void _calcularDestino20CAutomatico() {
    try {
      final fcvText = campos['fatorCorrecao']!.text;
      if (fcvText.isEmpty || fcvText == '-') {
        return;
      }
      
      final destinoAmbText = campos['destinoAmb']!.text;
      if (destinoAmbText.isEmpty) {
        campos['destino20']!.text = '';
        _calcularDiferenca20C();
        return;
      }
      
      final destinoAmbLimpo = destinoAmbText.replaceAll('.', '');
      final fcvLimpo = fcvText.replaceAll(',', '.');
      
      final destinoAmb = double.tryParse(destinoAmbLimpo);
      final fcv = double.tryParse(fcvLimpo);
      
      if (destinoAmb == null || fcv == null) {
        return;
      }
      
      final destino20C = destinoAmb * fcv;
      String destino20CFormatado = _formatarNumeroParaCampo(destino20C);
      
      campos['destino20']!.text = destino20CFormatado;
      _calcularDiferenca20C();
                  
    } catch (e) {
      // Erro ao calcular destino 20°C automático
    }
  }

  void _calcularDiferencaAmbiente() {
    try {
      final origemText = campos['origemAmb']!.text;
      final destinoText = campos['destinoAmb']!.text;
      
      if (origemText.isEmpty || destinoText.isEmpty) {
        campos['difAmb']!.text = '';
        setState(() {});
        return;
      }
      
      final origemLimpa = origemText.replaceAll('.', '');
      final destinoLimpa = destinoText.replaceAll('.', '');
      
      final origem = double.tryParse(origemLimpa);
      final destino = double.tryParse(destinoLimpa);
      
      if (origem != null && destino != null) {
        final diferenca = destino - origem;
        final resultadoFormatado = _formatarDiferencaComSinal(diferenca);
        campos['difAmb']!.text = resultadoFormatado;
      } else {
        campos['difAmb']!.text = '';
      }
      setState(() {});
    } catch (e) {
      campos['difAmb']!.text = '';
      setState(() {});
    }
  }

  void _calcularDiferenca20C() {
    try {
      final faturadaText = campos['qtdFaturada']!.text;
      final destino20Text = campos['destino20']!.text;
      
      if (faturadaText.isEmpty || destino20Text.isEmpty) {
        campos['dif20']!.text = '';
        setState(() {});
        return;
      }
      
      final faturadaLimpa = faturadaText.replaceAll('.', '');
      final destino20Limpa = destino20Text.replaceAll('.', '');
      
      final faturada = double.tryParse(faturadaLimpa);
      final destino20 = double.tryParse(destino20Limpa);
      
      if (faturada != null && destino20 != null) {
        final diferenca = destino20 - faturada;
        final resultadoFormatado = _formatarDiferencaComSinal(diferenca);
        campos['dif20']!.text = resultadoFormatado;
      } else {
        campos['dif20']!.text = '';
      }
      setState(() {});
    } catch (e) {
      campos['dif20']!.text = '';
      setState(() {});
    }
  }

  String _formatarDiferencaComSinal(double valor) {
    if (valor.isNaN || valor.isInfinite) {
      return '';
    }
    
    String sinal = '';
    if (valor > 0) {
      sinal = '+';
    } else if (valor < 0) {
      sinal = '-';
    }
    
    double valorAbs = valor.abs();
    int valorInteiro = valorAbs.floor();
    String valorFormatado = valorInteiro.toString();
    valorFormatado = _aplicarMascaraMilhar(valorFormatado);
    
    return sinal + valorFormatado;
  }

  Color _obterCorDiferencaAmb(String texto) {
    if (texto.isEmpty) return Colors.black87;
    if (texto.startsWith('-')) {
      return Colors.orange;
    } else if (texto.startsWith('+')) {
      return const Color.fromARGB(255, 0, 81, 255);
    }
    return Colors.black87;
  }

  Color _obterCorDiferenca20(String texto) {
    if (texto.isEmpty) return Colors.black87;
    if (texto.startsWith('-')) {
      return Colors.red;
    } else if (texto.startsWith('+')) {
      return const Color.fromARGB(255, 0, 81, 255);
    }
    return Colors.black87;
  }

  FontWeight _obterPesoDiferenca(String texto) {
    if (texto.isEmpty) return FontWeight.normal;
    return FontWeight.bold;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
                onPressed: _voltar,
              ),
              const Text(
                'Certificado de Apuração de Volumes - ENTRADA',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D47A1),
                ),
              ),
              if (_modoVisualizacao)
                Container(
                  margin: const EdgeInsets.only(left: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Certificado Emitido',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const Divider(),
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
                          if (_carregandoDadosMovimentacao)
                            Container(
                              padding: const EdgeInsets.all(20),
                              child: const Column(
                                children: [
                                  CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0D47A1)),
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Carregando dados da movimentação...',
                                    style: TextStyle(
                                      color: Color(0xFF0D47A1),
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Opacity(
                            opacity: _carregandoDadosMovimentacao ? 0.5 : 1.0,
                            child: AbsorbPointer(
                              absorbing: _modoVisualizacao || _carregandoDadosMovimentacao,
                              child: Column(
                                children: [
                                  _linhaFlexivel([
                                    {
                                      'flex': 7,
                                      'widget': Material(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: TextFormField(
                                          controller: campos['numeroControle'],
                                          enabled: false,
                                          decoration: _decoration('Nº Controle do Certificado').copyWith(
                                            hintText: _modoVisualizacao ? '' : 'A ser gerado automaticamente',
                                            filled: true,
                                            fillColor: const Color(0xFFF5F5F5),
                                          ),
                                          style: const TextStyle(
                                            fontStyle: FontStyle.italic,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                    },
                                    {
                                      'flex': 3,
                                      'widget': TextFormField(
                                        controller: campos['notas'],
                                        keyboardType: TextInputType.number,
                                        enabled: false,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                        decoration: _decoration('Notas Fiscais').copyWith(
                                          hintText: '',
                                          fillColor: const Color(0xFFF5F5F5),
                                        ),
                                      ),
                                    },
                                  ]),
                                  const SizedBox(height: 12),
                                  _linhaFlexivel([
                                    {
                                      'flex': 3,
                                      'widget': TextFormField(
                                        controller: campos['qtdFaturada'],
                                        keyboardType: TextInputType.number,
                                        enabled: !_modoVisualizacao,
                                        focusNode: _modoVisualizacao ? null : _focusQtdFaturada,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                        onChanged: (v) {
                                          final masc = _aplicarMascaraMilhar(v);
                                          if (masc != v) {
                                            campos['qtdFaturada']!.text = masc;
                                            campos['qtdFaturada']!.selection =
                                                TextSelection.fromPosition(
                                                    TextPosition(offset: masc.length));
                                          }
                                        },
                                        decoration: _decoration('Quantidade faturada'),
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
                                          : IgnorePointer(
                                              child: DropdownButtonFormField<String>(
                                                value: produtoSelecionado,
                                                items: produtos
                                                    .map(
                                                      (p) => DropdownMenuItem(
                                                        value: p,
                                                        child: Text(p),
                                                      ),
                                                    )
                                                    .toList(),
                                                onChanged: null,
                                                decoration: _decoration('Produto').copyWith(
                                                  fillColor: const Color(0xFFF5F5F5),
                                                ),
                                              ),
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
                                      'flex': 10,
                                      'widget': TextFormField(
                                        controller: campos['motorista'],
                                        maxLength: 50,
                                        enabled: !_modoVisualizacao,
                                        decoration: _decoration('Motorista').copyWith(
                                          counterText: '',
                                          fillColor: _modoVisualizacao ? const Color(0xFFF5F5F5) : Colors.white,
                                        ),
                                      ),
                                    },
                                    {
                                      'flex': 10,
                                      'widget': TextFormField(
                                        controller: campos['transportadora'],
                                        maxLength: 50,
                                        enabled: false,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                        decoration: _decoration('Transportadora').copyWith(
                                          counterText: '',
                                          fillColor: const Color(0xFFF5F5F5),
                                        ),
                                      ),
                                    },
                                  ]),
                                  const SizedBox(height: 12),
                                  _linhaFlexivel([
                                    {
                                      'flex': 4,
                                      'widget': PlacaAutocompleteField(
                                        controller: campos['placaCavalo']!,
                                        label: 'Placa do cavalo',
                                        enabled: false,
                                      ),
                                    },
                                    {
                                      'flex': 4,
                                      'widget': PlacaAutocompleteField(
                                        controller: campos['carreta1']!,
                                        label: 'Carreta 1',
                                        enabled: false,
                                      ),
                                    },
                                    {
                                      'flex': 4,
                                      'widget': PlacaAutocompleteField(
                                        controller: campos['carreta2']!,
                                        label: 'Carreta 2',
                                        enabled: false,
                                      ),
                                    },
                                  ]),
                                  const SizedBox(height: 20),
                                  _secao('Coletas na presença do motorista'),
                                  // Exibe apenas 2 campos para álcool, 3 para outros produtos
                                  _isAlcool
                                      ? _linha([
                                          TextFormField(
                                            controller: campos['tempObs'],
                                            focusNode: _modoVisualizacao ? null : _focusTempObs,
                                            keyboardType: TextInputType.number,
                                            enabled: !_modoVisualizacao,
                                            onChanged: _modoVisualizacao ? null : (value) {
                                              final masked = _aplicarMascaraTemperatura(value);
                                              if (masked != value) {
                                                campos['tempObs']!.value = TextEditingValue(
                                                  text: masked,
                                                  selection: TextSelection.collapsed(offset: masked.length),
                                                );
                                              }
                                            },
                                            decoration: _decoration('Temperatura observada (°C)').copyWith(
                                              hintText: '00,0',
                                              fillColor: _modoVisualizacao ? const Color(0xFFF5F5F5) : Colors.white,
                                            ),
                                          ),
                                          TextFormField(
                                            controller: campos['densidadeObs'],
                                            focusNode: _modoVisualizacao ? null : _focusDensidadeObs,
                                            keyboardType: TextInputType.number,
                                            enabled: !_modoVisualizacao,
                                            onChanged: _modoVisualizacao ? null : (value) {
                                              final masked = _aplicarMascaraDensidade(value);
                                              if (masked != value) {
                                                campos['densidadeObs']!.value = TextEditingValue(
                                                  text: masked,
                                                  selection: TextSelection.collapsed(offset: masked.length),
                                                );
                                              }
                                            },
                                            decoration: _decoration('Densidade observada').copyWith(
                                              hintText: '0,0000',
                                              fillColor: _modoVisualizacao ? const Color(0xFFF5F5F5) : Colors.white,
                                            ),
                                          ),
                                        ])
                                      : _linha([
                                          TextFormField(
                                            controller: campos['tempObs'],
                                            focusNode: _modoVisualizacao ? null : _focusTempObs,
                                            keyboardType: TextInputType.number,
                                            enabled: !_modoVisualizacao,
                                            onChanged: _modoVisualizacao ? null : (value) {
                                              final masked = _aplicarMascaraTemperatura(value);
                                              if (masked != value) {
                                                campos['tempObs']!.value = TextEditingValue(
                                                  text: masked,
                                                  selection: TextSelection.collapsed(offset: masked.length),
                                                );
                                              }
                                            },
                                            decoration: _decoration('Temperatura da amostra (°C)').copyWith(
                                              hintText: '00,0',
                                              fillColor: _modoVisualizacao ? const Color(0xFFF5F5F5) : Colors.white,
                                            ),
                                          ),
                                          TextFormField(
                                            controller: campos['densidadeObs'],
                                            focusNode: _modoVisualizacao ? null : _focusDensidadeObs,
                                            keyboardType: TextInputType.number,
                                            enabled: !_modoVisualizacao,
                                            onChanged: _modoVisualizacao ? null : (value) {
                                              final masked = _aplicarMascaraDensidade(value);
                                              if (masked != value) {
                                                campos['densidadeObs']!.value = TextEditingValue(
                                                  text: masked,
                                                  selection: TextSelection.collapsed(offset: masked.length),
                                                );
                                              }
                                            },
                                            decoration: _decoration('Densidade observada').copyWith(
                                              hintText: '0,0000',
                                              fillColor: _modoVisualizacao ? const Color(0xFFF5F5F5) : Colors.white,
                                            ),
                                          ),
                                        ]),
                                  const SizedBox(height: 20),
                                  _secao('Resultados obtidos'),
                                  _linha([
                                    _campo('Densidade a 20 ºC', campos['densidade20']!, 
                                           enabled: false), 
                                    _campo('Fator de correção (FCV)', campos['fatorCorrecao']!, 
                                           enabled: false), 
                                  ]),
                                  const SizedBox(height: 20),
                                  _secao('Volumes apurados - Ambiente'),
                                  _linha([
                                    TextFormField(
                                      controller: campos['origemAmb'],
                                      keyboardType: TextInputType.number,
                                      enabled: false,
                                      onChanged: null,
                                      decoration: _decoration('Quantidade de origem').copyWith(
                                        fillColor: const Color(0xFFF5F5F5),
                                      ),
                                    ),

                                    TextFormField(
                                      controller: campos['destinoAmb'],
                                      focusNode: _modoVisualizacao ? null : _focusDestinoAmb,
                                      keyboardType: TextInputType.number,
                                      enabled: !_modoVisualizacao,
                                      onChanged: _modoVisualizacao
                                          ? null
                                          : (value) {
                                              final ctrl = campos['destinoAmb']!;
                                              final masked = _aplicarMascaraNotasFiscais(value);

                                              if (masked != value) {
                                                ctrl.value = TextEditingValue(
                                                  text: masked,
                                                  selection: TextSelection.collapsed(offset: masked.length),
                                                );
                                              }
                                            },
                                      decoration: _decoration('Quantidade de destino').copyWith(
                                        fillColor: _modoVisualizacao ? const Color(0xFFF5F5F5) : Colors.white,
                                      ),
                                    ),
                                    
                                    TextFormField(
                                      controller: campos['difAmb'],
                                      enabled: false,
                                      keyboardType: TextInputType.number,
                                      style: TextStyle(
                                        color: _obterCorDiferencaAmb(campos['difAmb']!.text),
                                        fontWeight: _obterPesoDiferenca(campos['difAmb']!.text),
                                      ),
                                      decoration: _decoration(
                                        campos['difAmb']!.text.startsWith('-') 
                                          ? 'Abaixo do nível:' 
                                          : (campos['difAmb']!.text.startsWith('+') ? 'Acima do nível:' : 'Complemento/Retirada'),
                                        disabled: true
                                      ).copyWith(
                                        fillColor: const Color(0xFFF5F5F5),
                                        labelStyle: TextStyle(
                                          color: _obterCorDiferencaAmb(campos['difAmb']!.text),
                                        ),
                                      ),
                                    ),
                                  ]),
                                  const SizedBox(height: 20),
                                  _secao('Volumes apurados a 20 ºC'),
                                  _linha([
                                    TextFormField(
                                      controller: campos['qtdFaturada'],
                                      keyboardType: TextInputType.number,
                                      enabled: !_modoVisualizacao,
                                      focusNode: _modoVisualizacao ? null : _focusQtdFaturada,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                      onChanged: (v) {
                                        final masc = _aplicarMascaraMilhar(v);
                                        if (masc != v) {
                                          campos['qtdFaturada']!.text = masc;
                                          campos['qtdFaturada']!.selection =
                                              TextSelection.fromPosition(
                                                  TextPosition(offset: masc.length));
                                        }
                                      },
                                      decoration: _decoration('Quantidade faturada'),
                                    ),

                                    TextFormField(
                                      controller: campos['destino20'],
                                      style: TextStyle(color: const Color.fromARGB(255, 0, 81, 255)),
                                      enabled: false,
                                      focusNode: _modoVisualizacao ? null : _focusDestino20,
                                      keyboardType: TextInputType.number,
                                      decoration: _decoration('Quantidade apurada (20ºC)').copyWith(
                                        fillColor: const Color(0xFFF5F5F5),
                                      ),
                                    ),
                                    
                                    TextFormField(
                                      controller: campos['dif20'],
                                      enabled: false,
                                      keyboardType: TextInputType.number,
                                      style: TextStyle(
                                        color: _obterCorDiferenca20(campos['dif20']!.text),
                                        fontWeight: _obterPesoDiferenca(campos['dif20']!.text),
                                      ),
                                      decoration: _decoration('Sobra/Falta').copyWith(
                                        fillColor: const Color(0xFFF5F5F5),
                                        labelStyle: TextStyle(
                                          color: _obterCorDiferenca20(campos['dif20']!.text),
                                          fontWeight: _obterPesoDiferenca(campos['dif20']!.text),
                                        ),
                                      ),
                                    ),
                                  ]),
                                  const SizedBox(height: 40),
                                ],
                              ),
                            ),
                          ),
                          if (!_carregandoDadosMovimentacao)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _voltar,
                                icon: const Icon(Icons.arrow_back, size: 24),
                                label: const Text(
                                  'Voltar',
                                  style: TextStyle(fontSize: 16),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),

                              if (!_modoVisualizacao)
                                ElevatedButton.icon(
                                  onPressed: (_salvandoCertificado || (_converterParaInteiro(campos['destino20']!.text) ?? 0) <= 0)
                                    ? null
                                    : _confirmarEmissaoCertificado,
                                  icon: _salvandoCertificado 
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.check_circle, size: 24),
                                  label: Text(
                                    _salvandoCertificado ? 'Emitindo...' : 'Emitir certificado',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                )
                              else ...[
                                ElevatedButton.icon(
                                  onPressed: _baixarPDF,
                                  icon: const Icon(Icons.picture_as_pdf, size: 24),
                                  label: const Text(
                                    'Gerar Certificado PDF',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0D47A1),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),

                                if (widget.idAnaliseExistente != null)
                                  ElevatedButton.icon(
                                    onPressed: _salvandoCertificado ? null : _cancelarCertificado,
                                    icon: const Icon(Icons.delete_forever, size: 24),
                                    label: const Text(
                                      'Cancelar certificado',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 24, vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                              ],
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
      ),
    );
  }

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

  Widget _linhaFlexivel(List<Map<String, dynamic>> camposConfig) => Row(
        children: camposConfig
            .map((config) => Expanded(
                  flex: config['flex'] ?? 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: config['widget'],
                  ),
                ))
            .toList(),
      );

  Widget _campo(String label, TextEditingController c,
      {bool enabled = true}) {
    return Material(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
      ),
      child: TextFormField(
        controller: c,
        enabled: enabled,
        style: const TextStyle(fontWeight: FontWeight.bold),
        decoration: _decoration(label, disabled: !enabled).copyWith(
          fillColor: enabled ? Colors.white : const Color(0xFFF5F5F5),
        ),
      ),
    );
  }

  InputDecoration _decoration(String label,
          {bool disabled = false}) =>
      InputDecoration(
        labelText: label,
        filled: true,
        fillColor: disabled ? const Color(0xFFF5F5F5) : Colors.white,
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

  // ================= CÁLCULOS PARA ÁLCOOL =================
  
  Future<Map<String, dynamic>?> _buscarTabelaAlcool({
    required String temperatura,
    required String densidadeObservada,
  }) async {
    final supabase = Supabase.instance.client;

    try {
      final tempNum = double.tryParse(temperatura.replaceAll(',', '.')) ?? 0;
      double densNum =
          double.tryParse(densidadeObservada.replaceAll(',', '.')) ?? 0;

      if (densNum < 10) {
        densNum = densNum * 1000;
      }

      final registros = await supabase
          .from('tcv_alcool')
          .select('*')
          .gte('temp_obs', tempNum - 0.1)
          .lte('temp_obs', tempNum + 0.1)
          .order('densid_obs');

      if (registros.isEmpty) return null;

      Map<String, dynamic>? melhorRegistro;
      double menorDiferenca = double.infinity;

      for (var reg in registros) {
        final densReg = (reg['densid_obs'] as num).toDouble();
        final diferenca = (densReg - densNum).abs();

        if (diferenca < menorDiferenca) {
          menorDiferenca = diferenca;
          melhorRegistro = reg;
        }
      }

      return melhorRegistro;
    } catch (e) {
      debugPrint('Erro na busca da tabela alcoométrica (densidade obs): $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _buscarTabelaAlcoolPorDensidade20({
    required String temperatura,
    required String densidade20,
  }) async {
    final supabase = Supabase.instance.client;

    try {
      final tempNum = double.tryParse(temperatura.replaceAll(',', '.')) ?? 0;
      double dens20Num =
          double.tryParse(densidade20.replaceAll(',', '.')) ?? 0;

      if (dens20Num < 10) {
        dens20Num = dens20Num * 1000;
      }

      final registros = await supabase
          .from('tcv_alcool')
          .select('*')
          .gte('temp_obs', tempNum - 0.1)
          .lte('temp_obs', tempNum + 0.1)
          .order('densid_vinte');

      if (registros.isEmpty) return null;

      Map<String, dynamic>? melhorRegistro;
      double menorDiferenca = double.infinity;

      for (var reg in registros) {
        final densReg = (reg['densid_vinte'] as num).toDouble();
        final diferenca = (densReg - dens20Num).abs();

        if (diferenca < menorDiferenca) {
          menorDiferenca = diferenca;
          melhorRegistro = reg;
        }
      }

      return melhorRegistro;
    } catch (e) {
      debugPrint('Erro na busca da tabela alcoométrica (densidade 20): $e');
      return null;
    }
  }

  Future<String> _buscarDensidade20CAlcool({
    required String temperaturaAmostra,
    required String densidadeObservada,
  }) async {
    try {
      if (temperaturaAmostra.isEmpty || densidadeObservada.isEmpty) {
        return '-';
      }

      final resultado = await _buscarTabelaAlcool(
        temperatura: temperaturaAmostra,
        densidadeObservada: densidadeObservada,
      );

      if (resultado != null) {
        final densVinte = (resultado['densid_vinte'] as num).toDouble();
        final densVinteFormatada = (densVinte / 1000).toStringAsFixed(4).replaceAll('.', ',');
        return densVinteFormatada;
      }
      return '-';
    } catch (e) {
      return '-';
    }
  }

  Future<String> _buscarFCVAlcool({
    required String temperaturaObs,
    required String densidade20C,
  }) async {
    try {
      if (temperaturaObs.isEmpty || densidade20C.isEmpty || densidade20C == '-') {
        return '-';
      }

      final resultado = await _buscarTabelaAlcoolPorDensidade20(
        temperatura: temperaturaObs,
        densidade20: densidade20C,
      );

      if (resultado != null) {
        final fcv = (resultado['fcv'] as num).toDouble();
        final fcvFormatado = fcv.toStringAsFixed(4).replaceAll('.', ',');
        return fcvFormatado;
      }
      return '-';
    } catch (e) {
      return '-';
    }
  }

  // ================= CÁLCULOS PARA GASOLINA/DIESEL =================
  
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

      String temperaturaFormatada = temperaturaAmostra
          .replaceAll(' ºC', '')
          .replaceAll('°C', '')
          .replaceAll('ºC', '')
          .replaceAll('°', '')
          .replaceAll('C', '')
          .trim()
          .replaceAll('.', ',');

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
      
      const String nomeView = 'tcd_gasolina_diesel_vw';
      
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
      
      final resultado = await supabase
          .from(nomeView)
          .select(nomeColuna)
          .eq('temperatura_obs', temperaturaFormatada)
          .maybeSingle();
      
      if (resultado != null && resultado[nomeColuna] != null) {
        String valorBruto = resultado[nomeColuna].toString();
        return _formatarResultado(valorBruto);
      }
      
      List<String> formatosParaTentar = [];
      
      if (temperaturaFormatada.contains(',')) {
        final partes = temperaturaFormatada.split(',');
        if (partes.length == 2) {
          String parteInteira = partes[0];
          String parteDecimal = partes[1];
          
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
        }
      } else {
        formatosParaTentar.addAll([
          '$temperaturaFormatada,00',
          '$temperaturaFormatada,0',
          temperaturaFormatada,
        ]);
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

      const String nomeView = 'tcv_gasolina_diesel_vw';

      String temperaturaFormatada = temperaturaTanque
          .replaceAll('°C', '')
          .replaceAll('ºC', '')
          .replaceAll('°', '')
          .replaceAll('C', '')
          .trim()
          .replaceAll('.', ',');

      String densidadeFormatada =
          densidade20C.trim().replaceAll('.', ',');

      final densidadeNum =
          double.tryParse(densidadeFormatada.replaceAll(',', '.'));

      if (densidadeNum == null) {
        return '-';
      }

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

      String _densidadeParaCodigo(String densidade) {
        final partes = densidade.split(',');
        if (partes.length != 2) return '';
        final codigo =
            '${partes[0]}${partes[1].padRight(4, '0')}'.padLeft(5, '0');
        return codigo.length > 5 ? codigo.substring(0, 5) : codigo;
      }

      final codigoOriginal = _densidadeParaCodigo(densidadeFormatada);

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

      final direto = await _buscarFCVPorCodigo(codigoOriginal);
      if (direto != null) return direto;

      final sampleRow = await supabase
          .from(nomeView)
          .select()
          .limit(1)
          .maybeSingle();

      if (sampleRow == null) {
        return '-';
      }

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

      densidadesDisponiveis.sort((a, b) {
        final da = a['diferenca'] as double;
        final db = b['diferenca'] as double;
        return da.compareTo(db);
      });

      final densidadeMaisProxima = densidadesDisponiveis.first;
      final codigoMaisProximo = densidadeMaisProxima['codigo'] as String;

      final aproximado = await _buscarFCVPorCodigo(codigoMaisProximo);
      
      if (aproximado != null) {        
        return aproximado;
      }

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

  List<String> _gerarVariacoesTemperatura(String temperatura) {
    final List<String> variacoes = [];
    
    if (temperatura.contains(',')) {
      final partes = temperatura.split(',');
      final inteiro = partes[0];
      final decimal = partes[1];
      
      variacoes.addAll([
        '$inteiro,${decimal.padRight(2, '0')}',
        '$inteiro,${decimal.substring(0, decimal.length - 1)}',
      ]);
      
      if (decimal.length > 1) {
        variacoes.add('$inteiro,${decimal.substring(0, 1)}');
      }
      
      final temperaturaComPonto = temperatura.replaceAll(',', '.');
      variacoes.addAll([
        temperaturaComPonto,
        '$inteiro.${decimal.padRight(2, '0')}',
      ]);
    } else {
      variacoes.addAll([
        '$temperatura,0',
        '$temperatura,00',
        '$temperatura.0',
        '$temperatura.00',
      ]);
    }
    
    return variacoes.toSet().toList();
  }

  Future<void> _baixarPDF() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha todos os campos obrigatórios!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_modoVisualizacao) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Emita o certificado primeiro para gerar o PDF!'),
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
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
    
    try {
      final dadosPDF = {
        'numeroControle': campos['numeroControle']!.text,
        'transportadora': campos['transportadora']!.text,
        'motorista': campos['motorista']!.text,
        'placaCavalo': campos['placaCavalo']!.text,
        'carreta1': campos['carreta1']!.text,
        'carreta2': campos['carreta2']!.text,
        'notas': campos['notas']!.text,
        'tempObs': campos['tempObs']!.text,
        'densidadeObs': campos['densidadeObs']!.text,
        'densidade20': campos['densidade20']!.text,
        'fatorCorrecao': campos['fatorCorrecao']!.text,
        'origemAmb': campos['origemAmb']!.text,
        'destinoAmb': campos['destinoAmb']!.text,
        'difAmb': campos['difAmb']!.text,
        'origem20': campos['origem20']!.text,
        'destino20': campos['destino20']!.text,
        'dif20': campos['dif20']!.text,
      };
      
      final pdfDocument = await CertificadoPDF.gerar(
        data: dataCtrl.text,
        hora: horaCtrl.text,
        produto: produtoSelecionado,
        campos: dadosPDF,
      );
      
      final pdfBytes = await pdfDocument.save();
      
      if (context.mounted) Navigator.of(context).pop();
      
      if (kIsWeb) {
        await _downloadForWeb(pdfBytes);
      } else {
        _showMobileMessage();
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Certificado baixado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
    } catch (e) {
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

  Future<void> _downloadForWeb(Uint8List bytes) async {
    try {
      final base64 = base64Encode(bytes);
      final dataUrl = 'data:application/pdf;base64,$base64';
      final fileName = 'Certificado_${produtoSelecionado ?? "Analise"}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      
      final jsCode = '''
        try {
          const link = document.createElement('a');
          link.href = '$dataUrl';
          link.download = '$fileName';
          link.style.display = 'none';
          
          document.body.appendChild(link);
          link.click();
          
          setTimeout(() => {
            document.body.removeChild(link);
          }, 100);
        } catch (error) {
          window.open('$dataUrl', '_blank');
        }
      ''';
      
      js.context.callMethod('eval', [jsCode]);
      
    } catch (e) {
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
    String apenasNumeros = texto.replaceAll(RegExp(r'[^\d]'), '');

    if (apenasNumeros.length > 6) {
      apenasNumeros = apenasNumeros.substring(0, 6);
    }

    if (apenasNumeros.isEmpty) return '';

    if (apenasNumeros.length > 3) {
      String parteMilhar = apenasNumeros.substring(0, apenasNumeros.length - 3);
      String parteCentena = apenasNumeros.substring(apenasNumeros.length - 3);
      return '$parteMilhar.$parteCentena';
    }

    return apenasNumeros;
  }

  String _aplicarMascaraTemperatura(String texto) {
    String apenasNumeros = texto.replaceAll(RegExp(r'[^\d]'), '');

    if (apenasNumeros.length > 3) {
      apenasNumeros = apenasNumeros.substring(0, 3);
    }

    if (apenasNumeros.isEmpty) return '';

    if (apenasNumeros.length > 2) {
      return '${apenasNumeros.substring(0, 2)},${apenasNumeros.substring(2)}';
    }

    return apenasNumeros;
  }

  String _aplicarMascaraDensidade(String texto) {
    String apenasNumeros = texto.replaceAll(RegExp(r'[^\d]'), '');

    if (apenasNumeros.isEmpty) return '';

    if (apenasNumeros.length > 5) {
      apenasNumeros = apenasNumeros.substring(0, 5);
    }

    String parteInteira = apenasNumeros.substring(0, 1);
    String parteDecimal =
        apenasNumeros.length > 1 ? apenasNumeros.substring(1) : '';

    return parteDecimal.isEmpty
        ? '$parteInteira,'
        : '$parteInteira,$parteDecimal';
  }

  void _voltar() {
    FocusScope.of(context).unfocus();
    try {
      widget.onVoltar();
    } catch (_) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _cancelarCertificado() async {
    if (!_modoVisualizacao || (widget.idAnaliseExistente == null && campos['numeroControle']!.text.isEmpty)) return;

    final confirmacao = await showDialog<bool>(
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
                      'Confirmar cancelamento',
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
                        text: 'Tem certeza que quer cancelar este certificado?\n',
                      ),
                      TextSpan(
                        text: 'Atenção: Esta ação é irreversível. O certificado será removido permanentemente.',
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
                          'Sim, cancelar',
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

    if (confirmacao != true) return;

    setState(() {
      _salvandoCertificado = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final idCert = widget.idAnaliseExistente;

      if (idCert != null) {
        await supabase
            .from('ordens_analises')
            .delete()
            .eq('id', idCert);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Certificado cancelado com sucesso!'), backgroundColor: Colors.green),
          );
          _voltar();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao cancelar certificado: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _salvandoCertificado = false;
        });
      }
    }
  }

  void _confirmarEmissaoCertificado() {
    if (produtoSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione um produto!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

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
          content: const SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 8),
                Text(
                  'Confirma a emissão do certificado?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
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

            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _processarEmissaoCertificado();
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
                'Sim, emitir.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        );
      },
    );
  }
  
  Future<void> _processarEmissaoCertificado() async {
    if (!mounted) return;

    setState(() {
      _salvandoCertificado = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Usuário não autenticado');

      final usuario = UsuarioAtual.instance;
      if (usuario == null) throw Exception('Usuário não autenticado');

      final terminalIdEfetivo = widget.terminalId;
      if (terminalIdEfetivo.isEmpty) {
        throw Exception('Terminal não identificado. Verifique o vínculo de terminal.');
      }

      final produtoId = await _resolverProdutoId(produtoSelecionado!);

      String? ordemId;
      try {
        if (widget.idMovimentacao != null) {
          final movRef = await supabase
              .from('movimentacoes')
              .select('ordem_id')
              .eq('id', widget.idMovimentacao!)
              .maybeSingle();
          ordemId = movRef?['ordem_id']?.toString();
        }
      } catch (e) {
        print('Erro ao buscar ordem_id: $e');
      }

      final dadosOrdem = {
        'transportadora': campos['transportadora']!.text,
        'motorista': campos['motorista']!.text,
        'notas_fiscais': campos['notas']!.text,
        'placa_cavalo': campos['placaCavalo']!.text,
        'carreta1': campos['carreta1']!.text,
        'carreta2': campos['carreta2']!.text,
        'produto_id': produtoId,
        'produto_nome': produtoSelecionado,
        'temperatura_amostra': _converterParaDecimal(campos['tempObs']!.text),
        'densidade_observada': _converterParaDecimal(campos['densidadeObs']!.text),
        'densidade_20c': _converterParaDecimal(campos['densidade20']!.text),
        'fator_correcao': _converterParaDecimal(campos['fatorCorrecao']!.text),
        'origem_ambiente': _converterParaInteiro(campos['origemAmb']!.text),
        'destino_ambiente': _converterParaInteiro(campos['destinoAmb']!.text),
        'origem_20c': _converterParaInteiro(campos['origem20']!.text),
        'destino_20c': _converterParaInteiro(campos['destino20']!.text),
        'data_criacao': dataCtrl.text.split('/').reversed.join('-'),
        'usuario_id': user.id,
        'movimentacao_id': widget.idMovimentacao,
        'tipo_analise': 'destino',
        'terminal_id': terminalIdEfetivo,
        'ordem_id': ordemId,
      };

      final response = await supabase
          .from('ordens_analises')
          .insert(dadosOrdem)
          .select('id, numero_controle')
          .single();

      if (!mounted) return;

      campos['numeroControle']!.text =
          response['numero_controle'].toString();

      if (widget.idMovimentacao != null) {
        final volume20C =
            _converterParaInteiro(campos['destino20']!.text) ?? 0;
        final volumeAmbiente =
            _converterParaInteiro(campos['destinoAmb']!.text) ?? 0;

        await _atualizarMovimentacaoCompleta(
          movimentacaoId: widget.idMovimentacao!,
          produtoId: produtoId,
          volume20C: volume20C,
          volumeAmbiente: volumeAmbiente,
        );
      }

      if (!mounted) return;

      setState(() {
        _modoVisualizacao = true;
        _salvandoCertificado = false;
      });

      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Color(0xFF0D47A1), width: 1),
            ),
            content: const Text(
              'Certificado emitido com sucesso.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black87),
            ),
            actions: [
              Center(
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('OK'),
                ),
              ),
            ],
          ),
        );
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _salvandoCertificado = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao emitir certificado: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _atualizarMovimentacaoCompleta({
    required String movimentacaoId,
    required String produtoId,
    required int volume20C,
    required int volumeAmbiente,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      final timestampBrasilia = _obterTimestampBrasilia();

      String dataDescargaFormatada = timestampBrasilia;
      try {
        if (dataCtrl.text.isNotEmpty) {
          final partes = dataCtrl.text.split('/');
          if (partes.length == 3) {
            final agora = DateTime.now();
            final dataFinal = DateTime(
              int.parse(partes[2]),
              int.parse(partes[1]),
              int.parse(partes[0]),
              agora.hour,
              agora.minute,
              agora.second,
            );
            dataDescargaFormatada = dataFinal.toIso8601String();
          }
        }
      } catch (e) {
        print('Erro ao formatar data do campo para o banco: $e');
      }
      
      await supabase
          .from('movimentacoes_tanque')
          .update({
            'entrada_amb': volumeAmbiente,
          })
          .eq('movimentacao_id', movimentacaoId);

      await supabase
          .from('movimentacoes')
          .update({
            'entrada_amb': volumeAmbiente,
            'entrada_vinte': volume20C,
            'data_descarga': dataDescargaFormatada,
            'status_circuito_dest': '5',
            'updated_at': timestampBrasilia,
          })
          .eq('id', movimentacaoId);
          
    } catch (e) {
      print('✗ Erro ao atualizar movimentação: $e');
      rethrow;
    }
  }

  String _obterTimestampBrasilia() {
    final agora = DateTime.now().toUtc();
    final brasilia = agora.subtract(const Duration(hours: 3));
    return brasilia.toIso8601String();
  }

  
  Future<String> _resolverProdutoId(String nomeProduto) async {
    final r = await Supabase.instance.client
        .from('produtos')
        .select('id')
        .eq('nome', nomeProduto)
        .maybeSingle();

    if (r == null) {
      throw Exception('Produto não encontrado: $nomeProduto');
    }
    return r['id'].toString();
  }
  
  @override
  void dispose() {
    _focusTempObs.dispose();
    _focusDensidadeObs.dispose();
    _focusDestinoAmb.dispose();
    _focusDestino20.dispose();
    _focusOrigem20.dispose();
    _focusQtdFaturada.dispose();
    super.dispose();
  }

  Future<void> _carregarDadosOrdensAnalises(String idMovimentacao) async {
    try {
      final supabase = Supabase.instance.client;

      final ordemAnalise = await supabase
          .from('ordens_analises')
          .select('''
            *,
            produtos:produto_id(nome),
            movimentacoes:movimentacao_id(qtd_faturada)
          ''')
          .eq('movimentacao_id', idMovimentacao)
          .eq('tipo_analise', 'destino')
          .order('data_criacao', ascending: false)
          .limit(1)
          .maybeSingle();

      if (ordemAnalise == null) {
        return;
      }
      
      if (ordemAnalise['movimentacoes'] != null && ordemAnalise['movimentacoes']['qtd_faturada'] != null) {
        campos['qtdFaturada']!.text = _formatarInteiroParaTela(ordemAnalise['movimentacoes']['qtd_faturada']);
      }
      
      campos['numeroControle']!.text = ordemAnalise['numero_controle']?.toString() ?? '';
      campos['transportadora']!.text = ordemAnalise['transportadora']?.toString() ?? '';
      campos['motorista']!.text = ordemAnalise['motorista']?.toString() ?? '';
      campos['notas']!.text = ordemAnalise['notas_fiscais']?.toString() ?? '';
      
      campos['placaCavalo']!.text = ordemAnalise['placa_cavalo']?.toString() ?? '';
      campos['carreta1']!.text = ordemAnalise['carreta1']?.toString() ?? '';
      campos['carreta2']!.text = ordemAnalise['carreta2']?.toString() ?? '';
      
      campos['tempObs']!.text = _formatarDecimalParaTela(ordemAnalise['temperatura_amostra']);
      campos['densidadeObs']!.text = _formatarDecimalParaTela(ordemAnalise['densidade_observada']);
      campos['densidade20']!.text = _formatarDecimalParaTela(ordemAnalise['densidade_20c']);
      campos['fatorCorrecao']!.text = _formatarDecimalParaTela(ordemAnalise['fator_correcao']);
      
      campos['origemAmb']!.text = _formatarInteiroParaTela(ordemAnalise['origem_ambiente']);
      campos['destinoAmb']!.text = _formatarInteiroParaTela(ordemAnalise['destino_ambiente']);
      campos['origem20']!.text = _formatarInteiroParaTela(ordemAnalise['origem_20c']);
      campos['destino20']!.text = _formatarInteiroParaTela(ordemAnalise['destino_20c']);
      
      _calcularDiferencaAmbiente();
      _calcularDiferenca20C();
      
      if (ordemAnalise['produtos'] != null && ordemAnalise['produtos']['nome'] != null) {
        produtoSelecionado = ordemAnalise['produtos']['nome'].toString();
        _verificarSeEAlcool(produtoSelecionado!);
      }
      
      if (ordemAnalise['data_criacao'] != null) {
        dataCtrl.text = _formatarDataParaTela(ordemAnalise['data_criacao'].toString());
      }
      if (ordemAnalise['hora_analise'] != null) {
        horaCtrl.text = ordemAnalise['hora_analise'].toString();
      }
      
      setState(() {
        _modoVisualizacao = true;
      });
      
    } catch (e) {
      print('Erro ao carregar dados da ordem de análise: $e');
    }
  }

  String _formatarInteiroParaTela(dynamic valorBanco) {
    if (valorBanco == null) return '';
    
    try {
      String valorStr = valorBanco.toString();
      String apenasNumeros = valorStr.replaceAll(RegExp(r'[^\d]'), '');
      if (apenasNumeros.isEmpty) return '';
      return _aplicarMascaraMilhar(apenasNumeros);
    } catch (e) {
      return '';
    }
  }

  String _formatarDecimalParaTela(dynamic valorBanco) {
    if (valorBanco == null) return '';
    
    try {
      String valorStr = valorBanco.toString();
      valorStr = valorStr.replaceAll('.', ',');
      
      if (valorStr.contains(',')) {
        final partes = valorStr.split(',');
        if (partes.length == 2) {
          String parteInteira = partes[0];
          String parteDecimal = partes[1];
          
          if (valorBanco is num && valorBanco < 1) {
            parteDecimal = parteDecimal.padRight(4, '0');
            if (parteDecimal.length > 4) {
              parteDecimal = parteDecimal.substring(0, 4);
            }
          } else if (valorBanco is num && valorBanco > 1 && valorBanco < 10) {
            parteDecimal = parteDecimal.padRight(1, '0');
            if (parteDecimal.length > 1) {
              parteDecimal = parteDecimal.substring(0, 1);
            }
          }
          
          return '$parteInteira,$parteDecimal';
        }
      }
      
      return valorStr;
    } catch (e) {
      return '';
    }
  }

  String _formatarDataParaTela(String dataBanco) {
    if (dataBanco.isEmpty) return '';
    
    try {
      final partes = dataBanco.split('-');
      if (partes.length == 3) {
        return '${partes[2]}/${partes[1]}/${partes[0]}';
      }
      return dataBanco;
    } catch (e) {
      return '';
    }
  }

  double? _converterParaDecimal(String texto) {
    if (texto.isEmpty || texto == '-') return null;
    
    try {
      final textoLimpo = texto.replaceAll('.', '').replaceAll(',', '.');
      return double.tryParse(textoLimpo);
    } catch (e) {
      return null;
    }
  }

  int? _converterParaInteiro(String texto) {
    if (texto.isEmpty) return null;
    
    try {
      final textoLimpo = texto.replaceAll('.', '');
      return int.tryParse(textoLimpo);
    } catch (e) {
      return null;
    }
  }  
}