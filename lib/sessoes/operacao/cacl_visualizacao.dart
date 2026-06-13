import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cacl_pdf.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'dart:convert' show base64Encode;
import 'dart:js' as js;

class CaclHistoricoPage extends StatefulWidget {
  final String caclId;
  final VoidCallback? onVoltar;

  const CaclHistoricoPage({
    super.key,
    required this.caclId,
    this.onVoltar,
  });

  @override
  State<CaclHistoricoPage> createState() => _CaclHistoricoPageState();
}

class _CaclHistoricoPageState extends State<CaclHistoricoPage> {
  // Dados do formulário para exibição
  final Map<String, dynamic> _dadosFormulario = {
    'medicoes': {},
  };

  // Variáveis de volume (apenas para exibição)
  double _volumeInicial = 0;
  double _volumeFinal = 0;
  double _volumeTotalLiquidoInicial = 0;
  double _volumeTotalLiquidoFinal = 0;
  double _totalSaidasAmbienteReal = 0;
  double _totalSaidas20Real = 0;
  
  // Controles de estado
  bool _isLoading = true;
  bool _isGeneratingPDF = false;
  bool _caclEmitido = false;
  String? _numeroControle;

  bool get _mostrarCampoSobraPerda {
    return _dadosFormulario['origem_estoque_tanque'] == true;
  }

  double _obterEstoqueFinalCalculado20() {
    final estoqueRaw = _dadosFormulario['estoque_final_calculado_20'];
    return (estoqueRaw is num) ? estoqueRaw.toDouble() : (double.tryParse(estoqueRaw?.toString() ?? '') ?? 0.0);
  }

  String _obterEstoqueFinalCalculadoFormatado() {
    return _formatarVolumeLitros(_obterEstoqueFinalCalculado20());
  }

  String? _obterVolume20DisponivelRaw(Map<String, dynamic> medicoes) {
    final volume20FinalRaw = medicoes['volume20Final']?.toString().trim();
    final volume20InicialRaw = medicoes['volume20Inicial']?.toString().trim();
    
    final bool isCalculoSobra = _dadosFormulario['cacl_verificacao'] == true || 
                               _dadosFormulario['origem_estoque_tanque'] == true;
    
    if (isCalculoSobra) {
      bool validoFinal(String? valor) {
        if (valor == null || valor.isEmpty || valor == '-') return false;
        return valor.replaceAll(RegExp(r'[^0-9]'), '').isNotEmpty;
      }
      return validoFinal(volume20FinalRaw) ? volume20FinalRaw : null;
    }
    
    bool valido(String? valor) {
      if (valor == null || valor.isEmpty || valor == '-') return false;
      return valor.replaceAll(RegExp(r'[^0-9]'), '').isNotEmpty;
    }

    if (valido(volume20FinalRaw)) return volume20FinalRaw;
    if (valido(volume20InicialRaw)) return volume20InicialRaw;
    return null;
  }

  double? _obterValorSobraPerda(Map<String, dynamic> medicoes) {
    if (_obterVolume20DisponivelRaw(medicoes) == null) return null;

    final volume20Raw = _obterVolume20DisponivelRaw(medicoes);
    final volume20Final = _extrairNumero(volume20Raw);
    final estoqueFinalCalculado = _obterEstoqueFinalCalculado20();
    
    return volume20Final - estoqueFinalCalculado;
  }

  String _formatarSobraPerdaComSinal(double valor) {
    final sinal = valor >= 0 ? '+' : '-';
    final valorFormatado = _formatarVolumeLitros(valor.abs());
    return '$sinal$valorFormatado';
  }

  String _obterSobraPerdaFormatada(Map<String, dynamic> medicoes) {
    final sobraPerda = _obterValorSobraPerda(medicoes);
    if (sobraPerda == null) return '-';
    
    final formattedValue = _formatarSobraPerdaComSinal(sobraPerda);
    final estoqueFinalCalculado = _obterEstoqueFinalCalculado20();
    
    if (estoqueFinalCalculado != 0) {
      final percentual = (sobraPerda / estoqueFinalCalculado) * 100;
      return '$formattedValue (${percentual >= 0 ? '+' : ''}${percentual.toStringAsFixed(2)}%)';
    }
    
    return formattedValue;
  }

