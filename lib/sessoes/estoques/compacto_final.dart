import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class CompactoFinalPage extends StatefulWidget {
  const CompactoFinalPage({super.key});

  /// 👇 % da largura da tela usada pelo relatório
  static const double larguraArea = 0.35;

  /// 👇 largura de cada bloco de filial (muito fácil de ajustar)
  static const double blocoLargura = 320;

  /// 👇 altura dos blocos
  static const double blocoAltura = 210;

  /// 👇 largura das células numéricas
  static const double cellWidth = 55;

  /// 👇 largura da coluna de nomes de produto (G.A, S500-A etc)
  static const double larguraNomeProduto = 65;

  /// 👇 margem esquerda da página (ajuste rápido aqui)
  static const double margemEsquerdaPagina = 20;

  /// 👇 radius dos blocos de filial
  static const double radiusBloco = 6;

  /// 👇 radius das células com números
  static const double radiusCelula = 4;

  @override
  State<CompactoFinalPage> createState() => _CompactoFinalPageState();
}

class _CompactoFinalPageState extends State<CompactoFinalPage> {
  final GlobalKey _printKey = GlobalKey();
  bool _preparandoPdf = false;
  int _segundosRestantes = 0;

  Future<Uint8List> _capturarImagem() async {
    await Future.delayed(const Duration(milliseconds: 300));
    final boundary =
        _printKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  void _iniciarCronometro() async {
    while (_segundosRestantes > 0 && _preparandoPdf) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() {
        _segundosRestantes--;
      });
    }
  }

  Future<void> gerarPdf() async {
    setState(() {
      _preparandoPdf = true;
      _segundosRestantes = 20;
    });

    _iniciarCronometro();

    try {
      // Pequeno delay adicional para garantir que o overlay de carregamento
      // não seja capturado ou que o frame esteja pronto
      await Future.delayed(const Duration(milliseconds: 500));
      
      final imgBytes = await _capturarImagem();
      final pdf = pw.Document();
      final image = pw.MemoryImage(imgBytes);

      final hoje = DateTime.now();
      final dataStr =
          "${hoje.day.toString().padLeft(2, '0')}/${hoje.month.toString().padLeft(2, '0')}/${hoje.year}";

      pdf.addPage(
        pw.Page(
          margin: const pw.EdgeInsets.all(20),
          build: (context) => pw.Column(
            children: [
              pw.Header(
                level: 0,
                child: pw.Text(
                  'Relatório Compacto - $dataStr',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Image(image),
            ],
          ),
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
      );
    } catch (e) {
      debugPrint('Erro ao gerar PDF: $e');
    } finally {
      if (mounted) {
        setState(() {
          _preparandoPdf = false;
          _segundosRestantes = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final larguraTela = MediaQuery.of(context).size.width;

    final hoje = DateTime.now();
    final data =
        "${hoje.day.toString().padLeft(2, '0')}/${hoje.month.toString().padLeft(2, '0')}/${hoje.year}";

    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xfff2f2f2),
          body: SingleChildScrollView(
            child: Padding(
            padding: const EdgeInsets.only(
                left: CompactoFinalPage.margemEsquerdaPagina),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: larguraTela * CompactoFinalPage.larguraArea,
                child: RepaintBoundary(
                  key: _printKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _topBar(context, data),
                      const SizedBox(height: 8),

                      ListView(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: const [
                            CompactoBloco(
                              titulo: "Base São Caetano",
                              linhas: [
                                ["G.A", "820", "140", "960", Colors.amber],
                                ["S500-A", "740", "120", "860", Colors.brown],
                                ["S10-A", "690", "110", "800", Colors.purple],
                                ["A", "210", "90", "300", Colors.green],
                                ["H", "430", "70", "500", Colors.blueGrey],
                                ["B100", "120", "40", "160", Colors.cyan],
                              ],
                              saldosCotas: [
                                {'sigla': 'G', 'valor': 350},
                                {'sigla': 'D', 'valor': 120},
                                {'sigla': 'S10', 'valor': 480},
                              ],
                            ),
                            SizedBox(height: 10),
                            CompactoBloco(
                              titulo: "Base Guarulhos",
                              linhas: [
                                ["G.A", "820", "140", "960", Colors.amber],
                                ["S500-A", "740", "120", "860", Colors.brown],
                                ["S10-A", "690", "110", "800", Colors.purple],
                                ["A", "210", "90", "300", Colors.green],
                                ["H", "430", "70", "500", Colors.blueGrey],
                                ["B100", "120", "40", "160", Colors.cyan],
                              ],
                              saldosCotas: [
                                {'sigla': 'G', 'valor': 210},
                                {'sigla': 'D', 'valor': 450},
                                {'sigla': 'S10', 'valor': 95},
                              ],
                            ),
                            SizedBox(height: 10),
                            CompactoBloco(
                              titulo: "Base Osasco",
                              linhas: [
                                ["G.A", "780", "150", "930", Colors.amber],
                                ["S500-A", "650", "140", "790", Colors.brown],
                                ["S10-A", "620", "135", "755", Colors.purple],
                                ["A", "240", "95", "335", Colors.green],
                                ["H", "410", "85", "495", Colors.blueGrey],
                                ["B100", "130", "45", "175", Colors.cyan],
                              ],
                            ),
                            SizedBox(height: 10),
                            CompactoBloco(
                              titulo: "Base Barueri",
                              linhas: [
                                ["G.A", "810", "160", "970", Colors.amber],
                                ["S500-A", "700", "150", "850", Colors.brown],
                                ["S10-A", "660", "140", "800", Colors.purple],
                                ["A", "250", "100", "350", Colors.green],
                                ["H", "420", "80", "500", Colors.blueGrey],
                                ["B100", "140", "50", "190", Colors.cyan],
                              ],
                            ),
                            SizedBox(height: 10),
                            _TotaisGerais(
                              itens: [
                                ["G.A", "4.000", "710", "4.710", Colors.amber],
                                ["S500-A", "3.540", "690", "4.230", Colors.brown],
                                ["S10-A", "3.360", "635", "3.995", Colors.purple],
                              ],
                            ),
                            SizedBox(height: 20),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_preparandoPdf)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF1565C0)),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Relaxe, estamos preparando o PDF. São só $_segundosRestantes segundos',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _topBar(BuildContext context, String data) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        Text(
          "Relatório Compacto - $data",
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.picture_as_pdf,
              color: Color(0xFF1565C0), size: 20),
          tooltip: 'Gerar PDF',
          onPressed: gerarPdf,
        ),
      ],
    );
  }
}

class _TotaisGerais extends StatelessWidget {
  final List<dynamic> itens;

  const _TotaisGerais({required this.itens});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: CompactoFinalPage.blocoLargura,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFF0D47A1), width: 1),
        borderRadius: BorderRadius.circular(CompactoFinalPage.radiusBloco),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.summarize, size: 12, color: Color(0xFF0D47A1)),
              SizedBox(width: 4),
              Text(
                "TOTAL GERAL",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  color: Color(0xFF0D47A1),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const Divider(height: 8, thickness: 0.5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: itens.map((l) {
              final nome = l[0] as String;
              final v3 = l[3] as String;
              final cor = l[4] as Color;

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 3,
                    height: 10,
                    decoration: BoxDecoration(
                      color: cor,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "$nome: ",
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    v3,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D47A1),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class CompactoBloco extends StatelessWidget {
  final String titulo;
  final List<dynamic> linhas;
  final List<Map<String, dynamic>>? saldosCotas;

  const CompactoBloco({
    super.key,
    required this.titulo,
    required this.linhas,
    this.saldosCotas,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: CompactoFinalPage.blocoLargura,
      height: CompactoFinalPage.blocoAltura,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(CompactoFinalPage.radiusBloco),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on, size: 14, color: Color(0xFF0D47A1)),
                  const SizedBox(width: 4),
                  Text(
                    titulo,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0D47A1)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: linhas.map((l) {
                    final nome = l[0] as String;
                    final v1 = l[1] as String;
                    final v2 = l[2] as String;
                    final v3 = l[3] as String;
                    final cor = l[4] as Color;

                    return Row(
                      children: [

                        SizedBox(
                          width: CompactoFinalPage.larguraNomeProduto,
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: cor,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                nome,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),

                        _cell(v1),

                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 5),
                          child: Text("+", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                        ),

                        _cell(v2, semEstilo: true),

                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 5),
                          child: Text("=", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                        ),

                        _cell(v3, negrito: true),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          if (saldosCotas != null)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 95,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Center(
                      child: Text(
                        "Saldo de Cotas",
                        style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Divider(height: 6, thickness: 0.5),
                    ...saldosCotas!.map((s) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1.5),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(s['sigla'], style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w500)),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              s['valor'].toString(),
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 8, color: Color(0xFF0D47A1), fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            flex: 3,
                            child: Text(
                              "${(s['valor'] / 5).toStringAsFixed(0)}%",
                              textAlign: TextAlign.right,
                              style: TextStyle(fontSize: 8, color: Colors.green.shade700, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _cell(String v, {bool negrito = false, bool semEstilo = false}) {
    return Container(
      width: CompactoFinalPage.cellWidth,
      height: 20,
      alignment: Alignment.center,
      decoration: semEstilo
          ? null
          : BoxDecoration(
              color: const Color(0xfff8f8f8),
              border: Border.all(color: Colors.grey.shade300, width: 0.8),
              borderRadius: BorderRadius.circular(CompactoFinalPage.radiusCelula),
            ),
      child: Text(
        v,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10,
          fontWeight: negrito ? FontWeight.bold : FontWeight.normal,
          color: negrito ? const Color(0xFF0D47A1) : Colors.black87,
        ),
      ),
    );
  }
}