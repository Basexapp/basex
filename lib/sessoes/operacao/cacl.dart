import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../bombeios/cacl_pdf.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'dart:convert' show base64Encode;
import 'dart:js' as js;
import '../../login_page.dart';

// ✅ ETAPA 1 — Criar enum de modo do CACL
enum CaclModo { emissao, visualizacao, edicao }

class CalcPage extends StatefulWidget {
  final Map<String, dynamic> dadosFormulario;
  final CaclModo modo;
  final String? caclId;
  final VoidCallback? onFinalizar;
  final VoidCallback? onVoltar;

  const CalcPage({
    super.key,
    required this.dadosFormulario,
    this.modo = CaclModo.emissao,
    this.caclId,
    this.onFinalizar,
    this.onVoltar,
  });

  @override
  State<CalcPage> createState() => _CalcPageState();
}

class _CalcPageState extends State<CalcPage> {
  String? _tabelaArqueacao;
  double volumeInicial = 0;
  double volumeFinal = 0;
  double volumeTotalLiquidoInicial = 0;
  double volumeTotalLiquidoFinal = 0;
  double totalSaidasAmbienteReal = 0;
  double totalEntradasAmbienteReal = 0;
  double totalSaidas20Real = 0;
  double totalEntradas20Real = 0;
  double _estoqueInicialRPC = 0;
  bool _isGeneratingPDF = false;
  bool _isEmittingCACL = false;
  bool _caclJaEmitido = false;
  String? _numeroControle; // Variável para armazenar o número de controle
  ScaffoldMessengerState? _scaffoldMessenger;
  NavigatorState? _navigatorState;

  bool get _mostrarCampoSobraPerda {
    return widget.dadosFormulario['cacl_verificacao'] == true ||
        widget.dadosFormulario['origem_estoque_tanque'] == true;
  }

  double _obterEstoqueFinalCalculado20() {
    if (widget.modo == CaclModo.emissao && 
       (widget.dadosFormulario['cacl_verificacao'] == true || widget.dadosFormulario['origem_estoque_tanque'] == true)) {
      final medicoes = widget.dadosFormulario['medicoes'] ?? {};
      final totalEntradas = _extrairNumero(medicoes['totalEntradasPeriodo']?.toString());
      final totalSaidas = _extrairNumero(medicoes['totalSaidasPeriodo']?.toString());
      return _estoqueInicialRPC + totalEntradas - totalSaidas;
    }
    final estoqueRaw = widget.dadosFormulario['estoque_final_calculado_20'];
    if (estoqueRaw is num) return estoqueRaw.toDouble();
    return double.tryParse(estoqueRaw?.toString() ?? '') ?? 0.0;
  }

  String _obterEstoqueFinalCalculadoFormatado() {
    return _formatarVolumeLitros(_obterEstoqueFinalCalculado20());
  }

  String? _obterVolume20DisponivelRaw(Map<String, dynamic> medicoes) {
    final volume20FinalRaw = medicoes['volume20Final']?.toString().trim();
    final volume20InicialRaw = medicoes['volume20Inicial']?.toString().trim();
    
    // ✅ REGRA: Se for CACL de verificação ou origem de estoque tanque, 
    //            o cálculo da Sobra/Perda usa o volume final (2ª medição)
    final bool isCalculoSobra = widget.dadosFormulario['cacl_verificacao'] == true || 
                               widget.dadosFormulario['origem_estoque_tanque'] == true;
    
    if (isCalculoSobra) {
      bool validoFinal(String? valor) {
        if (valor == null || valor.isEmpty || valor == '-') return false;
        return valor.replaceAll(RegExp(r'[^0-9]'), '').isNotEmpty;
      }
      
      return validoFinal(volume20FinalRaw) ? volume20FinalRaw : null;
    }
    
    // Para outros casos: prioriza final, fallback para inicial
    bool valido(String? valor) {
      if (valor == null || valor.isEmpty || valor == '-') return false;
      return valor.replaceAll(RegExp(r'[^0-9]'), '').isNotEmpty;
    }

    if (valido(volume20FinalRaw)) return volume20FinalRaw;
    if (valido(volume20InicialRaw)) return volume20InicialRaw;
    return null;
  }

  bool _podeCalcularSobraPerda(Map<String, dynamic> medicoes) {
    return _obterVolume20DisponivelRaw(medicoes) != null;
  }

  double? _obterValorSobraPerda(Map<String, dynamic> medicoes) {
    if (!_podeCalcularSobraPerda(medicoes)) return null;

    final volume20Raw = _obterVolume20DisponivelRaw(medicoes);
    final volume20 = _extrairNumero(volume20Raw);
    return volume20 - _obterEstoqueFinalCalculado20();
  }

  String _formatarSobraPerdaComSinal(double valor) {
    final sinal = valor >= 0 ? '+' : '-';
    final valorFormatado = _formatarVolumeLitros(valor.abs());
    return '$sinal$valorFormatado';
  }

