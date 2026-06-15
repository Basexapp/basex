import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:convert' show base64Encode;
import 'dart:js' as js;
import 'certificado_pdf.dart';
import '../../login_page.dart';

// ================= INPUT FORMATTERS =================

class _TemperaturaInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    // Permitir apenas dígitos e vírgula
    final filtered = text.replaceAll(RegExp(r'[^\d,]'), '');
    // Apenas uma vírgula
    if (filtered.split(',').length > 2) return oldValue;
    // Máximo 1 dígito decimal após a vírgula
    if (filtered.contains(',')) {
      final parts = filtered.split(',');
      if (parts[1].length > 1) return oldValue;
    }
    if (filtered == text) return newValue;
    return TextEditingValue(
      text: filtered,
      selection: TextSelection.collapsed(offset: filtered.length),
    );
  }
}

class _DensidadeInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    // Permitir apenas dígitos e vírgula
    final filtered = text.replaceAll(RegExp(r'[^\d,]'), '');
    // Apenas uma vírgula
    if (filtered.split(',').length > 2) return oldValue;
    // Máximo 3 dígitos decimais após a vírgula
    if (filtered.contains(',')) {
      final parts = filtered.split(',');
      if (parts[1].length > 3) return oldValue;
    }
    if (filtered == text) return newValue;
    return TextEditingValue(
      text: filtered,
      selection: TextSelection.collapsed(offset: filtered.length),
    );
  }
}

// ================= MODELO DE DADOS TANQUE =================

class TanqueDados {
  final String id;
  final TextEditingController volumeAmbCtrl;
  final TextEditingController volume20CCtrl;
  final String? produtoNome; // Nome do produto deste tanque
  final String? produtoId; // ID do produto (UUID)
  bool buscarDoBanco;
  
  // Dados da coleta (preenchidos no dialog)
  String? tempAmostra;
  String? densidadeObservada;
  String? tempCT;
  String? densidade20C;
  String? fatorCorrecao;

  TanqueDados({
    required this.id,
    required this.volumeAmbCtrl,
    required this.volume20CCtrl,
    this.produtoNome,
    this.produtoId,
    this.buscarDoBanco = false,
    this.tempAmostra,
    this.densidadeObservada,
    this.tempCT,
    this.densidade20C,
    this.fatorCorrecao,
  });

  void dispose() {
    volumeAmbCtrl.dispose();
    volume20CCtrl.dispose();
  }
}

// ================= COMPONENTE PLACA AUTOCOMPLETE =================

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
      print('Erro ao buscar placas: $e');
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

// ================= PÁGINA PRINCIPAL =================
class EmitirCertificadoPage extends StatefulWidget {
  final VoidCallback onVoltar;
  final String? idCertificado;
  final String? idMovimentacao;
  final List<Map<String, dynamic>>? tanquesDaOrdem;
  final bool modoSomenteVisualizacao;
  final String? terminalId;
  final String? tipoOp;
  final String? dataFiltro;

  const EmitirCertificadoPage({
    super.key,
    required this.onVoltar,
    this.idCertificado,
    this.idMovimentacao,
    this.tanquesDaOrdem,
    this.modoSomenteVisualizacao = false,
    this.terminalId,
    this.tipoOp,
    this.dataFiltro,
  });

  @override
  State<EmitirCertificadoPage> createState() =>
      _EmitirCertificadoPageState();
}

class _EmitirCertificadoPageState extends State<EmitirCertificadoPage> {
  final _formKey = GlobalKey<FormState>();
  bool _modoVisualizacao = false;
  Map<String, dynamic>? _dadosExistentes;
  bool _carregandoDadosMovimentacao = false;
  bool _salvandoCertificado = false;
  bool _carregandoDadosTemp = false;

  // FocusNodes para entrada manual nos campos de temp/densidade (transf)
  final FocusNode _focusTempAmostra = FocusNode();
  final FocusNode _focusDensidadeAmostra = FocusNode();
  final FocusNode _focusTempCT = FocusNode();

  // ================= CONTROLLERS =================
  final TextEditingController dataCtrl = TextEditingController();
  final TextEditingController horaCtrl = TextEditingController();

  final Map<String, TextEditingController?> campos = {
    'numeroControle': TextEditingController(),
    'transportadora': TextEditingController(),
    'motorista': TextEditingController(),
    'notas': TextEditingController(),

    'placaCavalo': TextEditingController(),
    'carreta1': TextEditingController(),
    'carreta2': TextEditingController(),

    // Campos de temperatura e densidade - agora READONLY
    'tempAmostra': TextEditingController(),
    'densidadeAmostra': TextEditingController(),
    'tempCT': TextEditingController(),
    'densidade20': TextEditingController(),
    'fatorCorrecao': TextEditingController(),
  };

  // ================= LISTA DE TANQUES =================
  List<TanqueDados> _tanques = [];

  // ================= PRODUTOS =================
  List<String> produtos = [];
  String? produtoSelecionado;
  bool carregandoProdutos = true;

  @override
  void initState() {
    super.initState();
    _setarDataHoraAtual();
    _carregarProdutos();
    _inicializarTanquesDaOrdem();

    // Configurar listeners de foco para campos de entrada manual (transf)
    if (widget.tipoOp?.toLowerCase() == 'transf') {
      _focusTempAmostra.addListener(() {
        if (!_focusTempAmostra.hasFocus && !_camposTempVazios() &&
            (campos['densidade20']!.text.isEmpty || campos['fatorCorrecao']!.text.isEmpty)) {
          _calcularResultadosObtidos();
        }
      });
      _focusDensidadeAmostra.addListener(() {
        if (!_focusDensidadeAmostra.hasFocus && !_camposTempVazios() &&
            (campos['densidade20']!.text.isEmpty || campos['fatorCorrecao']!.text.isEmpty)) {
          _calcularResultadosObtidos();
        }
      });
      _focusTempCT.addListener(() {
        if (!_focusTempCT.hasFocus && !_camposTempVazios() &&
            (campos['densidade20']!.text.isEmpty || campos['fatorCorrecao']!.text.isEmpty)) {
          _calcularResultadosObtidos();
        }
      });
    }

    if (widget.modoSomenteVisualizacao || (widget.idCertificado != null && widget.idCertificado!.isNotEmpty)) {
      _modoVisualizacao = true;
      if (widget.idCertificado != null && widget.idCertificado!.isNotEmpty) {
        _carregarDadosCertificado(widget.idCertificado!);
      }
    } else {
      _modoVisualizacao = false;
      if (widget.idMovimentacao != null && widget.idMovimentacao!.isNotEmpty) {
        _carregarDadosMovimentacao(widget.idMovimentacao!);
      }
    }
  }

