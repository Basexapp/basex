import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_page.dart';

class CalculadoraArqueacaoPage extends StatefulWidget {
  final VoidCallback? onVoltar;

  const CalculadoraArqueacaoPage({super.key, this.onVoltar});

  @override
  State<CalculadoraArqueacaoPage> createState() =>
      _CalculadoraArqueacaoPageState();
}

class _CalculadoraArqueacaoPageState extends State<CalculadoraArqueacaoPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _abrirDialog();
    });
  }

  Future<void> _abrirDialog() async {
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const _CalculadoraArqueacaoDialog(),
    );
    if (mounted) {
      widget.onVoltar?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      body: SizedBox.shrink(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialog da calculadora
// ─────────────────────────────────────────────────────────────────────────────

class _CalculadoraArqueacaoDialog extends StatefulWidget {
  const _CalculadoraArqueacaoDialog();

  @override
  State<_CalculadoraArqueacaoDialog> createState() =>
      _CalculadoraArqueacaoDialogState();
}

class _CalculadoraArqueacaoDialogState
    extends State<_CalculadoraArqueacaoDialog> {
  // ── Dados dos tanques ──────────────────────────────────────────────────────
  List<Map<String, dynamic>> _tanques = [];
  Map<String, dynamic>? _tanqueSelecionado;
  bool _carregandoTanques = true;

  // ── Controllers ───────────────────────────────────────────────────────────
  final _cmCtrl = TextEditingController();
  final _mmCtrl = TextEditingController();
  final _tempTanqueCtrl = TextEditingController();
  final _densidadeObsCtrl = TextEditingController();
  final _tempAmostraCtrl = TextEditingController();

  // ── Resultados ─────────────────────────────────────────────────────────────
  String _volumeAmbiente = '-';
  double _volumeAmbienteRaw = 0; // ← raw double, evita re-parsear string formatada
  String _volume20 = '-';
  bool _calculandoVolume = false;
  bool _calculandoVolume20 = false;

  // ── Debounce ───────────────────────────────────────────────────────────────
  Timer? _debounceVolume;
  Timer? _debounceVolume20;

  @override
  void initState() {
    super.initState();
    _carregarTanques();

    _cmCtrl.addListener(_onAlturaChanged);
    _mmCtrl.addListener(_onAlturaChanged);
    _tempTanqueCtrl.addListener(_onDadosDensidadeChanged);
    _densidadeObsCtrl.addListener(_onDadosDensidadeChanged);
    _tempAmostraCtrl.addListener(_onDadosDensidadeChanged);
  }

  @override
  void dispose() {
    _debounceVolume?.cancel();
    _debounceVolume20?.cancel();
    _cmCtrl.dispose();
    _mmCtrl.dispose();
    _tempTanqueCtrl.dispose();
    _densidadeObsCtrl.dispose();
    _tempAmostraCtrl.dispose();
    super.dispose();
  }

  // ── Carregamento de tanques ────────────────────────────────────────────────

  Future<void> _carregarTanques() async {
    final usuario = UsuarioAtual.instance;
    final terminalId = usuario?.terminalId;

    if (terminalId == null || terminalId.isEmpty) {
      if (mounted) setState(() => _carregandoTanques = false);
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      final resposta = await supabase
          .from('tanques')
          .select('id, referencia, id_produto, produtos(nome)')
          .eq('terminal_id', terminalId)
          .order('referencia', ascending: true);

      final lista = <Map<String, dynamic>>[];
      for (final t in resposta) {
        lista.add({
          'id': t['id']?.toString() ?? '',
          'referencia': t['referencia']?.toString() ?? '',
          'produto': (t['produtos'] as Map?)?['nome']?.toString() ?? '',
          'id_produto': t['id_produto']?.toString() ?? '',
        });
      }

      if (mounted) {
        setState(() {
          _tanques = lista;
          _carregandoTanques = false;
          if (lista.isNotEmpty) _tanqueSelecionado = lista.first;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _carregandoTanques = false);
    }
  }

  // ── Listeners ──────────────────────────────────────────────────────────────

  void _onAlturaChanged() {
    _debounceVolume?.cancel();
    _debounceVolume = Timer(const Duration(milliseconds: 600), () {
      _calcularVolumeAmbiente();
    });
  }

  void _onDadosDensidadeChanged() {
    _debounceVolume20?.cancel();
    _debounceVolume20 = Timer(const Duration(milliseconds: 600), () {
      _calcularVolume20();
    });
  }

  // ── Cálculo do volume ao ambiente ─────────────────────────────────────────

  Future<void> _calcularVolumeAmbiente() async {
    final cm = _cmCtrl.text.trim();
    if (cm.isEmpty || _tanqueSelecionado == null) {
      if (mounted) {
        setState(() {
          _volumeAmbiente = '-';
          _volumeAmbienteRaw = 0;
          _volume20 = '-';
        });
      }
      return;
    }

    if (mounted) setState(() => _calculandoVolume = true);

    try {
      final mm = _mmCtrl.text.trim();
      final volume = await _buscarVolumeReal(cm, mm);
      if (mounted) {
        setState(() {
          _volumeAmbienteRaw = volume;
          _volumeAmbiente = volume > 0 ? _formatarVolume(volume) : '-';
          _calculandoVolume = false;
        });
        // Se já temos os dados de temperatura/densidade, recalcular a 20ºC
        if (volume > 0) _calcularVolume20();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _volumeAmbiente = '-';
          _volumeAmbienteRaw = 0;
          _calculandoVolume = false;
        });
      }
    }
  }

  // ── Cálculo do volume a 20ºC ──────────────────────────────────────────────

  Future<void> _calcularVolume20() async {
    final tempTanque = _tempTanqueCtrl.text.trim();
    final densObs = _densidadeObsCtrl.text.trim();
    final tempAmostra = _tempAmostraCtrl.text.trim();

    if (tempTanque.isEmpty || densObs.isEmpty || tempAmostra.isEmpty) {
      if (mounted) setState(() => _volume20 = '-');
      return;
    }

    // Usa o double bruto armazenado — sem re-parsear a string formatada
    final volAmb = _volumeAmbienteRaw;
    if (volAmb <= 0) {
      if (mounted) setState(() => _volume20 = '-');
      return;
    }

    final produtoNome = _tanqueSelecionado?['produto']?.toString() ?? '';

    if (mounted) setState(() => _calculandoVolume20 = true);

    try {
      final dens20 = await _buscarDensidade20C(
        temperaturaAmostra: tempAmostra,
        densidadeObservada: densObs,
        produtoNome: produtoNome,
      );

      if (dens20 == '-') {
        if (mounted) setState(() { _volume20 = '-'; _calculandoVolume20 = false; });
        return;
      }

      final fcv = await _buscarFCV(
        temperaturaTanque: tempTanque,
        densidade20C: dens20,
        produtoNome: produtoNome,
      );

      if (fcv == '-') {
        if (mounted) setState(() { _volume20 = '-'; _calculandoVolume20 = false; });
        return;
      }

      final fcvNum = double.tryParse(fcv.replaceAll(',', '.')) ?? 1.0;
      final vol20 = volAmb * fcvNum;

      if (mounted) {
        setState(() {
          _volume20 = _formatarVolume(vol20);
          _calculandoVolume20 = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _volume20 = '-'; _calculandoVolume20 = false; });
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

    final tanqueRef = _tanqueSelecionado?['referencia']?.toString() ?? '';
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
    final supabase = Supabase.instance.client;
    try {
      if (temperaturaAmostra.isEmpty || densidadeObservada.isEmpty) return '-';

      final tempNum = double.tryParse(
        temperaturaAmostra
            .replaceAll(' ºC', '')
            .replaceAll('°C', '')
            .replaceAll('ºC', '')
            .replaceAll(',', '.')
            .trim(),
      );
      final densNum = double.tryParse(densidadeObservada.replaceAll(',', '.').trim());
      if (tempNum == null || densNum == null) return '-';

      final int alvo = (densNum * 1000).round();

      // Idêntico ao cacl.dart: testa 5 formatos de temperatura
      final temperaturasTeste = <String>{
        tempNum.toStringAsFixed(0).replaceAll('.', ','),
        tempNum.toStringAsFixed(1).replaceAll('.', ','),
        tempNum.toStringAsFixed(2).replaceAll('.', ','),
        tempNum.toStringAsFixed(0),
        tempNum.toStringAsFixed(1),
      }.toList();

      Map<String, dynamic>? linha;
      for (final t in temperaturasTeste) {
        linha = await supabase.from('tcd_gasolina_diesel').select('*').eq('temperatura_obs', t).maybeSingle();
        if (linha != null) break;
      }
      if (linha == null) return '-';

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
      if (melhorValor == null) return '-';

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
    final supabase = Supabase.instance.client;
    try {
      if (temperaturaTanque.isEmpty || temperaturaTanque == '-' ||
          densidade20C.isEmpty || densidade20C == '-') return '-';

      final nomeProdutoLower = produtoNome.toLowerCase().trim();
      final nomeView = (nomeProdutoLower.contains('anidro') || nomeProdutoLower.contains('hidratado'))
          ? 'tcv_anidro_hidratado_vw'
          : 'tcv_gasolina_diesel_vw';

      // Mesmo tratamento do cacl.dart
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

      final densidadeNum = double.tryParse(densidadeFormatada.replaceAll(',', '.'));
      const double densidadeLimite = 0.8780;
      if (densidadeNum != null && densidadeNum > densidadeLimite) {
        densidadeFormatada = '0,8780';
      }
      if (!densidadeFormatada.contains(',')) return '-';

      final partes = densidadeFormatada.split(',');
      String parteInteira = partes[0];
      String parteDecimal = partes[1].padRight(4, '0');
      parteDecimal = '${parteDecimal.substring(0, 3)}0';
      final codigoBase = '$parteInteira$parteDecimal'.padLeft(5, '0');
      final colunaExata = 'v_$codigoBase';
      final prefixo = 'v_${codigoBase.substring(0, 4)}';

      // Funções locais idênticas ao cacl.dart
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
        return {'coluna': melhorColuna, 'valor': melhorValor};
      }

      // 1ª tentativa: coluna exata
      bool colunaInexistente = false;
      try {
        final r1 = await supabase
            .from(nomeView)
            .select(colunaExata)
            .eq('temperatura_obs', temperaturaFormatada)
            .maybeSingle();
        if (r1 != null && r1[colunaExata] != null) {
          return _formatarResultadoFCV(r1[colunaExata].toString());
        }
      } catch (e) {
        final msg = e.toString().toLowerCase();
        if (msg.contains('does not exist') || msg.contains('42703')) {
          colunaInexistente = true;
        }
      }

      // 2ª tentativa: se coluna não existe, busca todas e usa a mais próxima
      if (colunaInexistente) {
        final linha = await supabase
            .from(nomeView)
            .select('*')
            .eq('temperatura_obs', temperaturaFormatada)
            .limit(1)
            .maybeSingle();
        if (linha != null) {
          final escolha = valorMaisProximo(linha);
          if (escolha != null) return _formatarResultadoFCV(escolha['valor'].toString());
        }
      }

      // 3ª tentativa: linha completa + prefixo
      final linha = await supabase
          .from(nomeView)
          .select('*')
          .eq('temperatura_obs', temperaturaFormatada)
          .limit(1)
          .maybeSingle();
      if (linha != null) {
        final colunasEncontradas = linha.keys.where((k) => k.startsWith(prefixo)).toList();
        if (colunasEncontradas.isNotEmpty) {
          return _formatarResultadoFCV(linha[colunasEncontradas.first].toString());
        }
      }

      // 4ª tentativa: variantes de temperatura (idêntico ao cacl.dart)
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
        final linhaFb = await supabase
            .from(nomeView)
            .select('*')
            .eq('temperatura_obs', temp)
            .limit(1)
            .maybeSingle();
        if (linhaFb == null) continue;
        final cols = linhaFb.keys.where((k) => k.startsWith(prefixo)).toList();
        if (cols.isNotEmpty) {
          return _formatarResultadoFCV(linhaFb[cols.first].toString());
        }
      }

      return '-';
    } catch (_) {
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
        if (contador == 3 && i > 0) { buf.write('.'); contador = 0; }
      }
      str = buf.toString().split('').reversed.join('');
    }
    return '$str L';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
      child: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cabeçalho
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1565C0),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.calculate_outlined, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Calculadora de Arqueação',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close, color: Colors.white70, size: 18),
                    ),
                  ),
                ],
              ),
            ),

            // Corpo com scroll
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Seleção de tanque ──────────────────────────────────
                  _labelField('Tanque'),
                  const SizedBox(height: 4),
                  _carregandoTanques
                      ? const SizedBox(
                          height: 38,
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : _tanques.isEmpty
                          ? Container(
                              height: 38,
                              alignment: Alignment.center,
                              decoration: _boxDecoration(),
                              child: const Text('Nenhum tanque disponível',
                                  style: TextStyle(color: Colors.grey, fontSize: 13)),
                            )
                          : DropdownButtonFormField<Map<String, dynamic>>(
                              value: _tanqueSelecionado,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Color(0xFFBDBDBD)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Color(0xFFBDBDBD)),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              items: _tanques.map((t) {
                                return DropdownMenuItem(
                                  value: t,
                                  child: Text(
                                    '${t['referencia']}${t['produto'].isNotEmpty ? ' — ${t['produto']}' : ''}',
                                    style: const TextStyle(fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  _tanqueSelecionado = val;
                                  _volumeAmbiente = '-';
                                  _volumeAmbienteRaw = 0;
                                  _volume20 = '-';
                                });
                                _onAlturaChanged();
                              },
                            ),

                  const SizedBox(height: 12),
                  _divider('Medição de Altura'),
                  const SizedBox(height: 8),

                  // ── Altura cm / mm ─────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _labelField('Altura (cm)'),
                            const SizedBox(height: 4),
                            _buildIntField(_cmCtrl, 'Ex: 280', maxLength: 3),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 80,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _labelField('mm'),
                            const SizedBox(height: 4),
                            _buildIntField(_mmCtrl, '0–9', maxLength: 1),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // ── Resultado: volume ambiente ─────────────────────────
                  _labelField('Volume (temp. ambiente)'),
                  const SizedBox(height: 4),
                  _buildResultField(_volumeAmbiente, _calculandoVolume),

                  const SizedBox(height: 12),
                  _divider('Correção a 20 ºC'),
                  const SizedBox(height: 8),

                  // ── Temp. tanque / Densidade Obs. ──────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _labelField('Temp. Tanque (ºC)'),
                            const SizedBox(height: 4),
                            _buildTemperatureField(_tempTanqueCtrl, 'Ex: 28'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _labelField('Dens. Obs.'),
                            const SizedBox(height: 4),
                            _buildDensidadeField(_densidadeObsCtrl, '0,0000'),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // ── Temp. amostra ──────────────────────────────────────
                  _labelField('Temp. Amostra (ºC)'),
                  const SizedBox(height: 4),
                  _buildTemperatureField(_tempAmostraCtrl, 'Ex: 30'),

                  const SizedBox(height: 12),

                  // ── Resultado: volume a 20ºC ───────────────────────────
                  _labelField('Volume a 20 ºC'),
                  const SizedBox(height: 4),
                  _buildResultField(_volume20, _calculandoVolume20, isHighlighted: true),

                  const SizedBox(height: 4),
                ],
              ),
            ),

            // Rodapé
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF5F5F5),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                border: Border(top: BorderSide(color: Color(0xFFE0E0E0))),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _limpar,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                    ),
                    child: const Text('Limpar', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('Fechar'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _limpar() {
    _cmCtrl.clear();
    _mmCtrl.clear();
    _tempTanqueCtrl.clear();
    _densidadeObsCtrl.clear();
    _tempAmostraCtrl.clear();
    setState(() {
      _volumeAmbiente = '-';
      _volumeAmbienteRaw = 0;
      _volume20 = '-';
    });
  }

  // ── Widgets auxiliares ────────────────────────────────────────────────────

  Widget _labelField(String texto) => Text(
        texto,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF424242)),
      );

  Widget _divider(String label) => Row(
        children: [
          Expanded(child: Divider(color: Colors.grey.shade300, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Divider(color: Colors.grey.shade300, height: 1)),
        ],
      );

  BoxDecoration _boxDecoration({Color? color}) => BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBDBDBD)),
      );

  Widget _buildIntField(TextEditingController ctrl, String hint, {int maxLength = 3}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(maxLength),
      ],
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFBDBDBD))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFBDBDBD))),
        filled: true,
        fillColor: Colors.white,
      ),
      style: const TextStyle(fontSize: 13),
    );
  }

  Widget _buildTemperatureField(TextEditingController ctrl, String hint) {
    return TextFormField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
        LengthLimitingTextInputFormatter(5),
      ],
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
        suffixText: 'ºC',
        suffixStyle: const TextStyle(fontSize: 12, color: Colors.grey),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFBDBDBD))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFBDBDBD))),
        filled: true,
        fillColor: Colors.white,
      ),
      style: const TextStyle(fontSize: 13),
    );
  }

  Widget _buildDensidadeField(TextEditingController ctrl, String hint) {
    return TextFormField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
        LengthLimitingTextInputFormatter(6),
      ],
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFBDBDBD))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFBDBDBD))),
        filled: true,
        fillColor: Colors.white,
      ),
      style: const TextStyle(fontSize: 13),
    );
  }

  Widget _buildResultField(String valor, bool calculando, {bool isHighlighted = false}) {
    final bg = isHighlighted ? const Color(0xFFE3F2FD) : const Color(0xFFF5F5F5);
    final borderColor = isHighlighted ? const Color(0xFF2196F3) : const Color(0xFFBDBDBD);
    final textColor = isHighlighted ? const Color(0xFF0D47A1) : const Color(0xFF212121);

    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      alignment: Alignment.center,
      child: calculando
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : Text(
              valor,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: valor == '-' ? Colors.grey : textColor,
                letterSpacing: 0.5,
              ),
            ),
    );
  }
}
