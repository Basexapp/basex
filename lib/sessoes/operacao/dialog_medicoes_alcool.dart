import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_page.dart';

class DialogMedicoesAlcool extends StatefulWidget {
  final String? produtoNome;
  final String? tanqueReferencia;
  final VoidCallback onSaved;

  const DialogMedicoesAlcool({
    super.key,
    this.produtoNome,
    this.tanqueReferencia,
    required this.onSaved,
  });

  @override
  State<DialogMedicoesAlcool> createState() => _DialogMedicoesAlcoolState();
}

class _DialogMedicoesAlcoolState extends State<DialogMedicoesAlcool> {
  // Controllers para o diálogo de inserção
  final TextEditingController _tanqueCtrl = TextEditingController();
  final TextEditingController _dataCtrl = TextEditingController();
  final TextEditingController _horarioCtrl = TextEditingController();
  final TextEditingController _cmCtrl = TextEditingController();
  final TextEditingController _mmCtrl = TextEditingController();
  final TextEditingController _volCalcCtrl = TextEditingController();
  final TextEditingController _volAmbProdutoCtrl = TextEditingController();
  final TextEditingController _tempTanqueCtrl = TextEditingController();
  final TextEditingController _densidadeObsCtrl = TextEditingController();
  final TextEditingController _grauAlcoolGLCtrl = TextEditingController();
  final TextEditingController _fcvCtrl = TextEditingController();
  final TextEditingController _aguaCmCtrl = TextEditingController();
  final TextEditingController _aguaMmCtrl = TextEditingController();
  final TextEditingController _volAguaCtrl = TextEditingController();
  final TextEditingController _massaCtrl = TextEditingController();
  final TextEditingController _vol20Ctrl = TextEditingController();
  final TextEditingController _observacoesCtrl = TextEditingController();

  // FocusNodes para disparar cálculos ao perder o foco
  final FocusNode _tempTanqueFocus = FocusNode();
  final FocusNode _densidadeObsFocus = FocusNode();

  // Estados de cálculo
  bool _calculandoVolume = false;
  bool _calculandoVolume20 = false;
  double _volumeTotalRaw = 0;
  double _volumeAguaRaw = 0;

  // Debouncers
  Timer? _debounceVolume;
  Timer? _debounceVolume20;

  @override
  void initState() {
    super.initState();
    _tanqueCtrl.text = widget.tanqueReferencia ?? '';
    _dataCtrl.text = DateFormat('dd/MM/yyyy').format(DateTime.now());

    _cmCtrl.addListener(_onAlturaChanged);
    _mmCtrl.addListener(_onAlturaChanged);
    _aguaCmCtrl.addListener(_onAlturaAguaChanged);
    _aguaMmCtrl.addListener(_onAlturaAguaChanged);

    // Adiciona listeners para perda de foco
    _tempTanqueFocus.addListener(_onFocusChanged);
    _densidadeObsFocus.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    // Se nenhum dos campos de entrada tem o foco, força o cálculo
    if (!_tempTanqueFocus.hasFocus && !_densidadeObsFocus.hasFocus) {
      _calcularVolume20();
    }
  }

  @override
  void dispose() {
    _debounceVolume?.cancel();
    _debounceVolume20?.cancel();
    _tempTanqueFocus.dispose();
    _densidadeObsFocus.dispose();
    _tanqueCtrl.dispose();
    _dataCtrl.dispose();
    _horarioCtrl.dispose();
    _cmCtrl.dispose();
    _mmCtrl.dispose();
    _volCalcCtrl.dispose();
    _volAmbProdutoCtrl.dispose();
    _tempTanqueCtrl.dispose();
    _densidadeObsCtrl.dispose();
    _grauAlcoolGLCtrl.dispose();
    _fcvCtrl.dispose();
    _aguaCmCtrl.dispose();
    _aguaMmCtrl.dispose();
    _volAguaCtrl.dispose();
    _massaCtrl.dispose();
    _vol20Ctrl.dispose();
    _observacoesCtrl.dispose();
    super.dispose();
  }

  void _onAlturaChanged() {
    _debounceVolume?.cancel();
    _debounceVolume = Timer(const Duration(milliseconds: 600), () {
      _calcularVolumeAmbiente();
    });
  }

