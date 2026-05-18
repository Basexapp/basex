import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_page.dart';

class MedicoesPage extends StatefulWidget {
  final VoidCallback onVoltar;
  final String? produtoNome;
  final String? tanqueReferencia;

  const MedicoesPage({
    super.key,
    required this.onVoltar,
    this.produtoNome,
    this.tanqueReferencia,
  });

  @override
  State<MedicoesPage> createState() => _MedicoesPageState();
}

class _MedicoesPageState extends State<MedicoesPage> {
  int? _hoverIndex;

  // Controllers para o diálogo de inserção
  final TextEditingController _tanqueCtrl = TextEditingController();
  final TextEditingController _dataCtrl = TextEditingController();
  final TextEditingController _horarioCtrl = TextEditingController();
  final TextEditingController _cmCtrl = TextEditingController();
  final TextEditingController _mmCtrl = TextEditingController();
  final TextEditingController _volCalcCtrl = TextEditingController();
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

  // Estados de cálculo
  bool _calculandoVolume = false;
  bool _calculandoVolume20 = false;
  double _volumeAmbienteRaw = 0;

  // Debouncers
  Timer? _debounceVolume;
  Timer? _debounceVolume20;

  @override
  void initState() {
    super.initState();
    _cmCtrl.addListener(_onAlturaChanged);
    _mmCtrl.addListener(_onAlturaChanged);
    _aguaCmCtrl.addListener(_onAlturaAguaChanged);
    _aguaMmCtrl.addListener(_onAlturaAguaChanged);
    
    // Adiciona listeners para perda de foco
    _tempTanqueFocus.addListener(_onFocusChanged);
    _densidadeObsFocus.addListener(_onFocusChanged);
    _tempObsFocus.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    // Se nenhum dos campos de entrada de cálculo 20C tem o foco, força o cálculo
    if (!_tempTanqueFocus.hasFocus && !_densidadeObsFocus.hasFocus && !_tempObsFocus.hasFocus) {
      _calcularVolume20();
    }
  }

