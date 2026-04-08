import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_page.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:printing/printing.dart';

class ResultadosPage extends StatefulWidget {
  final VoidCallback? onVoltar;

  const ResultadosPage({super.key, this.onVoltar});

  @override
  State<ResultadosPage> createState() => _ResultadosPageState();
}

class _ResultadosPageState extends State<ResultadosPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final GlobalKey _printKey = GlobalKey();
  
  String? _selectedTerminalId;
  List<Map<String, dynamic>> _terminais = [];
  bool _carregandoTerminais = false;
  bool _isTerminalFixado = false;
  
  DateTime _selectedDate = DateTime.now();
  
  // Dados dos tanques
  List<Map<String, dynamic>> _tanques = [];
  bool _carregandoTanques = false;
  
  // Dados de movimentação por tanque
  Map<String, Map<String, dynamic>> _dadosTanques = {}; // key: tanqueId
  
  // Estados de carregamento
  bool _carregandoDados = false;
  bool _preparandoPdf = false;
  int _segundosRestantes = 0;
  String? _erroMensagem;

  @override
  void initState() {
    super.initState();
    _carregarTerminais();
    
    // Verificar se o usuário tem terminal fixo
    if (UsuarioAtual.instance != null && UsuarioAtual.instance!.terminalId != null) {
      _selectedTerminalId = UsuarioAtual.instance!.terminalId;
      _isTerminalFixado = true;
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    return months[month - 1];
  }

  void _showMonthPicker() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF1565C0), width: 1),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 350),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios, size: 18, color: Color(0xFF1565C0)),
                            onPressed: () {
                              setDialogState(() {
                                _selectedDate = DateTime(_selectedDate.year - 1, _selectedDate.month);
                              });
                            },
                          ),
                          Text(
                            '${_selectedDate.year}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1565C0),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward_ios, size: 18, color: Color(0xFF1565C0)),
                            onPressed: () {
                              setDialogState(() {
                                _selectedDate = DateTime(_selectedDate.year + 1, _selectedDate.month);
                              });
                            },
                          ),
                        ],
                      ),
                      const Divider(),
                      const SizedBox(height: 10),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 1.5,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: 12,
                        itemBuilder: (context, index) {
                          final month = index + 1;
                          final isSelected = _selectedDate.month == month;
                          return InkWell(
                            onTap: () {
                              setState(() {
                                _selectedDate = DateTime(_selectedDate.year, month);
                              });
                              Navigator.pop(context);
                              _carregarDadosMovimentacao();
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF1565C0) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF1565C0) : Colors.grey.shade300,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                _getMonthName(month).substring(0, 3),
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.black87,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('CANCELAR', style: TextStyle(color: Colors.grey)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<Uint8List> _capturarImagem() async {
    await Future.delayed(const Duration(milliseconds: 300));

    final boundary = _printKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);

    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> gerarPdf() async {
    setState(() {
      _preparandoPdf = true;
      _segundosRestantes = 20;
    });

    // Inicia a contagem regressiva em segundo plano (apenas visual)
    _iniciarCronometro();

    try {
      // O PDF é gerado e baixado imediatamente, sem esperar o contador acabar
      final imgBytes = await _capturarImagem();

      final terminalNome = _terminais.firstWhere(
        (t) => t['id'].toString() == _selectedTerminalId,
        orElse: () => {'nome': 'Todos os Terminais'},
      )['nome'];

      final pdf = pw.Document();

      final image = pw.MemoryImage(imgBytes);

      pdf.addPage(
        pw.Page(
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'Resultado Mensal - $terminalNome',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Align(
                alignment: pw.Alignment.topCenter,
                child: pw.Image(image),
              ),
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

  void _iniciarCronometro() async {
    while (_segundosRestantes > 0 && _preparandoPdf) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() {
        _segundosRestantes--;
      });
    }
  }

  Future<void> _carregarTerminais() async {
    setState(() => _carregandoTerminais = true);
    try {
      final user = UsuarioAtual.instance;
      if (user == null) {
        setState(() => _carregandoTerminais = false);
        return;
      }

      if (user.terminalId != null && user.terminalId!.isNotEmpty) {
        final response = await _supabase
            .from('terminais')
            .select('id, nome')
            .eq('id', user.terminalId!)
            .maybeSingle();
        
        if (response != null) {
          setState(() {
            _terminais = [response];
            _selectedTerminalId = user.terminalId;
            _isTerminalFixado = true;
            _carregandoTerminais = false;
          });
          await _carregarTanques();
          return;
        }
      }

      final empresaIdEfetivo = (user.empresaId ?? '').trim();
      List<Map<String, dynamic>> listaTerminais = [];

      if (empresaIdEfetivo.isNotEmpty) {
        final relacoes = await _supabase
            .from('relacoes_terminais')
            .select('terminal_id')
            .eq('empresa_id', empresaIdEfetivo);

        final terminaisIds = relacoes
            .map((r) => r['terminal_id']?.toString())
            .where((id) => id != null && id.isNotEmpty)
            .toSet()
            .toList();

        if (terminaisIds.isNotEmpty) {
          final dados = await _supabase
              .from('terminais')
              .select('id, nome')
              .inFilter('id', terminaisIds)
              .order('nome');

          listaTerminais = dados
              .map<Map<String, dynamic>>((t) => {
                    'id': t['id'].toString(),
                    'nome': t['nome'].toString(),
                  })
              .toList();
        }
      } else {
        final dados = await _supabase
            .from('terminais')
            .select('id, nome')
            .order('nome');

        listaTerminais = dados
            .map<Map<String, dynamic>>((t) => {
                  'id': t['id'].toString(),
                  'nome': t['nome'].toString(),
                })
            .toList();
      }

      setState(() {
        _terminais = listaTerminais;
        _carregandoTerminais = false;
        _isTerminalFixado = false;
      });
      
      if (_selectedTerminalId != null) {
        await _carregarTanques();
      }
    } catch (e) {
      debugPrint('Erro ao carregar terminais: $e');
      setState(() => _carregandoTerminais = false);
    }
  }

  int _extractNumberFromReferencia(String referencia) {
    final regex = RegExp(r'TQ-(\d+)-');
    final match = regex.firstMatch(referencia);
    if (match != null && match.groupCount >= 1) {
      return int.tryParse(match.group(1)!) ?? 0;
    }
    return 0;
  }

  Future<void> _carregarTanques() async {
    if (_selectedTerminalId == null || _selectedTerminalId!.isEmpty) {
      setState(() => _tanques = []);
      return;
    }
    
    setState(() => _carregandoTanques = true);
    try {
      final terminalId = _selectedTerminalId!;
      
      final dados = await _supabase
          .from('tanques')
          .select('''
            id,
            referencia,
            id_produto,
            produtos (
              id,
              nome
            )
          ''')
          .eq('terminal_id', terminalId);
      
      final List<Map<String, dynamic>> tanquesFormatados = [];
      
      for (var tanque in dados) {
        final produto = tanque['produtos'];
        tanquesFormatados.add({
          'id': tanque['id'].toString(),
          'referencia': tanque['referencia'].toString(),
          'produto_nome': produto != null ? produto['nome'].toString() : 'Sem Produto',
          'produto_id': tanque['id_produto']?.toString(),
        });
      }
      
      tanquesFormatados.sort((a, b) {
        final numA = _extractNumberFromReferencia(a['referencia']);
        final numB = _extractNumberFromReferencia(b['referencia']);
        return numA.compareTo(numB);
      });
      
      setState(() {
        _tanques = tanquesFormatados;
        _carregandoTanques = false;
      });
      
      // Após carregar os tanques, carrega os dados de movimentação
      await _carregarDadosMovimentacao();
      
    } catch (e) {
      debugPrint('Erro ao carregar tanques: $e');
      setState(() => _carregandoTanques = false);
    }
  }

  Future<void> _carregarDadosMovimentacao() async {
    if (_tanques.isEmpty) return;
    
    setState(() {
      _carregandoDados = true;
      _erroMensagem = null;
    });
    
    try {
      final inicioMes = DateTime(_selectedDate.year, _selectedDate.month, 1);
      final fimMes = DateTime(_selectedDate.year, _selectedDate.month + 1, 0, 23, 59, 59);
      final dataRefStr = inicioMes.toIso8601String().split('T')[0];
      
      final Map<String, Map<String, dynamic>> novosDados = {};
      
      for (var tanque in _tanques) {
        final tanqueId = tanque['id'];
        
        // 1. Buscar estoque inicial via função do banco
        num estoqueInicial = 0;
        try {
          final response = await _supabase.rpc(
            'fn_estoque_inicial_mes_tanque',
            params: {
              'p_tanque_id': tanqueId,
              'p_data': dataRefStr,
            },
          );
          estoqueInicial = (response['estoque_inicial'] ?? 0) as num;
        } catch (e) {
          debugPrint('Erro ao buscar estoque inicial para tanque $tanqueId: $e');
          estoqueInicial = 0;
        }
        
        // 2. Buscar movimentações do mês
        final movimentacoes = await _supabase
            .from('movimentacoes_tanque')
            .select('''
              entrada_vinte,
              entrada_amb,
              saida_vinte,
              saida_amb,
              tipo_mov,
              descricao,
              cliente
            ''')
            .eq('tanque_id', tanqueId)
            .gte('data_mov', inicioMes.toIso8601String())
            .lte('data_mov', fimMes.toIso8601String());
        
        // 3. Calcular totais
        num totalEntradas = 0;
        num totalSaidas = 0;
        num totalSaidasAmb = 0;
        num totalSobraPerda = 0;
        
        for (final mov in movimentacoes) {
          final num entradaVinte = (mov['entrada_vinte'] ?? 0) as num;
          final num saidaVinte = (mov['saida_vinte'] ?? 0) as num;
          final num saidaAmb = (mov['saida_amb'] ?? 0) as num;
          
          final String tipo = (mov['tipo_mov']?.toString() ?? '').toLowerCase();
          final String desc = (mov['descricao']?.toString() ?? '').toLowerCase();
          final String cli = (mov['cliente']?.toString() ?? '').toLowerCase();
          
          final bool eSobra = tipo.contains('sobra') || desc.contains('sobra') || cli.contains('sobra');
          final bool ePerda = tipo.contains('perda') || desc.contains('perda') || cli.contains('perda');
          
          if (eSobra) {
            totalSobraPerda += entradaVinte;
          } else if (ePerda) {
            totalSobraPerda -= saidaVinte;
          } else {
            totalEntradas += entradaVinte;
            totalSaidas += saidaVinte;
            totalSaidasAmb += saidaAmb;
          }
        }
        
        // 4. Calcular saldo final
        final saldoFinal = estoqueInicial + totalEntradas - totalSaidas + totalSobraPerda;
        
        // 5. Calcular diferença amb/20°C (MODIFICADO: total saídas ambiente - total saídas a 20°C)
        final diferencaAmb = totalSaidasAmb - totalSaidas;
        
        // 6. Novo Total: Soma de Diferença amb + Sobra/Perda
        final totalGeralSegundaTabela = totalSobraPerda + diferencaAmb;
        
        // 7. Calcular variação percentual: Total (da segunda tabela) / Saídas (da primeira tabela)
        double variacaoPercentual = 0;
        if (totalSaidas != 0) {
          variacaoPercentual = (totalGeralSegundaTabela / totalSaidas.abs()) * 100;
        }
        
        novosDados[tanqueId] = {
          'estoqueInicial': estoqueInicial,
          'totalEntradas': totalEntradas,
          'totalSaidas': totalSaidas,
          'saldoFinal': saldoFinal,
          'totalSobraPerda': totalSobraPerda,
          'diferencaAmb': diferencaAmb,
          'totalGeral': totalGeralSegundaTabela,
          'variacaoPercentual': variacaoPercentual,
        };
      }
      
      setState(() {
        _dadosTanques = novosDados;
        _carregandoDados = false;
      });
      
    } catch (e) {
      debugPrint('Erro ao carregar dados de movimentação: $e');
      setState(() {
        _carregandoDados = false;
        _erroMensagem = 'Erro ao carregar dados: $e';
      });
    }
  }

  String _formatarNumero(num? valor) {
    if (valor == null) return '0';
    final abs = valor.abs();
    final str = abs.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      final pos = str.length - i;
      buffer.write(str[i]);
      if (pos > 1 && pos % 3 == 1) buffer.write('.');
    }
    return valor < 0 ? '-${buffer.toString()}' : buffer.toString();
  }

  String _formatarPercentual(double valor) {
    return '${valor.toStringAsFixed(2)} %';
  }

  Widget _buildAppBar() {
    return Container(
      height: kToolbarHeight + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
        left: 16,
        right: 16,
      ),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: widget.onVoltar,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Resultados',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
          if (_carregandoDados)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Widget _buildTerminalSelector() {
    if (_carregandoTerminais) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (UsuarioAtual.instance == null) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 250,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              dropdownColor: Colors.white,
              hint: const Text('Selecione um Terminal', style: TextStyle(fontSize: 14)),
              value: _selectedTerminalId,
              items: [
                if (!_isTerminalFixado)
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Todos os Terminais', style: TextStyle(fontSize: 14)),
                  ),
                ..._terminais.map((t) {
                  return DropdownMenuItem<String>(
                    value: t['id'].toString(),
                    child: Text(t['nome'].toString(), style: const TextStyle(fontSize: 14)),
                  );
                }),
              ],
              onChanged: _isTerminalFixado ? null : (val) {
                setState(() => _selectedTerminalId = val);
                _carregarTanques();
              },
            ),
          ),
        ),
        const SizedBox(width: 16),
        InkWell(
          onTap: _showMonthPicker,
          child: Container(
            width: 180,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_getMonthName(_selectedDate.month)} de ${_selectedDate.year}',
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const Icon(Icons.calendar_today, size: 18, color: Color(0xFF1565C0)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.white,
          body: Column(
            children: [
              _buildAppBar(),
              Container(height: 1, color: Colors.grey.shade200),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32.0),
                  child: Center(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTerminalSelector(),
                        const SizedBox(height: 16),
                        if (_carregandoTanques || _carregandoDados)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32.0),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (_erroMensagem != null)
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                                const SizedBox(height: 16),
                                Text(
                                  _erroMensagem!,
                                  style: const TextStyle(color: Colors.red),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _carregarDadosMovimentacao,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1565C0),
                                  ),
                                  child: const Text('Tentar Novamente'),
                                ),
                              ],
                            ),
                          )
                        else if (_tanques.isEmpty && _selectedTerminalId != null)
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: const Text(
                              'Nenhum tanque encontrado para este terminal.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        else if (_tanques.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTableTitleWithButton(),
                              const SizedBox(height: 16),
                              RepaintBoundary(
                                key: _printKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildTableSection(
                                      title: 'Resumo da movimentação mensal',
                                      rows: _buildSaldoRows,
                                    ),
                                    const SizedBox(height: 24),
                                    _buildTableSection(
                                      title: 'Ganhos / Perdas / Variação',
                                      rows: _buildPerdaSobraRows,
                                      showColumnHeader: false,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
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
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1565C0)),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Relaxe, estamos preparando o PDF. São só $_segundosRestantes segundos',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1565C0),
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Aproveite para tomar um café ☕',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTableTitleWithButton() {
    final double columnWidth = 140.0;
    final double firstColumnWidth = 180.0;
    final double totalWidth = firstColumnWidth + (_tanques.length * columnWidth);
    
    return SizedBox(
      width: totalWidth,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            'Resultado Mensal - ${_terminais.firstWhere(
              (t) => t['id'].toString() == _selectedTerminalId,
              orElse: () => {'nome': 'Todos os Terminais'},
            )['nome']}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF37474F),
            ),
          ),
          Positioned(
            right: 0,
            child: IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: Color(0xFF1565C0)),
              tooltip: 'Gerar PDF',
              onPressed: gerarPdf,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableSection({
    required String title,
    required List<DataRow> Function(double, double) rows,
    bool showColumnHeader = true,
  }) {
    final double columnWidth = 140.0;
    final double firstColumnWidth = 180.0;
    final double totalWidth = firstColumnWidth + (_tanques.length * columnWidth);
    
    return Container(
      width: totalWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.analytics_outlined, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8F9FA)),
              headingRowHeight: showColumnHeader ? 60 : 0,
              dataRowMinHeight: 40,
              dataRowMaxHeight: 40,
              columnSpacing: 0,
              horizontalMargin: 0,
              dividerThickness: 0.5,
              border: TableBorder(
                horizontalInside: BorderSide(color: Colors.grey.shade200),
              ),
              columns: _buildColumns(firstColumnWidth, columnWidth),
              rows: rows(firstColumnWidth, columnWidth),
            ),
          ),
        ],
      ),
    );
  }

  List<DataColumn> _buildColumns(double firstColumnWidth, double columnWidth) {
    final columns = <DataColumn>[
      DataColumn(
        label: SizedBox(
          width: firstColumnWidth,
          child: const Center(
            child: Text(
              '',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF546E7A),
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    ];
    
    for (var tanque in _tanques) {
      columns.add(
        DataColumn(
          label: SizedBox(
            width: columnWidth,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    tanque['referencia'],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF1565C0),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tanque['produto_nome'],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.normal,
                    fontSize: 11,
                    color: Color(0xFF546E7A),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    return columns;
  }

  List<DataRow> _buildSaldoRows(double firstColumnWidth, double columnWidth) {
    final List<DataRow> rows = [];
    
    final aberturaValues = _tanques.map((tanque) {
      final dados = _dadosTanques[tanque['id']];
      return _formatarNumero(dados?['estoqueInicial']);
    }).toList();
    rows.add(_buildDataRow('Abertura Mês', aberturaValues, firstColumnWidth, columnWidth));
    
    final entradasValues = _tanques.map((tanque) {
      final dados = _dadosTanques[tanque['id']];
      return _formatarNumero(dados?['totalEntradas']);
    }).toList();
    rows.add(_buildDataRow('Entradas', entradasValues, firstColumnWidth, columnWidth));
    
    final saidasValues = _tanques.map((tanque) {
      final dados = _dadosTanques[tanque['id']];
      return _formatarNumero(dados?['totalSaidas']);
    }).toList();
    rows.add(_buildDataRow('Saídas', saidasValues, firstColumnWidth, columnWidth));
    
    final saldoValues = _tanques.map((tanque) {
      final dados = _dadosTanques[tanque['id']];
      return _formatarNumero(dados?['saldoFinal']);
    }).toList();
    rows.add(_buildDataRow('Saldo', saldoValues, firstColumnWidth, columnWidth, isHighlighted: true));
    
    return rows;
  }

  List<DataRow> _buildPerdaSobraRows(double firstColumnWidth, double columnWidth) {
    final List<DataRow> rows = [];
    
    final sobraPerdaValues = _tanques.map((tanque) {
      final dados = _dadosTanques[tanque['id']];
      return _formatarNumero(dados?['totalSobraPerda']);
    }).toList();
    rows.add(_buildDataRow('Sobra/Perda (apuração)', sobraPerdaValues, firstColumnWidth, columnWidth));
    
    final diferencaValues = _tanques.map((tanque) {
      final dados = _dadosTanques[tanque['id']];
      return _formatarNumero(dados?['diferencaAmb']);
    }).toList();
    rows.add(_buildDataRow('Diferença amb/20ºC', diferencaValues, firstColumnWidth, columnWidth));
    
    final totalValues = _tanques.map((tanque) {
      final dados = _dadosTanques[tanque['id']];
      return _formatarNumero(dados?['totalGeral']);
    }).toList();
    rows.add(_buildDataRow('Total', totalValues, firstColumnWidth, columnWidth, isHighlighted: true));
    
    final variacaoValues = _tanques.map((tanque) {
      final dados = _dadosTanques[tanque['id']];
      return _formatarPercentual(dados?['variacaoPercentual'] ?? 0);
    }).toList();
    rows.add(_buildDataRow('Variação %', variacaoValues, firstColumnWidth, columnWidth));
    
    return rows;
  }

  DataRow _buildDataRow(String label, List<String> values, double firstColumnWidth, double columnWidth, {bool isHighlighted = false}) {
    return DataRow(
      color: isHighlighted 
          ? WidgetStateProperty.all(const Color(0xFFF0F7FF))
          : null,
      cells: [
        DataCell(
          SizedBox(
            width: firstColumnWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isHighlighted ? const Color(0xFF1565C0) : const Color(0xFF37474F),
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
        ...values.asMap().entries.map((entry) {
          final value = entry.value;
          // Verifica se o valor é negativo para mostrar em vermelho
          final isNegative = value.contains('-') && !value.contains('%');
          return DataCell(
            SizedBox(
              width: columnWidth,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    value,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
                      color: isNegative ? Colors.red : (isHighlighted ? const Color(0xFF1565C0) : const Color(0xFF37474F)),
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}