  Future<void> _carregarDadosMovimentacao(String idMovimentacao) async {
    print('📥 ENTRANDO EM _carregarDadosMovimentacao: $idMovimentacao');
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
            nota_fiscal
          ''')
          .eq('id', idMovimentacao)
          .maybeSingle();

      if (movimentacao != null) {
        print('   ✅ Movimentação encontrada para produto: ${movimentacao['produtos']?['nome']}');
        if (movimentacao['nota_fiscal'] != null) {
          campos['notas']!.text =
              movimentacao['nota_fiscal'].toString();
        }

        if (movimentacao['produtos'] != null &&
            movimentacao['produtos']['nome'] != null) {
          produtoSelecionado =
              movimentacao['produtos']['nome'].toString();
        }

        if (movimentacao['motoristas'] != null &&
            movimentacao['motoristas']['nome'] != null) {
          campos['motorista']!.text =
              movimentacao['motoristas']['nome'].toString();
        }

        if (movimentacao['transportadoras'] != null &&
            movimentacao['transportadoras']['nome'] != null) {
          campos['transportadora']!.text =
              movimentacao['transportadoras']['nome'].toString();
        }

        if (movimentacao['placa'] != null &&
            movimentacao['placa'] is List) {
          final placas =
              List<String>.from(movimentacao['placa']);
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
      // Após carregar dados da movimentação, buscar parâmetros de temperatura/densidade
      _carregarDadosTempEDens();
    }
  }

  Future<void> _carregarDadosCertificado(String idCertificado) async {
    try {
      final supabase = Supabase.instance.client;
      
      final dados = await supabase
          .from('ordens_analises')
          .select('*')
          .eq('id', idCertificado)
          .single();
      
      _dadosExistentes = Map<String, dynamic>.from(dados);
      
      _preencherCamposComDadosExistentes();
      
    } catch (e) {
      print('Erro ao carregar certificado: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar certificado: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }
  
  void _preencherCamposComDadosExistentes() {
    if (_dadosExistentes == null) return;

    setState(() {
      campos['numeroControle']!.text =
          _dadosExistentes!['numero_controle']?.toString() ?? '';
      campos['transportadora']!.text =
          _dadosExistentes!['transportadora']?.toString() ?? '';
      campos['motorista']!.text =
          _dadosExistentes!['motorista']?.toString() ?? '';
      campos['notas']!.text =
          _dadosExistentes!['notas_fiscais']?.toString() ?? '';

      campos['placaCavalo']!.text =
          _dadosExistentes!['placa_cavalo']?.toString() ?? '';
      campos['carreta1']!.text =
          _dadosExistentes!['carreta1']?.toString() ?? '';
      campos['carreta2']!.text =
          _dadosExistentes!['carreta2']?.toString() ?? '';

      campos['tempAmostra']!.text =
          _formatarDecimalParaExibicao(_dadosExistentes!['temperatura_amostra']);
      campos['densidadeAmostra']!.text =
          _formatarDecimalParaExibicao(_dadosExistentes!['densidade_observada']);
      campos['tempCT']!.text =
          _formatarDecimalParaExibicao(_dadosExistentes!['temperatura_ct']);
      campos['densidade20']!.text =
          _formatarDecimalParaExibicao(_dadosExistentes!['densidade_20c']);
      campos['fatorCorrecao']!.text =
          _formatarDecimalParaExibicao(_dadosExistentes!['fator_correcao']);

      if (_tanques.isNotEmpty) {
        final origemAmb = _dadosExistentes!['origem_ambiente'];
        if (origemAmb != null) {
          _tanques[0].volumeAmbCtrl.text =
              _mascaraMilharUI(origemAmb.toString());
        }

        final destino20 = _dadosExistentes!['destino_20c'];
        if (destino20 != null) {
          _tanques[0].volume20CCtrl.text =
              _mascaraMilharUI(destino20.toString());
        }
      }

      if (_dadosExistentes!['data_analise'] != null) {
        try {
          final data = DateTime.parse(_dadosExistentes!['data_analise']);
          dataCtrl.text =
              '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
        } catch (_) {}
      }

      if (_dadosExistentes!['hora_analise'] != null) {
        horaCtrl.text = _dadosExistentes!['hora_analise'].toString();
      }

      produtoSelecionado =
          _dadosExistentes!['produto_nome']?.toString();
    });
  }
  
  String _formatarDecimalParaExibicao(dynamic valor) {
    if (valor == null) return '';
    
    try {
      String texto = valor.toString();
      if (texto.contains('.')) {
        texto = texto.replaceAll('.', ',');
      }
      return texto;
    } catch (e) {
      return '';
    }
  }

  void _setarDataHoraAtual() {
    final agora = DateTime.now();
    
    // Se dataFiltro estiver presente, usa essa data, senão usa a data atual
    if (widget.dataFiltro != null && widget.dataFiltro!.isNotEmpty) {
      dataCtrl.text = widget.dataFiltro!;
    } else {
      dataCtrl.text =
          '${agora.day.toString().padLeft(2, '0')}/${agora.month.toString().padLeft(2, '0')}/${agora.year}';
    }
    
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

  // ================= NOVA LÓGICA DE CARREGAMENTO DE TEMP/DENS =================
  Future<void> _carregarDadosTempEDens() async {
    print('🔄 ENTRANDO EM _carregarDadosTempEDens');
    if (_modoVisualizacao) {
      print('   - Abortando: modo visualização');
      return;
    }

    // Transferência com destino real (entre terminais) usa preenchimento manual pelo usuário
    // Consumo próprio usa busca automática igual à venda
    final isTransfReal = widget.tipoOp?.toLowerCase() == 'transf' &&
        widget.terminalId != null;
    if (isTransfReal) {
      return;
    }

    setState(() {
      _carregandoDadosTemp = true;
    });

    try {
      // Prioridade: usar terminal passado como parâmetro; fallback para o do usuário
      final terminalIdEfetivo = widget.terminalId ?? UsuarioAtual.instance?.terminalId;
      
      if (terminalIdEfetivo == null || terminalIdEfetivo.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Terminal não identificado. Não foi possível buscar dados.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() {
          _carregandoDadosTemp = false;
        });
        return;
      }

      // Determinar qual produto_id usar: preferência pelo primeiro tanque
      String? produtoIdBusca;
      
      if (_tanques.isNotEmpty && _tanques[0].produtoId != null && _tanques[0].produtoId!.isNotEmpty) {
        produtoIdBusca = _tanques[0].produtoId;
      }

      // Se não tem produto ID, não pode buscar
      if (produtoIdBusca == null || produtoIdBusca.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Produto não identificado. Necessita de lançamento pelo laboratório.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() {
          _carregandoDadosTemp = false;
        });
        return;
      }

      // Horário de São Paulo (UTC-3)
      final agoraSaoPaulo = DateTime.now().toUtc().subtract(const Duration(hours: 3));
      // ALTERADO: 60 minutos -> 120 minutos
      final centoEVinteMinAtrasSaoPaulo = agoraSaoPaulo.subtract(const Duration(minutes: 120));
      
      // Formatar datas no formato que o PostgreSQL espera (YYYY-MM-DD HH:MM:SS)
      String formatarDataParaPostgres(DateTime date) {
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
      }
      
      final dataInicio = formatarDataParaPostgres(centoEVinteMinAtrasSaoPaulo);
      
      // Buscar registros do MESMO produto nos últimos 120 minutos
      final registros = await Supabase.instance.client
          .from('temp_e_dens')
          .select('temp_amostra, densid_obs, temp_ct, data_hora_medicao, produto_id')
          .eq('terminal_id', terminalIdEfetivo)
          .eq('produto_id', produtoIdBusca)
          .gte('data_hora_medicao', dataInicio)
          .order('data_hora_medicao', ascending: false);
      
      if (registros.isNotEmpty) {
        print('   ✅ Encontrado(s) ${registros.length} registro(s)');
        // Calcular médias
        double somaTempAmostra = 0;
        double somaDensObs = 0;
        double somaTempCT = 0;
        int countTempAmostra = 0;
        int countDensObs = 0;
        int countTempCT = 0;
        
        for (var registro in registros) {
          if (registro['temp_amostra'] != null) {
            somaTempAmostra += double.parse(registro['temp_amostra'].toString());
            countTempAmostra++;
          }
          if (registro['densid_obs'] != null) {
            somaDensObs += double.parse(registro['densid_obs'].toString());
            countDensObs++;
          }
          if (registro['temp_ct'] != null) {
            somaTempCT += double.parse(registro['temp_ct'].toString());
            countTempCT++;
          }
        }
        
        // Calcular médias
        double? mediaTempAmostra = countTempAmostra > 0 ? somaTempAmostra / countTempAmostra : null;
        double? mediaDensObs = countDensObs > 0 ? somaDensObs / countDensObs : null;
        double? mediaTempCT = countTempCT > 0 ? somaTempCT / countTempCT : null;

        // Função para arredondar temperatura para o x,0 ou x,5 mais próximo
        double arredondarTemperatura(double? valor) {
          if (valor == null) return 0;
          return (valor * 2).roundToDouble() / 2;
        }

        // Função para arredondar densidade para 3 casas decimais
        double arredondarDensidade(double? valor) {
          if (valor == null) return 0;
          return double.parse(valor.toStringAsFixed(3));
        }
        
        // Preencher campos
        print('   📊 Preenchendo campos com médias calculadas');
        setState(() {
          if (mediaTempAmostra != null) {
            final valorArredondado = arredondarTemperatura(mediaTempAmostra);
            campos['tempAmostra']!.text = _formatarDecimalParaExibicao(valorArredondado.toString());
          }
          if (mediaDensObs != null) {
            final valorArredondado = arredondarDensidade(mediaDensObs);
            campos['densidadeAmostra']!.text = _formatarDecimalParaExibicao(valorArredondado.toString());
          }
          if (mediaTempCT != null) {
            final valorArredondado = arredondarTemperatura(mediaTempCT);
            campos['tempCT']!.text = _formatarDecimalParaExibicao(valorArredondado.toString());
          }
        });
        
        // Calcular densidade 20°C e FCV
        await _calcularResultadosObtidos();
        
        if (mounted) {
          String mensagem = '✓ Dados carregados (média de ${registros.length} registro(s) dos últimos 120 min)';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(mensagem),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        // Nenhum registro encontrado nos últimos 120 minutos
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Sem dados disponíveis. Necessita de lançamento pelo laboratório.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }
        
        // Limpar campos
        setState(() {
          campos['tempAmostra']!.text = '';
          campos['densidadeAmostra']!.text = '';
          campos['tempCT']!.text = '';
          campos['densidade20']!.text = '';
          campos['fatorCorrecao']!.text = '';
        });
      }
      
    } catch (e) {
      print('❌ Erro ao carregar dados de temperatura/densidade: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar dados: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _carregandoDadosTemp = false;
      });
    }
  }

  Future<void> _calcularResultadosObtidos() async {
    print('🚀 ENTRANDO EM _calcularResultadosObtidos - Visualização: $_modoVisualizacao');
    if (_modoVisualizacao) return;

    print('   - Produto selecionado: $produtoSelecionado');
    if (produtoSelecionado == null) return;

    final tempAmostra = campos['tempAmostra']!.text;
    final densObs = campos['densidadeAmostra']!.text;
    final tempCT = campos['tempCT']!.text;

    print('🚀 DEBUG _calcularResultadosObtidos:');
    print('   - tempAmostra: $tempAmostra');
    print('   - densObs: $densObs');
    print('   - tempCT: $tempCT');

    campos['densidade20']!.text = '';
    campos['fatorCorrecao']!.text = '';

    if (tempAmostra.isEmpty || densObs.isEmpty) {
      print('   ⚠️ Dados de entrada insuficientes para cálculo.');
      return;
    }

    final dens20 = await _buscarDensidade20C(
      temperaturaAmostra: tempAmostra,
      densidadeObservada: densObs,
      produtoNome: produtoSelecionado!,
    );

    print('   📊 Resultado Densidade 20C: $dens20');
    campos['densidade20']!.text = dens20;

    if (dens20 == '-' || dens20.isEmpty || tempCT.isEmpty) {
      print('   ⚠️ Densidade 20C ou Temp CT faltando para o cálculo do FCV.');
      campos['fatorCorrecao']!.text = '-';
      setState(() {});
      return;
    }

    final fcv = await _buscarFCV(
      temperaturaTanque: tempCT,
      densidade20C: dens20,
      produtoNome: produtoSelecionado!,
    );

    print('   📊 Resultado FCV: $fcv');
    campos['fatorCorrecao']!.text = fcv;

    // Calcular volume 20°C para todos os tanques que tiverem volume ambiente preenchido
    if (fcv != '-' && fcv.isNotEmpty) {
      _calcularVolumeApurado20C();
    }

    setState(() {});
  }

  String _formatarNumeroParaCampo(double valor) {
    if (valor.isNaN || valor.isInfinite) return '';

    final valorInteiro = valor.round();
    return _aplicarMascaraMilhar(valorInteiro.toString());
  }

  String _aplicarMascaraMilhar(String texto) {
    final apenasNumeros = texto.replaceAll(RegExp(r'[^\d]'), '');

    if (apenasNumeros.isEmpty || apenasNumeros == '0') return '0';

    String resultado = '';
    for (int i = apenasNumeros.length - 1, c = 0; i >= 0; i--, c++) {
      if (c > 0 && c % 3 == 0) resultado = '.$resultado';
      resultado = apenasNumeros[i] + resultado;
    }

    return resultado;
  }

  void _calcularVolumeApurado20C() {
    if (_modoVisualizacao) return;

    final fcvText = campos['fatorCorrecao']!.text;
    if (fcvText.isEmpty || fcvText == '-') return;

    // Calcula para todos os tanques
    for (var tanque in _tanques) {
      _calcularVolume20CTanque(tanque);
    }

    setState(() {});
  }

  bool _campoVolume20Valido(String texto) {
    if (texto.isEmpty) return false;
    final limpo = texto.replaceAll('.', '').replaceAll(',', '.');
    final v = double.tryParse(limpo);
    return v != null && v > 0;
  }

  bool _todosVolumes20Validos() {
    if (_tanques.isEmpty) return false;
    // Verificar FCV global
    final fcv = campos['fatorCorrecao']!.text;
    if (fcv.isEmpty || fcv == '-') return false;
    for (final t in _tanques) {
      if (!_campoVolume20Valido(t.volume20CCtrl.text.trim())) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // ================= HEADER =================
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
                onPressed: _voltar,
              ),
              const Text(
                'Certificado de Apuração de Volumes - SAÍDA',
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
                          // ================= LOADING =================
                          if (_carregandoDadosMovimentacao || _carregandoDadosTemp)
                            Container(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  const CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0D47A1)),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _carregandoDadosTemp 
                                        ? 'Carregando dados de temperatura e densidade...' 
                                        : 'Carregando dados da movimentação...',
                                    style: const TextStyle(
                                      color: Color(0xFF0D47A1),
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          
                          // ================= FORMULÁRIO =================
                          Opacity(
                            opacity: (_carregandoDadosMovimentacao || _carregandoDadosTemp) ? 0.5 : 1.0,
                            child: Column(
                              children: [
                                AbsorbPointer(
                                  absorbing: _modoVisualizacao || _carregandoDadosMovimentacao || _carregandoDadosTemp,
                                  child: Column(
                                    children: [
                                      _linha([
                                        Material(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: TextFormField(
                                            controller: campos['numeroControle'],
                                            enabled: false,
                                            decoration: _decoration('Nº Controle do Certificado').copyWith(
                                              hintText: _modoVisualizacao ? '' : 'A ser gerado automaticamente',
                                              filled: true,
                                              fillColor: Colors.grey[200],
                                            ),
                                            style: const TextStyle(
                                              fontStyle: FontStyle.italic,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                      ]),
                                      const SizedBox(height: 12),
                                      _linhaFlexivel([
                                        {
                                          'flex': 5,
                                          'widget': TextFormField(
                                            controller: TextEditingController(text: '(aguardando)'),
                                            keyboardType: TextInputType.number,
                                            enabled: false,
                                            decoration: _decoration('Notas Fiscais').copyWith(
                                              hintText: '',
                                              fillColor: Colors.grey[100],
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
                                              : IgnorePointer(
                                                  ignoring: true,
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
                                                      fillColor: Colors.grey[100],
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
                                            enabled: false,
                                            decoration: _decoration('Motorista').copyWith(
                                              counterText: '',
                                              fillColor: Colors.grey[100],
                                            ),
                                          ),
                                        },
                                        {
                                          'flex': 10,
                                          'widget': TextFormField(
                                            controller: campos['transportadora'],
                                            maxLength: 50,
                                            enabled: false,
                                            decoration: _decoration('Transportadora').copyWith(
                                              counterText: '',
                                              fillColor: Colors.grey[100],
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
                                    ],
                                  ),
                                ),
                                _secao('Parâmetros para conversão do volume observado'),
                                _buildSecaoParametrosConversao(),
                                const SizedBox(height: 12),
                                _secao('Volumes apurados'),
                                _buildSecaoTanques(),
                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
                          if (!_carregandoDadosMovimentacao && !_carregandoDadosTemp)
                          // ================= BOTÕES =================
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // BOTÃO CANCELAR CERTIFICADO (Novo)
                              ElevatedButton.icon(
                                onPressed: _modoVisualizacao ? _cancelarCertificado : null,
                                icon: Icon(Icons.cancel_outlined, size: 24, color: _modoVisualizacao ? Colors.white : Colors.grey[600]),
                                label: const Text(
                                  'Cancelar Certificado',
                                  style: TextStyle(fontSize: 16),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _modoVisualizacao ? Colors.red[700] : Colors.grey[300],
                                  foregroundColor: _modoVisualizacao ? Colors.white : Colors.grey[600],
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),

                              // BOTÃO GERAR PDF
                              ElevatedButton.icon(
                                onPressed: _modoVisualizacao ? _baixarPDF : null,
                                icon: const Icon(Icons.picture_as_pdf, size: 24),
                                label: const Text(
                                  'Gerar Certificado PDF',
                                  style: TextStyle(fontSize: 16),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _modoVisualizacao
                                      ? const Color(0xFF0D47A1)
                                      : Colors.grey[300],
                                  foregroundColor:
                                      _modoVisualizacao ? Colors.white : Colors.grey[600],
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),

                              // BOTÃO EMITIR CERTIFICADO
                              if (!_modoVisualizacao)
                                ElevatedButton.icon(
                                  onPressed: (_salvandoCertificado || !_todosVolumes20Validos() || _camposTempVazios()) ? null : _confirmarEmissaoCertificado,
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
                                    backgroundColor: (!_salvandoCertificado && _todosVolumes20Validos() && !_camposTempVazios()) ? Colors.green : Colors.grey[300],
                                    foregroundColor: (!_salvandoCertificado && _todosVolumes20Validos() && !_camposTempVazios()) ? Colors.white : Colors.grey[600],
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                )
                              else
                                // BOTÃO CONCLUIR (Antigo Voltar)
                                ElevatedButton.icon(
                                  onPressed: _voltar,
                                  icon: const Icon(Icons.check_circle_outline, size: 24),
                                  label: const Text(
                                    'Concluir',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue[800],
                                    foregroundColor: Colors.white,
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
      ),
    );
  }

  // Verificar se os campos de temperatura estão vazios
  bool _camposTempVazios() {
    return campos['tempAmostra']!.text.isEmpty ||
           campos['densidadeAmostra']!.text.isEmpty ||
           campos['tempCT']!.text.isEmpty;
  }

  void _limparVolumes20CTanques() {
    for (var tanque in _tanques) {
      tanque.volume20CCtrl.text = '';
    }
    setState(() {});
  }

  // ================= MÉTODOS DE GERENCIAMENTO DE TANQUES =================
  
  void _inicializarTanquesDaOrdem() {
    if (widget.tanquesDaOrdem != null && widget.tanquesDaOrdem!.isNotEmpty) {
      for (var tanqueInfo in widget.tanquesDaOrdem!) {
        final novoTanque = TanqueDados(
          id: tanqueInfo['movimentacao_id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
          volumeAmbCtrl: TextEditingController(),
          volume20CCtrl: TextEditingController(),
          buscarDoBanco: false,
          produtoNome: tanqueInfo['produto_nome']?.toString(),
          produtoId: tanqueInfo['produto_id']?.toString(),
        );
        
        if (tanqueInfo['saida_amb'] != null) {
          novoTanque.volumeAmbCtrl.text = _mascaraMilharUI(tanqueInfo['saida_amb'].toString());
        }
        if (tanqueInfo['saida_vinte'] != null) {
          novoTanque.volume20CCtrl.text = _mascaraMilharUI(tanqueInfo['saida_vinte'].toString());
        }
        
        novoTanque.volume20CCtrl.addListener(() {
          if (mounted) setState(() {});
        });
        _tanques.add(novoTanque);
      }
    } else {
      final novoTanque = TanqueDados(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        volumeAmbCtrl: TextEditingController(),
        volume20CCtrl: TextEditingController(),
        buscarDoBanco: false,
      );
      novoTanque.volume20CCtrl.addListener(() {
        if (mounted) setState(() {});
      });
      _tanques.add(novoTanque);
    }
  }

  // ================= SEÇÃO DE TANQUES =================

  Widget _buildSecaoParametrosConversao() {
    final bool isTransfEditavel =
        widget.tipoOp?.toLowerCase() == 'transf' && !_modoVisualizacao;

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text('TEMP. AMOSTRA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 2),
                TextFormField(
                  controller: campos['tempAmostra'],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  focusNode: isTransfEditavel ? _focusTempAmostra : null,
                  enabled: isTransfEditavel,
                  inputFormatters: isTransfEditavel ? [_TemperaturaInputFormatter()] : null,
                  onChanged: isTransfEditavel
                      ? (v) {
                          setState(() {
                            campos['densidade20']!.text = '';
                            campos['fatorCorrecao']!.text = '';
                          });
                          _limparVolumes20CTanques();
                        }
                      : null,
                  decoration: _decoration('').copyWith(
                    fillColor: isTransfEditavel ? Colors.white : Colors.grey[100],
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text('DENS. OBSERVADA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 2),
                TextFormField(
                  controller: campos['densidadeAmostra'],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  focusNode: isTransfEditavel ? _focusDensidadeAmostra : null,
                  enabled: isTransfEditavel,
                  inputFormatters: isTransfEditavel ? [_DensidadeInputFormatter()] : null,
                  onChanged: isTransfEditavel
                      ? (v) {
                          setState(() {
                            campos['densidade20']!.text = '';
                            campos['fatorCorrecao']!.text = '';
                          });
                          _limparVolumes20CTanques();
                        }
                      : null,
                  decoration: _decoration('').copyWith(
                    fillColor: isTransfEditavel ? Colors.white : Colors.grey[100],
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text('TEMP. CT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 2),
                TextFormField(
                  controller: campos['tempCT'],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  focusNode: isTransfEditavel ? _focusTempCT : null,
                  enabled: isTransfEditavel,
                  inputFormatters: isTransfEditavel ? [_TemperaturaInputFormatter()] : null,
                  onChanged: isTransfEditavel
                      ? (v) {
                          setState(() {
                            campos['densidade20']!.text = '';
                            campos['fatorCorrecao']!.text = '';
                          });
                          _limparVolumes20CTanques();
                        }
                      : null,
                  decoration: _decoration('').copyWith(
                    fillColor: isTransfEditavel ? Colors.white : Colors.grey[100],
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text('DENS. 20ºC', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 2),
                TextFormField(
                  controller: campos['densidade20'],
                  enabled: false,
                  decoration: _decoration('').copyWith(
                    fillColor: Colors.grey[100],
                    suffixIcon: const Icon(Icons.calculate, color: Colors.green),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text('FCV', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 2),
                TextFormField(
                  controller: campos['fatorCorrecao'],
                  enabled: false,
                  decoration: _decoration('').copyWith(
                    fillColor: Colors.grey[100],
                    suffixIcon: const Icon(Icons.calculate, color: Colors.green),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecaoTanques() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._tanques.asMap().entries.map((entry) {
          final index = entry.key;
          final tanque = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildLinhaTanque(tanque, index + 1),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildLinhaTanque(TanqueDados tanque, int numeroTanque) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[50],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tanque $numeroTanque${tanque.produtoNome != null ? " - ${tanque.produtoNome}" : ""}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF0D47A1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: TextFormField(
                    controller: tanque.volumeAmbCtrl,
                    keyboardType: TextInputType.number,
                    enabled: false,
                    onChanged: (value) => _calcularVolume20CTanque(tanque),
                    decoration: _decoration('Volume carregado (ambiente)').copyWith(
                      fillColor: Colors.grey[100],
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: TextFormField(
                    controller: tanque.volume20CCtrl,
                    keyboardType: TextInputType.number,
                    enabled: false,
                    decoration: _decoration('Volume apurado a 20 ºC').copyWith(
                      fillColor: Colors.grey[100],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _calcularVolume20CTanque(TanqueDados tanque) {
    if (_modoVisualizacao) return;

    final fcvText = campos['fatorCorrecao']!.text;
    if (fcvText.isEmpty || fcvText == '-') {
      tanque.volume20CCtrl.text = '';
      return;
    }

    final volumeAmbText = tanque.volumeAmbCtrl.text;
    if (volumeAmbText.isEmpty) {
      tanque.volume20CCtrl.text = '';
      return;
    }

    final volumeAmb = double.tryParse(volumeAmbText.replaceAll('.', ''));
    final fcv = double.tryParse(fcvText.replaceAll(',', '.'));

    if (volumeAmb == null || fcv == null) {
      return;
    }

    final volume20C = volumeAmb * fcv;
    tanque.volume20CCtrl.text = _formatarNumeroParaCampo(volume20C);

    setState(() {});
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
        decoration: _decoration(label, disabled: !enabled).copyWith(
          fillColor: enabled ? Colors.white : Colors.grey[200],
        ),
      ),
    );
  }

  InputDecoration _decoration(String label,
          {bool disabled = false}) =>
      InputDecoration(
        labelText: label,
        filled: true,
        fillColor: disabled ? Colors.grey[200] : Colors.white,
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

  // ================= CÁLCULOS =================
  Future<String> _buscarDensidade20C({
    required String temperaturaAmostra,
    required String densidadeObservada,
    required String produtoNome,
  }) async {
    final supabase = Supabase.instance.client;
    
    try {
      print('🔍 DEBUG _buscarDensidade20C:');
      print('   > Entrada: Temp=$temperaturaAmostra, Dens=$densidadeObservada, Produto=$produtoNome');

      if (temperaturaAmostra.isEmpty || densidadeObservada.isEmpty) {
        print('   ⚠️ Campos vazios, abortando.');
        return '-';
      }
      
      final nomeProdutoLower = produtoNome.toLowerCase().trim();
      final bool usarViewAnidroHidratado = 
          nomeProdutoLower.contains('anidro') || 
          nomeProdutoLower.contains('hidratado');
      
      String temperaturaFormatada = temperaturaAmostra
          .replaceAll(' ºC', '')
          .replaceAll('°C', '')
          .replaceAll('ºC', '')
          .replaceAll('°', '')
          .replaceAll('C', '')
          .trim();
      
      temperaturaFormatada = temperaturaFormatada.replaceAll('.', ',');
      
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
      
      print('   > Formatado: Temp=$temperaturaFormatada, Dens=$densidadeFormatada');

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
      
      print('   > View Target: $nomeView, Coluna: $nomeColuna');

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
        final formatado = _formatarResultado(valorBruto);
        print('   ✅ Sucesso (direto): $formatado');
        return formatado;
      }
      
      print('   ⚠️ Não encontrado (direto). Tentando variações de temperatura...');
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
          print('     - Tentando: $formatoTemp');
          final resultado = await supabase
              .from(nomeView)
              .select(nomeColuna)
              .eq('temperatura_obs', formatoTemp)
              .maybeSingle();
          
          if (resultado != null && resultado[nomeColuna] != null) {
            String valorBruto = resultado[nomeColuna].toString();
            final formatado = _formatarResultado(valorBruto);
            print('   ✅ Sucesso (variação): $formatado');
            return formatado;
          }
        } catch (e) {
          print('     ❌ Erro na variação $formatoTemp: $e');
          continue;
        }
      }
      
      print('   ❌ Nenhum resultado encontrado após variações.');
      return '-';
      
    } catch (e) {
      print('   🔴 ERRO CRÍTICO _buscarDensidade20C: $e');
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
      print('🔍 DEBUG _buscarFCV:');
      print('   > Entrada: TempTanque=$temperaturaTanque, Dens20C=$densidade20C, Produto=$produtoNome');

      if (temperaturaTanque.isEmpty ||
          temperaturaTanque == '-' ||
          densidade20C.isEmpty ||
          densidade20C == '-') {
        print('   ⚠️ Parâmetros inválidos ou vazios.');
        return '-';
      }

      final nomeProdutoLower = produtoNome.toLowerCase().trim();
      final nomeView = (nomeProdutoLower.contains('anidro') ||
              nomeProdutoLower.contains('hidratado'))
          ? 'tcv_anidro_hidratado_vw'
          : 'tcv_gasolina_diesel_vw';
      
      print('   > View Target: $nomeView');

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
        print('   ⚠️ Erro ao parsear densidade: $densidadeFormatada');
        return '-';
      }

      print('   > Formatado: Temp=$temperaturaFormatada, DensNum=$densidadeNum');

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
      print('   > Código Densidade: $codigoOriginal');

      Future<String?> _buscarFCVPorCodigo(String codigo) async {
        final coluna = 'v_$codigo';
        print('     - Buscando FCV na coluna: $coluna para temp $temperaturaFormatada');

        try {
          final r = await supabase
              .from(nomeView)
              .select(coluna)
              .eq('temperatura_obs', temperaturaFormatada)
              .maybeSingle();

          if (r != null && r[coluna] != null) {
            return _formatarFCV(r[coluna].toString());
          }
        } catch (e) {
          print('     ⚠️ Erro na consulta _buscarFCVPorCodigo: $e');
        }
        return null;
      }

      final direto = await _buscarFCVPorCodigo(codigoOriginal);
      if (direto != null) {
        print('   ✅ FCV encontrado (direto): $direto');
        return direto;
      }

      print('   ⚠️ FCV direto não mapeado. Buscando densidade disponível mais próxima...');
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
      print('   > Densidade mais próxima identificada: ${densidadeMaisProxima['valor']} (Cód: $codigoMaisProximo)');

      final aproximado = await _buscarFCVPorCodigo(codigoMaisProximo);
      
      if (aproximado != null) {        
        print('   ✅ FCV encontrado (por aproximação de densidade): $aproximado');
        return aproximado;
      }

      print('   ⚠️ Aproximação falhou. Tentando variações de temperatura para código $codigoMaisProximo...');
      final temperaturaAlternativas = [
        temperaturaFormatada,
        temperaturaFormatada.replaceAll(',', '.'),
        ..._gerarVariacoesTemperatura(temperaturaFormatada),
      ];

      for (final tempAlt in temperaturaAlternativas) {
        try {
          print('     - Tentando Variação Temp: $tempAlt');
          final r = await supabase
              .from(nomeView)
              .select('v_$codigoMaisProximo')
              .eq('temperatura_obs', tempAlt)
              .maybeSingle();

          if (r != null && r['v_$codigoMaisProximo'] != null) {
            final res = _formatarFCV(r['v_$codigoMaisProximo'].toString());
            print('   ✅ FCV encontrado (variação temp): $res');
            return res;
          }
        } catch (e) {
          print('     ❌ Erro na variação temp $tempAlt: $e');
          continue;
        }
      }

      print('   ❌ Nenhum FCV encontrado para os parâmetros fornecidos.');
      return '-';
    } catch (e) {
      print('   🔴 ERRO CRÍTICO _buscarFCV: $e');
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


  // ================= DOWNLOAD PDF =================
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
      final tanquePrincipal = _tanques.isNotEmpty ? _tanques[0] : null;
      
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
        'volumeCarregadoAmb': tanquePrincipal?.volumeAmbCtrl.text ?? '',
        'volumeApurado20C': tanquePrincipal?.volume20CCtrl.text ?? '',
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
          
          console.log('Download iniciado: ' + '$fileName');
        } catch (error) {
          console.error('Erro no download automático:', error);
          window.open('$dataUrl', '_blank');
        }
      ''';
      
      js.context.callMethod('eval', [jsCode]);
      
    } catch (e) {
      print('Erro no download Web: $e');
      
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

  // ================= BOTÃO VOLTAR =================
  void _voltar() {
    FocusScope.of(context).unfocus();
    try {
      widget.onVoltar();
    } catch (_) {
      Navigator.of(context).pop(true);
    }
  }

  // Método para cancelar o certificado no banco
  Future<void> _cancelarCertificado() async {
    if (!_modoVisualizacao || (widget.idCertificado == null && campos['numeroControle']!.text.isEmpty)) return;

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
                        text: 'Atenção: Esta ação é irreversível e o certificado será removido permanentemente do banco.',
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
      _salvandoCertificado = true; // Reutilizando flag de loading
    });

