import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class OrdemCarregamentoVendaPDF {
  static Future<pw.Document> gerar({
    required Map<String, dynamic> dados,
  }) async {
    final pdf = pw.Document();

    final azul = PdfColor.fromInt(0xFF0D47A1);
    final cinza = PdfColor.fromInt(0xFFF5F5F5);

    // Extração de dados com fallbacks
    final ordemId = (dados['ordens'] != null && dados['ordens']['n_controle'] != null)
        ? dados['ordens']['n_controle'].toString()
        : (dados['ordem_id']?.toString() ?? '---');
    final dataMov = dados['data_mov']?.toString() ?? '';
    final dataFormatada = dataMov.isNotEmpty ? dataMov.split('T')[0].split('-').reversed.join('/') : '---';
    final horaFormatada = dataMov.length >= 16 ? dataMov.substring(11, 16) : '---';
    
    final transportadora = dados['cliente']?.toString() ?? 'Consumo Próprio'; // Ajustado para contexto de venda
    final motorista = dados['motorista']?.toString() ?? 'Não identificado';
    
    final placas = dados['placa'];
    String placaCavalo = '---';
    if (placas is List && placas.isNotEmpty) {
      placaCavalo = placas[0].toString();
    } else if (placas != null) {
      placaCavalo = placas.toString();
    }
    
    final uf = dados['uf']?.toString() ?? '---';
    final produtoNome = dados['produto_nome']?.toString() ?? '---';
    final quantidade = dados['saida_amb']?.toString() ?? '0';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // CABEÇALHO
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: cinza,
                  border: pw.Border.all(color: azul, width: 1.5),
                  borderRadius: pw.BorderRadius.circular(6),
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
                      'Documento obrigatório durante toda a operação',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // DADOS DA ORDEM
              _bloco(
                titulo: 'DADOS DA ORDEM',
                azul: azul,
                child: pw.Column(
                  children: [
                    pw.Row(
                      children: [
                        _campo('Nº Ordem', ordemId),
                        _campo('Data', dataFormatada),
                        _campo('Hora', horaFormatada),
                      ],
                    ),
                    pw.SizedBox(height: 10),
                    pw.Row(
                      children: [
                        _campo('Cliente/Transportadora', transportadora),
                        _campo('Motorista', motorista),
                      ],
                    ),
                    pw.SizedBox(height: 10),
                    pw.Row(
                      children: [
                        _campo('Placa Cavalo', placaCavalo),
                        _campo('UF', uf),
                        _campo('Status', 'PROGRAMADO'),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 15),

              // PRODUTOS
              _bloco(
                titulo: 'PRODUTOS PROGRAMADOS',
                azul: azul,
                child: pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: azul),
                      children: [
                        _header('Produto'),
                        _header('Compartimento'),
                        _header('Quantidade'),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        _celula(produtoNome),
                        _celula('1', center: true),
                        _celula('$quantidade L', center: true),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 15),

              // CONTROLE OPERACIONAL
              _bloco(
                titulo: 'CONTROLE OPERACIONAL',
                azul: azul,
                child: pw.Column(
                  children: [
                    _etapa('Portaria', 'Pendente'),
                    _etapa('Check-list', 'Pendente'),
                    _etapa('Operação de Carregamento', 'Pendente'),
                    _etapa('Liberação Fiscal / Notas', 'Pendente'),
                    _etapa('Saída do Terminal', 'Pendente'),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // OBSERVAÇÃO
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  'Este documento deve permanecer com o motorista durante toda a permanência na base e deve ser apresentado nos pontos de controle.',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),

              pw.Spacer(),

              // ASSINATURAS
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _assinatura('Responsável Operacional'),
                  _assinatura('Motorista'),
                  _assinatura('Portaria / Segurança'),
                ],
              ),

              pw.SizedBox(height: 20),
              pw.Center(
                child: pw.Text(
                  'Base-X Management Systems - ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                  style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  static pw.Widget _bloco({required String titulo, required PdfColor azul, required pw.Widget child}) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFFBFBFB),
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            titulo,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: azul),
          ),
          pw.Divider(color: azul, thickness: 0.5, height: 10),
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
          pw.Text(titulo, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
          pw.SizedBox(height: 2),
          pw.Text(valor, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static pw.Widget _header(String texto) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        texto,
        style: pw.TextStyle(color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _celula(String texto, {bool center = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        texto,
        style: const pw.TextStyle(fontSize: 9),
        textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
      ),
    );
  }

  static pw.Widget _etapa(String etapa, String status) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(etapa, style: const pw.TextStyle(fontSize: 9)),
          pw.Text(status, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
        ],
      ),
    );
  }

  static pw.Widget _assinatura(String titulo) {
    return pw.Column(
      children: [
        pw.Container(
          width: 120,
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(width: 0.5)),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(titulo, style: pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
      ],
    );
  }
}