  TextStyle _obterEstiloSobraPerda(Map<String, dynamic> medicoes) {
    final valor = _obterValorSobraPerda(medicoes);
    if (valor == null) return const TextStyle(fontSize: 11);

    return TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.bold,
      color: valor >= 0 ? Colors.blue[700] : Colors.red[700],
    );
  }

  @override
  void initState() {
    super.initState();
    _carregarDadosDoBanco();
  }

  Future<void> _carregarDadosDoBanco() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      
      // Busca os dados do CACL pelo ID
      final resultado = await supabase
          .from('cacl')
          .select('*, produtos:produto_id(nome), terminais:terminal_id(nome)')
          .eq('id', widget.caclId)
          .single();     

      // 1. NÚMERO DE CONTROLE
      _numeroControle = resultado['numero_controle']?.toString();

      // 2. STATUS (para saber se é emitido ou pendente)
      final status = resultado['status']?.toString();
      _caclEmitido = status == 'emitido';

      // 3. DADOS BÁSICOS
      if (resultado['data'] != null) {
        _dadosFormulario['data'] = _formatarDataDisplay(resultado['data']);
      }
      
      if (resultado['terminais'] != null && resultado['terminais']['nome'] != null) {
        _dadosFormulario['base'] = resultado['terminais']['nome']?.toString();
      }
      
      if (resultado['produtos'] != null && resultado['produtos']['nome'] != null) {
        _dadosFormulario['produto'] = resultado['produtos']['nome']?.toString();
      }
      
      if (resultado['terminal_id'] != null) {
        _dadosFormulario['terminal_id'] = resultado['terminal_id']?.toString();
      }
      
      if (resultado['tipo'] != null) {
        final tipo = resultado['tipo']?.toString();
        _dadosFormulario['cacl_verificacao'] = tipo == 'verificacao';
        _dadosFormulario['cacl_movimentacao'] = tipo == 'movimentacao';
        _dadosFormulario['origem_estoque_tanque'] = resultado['origem_estoque_tanque'] == true;
      }

      // 4. BUSCAR NOME DO TANQUE (se tanque_id existir)
      final tanqueId = resultado['tanque_id']?.toString();
      if (tanqueId != null && tanqueId.isNotEmpty) {
        final tanqueInfo = await supabase
            .from('tanques')
            .select('referencia')
            .eq('id', tanqueId)
            .maybeSingle();

        if (tanqueInfo != null && tanqueInfo['referencia'] != null) {
          _dadosFormulario['tanque'] = tanqueInfo['referencia']?.toString();
        } else {
          _dadosFormulario['tanque'] = resultado['produto']?.toString();
        }
        
        _dadosFormulario['tanque_id'] = tanqueId;
      } else {
        _dadosFormulario['tanque'] = resultado['produto']?.toString();
      }

      // 5. VOLUMES (apenas para exibição)
      _volumeInicial = resultado['volume_produto_inicial']?.toDouble() ?? 0.0;
      _volumeFinal = resultado['volume_produto_final']?.toDouble() ?? 0.0;
      _volumeTotalLiquidoInicial = resultado['volume_total_liquido_inicial']?.toDouble() ?? 0.0;
      _volumeTotalLiquidoFinal = resultado['volume_total_liquido_final']?.toDouble() ?? 0.0;
      
      final double totalSaidasBanco20 = (resultado['total_saidas'] ?? 0.0).toDouble();
      final double totalSaidasBancoAmb = (resultado['total_saidas_ambiente'] ?? 0.0).toDouble();

      _totalSaidasAmbienteReal = totalSaidasBancoAmb;
      _totalSaidas20Real = totalSaidasBanco20;

      // 6. MEDIÇÕES - Mapear campos do banco para o formato de exibição
      final medicoesAtualizadas = <String, dynamic>{};

      // 6.1. MEDIÇÃO INICIAL
      if (resultado['horario_inicial'] != null) {
        medicoesAtualizadas['horarioInicial'] = 
            _formatarHorarioDisplay(resultado['horario_inicial']);
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
        medicoesAtualizadas['massaInicial'] = 
            resultado['massa_inicial']?.toString();
      }

      // 6.2. MEDIÇÃO FINAL
      if (resultado['horario_final'] != null) {
        medicoesAtualizadas['horarioFinal'] = 
            _formatarHorarioDisplay(resultado['horario_final']);
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
        medicoesAtualizadas['massaFinal'] = 
            resultado['massa_final']?.toString();
      }

      // 6.3. VOLUMES FORMATADOS
      medicoesAtualizadas['volumeProdutoInicial'] = 
          _formatarVolumeLitros(_volumeInicial);
      medicoesAtualizadas['volumeProdutoFinal'] = 
          _formatarVolumeLitros(_volumeFinal);
      medicoesAtualizadas['volumeTotalLiquidoInicial'] = 
          _formatarVolumeLitros(_volumeTotalLiquidoInicial);
      medicoesAtualizadas['volumeTotalLiquidoFinal'] = 
          _formatarVolumeLitros(_volumeTotalLiquidoFinal);

      if (resultado['volume_agua_inicial'] != null) {
        medicoesAtualizadas['volumeAguaInicial'] = 
            _formatarVolumeLitros(resultado['volume_agua_inicial']?.toDouble() ?? 0.0);
      }
      
      if (resultado['volume_agua_final'] != null) {
        medicoesAtualizadas['volumeAguaFinal'] = 
            _formatarVolumeLitros(resultado['volume_agua_final']?.toDouble() ?? 0.0);
      }

      if (resultado['volume_20_inicial'] != null) {
        medicoesAtualizadas['volume20Inicial'] = 
            _formatarVolumeLitros(resultado['volume_20_inicial']?.toDouble() ?? 0.0);
      }
      
      if (resultado['volume_20_final'] != null) {
        medicoesAtualizadas['volume20Final'] = 
            _formatarVolumeLitros(resultado['volume_20_final']?.toDouble() ?? 0.0);
      }

      if (resultado['faturado_final'] != null) {
        medicoesAtualizadas['faturadoFinal'] = 
            resultado['faturado_final']?.toString();
      }
      
      if (resultado['estoque_final_calculado'] != null) {
        _dadosFormulario['estoque_final_calculado_20'] = 
            resultado['estoque_final_calculado'];
      }
      
      if (resultado['total_entradas'] != null) {
        _dadosFormulario['total_entradas_periodo'] = 
            resultado['total_entradas'];
        medicoesAtualizadas['totalEntradasPeriodo'] = 
            _formatarVolumeLitros(resultado['total_entradas']?.toDouble() ?? 0.0);
      } else {
        medicoesAtualizadas['totalEntradasPeriodo'] = '-';
      }
      
      medicoesAtualizadas['totalSaidasPeriodo'] = 
          _formatarVolumeLitros(_totalSaidas20Real);

      // 6.4. CAMPOS DE COMPARAÇÃO (se existirem)
      if (resultado['entrada_saida_ambiente'] != null) {
        medicoesAtualizadas['entradaSaidaAmbiente'] = 
            resultado['entrada_saida_ambiente']?.toString();
      }
      
      if (resultado['entrada_saida_20'] != null) {
        medicoesAtualizadas['entradaSaida20'] = 
            resultado['entrada_saida_20']?.toString();
      }
      
      if (resultado['diferenca_faturado'] != null) {
        medicoesAtualizadas['diferencaFaturado'] = 
            resultado['diferenca_faturado']?.toString();
      }
      
      if (resultado['porcentagem_diferenca'] != null) {
        medicoesAtualizadas['porcentagemDiferenca'] = 
            resultado['porcentagem_diferenca']?.toString();
      }

      // ✅ NOVO: Buscar e povoar Total de Entradas e Saídas se for verificação
      if (_dadosFormulario['cacl_verificacao'] == true || _dadosFormulario['origem_estoque_tanque'] == true) {
        await _buscarTotaisEntradasSaidasHistorico(
          tanqueId: tanqueId,
          dataSql: resultado['data']?.toString(),
        );
      }

      _dadosFormulario['medicoes'] = medicoesAtualizadas;

      setState(() {
        _isLoading = false;
      });

    } catch (e) {
      print('❌ ERRO ao carregar CACL: $e');
      
      setState(() {
        _isLoading = false;
        _caclEmitido = false;
        _numeroControle = null;
      });
    }
  }

  // FUNÇÕES AUXILIARES DE FORMATAÇÃO (copiadas da CalcPage)
  String _formatarHorarioDisplay(String? timeString) {
    if (timeString == null || timeString.isEmpty) return '-';
    
    try {
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

  String _formatarDataDisplay(String? dataSql) {
    if (dataSql == null || dataSql.isEmpty) return '';
    
    try {
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

  String _obterValorMedicao(dynamic valor) {
    if (valor == null) return "-";

    if (valor is String) {
      final v = valor.trim();
      if (v.isEmpty) return "-";
      return v;
    }

    return valor.toString();
  }

  String _formatarAlturaTotal(String? cm, String? mm) {
    if (cm == null || cm.isEmpty) return "-";
    final mmValue = (mm == null || mm.isEmpty) ? "0" : mm;
    return "$cm,$mmValue cm";
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

  String _obterApenasData(String dataCompleta) {
    if (dataCompleta.contains(',')) {
      return dataCompleta.split(',').first.trim();
    }
    return dataCompleta;
  }

  String _formatarHorarioCACL(String? horario) {
    if (horario == null || horario.isEmpty) return '--:-- h';
    
    String horarioLimpo = horario.trim();
    
    if (horarioLimpo.toLowerCase().endsWith('h')) {
      return horarioLimpo;
    }
    
    return '$horarioLimpo h';
  }

  double _extrairNumero(String? valor) {
    if (valor == null) return 0;

    final somenteNumeros = valor.replaceAll(RegExp(r'[^0-9]'), '');

    if (somenteNumeros.isEmpty) return 0;

    return double.tryParse(somenteNumeros) ?? 0;
  }

  // WIDGETS DE UI (copiados da CalcPage)
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
      child: Text(
        valor,
        style: const TextStyle(fontSize: 11),
      ),
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
          decoration: BoxDecoration(
            color: Colors.grey[200],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: Text(
                "DESCRIÇÃO",
                style: const TextStyle(
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

        if (_dadosFormulario['cacl_verificacao'] == true ||
            _dadosFormulario['origem_estoque_tanque'] == true) ...[
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: Text(
                  "Total de entradas no período (20°):",
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
                  "Total de saídas no período (20°):",
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
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: Text(
                  "Estoque final calculado (20°C):",
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
                  _formatarVolumeLitros((_dadosFormulario['estoque_final_calculado_20'] ?? 0).toDouble()),
                  style: const TextStyle(fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ],

        if (_mostrarCampoSobraPerda && !(_dadosFormulario['cacl_verificacao'] == true || _dadosFormulario['origem_estoque_tanque'] == true))
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: Text(
                  "Estoque final calculado (20ºC):",
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

  TableRow _linhaMedicao(String descricao, String valorInicial, String valorFinal) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Text(
            descricao,
            style: const TextStyle(fontSize: 11),
          ),
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
    String fmt(dynamic v) {
      if (v == null) return "-";
      
      try {
        double valor;
        if (v is String) {
          if (v.isEmpty || v == '-') return "-";
          valor = double.tryParse(v.replaceAll(',', '.')) ?? 0.0;
        } else if (v is num) {
          valor = v.toDouble();
        } else {
          return "-";
        }
        
        final volumeInteiro = valor.round();
        final isNegativo = volumeInteiro < 0;
        String inteiroFormatado = volumeInteiro.abs().toString();
        
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
        
        final sinal = isNegativo ? '-' : '';
        return '$sinal$inteiroFormatado L';
      } catch (e) {
        return "-";
      }
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
        TableRow(
          decoration: BoxDecoration(color: Color(0xFFE0E0E0)),
          children: [
            Padding(
              padding: EdgeInsets.all(6.0),
              child: Text("DESCRIÇÃO",
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: EdgeInsets.all(6.0),
              child: Text("1ª MEDIÇÃO",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: EdgeInsets.all(6.0),
              child: Text("ENTRADA/SAÍDA",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: EdgeInsets.all(6.0),
              child: Text("2ª MEDIÇÃO",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: EdgeInsets.all(6.0),
              child: Text("DIFERENÇA",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ),

        TableRow(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
              child: Text("Volume ambiente", style: TextStyle(fontSize: 10)),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
              child: Text(fmt(volumeAmbienteInicial), 
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10)),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
              child: Text(fmt(entradaSaidaAmbiente),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10)),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
              child: Text(fmt(volumeAmbienteFinal), 
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10)),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
              child: Text(fmt((volumeAmbienteFinal - volumeAmbienteInicial) - entradaSaidaAmbiente),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10)),
            ),
          ],
        ),

        TableRow(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
              child: Text("Volume a 20 ºC", style: TextStyle(fontSize: 10)),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
              child: Text(fmt(volume20Inicial), 
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10)),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
              child: Text(fmt(entradaSaida20),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10)),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
              child: Text(fmt(volume20Final), 
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10)),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
              child: Text(fmt((volume20Final - volume20Inicial) - entradaSaida20),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10)),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _buscarTotaisEntradasSaidasHistorico({
    required String? tanqueId,
    required String? dataSql,
  }) async {
    if (tanqueId == null || dataSql == null) return;

    final inicioDoDia = '$dataSql 00:00:00';
    final fimDoDia = '$dataSql 23:59:59';

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('movimentacoes_tanque')
          .select('entrada_amb, saida_amb, entrada_vinte, saida_vinte')
          .eq('tanque_id', tanqueId)
          .gte('data_mov', inicioDoDia)
          .lte('data_mov', fimDoDia);

      double totalSaidasAmb = 0;
      double totalEntradas20 = 0;
      double totalSaidas20 = 0;

      for (final m in response) {
        totalSaidasAmb += (m['saida_amb'] ?? 0).toDouble();
        totalEntradas20 += (m['entrada_vinte'] ?? 0).toDouble();
        totalSaidas20 += (m['saida_vinte'] ?? 0).toDouble();
      }

      setState(() {
        // ✅ CORRETO: Total de saídas é simplesmente totalSaidas20
        _totalSaidas20Real = totalSaidas20;
        
        // Para ambiente, também é simplesmente totalSaidasAmb
        _totalSaidasAmbienteReal = totalSaidasAmb;
        
        _dadosFormulario['medicoes']['entradaSaidaAmbiente'] =
            totalSaidasAmb.toString();
        _dadosFormulario['medicoes']['entradaSaida20'] =
            totalSaidas20.toString();
            
        _dadosFormulario['medicoes']['totalEntradasPeriodo'] =
            _formatarVolumeLitros(totalEntradas20);
        _dadosFormulario['medicoes']['totalSaidasPeriodo'] =
            _formatarVolumeLitros(totalSaidas20);
      });
    } catch (e) {
      debugPrint('Erro ao buscar totais de entradas e saídas no histórico: $e');
    }
  }

  double _converterVolumeParaDouble(String volumeStr) {
    try {
      String limpo = volumeStr.replaceAll(' L', '').trim();
      
      if (limpo.isEmpty || limpo == '-') {
        return 0.0;
      }
      
      if (limpo.contains('.')) {
        final partes = limpo.split('.');
        if (partes.length > 1) {
          if (partes.last.length == 3) {
            limpo = limpo.replaceAll('.', '');
          } else {
            limpo = limpo.replaceAll('.', ',');
          }
        } else {
          limpo = limpo.replaceAll('.', '');
        }
      }
      
      limpo = limpo.replaceAll(',', '.');
      
      return double.tryParse(limpo) ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  Widget _blocoFaturado() {
    final medicoes = _dadosFormulario['medicoes'] ?? {};
    
    // Função para formatar no padrão "999.999 L"
    String fmt(num v) {
      if (v.isNaN) return "-";
      
      final volumeInteiro = v.round();
      final isNegativo = volumeInteiro < 0;
      String inteiroFormatado = volumeInteiro.abs().toString();
      
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
      
      final sinal = isNegativo ? '-' : '';
      return '$sinal$inteiroFormatado L';
    }

    // Função para formatar porcentagem com 2 casas decimais
    String fmtPercent(double v) {
      if (v.isNaN || v.isInfinite) return "-";
      return '${v >= 0 ? '+' : ''}${v.toStringAsFixed(2)}%';
    }

    // Buscar valores do banco
    double faturadoUsuario = 0.0;
    if (medicoes['faturadoFinal'] != null && 
        medicoes['faturadoFinal'].toString().isNotEmpty && 
        medicoes['faturadoFinal'].toString() != '-') {
      try {
        String limpo = medicoes['faturadoFinal'].toString()
            .replaceAll('.', '')
            .replaceAll(',', '.');
        faturadoUsuario = double.tryParse(limpo) ?? 0.0;
      } catch (e) {
        faturadoUsuario = 0.0;
      }
    }
    
    final volume20Final = _converterVolumeParaDouble(medicoes['volume20Final']?.toString() ?? '0');
    final volume20Inicial = _converterVolumeParaDouble(medicoes['volume20Inicial']?.toString() ?? '0');
    final estoqueFinalCalculado = _obterEstoqueFinalCalculado20();

    // Usar diferença armazenada ou calcular se não existir
    double diferenca;
    double porcentagem;
    
    if (_dadosFormulario['cacl_verificacao'] == true || _dadosFormulario['origem_estoque_tanque'] == true) {
      // Diferença = Volume 20ºC Final - Estoque Final Calculado
      diferenca = volume20Final - estoqueFinalCalculado;
      
      // O percentual é quanto esta diferença representa do "Estoque final calculado"
      porcentagem = estoqueFinalCalculado != 0 ? (diferenca / estoqueFinalCalculado) * 100 : 0.0;
    } else {
      // Casos normais (não verificação)
      if (medicoes['diferencaFaturado'] != null) {
        diferenca = double.tryParse(medicoes['diferencaFaturado'].toString().replaceAll(',', '.')) ?? 0.0;
      } else {
        diferenca = (volume20Final - volume20Inicial) - _totalSaidas20Real;
      }
      
      if (medicoes['porcentagemDiferenca'] != null) {
        final porcentagemStr = medicoes['porcentagemDiferenca'].toString()
            .replaceAll('%', '')
            .replaceAll(',', '.');
        porcentagem = double.tryParse(porcentagemStr) ?? 0.0;
      } else {
        porcentagem = _totalSaidas20Real != 0 ? (diferenca / _totalSaidas20Real) * 100 : 0.0;
      }
    }
    
    final faturadoFormatado = faturadoUsuario > 0 ? fmt(faturadoUsuario) : "-";
    final diferencaFormatada = fmt(diferenca);
    final porcentagemFormatada = fmtPercent(porcentagem);
    
    final concatenacao = '$diferencaFormatada ║ $porcentagemFormatada';
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
                    if (_dadosFormulario['cacl_verificacao'] != true)
                      TableRow(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
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
                            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            color: Colors.white,
                            child: Center(
                              child: Text(
                                faturadoFormatado,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
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
                          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          color: Color(0xFFF5F5F5),
                          child: Center(
                            child: Text(
                              "Sobra/Perda",
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
                          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          color: Colors.white,
                          child: Center(
                            child: Text(
                              concatenacao,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: corDiferenca,
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

  // FUNÇÕES PARA PDF
  Future<void> _baixarPDFCACL() async {
    setState(() {
      _isGeneratingPDF = true;
    });
    
    try {
      // Adiciona número de controle para o PDF
      if (_numeroControle != null) {
        _dadosFormulario['numero_controle'] = _numeroControle;
      }
      
      // Gera o PDF
      final pdfDocument = await CACLPdf.gerar(
        dadosFormulario: _dadosFormulario,
      );
      
      final pdfBytes = await pdfDocument.save();
      
      if (kIsWeb) {
        await _downloadForWebCACL(pdfBytes);
      } else {
        print('PDF CACL gerado (${pdfBytes.length} bytes)');
        _showMobileMessageCACL();
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Certificado CACL baixado com sucesso!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
      
    } catch (e) {
      print('ERRO ao gerar PDF CACL: $e');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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

  Future<void> _downloadForWebCACL(Uint8List bytes) async {
    try {
      final base64 = base64Encode(bytes);
      final dataUrl = 'data:application/pdf;base64,$base64';
      
      final produto = _dadosFormulario['produto']?.toString() ?? 'CACL';
      final data = _dadosFormulario['data']?.toString() ?? '';
      final fileName = 'CACL_${produto}_${data.replaceAll('/', '-')}.pdf';
      
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF CACL gerado! Em breve disponível para download no mobile.'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text(
                'Carregando CACL...',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    final medicoes = _dadosFormulario['medicoes'] ?? {};

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
                  // CABEÇALHO
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
                              "CACL - VISUALIZAÇÃO",
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

                  // DADOS PRINCIPAIS
                  SizedBox(
                    width: double.infinity,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nº DE CONTROLE
                        Expanded(
                          flex: 16,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _secaoTitulo("Nº DE CONTROLE:"),
                              _linhaValor(_numeroControle ?? "-"),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        
                        Expanded(
                          flex: 16,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _secaoTitulo("DATA:"),
                              _linhaValor(_obterApenasData(_dadosFormulario['data']?.toString() ?? "-")),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 28,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _secaoTitulo("BASE:"),
                              _linhaValor(_dadosFormulario['base']?.toString() ?? "POLO DE COMBUSTÍVEL"),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 20,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _secaoTitulo("PRODUTO:"),
                              _linhaValor(_dadosFormulario['produto']?.toString() ?? "-"),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 20,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _secaoTitulo("TANQUE Nº:"),
                              _linhaValor(_dadosFormulario['tanque']?.toString() ?? "-"),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  // SEÇÃO DE MEDIÇÕES
                  _subtitulo("VOLUME RECEBIDO NOS TANQUES DE TERRA E CANALIZAÇÃO RESPECTIVA"),
                  const SizedBox(height: 12),

                  _tabelaMedicoes(
                    [
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
                        _formatarVolumeLitros(_volumeTotalLiquidoInicial),
                        _formatarVolumeLitros(_volumeTotalLiquidoFinal),
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
                        _formatarVolumeLitros(_volumeInicial),
                        _formatarVolumeLitros(_volumeFinal),
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
                    ],
                    medicoes,
                    extraAposEstoque: _linhaMedicao(
                      "Volume total do produto, considerada a temperatura padrão (20 ºC):",
                      _obterValorMedicao(medicoes['volume20Inicial']),
                      _obterValorMedicao(medicoes['volume20Final']),
                    ),
                  ),

                  const SizedBox(height: 25),

                  // COMPARAÇÃO DE RESULTADOS
                  _subtitulo("COMPARAÇÃO DE RESULTADOS"),
                  const SizedBox(height: 8),

                  _tabelaComparacaoResultados(
                    volumeAmbienteInicial: _volumeInicial,
                    volumeAmbienteFinal: _volumeFinal,
                    volume20Inicial: _converterVolumeParaDouble(
                      medicoes['volume20Inicial']?.toString() ?? '0',
                    ),
                    volume20Final: _converterVolumeParaDouble(
                      medicoes['volume20Final']?.toString() ?? '0',
                    ),
                    entradaSaidaAmbiente: _totalSaidasAmbienteReal,
                    entradaSaida20: _totalSaidas20Real,
                  ),

                  // BLOCO FATURADO
                  const SizedBox(height: 20),
                  _blocoFaturado(),                 

                  // RODAPÉ
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _caclEmitido 
                          ? const Color(0xFFE3F2FD)  // Azul claro se emitido
                          : const Color(0xFFFFF3E0), // Laranja claro se pendente
                      border: Border.all(
                        color: _caclEmitido 
                            ? const Color(0xFF2196F3)
                            : Colors.orange,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _caclEmitido ? Icons.info_outline : Icons.pending,
                          color: _caclEmitido 
                              ? const Color(0xFF2196F3)
                              : Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _caclEmitido ? "CACL Emitido" : "CACL Pendente",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _caclEmitido 
                                      ? const Color(0xFF0D47A1)
                                      : Colors.orange[800],
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _caclEmitido 
                                  ? "Este CACL já foi emitido e está salvo no histórico."
                                  : "Este CACL está pendente. Faltam dados da medição final.",
                                style: TextStyle(
                                  color: _caclEmitido 
                                      ? Colors.grey[700]
                                      : Colors.orange[700],
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
                  
                  // BOTÕES
                  Container(
                    margin: const EdgeInsets.only(top: 20),
                    width: double.infinity,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // BOTÃO VOLTAR
                        ElevatedButton.icon(
                          onPressed: () {
                            if (widget.onVoltar != null) {
                              widget.onVoltar!();
                            } else {
                              Navigator.of(context).pop();
                            }
                          },
                          icon: const Icon(Icons.arrow_back, size: 18),
                          label: const Text('Voltar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D47A1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 20),
                        
                        // BOTÃO GERAR PDF (apenas se CACL emitido)
                        if (_caclEmitido)
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
                            label: Text(_isGeneratingPDF ? 'Gerando...' : 'Gerar PDF'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D47A1),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
}