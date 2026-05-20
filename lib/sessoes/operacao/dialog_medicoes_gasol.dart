import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_page.dart';

class DialogMedicoesGasol extends StatefulWidget {
  final String? produtoNome;
  final String? tanqueReferencia;
  final String? data;
  final String? horario;
  final Function(Map<String, dynamic>)? onSaved;

  const DialogMedicoesGasol({
    super.key,
    this.produtoNome,
    this.tanqueReferencia,
    this.data,
    this.horario,
    this.onSaved,
  });

  @override
  State<DialogMedicoesGasol> createState() => _DialogMedicoesGasolState();
}

class _DialogMedicoesGasolState extends State<DialogMedicoesGasol> {
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
  final TextEditingController _densidade20Ctrl = TextEditingController();
  final TextEditingController _tempObsCtrl = TextEditingController();
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
  final FocusNode _tempObsFocus = FocusNode();
  final FocusNode _cmFocus = FocusNode();
  final FocusNode _mmFocus = FocusNode();
  final FocusNode _aguaCmFocus = FocusNode();
  final FocusNode _aguaMmFocus = FocusNode();

  // Estados de cálculo
  bool _calculandoVolume = false;
  bool _calculandoVolume20 = false;
  double _volumeTotalRaw = 0;
  double _volumeAguaRaw = 0;

  // Debouncers
  Timer? _debounceVolumeAmbiente;
  Timer? _debounceVolumeAgua;
  Timer? _debounceVolume20;

  @override
  void initState() {
    super.initState();
    _tanqueCtrl.text = widget.tanqueReferencia ?? '';
    _dataCtrl.text = widget.data ?? DateFormat('dd/MM/yyyy').format(DateTime.now());
    if (widget.horario != null) {
      _horarioCtrl.text = widget.horario!.contains('h') ? widget.horario! : '${widget.horario!} h';
    }

    _cmCtrl.addListener(_onAlturaChanged);
    _mmCtrl.addListener(_onAlturaChanged);
    _aguaCmCtrl.addListener(_onAlturaAguaChanged);
    _aguaMmCtrl.addListener(_onAlturaAguaChanged);

    // Adiciona listeners para perda de foco
    _tempTanqueFocus.addListener(_onFocusChanged);
    _densidadeObsFocus.addListener(_onFocusChanged);
    _tempObsFocus.addListener(_onFocusChanged);
    _cmFocus.addListener(_onHeightFocusChanged);
    _mmFocus.addListener(_onHeightFocusChanged);
    _aguaCmFocus.addListener(_onAguaHeightFocusChanged);
    _aguaMmFocus.addListener(_onAguaHeightFocusChanged);
  }

  void _onFocusChanged() {
    // Se nenhum dos campos de entrada de cálculo 20C tem o foco, força o cálculo
    if (!_tempTanqueFocus.hasFocus && !_densidadeObsFocus.hasFocus && !_tempObsFocus.hasFocus) {
      _calcularVolume20();
    }
  }

  void _onHeightFocusChanged() {
    // Se perdeu o foco do bloco de alturas, força o cálculo imediato
    if (!_cmFocus.hasFocus && !_mmFocus.hasFocus) {
      _debounceVolumeAmbiente?.cancel();
      _calcularVolumeAmbiente();
    }
  }

  void _onAguaHeightFocusChanged() {
    // Se perdeu o foco do bloco de alturas de água, força o cálculo imediato
    if (!_aguaCmFocus.hasFocus && !_aguaMmFocus.hasFocus) {
      _debounceVolumeAgua?.cancel();
      _calcularVolumeAgua();
    }
  }

  @override
  void dispose() {
    _debounceVolumeAmbiente?.cancel();
    _debounceVolumeAgua?.cancel();
    _debounceVolume20?.cancel();
    _tempTanqueFocus.dispose();
    _densidadeObsFocus.dispose();
    _tempObsFocus.dispose();
    _cmFocus.dispose();
    _mmFocus.dispose();
    _aguaCmFocus.dispose();
    _aguaMmFocus.dispose();
    _tanqueCtrl.dispose();
    _dataCtrl.dispose();
    _horarioCtrl.dispose();
    _cmCtrl.dispose();
    _mmCtrl.dispose();
    _volCalcCtrl.dispose();
    _volAmbProdutoCtrl.dispose();
    _tempTanqueCtrl.dispose();
    _densidadeObsCtrl.dispose();
    _tempObsCtrl.dispose();
    _densidade20Ctrl.dispose();
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
    _debounceVolumeAmbiente?.cancel();
    _debounceVolumeAmbiente = Timer(const Duration(milliseconds: 600), () {
      _calcularVolumeAmbiente();
    });
    // Se ambos os campos têm valor, tenta calcular imediatamente em background
    if (_cmCtrl.text.isNotEmpty && _mmCtrl.text.isNotEmpty) {
      _calcularVolumeAmbiente();
    }
  }

