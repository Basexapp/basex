import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class CACLPdf {
  // Cores compartilhadas usadas pelo PDF
  static final PdfColor azulPrincipal = PdfColor.fromInt(0xFF0D47A1);
  static final PdfColor cinzaClaro = PdfColor.fromInt(0xFFF5F5F5);
  static final PdfColor verdePrincipal = PdfColor.fromInt(0xFF2E7D32);
  // Função principal para gerar o PDF do CACL
  static Future<pw.Document> gerar({
    required Map<String, dynamic> dadosFormulario,
  }) async {
    final pdf = pw.Document();
    
    // Cores personalizadas (usar campos estáticos da classe)
    
    // Normalizar dados recebidos
    final dados = Map<String, dynamic>.from(dadosFormulario);
    final rawMedicoes = dados['medicoes'];
    final medicoes = (rawMedicoes is Map) ? Map<String, dynamic>.from(rawMedicoes) : <String, dynamic>{};
    final data = dados['data']?.toString() ?? "";
    final hora = dados['horarioInicial']?.toString() ?? "";
    
    // Verifica se tem segundo tanque
    final temTanque2 = _temSegundoTanque(medicoes);
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(15),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // CABEÇALHO
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
              
              // INFORMAÇÕES PRINCIPAIS
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
                        pw.Expanded(
                          child: _infoLinhaPDFMuitoCompacta(
                            'Nº Controle:',
                            (dadosFormulario['numero_controle'] ?? 
                            dadosFormulario['numeroControle'] ?? 
                            'A ser gerado').toString(),
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Expanded(
                          child: _infoLinhaPDFMuitoCompacta(
                            'Data:',
                            _obterApenasData(data),
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Expanded(
                          child: _infoLinhaPDFMuitoCompacta(
                            'Terminal:',
                            () {
                              final t = dadosFormulario['terminal'];
                              if (t is Map) {
                                return (t['nome'] ?? t['referencia'] ?? t['nome_dois'])?.toString() ?? 'POLO DE COMBUSTÍVEL';
                              }
                              return dadosFormulario['terminal']?.toString() ?? 'POLO DE COMBUSTÍVEL';
                            }(),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: _infoLinhaPDFMuitoCompacta(
                            'Produto 1:',
                            dadosFormulario['produto']?.toString() ?? "",
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Expanded(
                          child: _infoLinhaPDFMuitoCompacta(
                            'Tanque 1:',
                            dadosFormulario['tanque']?.toString() ?? "",
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        if (temTanque2) ...[
                          pw.Expanded(
                            child: _infoLinhaPDFMuitoCompacta(
                              'Produto 2:',
                              dadosFormulario['produto_2']?.toString() ?? "",
                            ),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Expanded(
                            child: _infoLinhaPDFMuitoCompacta(
                              'Tanque 2:',
                              dadosFormulario['tanque_2']?.toString() ?? "",
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 10),
              
              // SEÇÃO: MEDIÇÕES
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
                    
                    // TABELA DE MEDIÇÕES
                    _tabelaMedicoesPDFCompacta(medicoes, temTanque2),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 10),
              
              // SEÇÃO: COMPARAÇÃO DE RESULTADOS (TOTAIS COMBINADOS)
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
                      'COMPARAÇÃO DE RESULTADOS (TOTAIS COMBINADOS)',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: azulPrincipal,
                        fontSize: 10,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    
                    // TABELA DE COMPARAÇÃO
                    _tabelaComparacaoPDFCompacta(medicoes),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 10),
              
              // SEÇÃO: FATURADO / SOBRA E PERDA
              if (medicoes['faturadoFinal'] != null && medicoes['faturadoFinal'].toString().isNotEmpty)
                pw.Container(
                  width: double.infinity,
                  margin: const pw.EdgeInsets.only(top: 8),
                  child: _blocoFaturadoPDFCompacto(medicoes),
                ),
              
              pw.SizedBox(height: 20),
              
              // RODAPÉ COM ASSINATURAS
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
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
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
                      'PowerTank - ${_obterApenasData(data)} ${_formatarHoraSimples(hora)}',
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
  
  static bool _temSegundoTanque(Map<String, dynamic> medicoes) {
    // Verifica se existem medições para o segundo tanque
    final temIni2 = medicoes['cmInicial2'] != null || medicoes['volumeProdutoInicial2'] != null;
    final temFin2 = medicoes['cmFinal2'] != null || medicoes['volumeProdutoFinal2'] != null;
    return temIni2 || temFin2;
  }
  
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
  
  static pw.Table _tabelaMedicoesPDFCompacta(Map<String, dynamic> medicoes, bool temTanque2) {
    final horarioInicial = _formatarHorarioCACL(medicoes['horarioInicial']);
    final horarioFinal = _formatarHorarioCACL(medicoes['horarioFinal']);
    final horarioInicial2 = _formatarHorarioCACL(medicoes['horarioInicial2']);
    final horarioFinal2 = _formatarHorarioCACL(medicoes['horarioFinal2']);
    
    // Define larguras das colunas baseado se tem segundo tanque
    Map<int, pw.TableColumnWidth> columnWidths;
    if (temTanque2) {
      columnWidths = {
        0: const pw.FlexColumnWidth(2.3),
        1: const pw.FlexColumnWidth(0.9),
        2: const pw.FlexColumnWidth(0.9),
        3: const pw.FlexColumnWidth(0.9),
        4: const pw.FlexColumnWidth(0.9),
      };
    } else {
      columnWidths = {
        0: const pw.FlexColumnWidth(2.5),
        1: const pw.FlexColumnWidth(1.0),
        2: const pw.FlexColumnWidth(1.0),
      };
    }
    
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.3),
      columnWidths: columnWidths,
      children: [
        // CABEÇALHO
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: azulPrincipal,
          ),
          children: [
            _celulaTabelaMuitoCompacta("DESCRIÇÃO", true),
            _celulaTabelaMuitoCompacta(
              "T1 INÍCIO\n$horarioInicial",
              true,
              centralizado: true,
            ),
            _celulaTabelaMuitoCompacta(
              "T1 FINAL\n$horarioFinal",
              true,
              centralizado: true,
            ),
            if (temTanque2) ...[
              _celulaTabelaMuitoCompacta(
                "T2 INÍCIO\n$horarioInicial2",
                true,
                centralizado: true,
                color: verdePrincipal,
              ),
              _celulaTabelaMuitoCompacta(
                "T2 FINAL\n$horarioFinal2",
                true,
                centralizado: true,
                color: verdePrincipal,
              ),
            ],
          ],
        ),
        
        // LINHAS DE MEDIÇÕES
        if (temTanque2)
          _linhaMedicaoTabelaCompactaDupla(
            "Altura total líquido:",
            _formatarAlturaTotalPDF(medicoes['cmInicial'], medicoes['mmInicial']),
            _formatarAlturaTotalPDF(medicoes['cmFinal'], medicoes['mmFinal']),
            _formatarAlturaTotalPDF(medicoes['cmInicial2'], medicoes['mmInicial2']),
            _formatarAlturaTotalPDF(medicoes['cmFinal2'], medicoes['mmFinal2']),
          )
        else
          _linhaMedicaoTabelaCompacta(
            "Altura total líquido:",
            _formatarAlturaTotalPDF(medicoes['cmInicial'], medicoes['mmInicial']),
            _formatarAlturaTotalPDF(medicoes['cmFinal'], medicoes['mmFinal']),
          ),
        
        if (temTanque2)
          _linhaMedicaoTabelaCompactaDupla(
            "Volume total líquido (amb.):",
            _obterValorMedicaoPDF(medicoes['volumeTotalLiquidoInicial']),
            _obterValorMedicaoPDF(medicoes['volumeTotalLiquidoFinal']),
            _obterValorMedicaoPDF(medicoes['volumeTotalLiquidoInicial2']),
            _obterValorMedicaoPDF(medicoes['volumeTotalLiquidoFinal2']),
          )
        else
          _linhaMedicaoTabelaCompacta(
            "Volume total líquido (amb.):",
            _obterValorMedicaoPDF(medicoes['volumeTotalLiquidoInicial']),
            _obterValorMedicaoPDF(medicoes['volumeTotalLiquidoFinal']),
          ),
        
        if (temTanque2)
          _linhaMedicaoTabelaCompactaDupla(
            "Altura água:",
            _obterValorMedicaoPDF(medicoes['alturaAguaInicial']),
            _obterValorMedicaoPDF(medicoes['alturaAguaFinal']),
            _obterValorMedicaoPDF(medicoes['alturaAguaInicial2']),
            _obterValorMedicaoPDF(medicoes['alturaAguaFinal2']),
          )
        else
          _linhaMedicaoTabelaCompacta(
            "Altura água:",
            _obterValorMedicaoPDF(medicoes['alturaAguaInicial']),
            _obterValorMedicaoPDF(medicoes['alturaAguaFinal']),
          ),
        
        if (temTanque2)
          _linhaMedicaoTabelaCompactaDupla(
            "Volume água:",
            _obterValorMedicaoPDF(medicoes['volumeAguaInicial']),
            _obterValorMedicaoPDF(medicoes['volumeAguaFinal']),
            _obterValorMedicaoPDF(medicoes['volumeAguaInicial2']),
            _obterValorMedicaoPDF(medicoes['volumeAguaFinal2']),
          )
        else
          _linhaMedicaoTabelaCompacta(
            "Volume água:",
            _obterValorMedicaoPDF(medicoes['volumeAguaInicial']),
            _obterValorMedicaoPDF(medicoes['volumeAguaFinal']),
          ),
        
        if (temTanque2)
          _linhaMedicaoTabelaCompactaDupla(
            "Altura produto:",
            _obterValorMedicaoPDF(medicoes['alturaProdutoInicial']),
            _obterValorMedicaoPDF(medicoes['alturaProdutoFinal']),
            _obterValorMedicaoPDF(medicoes['alturaProdutoInicial2']),
            _obterValorMedicaoPDF(medicoes['alturaProdutoFinal2']),
          )
        else
          _linhaMedicaoTabelaCompacta(
            "Altura produto:",
            _obterValorMedicaoPDF(medicoes['alturaProdutoInicial']),
            _obterValorMedicaoPDF(medicoes['alturaProdutoFinal']),
          ),
        
        if (temTanque2)
          _linhaMedicaoTabelaCompactaDupla(
            "Volume produto (amb.):",
            _obterValorMedicaoPDF(medicoes['volumeProdutoInicial']),
            _obterValorMedicaoPDF(medicoes['volumeProdutoFinal']),
            _obterValorMedicaoPDF(medicoes['volumeProdutoInicial2']),
            _obterValorMedicaoPDF(medicoes['volumeProdutoFinal2']),
          )
        else
          _linhaMedicaoTabelaCompacta(
            "Volume produto (amb.):",
            _obterValorMedicaoPDF(medicoes['volumeProdutoInicial']),
            _obterValorMedicaoPDF(medicoes['volumeProdutoFinal']),
          ),
        
        if (temTanque2)
          _linhaMedicaoTabelaCompactaDupla(
            "Temp. tanque:",
            _formatarTemperaturaPDF(medicoes['tempTanqueInicial']),
            _formatarTemperaturaPDF(medicoes['tempTanqueFinal']),
            _formatarTemperaturaPDF(medicoes['tempTanqueInicial2']),
            _formatarTemperaturaPDF(medicoes['tempTanqueFinal2']),
          )
        else
          _linhaMedicaoTabelaCompacta(
            "Temp. tanque:",
            _formatarTemperaturaPDF(medicoes['tempTanqueInicial']),
            _formatarTemperaturaPDF(medicoes['tempTanqueFinal']),
          ),
        
        if (temTanque2)
          _linhaMedicaoTabelaCompactaDupla(
            "Densidade observada:",
            _obterValorMedicaoPDF(medicoes['densidadeInicial']),
            _obterValorMedicaoPDF(medicoes['densidadeFinal']),
            _obterValorMedicaoPDF(medicoes['densidadeInicial2']),
            _obterValorMedicaoPDF(medicoes['densidadeFinal2']),
          )
        else
          _linhaMedicaoTabelaCompacta(
            "Densidade observada:",
            _obterValorMedicaoPDF(medicoes['densidadeInicial']),
            _obterValorMedicaoPDF(medicoes['densidadeFinal']),
          ),
        
        if (temTanque2)
          _linhaMedicaoTabelaCompactaDupla(
            "Temp. amostra:",
            _formatarTemperaturaPDF(medicoes['tempAmostraInicial']),
            _formatarTemperaturaPDF(medicoes['tempAmostraFinal']),
            _formatarTemperaturaPDF(medicoes['tempAmostraInicial2']),
            _formatarTemperaturaPDF(medicoes['tempAmostraFinal2']),
          )
        else
          _linhaMedicaoTabelaCompacta(
            "Temp. amostra:",
            _formatarTemperaturaPDF(medicoes['tempAmostraInicial']),
            _formatarTemperaturaPDF(medicoes['tempAmostraFinal']),
          ),
        
        if (temTanque2)
          _linhaMedicaoTabelaCompactaDupla(
            "Densidade 20ºC:",
            _obterValorMedicaoPDF(medicoes['densidade20Inicial']),
            _obterValorMedicaoPDF(medicoes['densidade20Final']),
            _obterValorMedicaoPDF(medicoes['densidade20Inicial2']),
            _obterValorMedicaoPDF(medicoes['densidade20Final2']),
          )
        else
          _linhaMedicaoTabelaCompacta(
            "Densidade 20ºC:",
            _obterValorMedicaoPDF(medicoes['densidade20Inicial']),
            _obterValorMedicaoPDF(medicoes['densidade20Final']),
          ),
        
        if (temTanque2)
          _linhaMedicaoTabelaCompactaDupla(
            "FCV:",
            _obterValorMedicaoPDF(medicoes['fatorCorrecaoInicial']),
            _obterValorMedicaoPDF(medicoes['fatorCorrecaoFinal']),
            _obterValorMedicaoPDF(medicoes['fatorCorrecaoInicial2']),
            _obterValorMedicaoPDF(medicoes['fatorCorrecaoFinal2']),
          )
        else
          _linhaMedicaoTabelaCompacta(
            "FCV:",
            _obterValorMedicaoPDF(medicoes['fatorCorrecaoInicial']),
            _obterValorMedicaoPDF(medicoes['fatorCorrecaoFinal']),
          ),
        
        if (temTanque2)
          _linhaMedicaoTabelaCompactaDupla(
            "Massa produto:",
            _obterValorMedicaoPDF(medicoes['massaInicial']),
            _obterValorMedicaoPDF(medicoes['massaFinal']),
            _obterValorMedicaoPDF(medicoes['massaInicial2']),
            _obterValorMedicaoPDF(medicoes['massaFinal2']),
          )
        else
          _linhaMedicaoTabelaCompacta(
            "Massa produto:",
            _obterValorMedicaoPDF(medicoes['massaInicial']),
            _obterValorMedicaoPDF(medicoes['massaFinal']),
          ),
        
        if (temTanque2)
          _linhaMedicaoTabelaCompactaDupla(
            "Volume 20ºC:",
            _obterValorMedicaoPDF(medicoes['volume20Inicial']),
            _obterValorMedicaoPDF(medicoes['volume20Final']),
            _obterValorMedicaoPDF(medicoes['volume20Inicial2']),
            _obterValorMedicaoPDF(medicoes['volume20Final2']),
          )
        else
          _linhaMedicaoTabelaCompacta(
            "Volume 20ºC:",
            _obterValorMedicaoPDF(medicoes['volume20Inicial']),
            _obterValorMedicaoPDF(medicoes['volume20Final']),
          ),
      ],
    );
  }
  
  static pw.Table _tabelaComparacaoPDFCompacta(Map<String, dynamic> medicoes) {
    // Extrai valores dos dois tanques
    final double volIni1 = _extrairNumero(medicoes['volumeProdutoInicial']?.toString());
    final double volFin1 = _extrairNumero(medicoes['volumeProdutoFinal']?.toString());
    final double vol20Ini1 = _extrairNumero(medicoes['volume20Inicial']?.toString());
    final double vol20Fin1 = _extrairNumero(medicoes['volume20Final']?.toString());
    
    final double volIni2 = _extrairNumero(medicoes['volumeProdutoInicial2']?.toString());
    final double volFin2 = _extrairNumero(medicoes['volumeProdutoFinal2']?.toString());
    final double vol20Ini2 = _extrairNumero(medicoes['volume20Inicial2']?.toString());
    final double vol20Fin2 = _extrairNumero(medicoes['volume20Final2']?.toString());
    
    // Totais combinados
    final double volIniTotal = volIni1 + volIni2;
    final double volFinTotal = volFin1 + volFin2;
    final double vol20IniTotal = vol20Ini1 + vol20Ini2;
    final double vol20FinTotal = vol20Fin1 + vol20Fin2;
    
    final entradaSaidaAmbiente = volFinTotal - volIniTotal;
    final entradaSaida20 = vol20FinTotal - vol20IniTotal;
    
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.3),
      columnWidths: {
        0: const pw.FlexColumnWidth(2.0),
        1: const pw.FlexColumnWidth(0.8),
        2: const pw.FlexColumnWidth(0.8),
        3: const pw.FlexColumnWidth(0.8),
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
        
        // VOLUME AMBIENTE (TOTAL)
        pw.TableRow(
          children: [
            _celulaTabelaMuitoCompacta("Volume ambiente (total)", false),
            _celulaTabelaMuitoCompacta(_fmtVolume(volIniTotal), false, centralizado: true),
            _celulaTabelaMuitoCompacta(_fmtVolume(volFinTotal), false, centralizado: true),
            _celulaTabelaMuitoCompacta(_fmtVolume(entradaSaidaAmbiente), false, centralizado: true),
          ],
        ),
        
        // VOLUME A 20 ºC (TOTAL)
        pw.TableRow(
          children: [
            _celulaTabelaMuitoCompacta("Volume a 20ºC (total)", false),
            _celulaTabelaMuitoCompacta(_fmtVolume(vol20IniTotal), false, centralizado: true),
            _celulaTabelaMuitoCompacta(_fmtVolume(vol20FinTotal), false, centralizado: true),
            _celulaTabelaMuitoCompacta(_fmtVolume(entradaSaida20), false, centralizado: true),
          ],
        ),
        
        // LINHA DE DETALHAMENTO DOS TANQUES (se houver segundo)
        if (_temSegundoTanque(medicoes)) ...[
          pw.TableRow(
            children: [
              _celulaTabelaMuitoCompacta("  └ Tanque 1", false, estilo: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
              _celulaTabelaMuitoCompacta(_fmtVolume(vol20Ini1), false, centralizado: true, estilo: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
              _celulaTabelaMuitoCompacta(_fmtVolume(vol20Fin1), false, centralizado: true, estilo: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
              _celulaTabelaMuitoCompacta(_fmtVolume(vol20Fin1 - vol20Ini1), false, centralizado: true, estilo: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
            ],
          ),
          pw.TableRow(
            children: [
              _celulaTabelaMuitoCompacta("  └ Tanque 2", false, estilo: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
              _celulaTabelaMuitoCompacta(_fmtVolume(vol20Ini2), false, centralizado: true, estilo: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
              _celulaTabelaMuitoCompacta(_fmtVolume(vol20Fin2), false, centralizado: true, estilo: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
              _celulaTabelaMuitoCompacta(_fmtVolume(vol20Fin2 - vol20Ini2), false, centralizado: true, estilo: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
            ],
          ),
        ],
      ],
    );
  }
  
  static pw.Widget _blocoFaturadoPDFCompacto(Map<String, dynamic> medicoes) {
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
    
    // Usa totais combinados
    final double vol20IniFromTotal = _extrairNumero(medicoes['volume20InicialTotal']?.toString());
    final double vol20IniTotal = vol20IniFromTotal > 0
      ? vol20IniFromTotal
      : (_extrairNumero(medicoes['volume20Inicial']?.toString()) + _extrairNumero(medicoes['volume20Inicial2']?.toString()));

    final double vol20FinFromTotal = _extrairNumero(medicoes['volume20FinalTotal']?.toString());
    final double vol20FinTotal = vol20FinFromTotal > 0
      ? vol20FinFromTotal
      : (_extrairNumero(medicoes['volume20Final']?.toString()) + _extrairNumero(medicoes['volume20Final2']?.toString()));
    
    final entradaSaida20 = vol20FinTotal - vol20IniTotal;
    final diferenca = entradaSaida20 - faturadoUsuario;
    
    final faturadoFormatado = faturadoUsuario > 0 ? _fmtVolume(faturadoUsuario) : "-";
    final diferencaFormatada = _fmtVolume(diferenca);
    
    final porcentagem = entradaSaida20 != 0 ? (diferenca / entradaSaida20) * 100 : 0.0;
    final porcentagemFormatada = _fmtPercent(porcentagem);
    
    final concatenacao = '$diferencaFormatada   |   $porcentagemFormatada';
    
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          width: 200,
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
                        "Vol. apurado a 20ºC",
                        style: pw.TextStyle(
                          fontSize: 7,
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
                        _fmtVolume(entradaSaida20),
                        style: pw.TextStyle(
                          fontSize: 8,
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
                        "Faturado",
                        style: pw.TextStyle(
                          fontSize: 7,
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
                          fontSize: 8,
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
                        "Sobra / Perda",
                        style: pw.TextStyle(
                          fontSize: 7,
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
                          fontSize: 8,
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
  
  // ================= FUNÇÕES DE LINHAS DA TABELA =================
  
  static pw.TableRow _linhaMedicaoTabelaCompacta(String descricao, String valorInicial, String valorFinal) {
    return pw.TableRow(
      children: [
        _celulaTabelaMuitoCompacta(descricao, false),
        _celulaTabelaMuitoCompacta(valorInicial, false, centralizado: true),
        _celulaTabelaMuitoCompacta(valorFinal, false, centralizado: true),
      ],
    );
  }
  
  static pw.TableRow _linhaMedicaoTabelaCompactaDupla(
    String descricao, 
    String valorIni1, String valorFin1, 
    String valorIni2, String valorFin2
  ) {
    return pw.TableRow(
      children: [
        _celulaTabelaMuitoCompacta(descricao, false),
        _celulaTabelaMuitoCompacta(valorIni1, false, centralizado: true),
        _celulaTabelaMuitoCompacta(valorFin1, false, centralizado: true),
        _celulaTabelaMuitoCompacta(valorIni2, false, centralizado: true),
        _celulaTabelaMuitoCompacta(valorFin2, false, centralizado: true),
      ],
    );
  }
  
  static pw.Container _celulaTabelaMuitoCompacta(
    String texto, 
    bool isHeader, {
    bool centralizado = false,
    PdfColor? color,
    pw.TextStyle? estilo,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        texto,
        style: estilo ?? pw.TextStyle(
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: isHeader ? 7 : 7,
          color: isHeader ? (color ?? PdfColors.white) : PdfColors.black,
        ),
        textAlign: centralizado ? pw.TextAlign.center : pw.TextAlign.left,
      ),
      decoration: isHeader 
          ? pw.BoxDecoration(color: color ?? PdfColor.fromInt(0xFF0D47A1))
          : null,
    );
  }
  
  // ================= FUNÇÕES DE FORMATAÇÃO =================
  
  static double _extrairNumero(String? valor) {
    if (valor == null || valor.isEmpty) return 0.0;
    final somenteNumeros = valor.replaceAll(RegExp(r'[^0-9]'), '');
    if (somenteNumeros.isEmpty) return 0.0;
    return double.tryParse(somenteNumeros) ?? 0.0;
  }
  
  static String _fmtVolume(double v) {
    if (v.isNaN || v.isInfinite) return "-";
    if (v == 0) return "-";
    
    final isNegativo = v < 0;
    final volumeInteiro = v.abs().round();
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
    
    final sinal = isNegativo ? '-' : '';
    return '$sinal$inteiroFormatado L';
  }
  
  static String _fmtPercent(double v) {
    if (v.isNaN || v.isInfinite) return "-";
    return '${v >= 0 ? '+' : ''}${v.toStringAsFixed(2)}%';
  }
  
  static String _obterApenasData(String dataCompleta) {
    if (dataCompleta.contains(',')) {
      return dataCompleta.split(',').first.trim();
    }
    return dataCompleta;
  }
  
  static String _formatarHoraSimples(String? hora) {
    if (hora == null || hora.isEmpty) return '--:--';
    String horarioLimpo = hora.trim();
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
      if (v.isEmpty || v == "-") return "-";
      return v;
    }
    if (valor is double) {
      if (valor == 0) return "-";
      return valor.toString().replaceAll('.', ',');
    }
    return valor.toString();
  }
  
  static String _formatarTemperaturaPDF(dynamic valor) {
    if (valor == null) return "-";
    final strValor = valor.toString().trim();
    if (strValor.isEmpty || strValor == "-") return "-";
    final valorSemUnidade = strValor
        .replaceAll(' ºC', '')
        .replaceAll('°C', '')
        .replaceAll('ºC', '')
        .trim();
    if (valorSemUnidade.isEmpty) return "-";
    return '$valorSemUnidade°C';
  }
}

// Página que exibe a pré-visualização do PDF gerado pelo CACLPdf
class CaclPdfDuploPage extends StatelessWidget {
  final Map<String, dynamic> dadosFormulario;
  const CaclPdfDuploPage({super.key, required this.dadosFormulario});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'PRÉ-VISUALIZAR CACL',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0D47A1),
      ),
      body: PdfPreview(
        maxPageWidth: 900,
        build: (PdfPageFormat format) async {
          final doc = await CACLPdf.gerar(dadosFormulario: dadosFormulario);
          return doc.save();
        },
        allowPrinting: true,
        allowSharing: true,
      ),
    );
  }
}