  void _onAlturaAguaChanged() {
    _debounceVolume?.cancel();
    _debounceVolume = Timer(const Duration(milliseconds: 600), () {
      _calcularVolumeAgua();
    });
  }

  String _aplicarMascaraHorario(String texto, String valorAntigo) {
    // Se o usuário está apagando (texto menor que o anterior), permite a deleção natural
    if (texto.length < valorAntigo.length) {
      // Remove o sufixo " h" se sobrar apenas ele ou se estiver apenas deletando
      String limpo = texto.replaceAll(' h', '');
      if (limpo.isEmpty) return '';
      return '$limpo h';
    }

    String apenasNumeros = texto.replaceAll(RegExp(r'[^\d]'), '');
    if (apenasNumeros.length > 4) apenasNumeros = apenasNumeros.substring(0, 4);

    String resultado = '';
    for (int i = 0; i < apenasNumeros.length; i++) {
      if (i == 2) resultado += ':';
      resultado += apenasNumeros[i];
    }

    if (resultado.isNotEmpty) resultado += ' h';
    return resultado;
  }

  String _aplicarMascaraTemperatura(String texto, String valorAntigo) {
    if (texto.length < valorAntigo.length) return texto;

    String apenasNumeros = texto.replaceAll(RegExp(r'[^\d]'), '');
    if (apenasNumeros.length > 3) apenasNumeros = apenasNumeros.substring(0, 3);
    String resultado = '';
    for (int i = 0; i < apenasNumeros.length; i++) {
      if (i == 2 && apenasNumeros.length > 2) resultado += ',';
      resultado += apenasNumeros[i];
    }
    return resultado;
  }

  String _aplicarMascaraDensidade(String texto, String valorAntigo) {
    if (texto.length < valorAntigo.length) return texto;

    String apenasNumeros = texto.replaceAll(RegExp(r'[^\d]'), '');
    if (apenasNumeros.length > 5) apenasNumeros = apenasNumeros.substring(0, 5);
    if (apenasNumeros.isEmpty) return '';
    String parteInteira = apenasNumeros.substring(0, 1);
    String parteDecimal = '';
    if (apenasNumeros.length > 1) parteDecimal = apenasNumeros.substring(1);
    return parteDecimal.isEmpty ? '$parteInteira,' : '$parteInteira,$parteDecimal';
  }

  // ── Cálculo do volume ao ambiente ─────────────────────────────────────────