  void _onAlturaAguaChanged() {
    _debounceVolumeAgua?.cancel();
    _debounceVolumeAgua = Timer(const Duration(milliseconds: 600), () {
      _calcularVolumeAgua();
    });
    // Se ambos os campos têm valor, tenta calcular imediatamente em background
    if (_aguaCmCtrl.text.isNotEmpty && _aguaMmCtrl.text.isNotEmpty) {
      _calcularVolumeAgua();
    }
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
    if (_horarioCtrl.text.isEmpty || _cmCtrl.text.isEmpty || _tempTanqueCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, preencha os campos obrigatórios.'), backgroundColor: Colors.red),
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
        'temperatura_amostra': _parseNumero(_tempObsCtrl.text),
        'densidade_20': _parseNumero(_densidade20Ctrl.text),
        'fcv': _parseNumero(_fcvCtrl.text),
        'massa': _parseNumero(_massaCtrl.text),
        'volume_20': _parseNumero(_vol20Ctrl.text),
        'volume_ambiente': _parseNumero(_volCalcCtrl.text),
        'observacoes': _observacoesCtrl.text.trim(),
      };

      final savedMedicao = await supabase.from('medicoes').insert(payload).select().single();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Medição salva com sucesso!'), backgroundColor: Colors.green),
        );
        if (widget.onSaved != null) widget.onSaved!(savedMedicao);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar medição: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ── Cálculo do volume a 20ºC ──────────────────────────────────────────────