  TextStyle _obterEstiloSobraPerda(Map<String, dynamic> medicoes) {
    final valor = _obterValorSobraPerda(medicoes);
    if (valor == null) {
      return const TextStyle(fontSize: 11);
    }

    return TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.bold,
      color: valor >= 0 ? Colors.blue[700] : Colors.red[700],
    );
  }

  String _obterSobraPerdaFormatada(Map<String, dynamic> medicoes) {
    final sobraPerda = _obterValorSobraPerda(medicoes);
    if (sobraPerda == null) {
      return '-';
    }

    return _formatarSobraPerdaComSinal(sobraPerda);
  }

  @override
  void initState() {
    super.initState();

    // 🔒 REGRA ABSOLUTA: UI sempre começa sem nº de controle
    _numeroControle = null;

    if (widget.modo == CaclModo.emissao) {
      _calcularVolumesIniciais();
      if (widget.dadosFormulario['cacl_verificacao'] == true || 
          widget.dadosFormulario['origem_estoque_tanque'] == true) {
        _buscarEstoqueInicialRPCRepositorio();
      }
    } else {
      _carregarDadosParaVisualizacao();
    }
  }

  Future<void> _buscarEstoqueInicialRPCRepositorio() async {
    final tanqueId = _obterTanqueId();
    final dataRef = _obterDataParaEstoque();
    final dataSql = dataRef.toIso8601String().split('T')[0];

    if (tanqueId == null) return;

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.rpc(
        'fn_estoque_inicial_tanque',
        params: {
          'p_tanque_id': tanqueId,
          'p_data': dataSql,
        },
      );

      double saldo = 0;
      if (response is Map) {
        saldo = (response['estoque_inicial'] ?? 0).toDouble();
      } else {
        saldo = (response ?? 0).toDouble();
      }

      setState(() {
        _estoqueInicialRPC = saldo;
      });
    } catch (e) {
      debugPrint('Erro ao buscar estoque inicial via RPC: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scaffoldMessenger ??= ScaffoldMessenger.maybeOf(context);
    _navigatorState ??= Navigator.maybeOf(context);
  }

  void _mostrarSnackBar(SnackBar snackBar) {
    _scaffoldMessenger?.showSnackBar(snackBar);
  }

  DateTime _obterDataParaEstoque() {
    final dataRaw = widget.dadosFormulario['data']?.toString().trim() ?? '';
    final hoje = DateTime.now();
    if (dataRaw.isEmpty) return DateTime(hoje.year, hoje.month, hoje.day);

    try {
      if (dataRaw.contains('/')) {
        final partes = dataRaw.split('/');
        if (partes.length == 3) {
          final dia = int.tryParse(partes[0]) ?? hoje.day;
          final mes = int.tryParse(partes[1]) ?? hoje.month;
          final ano = int.tryParse(partes[2]) ?? hoje.year;
          return DateTime(ano, mes, dia);
        }
      }

      if (dataRaw.contains('-')) {
        final parsed = DateTime.parse(dataRaw);
        return DateTime(parsed.year, parsed.month, parsed.day);
      }
    } catch (_) {}

    return DateTime(hoje.year, hoje.month, hoje.day);
  }

  String _obterTimestampBrasiliaComDataReferencia() {
    final agoraUtc = DateTime.now().toUtc();
    final horaBrasilia = agoraUtc.subtract(const Duration(hours: 3));
    final dataReferencia = _obterDataParaEstoque();

    final combinado = DateTime.utc(
      dataReferencia.year,
      dataReferencia.month,
      dataReferencia.day,
      horaBrasilia.hour,
      horaBrasilia.minute,
      horaBrasilia.second,
      horaBrasilia.millisecond,
      horaBrasilia.microsecond,
    );

    return combinado.toIso8601String();
  }

  // Em CalcPage.dart - método _irParaEstoqueTanqueAposEmissao()
  Future<void> _irParaEstoqueTanqueAposEmissao() async {
    // ✅ VERIFICA SE É EDIÇÃO DE PENDENTE
    final bool isEdicaoPendente = widget.dadosFormulario['modo_edicao'] == true && 
                                  widget.dadosFormulario['id_cacl'] != null;
    
    if (isEdicaoPendente) {
      // Se é edição de pendente, precisa voltar 2 níveis: 
      // CalcPage -> EditarCaclPage -> EstoqueTanquePage
      if (_navigatorState != null && mounted) {
        // Primeiro pop fecha a CalcPage
        _navigatorState!.pop();
        // Depois precisamos encontrar e fechar a EditarCaclPage
        // Mas como estamos dentro de um push, o Navigator atual já fechou a CalcPage
        // O contexto atual agora é da EditarCaclPage
        if (mounted) {
          // Retorna para a EstoqueTanquePage com status
          Navigator.of(context).pop({'status': 'cacl_emitido'});
        }
      }
    } else {
      // Fluxo normal de emissão (não é edição)
      if (_navigatorState != null && mounted) {
        _navigatorState!.pop({'status': 'cacl_emitido'});
      }
    }
  }

  Future<void> _carregarDadosParaVisualizacao() async {
    try {
      final supabase = Supabase.instance.client;
      final medicoes = widget.dadosFormulario['medicoes'] ?? {};

      if (medicoes.isNotEmpty && medicoes.containsKey('volumeProdutoInicial')) {
        volumeInicial = _extrairNumero(
          medicoes['volumeProdutoInicial']?.toString(),
        );
        volumeFinal = _extrairNumero(
          medicoes['volumeProdutoFinal']?.toString(),
        );

        volumeTotalLiquidoInicial = _extrairNumero(
          medicoes['volumeTotalLiquidoInicial']?.toString(),
        );
        volumeTotalLiquidoFinal = _extrairNumero(
          medicoes['volumeTotalLiquidoFinal']?.toString(),
        );

        final num totalSaidasRecAmb =
            widget.dadosFormulario['total_saidas_ambiente'] ?? 0;
        final num totalEntradasRecAmb =
            widget.dadosFormulario['total_entradas_ambiente'] ?? 0;
        final num totalSaidasRec20 =
            widget.dadosFormulario['total_saidas_periodo'] ?? 0;
        final num totalEntradasRec20 =
            widget.dadosFormulario['total_entradas_periodo'] ?? 0;
        totalSaidasAmbienteReal = totalSaidasRecAmb.toDouble();
        totalEntradasAmbienteReal = totalEntradasRecAmb.toDouble();
        totalSaidas20Real = totalSaidasRec20.toDouble();
        totalEntradas20Real = totalEntradasRec20.toDouble();

        setState(() {
          _caclJaEmitido = true;
        });
        return;
      }

      if (widget.caclId != null && widget.caclId!.isNotEmpty) {
        try {
          final resultado = await supabase
              .from('cacl')
              .select('*')
              .eq('id', widget.caclId!)
              .maybeSingle();

          if (resultado != null) {
            final tanqueId = resultado['tanque_id']?.toString();
            if (tanqueId != null && tanqueId.isNotEmpty) {
              final tanqueInfo = await supabase
                  .from('tanques')
                  .select('referencia')
                  .eq('id', tanqueId)
                  .maybeSingle();

              if (tanqueInfo != null && tanqueInfo['referencia'] != null) {
                widget.dadosFormulario['tanque'] = tanqueInfo['referencia']
                    ?.toString();
              }
            }

            widget.dadosFormulario['tanque_id'] = resultado['tanque_id']
                ?.toString();
            widget.dadosFormulario['produto_id'] = resultado['produto_id']
                ?.toString();

            if (resultado['data'] != null) {
              widget.dadosFormulario['data'] = _formatarDataDisplay(
                resultado['data'],
              );
            }
            if (resultado['terminal_id'] != null) {
              widget.dadosFormulario['terminal_id'] = resultado['terminal_id']
                  ?.toString();
            }
            if (resultado['tipo'] != null) {
              final tipo = resultado['tipo']?.toString();
              widget.dadosFormulario['cacl_verificacao'] =
                  tipo == 'verificacao';
              widget.dadosFormulario['cacl_movimentacao'] =
                  tipo == 'movimentacao';
            }

            if (resultado['numero_controle'] != null) {
              _numeroControle = resultado['numero_controle']?.toString();
            }

            volumeInicial =
                resultado['volume_produto_inicial']?.toDouble() ?? 0.0;
            volumeFinal = resultado['volume_produto_final']?.toDouble() ?? 0.0;
            volumeTotalLiquidoInicial =
                resultado['volume_total_liquido_inicial']?.toDouble() ?? 0.0;
            volumeTotalLiquidoFinal =
                resultado['volume_total_liquido_final']?.toDouble() ?? 0.0;

            final medicoesAtualizadas = <String, dynamic>{};

            if (resultado['horario_inicial'] != null) {
              medicoesAtualizadas['horarioInicial'] = _formatarHorarioDisplay(
                resultado['horario_inicial'],
              );
            }
            if (resultado['altura_total_cm_inicial'] != null) {
              medicoesAtualizadas['cmInicial'] =
                  resultado['altura_total_cm_inicial']?.toString();
            }
            if (resultado['altura_total_mm_inicial'] != null) {
              medicoesAtualizadas['mmInicial'] =
                  resultado['altura_total_mm_inicial']?.toString();
            }
            if (resultado['altura_agua_inicial'] != null) {
              medicoesAtualizadas['alturaAguaInicial'] =
                  resultado['altura_agua_inicial']?.toString();
            }
            if (resultado['altura_produto_inicial'] != null) {
              medicoesAtualizadas['alturaProdutoInicial'] =
                  resultado['altura_produto_inicial']?.toString();
            }
            if (resultado['temperatura_tanque_inicial'] != null) {
              medicoesAtualizadas['tempTanqueInicial'] =
                  resultado['temperatura_tanque_inicial']?.toString();
            }
            if (resultado['densidade_observada_inicial'] != null) {
              medicoesAtualizadas['densidadeInicial'] =
                  resultado['densidade_observada_inicial']?.toString();
            }
            if (resultado['temperatura_amostra_inicial'] != null) {
              medicoesAtualizadas['tempAmostraInicial'] =
                  resultado['temperatura_amostra_inicial']?.toString();
            }
            if (resultado['densidade_20_inicial'] != null) {
              medicoesAtualizadas['densidade20Inicial'] =
                  resultado['densidade_20_inicial']?.toString();
            }
            if (resultado['fator_correcao_inicial'] != null) {
              medicoesAtualizadas['fatorCorrecaoInicial'] =
                  resultado['fator_correcao_inicial']?.toString();
            }
            if (resultado['massa_inicial'] != null) {
              medicoesAtualizadas['massaInicial'] = resultado['massa_inicial']
                  ?.toString();
            }

            if (resultado['horario_final'] != null) {
              medicoesAtualizadas['horarioFinal'] = _formatarHorarioDisplay(
                resultado['horario_final'],
              );
            }
            if (resultado['altura_total_cm_final'] != null) {
              medicoesAtualizadas['cmFinal'] =
                  resultado['altura_total_cm_final']?.toString();
            }
            if (resultado['altura_total_mm_final'] != null) {
              medicoesAtualizadas['mmFinal'] =
                  resultado['altura_total_mm_final']?.toString();
            }
            if (resultado['altura_agua_final'] != null) {
              medicoesAtualizadas['alturaAguaFinal'] =
                  resultado['altura_agua_final']?.toString();
            }
            if (resultado['altura_produto_final'] != null) {
              medicoesAtualizadas['alturaProdutoFinal'] =
                  resultado['altura_produto_final']?.toString();
            }
            if (resultado['temperatura_tanque_final'] != null) {
              medicoesAtualizadas['tempTanqueFinal'] =
                  resultado['temperatura_tanque_final']?.toString();
            }
            if (resultado['densidade_observada_final'] != null) {
              medicoesAtualizadas['densidadeFinal'] =
                  resultado['densidade_observada_final']?.toString();
            }
            if (resultado['temperatura_amostra_final'] != null) {
              medicoesAtualizadas['tempAmostraFinal'] =
                  resultado['temperatura_amostra_final']?.toString();
            }
            if (resultado['densidade_20_final'] != null) {
              medicoesAtualizadas['densidade20Final'] =
                  resultado['densidade_20_final']?.toString();
            }
            if (resultado['fator_correcao_final'] != null) {
              medicoesAtualizadas['fatorCorrecaoFinal'] =
                  resultado['fator_correcao_final']?.toString();
            }
            if (resultado['massa_final'] != null) {
              medicoesAtualizadas['massaFinal'] = resultado['massa_final']
                  ?.toString();
            }

            medicoesAtualizadas['volumeProdutoInicial'] = _formatarVolumeLitros(
              volumeInicial,
            );
            medicoesAtualizadas['volumeProdutoFinal'] = _formatarVolumeLitros(
              volumeFinal,
            );
            medicoesAtualizadas['volumeTotalLiquidoInicial'] =
                _formatarVolumeLitros(volumeTotalLiquidoInicial);
            medicoesAtualizadas['volumeTotalLiquidoFinal'] =
                _formatarVolumeLitros(volumeTotalLiquidoFinal);

            if (resultado['volume_agua_inicial'] != null) {
              medicoesAtualizadas['volumeAguaInicial'] = _formatarVolumeLitros(
                resultado['volume_agua_inicial']?.toDouble() ?? 0.0,
              );
            }
            if (resultado['volume_agua_final'] != null) {
              medicoesAtualizadas['volumeAguaFinal'] = _formatarVolumeLitros(
                resultado['volume_agua_final']?.toDouble() ?? 0.0,
              );
            }

            if (resultado['volume_20_inicial'] != null) {
              medicoesAtualizadas['volume20Inicial'] = _formatarVolumeLitros(
                resultado['volume_20_inicial']?.toDouble() ?? 0.0,
              );
            }
            if (resultado['volume_20_final'] != null) {
              medicoesAtualizadas['volume20Final'] = _formatarVolumeLitros(
                resultado['volume_20_final']?.toDouble() ?? 0.0,
              );
            }

            if (resultado['faturado_final'] != null) {
              medicoesAtualizadas['faturadoFinal'] = resultado['faturado_final']
                  ?.toString();
            }

            if (resultado['estoque_final_calculado'] != null) {
              widget.dadosFormulario['estoque_final_calculado_20'] =
                  resultado['estoque_final_calculado'];
            }

            if (resultado['total_entradas'] != null) {
              widget.dadosFormulario['total_entradas_periodo'] =
                  resultado['total_entradas'];
              medicoesAtualizadas['totalEntradasPeriodo'] =
                  _formatarVolumeLitros(resultado['total_entradas'].toDouble());
              totalEntradas20Real = resultado['total_entradas'].toDouble();
            }

            // ✅ NOVO: Carregar total_saidas_ambiente do banco para o histórico
            if (resultado['total_saidas_ambiente'] != null &&
                resultado['total_saidas_ambiente'] != 0) {
              totalSaidasAmbienteReal =
                  (resultado['total_saidas_ambiente'] ?? 0).toDouble();
            } else {
              // REPLICAÇÃO DA LÓGICA DE ESTOQUE_TANQUE_DIA.DART
              try {
                final dataOriginal = resultado['data']?.toString() ?? '';
                final tanqueId = resultado['tanque_id']?.toString();
                if (tanqueId != null && dataOriginal.isNotEmpty) {
                  final responseMovs = await supabase
                      .from('movimentacoes_tanque')
                      .select('entrada_amb, saida_amb, entrada_vinte, saida_vinte')
                      .eq('tanque_id', tanqueId)
                      .gte('data_mov', '$dataOriginal 00:00:00')
                      .lte('data_mov', '$dataOriginal 23:59:59');

                  double somaSaidasAmb = 0;
                  double somaEntradasAmb = 0;
                  double somaEntradas20 = 0;
                  double somaSaidas20 = 0;
                  for (final m in responseMovs) {
                    final num sAmb = (m['saida_amb'] ?? 0) as num;
                    final num eAmb = (m['entrada_amb'] ?? 0) as num;
                    final num eVinte = (m['entrada_vinte'] ?? 0) as num;
                    final num sVinte = (m['saida_vinte'] ?? 0) as num;
                    somaSaidasAmb += sAmb.toDouble();
                    somaEntradasAmb += eAmb.toDouble();
                    somaEntradas20 += eVinte.toDouble();
                    somaSaidas20 += sVinte.toDouble();
                  }
                  totalSaidasAmbienteReal = somaSaidasAmb;
                  totalEntradasAmbienteReal = somaEntradasAmb;
                  if (totalEntradas20Real == 0) totalEntradas20Real = somaEntradas20;
                  if (totalSaidas20Real == 0) totalSaidas20Real = somaSaidas20;
                }
              } catch (e) {
                debugPrint('Erro ao buscar saídas ambiente no Histórico: $e');
              }
            }

            if (resultado['total_saidas'] != null) {
              widget.dadosFormulario['total_saidas_periodo'] =
                  resultado['total_saidas'];
              medicoesAtualizadas['totalSaidasPeriodo'] =
                  _formatarVolumeLitros(resultado['total_saidas'].toDouble());
            }

            widget.dadosFormulario['medicoes'] = medicoesAtualizadas;

            setState(() {
              _caclJaEmitido = true;
            });
            return;
          }
        } catch (_) {}
      }

      final dadosDoBanco = widget.dadosFormulario;

      volumeInicial = dadosDoBanco['volume_produto_inicial']?.toDouble() ?? 0.0;
      volumeFinal = dadosDoBanco['volume_produto_final']?.toDouble() ?? 0.0;
      volumeTotalLiquidoInicial =
          dadosDoBanco['volume_total_liquido_inicial']?.toDouble() ?? 0.0;
      volumeTotalLiquidoFinal =
          dadosDoBanco['volume_total_liquido_final']?.toDouble() ?? 0.0;

      _numeroControle = dadosDoBanco['numero_controle']?.toString();

      final medicoesAtualizadas = <String, dynamic>{
        ...medicoes,
        'volumeProdutoInicial': _formatarVolumeLitros(volumeInicial),
        'volumeProdutoFinal': _formatarVolumeLitros(volumeFinal),
        'volumeTotalLiquidoInicial': _formatarVolumeLitros(
          volumeTotalLiquidoInicial,
        ),
        'volumeTotalLiquidoFinal': _formatarVolumeLitros(
          volumeTotalLiquidoFinal,
        ),
      };

      widget.dadosFormulario['medicoes'] = medicoesAtualizadas;

      setState(() {
        _caclJaEmitido = true;
      });
    } catch (_) {
      setState(() {
        volumeInicial = 0;
        volumeFinal = 0;
        volumeTotalLiquidoInicial = 0;
        volumeTotalLiquidoFinal = 0;
        _caclJaEmitido = false;
      });
    }
  }

  // ✅ FUNÇÃO AUXILIAR: Formatar horário para exibição
  String _formatarHorarioDisplay(String? timeString) {
    if (timeString == null || timeString.isEmpty) return '-';

    try {
      if (timeString.contains('T')) {
        final dt = DateTime.parse(timeString);
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} h';
      }

      final partes = timeString.split(':');
      if (partes.length >= 2) {
        final horas = partes[0];
        final minutos = partes[1];
        return '$horas:$minutos h';
      }
    } catch (e) {
      return timeString;
    }

    return timeString;
  }

  // ✅ FUNÇÃO AUXILIAR: Formatar data para exibição
  String _formatarDataDisplay(String? dataSql) {
    if (dataSql == null || dataSql.isEmpty) return '';

    try {
      // Formato SQL: "YYYY-MM-DD"
      final partes = dataSql.split('-');
      if (partes.length == 3) {
        final ano = partes[0];
        final mes = partes[1];
        final dia = partes[2];
        return '$dia/$mes/$ano';
      }
    } catch (e) {
      return dataSql;
    }

    return dataSql;
  }

  Future<void> _calcularVolumesIniciais() async {
    final String? terminalId = widget.dadosFormulario['terminal_id']?.toString();

    if (terminalId != null && terminalId.isNotEmpty) {
      try {
        final supabase = Supabase.instance.client;
        final terminalResp = await supabase
            .from('terminais')
            .select('tabela_arqueacao')
            .eq('id', terminalId)
            .maybeSingle();

        if (terminalResp != null) {
          _tabelaArqueacao = terminalResp['tabela_arqueacao']?.toString();
        }
      } catch (e) {
        debugPrint('Erro ao buscar tabela_arqueacao: $e');
      }
    }

    final medicoes = widget.dadosFormulario['medicoes'];

    final alturaAguaInicial = medicoes['alturaAguaInicial'];
    final alturaAguaFinal = medicoes['alturaAguaFinal'];

    final alturaTotalCmInicial = medicoes['cmInicial']?.toString() ?? '';
    final alturaTotalMmInicial = medicoes['mmInicial']?.toString() ?? '';
    final alturaTotalCmFinal = medicoes['cmFinal']?.toString() ?? '';
    final alturaTotalMmFinal = medicoes['mmFinal']?.toString() ?? '';

    Map<String, String?> extrairCmMm(String? alturaFormatada) {
      if (alturaFormatada == null ||
          alturaFormatada.isEmpty ||
          alturaFormatada == '-') {
        return {'cm': null, 'mm': null};
      }

      try {
        final semUnidade = alturaFormatada.replaceAll(' cm', '').trim();
        final partes = semUnidade.split(',');

        if (partes.length == 2) {
          return {'cm': partes[0], 'mm': partes[1]};
        } else if (partes.length == 1) {
          return {'cm': partes[0], 'mm': '0'};
        } else {
          return {'cm': null, 'mm': null};
        }
      } catch (e) {
        return {'cm': null, 'mm': null};
      }
    }

    final aguaCmMmInicial = extrairCmMm(alturaAguaInicial);
    final aguaCmMmFinal = extrairCmMm(alturaAguaFinal);

    final Map<String, String?> totalCmMmInicial = {
      'cm': alturaTotalCmInicial.isEmpty ? null : alturaTotalCmInicial,
      'mm': alturaTotalMmInicial.isEmpty ? null : alturaTotalMmInicial,
    };

    final Map<String, String?> totalCmMmFinal = {
      'cm': alturaTotalCmFinal.isEmpty ? null : alturaTotalCmFinal,
      'mm': alturaTotalMmFinal.isEmpty ? null : alturaTotalMmFinal,
    };

    final volumeTotalLiquidoInicial = await _buscarVolumeReal(
      totalCmMmInicial['cm'],
      totalCmMmInicial['mm'],
    );
    final volumeTotalLiquidoFinal = await _buscarVolumeReal(
      totalCmMmFinal['cm'],
      totalCmMmFinal['mm'],
    );

    final volAguaInicial = await _buscarVolumeReal(
      aguaCmMmInicial['cm'],
      aguaCmMmInicial['mm'],
    );
    final volAguaFinal = await _buscarVolumeReal(
      aguaCmMmFinal['cm'],
      aguaCmMmFinal['mm'],
    );

    final volProdutoInicial = volumeTotalLiquidoInicial - volAguaInicial;
    final volProdutoFinal = volumeTotalLiquidoFinal - volAguaFinal;

    final volumeTotalInicial = volProdutoInicial;
    final volumeTotalFinal = volProdutoFinal;

    // ✅ BUSCAR TOTAL DE SAÍDAS AMBIENTE E 20ºC DO DIA (Lógica EstonqueTanquePage)
    double totalEntradasAmb = 0;
    double totalSaidasAmb = 0;
    double totalEntradas20 = 0;
    double totalSaidas20 = 0;
    try {
      final supabase = Supabase.instance.client;
      final dataRaw = widget.dadosFormulario['data']?.toString() ?? '';
      String dataBusca = '';
      if (dataRaw.contains('/')) {
        final partes = dataRaw.split('/');
        if (partes.length == 3) {
          dataBusca = "${partes[2]}-${partes[1]}-${partes[0]}";
        }
      } else {
        dataBusca = dataRaw;
      }

      final tanqueId = widget.dadosFormulario['tanque_id']?.toString();
      if (tanqueId != null && dataBusca.isNotEmpty) {
        final response = await supabase
            .from('movimentacoes_tanque')
            .select('entrada_amb, saida_amb, entrada_vinte, saida_vinte')
            .eq('tanque_id', tanqueId)
            .gte('data_mov', '$dataBusca 00:00:00')
            .lte('data_mov', '$dataBusca 23:59:59');

        for (final m in response) {
          final num entradaAmb = (m['entrada_amb'] ?? 0) as num;
          final num saidaAmb = (m['saida_amb'] ?? 0) as num;
          final num entradaVinte = (m['entrada_vinte'] ?? 0) as num;
          final num saidaVinte = (m['saida_vinte'] ?? 0) as num;
          totalEntradasAmb += entradaAmb.toDouble();
          totalSaidasAmb += saidaAmb.toDouble();
          totalEntradas20 += entradaVinte.toDouble();
          totalSaidas20 += saidaVinte.toDouble();
        }
      }
    } catch (e) {
      debugPrint('Erro ao calcular saídas no CACL: $e');
    }

    setState(() {
      this.volumeInicial = volProdutoInicial;
      this.volumeFinal = volProdutoFinal;
      this.volumeTotalLiquidoInicial = volumeTotalLiquidoInicial;
      this.volumeTotalLiquidoFinal = volumeTotalLiquidoFinal;
      this.totalSaidasAmbienteReal = totalSaidasAmb;
      this.totalEntradasAmbienteReal = totalEntradasAmb;
      this.totalEntradas20Real = totalEntradas20;
      this.totalSaidas20Real = totalSaidas20;
    });

    final volumeProdutoInicialFormatado = _formatarVolumeLitros(
      volProdutoInicial,
    );
    final volumeProdutoFinalFormatado = _formatarVolumeLitros(volProdutoFinal);
    final volumeAguaInicialFormatado = _formatarVolumeLitros(volAguaInicial);
    final volumeAguaFinalFormatado = _formatarVolumeLitros(volAguaFinal);
    final volumeTotalInicialFormatado = _formatarVolumeLitros(
      volumeTotalInicial,
    );
    final volumeTotalFinalFormatado = _formatarVolumeLitros(volumeTotalFinal);

    widget.dadosFormulario['medicoes']['volumeProdutoInicial'] =
        volumeProdutoInicialFormatado;
    widget.dadosFormulario['medicoes']['volumeProdutoFinal'] =
        volumeProdutoFinalFormatado;
    widget.dadosFormulario['medicoes']['volumeAguaInicial'] =
        volumeAguaInicialFormatado;
    widget.dadosFormulario['medicoes']['volumeAguaFinal'] =
        volumeAguaFinalFormatado;
    widget.dadosFormulario['medicoes']['volumeTotalLiquidoInicial'] =
        _formatarVolumeLitros(volumeTotalLiquidoInicial);
    widget.dadosFormulario['medicoes']['volumeTotalLiquidoFinal'] =
        _formatarVolumeLitros(volumeTotalLiquidoFinal);

    widget.dadosFormulario['medicoes']['volumeTotalInicial'] =
        volumeTotalInicialFormatado;
    widget.dadosFormulario['medicoes']['volumeTotalFinal'] =
        volumeTotalFinalFormatado;

    final produtoNome = _obterNomeProduto();

    if (medicoes['tempAmostraInicial'] != null &&
        medicoes['tempAmostraInicial'].toString().isNotEmpty &&
        medicoes['tempAmostraInicial'].toString() != '-' &&
        medicoes['densidadeInicial'] != null &&
        medicoes['densidadeInicial'].toString().isNotEmpty &&
        medicoes['densidadeInicial'].toString() != '-' &&
        produtoNome != 'Produto' &&
        produtoNome != 'Carregando...') {
      final densidade20Inicial = await _buscarDensidade20C(
        temperaturaAmostra: medicoes['tempAmostraInicial'].toString(),
        densidadeObservada: medicoes['densidadeInicial'].toString(),
        produtoNome: produtoNome,
      );

      widget.dadosFormulario['medicoes']['densidade20Inicial'] =
          densidade20Inicial;
    } else {
      widget.dadosFormulario['medicoes']['densidade20Inicial'] = '-';
    }

    if (medicoes['tempAmostraFinal'] != null &&
        medicoes['tempAmostraFinal'].toString().isNotEmpty &&
        medicoes['tempAmostraFinal'].toString() != '-' &&
        medicoes['densidadeFinal'] != null &&
        medicoes['densidadeFinal'].toString().isNotEmpty &&
        medicoes['densidadeFinal'].toString() != '-' &&
        produtoNome != 'Produto' &&
        produtoNome != 'Carregando...') {
      final densidade20Final = await _buscarDensidade20C(
        temperaturaAmostra: medicoes['tempAmostraFinal'].toString(),
        densidadeObservada: medicoes['densidadeFinal'].toString(),
        produtoNome: produtoNome,
      );

      widget.dadosFormulario['medicoes']['densidade20Final'] = densidade20Final;
    } else {
      widget.dadosFormulario['medicoes']['densidade20Final'] = '-';
    }

    if (medicoes['tempTanqueInicial'] != null &&
        medicoes['tempTanqueInicial'].toString().isNotEmpty &&
        medicoes['tempTanqueInicial'].toString() != '-' &&
        widget.dadosFormulario['medicoes']['densidade20Inicial'] != null &&
        widget.dadosFormulario['medicoes']['densidade20Inicial']
            .toString()
            .isNotEmpty &&
        widget.dadosFormulario['medicoes']['densidade20Inicial'].toString() !=
            '-') {
      final fcvInicial = await _buscarFCV(
        temperaturaTanque: medicoes['tempTanqueInicial'].toString(),
        densidade20C: widget.dadosFormulario['medicoes']['densidade20Inicial']
            .toString(),
        produtoNome: produtoNome,
      );

      widget.dadosFormulario['medicoes']['fatorCorrecaoInicial'] = fcvInicial;
    } else {
      widget.dadosFormulario['medicoes']['fatorCorrecaoInicial'] = '-';
    }

    if (medicoes['tempTanqueFinal'] != null &&
        medicoes['tempTanqueFinal'].toString().isNotEmpty &&
        medicoes['tempTanqueFinal'].toString() != '-' &&
        widget.dadosFormulario['medicoes']['densidade20Final'] != null &&
        widget.dadosFormulario['medicoes']['densidade20Final']
            .toString()
            .isNotEmpty &&
        widget.dadosFormulario['medicoes']['densidade20Final'].toString() !=
            '-') {
      final fcvFinal = await _buscarFCV(
        temperaturaTanque: medicoes['tempTanqueFinal'].toString(),
        densidade20C: widget.dadosFormulario['medicoes']['densidade20Final']
            .toString(),
        produtoNome: produtoNome,
      );

      widget.dadosFormulario['medicoes']['fatorCorrecaoFinal'] = fcvFinal;
    } else {
      widget.dadosFormulario['medicoes']['fatorCorrecaoFinal'] = '-';
    }

    if (widget.dadosFormulario['medicoes']['fatorCorrecaoInicial'] != null &&
        widget.dadosFormulario['medicoes']['fatorCorrecaoInicial']
            .toString()
            .isNotEmpty &&
        widget.dadosFormulario['medicoes']['fatorCorrecaoInicial'].toString() !=
            '-') {
      try {
        final fcvInicialStr = widget
            .dadosFormulario['medicoes']['fatorCorrecaoInicial']
            .toString();
        final fcvInicial =
            double.tryParse(fcvInicialStr.replaceAll(',', '.')) ?? 1.0;
        final volume20Inicial = volProdutoInicial * fcvInicial;

        widget.dadosFormulario['medicoes']['volume20Inicial'] =
            _formatarVolumeLitros(volume20Inicial);
      } catch (e) {
        widget.dadosFormulario['medicoes']['volume20Inicial'] = '-';
      }
    } else {
      widget.dadosFormulario['medicoes']['volume20Inicial'] = '-';
    }

    if (widget.dadosFormulario['medicoes']['fatorCorrecaoFinal'] != null &&
        widget.dadosFormulario['medicoes']['fatorCorrecaoFinal']
            .toString()
            .isNotEmpty &&
        widget.dadosFormulario['medicoes']['fatorCorrecaoFinal'].toString() !=
            '-') {
      try {
        final fcvFinalStr = widget
            .dadosFormulario['medicoes']['fatorCorrecaoFinal']
            .toString();
        final fcvFinal =
            double.tryParse(fcvFinalStr.replaceAll(',', '.')) ?? 1.0;
        final volume20Final = volProdutoFinal * fcvFinal;

        widget.dadosFormulario['medicoes']['volume20Final'] =
            _formatarVolumeLitros(volume20Final);
      } catch (e) {
        widget.dadosFormulario['medicoes']['volume20Final'] = '-';
      }
    } else {
      widget.dadosFormulario['medicoes']['volume20Final'] = '-';
    }

    await _calcularMassa();

    setState(() {});
  }

  Future<double> _buscarVolumeReal(String? cm, String? mm) async {
    final nomeTabela = _tabelaArqueacao;
    if (nomeTabela == null || nomeTabela.isEmpty) {
      return 0;
    }

    final supabase = Supabase.instance.client;

    if (cm == null || cm.isEmpty) {
      return 0;
    }

    final intCm = int.tryParse(cm) ?? 0;
    final intMm = int.tryParse(mm ?? '0') ?? 0;

    final String tanqueRef = widget.dadosFormulario['tanque']?.toString() ?? '';
    String numeroTanque = '01';

    if (tanqueRef.isNotEmpty) {
      final numeros = tanqueRef.replaceAll(RegExp(r'[^0-9]'), '');
      if (numeros.isNotEmpty) {
        numeroTanque = numeros.padLeft(2, '0');
      }
    }

    final colunaCm = 'tq_${numeroTanque}_cm';
    final colunaMm = 'tq_${numeroTanque}_mm';

    try {
      final resultadoCm = await supabase
          .from(nomeTabela)
          .select(colunaCm)
          .eq('altura_cm_mm', intCm)
          .maybeSingle();

      if (resultadoCm == null || resultadoCm[colunaCm] == null) {
        return 0;
      }

      final volumeCm = _converterVolumeLitros(resultadoCm[colunaCm]);

      if (intMm == 0) {
        return volumeCm;
      }

      final resultadoMm = await supabase
          .from(nomeTabela)
          .select(colunaMm)
          .eq('altura_cm_mm', intMm)
          .maybeSingle();

      if (resultadoMm == null || resultadoMm[colunaMm] == null) {
        return volumeCm;
      }

      final volumeMm = _converterVolumeLitros(resultadoMm[colunaMm], isMilimetros: true);
      final volumeTotal = volumeCm + volumeMm;

      return double.parse(volumeTotal.toStringAsFixed(3));
    } catch (e) {
      return 0;
    }
  }

  double _converterVolumeLitros(dynamic valor, {bool isMilimetros = false}) {
    try {
      if (valor == null) return 0.0;

      // Se já for numérico (double/int vindo do banco/Supabase),
      // assumimos que está em m³ e convertemos para Litros (multiplicando por 1000).
      if (valor is num) {
        double litros = valor.toDouble() * 1000;
        return isMilimetros ? litros / 1000 : litros;
      }

      String str = valor.toString().trim().replaceAll(',', '.');
      if (str.isEmpty || str == '-') return 0.0;

      double finalValue = 0.0;

      // Se houver pontos, tratamos o último como separador decimal (m³ -> L)
      if (str.contains('.')) {
        final partes = str.split('.');
        // Removemos todos os pontos exceto o último (suporte a separadores de milhar)
        // Ex: "1.000.610" -> integerPart = "1000", decimalPart = "610"
        final decimalPart = partes.last;
        final integerPart = partes.sublist(0, partes.length - 1).join('');

        // Normalizamos a parte decimal para 3 dígitos para garantir precisão ex: "701.2"
        String d = decimalPart.padRight(3, '0');
        if (d.length > 3) d = d.substring(0, 3);

        final double? v = double.tryParse('$integerPart.$d');
        if (v != null) finalValue = v * 1000;
      } else {
        // Se não houver pontos, tratamos como valor m³ inteiro e convertemos para Litros
        final double? v = double.tryParse(str);
        if (v != null) finalValue = v * 1000;
      }

      // Se for milímetros, o valor da tabela (ex: "412") já representa Litros
      return isMilimetros ? finalValue / 1000 : finalValue;
    } catch (e) {
      return 0.0;
    }
  }

  Future<void> _emitirCACL() async {
    if (_isEmittingCACL) return;

    setState(() {
      _isEmittingCACL = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final medicoes = widget.dadosFormulario['medicoes'] ?? {};

      final session = supabase.auth.currentSession;
      if (session == null) {
        print('🔴 [CACL] Erro: Sessão Supabase é nula');
        if (context.mounted) {
          _mostrarSnackBar(
            const SnackBar(
              content: Text('Você precisa estar logado para emitir o CACL'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      String? tipoCACL;
      final bool caclVerificacao =
          widget.dadosFormulario['cacl_verificacao'] ?? false;
      final bool caclMovimentacao =
          widget.dadosFormulario['cacl_movimentacao'] ?? false;

      if (caclVerificacao) {
        tipoCACL = 'verificacao';
      } else if (caclMovimentacao) {
        tipoCACL = 'movimentacao';
      }

      final dataOriginal = widget.dadosFormulario['data']?.toString() ?? '';
      final dataFormatada = _formatarDataParaSQL(dataOriginal);
      final timestampReferencia = _obterTimestampBrasiliaComDataReferencia();

      final tanqueIdParaSalvar = _obterTanqueId();
      final produtoIdParaSalvar = _obterProdutoId();
      final terminalIdParaSalvar = UsuarioAtual.instance?.terminalId ??
          widget.dadosFormulario['terminal_id']?.toString();

      final dadosParaInserir = {
        'data': dataFormatada,
        'produto_id': produtoIdParaSalvar,
        'tanque_id': tanqueIdParaSalvar,
        'terminal_id': terminalIdParaSalvar,
        'status': 'emitido',
        'tipo': tipoCACL,

        'horario_inicial': _formatarHorarioParaTime(
          medicoes['horarioInicial']?.toString(),
        ),
        'altura_total_liquido_inicial': medicoes['alturaTotalInicial']
            ?.toString(),
        'altura_total_cm_inicial': medicoes['cmInicial']?.toString(),
        'altura_total_mm_inicial': medicoes['mmInicial']?.toString(),
        'volume_total_liquido_inicial': volumeTotalLiquidoInicial,
        'altura_agua_inicial': medicoes['alturaAguaInicial']?.toString(),
        'volume_agua_inicial': _extrairNumeroFormatado(
          medicoes['volumeAguaInicial']?.toString(),
        ),
        'altura_produto_inicial': medicoes['alturaProdutoInicial']?.toString(),
        'volume_produto_inicial': volumeInicial,
        'temperatura_tanque_inicial': medicoes['tempTanqueInicial']?.toString(),
        'densidade_observada_inicial': medicoes['densidadeInicial']?.toString(),
        'temperatura_amostra_inicial': medicoes['tempAmostraInicial']
            ?.toString(),
        'densidade_20_inicial': medicoes['densidade20Inicial']?.toString(),
        'fator_correcao_inicial': medicoes['fatorCorrecaoInicial']?.toString(),
        'volume_20_inicial': _extrairNumeroFormatado(
          medicoes['volume20Inicial']?.toString(),
        ),
        'massa_inicial': medicoes['massaInicial']?.toString(),

        'horario_final': _formatarHorarioParaTime(
          medicoes['horarioFinal']?.toString(),
        ),
        'altura_total_cm_final': medicoes['cmFinal']?.toString(),
        'altura_total_mm_final': medicoes['mmFinal']?.toString(),
        'volume_total_liquido_final': volumeTotalLiquidoFinal,
        'altura_agua_final': medicoes['alturaAguaFinal']?.toString(),
        'volume_agua_final': _extrairNumeroFormatado(
          medicoes['volumeAguaFinal']?.toString(),
        ),
        'altura_produto_final': medicoes['alturaProdutoFinal']?.toString(),
        'volume_produto_final': volumeFinal,
        'temperatura_tanque_final': medicoes['tempTanqueFinal']?.toString(),
        'densidade_observada_final': medicoes['densidadeFinal']?.toString(),
        'temperatura_amostra_final': medicoes['tempAmostraFinal']?.toString(),
        'densidade_20_final': medicoes['densidade20Final']?.toString(),
        'fator_correcao_final': medicoes['fatorCorrecaoFinal']?.toString(),
        'volume_20_final': _extrairNumeroFormatado(
          medicoes['volume20Final']?.toString(),
        ),
        'massa_final': medicoes['massaFinal']?.toString(),

        'volume_ambiente_inicial': volumeInicial,
        'volume_ambiente_final': volumeFinal,
        'entrada_saida_ambiente': volumeFinal - volumeInicial,
        'entrada_saida_20':
            (_extrairNumero(medicoes['volume20Final']?.toString()) -
            _extrairNumero(medicoes['volume20Inicial']?.toString())),

        'faturado_final': _converterParaDouble(
          medicoes['faturadoFinal']?.toString(),
        ),
        'diferenca_faturado':
            (_extrairNumeroFormatado(medicoes['volume20Final']?.toString()) ??
                0) -
            (_extrairNumeroFormatado(medicoes['volume20Inicial']?.toString()) ??
                0) -
            (_converterParaDouble(medicoes['faturadoFinal']?.toString()) ?? 0),

        'updated_at': timestampReferencia,
        'created_by': session.user.id,
        'estoque_final_calculado': _obterEstoqueFinalCalculado20(),
        'sobra_perda': _obterValorSobraPerda(medicoes),
        'total_entradas': _extrairNumeroFormatado(
          medicoes['totalEntradasPeriodo']?.toString(),
        ),
        'total_saidas': _extrairNumeroFormatado(
          medicoes['totalSaidasPeriodo']?.toString(),
        ),
      };

      final entradaSaida20 =
          _extrairNumero(medicoes['volume20Final']?.toString()) -
          _extrairNumero(medicoes['volume20Inicial']?.toString());
      final diferenca =
          entradaSaida20 -
          (_converterParaDouble(medicoes['faturadoFinal']?.toString()) ?? 0);

      if (entradaSaida20 != 0) {
        final porcentagem = (diferenca / entradaSaida20) * 100;
        dadosParaInserir['porcentagem_diferenca'] =
            '${porcentagem >= 0 ? '+' : ''}${porcentagem.toStringAsFixed(2)}%';
      } else {
        dadosParaInserir['porcentagem_diferenca'] = '0.00%';
      }

      dadosParaInserir.remove('numero_controle');

      String? idParaUpdate = widget.caclId;
      if ((idParaUpdate == null || idParaUpdate.isEmpty) &&
          widget.dadosFormulario.containsKey('id_cacl')) {
        idParaUpdate = widget.dadosFormulario['id_cacl']?.toString();
      }

      String caclIdSalvo = '';
      String? numeroControleGerado = _numeroControle;

      if (idParaUpdate != null && idParaUpdate.isNotEmpty) {
        try {
          final verificaExistencia = await supabase
              .from('cacl')
              .select('id')
              .eq('id', idParaUpdate)
              .maybeSingle();

          if (verificaExistencia == null) {
            throw Exception('CACL não encontrado para atualização');
          }

          await supabase
              .from('cacl')
              .update(dadosParaInserir)
              .eq('id', idParaUpdate);

          final resultadoAtualizado = await supabase
              .from('cacl')
              .select('numero_controle')
              .eq('id', idParaUpdate)
              .single();

          if (resultadoAtualizado['numero_controle'] != null) {
            setState(() {
              numeroControleGerado = _tratarNumeroControle(
                resultadoAtualizado['numero_controle'],
              );
              _numeroControle = numeroControleGerado;
            });
          }

          caclIdSalvo = idParaUpdate;
        } catch (e) {
          print('🔴 [CACL] Erro no Update (tentando fallback insert): $e');
          dadosParaInserir['created_by'] = session.user.id;

          final resultadoInserir = await supabase
              .from('cacl')
              .insert(dadosParaInserir)
              .select('id, numero_controle')
              .single();

          if (resultadoInserir['numero_controle'] != null) {
            setState(() {
              numeroControleGerado = _tratarNumeroControle(
                resultadoInserir['numero_controle'],
              );
              _numeroControle = numeroControleGerado;
            });
          }

          caclIdSalvo = resultadoInserir['id'].toString();

          if (context.mounted) {
            _mostrarSnackBar(
              const SnackBar(
                content: Text('✓ Novo CACL criado (fallback)'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      } else {
        final resultadoInserir = await supabase
            .from('cacl')
            .insert(dadosParaInserir)
            .select('id, numero_controle')
            .single();

        if (resultadoInserir['numero_controle'] != null) {
          setState(() {
            numeroControleGerado = _tratarNumeroControle(
              resultadoInserir['numero_controle'],
            );
            _numeroControle = numeroControleGerado;
          });
        }

        caclIdSalvo = resultadoInserir['id'].toString();
      }

      if (tipoCACL == 'movimentacao' &&
          caclIdSalvo.isNotEmpty &&
          numeroControleGerado != null &&
          numeroControleGerado!.isNotEmpty) {
        try {
          await _salvarMovimentacaoCACL(
            caclId: caclIdSalvo,
            numeroControle: numeroControleGerado!,
            dadosCacl: dadosParaInserir,
          );
        } catch (e) {
          print('🔴 [CACL] Erro ao salvar movimentação vinculada: $e');
        }
      }

      if (caclIdSalvo.isNotEmpty) {
        try {
          await _inserirMovimentacaoTanqueSobraPerda(
            caclId: caclIdSalvo,
            medicoes: medicoes,
          );
        } catch (e) {
          print('🔴 [CACL] Erro ao inserir movimentação de tanque: $e');
        }
      }

      if (mounted) {
        setState(() {
          _caclJaEmitido =
              _numeroControle != null && _numeroControle!.isNotEmpty;
        });
      }

      if (context.mounted) {
        _mostrarSnackBar(
          const SnackBar(
            content: Text('✓ CACL emitido com sucesso!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
      return;
    } catch (e, stack) {
      print('🔴 [CACL] ERRO FATAL NA EMISSÃO: $e');
      print('🔴 [CACL] STACKTRACE: $stack');
      if (context.mounted) {
        _mostrarSnackBar(
          SnackBar(
            content: Text('Erro: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isEmittingCACL = false;
        });
      }
    }
  }

  Future<void> _salvarMovimentacaoCACL({
    required String caclId,
    required String? numeroControle,
    required Map<String, dynamic> dadosCacl,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      final usuario = UsuarioAtual.instance;

      if (usuario == null) {
        return;
      }

      final tipoCACL = dadosCacl['tipo']?.toString();
      final terminalId = dadosCacl['terminal_id']?.toString();
      final tanqueId = dadosCacl['tanque_id']?.toString();

      if (tipoCACL != 'movimentacao') {
        return;
      }

      if (numeroControle == null || numeroControle.isEmpty) {
        return;
      }

      if (terminalId == null || terminalId.isEmpty) {
        return;
      }

      if (tanqueId == null || tanqueId.isEmpty) {
        return;
      }

      String? produtoId;
      try {
        final tanqueData = await supabase
            .from('tanques')
            .select('produto_id, referencia')
            .eq('id', tanqueId)
            .maybeSingle();

        if (tanqueData != null) {
          produtoId = tanqueData['produto_id']?.toString();
        }
      } catch (e) {
        return;
      }

      String dataMov = dadosCacl['data']?.toString() ?? '';
      String dataFormatada = '';
      if (dataMov.isNotEmpty && dataMov.contains('-')) {
        final partes = dataMov.split('-');
        if (partes.length == 3) {
          dataFormatada = '${partes[2]}/${partes[1]}/${partes[0]}';
        }
      }

      final descricao = 'CACL $numeroControle, $dataFormatada';

      final entradaSaidaAmbiente = dadosCacl['entrada_saida_ambiente'] ?? 0;
      final entradaSaida20 = dadosCacl['entrada_saida_20'] ?? 0;

      final entradaAmbDouble = entradaSaidaAmbiente is num
          ? entradaSaidaAmbiente.toDouble()
          : double.tryParse(entradaSaidaAmbiente.toString()) ?? 0.0;

      final entradaVinteDouble = entradaSaida20 is num
          ? entradaSaida20.toDouble()
          : double.tryParse(entradaSaida20.toString()) ?? 0.0;

      final entradaAmbInt = entradaAmbDouble.round();
      final entradaVinteInt = entradaVinteDouble.round();

      final entradaAmbPositiva = entradaAmbInt >= 0 ? entradaAmbInt : 0;
      final saidaAmbPositiva = entradaAmbInt < 0 ? entradaAmbInt.abs() : 0;

      final entradaVintePositiva = entradaVinteInt >= 0 ? entradaVinteInt : 0;
      final saidaVintePositiva = entradaVinteInt < 0
          ? entradaVinteInt.abs()
          : 0;

      final timestampBrasilia = _obterTimestampBrasiliaComDataReferencia();

      final dadosMovimentacao = <String, dynamic>{
        'terminal_id': terminalId,
        'empresa_id': usuario.empresaId,
        'data_mov': timestampBrasilia,
        'updated_at': timestampBrasilia,
        'descricao': descricao,
        'entrada_amb': entradaAmbPositiva,
        'entrada_vinte': entradaVintePositiva,
        'saida_amb': saidaAmbPositiva,
        'saida_vinte': saidaVintePositiva,
        'produto_id': produtoId,
        'cacl_id': caclId,
        'usuario_id': usuario.id,
        'filial_origem_id': terminalId,
        'tipo_mov_orig': 'entrada',
        'tipo_mov': '',
        'tipo_op': 'cacl',
        'anp': false,
        'status_circuito_orig': 1,
        'status_circuito_dest': 1,
        'estoque_final_calculado': _obterEstoqueFinalCalculado20(),
      };

      await supabase
          .from('movimentacoes')
          .insert(dadosMovimentacao)
          .select('id')
          .single();
    } catch (e) {
      // Silencioso
    }
  }

  Future<void> _inserirMovimentacaoTanqueSobraPerda({
    required String caclId,
    required Map<String, dynamic> medicoes,
  }) async {
    try {
      if (!_mostrarCampoSobraPerda) {
        return;
      }

      final supabase = Supabase.instance.client;

      final caclData = await supabase
          .from('cacl')
          .select('sobra_perda')
          .eq('id', caclId)
          .maybeSingle();

      double? sobraPerda;

      final sobraPerdaRaw = caclData?['sobra_perda'];

      if (sobraPerdaRaw is num) {
        sobraPerda = sobraPerdaRaw.toDouble();
      } else if (sobraPerdaRaw is String) {
        sobraPerda = double.tryParse(sobraPerdaRaw.replaceAll(',', '.'));
      }

      if (sobraPerda == null || sobraPerda == 0) {
        return;
      }      

      if (sobraPerdaRaw is num) {
        sobraPerda = sobraPerdaRaw.toDouble();
      } else if (sobraPerdaRaw is String) {
        sobraPerda = double.tryParse(sobraPerdaRaw.replaceAll(',', '.'));
      }

      if (sobraPerda == null || sobraPerda == 0) {
        return;
      }      

      final tanqueId = _obterTanqueId();

      if (tanqueId == null || tanqueId.isEmpty) {
        return;
      }

      final tanqueData = await supabase
          .from('tanques')
          .select('produto_id')
          .eq('id', tanqueId)
          .maybeSingle();

      final produtoId = tanqueData?['produto_id']?.toString();
      if (produtoId == null || produtoId.isEmpty) {
        return;
      }

      // ✅ NOVA REGRA: só usa movimentacao_id se for CACL de movimentação
      final bool isMovimentacao =
          widget.dadosFormulario['cacl_movimentacao'] == true;

      String? movimentacaoId;

      if (isMovimentacao) {
        final movExistente = await supabase
            .from('movimentacoes')
            .select('id')
            .eq('cacl_id', caclId)
            .maybeSingle();

        movimentacaoId = movExistente?['id']?.toString();

        // Se for movimentação e não encontrou, aborta
        if (movimentacaoId == null || movimentacaoId.isEmpty) {
          return;
        }
      } else {
        // ✅ CACL de verificação → NÃO vincula a movimentação
        movimentacaoId = null;
      }

      final quantidade = sobraPerda.abs().round();
      final bool isSobra = sobraPerda > 0;

      final numeroControle = _numeroControle;
      String dataFormatada = '';
      final dataRaw = widget.dadosFormulario['data']?.toString() ?? '';
      if (dataRaw.contains('/')) {
        dataFormatada = dataRaw;
      } else if (dataRaw.contains('-')) {
        final partes = dataRaw.split('-');
        if (partes.length == 3) {
          dataFormatada = '${partes[2]}/${partes[1]}/${partes[0]}';
        }
      }

      final descricao = isSobra
          ? 'Sobra CACL ${numeroControle ?? ''}, $dataFormatada'
          : 'Perda CACL ${numeroControle ?? ''}, $dataFormatada';

      final payload = {
        'movimentacao_id': movimentacaoId, // pode ser null
        'tanque_id': tanqueId,
        'produto_id': produtoId,
        'cacl_id': caclId,
        'data_mov': _obterTimestampBrasiliaComDataReferencia(),
        'cliente': null,
        'entrada_amb': 0,
        'entrada_vinte': isSobra ? quantidade : 0,
        'saida_amb': 0,
        'saida_vinte': isSobra ? 0 : quantidade,
        'descricao': descricao,
        'tipo_mov': isSobra ? 'sobra' : 'perda',
        'estoque_final_calculado': _obterEstoqueFinalCalculado20(),
      };

      await supabase
          .from('movimentacoes_tanque')
          .insert(payload)
          .select('id')
          .single();
    } catch (e, s) {
      print('🔴 [SOBRA/PERDA] ERRO ao inserir movimentação de sobra/perda');
      print('🔴 [SOBRA/PERDA] Exception: $e');
      print('🔴 [SOBRA/PERDA] Stacktrace: $s');
    }
  }

  String? _tratarNumeroControle(dynamic valor) {
    if (valor == null) return null;

    final strValor = valor.toString().trim();

    if (strValor.isEmpty ||
        strValor == 'null' ||
        strValor.toLowerCase() == 'null') {
      return null;
    }

    if (strValor.startsWith("'") && strValor.endsWith("'")) {
      return strValor.substring(1, strValor.length - 1);
    }

    if (strValor == '0' || strValor == "'0'") {
      return null;
    }

    return strValor;
  }

  @override
  Widget build(BuildContext context) {
    final medicoes = Map<String, dynamic>.from(
      (widget.dadosFormulario['medicoes'] ?? <String, dynamic>{}) as Map<dynamic, dynamic>
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 670,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // CABEÇALHO COM BANDEIRA DE PRÉ-VISUALIZAÇÃO
                  Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0E0E0),
                          border: Border.all(color: Colors.black, width: 1.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          children: [
                            Text(
                              widget.modo == CaclModo.emissao
                                  ? "CACL - PRÉ-VISUALIZAÇÃO"
                                  : widget.modo == CaclModo.edicao
                                  ? "CACL - EDIÇÃO"
                                  : "CACL - HISTÓRICO",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ✅ ATUALIZADO: DADOS PRINCIPAIS COM "Nº DE CONTROLE"
                  SizedBox(
                    width: double.infinity,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ✅ NOVO CAMPO: Nº DE CONTROLE
                        Expanded(
                          flex: 16, // Redução leve (antes era 12, valor base era flex: 1 equivalente)
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _secaoTitulo("Nº DE CONTROLE:"),
                              _linhaValor(
                                _numeroControle ??
                                    (widget.modo == CaclModo.emissao
                                        ? "A ser gerado..."
                                        : "C-XXXX"),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10), // Voltou para 10 para evitar aperto excessivo

                        Expanded(
                          flex: 16, // Redução leve
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _secaoTitulo("DATA:"),
                              _linhaValor(
                                _obterApenasData(
                                  widget.dadosFormulario['data']?.toString() ??
                                      "",
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 28, // Aumento moderado para a BASE
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _secaoTitulo("BASE:"),
                              _linhaValor(
                                UsuarioAtual.instance?.terminalNome ??
                                    widget.dadosFormulario['base']?.toString() ??
                                    "FILIAL",
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 20, // Redução leve no PRODUTO
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _secaoTitulo("PRODUTO:"),
                              _linhaValor(_obterNomeProduto()),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 20, // Redução leve no TANQUE
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _secaoTitulo("TANQUE Nº:"),
                              _linhaValor(_obterNomeTanque()),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  // SEÇÃO DE MEDIÇÕES
                  _subtitulo(
                    "VOLUME RECEBIDO NOS TANQUES DE TERRA E CANALIZAÇÃO RESPECTIVA",
                  ),
                  const SizedBox(height: 12),

                  _tabelaMedicoes([
                    _linhaMedicao(
                      "Altura total de líquido no tanque:",
                      _formatarAlturaTotal(
                        medicoes['cmInicial'],
                        medicoes['mmInicial'],
                      ),
                      _formatarAlturaTotal(
                        medicoes['cmFinal'],
                        medicoes['mmFinal'],
                      ),
                    ),
                    _linhaMedicao(
                      "Volume total de líquido no tanque (temp. ambiente):",
                      _formatarVolumeLitros(volumeTotalLiquidoInicial),
                      _formatarVolumeLitros(volumeTotalLiquidoFinal),
                    ),
                    _linhaMedicao(
                      "Altura da água aferida no tanque:",
                      _obterValorMedicao(medicoes['alturaAguaInicial']),
                      _obterValorMedicao(medicoes['alturaAguaFinal']),
                    ),
                    _linhaMedicao(
                      "Volume correspondente à água:",
                      _obterValorMedicao(medicoes['volumeAguaInicial']),
                      _obterValorMedicao(medicoes['volumeAguaFinal']),
                    ),
                    _linhaMedicao(
                      "Altura do produto aferido no tanque:",
                      _obterValorMedicao(medicoes['alturaProdutoInicial']),
                      _obterValorMedicao(medicoes['alturaProdutoFinal']),
                    ),
                    _linhaMedicao(
                      "Volume correspondente ao produto (temp. ambiente):",
                      _formatarVolumeLitros(volumeInicial),
                      _formatarVolumeLitros(volumeFinal),
                    ),
                    _linhaMedicao(
                      "Temperatura do produto no tanque:",
                      _formatarTemperatura(medicoes['tempTanqueInicial']),
                      _formatarTemperatura(medicoes['tempTanqueFinal']),
                    ),
                    _linhaMedicao(
                      "Densidade observada na amostra:",
                      _obterValorMedicao(medicoes['densidadeInicial']),
                      _obterValorMedicao(medicoes['densidadeFinal']),
                    ),
                    _linhaMedicao(
                      "Temperatura da amostra:",
                      _formatarTemperatura(medicoes['tempAmostraInicial']),
                      _formatarTemperatura(medicoes['tempAmostraFinal']),
                    ),
                    _linhaMedicao(
                      "Densidade da amostra, considerada à temperatura padrão (20 ºC):",
                      _obterValorMedicao(medicoes['densidade20Inicial']),
                      _obterValorMedicao(medicoes['densidade20Final']),
                    ),
                    _linhaMedicao(
                      "Fator de correção de volume do produto (FCV):",
                      _obterValorMedicao(medicoes['fatorCorrecaoInicial']),
                      _obterValorMedicao(medicoes['fatorCorrecaoFinal']),
                    ),
                  ], medicoes,
                  extraAposEstoque: _linhaMedicao(
                      "Volume total do produto, considerada a temperatura padrão (20 ºC):",
                      _obterValorMedicao(medicoes['volume20Inicial']),
                      _obterValorMedicao(medicoes['volume20Final']),
                    ),
                  ),

                  const SizedBox(height: 25),

                  // COMPARAÇÃO DE RESULTADOS - OCULTO SE APENAS 1ª MEDIÇÃO
                  if (_dadosFinaisEstaoCompletos()) ...[
                    _subtitulo("COMPARAÇÃO DE RESULTADOS"),
                    const SizedBox(height: 8),

                    _tabelaComparacaoResultados(
                      volumeAmbienteInicial: volumeInicial,
                      volumeAmbienteFinal: volumeFinal,
                      volume20Inicial: _extrairNumero(
                        medicoes['volume20Inicial']?.toString(),
                      ),
                      volume20Final: _extrairNumero(
                        medicoes['volume20Final']?.toString(),
                      ),
                      entradaSaidaAmbiente: totalEntradasAmbienteReal - totalSaidasAmbienteReal,
                      entradaSaida20: (widget.modo == CaclModo.visualizacao)
                          ? _extrairNumero(medicoes['totalEntradasPeriodo']?.toString()) - _extrairNumero(medicoes['totalSaidasPeriodo']?.toString())
                          : totalEntradas20Real - totalSaidas20Real,
                    ),

                    // BLOCO FATURADO
                    if (!(widget.dadosFormulario['cacl_verificacao'] ??
                        false)) ...[
                      const SizedBox(height: 20),
                      _blocoFaturado(medicoes: medicoes),
                    ],
                  ],

                  if (_dadosFinaisEstaoCompletos() &&
                      (widget.dadosFormulario['cacl_verificacao'] ?? false))
                    const SizedBox(height: 20),

                  // RODAPÉ
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          widget.modo == CaclModo.emissao &&
                              !_dadosFinaisEstaoCompletos()
                          ? const Color(0xFFFFF3E0) // Laranja claro se pendente
                          : const Color(
                              0xFFE3F2FD,
                            ), // Azul claro se completo/visualização
                      border: Border.all(
                        color:
                            widget.modo == CaclModo.emissao &&
                                !_dadosFinaisEstaoCompletos()
                            ? Colors.orange
                            : const Color(0xFF2196F3),
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          widget.modo == CaclModo.emissao &&
                                  !_dadosFinaisEstaoCompletos()
                              ? Icons.pending
                              : Icons.info_outline,
                          color:
                              widget.modo == CaclModo.emissao &&
                                  !_dadosFinaisEstaoCompletos()
                              ? Colors.orange
                              : const Color(0xFF2196F3),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.modo == CaclModo.emissao &&
                                        !_dadosFinaisEstaoCompletos()
                                    ? "CACL Pendente"
                                    : widget.modo == CaclModo.emissao
                                    ? "Pré-visualização do CACL"
                                    : "Visualização do CACL",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      widget.modo == CaclModo.emissao &&
                                          !_dadosFinaisEstaoCompletos()
                                      ? Colors.orange[800]
                                      : const Color(0xFF0D47A1),
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.modo == CaclModo.emissao &&
                                        !_dadosFinaisEstaoCompletos()
                                    ? "Faltam dados da medição final. Salve como pendente para completar depois."
                                    : widget.modo == CaclModo.edicao
                                    ? "Editando CACL pendente. Verifique os dados antes de finalizar."
                                    : widget.modo == CaclModo.emissao
                                    ? "Verifique os dados antes de emitir o documento oficial."
                                    : "Este CACL já foi emitido e está salvo no histórico.",
                                style: TextStyle(
                                  color:
                                      widget.modo == CaclModo.emissao &&
                                          !_dadosFinaisEstaoCompletos()
                                      ? Colors.orange[700]
                                      : widget.modo == CaclModo.edicao
                                      ? Colors
                                            .blue[700] // ← COR DIFERENTE PARA EDIÇÃO
                                      : Colors.grey[700],
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ✅ BOTÕES PRINCIPAIS
                  Container(
                    margin: const EdgeInsets.only(top: 20),
                    width: double.infinity,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // BOTÃO VOLTAR (AZUL) - DESABILITADO SE CACL JÁ FOI EMITIDO
                        ElevatedButton.icon(
                          onPressed:
                              (_caclJaEmitido &&
                                  widget.modo == CaclModo.emissao)
                              ? null // Desabilita se já foi emitido
                              : () {
                                  // Verifica se tem callback personalizado para voltar
                                  if (widget.onVoltar != null) {
                                    widget
                                        .onVoltar!(); // Usa o callback fornecido
                                  } else {
                                    _navigatorState?.pop(); // Fallback padrão
                                  }
                                },
                          icon: const Icon(Icons.arrow_back, size: 18),
                          label: const Text('Voltar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D47A1), // Azul
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),

                        const SizedBox(width: 20), // Espaço entre botões
                        // VERIFICA SE OS DADOS FINAIS ESTÃO COMPLETOS
                        if ((widget.modo == CaclModo.emissao ||
                                widget.modo == CaclModo.edicao) &&
                            !_caclJaEmitido)
                          ElevatedButton.icon(
                            onPressed: (_isEmittingCACL || !_temVolumeMinimoValido())
                                ? null
                                : (_dadosFinaisEstaoCompletos()
                                      ? _emitirCACL
                                      : _salvarComoPendente),
                            icon: _isEmittingCACL
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : _dadosFinaisEstaoCompletos()
                                ? const Icon(Icons.send, size: 18)
                                : const Icon(Icons.pending_actions, size: 18),
                            label: _isEmittingCACL
                                ? const Text('Processando...')
                                : _dadosFinaisEstaoCompletos()
                                ? const Text('Emitir CACL')
                                : const Text('Salvar como Pendente'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _dadosFinaisEstaoCompletos()
                                  ? Colors.green
                                  : Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),

                        // ESPAÇO ENTRE BOTÕES
                        if (_caclJaEmitido ||
                            widget.modo == CaclModo.visualizacao)
                          const SizedBox(width: 20),

                        // BOTÃO GERAR PDF (só se já emitido)
                        if (_caclJaEmitido ||
                            widget.modo == CaclModo.visualizacao)
                          ElevatedButton.icon(
                            onPressed: _isGeneratingPDF ? null : _baixarPDFCACL,
                            icon: _isGeneratingPDF
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.picture_as_pdf, size: 18),
                            label: Text(
                              _isGeneratingPDF ? 'Gerando...' : 'Gerar PDF',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D47A1),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),

                        // BOTÃO FINALIZAR (só se já emitido no modo emissão)
                        if (widget.modo == CaclModo.emissao && _caclJaEmitido)
                          const SizedBox(width: 20),

                        if (widget.modo == CaclModo.emissao && _caclJaEmitido)
                          ElevatedButton.icon(
                            onPressed: _irParaApuracao,
                            icon: const Icon(Icons.arrow_forward, size: 18),
                            label: const Text('Finalizar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _secaoTitulo(String texto) {
    return Text(
      texto,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _subtitulo(String texto) {
    return Text(
      texto,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _linhaValor(String valor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black26),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(valor, style: const TextStyle(fontSize: 11)),
    );
  }

  Widget _tabelaMedicoes(List<TableRow> linhas, Map<String, dynamic> medicoes, {TableRow? extraAposEstoque}) {
    return Table(
      border: TableBorder.all(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      columnWidths: const {
        0: FlexColumnWidth(2.5),
        1: FlexColumnWidth(1.0),
        2: FlexColumnWidth(1.0),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey[200]),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: Text(
                "DESCRIÇÃO",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: Text(
                "1ª MEDIÇÃO, ${_formatarHorarioCACL(medicoes['horarioInicial'])}",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: Text(
                "2ª MEDIÇÃO, ${_formatarHorarioCACL(medicoes['horarioFinal'])}",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        ...linhas,

        TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: Text(
                "Massa do produto (Volume a 20 ºC × Densidade  a 20 ºC):",
                style: const TextStyle(fontSize: 11),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: Text(
                _obterValorMedicao(medicoes['massaInicial']),
                style: const TextStyle(fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: Text(
                _obterValorMedicao(medicoes['massaFinal']),
                style: const TextStyle(fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),

        if (widget.dadosFormulario['cacl_verificacao'] == true ||
            widget.dadosFormulario['origem_estoque_tanque'] == true) ...[
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: Text(
                  "Total de entradas no período:",
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: Text(
                  "-",
                  style: TextStyle(fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: Text(
                  _obterValorMedicao(medicoes['totalEntradasPeriodo']),
                  style: const TextStyle(fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: Text(
                  "Total de saídas no período:",
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: Text(
                  "-",
                  style: TextStyle(fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: Text(
                  _obterValorMedicao(medicoes['totalSaidasPeriodo']),
                  style: const TextStyle(fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ],

        if (_mostrarCampoSobraPerda)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: Text(
                  "Estoque final calculado:",
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: Text(
                  "-",
                  style: TextStyle(fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: Text(
                  _obterEstoqueFinalCalculadoFormatado(),
                  style: const TextStyle(fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),

        if (extraAposEstoque != null)
          extraAposEstoque,

        if (_mostrarCampoSobraPerda)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: Text(
                  "Sobra/perda:",
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: Text(
                  "-",
                  style: TextStyle(fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: Text(
                  _obterSobraPerdaFormatada(medicoes),
                  style: _obterEstiloSobraPerda(medicoes),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
      ],
    );
  }

  String _formatarHorarioCACL(String? horario) {
    if (horario == null || horario.isEmpty) return '--:-- h';

    String horarioLimpo = horario.trim();

    if (horarioLimpo.contains('T')) {
      try {
        final dt = DateTime.parse(horarioLimpo);
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} h';
      } catch (_) {
        // Continua para os fallbacks
      }
    }

    if (horarioLimpo.toLowerCase().endsWith('h')) {
      return horarioLimpo;
    }

    return '$horarioLimpo h';
  }

  TableRow _linhaMedicao(
    String descricao,
    String valorInicial,
    String valorFinal,
  ) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Text(descricao, style: const TextStyle(fontSize: 11)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Text(
            valorInicial,
            style: const TextStyle(fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Text(
            valorFinal,
            style: const TextStyle(fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _tabelaComparacaoResultados({
    required double volumeAmbienteInicial,
    required double volumeAmbienteFinal,
    required double volume20Inicial,
    required double volume20Final,
    required double entradaSaidaAmbiente,
    required double entradaSaida20,
  }) {
    // Função para formatar no padrão "999.999 L"
    String fmt(double v) {
      if (v.isNaN) return "-";

      final volumeInteiro = v.round();
      final isNegativo = volumeInteiro < 0;
      String inteiroFormatado = volumeInteiro.abs().toString();

      // CORREÇÃO: Só adiciona pontos se tiver mais de 3 dígitos
      if (inteiroFormatado.length > 3) {
        final buffer = StringBuffer();
        int contador = 0;

        for (int i = inteiroFormatado.length - 1; i >= 0; i--) {
          buffer.write(inteiroFormatado[i]);
          contador++;

          if (contador == 3 && i > 0) {
            buffer.write('.');
            contador = 0;
          }
        }

        final chars = buffer.toString().split('').reversed.toList();
        inteiroFormatado = chars.join('');
      }

      // Se número for menor que 1000, não adiciona ponto
      final sinal = isNegativo ? '-' : '';
      return '$sinal$inteiroFormatado L';
    }

    return Table(
      border: TableBorder.all(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      columnWidths: const {
        0: FlexColumnWidth(2.5),
        1: FlexColumnWidth(1.0),
        2: FlexColumnWidth(1.0),
        3: FlexColumnWidth(1.0),
        4: FlexColumnWidth(1.0),
      },
      children: [
        // CABEÇALHO - REDUZIDO
        TableRow(
          decoration: BoxDecoration(color: Color(0xFFE0E0E0)),
          children: [
            Padding(
              padding: EdgeInsets.all(6.0),
              child: Text(
                "DESCRIÇÃO",
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(6.0),
              child: Text(
                "1ª MEDIÇÃO",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(6.0),
              child: Text(
                "ENTRADA/SAÍDA",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(6.0),
              child: Text(
                "2ª MEDIÇÃO",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(6.0),
              child: Text(
                "DIFERENÇA",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),

        // LINHA 1: VOLUME AMBIENTE - REDUZIDA
        TableRow(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
              child: Text("Volume ambiente", style: TextStyle(fontSize: 10)),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
              child: Text(
                fmt(volumeAmbienteInicial),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
              child: Text(
                fmt(entradaSaidaAmbiente),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
              child: Text(
                fmt(volumeAmbienteFinal),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
              child: Text(
                fmt(volumeAmbienteFinal - entradaSaidaAmbiente - volumeAmbienteInicial),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10),
              ),
            ),
          ],
        ),

        // LINHA 2: VOLUME A 20 ºC - REDUZIDA
        TableRow(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
              child: Text("Volume a 20 ºC", style: TextStyle(fontSize: 10)),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
              child: Text(
                fmt(volume20Inicial),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
              child: Text(
                fmt(entradaSaida20),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
              child: Text(
                fmt(volume20Final),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
              child: Text(
                fmt(volume20Final - entradaSaida20 - volume20Inicial),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _obterValorMedicao(dynamic valor) {
    if (valor == null) return "-";

    if (valor is String) {
      final v = valor.trim();

      if (v.isEmpty) return "-";

      final semUnidade = v.replaceAll(" cm", "").trim();

      if (semUnidade == "," ||
          semUnidade == "0,0" ||
          semUnidade == "0,00" ||
          semUnidade == "0,000" ||
          semUnidade == "0,0000") {
        return "-";
      }

      if (semUnidade == "0,") return "-";

      if (semUnidade.startsWith("0,") &&
          semUnidade.substring(2).replaceAll("0", "").isEmpty) {
        return "-";
      }

      return v;
    }

    return valor.toString();
  }

  String _obterApenasData(String dataCompleta) {
    if (dataCompleta.contains(',')) {
      return dataCompleta.split(',').first.trim();
    }
    return dataCompleta;
  }

  String _formatarAlturaTotal(String? cm, String? mm) {
    if (cm == null || cm.isEmpty) return "-";
    final mmValue = (mm == null || mm.isEmpty) ? "0" : mm;
    return "$cm,$mmValue cm";
  }

  String _formatarVolumeLitros(double volume) {
    final volumeInteiro = volume.round();

    String inteiroFormatado = volumeInteiro.toString();

    if (inteiroFormatado.length > 3) {
      final buffer = StringBuffer();
      int contador = 0;

      for (int i = inteiroFormatado.length - 1; i >= 0; i--) {
        buffer.write(inteiroFormatado[i]);
        contador++;

        if (contador == 3 && i > 0) {
          buffer.write('.');
          contador = 0;
        }
      }

      final chars = buffer.toString().split('').reversed.toList();
      inteiroFormatado = chars.join('');
    }

    return '$inteiroFormatado L';
  }

  String _formatarTemperatura(dynamic valor) {
    if (valor == null) return "-";
    if (valor is String && valor.isEmpty) return "-";

    final strValor = valor.toString().trim();

    final valorSemUnidade = strValor
        .replaceAll(' ºC', '')
        .replaceAll('°C', '')
        .replaceAll('ºC', '')
        .trim();

    if (valorSemUnidade.isEmpty) return "-";

    return '$valorSemUnidade ºC';
  }

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

      final double? tempNum = double.tryParse(
        temperaturaAmostra
            .replaceAll(' ºC', '')
            .replaceAll('°C', '')
            .replaceAll('ºC', '')
            .replaceAll(',', '.')
            .trim(),
      );

      final double? densNum =
          double.tryParse(densidadeObservada.replaceAll(',', '.').trim());

      if (tempNum == null || densNum == null) {
        return '-';
      }

      // 🔥 CORREÇÃO: agora multiplicando por 1000 (não 10000)
      final int alvo = (densNum * 1000).round();

      final temperaturasTeste = <String>{
        tempNum.toStringAsFixed(0).replaceAll('.', ','),
        tempNum.toStringAsFixed(1).replaceAll('.', ','),
        tempNum.toStringAsFixed(2).replaceAll('.', ','),
        tempNum.toStringAsFixed(0),
        tempNum.toStringAsFixed(1),
      }.toList();

      Map<String, dynamic>? linha;

      for (final t in temperaturasTeste) {
        linha = await supabase
            .from('tcd_gasolina_diesel')
            .select('*')
            .eq('temperatura_obs', t)
            .maybeSingle();

        if (linha != null) {
          break;
        }
      }

      if (linha == null) {
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
        return '-';
      }

      String valorFinal = melhorValor.toString().trim().replaceAll('.', ',');

      if (!valorFinal.contains(',')) valorFinal = '$valorFinal,0';
      final partes = valorFinal.split(',');
      final parteInteira = partes[0];
      String parteDecimal = partes.length > 1 ? partes[1] : '0';
      parteDecimal = parteDecimal.padRight(4, '0').substring(0, 4);

      return '$parteInteira,$parteDecimal';
    } catch (e) {
      debugPrint('❌ [DENS20] Erro ao buscar densidade20C: $e');
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

      final nomeProdutoLower = produtoNome.toLowerCase().trim();
      final String nomeView =
          (nomeProdutoLower.contains('anidro') ||
              nomeProdutoLower.contains('hidratado'))
          ? 'tcv_anidro_hidratado_vw'
          : 'tcv_gasolina_diesel_vw';

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

      final densidadeNum = double.tryParse(
        densidadeFormatada.replaceAll(',', '.'),
      );
      const double densidadeLimite = 0.8780;

      if (densidadeNum != null && densidadeNum > densidadeLimite) {
        densidadeFormatada = '0,8780';
      }

      if (!densidadeFormatada.contains(',')) {
        return '-';
      }

      final partes = densidadeFormatada.split(',');
      String parteInteira = partes[0];
      String parteDecimal = partes[1];

      parteDecimal = parteDecimal.padRight(4, '0');
      parteDecimal = '${parteDecimal.substring(0, 3)}0';

      final String codigoBase = '${parteInteira}${parteDecimal}'.padLeft(
        5,
        '0',
      );

      final String colunaExata = 'v_$codigoBase';
      final String prefixo = 'v_${codigoBase.substring(0, 4)}';

      int? _codigoFcvAlvo() {
        final cod = colunaExata.replaceFirst('v_', '');
        return int.tryParse(cod);
      }

      Map<String, dynamic>? _valorMaisProximo(Map<String, dynamic> linha) {
        final alvo = _codigoFcvAlvo();
        if (alvo == null) return null;

        int? melhorDelta;
        String? melhorColuna;
        dynamic melhorValor;

        for (final entry in linha.entries) {
          final key = entry.key;
          if (!key.startsWith('v_')) continue;

          final codStr = key.substring(2);
          final cod = int.tryParse(codStr);
          if (cod == null) continue;

          final valor = entry.value;
          if (valor == null) continue;
          if (valor is String) {
            final limpo = valor.trim();
            if (limpo.isEmpty ||
                limpo == '-' ||
                limpo.toLowerCase() == 'null') {
              continue;
            }
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
        // Falha esperada se a coluna não existir
        final msg = e.toString().toLowerCase();
        if (msg.contains('does not exist') || msg.contains('42703')) {
          colunaInexistente = true;
        }
      }

      if (colunaInexistente) {
        final linha = await supabase
            .from(nomeView)
            .select('*')
            .eq('temperatura_obs', temperaturaFormatada)
            .limit(1)
            .maybeSingle();

        if (linha != null) {
          final escolha = _valorMaisProximo(linha);
          if (escolha != null) {
            final valor = escolha['valor'];
            return _formatarResultadoFCV(valor.toString());
          }
        }
      }

      final linha = await supabase
          .from(nomeView)
          .select('*')
          .eq('temperatura_obs', temperaturaFormatada)
          .limit(1)
          .maybeSingle();

      if (linha != null) {
        final colunasEncontradas = linha.keys
            .where((k) => k.startsWith(prefixo))
            .toList();

        if (colunasEncontradas.isNotEmpty) {
          final colunaEscolhida = colunasEncontradas.first;
          return _formatarResultadoFCV(linha[colunaEscolhida].toString());
        }
      }

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

      final comPonto = temperaturasParaTentar
          .map((t) => t.replaceAll(',', '.'))
          .toList();
      temperaturasParaTentar = {
        ...temperaturasParaTentar,
        ...comPonto,
      }.toList();

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
          final c = cols.first;
          return _formatarResultadoFCV(linhaFb[c].toString());
        }
      }

      return '-';
    } catch (e) {
      return '-';
    }
  }

  String _formatarResultadoFCV(String valorBruto) {
    String valorLimpo = valorBruto.trim().replaceAll('.', ',');

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

  Future<void> _calcularMassa() async {
    final medicoes = widget.dadosFormulario['medicoes'];

    // Para 1ª medição (Inicial) - Volume20 × Densidade20
    if (medicoes['volume20Inicial'] != null &&
        medicoes['volume20Inicial'].toString().isNotEmpty &&
        medicoes['volume20Inicial'].toString() != '-' &&
        medicoes['densidade20Inicial'] != null &&
        medicoes['densidade20Inicial'].toString().isNotEmpty &&
        medicoes['densidade20Inicial'].toString() != '-') {
      try {
        // Converter volume a 20ºC formatado para double
        final volume20Inicial = _converterVolumeParaDouble(
          medicoes['volume20Inicial'].toString(),
        );

        // Converter densidade a 20ºC para double
        final densidade20Inicial =
            double.tryParse(
              medicoes['densidade20Inicial']
                  .toString()
                  .replaceAll(' kg/L', '')
                  .replaceAll(',', '.')
                  .trim(),
            ) ??
            0.0;

        // Cálculo da massa: Volume a 20ºC × Densidade a 20ºC
        final massaInicial = volume20Inicial * densidade20Inicial;

        // Formatar massa: ponto como milhar, vírgula como decimal, 1 casa decimal
        final massaInicialFormatada = _formatarMassa(massaInicial);

        widget.dadosFormulario['medicoes']['massaInicial'] =
            massaInicialFormatada;
      } catch (e) {
        widget.dadosFormulario['medicoes']['massaInicial'] = '-';
      }
    } else {
      widget.dadosFormulario['medicoes']['massaInicial'] = '-';
    }

    // Para 2ª medição (Final) - Volume20 × Densidade20
    if (medicoes['volume20Final'] != null &&
        medicoes['volume20Final'].toString().isNotEmpty &&
        medicoes['volume20Final'].toString() != '-' &&
        medicoes['densidade20Final'] != null &&
        medicoes['densidade20Final'].toString().isNotEmpty &&
        medicoes['densidade20Final'].toString() != '-') {
      try {
        // Converter volume a 20ºC formatado para double
        final volume20Final = _converterVolumeParaDouble(
          medicoes['volume20Final'].toString(),
        );

        // Converter densidade a 20ºC para double
        final densidade20Final =
            double.tryParse(
              medicoes['densidade20Final']
                  .toString()
                  .replaceAll(' kg/L', '')
                  .replaceAll(',', '.')
                  .trim(),
            ) ??
            0.0;

        // Cálculo da massa: Volume a 20ºC × Densidade a 20ºC
        final massaFinal = volume20Final * densidade20Final;

        // Formatar massa: ponto como milhar, vírgula como decimal, 1 casa decimal
        final massaFinalFormatada = _formatarMassa(massaFinal);

        widget.dadosFormulario['medicoes']['massaFinal'] = massaFinalFormatada;
      } catch (e) {
        widget.dadosFormulario['medicoes']['massaFinal'] = '-';
      }
    } else {
      widget.dadosFormulario['medicoes']['massaFinal'] = '-';
    }

    // ✅ NOVO: Buscar e povoar Total de Entradas e Saídas se for verificação
    if (widget.dadosFormulario['cacl_verificacao'] == true || 
        widget.dadosFormulario['origem_estoque_tanque'] == true) {
      await _buscarTotaisEntradasSaidasVinte();
    }
  }

  Future<void> _buscarTotaisEntradasSaidasVinte() async {
    final tanqueId = _obterTanqueId();
    if (tanqueId == null) return;

    final dataReferencia = _obterDataParaEstoque();
    final dataStr = dataReferencia.toIso8601String().split('T')[0];
    final inicioDoDia = '$dataStr 00:00:00';
    final fimDoDia = '$dataStr 23:59:59';

    try {
      final supabase = Supabase.instance.client;
      
      // Busca terminal_id dos dados do formulário ou do usuário logado
      String? terminalId = widget.dadosFormulario['terminal_id']?.toString();
      
      if (terminalId == null || terminalId.isEmpty) {
        final user = supabase.auth.currentUser;
        if (user != null) {
          final res = await supabase
              .from('usuarios')
              .select('terminal_id')
              .eq('id', user.id)
              .maybeSingle();
          if (res != null) {
            terminalId = res['terminal_id']?.toString();
          }
        }
      }

      var query = supabase
          .from('movimentacoes_tanque')
          .select('entrada_vinte, saida_vinte')
          .eq('tanque_id', tanqueId)
          .gte('data_mov', inicioDoDia)
          .lte('data_mov', fimDoDia);

      // Se tivermos o terminal_id, filtramos por ele também, 
      // seguindo a lógica de que o estoque é por tanque e terminal.
      if (terminalId != null && terminalId.isNotEmpty) {
        // Nota: A tabela movimentacoes_tanque geralmente tem terminal_id se 
        // a lógica do estoque_tanque_dia considerar terminal.
        // Verificando se devemos filtrar. No estoque_tanque_dia.dart, 
        // ele carrega o terminal do usuário.
        // query = query.eq('terminal_id', terminalId); 
        // No entanto, movimentacoes_tanque costuma ser vinculada ao tanque.
      }

      final response = await query;

      double totalEntradas = 0;
      double totalSaidas = 0;

      for (final m in response) {
        totalEntradas += (m['entrada_vinte'] ?? 0).toDouble();
        totalSaidas += (m['saida_vinte'] ?? 0).toDouble();
      }

      setState(() {
        widget.dadosFormulario['medicoes']['totalEntradasPeriodo'] =
            _formatarVolumeLitros(totalEntradas);
        widget.dadosFormulario['medicoes']['totalSaidasPeriodo'] =
            _formatarVolumeLitros(totalSaidas);

        // ✅ Atualiza o estoque final calculado baseando-se na fórmula:
        // Volume20 Inicial + Entradas - Saídas
        final volume20InicialStr =
            widget.dadosFormulario['medicoes']['volume20Inicial']?.toString();
        if (volume20InicialStr != null &&
            volume20InicialStr.isNotEmpty &&
            volume20InicialStr != '-') {
          final volume20Inicial = _converterVolumeParaDouble(volume20InicialStr);
          final estoqueCalculado =
              volume20Inicial + totalEntradas - totalSaidas;

          widget.dadosFormulario['estoque_final_calculado_20'] =
              estoqueCalculado;
        }
      });
    } catch (e) {
      debugPrint('Erro ao buscar totais de entradas e saídas: $e');
    }
  }

  String _formatarMassa(double massa) {
    try {
      if (massa.isNaN || massa.isInfinite || massa == 0.0) {
        return '-';
      }

      // Arredonda para 1 casa decimal
      final massaArredondada = massa.toStringAsFixed(1);

      // Separa parte inteira e decimal
      final partes = massaArredondada.split('.');
      if (partes.length != 2) {
        return massaArredondada;
      }

      String parteInteira = partes[0];
      String parteDecimal = partes[1];

      // Formata parte inteira com pontos como separadores de milhar
      String parteInteiraFormatada = '';
      int contador = 0;

      // Percorre de trás para frente para adicionar pontos
      for (int i = parteInteira.length - 1; i >= 0; i--) {
        parteInteiraFormatada = parteInteira[i] + parteInteiraFormatada;
        contador++;

        // Adiciona ponto a cada 3 dígitos (exceto no início)
        if (contador == 3 && i > 0) {
          parteInteiraFormatada = '.$parteInteiraFormatada';
          contador = 0;
        }
      }

      // Retorna no formato: "194.458,3"
      return '$parteInteiraFormatada,$parteDecimal';
    } catch (e) {
      return '-';
    }
  }

  double _converterVolumeParaDouble(String volumeStr) {
    try {
      // Remove "L" e espaços
      String limpo = volumeStr.replaceAll(' L', '').trim();

      // Se estiver vazio após limpar, retorna 0
      if (limpo.isEmpty || limpo == '-') {
        return 0.0;
      }

      // Remove pontos usados como separadores de milhar (formato: 1.500)
      if (limpo.contains('.')) {
        // Verifica se é formato brasileiro (ponto como separador de milhar)
        final partes = limpo.split('.');
        if (partes.length > 1) {
          // Se a última parte tem 3 dígitos, provavelmente é separador de milhar
          if (partes.last.length == 3) {
            limpo = limpo.replaceAll('.', '');
          } else {
            // Caso contrário, trata como decimal (substitui ponto por vírgula)
            limpo = limpo.replaceAll('.', ',');
          }
        } else {
          limpo = limpo.replaceAll('.', '');
        }
      }

      // Converte vírgula para ponto para parse
      limpo = limpo.replaceAll(',', '.');

      return double.tryParse(limpo) ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  double _extrairNumero(String? valor) {
    if (valor == null) return 0;

    final somenteNumeros = valor.replaceAll(RegExp(r'[^0-9]'), '');

    if (somenteNumeros.isEmpty) return 0;

    return double.tryParse(somenteNumeros) ?? 0;
  }

  Widget _blocoFaturado({required Map<String, dynamic> medicoes}) {
    // Função para formatar no padrão "999.999 L" - Corrigida para negativos
    String fmt(num v) {
      if (v.isNaN) return "-";

      // Arredonda e converte para inteiro
      final volumeInteiro = v.round();

      // Converte para string e remove sinal negativo temporariamente
      final isNegativo = volumeInteiro < 0;
      String inteiroFormatado = volumeInteiro.abs().toString();

      // Adiciona pontos como separadores de milhar
      if (inteiroFormatado.length > 3) {
        final buffer = StringBuffer();
        int contador = 0;

        for (int i = inteiroFormatado.length - 1; i >= 0; i--) {
          buffer.write(inteiroFormatado[i]);
          contador++;

          if (contador == 3 && i > 0) {
            buffer.write('.');
            contador = 0;
          }
        }

        final chars = buffer.toString().split('').reversed.toList();
        inteiroFormatado = chars.join('');
      }

      // Adiciona sinal negativo se necessário
      final sinal = isNegativo ? '-' : '';
      return '$sinal$inteiroFormatado L';
    }

    // Função para formatar porcentagem com 2 casas decimais
    String fmtPercent(double v) {
      if (v.isNaN || v.isInfinite) return "-";
      return '${v >= 0 ? '+' : ''}${v.toStringAsFixed(2)}%';
    }

    // Pega o valor do usuário para "Faturado"
    final faturadoUsuarioStr = medicoes['faturadoFinal']?.toString() ?? '';

    // Converte para double (se não for vazio)
    double faturadoUsuario = 0.0;
    if (faturadoUsuarioStr.isNotEmpty && faturadoUsuarioStr != '-') {
      try {
        // Remove pontos de milhar e converte vírgula para ponto
        String limpo = faturadoUsuarioStr
            .replaceAll('.', '')
            .replaceAll(',', '.');
        faturadoUsuario = double.tryParse(limpo) ?? 0.0;
      } catch (e) {
        faturadoUsuario = 0.0;
      }
    }

    // Pega os volumes
    final volume20Final = _extrairNumero(medicoes['volume20Final']?.toString());
    final volume20Inicial = _extrairNumero(
      medicoes['volume20Inicial']?.toString(),
    );

    // Cálculo da diferença: Volume a 20ºC - Faturado
    final entradaSaida20 = volume20Final - volume20Inicial;
    final diferenca = entradaSaida20 - faturadoUsuario;

    // Formata
    final faturadoFormatado = faturadoUsuario > 0 ? fmt(faturadoUsuario) : "-";
    final diferencaFormatada = fmt(diferenca);

    // Porcentagem
    final entradaSaida20Double = entradaSaida20.toDouble();
    final porcentagem = entradaSaida20Double != 0
        ? (diferenca.toDouble() / entradaSaida20Double) * 100
        : 0.0;
    final porcentagemFormatada = fmtPercent(porcentagem);

    // Concatenação: "-114 L | -0,36%"
    final concatenacao = '$diferencaFormatada ║ $porcentagemFormatada';

    // REGRAS DE CORES:
    // 1. "Faturado": cor automática (preto) - REMOVER O VERDE
    // 2. "Diferença": vermelho se negativo, azul se positivo
    final corDiferenca = diferenca < 0 ? Colors.red[700] : Colors.blue[700];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(flex: 7, child: SizedBox()),
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black54),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Table(
                  defaultColumnWidth: IntrinsicColumnWidth(),
                  border: TableBorder.all(color: Colors.black54),
                  children: [
                    TableRow(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                          color: Color(0xFFF5F5F5),
                          child: Center(
                            child: Text(
                              "Faturado",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                          color: Colors.white,
                          child: Center(
                            child: Text(
                              faturadoFormatado,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors
                                    .black87, // ALTERADO: COR AUTOMÁTICA (PRETO)
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                    TableRow(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                          color: Color(0xFFF5F5F5),
                          child: Center(
                            child: Text(
                              "Diferença",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                          color: Colors.white,
                          child: Center(
                            child: Text(
                              concatenacao,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color:
                                    corDiferenca, // ALTERADO: COR CONDICIONAL
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 15),
      ],
    );
  }

  Future<void> _baixarPDFCACL() async {
    setState(() {
      _isGeneratingPDF = true;
    });

    try {
      // ✅ ATUALIZA: Passa o número de controle para o PDF
      if (_numeroControle != null) {
        widget.dadosFormulario['numero_controle'] = _numeroControle;
      }

      // Gera o PDF usando a classe CACLPdf
      final pdfDocument = await CACLPdf.gerar(
        dadosFormulario: widget.dadosFormulario,
      );

      // Converte o documento para bytes
      final pdfBytes = await pdfDocument.save();

      // Faz download
      if (kIsWeb) {
        await _downloadForWebCACL(pdfBytes);
      } else {
        _showMobileMessageCACL();
      }

      // Mensagem de sucesso
      if (context.mounted) {
        _mostrarSnackBar(
          const SnackBar(
            content: Text('✓ Certificado CACL baixado com sucesso!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      print('ERRO ao gerar PDF CACL: $e');

      if (context.mounted) {
        _mostrarSnackBar(
          SnackBar(
            content: Text('Erro ao gerar PDF: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingPDF = false;
        });
      }
    }
  }

  // Função para download Web
  Future<void> _downloadForWebCACL(Uint8List bytes) async {
    try {
      final base64 = base64Encode(bytes);
      final dataUrl = 'data:application/pdf;base64,$base64';

      final produto = _obterNomeProduto();
      final data = widget.dadosFormulario['data']?.toString() ?? '';
      final fileName = 'CACL_${produto}_${data.replaceAll('/', '-')}.pdf';

      final jsCode =
          '''
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
          
          console.log('Download CACL iniciado: ' + '$fileName');
        } catch (error) {
          console.error('Erro no download automático:', error);
          window.open('$dataUrl', '_blank');
        }
      ''';

      js.context.callMethod('eval', [jsCode]);
    } catch (e) {
      print('Erro no download Web CACL: $e');
    }
  }

  void _showMobileMessageCACL() {
    if (context.mounted) {
      _mostrarSnackBar(
        const SnackBar(
          content: Text(
            'PDF CACL gerado! Em breve disponível para download no mobile.',
          ),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  String _formatarDataParaSQL(String dataDisplay) {
    try {
      if (dataDisplay.contains('-')) {
        final parsed = DateTime.parse(dataDisplay);
        return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
      }

      // Converte "22/12/2025" para "2025-12-22"
      final partes = dataDisplay.split('/');
      if (partes.length == 3) {
        final dia = partes[0];
        final mes = partes[1];
        final ano = partes[2];
        return '$ano-$mes-$dia'; // Formato SQL: yyyy-MM-dd
      }
      final data = _obterDataParaEstoque();
      return '${data.year}-${data.month.toString().padLeft(2, '0')}-${data.day.toString().padLeft(2, '0')}';
    } catch (e) {
      final data = _obterDataParaEstoque();
      return '${data.year}-${data.month.toString().padLeft(2, '0')}-${data.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _irParaApuracao() async {
    try {
      if (!mounted) return;
      await _irParaEstoqueTanqueAposEmissao();
      return;
    } catch (e) {
      print('Erro ao finalizar CACL: $e');
      if (context.mounted) {
        _mostrarSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _salvarComoPendente() async {
    if (_isEmittingCACL) return;

    setState(() {
      _isEmittingCACL = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final medicoes = widget.dadosFormulario['medicoes'] ?? {};

      final session = supabase.auth.currentSession;
      if (session == null) {
        if (context.mounted) {
          _mostrarSnackBar(
            const SnackBar(
              content: Text('Você precisa estar logado'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      String? tipoCACL;
      final bool caclVerificacao =
          widget.dadosFormulario['cacl_verificacao'] ?? false;
      final bool caclMovimentacao =
          widget.dadosFormulario['cacl_movimentacao'] ?? false;

      if (caclVerificacao) {
        tipoCACL = 'verificacao';
      } else if (caclMovimentacao) {
        tipoCACL = 'movimentacao';
      }

      final dataOriginal = widget.dadosFormulario['data']?.toString() ?? '';
      final dataFormatada = _formatarDataParaSQL(dataOriginal);
      final timestampReferencia = _obterTimestampBrasiliaComDataReferencia();

      final terminalIdParaSalvar = UsuarioAtual.instance?.terminalId ??
          widget.dadosFormulario['terminal_id']?.toString();

      final dadosParaInserir = {
        'data': dataFormatada,
        'produto_id': _obterProdutoId(),
        'tanque_id': _obterTanqueId(),
        'terminal_id': terminalIdParaSalvar,
        'status': 'pendente',
        'tipo': tipoCACL,

        'horario_inicial': _formatarHorarioParaTime(
          medicoes['horarioInicial']?.toString(),
        ),
        'altura_total_cm_inicial': medicoes['cmInicial']?.toString(),
        'altura_total_mm_inicial': medicoes['mmInicial']?.toString(),
        'volume_total_liquido_inicial': volumeTotalLiquidoInicial,
        'altura_agua_inicial': medicoes['alturaAguaInicial']?.toString(),
        'volume_agua_inicial': _extrairNumeroFormatado(
          medicoes['volumeAguaInicial']?.toString(),
        ),
        'altura_produto_inicial': medicoes['alturaProdutoInicial']?.toString(),
        'volume_produto_inicial': volumeInicial,
        'temperatura_tanque_inicial': medicoes['tempTanqueInicial']?.toString(),
        'densidade_observada_inicial': medicoes['densidadeInicial']?.toString(),
        'temperatura_amostra_inicial': medicoes['tempAmostraInicial']
            ?.toString(),
        'densidade_20_inicial': medicoes['densidade20Inicial']?.toString(),
        'fator_correcao_inicial': medicoes['fatorCorrecaoInicial']?.toString(),
        'volume_20_inicial': _extrairNumeroFormatado(
          medicoes['volume20Inicial']?.toString(),
        ),
        'massa_inicial': medicoes['massaInicial']?.toString(),

        'horario_final': null,
        'altura_total_cm_final': null,
        'altura_total_mm_final': null,
        'volume_total_liquido_final': null,
        'altura_agua_final': null,
        'volume_agua_final': null,
        'altura_produto_final': null,
        'volume_produto_final': null,
        'temperatura_tanque_final': null,
        'densidade_observada_final': null,
        'temperatura_amostra_final': null,
        'densidade_20_final': null,
        'fator_correcao_final': null,
        'volume_20_final': null,
        'massa_final': null,

        'volume_ambiente_inicial': volumeInicial,
        'volume_ambiente_final': null,
        'entrada_saida_ambiente': null,
        'entrada_saida_20': null,
        'faturado_final': null,
        'diferenca_faturado': null,
        'porcentagem_diferenca': null,

        'created_by': session.user.id,
        'updated_at': timestampReferencia,
        'estoque_final_calculado': _obterEstoqueFinalCalculado20(),
      };

      dadosParaInserir.remove('numero_controle');

      final resultadoInserir = await supabase
          .from('cacl')
          .insert(dadosParaInserir)
          .select('id, numero_controle')
          .single();

      if (resultadoInserir['numero_controle'] != null) {
        setState(() {
          _numeroControle = _tratarNumeroControle(
            resultadoInserir['numero_controle'],
          );
        });
      }

      final caclIdSalvo = resultadoInserir['id'].toString();
      final numeroControleGerado = _numeroControle;

      if (tipoCACL == 'movimentacao' &&
          caclIdSalvo.isNotEmpty &&
          numeroControleGerado != null &&
          numeroControleGerado.isNotEmpty) {
        try {
          await _salvarMovimentacaoCACL(
            caclId: caclIdSalvo,
            numeroControle: numeroControleGerado,
            dadosCacl: dadosParaInserir,
          );
        } catch (e) {}
      }

      await _inserirMovimentacaoTanqueSobraPerda(
        caclId: caclIdSalvo,
        medicoes: medicoes,
      );

      if (mounted) {
        setState(() {
          _caclJaEmitido = true;
          _isEmittingCACL = false;
        });
      }

      if (context.mounted) {
        _mostrarSnackBar(
          const SnackBar(
            content: Text('✓ CACL salvo como pendente!'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    } catch (e) {
      if (context.mounted) {
        _mostrarSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isEmittingCACL = false;
        });
      }
    }
  }

  bool _dadosFinaisEstaoCompletos() {
    final medicoes = widget.dadosFormulario['medicoes'] ?? {};

    // Lista dos campos OBRIGATÓRIOS para medição final
    final camposObrigatorios = [
      'horarioFinal', // Horário final
      'tempTanqueFinal', // Temperatura tanque
      'densidadeFinal', // Densidade observada
      'tempAmostraFinal', // Temperatura amostra
      'cmFinal', // Altura total cm
      // 'mmFinal', // Opcional se cm estiver preenchido
    ];

    // Verifica cada campo básico
    for (var campo in camposObrigatorios) {
      final valor = medicoes[campo]?.toString().trim() ?? '';
      if (valor.isEmpty || valor == '-') {
        return false;
      }
    }

    // Validação específica da altura total (pelo menos cm deve existir)
    final cmFinalValue = medicoes['cmFinal']?.toString().trim() ?? '';
    if (cmFinalValue.isEmpty || cmFinalValue == '-') {
      return false;
    }

    return true; // Se chegou aqui com os campos básicos, consideramos completo
  }

  bool _temVolumeMinimoValido() {
    final medicoes = widget.dadosFormulario['medicoes'] ?? {};
    final v20Inicial = _extrairNumero(medicoes['volume20Inicial']?.toString());
    
    // ✅ NOVA REGRA: O botão 'Salvar como pendente' só fica ativo se o 
    //            Volume a 20ºC da 1ª Medição for > 0.
    return v20Inicial > 0;
  }

  String? _formatarHorarioParaTime(String? horario) {
    if (horario == null || horario.isEmpty || horario == '-') return null;

    final horarioLimpo = horario.trim();
    final agoraUtc = DateTime.now().toUtc();
    final brasiliaData = agoraUtc.subtract(const Duration(hours: 3));

    int horas;
    int minutos;

    if (horarioLimpo.contains('T')) {
      try {
        final dt = DateTime.parse(horarioLimpo);
        horas = dt.hour;
        minutos = dt.minute;
      } catch (_) {
        return null;
      }
    } else {
      final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(horarioLimpo);
      if (match == null) return null;
      horas = int.tryParse(match.group(1) ?? '') ?? -1;
      minutos = int.tryParse(match.group(2) ?? '') ?? -1;
    }

    if (horas < 0 || horas > 23 || minutos < 0 || minutos > 59) return null;

    final dataDisplay = widget.dadosFormulario['data']?.toString() ?? '';
    DateTime baseDate;

    if (dataDisplay.contains('/')) {
      final partes = dataDisplay.split('/');
      if (partes.length == 3) {
        final dia = int.tryParse(partes[0]) ?? brasiliaData.day;
        final mes = int.tryParse(partes[1]) ?? brasiliaData.month;
        final ano = int.tryParse(partes[2]) ?? brasiliaData.year;
        baseDate = DateTime(ano, mes, dia, horas, minutos);
      } else {
        baseDate = DateTime(
          brasiliaData.year,
          brasiliaData.month,
          brasiliaData.day,
          horas,
          minutos,
        );
      }
    } else if (dataDisplay.contains('-')) {
      try {
        final dt = DateTime.parse(dataDisplay);
        baseDate = DateTime(dt.year, dt.month, dt.day, horas, minutos);
      } catch (_) {
        baseDate = DateTime(
          brasiliaData.year,
          brasiliaData.month,
          brasiliaData.day,
          horas,
          minutos,
        );
      }
    } else {
      baseDate = DateTime(
        brasiliaData.year,
        brasiliaData.month,
        brasiliaData.day,
        horas,
        minutos,
      );
    }

    // Formato compatível com timestamp without time zone: YYYY-MM-DD HH:MM:SS
    final y = baseDate.year.toString();
    final m = baseDate.month.toString().padLeft(2, '0');
    final d = baseDate.day.toString().padLeft(2, '0');
    final h = baseDate.hour.toString().padLeft(2, '0');
    final min = baseDate.minute.toString().padLeft(2, '0');
    final s = baseDate.second.toString().padLeft(2, '0');

    return '$y-$m-$d $h:$min:$s';
  }

  double? _extrairNumeroFormatado(String? valor) {
    if (valor == null || valor.isEmpty || valor == '-') return null;
    try {
      String somenteNumeros = valor.replaceAll(RegExp(r'[^0-9]'), '');
      if (somenteNumeros.isEmpty) return null;
      return double.tryParse(somenteNumeros);
    } catch (e) {
      return null;
    }
  }

  double? _converterParaDouble(String? valor) {
    if (valor == null || valor.isEmpty || valor == '-') return null;
    try {
      String limpo = valor
          .replaceAll(' L', '')
          .replaceAll(' cm', '')
          .replaceAll(' ºC', '')
          .replaceAll('°C', '')
          .replaceAll(',', '.')
          .replaceAll('.', '');
      return double.tryParse(limpo);
    } catch (e) {
      return null;
    }
  }

  // Adicione este método para obter o ID do tanque
  String? _obterTanqueId() {
    if (widget.dadosFormulario.containsKey('tanque_id')) {
      final tanqueId = widget.dadosFormulario['tanque_id']?.toString().trim();

      if (tanqueId != null && tanqueId.isNotEmpty && tanqueId.toLowerCase() != 'null') {
        return tanqueId;
      }
    } else if (widget.dadosFormulario.containsKey('id_tanque')) {
      final tanqueId = widget.dadosFormulario['id_tanque']?.toString().trim();
      if (tanqueId != null && tanqueId.isNotEmpty && tanqueId.toLowerCase() != 'null') {
        return tanqueId;
      }
    }

    return null;
  }

  String? _obterProdutoId() {
    if (widget.dadosFormulario.containsKey('produto_id')) {
      final produtoId = widget.dadosFormulario['produto_id']?.toString().trim();

      if (produtoId != null && produtoId.isNotEmpty && produtoId.toLowerCase() != 'null') {
        return produtoId;
      }
    }
    return null;
  }

  bool _isValidUUID(String str) {
    if (str.isEmpty) return false;

    // Aceita UUID com hífens: 123e4567-e89b-12d3-a456-426614174000
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );

    // Aceita UUID sem hífens: 123e4567e89b12d3a456426614174000
    final uuidNoHyphensRegex = RegExp(r'^[0-9a-f]{32}$', caseSensitive: false);

    return uuidRegex.hasMatch(str) || uuidNoHyphensRegex.hasMatch(str);
  }

  String _obterNomeTanque() {
    // Tenta pegar o nome do tanque
    final tanqueNome = widget.dadosFormulario['tanque']?.toString();

    // Se já tem e não é um UUID, retorna ele
    if (tanqueNome != null &&
        tanqueNome.isNotEmpty &&
        !_isValidUUID(tanqueNome)) {
      return tanqueNome;
    }

    // Se o valor atual é um UUID, tenta buscar o nome da tabela 'tanques'
    if (tanqueNome != null && _isValidUUID(tanqueNome)) {
      _buscarNomeTanquePorId(tanqueNome);
      return 'Carregando...'; // Retorna temporário
    }

    return 'Tanque';
  }

  String _obterNomeProduto() {
    final produtoNome = widget.dadosFormulario['produto']?.toString();
    if (produtoNome != null &&
        produtoNome.isNotEmpty &&
        !_isValidUUID(produtoNome)) {
      return produtoNome;
    }

    final produtoId = _obterProdutoId();
    if (produtoId != null) {
      _buscarNomeProdutoPorId(produtoId);
      return 'Carregando...';
    }

    return 'Produto';
  }

  Future<void> _buscarNomeProdutoPorId(String produtoId) async {
    try {
      final supabase = Supabase.instance.client;
      final resultado = await supabase
          .from('produtos')
          .select('nome')
          .eq('id', produtoId)
          .maybeSingle();

      if (resultado != null && resultado['nome'] != null) {
        if (mounted) {
          setState(() {
            widget.dadosFormulario['produto'] = resultado['nome']?.toString();
          });
        }
      }
    } catch (e) {}
  }

  Future<void> _buscarNomeTanquePorId(String tanqueId) async {
    try {
      final supabase = Supabase.instance.client;
      final resultado = await supabase
          .from('tanques')
          .select('referencia')
          .eq('id', tanqueId)
          .maybeSingle();

      if (resultado != null && resultado['referencia'] != null) {
        if (mounted) {
          setState(() {
            widget.dadosFormulario['tanque'] = resultado['referencia']
                ?.toString();
          });
        }
      }
    } catch (e) {
      // Silencioso
    }
  }
}