  @override
  void dispose() {
    _debounceVolume?.cancel();
    _debounceVolume20?.cancel();
    _tempTanqueFocus.dispose();
    _densidadeObsFocus.dispose();
    _tempObsFocus.dispose();
    _tanqueCtrl.dispose();
    _dataCtrl.dispose();
    _horarioCtrl.dispose();
    _cmCtrl.dispose();
    _mmCtrl.dispose();
    _volCalcCtrl.dispose();
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
          _volumeAmbienteRaw = 0;
          _vol20Ctrl.text = '';
        });
      }
      return;
    }

    if (mounted) setState(() => _calculandoVolume = true);

    try {
      final mm = _mmCtrl.text.trim();
      final volume = await _buscarVolumeReal(cm, mm);
      
      _volumeAmbienteRaw = volume;
      _volCalcCtrl.text = volume > 0 ? _formatarVolume(volume).replaceAll(' L', '') : '';
      
      if (mounted) setState(() => _calculandoVolume = false);
      
      if (volume > 0) _calcularVolume20();
    } catch (_) {
      if (mounted) {
        setState(() {
          _volCalcCtrl.text = '';
          _volumeAmbienteRaw = 0;
          _calculandoVolume = false;
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
        });
      }
      return;
    }

    if (mounted) setState(() => _calculandoVolume = true);

    try {
      final mm = _aguaMmCtrl.text.trim();
      final volume = await _buscarVolumeReal(cm, mm);
      
      _volAguaCtrl.text = volume > 0 ? _formatarVolume(volume).replaceAll(' L', '') : '';
      
      if (mounted) setState(() => _calculandoVolume = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _volAguaCtrl.text = '';
          _calculandoVolume = false;
        });
      }
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

    final volAmb = _volumeAmbienteRaw;
    if (volAmb <= 0) {
      if (mounted) setState(() => _vol20Ctrl.text = '');
      return;
    }

    final produtoNome = widget.produtoNome ?? '';

    if (mounted) setState(() => _calculandoVolume20 = true);

    try {
      final dens20 = await _buscarDensidade20C(
        temperaturaAmostra: tempAmostra,
        densidadeObservada: densObs,
        produtoNome: produtoNome,
      );

      if (dens20 == '-') {
        if (mounted) {
          setState(() {
            _vol20Ctrl.text = '';
            _densidade20Ctrl.text = '';
            _fcvCtrl.text = '';
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

  Future<String> _buscarDensidade20C({
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
        return '-';
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
        return '-';
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
        return '-';
      }

      int? melhorDelta;
      dynamic melhorValor;
      for (final entry in linha.entries) {
        if (!entry.key.startsWith('d_')) continue;
        final cod = int.tryParse(entry.key.replaceFirst('d_', ''));
        if (cod == null) continue;
        final valor = entry.value;
        if (valor == null || valor.toString().trim().isEmpty) continue;
        final delta = (cod - alvo).abs();
        if (melhorDelta == null || delta < melhorDelta) {
          melhorDelta = delta;
          melhorValor = valor;
        }
      }
      
      if (melhorValor == null) {
        print('DEBUG DENS20: Nenhum valor de coluna d_XXX encontrado na linha.');
        return '-';
      }

      print('DEBUG DENS20: Melhor valor encontrado: $melhorValor (delta: $melhorDelta)');
      String valorFinal = melhorValor.toString().trim().replaceAll('.', ',');
      if (!valorFinal.contains(',')) valorFinal = '$valorFinal,0';
      final partes = valorFinal.split(',');
      String parteDecimal = (partes.length > 1 ? partes[1] : '0').padRight(4, '0').substring(0, 4);
      return '${partes[0]},$parteDecimal';
    } catch (_) {
      return '-';
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

  void _abrirDialogOInserirMedicao() {
    _tanqueCtrl.text = widget.tanqueReferencia ?? '';
    _dataCtrl.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
    _horarioCtrl.clear();
    _cmCtrl.clear();
    _mmCtrl.clear();
    _volCalcCtrl.clear();
    _tempTanqueCtrl.clear();
    _densidadeObsCtrl.clear();
    _tempObsCtrl.clear();
    _densidade20Ctrl.clear();
    _fcvCtrl.clear();
    _aguaCmCtrl.clear();
    _aguaMmCtrl.clear();
    _volAguaCtrl.clear();
    _massaCtrl.clear();
    _vol20Ctrl.clear();
    _observacoesCtrl.clear();
    
    _volumeAmbienteRaw = 0;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFF0D47A1), width: 1),
        ),
        title: const Text(
          'Inserir dados da medição',
          style: TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.bold),
        ),
        content: StatefulBuilder(
          builder: (context, setStateDialog) => SingleChildScrollView(
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
                      Expanded(child: _buildField('Alt. cm (Produto)', '0', controller: _cmCtrl, maxLength: 4)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildField('Alt. mm (Produto)', '0', controller: _mmCtrl, maxLength: 1)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildField(
                          'Volume Calculado',
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
                          maxLength: 6,
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          SizedBox(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
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
      ),
    );
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
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
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
            if (onChanged != null) {
              onChanged(v, effectiveController, valorAntigo);
              valorAntigo = effectiveController.text;
            } else {
              valorAntigo = v;
            }
          },
          keyboardType: maxLength != null || label.contains('Temp') || label.contains('Dens') || label.contains('Alt') || label.contains('Vol') || label.contains('FCD') || label.contains('FCV') || label.contains('Massa') || label.contains('Água') ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
            filled: !enabled,
            fillColor: Colors.grey.shade100,
            isDense: true,
            counterText: '',
          ),
        ),
      ],
    );
  }

  // Dados fictícios para teste de layout
  final List<Map<String, dynamic>> _medicoesFicticias = [
    {
      'tanque': 'TQ-01',
      'data': '15/05/2026',
      'horario': '08:00 h',
      'altura_cm': '500',
      'altura_mm': '5',
      'volume_amb': '50.000',
      'temp_tanque': '25,5',
      'densidade': '0,850',
      'temp_amostra': '24,0',
      'fcd': '1,0002',
      'fcv': '0,9970',
      'volume_20': '49.850',
      'massa': '42.372',
    },
    {
      'tanque': 'TQ-02',
      'data': '15/05/2026',
      'horario': '09:30 h',
      'altura_cm': '320',
      'altura_mm': '2',
      'volume_amb': '32.000',
      'temp_tanque': '26,0',
      'densidade': '0,845',
      'temp_amostra': '25,0',
      'fcd': '1,0001',
      'fcv': '0,9950',
      'volume_20': '31.840',
      'massa': '26.905',
    },
    {
      'tanque': 'TQ-03',
      'data': '14/05/2026',
      'horario': '14:15 h',
      'altura_cm': '450',
      'altura_mm': '0',
      'volume_amb': '45.000',
      'temp_tanque': '24,8',
      'densidade': '0,852',
      'temp_amostra': '24,5',
      'fcd': '1,0003',
      'fcv': '0,9980',
      'volume_20': '44.910',
      'massa': '38.263',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15.0),
        child: Column(
          children: [
            // Cabeçalho similar ao HistoricoCaclPage
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(0, 8, 16, 8),
              decoration: const BoxDecoration(
                color: Color(0xFFF8F9FA),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
                    onPressed: widget.onVoltar,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.produtoNome != null 
                              ? 'Medições - ${widget.produtoNome}'
                              : 'Medições',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                        const Text(
                          'Lista de todas as medições realizadas',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Cabeçalho da Tabela
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Container(width: 4), // Espaço para barra colorida
                  const SizedBox(width: 12),
                  _buildHeaderCell('Tanque', flex: 2),
                  _buildHeaderCell('Data', flex: 2),
                  _buildHeaderCell('Horário', flex: 2),
                  _buildHeaderCell('Alt. cm', flex: 2),
                  _buildHeaderCell('Alt. mm', flex: 2),
                  _buildHeaderCell('Vol. Amb', flex: 3),
                  _buildHeaderCell('Temp. Tq', flex: 2),
                  _buildHeaderCell('Dens. Obs', flex: 2),
                  _buildHeaderCell('Temp. Obs', flex: 2),
                  _buildHeaderCell('FCD', flex: 2),
                  _buildHeaderCell('FCV', flex: 2),
                  _buildHeaderCell('Massa', flex: 3),
                  _buildHeaderCell('Vol. 20°C', flex: 3),
                  const SizedBox(width: 24), // Espaço para o ícone
                ],
              ),
            ),

            const Divider(height: 1),

            // Lista de Medições
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: _medicoesFicticias.length,
                itemBuilder: (context, index) {
                  final medicao = _medicoesFicticias[index];
                  return MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) => setState(() => _hoverIndex = index),
                    onExit: (_) => setState(() => _hoverIndex = null),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      color: _hoverIndex == index 
                          ? Colors.grey.shade200 
                          : (index.isEven ? Colors.white : Colors.grey.shade50),
                      child: Row(
                        children: [
                          // Indicador de status (decorativo)
                          Container(
                            width: 4,
                            height: 24,
                            color: const Color(0xFF0D47A1).withOpacity(0.5),
                          ),
                          const SizedBox(width: 12),
                          
                          _buildDataCell(medicao['tanque'], flex: 2),
                          _buildDataCell(medicao['data'], flex: 2),
                          _buildDataCell(medicao['horario'], flex: 2),
                          _buildDataCell(medicao['altura_cm'], flex: 2),
                          _buildDataCell(medicao['altura_mm'], flex: 2),
                          _buildDataCell(medicao['volume_amb'], flex: 3),
                          _buildDataCell(medicao['temp_tanque'], flex: 2),
                          _buildDataCell(medicao['densidade'], flex: 2),
                          _buildDataCell(medicao['temp_amostra'], flex: 2),
                          _buildDataCell(medicao['fcd'], flex: 2),
                          _buildDataCell(medicao['fcv'], flex: 2),
                          _buildDataCell(medicao['massa'], flex: 3),
                          _buildDataCell(medicao['volume_20'], flex: 3),
                          
                          const SizedBox(width: 24), // Espaço para manter alinhamento
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _abrirDialogOInserirMedicao,
        backgroundColor: const Color(0xFF0D47A1),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildHeaderCell(String label, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildDataCell(String? value, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        value ?? '-',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