  Future<void> _calcularVolume20() async {
    final tempTanque = _tempTanqueCtrl.text.trim();
    final densObs = _densidadeObsCtrl.text.trim();
    final tempAmostra = _tempObsCtrl.text.trim();

    if (tempTanque.isEmpty || densObs.isEmpty || tempAmostra.isEmpty) {
      if (mounted) setState(() => _vol20Ctrl.text = '');
      return;
    }

    final volAmb = _volumeTotalRaw - _volumeAguaRaw;
    if (volAmb <= 0) {
      if (mounted) setState(() => _vol20Ctrl.text = '');
      return;
    }

    final produtoNome = widget.produtoNome ?? '';

    if (mounted) setState(() => _calculandoVolume20 = true);

    try {
      final dens20Data = await _buscarDensidade20C(
        temperaturaAmostra: tempAmostra,
        densidadeObservada: densObs,
        produtoNome: produtoNome,
      );

      final dens20 = dens20Data['valor'] ?? '-';

      if (dens20 == '-') {
        if (mounted) {
          setState(() {
            _vol20Ctrl.text = '';
            _densidade20Ctrl.text = '';
            _calculandoVolume20 = false;
          });
        }
        return;
      }

      // ───────────────────────────────────────────────────────────────────────
      // Verificação para suspender cálculo se produtos.tabela_alcool for TRUE
      // ───────────────────────────────────────────────────────────────────────
      final supabase = Supabase.instance.client;
      final prodRes = await supabase
          .from('produtos')
          .select('tabela_alcool')
          .eq('nome', produtoNome)
          .maybeSingle();

      if (prodRes != null && prodRes['tabela_alcool'] == true) {
        print('DEBUG FCV: Produto $produtoNome possui tabela_alcool=TRUE. Suspendendo cálculo.');
        if (mounted) {
          setState(() {
            _fcvCtrl.text = '-';
            _vol20Ctrl.text = '-';
            _massaCtrl.text = '-';
            _calculandoVolume20 = false;
          });
        }
        return;
      }
      // ───────────────────────────────────────────────────────────────────────

      final fcv = await _buscarFCV(
        temperaturaTanque: tempTanque,
        densidade20C: dens20,
        produtoNome: produtoNome,
      );

      if (fcv == '-') {
        if (mounted) {
          setState(() {
            _vol20Ctrl.text = '';
            _fcvCtrl.text = '';
            _calculandoVolume20 = false;
          });
        }
        return;
      }

      final fcvNum = double.tryParse(fcv.replaceAll(',', '.')) ?? 1.0;
      final vol20 = volAmb * fcvNum;

      final dens20Num = double.tryParse(dens20.replaceAll(',', '.')) ?? 0;
      final massa = vol20 * dens20Num;

      if (mounted) {
        setState(() {
          _fcvCtrl.text = fcv;
          _densidade20Ctrl.text = dens20;
          _vol20Ctrl.text = _formatarVolume(vol20).replaceAll(' L', '');
          _massaCtrl.text = _formatarVolume(massa).replaceAll(' L', '');
          _calculandoVolume20 = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _vol20Ctrl.text = '';
          _calculandoVolume20 = false;
        });
      }
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

  Future<Map<String, String>> _buscarDensidade20C({
    required String temperaturaAmostra,
    required String densidadeObservada,
    required String produtoNome,
  }) async {
    print('DEBUG DENS20: Iniciando busca de Densidade a 20°C');
    print('DEBUG DENS20: Entradas -> tempAmostra: $temperaturaAmostra, densObs: $densidadeObservada, produto: $produtoNome');

    final supabase = Supabase.instance.client;
    try {
      if (temperaturaAmostra.isEmpty || densidadeObservada.isEmpty) {
        print('DEBUG DENS20: Parâmetros vazios.');
        return {'valor': '-', 'fcd': '-'};
      }

      final tempNum = double.tryParse(
        temperaturaAmostra
            .replaceAll(' ºC', '')
            .replaceAll('°C', '')
            .replaceAll('ºC', '')
            .replaceAll(',', '.')
            .trim(),
      );
      final densNum = double.tryParse(densidadeObservada.replaceAll(',', '.').trim());

      if (tempNum == null || densNum == null) {
        print('DEBUG DENS20: Falha ao converter valores para double.');
        return {'valor': '-', 'fcd': '-'};
      }

      final int alvo = (densNum * 1000).round();
      print('DEBUG DENS20: Alvo calculado (densObs * 1000): $alvo');

      final temperaturasTeste = <String>{
        tempNum.toStringAsFixed(0).replaceAll('.', ','),
        tempNum.toStringAsFixed(1).replaceAll('.', ','),
        tempNum.toStringAsFixed(2).replaceAll('.', ','),
        tempNum.toStringAsFixed(0),
        tempNum.toStringAsFixed(1),
      }.toList();

      print('DEBUG DENS20: Temperaturas para tentar no banco: $temperaturasTeste');

      Map<String, dynamic>? linha;
      for (final t in temperaturasTeste) {
        print('DEBUG DENS20: Consultando tcd_gasolina_diesel para temperatura_obs = $t');
        linha = await supabase.from('tcd_gasolina_diesel').select('*').eq('temperatura_obs', t).maybeSingle();
        if (linha != null) {
          print('DEBUG DENS20: Linha encontrada para temp $t');
          break;
        }
      }

      if (linha == null) {
        print('DEBUG DENS20: Nenhuma linha encontrada para as temperaturas testadas.');
        return {'valor': '-', 'fcd': '-'};
      }

      int? melhorDelta;
      dynamic melhorValor;
      String? melhorColuna;
      for (final entry in linha.entries) {
        if (!entry.key.startsWith('d_')) continue;
        final cod = int.tryParse(entry.key.replaceFirst('d_', ''));
        if (cod == null) continue;
        final valor = entry.value;
        if (valor == null || valor.toString().trim().isEmpty) continue;
        final delta = (cod - alvo).abs();
        if (melhorDelta == null || delta < melhorDelta) {
          melhorDelta = delta;
          melhorColuna = entry.key;
          melhorValor = valor;
        }
      }

      if (melhorValor == null) {
        print('DEBUG DENS20: Nenhum valor de coluna d_XXX encontrado na linha.');
        return {'valor': '-', 'fcd': '-'};
      }

      print('DEBUG DENS20: Melhor valor encontrado: $melhorValor (delta: $melhorDelta)');
      String valorFinal = melhorValor.toString().trim().replaceAll('.', ',');
      if (!valorFinal.contains(',')) valorFinal = '$valorFinal,0';
      final partes = valorFinal.split(',');
      String parteDecimal = (partes.length > 1 ? partes[1] : '0').padRight(4, '0').substring(0, 4);

      String fcdValue = '-';
      if (melhorColuna != null) {
        final fcdNumStr = melhorColuna.replaceFirst('d_', '');
        fcdValue = '0,$fcdNumStr';
      }

      return {'valor': '${partes[0]},$parteDecimal', 'fcd': fcdValue};
    } catch (_) {
      return {'valor': '-', 'fcd': '-'};
    }
  }

  Future<String> _buscarFCV({
    required String temperaturaTanque,
    required String densidade20C,
    required String produtoNome,
  }) async {
    print('DEBUG FCV: Iniciando busca de FCV');
    print('DEBUG FCV: Entradas -> tempTanque: $temperaturaTanque, dens20C: $densidade20C, produto: $produtoNome');

    final supabase = Supabase.instance.client;
    try {
      if (temperaturaTanque.isEmpty || temperaturaTanque == '-' ||
          densidade20C.isEmpty || densidade20C == '-') {
        print('DEBUG FCV: Parâmetros vazios ou "-" detectados.');
        return '-';
      }

      final nomeProdutoLower = produtoNome.toLowerCase().trim();
      final nomeView = (nomeProdutoLower.contains('anidro') || nomeProdutoLower.contains('hidratado'))
          ? 'tcv_anidro_hidratado_vw'
          : 'tcv_gasolina_diesel';

      print('DEBUG FCV: Tabela/View utilizada: $nomeView');

      String temperaturaFormatada = temperaturaTanque
          .replaceAll(' ºC', '')
          .replaceAll('°C', '')
          .replaceAll('ºC', '')
          .replaceAll('°', '')
          .replaceAll('C', '')
          .trim()
          .replaceAll('.', ',');

      String densidadeFormatada = densidade20C
          .replaceAll(' ', '')
          .replaceAll('°C', '')
          .replaceAll('ºC', '')
          .replaceAll('°', '')
          .trim()
          .replaceAll('.', ',');

      print('DEBUG FCV: Formatados -> temp: $temperaturaFormatada, dens: $densidadeFormatada');

      final densidadeNum = double.tryParse(densidadeFormatada.replaceAll(',', '.'));
      const double densidadeLimite = 0.8780;
      if (densidadeNum != null && densidadeNum > densidadeLimite) {
        print('DEBUG FCV: Densidade $densidadeNum > $densidadeLimite, limitando para 0,8780');
        densidadeFormatada = '0,8780';
      }
      if (!densidadeFormatada.contains(',')) {
        print('DEBUG FCV: Erro - Densidade formatada não possui vírgula.');
        return '-';
      }

      final partes = densidadeFormatada.split(',');
      String parteInteira = partes[0];
      String parteDecimal = partes[1].padRight(4, '0');
      parteDecimal = '${parteDecimal.substring(0, 3)}0';
      final codigoBase = '$parteInteira$parteDecimal'.padLeft(5, '0');
      final colunaExata = 'v_$codigoBase';
      final prefixo = 'v_${codigoBase.substring(0, 4)}';

      print('DEBUG FCV: Alvos -> colunaExata: $colunaExata, prefixo: $prefixo');

      int? codigoFcvAlvo() {
        final cod = colunaExata.replaceFirst('v_', '');
        return int.tryParse(cod);
      }

      Map<String, dynamic>? valorMaisProximo(Map<String, dynamic> linha) {
        final alvo = codigoFcvAlvo();
        if (alvo == null) return null;
        int? melhorDelta;
        String? melhorColuna;
        dynamic melhorValor;
        for (final entry in linha.entries) {
          final key = entry.key;
          if (!key.startsWith('v_')) continue;
          final cod = int.tryParse(key.substring(2));
          if (cod == null) continue;
          final valor = entry.value;
          if (valor == null) continue;
          if (valor is String) {
            final limpo = valor.trim();
            if (limpo.isEmpty || limpo == '-' || limpo.toLowerCase() == 'null') continue;
          }
          final delta = (cod - alvo).abs();
          if (melhorDelta == null || delta < melhorDelta) {
            melhorDelta = delta;
            melhorColuna = key;
            melhorValor = valor;
          }
        }
        if (melhorColuna == null || melhorValor == null) return null;
        print('DEBUG FCV: Mais próximo -> Coluna: $melhorColuna, Delta: $melhorDelta');
        return {'coluna': melhorColuna, 'valor': melhorValor};
      }

      bool colunaInexistente = false;
      try {
        print('DEBUG FCV: Tentativa 1 (Exata) -> Tqv: $nomeView, Col: $colunaExata, Temp: $temperaturaFormatada');
        final r1 = await supabase
            .from(nomeView)
            .select(colunaExata)
            .eq('temperatura_obs', temperaturaFormatada)
            .maybeSingle();
        if (r1 != null && r1[colunaExata] != null) {
          print('DEBUG FCV: Sucesso na busca exata: ${r1[colunaExata]}');
          return _formatarResultadoFCV(r1[colunaExata].toString());
        }
      } catch (e) {
        print('DEBUG FCV: Exceção na busca exata: $e');
        final msg = e.toString().toLowerCase();
        if (msg.contains('does not exist') || msg.contains('42703')) {
          colunaInexistente = true;
        }
      }

      if (colunaInexistente) {
        print('DEBUG FCV: Tentativa 2 (Proximidade) em $nomeView para temp $temperaturaFormatada');
        final linha = await supabase
            .from(nomeView)
            .select('*')
            .eq('temperatura_obs', temperaturaFormatada)
            .limit(1)
            .maybeSingle();
        if (linha != null) {
          final escolha = valorMaisProximo(linha);
          if (escolha != null) {
            print('DEBUG FCV: Sucesso na busca por proximidade: ${escolha['valor']}');
            return _formatarResultadoFCV(escolha['valor'].toString());
          }
        }
      }

      print('DEBUG FCV: Tentativa 3 (Prefixo) -> prefixo: $prefixo');
      final linha = await supabase
          .from(nomeView)
          .select('*')
          .eq('temperatura_obs', temperaturaFormatada)
          .limit(1)
          .maybeSingle();
      if (linha != null) {
        final colunasEncontradas = linha.keys.where((k) => k.startsWith(prefixo)).toList();
        if (colunasEncontradas.isNotEmpty) {
          print('DEBUG FCV: Sucesso por prefixo (${colunasEncontradas.first}): ${linha[colunasEncontradas.first]}');
          return _formatarResultadoFCV(linha[colunasEncontradas.first].toString());
        }
      }

      print('DEBUG FCV: Tentativa 4 (Ajustes de Temperatura)');
      List<String> temperaturasParaTentar = [];
      if (temperaturaFormatada.contains(',')) {
        final p = temperaturaFormatada.split(',');
        temperaturasParaTentar.addAll([
          '${p[0]},${p[1]}',
          '${p[0]},${p[1]}0',
          '${p[0]},0${p[1]}',
          '${p[0]}',
        ]);
      } else {
        temperaturasParaTentar.addAll([
          '$temperaturaFormatada,0',
          '$temperaturaFormatada,00',
          temperaturaFormatada,
        ]);
      }
      final comPonto = temperaturasParaTentar.map((t) => t.replaceAll(',', '.')).toList();
      temperaturasParaTentar = <String>{...temperaturasParaTentar, ...comPonto}.toList();

      for (final temp in temperaturasParaTentar) {
        print('DEBUG FCV: Tentando variação temp: $temp');
        final linhaFb = await supabase
            .from(nomeView)
            .select('*')
            .eq('temperatura_obs', temp)
            .limit(1)
            .maybeSingle();
        if (linhaFb == null) continue;
        final cols = linhaFb.keys.where((k) => k.startsWith(prefixo)).toList();
        if (cols.isNotEmpty) {
          print('DEBUG FCV: Sucesso em variação -> temp: $temp, col: ${cols.first}, valor: ${linhaFb[cols.first]}');
          return _formatarResultadoFCV(linhaFb[cols.first].toString());
        }
      }

      print('DEBUG FCV: Nenhuma correspondência encontrada.');
      return '-';
    } catch (e) {
      print('DEBUG FCV: Erro crítico: $e');
      return '-';
    }
  }

  String _formatarResultadoFCV(String valorBruto) {
    String valorLimpo = valorBruto.trim().replaceAll('.', ',');
    if (!valorLimpo.contains(',')) valorLimpo = '$valorLimpo,0';
    final partes = valorLimpo.split(',');
    if (partes.length == 2) {
      String parteDecimal = partes[1].padRight(4, '0');
      if (parteDecimal.length > 4) parteDecimal = parteDecimal.substring(0, 4);
      return '${partes[0]},$parteDecimal';
    }
    return valorLimpo;
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
      'Temp. Obs.'
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
                  label.contains('FCD') ||
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
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              Row(
                children: [
                  Expanded(child: _buildField('Alt. cm', '0', controller: _cmCtrl, focusNode: _cmFocus, maxLength: 4)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildField('Alt. mm', '0', controller: _mmCtrl, focusNode: _mmFocus, maxLength: 1)),
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
              Row(
                children: [
                  Expanded(child: _buildField('Alt. cm (Água)', '0', controller: _aguaCmCtrl, focusNode: _aguaCmFocus, maxLength: 4)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildField('Alt. mm (Água)', '0', controller: _aguaMmCtrl, focusNode: _aguaMmFocus, maxLength: 1)),
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
                      'Temp. Obs.',
                      '00,0',
                      controller: _tempObsCtrl,
                      focusNode: _tempObsFocus,
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
                      'Densid. a 20ºC',
                      '0,0000',
                      controller: _densidade20Ctrl,
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