    try {
      final supabase = Supabase.instance.client;
      final idCert = widget.idCertificado ?? _dadosExistentes?['id'];

      if (idCert != null) {
        await supabase
            .from('ordens_analises')
            .delete()
            .eq('id', idCert);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Certificado cancelado com sucesso!'), backgroundColor: Colors.green),
          );
          _voltar(); // Volta para a tela anterior após cancelar
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

  // Método para confirmar emissão do certificado
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

    if (_camposTempVazios()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dados de temperatura e densidade não disponíveis. Necessita de lançamento pelo laboratório.'),
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
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                const Text(
                  'Tem certeza que deseja emitir o certificado?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),
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
  
  // Método para processar a emissão do certificado
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
      final terminalIdEfetivo = widget.terminalId ?? usuario?.terminalId;
      if (terminalIdEfetivo == null || terminalIdEfetivo.isEmpty) {
        throw Exception('Terminal não identificado. Verifique o vínculo de terminal.');
      }

      // ===== VERIFICA SE JÁ EXISTE CERTIFICADO DE ORIGEM =====
      if (widget.idMovimentacao != null && widget.idMovimentacao!.isNotEmpty) {
        final certificadoExistente = await supabase
            .from('ordens_analises')
            .select('id, numero_controle, tipo_analise')
            .eq('movimentacao_id', widget.idMovimentacao!)
            .eq('tipo_analise', 'origem')
            .maybeSingle();

        if (certificadoExistente != null &&
            certificadoExistente['id'] != null &&
            certificadoExistente['tipo_analise'] == 'origem') {
          if (!mounted) return;

          setState(() {
            _salvandoCertificado = false;
            _modoVisualizacao = true;
          });

          await _carregarDadosCertificado(
            certificadoExistente['id'].toString(),
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    '⚠️ Já existe certificado de ORIGEM (Nº ${certificadoExistente['numero_controle'] ?? '--'})!'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
      }

      if (produtoSelecionado == null) {
        throw Exception('Selecione um produto!');
      }

      final produtoId = await _resolverProdutoId(produtoSelecionado!);

      if (_tanques.isEmpty) {
        throw Exception('Nenhum tanque encontrado!');
      }

      if (_camposTempVazios()) {
        throw Exception('Dados de temperatura e densidade não disponíveis. Necessita de lançamento pelo laboratório.');
      }

      final tanquePrincipal = _tanques[0];

      final agoraUtc = DateTime.now().toUtc();
      final agoraSaoPaulo =
          agoraUtc.subtract(const Duration(hours: 3));

      // Buscar ordem_id da movimentação
      String? ordemId;
      try {
        final movRef = await supabase
            .from('movimentacoes')
            .select('ordem_id')
            .eq('id', widget.idMovimentacao!)
            .maybeSingle();
        ordemId = movRef?['ordem_id']?.toString();
      } catch (e) {
        print('Erro ao buscar ordem_id: $e');
      }

      final dadosOrdem = {
        'data_criacao': agoraSaoPaulo.toIso8601String(),
        'transportadora': campos['transportadora']!.text,
        'motorista': campos['motorista']!.text,
        'notas_fiscais': campos['notas']!.text,
        'placa_cavalo': campos['placaCavalo']!.text,
        'carreta1': campos['carreta1']!.text,
        'carreta2': campos['carreta2']!.text,
        'produto_id': produtoId,
        'produto_nome': produtoSelecionado,
        'temperatura_amostra':
            _converterParaDecimal(campos['tempAmostra']!.text),
        'densidade_observada':
            _converterParaDecimal(campos['densidadeAmostra']!.text),
        'temperatura_ct':
            _converterParaDecimal(campos['tempCT']!.text),
        'densidade_20c':
            _converterParaDecimal(campos['densidade20']!.text),
        'fator_correcao':
            _converterParaDecimal(campos['fatorCorrecao']!.text),
        'origem_ambiente':
            _converterParaInteiro(tanquePrincipal.volumeAmbCtrl.text),
        'destino_ambiente': null,
        'origem_20c': null,
        'destino_20c':
            _converterParaInteiro(tanquePrincipal.volume20CCtrl.text),
        'usuario_id': user.id,
        'movimentacao_id': widget.idMovimentacao,
        'tipo_analise': 'origem',
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

      if (widget.idMovimentacao != null &&
          widget.idMovimentacao!.isNotEmpty) {
        await _atualizarMovimentacoesDaOrdem(
          movimentacaoReferenciaId: widget.idMovimentacao!,
        );
      }

      // Para transferências e consumo próprio, registrar os dados de temp/densidade no histórico
      if (widget.tipoOp?.toLowerCase() == 'transf' || widget.tipoOp?.toLowerCase() == 'consumo') {
        try {
          await supabase.from('temp_e_dens').insert({
            'temp_amostra': _converterParaDecimal(campos['tempAmostra']!.text),
            'densid_obs': _converterParaDecimal(campos['densidadeAmostra']!.text),
            'temp_ct': _converterParaDecimal(campos['tempCT']!.text),
            'placa': campos['placaCavalo']!.text.isEmpty ? null : campos['placaCavalo']!.text,
            'terminal_id': terminalIdEfetivo,
            'produto_id': produtoId,
            'data_hora_medicao': agoraSaoPaulo.toIso8601String(),
          });
        } catch (e) {
          // Não bloqueia a emissão do certificado se o registro falhar
          print('Aviso: erro ao registrar temp_e_dens: $e');
        }
      }

      setState(() {
        _modoVisualizacao = true;
        _salvandoCertificado = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Certificado emitido com sucesso!'),
            backgroundColor: Colors.green,
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

  Future<void> _atualizarMovimentacoesDaOrdem({
    required String movimentacaoReferenciaId,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      String timestampBrasilia = _obterTimestampBrasilia();

      // Ajustar data_carga se dataFiltro estiver presente (dd/mm/aaaa)
      if (widget.dataFiltro != null && widget.dataFiltro!.isNotEmpty) {
        try {
          final partes = widget.dataFiltro!.split('/');
          if (partes.length == 3) {
            final dia = int.parse(partes[0]);
            final mes = int.parse(partes[1]);
            final ano = int.parse(partes[2]);
            
            final agora = DateTime.now();
            final dataCarga = DateTime(ano, mes, dia, agora.hour, agora.minute, agora.second);
            timestampBrasilia = dataCarga.toIso8601String();
          }
        } catch (e) {
          print('Erro ao formatar data do filtro: $e');
        }
      }

      final movimentacaoRef = await supabase
          .from('movimentacoes')
          .select('ordem_id')
          .eq('id', movimentacaoReferenciaId)
          .maybeSingle();

      final ordemId = movimentacaoRef?['ordem_id']?.toString();
      if (ordemId == null || ordemId.isEmpty) {
        throw Exception('Não foi possível identificar a ordem da movimentação.');
      }

      final movimentacoesDaOrdem = await supabase
          .from('movimentacoes')
          .select('id')
          .eq('ordem_id', ordemId);

      final tanquesPorMovimentacaoId = {
        for (final tanque in _tanques) tanque.id: tanque,
      };

      for (final mov in movimentacoesDaOrdem) {
        final movimentacaoId = mov['id']?.toString();
        if (movimentacaoId == null || movimentacaoId.isEmpty) continue;

        final tanque = tanquesPorMovimentacaoId[movimentacaoId];
        final tipoOp = widget.tipoOp?.toLowerCase() ?? '';

        final dadosUpdate = <String, dynamic>{
          'data_carga': timestampBrasilia,
          'status_circuito_orig': (tipoOp == 'venda' || tipoOp == 'consumo') ? '5' : '4',
          'updated_at': timestampBrasilia,
        };

        if (tanque != null) {
          final volumeVinte = _converterParaInteiro(tanque.volume20CCtrl.text);
          dadosUpdate['saida_amb'] = _converterParaInteiro(tanque.volumeAmbCtrl.text);
          dadosUpdate['saida_vinte'] = volumeVinte;
          dadosUpdate['qtd_faturada'] = volumeVinte;
        }

        await supabase
            .from('movimentacoes')
            .update(dadosUpdate)
            .eq('id', movimentacaoId);
      }
    } catch (e) {
      print('✗ Erro ao atualizar movimentações da ordem: $e');
      rethrow;
    }
  }
  
  String _obterTimestampBrasilia() {
    final agora = DateTime.now().toUtc();
    final brasilia = agora.subtract(const Duration(hours: 3));
    return brasilia.toIso8601String();
  }
  
  // ================= AUXILIAR =================
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
    _focusTempAmostra.dispose();
    _focusDensidadeAmostra.dispose();
    _focusTempCT.dispose();
    for (var tanque in _tanques) {
      tanque.dispose();
    }
    super.dispose();
  }

  double? _converterParaDecimal(String? texto) {
    if (texto == null || texto.isEmpty || texto == '-') return null;
    
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

  String _mascaraMilharUI(String texto) {
    final numeros = texto.replaceAll(RegExp(r'[^\d]'), '');
    if (numeros.isEmpty) return '';

    String resultado = '';
    for (int i = numeros.length - 1, c = 0; i >= 0; i--, c++) {
      if (c > 0 && c % 3 == 0) resultado = '.$resultado';
      resultado = numeros[i] + resultado;
    }
    return resultado;
  }
}