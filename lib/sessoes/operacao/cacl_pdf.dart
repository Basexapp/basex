import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class CACLPdf {
  // Função principal para gerar o PDF do CACL
  static Future<pw.Document> gerar({
    required Map<String, dynamic> dadosFormulario,
  }) async {
    final pdf = pw.Document();
    
    // Cores personalizadas
    final azulPrincipal = PdfColor.fromInt(0xFF0D47A1);
    final cinzaClaro = PdfColor.fromInt(0xFFF5F5F5);
    // Normalizar dados recebidos (pode ser LinkedMap de alguns decode/JSON)
    final dados = Map<String, dynamic>.from(dadosFormulario);
    final rawMedicoes = dados['medicoes'];
    final medicoes = (rawMedicoes is Map) ? Map<String, dynamic>.from(rawMedicoes) : <String, dynamic>{};
    final data = dados['data']?.toString() ?? "";
    final hora = dados['horarioInicial']?.toString() ?? "";
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(15), // Reduzido para caber tudo
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // CABEÇALHO COM BORDAS (mais compacto)
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: cinzaClaro,
                  border: pw.Border.all(color: azulPrincipal, width: 1),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'CERTIFICADO DE ARQUEAÇÃO DE CARGAS LÍQUIDAS (CACL)',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: azulPrincipal,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'Em conformidade com a NBR ISO/IEC 17025:2017',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 10),
              
              // INFORMAÇÕES PRINCIPAIS EM LINHA ÚNICA (mais compacto)
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.3),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'DADOS DO PROCESSO',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: azulPrincipal,
                        fontSize: 10,
                      ),
                    ),
                    pw.Divider(color: azulPrincipal, height: 6),
                    pw.Row(
                      children: [
                        // Nº Controle (NOVO CAMPO)
                        // Versão simplificada (no local original):
                        pw.Expanded(
                          child: _infoLinhaPDFMuitoCompacta(
                            'Nº Controle:',
                            (dadosFormulario['numero_controle'] ?? 
                            dadosFormulario['numeroControle'] ?? 
                            'A ser gerado').toString(),
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        // Data
                        pw.Expanded(
                          child: _infoLinhaPDFMuitoCompacta(
                            'Data:',
                            _obterApenasData(data),
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        // Terminal (antes chamado 'Base')
                        pw.Expanded(
                          child: _infoLinhaPDFMuitoCompacta(
                            'Terminal:',
                            // if terminal was passed as a Map, try to extract a name
                            () {
                              final t = dadosFormulario['terminal'];
                              if (t is Map) {
                                return (t['nome'] ?? t['referencia'] ?? t['nome_dois'])?.toString() ?? 'POLO DE COMBUSTÍVEL';
                              }
                              return dadosFormulario['terminal']?.toString() ?? 'POLO DE COMBUSTÍVEL';
                            }(),
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        // Produto
                        pw.Expanded(
                          child: _infoLinhaPDFMuitoCompacta(
                            'Produto:',
                            dadosFormulario['produto']?.toString() ?? "",
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        // Tanque
                        pw.Expanded(
                          child: _infoLinhaPDFMuitoCompacta(
                            'Tanque Nº:',
                            dadosFormulario['tanque']?.toString() ?? "",
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 10),
              
              // SEÇÃO: MEDIÇÕES (mais compacta)
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: cinzaClaro,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'VOLUME RECEBIDO NOS TANQUES DE TERRA E CANALIZAÇÃO RESPECTIVA',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: azulPrincipal,
                        fontSize: 10,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    
                    // TABELA DE MEDIÇÕES (fontes menores)
                    _tabelaMedicoesPDFCompacta(medicoes),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 10),
              
              // SEÇÃO: COMPARAÇÃO DE RESULTADOS (mais compacta)
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: cinzaClaro,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'COMPARAÇÃO DE RESULTADOS',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: azulPrincipal,
                        fontSize: 10,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    
                    // TABELA DE COMPARAÇÃO (fontes menores)
                    _tabelaComparacaoPDFCompacta(medicoes),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              // SEÇÃO: FATURADO (se existir, em linha única)
              if (medicoes['faturadoFinal'] != null && medicoes['faturadoFinal'].toString().isNotEmpty)
                pw.Container(
                  width: double.infinity,
                  margin: const pw.EdgeInsets.only(top: 8),
                  child: _blocoFaturadoPDFCompacto(medicoes),
                ),              
              
              // ESPAÇO ANTES DAS ASSINATURAS
              pw.SizedBox(height: 30),
              
              // RODAPÉ COM ASSINATURAS (copiado do modelo da ordem)
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  children: [ 
                    
                    pw.SizedBox(height: 12),
                                                            
                    // 4️⃣ ASSINATURAS DOS TÉCNICOS
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        // Assinatura do Operador Responsável
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text('_________________________', 
                              style: pw.TextStyle(fontSize: 8, height: 1)),
                            pw.SizedBox(height: 2),
                            pw.Text('Operador responsável', 
                              style: pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                          ],
                        ),
                        
                        // Assinatura do Responsável Técnico
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text('_________________________', 
                              style: pw.TextStyle(fontSize: 8, height: 1)),
                            pw.SizedBox(height: 2),
                            pw.Text('Laboratório', 
                              style: pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                          ],
                        ),
                      ],
                    ),
                    
                    pw.SizedBox(height: 10),
                    pw.Divider(height: 0.5, color: PdfColors.grey400),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'Base-X - ${_obterApenasData(data)} ${_formatarHoraSimples(hora)}',
                      style: pw.TextStyle(fontSize: 6, color: PdfColors.grey600),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
    
    return pdf;
  }
  
  // ================= FUNÇÕES AUXILIARES =================
  
  // Versão MUITO compacta para informações (uma linha)
  static pw.Widget _infoLinhaPDFMuitoCompacta(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 7,
          ),
        ),
        pw.Text(
          value.isEmpty ? '-' : value,
          style: const pw.TextStyle(fontSize: 8),
        ),
      ],
    );
  }
  
  static pw.Table _tabelaMedicoesPDFCompacta(Map<String, dynamic> medicoes) {
    final horarioInicial = _formatarHorarioCACL(medicoes['horarioInicial']);
    final horarioFinal = _formatarHorarioCACL(medicoes['horarioFinal']);
    
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.3),
      columnWidths: {
        0: const pw.FlexColumnWidth(2.3), // Reduzido
        1: const pw.FlexColumnWidth(0.9), // Reduzido
        2: const pw.FlexColumnWidth(0.9), // Reduzido
      },
      children: [
        // CABEÇALHO
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: PdfColor.fromInt(0xFF0D47A1), // AZUL NO ROW
          ),
          children: [
            _celulaTabelaMuitoCompacta("DESCRIÇÃO", true),
            _celulaTabelaMuitoCompacta(
              "1ª MEDIÇÃO - $horarioInicial",
              true,
              centralizado: true,
            ),
            _celulaTabelaMuitoCompacta(
              "2ª MEDIÇÃO - $horarioFinal",
              true,
              centralizado: true,
            ),
          ],
        ),

        
        // LINHAS DE MEDIÇÕES (apenas as principais para economizar espaço)
        _linhaMedicaoTabelaCompacta(
          "Altura total líquido:",
          _formatarAlturaTotalPDF(medicoes['cmInicial'], medicoes['mmInicial']),
          _formatarAlturaTotalPDF(medicoes['cmFinal'], medicoes['mmFinal']),
        ),
        
        _linhaMedicaoTabelaCompacta(
          "Volume total (ambiente):",
          _obterValorMedicaoPDF(medicoes['volumeTotalLiquidoInicial']),
          _obterValorMedicaoPDF(medicoes['volumeTotalLiquidoFinal']),
        ),
        
        _linhaMedicaoTabelaCompacta(
          "Altura água:",
          _obterValorMedicaoPDF(medicoes['alturaAguaInicial']),
          _obterValorMedicaoPDF(medicoes['alturaAguaFinal']),
        ),
        
        _linhaMedicaoTabelaCompacta(
          "Volume água:",
          _obterValorMedicaoPDF(medicoes['volumeAguaInicial']),
          _obterValorMedicaoPDF(medicoes['volumeAguaFinal']),
        ),
        
        _linhaMedicaoTabelaCompacta(
          "Volume produto (ambiente):",
          _obterValorMedicaoPDF(medicoes['volumeTotalLiquidoInicial']),
          _obterValorMedicaoPDF(medicoes['volumeTotalLiquidoFinal']),
        ),
        
        _linhaMedicaoTabelaCompacta(
          "Temp. tanque:",
          _formatarTemperaturaPDF(medicoes['tempTanqueInicial']),
          _formatarTemperaturaPDF(medicoes['tempTanqueFinal']),
        ),
        
        _linhaMedicaoTabelaCompacta(
          "Densidade observada:",
          _obterValorMedicaoPDF(medicoes['densidadeInicial']),
          _obterValorMedicaoPDF(medicoes['densidadeFinal']),
        ),
        
        _linhaMedicaoTabelaCompacta(
          "Temp. amostra:",
          _formatarTemperaturaPDF(medicoes['tempAmostraInicial']),
          _formatarTemperaturaPDF(medicoes['tempAmostraFinal']),
        ),
        
        _linhaMedicaoTabelaCompacta(
          "Densidade 20ºC:",
          _obterValorMedicaoPDF(medicoes['densidade20Inicial']),
          _obterValorMedicaoPDF(medicoes['densidade20Final']),
        ),
        
        _linhaMedicaoTabelaCompacta(
          "FCV:",
          _obterValorMedicaoPDF(medicoes['fatorCorrecaoInicial']),
          _obterValorMedicaoPDF(medicoes['fatorCorrecaoFinal']),
        ),
        
        _linhaMedicaoTabelaCompacta(
          "Volume 20ºC:",
          _obterValorMedicaoPDF(medicoes['volume20Inicial']),
          _obterValorMedicaoPDF(medicoes['volume20Final']),
        ),
        
        // MASSA DO PRODUTO
        pw.TableRow(
          children: [
            _celulaTabelaMuitoCompacta(
              "Massa produto (20ºC × Densidade):",
              false,
            ),
            _celulaTabelaMuitoCompacta(
              _obterValorMedicaoPDF(medicoes['massaInicial']),
              false,
              centralizado: true,
            ),
            _celulaTabelaMuitoCompacta(
              _obterValorMedicaoPDF(medicoes['massaFinal']),
              false,
              centralizado: true,
            ),
          ],
        ),
      ],
    );
  }
  
  static pw.Table _tabelaComparacaoPDFCompacta(Map<String, dynamic> medicoes) {
    // Função para extrair números dos valores formatados
    double extrairNumero(String? valor) {
      if (valor == null) return 0;
      final somenteNumeros = valor.replaceAll(RegExp(r'[^0-9]'), '');
      if (somenteNumeros.isEmpty) return 0;
      return double.tryParse(somenteNumeros) ?? 0;
    }
    
    final volumeInicial = extrairNumero(medicoes['volumeProdutoInicial']?.toString());
    final volumeFinal = extrairNumero(medicoes['volumeProdutoFinal']?.toString());
    final volume20Inicial = extrairNumero(medicoes['volume20Inicial']?.toString());
    final volume20Final = extrairNumero(medicoes['volume20Final']?.toString());
    
    final entradaSaidaAmbiente = volumeFinal - volumeInicial;
    final entradaSaida20 = volume20Final - volume20Inicial;
    
    // Função para formatar no padrão "999.999 L"
    String fmt(double v) {
      if (v.isNaN) return "-";
      
      final volumeInteiro = v.round();
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
    
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.3),
      columnWidths: {
        0: const pw.FlexColumnWidth(2.0), // Reduzido
        1: const pw.FlexColumnWidth(0.8), // Reduzido
        2: const pw.FlexColumnWidth(0.8), // Reduzido
        3: const pw.FlexColumnWidth(0.8), // Reduzido
      },
      children: [
        // CABEÇALHO
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _celulaTabelaMuitoCompacta("DESCRIÇÃO", true),
            _celulaTabelaMuitoCompacta("1ª MEDIÇÃO", true, centralizado: true),
            _celulaTabelaMuitoCompacta("2ª MEDIÇÃO", true, centralizado: true),
            _celulaTabelaMuitoCompacta("ENTRADA/SAÍDA", true, centralizado: true),
          ],
        ),
        
        // VOLUME AMBIENTE
        pw.TableRow(
          children: [
            _celulaTabelaMuitoCompacta("Volume ambiente", false),
            _celulaTabelaMuitoCompacta(fmt(volumeInicial), false, centralizado: true),
            _celulaTabelaMuitoCompacta(fmt(volumeFinal), false, centralizado: true),
            _celulaTabelaMuitoCompacta(fmt(entradaSaidaAmbiente), false, centralizado: true),
          ],
        ),
        
        // VOLUME A 20 ºC
        pw.TableRow(
          children: [
            _celulaTabelaMuitoCompacta("Volume a 20ºC", false),
            _celulaTabelaMuitoCompacta(fmt(volume20Inicial), false, centralizado: true),
            _celulaTabelaMuitoCompacta(fmt(volume20Final), false, centralizado: true),
            _celulaTabelaMuitoCompacta(fmt(entradaSaida20), false, centralizado: true),
          ],
        ),
      ],
    );
  }
  
  static pw.Widget _blocoFaturadoPDFCompacto(Map<String, dynamic> medicoes) {
    // Função para extrair números
    double extrairNumero(String? valor) {
      if (valor == null) return 0;
      final somenteNumeros = valor.replaceAll(RegExp(r'[^0-9]'), '');
      if (somenteNumeros.isEmpty) return 0;
      return double.tryParse(somenteNumeros) ?? 0;
    }
    
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
    
    // Função para formatar porcentagem
    String fmtPercent(double v) {
      if (v.isNaN || v.isInfinite) return "-";
      return '${v >= 0 ? '+' : ''}${v.toStringAsFixed(2)}%';
    }
    
    // Cálculos
    final faturadoUsuarioStr = medicoes['faturadoFinal']?.toString() ?? '';
    double faturadoUsuario = 0.0;
    if (faturadoUsuarioStr.isNotEmpty && faturadoUsuarioStr != '-') {
      try {
        String limpo = faturadoUsuarioStr.replaceAll('.', '').replaceAll(',', '.');
        faturadoUsuario = double.tryParse(limpo) ?? 0.0;
      } catch (e) {
        faturadoUsuario = 0.0;
      }
    }
    
    final volume20Final = extrairNumero(medicoes['volume20Final']?.toString());
    final volume20Inicial = extrairNumero(medicoes['volume20Inicial']?.toString());
    final entradaSaida20 = volume20Final - volume20Inicial;
    final diferenca = entradaSaida20 - faturadoUsuario;
    
    final faturadoFormatado = faturadoUsuario > 0 ? fmt(faturadoUsuario) : "-";
    final diferencaFormatada = fmt(diferenca);
    
    final porcentagem = entradaSaida20 != 0 ? (diferenca / entradaSaida20) * 100 : 0.0;
    final porcentagemFormatada = fmtPercent(porcentagem);
    
    final concatenacao = '$diferencaFormatada   |   $porcentagemFormatada';
    
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          width: 180, // Largura fixa para manter compacto
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey600, width: 0.5),
            borderRadius: pw.BorderRadius.circular(3),
          ),
          child: pw.Table(
            defaultColumnWidth: const pw.IntrinsicColumnWidth(),
            border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
            children: [
              pw.TableRow(
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                    color: PdfColors.grey100,
                    child: pw.Center(
                      child: pw.Text(
                        "Faturado",
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                    color: PdfColors.white,
                    child: pw.Center(
                      child: pw.Text(
                        faturadoFormatado,
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                    color: PdfColors.grey100,
                    child: pw.Center(
                      child: pw.Text(
                        "Diferença",
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                    color: PdfColors.white,
                    child: pw.Center(
                      child: pw.Text(
                        concatenacao,
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: diferenca < 0 ? PdfColors.red : PdfColors.blue,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  static pw.TableRow _linhaMedicaoTabelaCompacta(String descricao, String valorInicial, String valorFinal) {
    return pw.TableRow(
      children: [
        _celulaTabelaMuitoCompacta(descricao, false),
        _celulaTabelaMuitoCompacta(valorInicial, false, centralizado: true),
        _celulaTabelaMuitoCompacta(valorFinal, false, centralizado: true),
      ],
    );
  }
  
  static pw.Container _celulaTabelaMuitoCompacta(String texto, bool isHeader, {bool centralizado = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4), // Reduzido de 6
      child: pw.Text(
        texto,
        style: pw.TextStyle(
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: 8, // Reduzido de 9
          color: isHeader ? PdfColors.white : PdfColors.black,
        ),
        textAlign: centralizado ? pw.TextAlign.center : pw.TextAlign.left,
      ),
      decoration: isHeader 
          ? pw.BoxDecoration(color: PdfColor.fromInt(0xFF0D47A1))
          : null,
    );
  }
  
  // ================= FUNÇÕES DE FORMATAÇÃO =================
  
  static String _obterApenasData(String dataCompleta) {
    if (dataCompleta.contains(',')) {
      return dataCompleta.split(',').first.trim();
    }
    return dataCompleta;
  }
  
  static String _formatarHoraSimples(String? hora) {
    if (hora == null || hora.isEmpty) return '--:--';
    
    String horarioLimpo = hora.trim();
    
    // Remove o "h" se existir
    if (horarioLimpo.toLowerCase().endsWith('h')) {
      return horarioLimpo.substring(0, horarioLimpo.length - 1).trim();
    }
    
    return horarioLimpo;
  }
  
  static String _formatarHorarioCACL(String? horario) {
    if (horario == null || horario.isEmpty) return '--:--';
    
    String horarioLimpo = horario.trim();
    
    if (horarioLimpo.toLowerCase().endsWith('h')) {
      return horarioLimpo;
    }
    
    return '$horarioLimpo h';
  }
  
  static String _formatarAlturaTotalPDF(String? cm, String? mm) {
    if (cm == null || cm.isEmpty) return "-";
    final mmValue = (mm == null || mm.isEmpty) ? "0" : mm;
    return "$cm,$mmValue";
  }
  
  static String _obterValorMedicaoPDF(dynamic valor) {
    if (valor == null) return "-";
    
    if (valor is String) {
      final v = valor.trim();
      if (v.isEmpty) return "-";
      
      final semUnidade = v.replaceAll(" cm", "").trim();
      
      if (semUnidade == "," || semUnidade == "0,0" || semUnidade == "0,00" || 
          semUnidade == "0,000" || semUnidade == "0,0000") {
        return "-";
      }
      
      if (semUnidade == "0,") return "-";
      
      if (semUnidade.startsWith("0,") && semUnidade.substring(2).replaceAll("0", "").isEmpty) {
        return "-";
      }
      
      return v;
    }
    
    return valor.toString();
  }
  
  static String _formatarTemperaturaPDF(dynamic valor) {
    if (valor == null) return "-";
    if (valor is String && valor.isEmpty) return "-";
    
    final strValor = valor.toString().trim();
    
    final valorSemUnidade = strValor
        .replaceAll(' ºC', '')
        .replaceAll('°C', '')
        .replaceAll('ºC', '')
        .trim();
    
    if (valorSemUnidade.isEmpty) return "-";
    
    return '$valorSemUnidade°C';
  }
}