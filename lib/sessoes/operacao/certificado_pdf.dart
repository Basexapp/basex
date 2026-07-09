import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class CertificadoPDF {
  // Função principal para gerar o PDF do Certificado de Apuração de Volumes
  static Future<pw.Document> gerar({
    required String data,
    required String hora,
    required String? produto,
    required Map<String, String> campos,
  }) async {
    final pdf = pw.Document();
    
    // Cores personalizadas
    final azulPrincipal = PdfColor.fromInt(0xFF0D47A1);
    final cinzaClaro = PdfColor.fromInt(0xFFF5F5F5);
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // CABEÇALHO PRINCIPAL
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: cinzaClaro,
                  border: pw.Border.all(color: azulPrincipal, width: 1.5),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'CERTIFICADO DE APURAÇÃO DE VOLUMES',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: azulPrincipal,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Nº de Controle: ${campos['numeroControle']?.isNotEmpty == true ? campos['numeroControle']! : "A SER GERADO"}',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 15),
              
              // INFORMAÇÕES DO CERTIFICADO
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // CARTÃO 1: Informações do Produto
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                        borderRadius: pw.BorderRadius.circular(5),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'INFORMAÇÕES DO PRODUTO',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              color: azulPrincipal,
                              fontSize: 11,
                            ),
                          ),
                          pw.Divider(color: azulPrincipal, height: 10),
                          _infoLinhaPDFCompacta('Produto:', produto ?? "Não informado"),
                          _infoLinhaPDFCompacta('Data da Apuração:', data),
                          _infoLinhaPDFCompacta('Hora da Apuração:', hora),
                          _infoLinhaPDFCompacta('Notas Fiscais:', campos['notas'] ?? ""),
                        ],
                      ),
                    ),
                  ),
                  
                  pw.SizedBox(width: 10),
                  
                  // CARTÃO 2: Informações do Transporte
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                        borderRadius: pw.BorderRadius.circular(5),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'INFORMAÇÕES DO TRANSPORTE',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              color: azulPrincipal,
                              fontSize: 11,
                            ),
                          ),
                          pw.Divider(color: azulPrincipal, height: 10),
                          
                          // Motorista e Transportadora
                          _infoLinhaPDFCompacta('Motorista:', campos['motorista'] ?? ""),
                          _infoLinhaPDFCompacta('Transportadora:', campos['transportadora'] ?? ""),
                          
                          // Placas combinadas
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 6),
                            child: pw.Row(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  'Placas: ',
                                  style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 9,
                                  ),
                                ),
                                pw.Expanded(
                                  child: pw.Text(
                                    _formatarPlacasParaPDF(
                                      cavalo: campos['placaCavalo'],
                                      carreta1: campos['carreta1'],
                                      carreta2: campos['carreta2'],
                                    ),
                                    style: const pw.TextStyle(fontSize: 9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              pw.SizedBox(height: 15),
              
              // SEÇÃO: DADOS DA ANÁLISE
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: cinzaClaro,
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'DADOS DA ANÁLISE',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: azulPrincipal,
                        fontSize: 12,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    
                    // QUADRO: Coletas realizadas
                    pw.Table(
                      columnWidths: {
                        0: const pw.FlexColumnWidth(1.8),
                        1: const pw.FlexColumnWidth(1),
                        2: const pw.FlexColumnWidth(0.7),
                      },
                      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                      children: [
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: PdfColors.grey200),
                          children: [
                            _celulaTabelaCompacta('PARÂMETRO', true),
                            _celulaTabelaCompacta('VALOR', true, centralizado: true),
                            _celulaTabelaCompacta('UNIDADE', true),
                          ],
                        ),
                        _linhaTabelaCompacta('Temperatura da amostra', campos['tempAmostra'] ?? "", '°C'),
                        _linhaTabelaCompacta('Densidade observada', campos['densidadeAmostra'] ?? "", 'g/cm³'),
                        _linhaTabelaCompacta('Temperatura do CT', campos['tempCT'] ?? "", '°C'),
                      ],
                    ),
                    
                    pw.SizedBox(height: 12),
                    
                    // QUADRO: Resultados obtidos
                    pw.Table(
                      columnWidths: {
                        0: const pw.FlexColumnWidth(1.8),
                        1: const pw.FlexColumnWidth(1),
                        2: const pw.FlexColumnWidth(0.7),
                      },
                      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                      children: [
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: PdfColors.grey200),
                          children: [
                            _celulaTabelaCompacta('RESULTADOS OBTIDOS', true),
                            _celulaTabelaCompacta('VALOR', true, centralizado: true),
                            _celulaTabelaCompacta('UNIDADE', true),
                          ],
                        ),
                        _linhaTabelaCompacta('Densidade a 20ºC', campos['densidade20'] ?? "", 'g/cm³'),
                        _linhaTabelaCompacta('Fator de correção (FCV)', campos['fatorCorrecao'] ?? "", ''),
                      ],
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 15),
              
              // SEÇÃO: VOLUMES APURADOS (ÚNICA SEÇÃO COMO NO NOVO FORMULÁRIO)
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: azulPrincipal, width: 1),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'VOLUMES APURADOS',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: azulPrincipal,
                        fontSize: 14,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    
                    // Tabela de volumes
                    pw.Table(
                      columnWidths: {
                        0: const pw.FlexColumnWidth(2),
                        1: const pw.FlexColumnWidth(1),
                        2: const pw.FlexColumnWidth(0.5),
                      },
                      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                      children: [
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: PdfColors.grey200),
                          children: [
                            _celulaTabelaCompacta('DESCRIÇÃO', true),
                            _celulaTabelaCompacta('VOLUME', true, centralizado: true),
                            _celulaTabelaCompacta('UNID.', true),
                          ],
                        ),
                        _linhaTabelaCompacta('Volume carregado (ambiente)', campos['volumeCarregadoAmb'] ?? "", 'L'),
                        _linhaTabelaCompacta('Volume apurado a 20ºC', campos['volumeApurado20C'] ?? "", 'L'),
                      ],
                    ),
                    
                    pw.SizedBox(height: 10),
                    
                    // Observação
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.amber100, // Corrigido
                        borderRadius: pw.BorderRadius.circular(4),
                        border: pw.Border.all(color: PdfColors.amber300, width: 0.5), // Corrigido
                      ),
                      child: pw.Text(
                        'Nota: Os volumes foram apurados conforme procedimento padrão da empresa, considerando as correções de temperatura aplicáveis.',
                        style: pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey700, // Corrigido
                          fontStyle: pw.FontStyle.italic,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    )
                  ],
                ),
              ),
              
              // RODAPÉ COM ASSINATURAS
              pw.Container(
                width: double.infinity,
                margin: const pw.EdgeInsets.only(top: 15),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  children: [
                    // 1️⃣ AVISO "DOCUMENTO VÁLIDO APENAS..."
                    pw.Text(
                      'DOCUMENTO VÁLIDO APENAS COM ASSINATURA',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.red,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 12),
                    
                    // 2️⃣ FRASE DE DECLARAÇÃO DO MOTORISTA
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 20),
                      child: pw.Text(
                        'Eu, ${campos['motorista']?.isNotEmpty == true ? campos['motorista'] : "______________________"}, declaro que acompanhei o processo de coleta e análise, e estou de acordo com os resultados de apuração apresentados neste certificado.',
                        style: pw.TextStyle(
                          fontSize: 7,
                          color: PdfColors.grey600,
                          fontStyle: pw.FontStyle.italic,
                          height: 1.3,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    
                    pw.SizedBox(height: 15),
                    
                    // 3️⃣ ASSINATURA DO MOTORISTA
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('_________________________', 
                          style: pw.TextStyle(fontSize: 9, height: 1)),
                        pw.SizedBox(height: 3),
                        pw.Text('Motorista - ${campos['motorista'] ?? "Não informado"}', 
                          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                        pw.SizedBox(height: 1),
                        pw.Text('', 
                          style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic)),
                      ],
                    ),
                    
                    pw.SizedBox(height: 20),
                    
                    // 4️⃣ ASSINATURAS DOS TÉCNICOS
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        // Assinatura do Responsável pela Coleta
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text('_________________________', 
                              style: pw.TextStyle(fontSize: 9, height: 1)),
                            pw.SizedBox(height: 3),
                            pw.Text('Operador responsável', 
                              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                            pw.SizedBox(height: 2),
                            pw.Text('Coleta e análise', 
                              style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic)),
                          ],
                        ),
                        
                        // Assinatura do Responsável Técnico
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text('_________________________', 
                              style: pw.TextStyle(fontSize: 9, height: 1)),
                            pw.SizedBox(height: 3),
                            pw.Text('Laboratório', 
                              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                            pw.SizedBox(height: 2),
                            pw.Text('Verificação e certificação', 
                              style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic)),
                          ],
                        ),
                      ],
                    ),
                    
                    pw.SizedBox(height: 12),
                    pw.Divider(height: 0.5, color: PdfColors.grey400),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'PowerTank - Sistema de Gestão de Terminais - $data $hora',
                      style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
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
  
  // ================= FUNÇÕES AUXILIARES (privadas) =================
  
  // Versão compacta para informações
  static pw.Widget _infoLinhaPDFCompacta(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '$label ',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value.isEmpty ? 'Não informado' : value,
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }
  
  // Versão compacta para linhas da tabela
  static pw.TableRow _linhaTabelaCompacta(String parametro, String valor, String unidade) {
    return pw.TableRow(
      children: [
        _celulaTabelaCompacta(parametro, false),
        _celulaTabelaCompacta(valor, false, centralizado: true),
        _celulaTabelaCompacta(unidade, false),
      ],
    );
  }
  
  // Versão compacta para células da tabela
  static pw.Container _celulaTabelaCompacta(String texto, bool isHeader, {bool centralizado = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        texto,
        style: pw.TextStyle(
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: 9,
          color: isHeader ? PdfColors.white : PdfColors.black,
        ),
        textAlign: centralizado ? pw.TextAlign.center : pw.TextAlign.left,
      ),
      decoration: isHeader 
          ? pw.BoxDecoration(color: PdfColor.fromInt(0xFF0D47A1))
          : null,
    );
  }

  // Função auxiliar para formatar as placas para o PDF
  static String _formatarPlacasParaPDF({
    String? cavalo,
    String? carreta1,
    String? carreta2,
  }) {
    // Lista para armazenar as placas não vazias
    final List<String> placas = [];
    
    if (cavalo != null && cavalo.trim().isNotEmpty) {
      placas.add(cavalo.trim());
    }
    
    if (carreta1 != null && carreta1.trim().isNotEmpty) {
      placas.add(carreta1.trim());
    }
    
    if (carreta2 != null && carreta2.trim().isNotEmpty) {
      placas.add(carreta2.trim());
    }
    
    // Se não há nenhuma placa
    if (placas.isEmpty) {
      return 'Não informado';
    }
    
    // Junta as placas com vírgula e espaço
    return placas.join(', ');
  }
}