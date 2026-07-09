import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class OrdemCarregamentoPdf {
  static Future<pw.Document> gerar({
    required Map<String, dynamic> dados,
  }) async {
    final pdf = pw.Document();

    final azul = PdfColor.fromInt(0xFF0D47A1);
    final cinza = PdfColor.fromInt(0xFFF5F5F5);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(18),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [

              // CABEÇALHO
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: cinza,
                  border: pw.Border.all(color: azul, width: 1),
                ),
                child: pw.Column(
                  children: [

                    pw.Text(
                      'ORDEM DE CARREGAMENTO',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: azul,
                      ),
                    ),

                    pw.SizedBox(height: 4),

                    pw.Text(
                      'Documento obrigatório durante toda operação',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 14),

              // DADOS PRINCIPAIS
              _bloco(
                titulo: 'DADOS DA ORDEM',
                azul: azul,
                child: pw.Column(
                  children: [

                    pw.Row(
                      children: [
                        _campo('Nº Ordem', 'OC-000154'),
                        _campo('Data', '12/05/2026'),
                        _campo('Hora', '08:42'),
                      ],
                    ),

                    pw.SizedBox(height: 8),

                    pw.Row(
                      children: [
                        _campo('Transportadora', 'TransBahia Logística'),
                        _campo('Motorista', 'Carlos Oliveira'),
                      ],
                    ),

                    pw.SizedBox(height: 8),

                    pw.Row(
                      children: [
                        _campo('Placa Cavalo', 'RPD-4A21'),
                        _campo('Placa Carreta', 'QTX-9B77'),
                        _campo('UF', 'BA'),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              // PRODUTOS
              _bloco(
                titulo: 'PRODUTOS PROGRAMADOS',
                azul: azul,
                child: pw.Table(
                  border: pw.TableBorder.all(
                    color: PdfColors.grey400,
                    width: 0.5,
                  ),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3),
                    1: const pw.FlexColumnWidth(1.5),
                    2: const pw.FlexColumnWidth(1.5),
                  },
                  children: [

                    pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: azul,
                      ),
                      children: [
                        _header('Produto'),
                        _header('Compartimento'),
                        _header('Quantidade'),
                      ],
                    ),

                    _linhaProduto('Óleo Diesel S10', '1', '15.000 L'),
                    _linhaProduto('Gasolina Comum', '2', '10.000 L'),
                    _linhaProduto('Etanol', '3', '5.000 L'),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              // ETAPAS
              _bloco(
                titulo: 'CONTROLE OPERACIONAL',
                azul: azul,
                child: pw.Column(
                  children: [

                    _etapa('Portaria', 'Pendente'),
                    _etapa('Check-list', 'Pendente'),
                    _etapa('Operação', 'Pendente'),
                    _etapa('Liberação Fiscal', 'Pendente'),
                    _etapa('Saída', 'Pendente'),

                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // OBSERVAÇÃO
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: PdfColors.grey400,
                    width: 0.5,
                  ),
                ),
                child: pw.Text(
                  'Este documento deve permanecer com o motorista durante toda permanência na base.',
                  style: const pw.TextStyle(
                    fontSize: 9,
                  ),
                ),
              ),

              pw.Spacer(),

              // ASSINATURAS
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [

                  _assinatura('Operador'),

                  _assinatura('Motorista'),

                  _assinatura('Portaria'),

                ],
              ),

              pw.SizedBox(height: 18),

              pw.Center(
                child: pw.Text(
                  'PowerTank',
                  style: pw.TextStyle(
                    fontSize: 7,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  static pw.Widget _bloco({
    required String titulo,
    required PdfColor azul,
    required pw.Widget child,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFF8F8F8),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [

          pw.Text(
            titulo,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: azul,
            ),
          ),

          pw.SizedBox(height: 6),

          child,
        ],
      ),
    );
  }

  static pw.Widget _campo(String titulo, String valor) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [

          pw.Text(
            titulo,
            style: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
            ),
          ),

          pw.SizedBox(height: 2),

          pw.Text(
            valor,
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
    );
  }

  static pw.Widget _header(String texto) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        texto,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.TableRow _linhaProduto(
    String produto,
    String compartimento,
    String quantidade,
  ) {
    return pw.TableRow(
      children: [
        _celula(produto),
        _celula(compartimento, center: true),
        _celula(quantidade, center: true),
      ],
    );
  }

  static pw.Widget _celula(
    String texto, {
    bool center = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        texto,
        style: const pw.TextStyle(fontSize: 8),
        textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
      ),
    );
  }

  static pw.Widget _etapa(String etapa, String status) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 4),
      padding: const pw.EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 6,
      ),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
          color: PdfColors.grey300,
          width: 0.4,
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [

          pw.Text(
            etapa,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 8,
            ),
          ),

          pw.Text(
            status,
            style: const pw.TextStyle(
              fontSize: 8,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _assinatura(String titulo) {
    return pw.Column(
      children: [

        pw.Text(
          '________________________',
          style: const pw.TextStyle(fontSize: 8),
        ),

        pw.SizedBox(height: 2),

        pw.Text(
          titulo,
          style: pw.TextStyle(
            fontSize: 7,
            color: PdfColors.grey700,
          ),
        ),
      ],
    );
  }
}