  Future<void> _calcularVolumeAmbiente() async {
    final cm = _cmCtrl.text.trim();
    if (cm.isEmpty) {
      if (mounted) {
        setState(() {
          _volCalcCtrl.text = '';
          _volumeTotalRaw = 0;
          _atualizarVolumeLiquido();
        });
      }
      return;
    }

    if (mounted) setState(() => _calculandoVolume = true);

    try {
      final mm = _mmCtrl.text.trim();
      final volume = await _buscarVolumeReal(cm, mm);

      _volumeTotalRaw = volume;
      _volCalcCtrl.text = volume > 0 ? _formatarVolume(volume).replaceAll(' L', '') : '';

      _atualizarVolumeLiquido();

      if (mounted) setState(() => _calculandoVolume = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _volCalcCtrl.text = '';
          _volumeTotalRaw = 0;
          _calculandoVolume = false;
          _atualizarVolumeLiquido();
        });
      }
    }
  }

  Future<void> _calcularVolumeAgua() async {
    final cm = _aguaCmCtrl.text.trim();
    if (cm.isEmpty) {
      if (mounted) {
        setState(() {
          _volAguaCtrl.text = '';
          _volumeAguaRaw = 0;
          _atualizarVolumeLiquido();
        });
      }
      return;
    }

    if (mounted) setState(() => _calculandoVolume = true);

    try {
      final mm = _aguaMmCtrl.text.trim();
      final volume = await _buscarVolumeReal(cm, mm);

      _volumeAguaRaw = volume;
      _volAguaCtrl.text = volume > 0 ? _formatarVolume(volume).replaceAll(' L', '') : '';

      _atualizarVolumeLiquido();

      if (mounted) setState(() => _calculandoVolume = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _volAguaCtrl.text = '';
          _volumeAguaRaw = 0;
          _calculandoVolume = false;
          _atualizarVolumeLiquido();
        });
      }
    }
  }

  void _atualizarVolumeLiquido() {
    final liquido = _volumeTotalRaw - _volumeAguaRaw;
    final valorFinal = liquido > 0 ? liquido : 0.0;

    _volAmbProdutoCtrl.text = valorFinal > 0 ? _formatarVolume(valorFinal).replaceAll(' L', '') : '';

    // Dispara o cálculo de 20C se houver volume de produto
    if (valorFinal > 0) {
      _calcularVolume20();
    } else {
      _vol20Ctrl.text = '';
      _massaCtrl.text = '';
    }
  }

  // ── Persistência e busca de dados ─────────────────────────────────────────

  double? _parseNumero(String v) {
    if (v.isEmpty || v == '-') return null;
    final t = v.replaceAll('.', '').replaceAll(',', '.').replaceAll(' L', '').trim();
    return double.tryParse(t);
  }

  Future<void> _salvarMedicao() async {
    final supabase = Supabase.instance.client;

    // Validações básicas antes de salvar
    if (_horarioCtrl.text.isEmpty || _cmCtrl.text.isEmpty || _tempTanqueCtrl.text.isEmpty || _densidadeObsCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, preencha os campos obrigatórios: Horário, Altura, Temp. Tanque e Densid. Obs.'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      // 1. Buscar IDs necessários
      final prodRes = await supabase
          .from('produtos')
          .select('id')
          .eq('nome', widget.produtoNome ?? '')
          .maybeSingle();

      final tqRes = await supabase
          .from('tanques')
          .select('id')
          .eq('referencia', widget.tanqueReferencia ?? '')
          .maybeSingle();

      if (prodRes == null) throw 'Produto não encontrado.';

      // 2. Formatar data e horário
      DateTime dataFormatada = DateFormat('dd/MM/yyyy').parse(_dataCtrl.text);
      String isoData = DateFormat('yyyy-MM-dd').format(dataFormatada);
      String isoHorario = _horarioCtrl.text.replaceAll(' h', '').trim();
      if (isoHorario.length == 4 && !isoHorario.contains(':')) {
        isoHorario = '${isoHorario.substring(0, 2)}:${isoHorario.substring(2, 4)}';
      }

      // 3. Montar payload
      final payload = {
        'data': isoData,
        'horario': isoHorario,
        'produto_id': prodRes['id'],
        'tanque_id': tqRes?['id'],
        'terminal_id': UsuarioAtual.instance?.terminalId,
        'usuario_id': supabase.auth.currentUser?.id,
        'altura_total_cm': _parseNumero(_cmCtrl.text),
        'altura_total_mm': _parseNumero(_mmCtrl.text),
        'volume_total_liquido': _parseNumero(_volAmbProdutoCtrl.text),
        'agua_cm': _parseNumero(_aguaCmCtrl.text),
        'agua_mm': _parseNumero(_aguaMmCtrl.text),
        'vol_agua': _parseNumero(_volAguaCtrl.text),
        'temperatura_tanque': _parseNumero(_tempTanqueCtrl.text),
        'densidade_observada': _parseNumero(_densidadeObsCtrl.text),
        'grau_alcolico_gl': _parseNumero(_grauAlcoolGLCtrl.text),
        'fcv': _parseNumero(_fcvCtrl.text),
        'massa': _parseNumero(_massaCtrl.text),
        'volume_20': _parseNumero(_vol20Ctrl.text),
        'volume_ambiente': _parseNumero(_volCalcCtrl.text),
        'observacoes': _observacoesCtrl.text.trim(),
      };

      await supabase.from('medicoes').insert(payload);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Medição salva com sucesso!'), backgroundColor: Colors.green),
        );
        widget.onSaved();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar medição: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ── Cálculo para Álcool usando tabela tcv_alcool ──────────────────────────

  Future<void> _calcularVolume20() async {
    final tempTanque = _tempTanqueCtrl.text.trim();
    final densObs = _densidadeObsCtrl.text.trim();

    if (tempTanque.isEmpty || densObs.isEmpty) {
      if (mounted) {
        setState(() {
          _vol20Ctrl.text = '';
          _grauAlcoolGLCtrl.text = '';
          _fcvCtrl.text = '';
        });
      }
      return;
    }

    final volAmb = _volumeTotalRaw - _volumeAguaRaw;
    if (volAmb <= 0) {
      if (mounted) {
        setState(() {
          _vol20Ctrl.text = '';
          _massaCtrl.text = '';
        });
      }
      return;
    }

    if (mounted) setState(() => _calculandoVolume20 = true);

    try {
      // Busca na tabela tcv_alcool
      final resultado = await _buscarTabelaAlcool(
        temperatura: tempTanque,
        densidadeObservada: densObs,
      );

      if (resultado == null) {
        if (mounted) {
          setState(() {
            _vol20Ctrl.text = '';
            _grauAlcoolGLCtrl.text = '';
            _fcvCtrl.text = '';
            _calculandoVolume20 = false;
          });
        }
        return;
      }

      final fcvNum = resultado['fcv'];
      final vol20 = volAmb * fcvNum;
      
      // Densidade a 20°C (kg/m³) -> converte para kg/L dividindo por 1000
      final densidade20 = resultado['densidade20'] / 1000;
      final massa = vol20 * densidade20;

      if (mounted) {
        setState(() {
          _grauAlcoolGLCtrl.text = resultado['grauGl'].toStringAsFixed(2).replaceAll('.', ',');
          _fcvCtrl.text = resultado['fcv'].toStringAsFixed(4).replaceAll('.', ',');
          _vol20Ctrl.text = _formatarVolume(vol20).replaceAll(' L', '');
          _massaCtrl.text = _formatarVolume(massa).replaceAll(' L', '');
          _calculandoVolume20 = false;
        });
      }
    } catch (e) {
      print('Erro no cálculo do álcool: $e');
      if (mounted) {
        setState(() {
          _vol20Ctrl.text = '';
          _grauAlcoolGLCtrl.text = '';
          _fcvCtrl.text = '';
          _calculandoVolume20 = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>?> _buscarTabelaAlcool({
    required String temperatura,
    required String densidadeObservada,
  }) async {
    final supabase = Supabase.instance.client;
    
    try {
      // Converte os valores de entrada (vírgula para ponto)
      final tempNum = double.tryParse(temperatura.replaceAll(',', '.')) ?? 0;
      double densNum = double.tryParse(densidadeObservada.replaceAll(',', '.')) ?? 0;
      
      // 🔥 CORREÇÃO: Converte de kg/L para kg/m³ (multiplica por 1000)
      // Se o valor for menor que 10, assume que está em kg/L e converte
      if (densNum < 10) {
        densNum = densNum * 1000;
      }
      
      // Busca todos os registros com a mesma temperatura (com tolerância de 0.1°C)
      final registros = await supabase
          .from('tcv_alcool')
          .select('*')
          .gte('temp_obs', tempNum - 0.1)
          .lte('temp_obs', tempNum + 0.1)
          .order('densid_obs');
      
      if (registros.isEmpty) {
        debugPrint('Tabela Alcoométrica: Nenhum registro para temperatura $tempNum');
        return null;
      }
      
      // Encontra o registro com densidade observada mais próxima
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
      
      if (melhorRegistro == null) return null;

      // Extrai os valores numéricos
      final fcv = (melhorRegistro['fcv'] as num).toDouble();
      final densidade20 = (melhorRegistro['densid_vinte'] as num).toDouble();
      final grauGl = (melhorRegistro['grau_alcol_gl'] as num).toDouble();
      
      return {
        'fcv': fcv,
        'densidade20': densidade20,
        'grauGl': grauGl,
      };
    } catch (e) {
      debugPrint('Erro na busca da tabela alcoométrica: $e');
      return null;
    }
  }

  // ── Funções de cálculo replicadas do cacl.dart ────────────────────────────

  Future<double> _buscarVolumeReal(String cm, String mm) async {
    final supabase = Supabase.instance.client;
    final intCm = int.tryParse(cm) ?? 0;
    final intMm = int.tryParse(mm.isEmpty ? '0' : mm) ?? 0;

    final terminalId = UsuarioAtual.instance?.terminalId ?? '';
    final nomeTabela = (terminalId == '198c2b9b-2708-420e-8992-3b2c9ae3ed6a')
        ? 'arqueacao_janauba'
        : 'arqueacao_jequie';

    final tanqueRef = widget.tanqueReferencia ?? '';
    String numeroTanque = '01';
    if (tanqueRef.isNotEmpty) {
      final numeros = tanqueRef.replaceAll(RegExp(r'[^0-9]'), '');
      if (numeros.isNotEmpty) numeroTanque = numeros.padLeft(2, '0');
    }

    final colunaCm = 'tq_${numeroTanque}_cm';
    final colunaMm = 'tq_${numeroTanque}_mm';

    try {
      final resultadoCm = await supabase
          .from(nomeTabela)
          .select(colunaCm)
          .eq('altura_cm_mm', intCm)
          .maybeSingle();

      if (resultadoCm == null || resultadoCm[colunaCm] == null) return 0;

      final volumeCm = _converterVolumeLitros(resultadoCm[colunaCm]);
      if (intMm == 0) return volumeCm;

      final resultadoMm = await supabase
          .from(nomeTabela)
          .select(colunaMm)
          .eq('altura_cm_mm', intMm)
          .maybeSingle();

      if (resultadoMm == null || resultadoMm[colunaMm] == null) return volumeCm;

      final volumeMm = _converterVolumeLitros(resultadoMm[colunaMm]);
      return double.parse((volumeCm + volumeMm).toStringAsFixed(3));
    } catch (_) {
      return 0;
    }
  }

  double _converterVolumeLitros(dynamic valor) {
    try {
      if (valor == null) return 0.0;
      String str = valor.toString().trim().replaceAll(',', '.');
      if (str.contains('.')) {
        final partes = str.split('.');
        if (partes.length == 2) {
          String parteDecimal = partes[1].padRight(3, '0');
          return (double.tryParse('${partes[0]}.$parteDecimal') ?? 0.0) * 1000;
        }
      }
      return double.tryParse(str) ?? 0.0;
    } catch (_) {
      return 0.0;
    }
  }

  String _formatarVolume(double volume) {
    final inteiro = volume.round();
    String str = inteiro.toString();
    if (str.length > 3) {
      final buf = StringBuffer();
      int contador = 0;
      for (int i = str.length - 1; i >= 0; i--) {
        buf.write(str[i]);
        contador++;
        if (contador == 3 && i > 0) {
          buf.write('.');
          contador = 0;
        }
      }
      str = buf.toString().split('').reversed.join('');
    }
    return '$str L';
  }

  Widget _buildField(
    String label,
    String hint, {
    int maxLines = 1,
    int? maxLength,
    TextEditingController? controller,
    FocusNode? focusNode,
    bool enabled = true,
    bool isLoading = false,
    void Function(String, TextEditingController, String)? onChanged,
  }) {
    final effectiveController = controller ?? TextEditingController();
    String valorAntigo = effectiveController.text;

    // Define se o campo é obrigatório
    final isMandatory = [
      'Horário',
      'Alt. cm',
      'Alt. mm',
      'Temp. Tanque',
      'Densid. Obs.',
    ].contains(label);

    // Validação básica: se for obrigatório e estiver vazio, exibe alerta
    final bool showWarning = isMandatory && effectiveController.text.trim().isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: showWarning ? Colors.red.shade700 : Colors.black87,
              ),
            ),
            if (isLoading) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        TextField(
          controller: effectiveController,
          textAlign: TextAlign.center,
          focusNode: focusNode,
          maxLines: maxLines,
          maxLength: maxLength,
          enabled: enabled,
          onChanged: (v) {
            setState(() {});

            if (onChanged != null) {
              onChanged(v, effectiveController, valorAntigo);
              valorAntigo = effectiveController.text;
            } else {
              valorAntigo = v;
            }
          },
          keyboardType: maxLength != null ||
                  label.contains('Temp') ||
                  label.contains('Dens') ||
                  label.contains('Alt') ||
                  label.contains('Vol') ||
                  label.contains('Grau') ||
                  label.contains('FCV') ||
                  label.contains('Massa') ||
                  label.contains('Água')
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(
                color: showWarning ? Colors.red : Colors.grey,
                width: showWarning ? 1.5 : 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(
                color: showWarning ? Colors.red : Colors.grey,
                width: showWarning ? 1.5 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(
                color: showWarning ? Colors.red : const Color(0xFF0D47A1),
                width: 2,
              ),
            ),
            filled: !enabled,
            fillColor: Colors.grey.shade100,
            isDense: true,
            counterText: '',
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFF0D47A1), width: 1),
      ),
      title: Text(
        'Inserir dados da medição - ${widget.tanqueReferencia ?? ""} - ${widget.produtoNome ?? ""}',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF0D47A1),
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 600,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Primeira linha: Tanque, Data, Horário
              Row(
                children: [
                  Expanded(child: _buildField('Tanque', 'Ex: TQ-01', controller: _tanqueCtrl, enabled: false)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildField('Data', '00/00/0000', controller: _dataCtrl)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildField(
                      'Horário',
                      '00:00 h',
                      controller: _horarioCtrl,
                      onChanged: (v, controller, antigo) {
                        final masked = _aplicarMascaraHorario(v, antigo);
                        if (masked != v) {
                          controller.value = TextEditingValue(
                            text: masked,
                            selection: TextSelection.collapsed(offset: masked.endsWith(' h') && masked.length > 2 ? masked.length - 2 : masked.length),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Segunda linha: Alturas e Volume total
              Row(
                children: [
                  Expanded(child: _buildField('Alt. cm', '0', controller: _cmCtrl, maxLength: 4)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildField('Alt. mm', '0', controller: _mmCtrl, maxLength: 1)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildField(
                      'Vol. total ocupado',
                      '0',
                      controller: _volCalcCtrl,
                      maxLength: 10,
                      enabled: false,
                      isLoading: _calculandoVolume,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Terceira linha: Água
              Row(
                children: [
                  Expanded(child: _buildField('Alt. cm (Água)', '0', controller: _aguaCmCtrl, maxLength: 4)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildField('Alt. mm (Água)', '0', controller: _aguaMmCtrl, maxLength: 1)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildField(
                      'Vol. Calc. de Água',
                      '0',
                      controller: _volAguaCtrl,
                      enabled: false,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Quarta linha: Temperatura, Densidade, Grau Alcóolico e FCV (conforme solicitado)
              Row(
                children: [
                  Expanded(
                    child: _buildField(
                      'Temp. Tanque',
                      '00,0',
                      controller: _tempTanqueCtrl,
                      focusNode: _tempTanqueFocus,
                      onChanged: (v, controller, antigo) {
                        final masked = _aplicarMascaraTemperatura(v, antigo);
                        if (masked != v) {
                          controller.value = TextEditingValue(
                            text: masked,
                            selection: TextSelection.collapsed(offset: masked.length),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildField(
                      'Densid. Obs.',
                      '0,000',
                      controller: _densidadeObsCtrl,
                      focusNode: _densidadeObsFocus,
                      onChanged: (v, controller, antigo) {
                        final masked = _aplicarMascaraDensidade(v, antigo);
                        if (masked != v) {
                          controller.value = TextEditingValue(
                            text: masked,
                            selection: TextSelection.collapsed(offset: masked.length),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildField(
                      'Grau Alcoo. GL',
                      '0,00',
                      controller: _grauAlcoolGLCtrl,
                      enabled: false,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildField(
                      'FCV',
                      '0,0000',
                      controller: _fcvCtrl,
                      enabled: false,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Quinta linha: Massa, Volume Ambiente, Volume 20°C
              Row(
                children: [
                  Expanded(
                    child: _buildField(
                      'Massa do produto',
                      '0',
                      controller: _massaCtrl,
                      maxLength: 15,
                      enabled: false,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildField(
                      'Vol. amb. (Produto)',
                      '0',
                      controller: _volAmbProdutoCtrl,
                      enabled: false,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildField(
                      'Vol. 20ºC',
                      '0',
                      controller: _vol20Ctrl,
                      maxLength: 15,
                      enabled: false,
                      isLoading: _calculandoVolume20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Sexta linha: Observações
              _buildField('Observações', '', controller: _observacoesCtrl, maxLines: 2),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
        ),
        SizedBox(
          child: ElevatedButton(
            onPressed: _salvarMedicao,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text(
              'Salvar dados',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}