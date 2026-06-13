import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_page.dart';
import 'cacl.dart';

class MedicaoTanquesPage extends StatefulWidget {
  final VoidCallback onVoltar;
  final String? tanqueSelecionadoId;
  final DateTime? dataReferencia;
  final VoidCallback? onFinalizarCACL;
  final List<Map<String, dynamic>>? caclesHoje;
  final bool caclBloqueadoComoVerificacao;
  final bool caclBloqueadoComoMovimentacao;
  final double? estoqueFinalCalculado20;
  final String? movimentacaoIdReferencia;

  const MedicaoTanquesPage({
    super.key,
    required this.onVoltar,
    this.tanqueSelecionadoId,
    this.dataReferencia,
    this.onFinalizarCACL,
    this.caclesHoje,
    this.caclBloqueadoComoVerificacao = false,
    this.caclBloqueadoComoMovimentacao = false,
    this.estoqueFinalCalculado20,
    this.movimentacaoIdReferencia,
  });

  @override
  State<MedicaoTanquesPage> createState() => _MedicaoTanquesPageState();
}

class _MedicaoTanquesPageState extends State<MedicaoTanquesPage> {
  List<Map<String, dynamic>> tanques = [];
  final List<List<TextEditingController>> _controllers = [];
  late final TextEditingController _dataController;
  final List<List<FocusNode>> _focusNodes = [];

  int _tanqueSelecionadoIndex = 0;
  bool _carregando = true;
  String? _nomeTerminal;
  String? _terminalId;

  // Novas variáveis para os tipos de CACL
  bool _caclVerificacao = false;
  bool _caclMovimentacao = false;
  bool _botaoHabilitado = false;

  String _formatarDataDisplay(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

  String _horarioAtualBrasiliaFormatado() {
    final agoraUtc = DateTime.now().toUtc();
    final brasilia = agoraUtc.subtract(const Duration(hours: 3));
    final hora = brasilia.hour.toString().padLeft(2, '0');
    final minuto = brasilia.minute.toString().padLeft(2, '0');
    return '$hora:$minuto h';
  }

  @override
  void initState() {
    super.initState();
    final dataBase = widget.dataReferencia ?? DateTime.now();
    _dataController = TextEditingController(
      text: _formatarDataDisplay(dataBase),
    );

    // Se foi aberto via botão "Fechar Tanque", já vem como verificação
    if (widget.caclBloqueadoComoVerificacao) {
      _caclVerificacao = true;
      _caclMovimentacao = false;
    }

    // Se foi aberto via botão "CACL Movimentação", já vem como movimentação
    if (widget.caclBloqueadoComoMovimentacao) {
      _caclMovimentacao = true;
      _caclVerificacao = false;
    }
    
    _carregarDadosDoUsuario();
    _carregarTanques();
  }

  Future<void> _carregarDadosDoUsuario() async {
    final usuario = UsuarioAtual.instance;
    if (usuario != null) {
      setState(() {
        _terminalId = usuario.terminalId;
        _nomeTerminal = usuario.terminalNome;
      });
    }
  }

  Future<void> _carregarTanques() async {
    try {
      final supabase = Supabase.instance.client;

      if (_terminalId == null) {
        setState(() => _carregando = false);
        return;
      }

      final tanquesResponse = await supabase
          .from('tanques')
          .select('''
            id,
            referencia,
            capacidade,
            id_produto,
            produtos (nome)
          ''')
          .eq('terminal_id', _terminalId!)
          .order('referencia', ascending: true);

      final List<Map<String, dynamic>> tanquesFormatados = [];

      for (final tanque in tanquesResponse) {
        tanquesFormatados.add({
          'id': tanque['id'],
          'numero': tanque['referencia']?.toString() ?? '',
          'produto': tanque['produtos']?['nome']?.toString() ?? '',
          'id_produto': tanque['id_produto']?.toString(),
          'capacidade': '${tanque['capacidade']?.toString() ?? '0'} L',
        });
      }

      final int tanqueIndexSelecionado;
      if (widget.tanqueSelecionadoId != null) {
        final indexEncontrado = tanquesFormatados.indexWhere(
          (tanque) => tanque['id']?.toString() == widget.tanqueSelecionadoId,
        );
        tanqueIndexSelecionado = indexEncontrado >= 0 ? indexEncontrado : 0;
      } else {
        tanqueIndexSelecionado = 0;
      }

      if (mounted) {
        setState(() {
          tanques = tanquesFormatados;
          _tanqueSelecionadoIndex = tanqueIndexSelecionado;
          _carregando = false;
        });
      }

      if (!mounted) return;

      // Limpa controllers e focusNodes antigos
      for (var list in _controllers) {
        for (var c in list) {
          try {
            c.dispose();
          } catch (_) {}
        }
      }
      for (var list in _focusNodes) {
        for (var f in list) {
          try {
            f.dispose();
          } catch (_) {}
        }
      }

      _controllers.clear();
      _focusNodes.clear();

      for (int i = 0; i < tanques.length; i++) {
        _controllers.add([
          // ===== 1ª MEDIÇÃO =====
          TextEditingController(
            text: _horarioAtualBrasiliaFormatado(),
          ), // 0 - horário Inicial
          TextEditingController(), // 1 - cm Inicial
          TextEditingController(), // 2 - mm Inicial
          TextEditingController(), // 3 - temp tanque Inicial
          TextEditingController(), // 4 - densidade Inicial
          TextEditingController(), // 5 - temp amostra Inicial
          TextEditingController(), // 6 - água cm Inicial
          TextEditingController(), // 7 - água mm Inicial
          TextEditingController(), // 8 - observações Inicial
          // ===== 2ª MEDIÇÃO =====
          TextEditingController(), // 9  - horário Final
          TextEditingController(), // 10 - cm Final
          TextEditingController(), // 11 - mm Final
          TextEditingController(), // 12 - temp tanque Final
          TextEditingController(), // 13 - densidade Final
          TextEditingController(), // 14 - temp amostra Final
          TextEditingController(), // 15 - água cm Final
          TextEditingController(), // 16 - água mm Final
          TextEditingController(), // 17 - faturado Final
          TextEditingController(), // 18 - observações Final
        ]);

        _focusNodes.add(List.generate(19, (_) => FocusNode()));

        // Escutar TODOS os campos para garantir validação em tempo real
        for (int j = 0; j < 19; j++) {
          _focusNodes[i][j].addListener(() {
            if (!_focusNodes[i][j].hasFocus && mounted) {
              _verificarCamposObrigatorios();
            }
          });

          _controllers[i][j].addListener(() {
            if (mounted) {
              _verificarCamposObrigatorios();
            }
          });
        }
      }

      _verificarCamposObrigatorios();
    } catch (e) {
      print('Erro ao carregar tanques: $e');
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  String _aplicarMascaraHorario(String texto, {String valorAntigo = ''}) {
    if (valorAntigo.isNotEmpty && texto.length < valorAntigo.length) {
      String limpo = texto.replaceAll(' h', '');
      if (limpo.isEmpty) return '';
      return '$limpo h';
    }

    String apenasNumeros = texto.replaceAll(RegExp(r'[^\d]'), '');

    if (apenasNumeros.length > 4) {
      apenasNumeros = apenasNumeros.substring(0, 4);
    }

    String resultado = '';
    for (int i = 0; i < apenasNumeros.length; i++) {
      if (i == 2) {
        resultado += ':';
      }
      resultado += apenasNumeros[i];
    }

    if (resultado.isNotEmpty) {
      resultado += ' h';
    }

    return resultado;
  }

  String _aplicarMascaraTemperatura(String texto, {String valorAntigo = ''}) {
    if (valorAntigo.isNotEmpty && texto.length < valorAntigo.length) return texto;
    String apenasNumeros = texto.replaceAll(RegExp(r'[^\d]'), '');

    if (apenasNumeros.length > 3) {
      apenasNumeros = apenasNumeros.substring(0, 3);
    }

    String resultado = '';
    for (int i = 0; i < apenasNumeros.length; i++) {
      if (i == 2 && apenasNumeros.length > 2) {
        resultado += ',';
      }
      resultado += apenasNumeros[i];
    }

    return resultado;
  }

  String _aplicarMascaraDensidade(String texto, {String valorAntigo = ''}) {
    if (valorAntigo.isNotEmpty && texto.length < valorAntigo.length) return texto;
    String apenasNumeros = texto.replaceAll(RegExp(r'[^\d]'), '');

    if (apenasNumeros.length > 5) {
      apenasNumeros = apenasNumeros.substring(0, 5);
    }

    if (apenasNumeros.isEmpty) return '';

    String parteInteira = apenasNumeros.substring(0, 1);
    String parteDecimal = '';
    if (apenasNumeros.length > 1) {
      parteDecimal = apenasNumeros.substring(1);
    }

    return parteDecimal.isEmpty
        ? '$parteInteira,'
        : '$parteInteira,$parteDecimal';
  }

  Future<void> _gerarCACL() async {
    if (tanques.isEmpty) return;

    final tanqueAtual = tanques[_tanqueSelecionadoIndex];
    final controllers = _controllers[_tanqueSelecionadoIndex];

    const int segunda = 9;

    // -------- 1ª MEDIÇÃO --------
    final cmTotalInicial = controllers[1].text;
    final mmTotalInicial = controllers[2].text;

    final cmAguaInicial = controllers[6].text;
    final mmAguaInicial = controllers[7].text;

    // -------- 2ª MEDIÇÃO --------
    final cmTotalFinal = controllers[segunda + 1].text;
    final mmTotalFinal = controllers[segunda + 2].text;

    final cmAguaFinal = controllers[segunda + 6].text;
    final mmAguaFinal = controllers[segunda + 7].text;

    // -------- CONVERSÕES --------
    final totalCmInicial = double.tryParse(cmTotalInicial) ?? 0.0;
    final totalMmInicial = double.tryParse(mmTotalInicial) ?? 0.0;
    final aguaCmInicial = double.tryParse(cmAguaInicial) ?? 0.0;
    final aguaMmInicial = double.tryParse(mmAguaInicial) ?? 0.0;

    final totalCmFinal = double.tryParse(cmTotalFinal) ?? 0.0;
    final totalMmFinal = double.tryParse(mmTotalFinal) ?? 0.0;
    final aguaCmFinal = double.tryParse(cmAguaFinal) ?? 0.0;
    final aguaMmFinal = double.tryParse(mmAguaFinal) ?? 0.0;

    final alturaTotalInicialCm = totalCmInicial + (totalMmInicial / 10);
    final alturaAguaInicialCm = aguaCmInicial + (aguaMmInicial / 10);
    final alturaProdutoInicialCm = alturaTotalInicialCm - alturaAguaInicialCm;

    final alturaTotalFinalCm = totalCmFinal + (totalMmFinal / 10);
    final alturaAguaFinalCm = aguaCmFinal + (aguaMmFinal / 10);
    final alturaProdutoFinalCm = alturaTotalFinalCm - alturaAguaFinalCm;

    String formatarParaCACL(double alturaCm) {
      final parteInteira = alturaCm.floor();
      final parteDecimal = ((alturaCm - parteInteira) * 10).round();
      return '$parteInteira,$parteDecimal cm';
    }

    final dadosMedicoes = {
      // Altura total
      'cmInicial': cmTotalInicial,
      'mmInicial': mmTotalInicial,
      'cmFinal': cmTotalFinal,
      'mmFinal': mmTotalFinal,

      // Água
      'alturaAguaInicial': '$cmAguaInicial,$mmAguaInicial cm',
      'alturaAguaFinal': '$cmAguaFinal,$mmAguaFinal cm',

      // Produto
      'alturaProdutoInicial': formatarParaCACL(alturaProdutoInicialCm),
      'alturaProdutoFinal': formatarParaCACL(alturaProdutoFinalCm),

      // 1ª medição
      'horarioInicial': controllers[0].text,
      'tempTanqueInicial': controllers[3].text,
      'densidadeInicial': controllers[4].text,
      'tempAmostraInicial': controllers[5].text,

      // 2ª medição
      'horarioFinal': controllers[segunda + 0].text,
      'tempTanqueFinal': controllers[segunda + 3].text,
      'densidadeFinal': controllers[segunda + 4].text,
      'tempAmostraFinal': controllers[segunda + 5].text,
      'faturadoFinal': controllers[segunda + 8].text,

      // Placeholders
      'volumeProdutoInicial': '0',
      'volumeProdutoFinal': '0',
      'volumeAguaInicial': '0',
      'volumeAguaFinal': '0',
      'volumeTotalInicial': '0',
      'volumeTotalFinal': '0',
      'fatorCorrecaoInicial': '1.0',
      'fatorCorrecaoFinal': '1.0',
      'volume20Inicial': '0',
      'volume20Final': '0',
      'densidade20Inicial': '0.000',
      'densidade20Final': '0.000',
    };

    final dadosFormulario = {
      'data': _dataController.text,
      'base': _nomeTerminal ?? 'POLO DE COMBUSTÍVEL',
      'produto': tanqueAtual['produto'],
      'produto_id': tanqueAtual['id_produto'],
      'tanque': tanqueAtual['numero'],
      'tanque_id': tanqueAtual['id'],
      'origem_estoque_tanque': widget.caclBloqueadoComoVerificacao,
      'estoque_final_calculado_20': widget.estoqueFinalCalculado20,
      'movimentacao_id_referencia': widget.movimentacaoIdReferencia,
      'responsavel': UsuarioAtual.instance?.nome ?? 'Usuário',
      'medicoes': dadosMedicoes,
      'terminal_id': _terminalId,
      'cacl_verificacao': _caclVerificacao,
      'cacl_movimentacao': _caclMovimentacao,
    };

    final resultado = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CalcPage(dadosFormulario: dadosFormulario),
      ),
    );

    if (!mounted) return;

    if (resultado is Map &&
        (resultado['status'] == 'pendente_salvo' ||
            resultado['status'] == 'cacl_finalizado' ||
            resultado['status'] == 'cacl_emitido')) {
      widget.onFinalizarCACL?.call();
      Navigator.of(context).pop(resultado);
    }
  }

  @override
  void dispose() {
    try {
      _dataController.dispose();
    } catch (_) {}
    for (final list in List<List<TextEditingController>>.from(_controllers)) {
      for (final c in List<TextEditingController>.from(list)) {
        try {
          c.dispose();
        } catch (_) {}
      }
    }
    for (final list in List<List<FocusNode>>.from(_focusNodes)) {
      for (final f in List<FocusNode>.from(list)) {
        try {
          f.dispose();
        } catch (_) {}
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            decoration: const BoxDecoration(
              color: Color(0xFFF8F9FA),
              border: Border(bottom: BorderSide(color: Colors.grey, width: 1)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Color(0xFF0D47A1),
                    size: 20,
                  ),
                  onPressed: widget.onVoltar,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Emissão de CACL',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  _dataController.text,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.person, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  UsuarioAtual.instance?.nome ?? 'Usuário',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_nomeTerminal != null) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.business, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    _nomeTerminal!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                ],
                const Spacer(),
              ],
            ),
          ),

          if (widget.tanqueSelecionadoId == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: _carregando
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : tanques.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Nenhum tanque encontrado',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: tanques.asMap().entries.map((entry) {
                          final index = entry.key;
                          final tanque = entry.value;
                          final isSelected = index == _tanqueSelecionadoIndex;

                          final tanqueId = tanque['id']?.toString() ?? '';
                          final quantidadeCacls =
                              _caclsPorTanque[tanqueId] ?? 0;
                          final temCaclsHoje = quantidadeCacls > 0;

                          return Container(
                            margin: const EdgeInsets.only(right: 8),
                            width: 120,
                            constraints: const BoxConstraints(minWidth: 30),
                            child: Stack(
                              children: [
                                ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _tanqueSelecionadoIndex = index;
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isSelected
                                        ? const Color(0xFF0D47A1)
                                        : Colors.white,
                                    foregroundColor: isSelected
                                        ? Colors.white
                                        : const Color(0xFF0D47A1),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: BorderSide(
                                        color: isSelected
                                            ? const Color(0xFF0D47A1)
                                            : Colors.grey.shade300,
                                        width: 1,
                                      ),
                                    ),
                                    elevation: isSelected ? 2 : 0,
                                    shadowColor: Colors.grey.shade300,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        tanque['numero']?.toString() ?? 'N/A',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isSelected
                                              ? Colors.white
                                              : const Color(0xFF0D47A1),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        tanque['produto']?.toString() ?? 'N/A',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isSelected
                                              ? Colors.white70
                                              : Colors.grey.shade600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),

                                // Etiqueta de alerta se houver CACLs
                                if (temCaclsHoje)
                                  Positioned(
                                    top: -4,
                                    right: -4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange[700],
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.2,
                                            ),
                                            blurRadius: 2,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        quantidadeCacls.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
            ),

          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              child: _carregando
                  ? Card(
                      elevation: 2,
                      margin: EdgeInsets.zero,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(height: 16),
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text(
                              'Carregando tanques...',
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    )
                  : tanques.isEmpty
                  ? Card(
                      elevation: 2,
                      margin: EdgeInsets.zero,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Nenhum tanque encontrado',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Não há tanques cadastrados para este terminal',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        // Formulário principal
                        Expanded(
                          child: _buildTanqueCard(
                            tanques[_tanqueSelecionadoIndex],
                            _tanqueSelecionadoIndex,
                          ),
                        ),

                        // Espaço antes das caixas de seleção
                        const SizedBox(height: 8),

                        // CAIXAS DE SELEÇÃO - Agora no meio do espaço
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Column(
                            children: [
                              // Checkboxes
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Caixa de seleção "CACL verificação"
                                  Container(
                                    margin: const EdgeInsets.only(right: 24),
                                    child: Row(
                                      children: [
                                        Checkbox(
                                          value: _caclVerificacao,
                                          onChanged: (widget.caclBloqueadoComoVerificacao ||
                                                  widget.caclBloqueadoComoMovimentacao)
                                              ? null
                                              : (value) {
                                                  setState(() {
                                                    _caclVerificacao =
                                                        value ?? false;
                                                    // Se marcar verificação, desmarca movimentação
                                                    if (_caclVerificacao) {
                                                      _caclMovimentacao = false;
                                                    }
                                                  });
                                                  _verificarCamposObrigatorios();
                                                },
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        Text(
                                          'CACL verificação',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: (widget.caclBloqueadoComoVerificacao ||
                                                    widget.caclBloqueadoComoMovimentacao)
                                                ? Colors.grey
                                                : Colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Caixa de seleção "CACL movimentação"
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: _caclMovimentacao,
                                        onChanged: (widget.caclBloqueadoComoVerificacao ||
                                                widget.caclBloqueadoComoMovimentacao)
                                            ? null
                                            : (value) {
                                                setState(() {
                                                  _caclMovimentacao =
                                                      value ?? false;
                                                  // Se marcar movimentação, desmarca verificação
                                                  if (_caclMovimentacao) {
                                                    _caclVerificacao = false;
                                                  }
                                                });
                                                _verificarCamposObrigatorios();
                                              },
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      Text(
                                        'CACL movimentação',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: (widget.caclBloqueadoComoVerificacao ||
                                                  widget.caclBloqueadoComoMovimentacao)
                                              ? Colors.grey
                                              : Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              const SizedBox(
                                height: 12,
                              ),
                              // Botão Pré-visualização
                              SizedBox(
                                width: 200,
                                child: ElevatedButton(
                                  onPressed: _botaoHabilitado
                                      ? _gerarCACL
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _botaoHabilitado
                                        ? const Color(0xFF0D47A1)
                                        : Colors.grey[400],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    elevation: 2,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.description,
                                        size: 18,
                                        color: _botaoHabilitado
                                            ? Colors.white
                                            : Colors.grey[600],
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Pré-visualização',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: _botaoHabilitado
                                              ? Colors.white
                                              : Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Mensagem de ajuda (opcional)
                              if (!_botaoHabilitado && tanques.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    _caclVerificacao
                                        ? 'No modo Verificação, complete integralmente cada bloco iniciado (exceto Água/Obs/Faturado).'
                                        : 'Preencha os campos obrigatórios (*) da 1ª medição e o faturado.',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.orange[700],
                                      fontStyle: FontStyle.italic,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTanqueCard(Map<String, dynamic> tanque, int index) {
    final ctrls = _controllers[index];
    final focusNodes = _focusNodes[index];

    return SingleChildScrollView(
      child: Card(
        elevation: 2,
        margin: EdgeInsets.zero,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: [
            // CABEÇALHO DO TANQUE
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF0D47A1),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      tanque['numero']?.toString() ?? 'N/A',
                      style: const TextStyle(
                        color: Color(0xFF0D47A1),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tanque['produto']?.toString() ?? 'N/A',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    tanque['capacidade']?.toString() ?? 'N/A',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // FORMULÁRIOS
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ===== 1ª MEDIÇÃO =====
                  Expanded(
                    child: _buildSection(
                      '1ª Medição',
                      'Inicial',
                      Colors.blue[50]!,
                      Colors.blue,
                      ctrls.sublist(0, 9), // 0–8
                      focusNodes.sublist(0, 9), // 0–8
                      ehSegundaMedicao: false,
                    ),
                  ),

                  const SizedBox(width: 16),

                  // ===== 2ª MEDIÇÃO =====
                  Expanded(
                    child: _buildSection(
                      '2ª Medição',
                      'Final',
                      Colors.green[50]!,
                      Colors.green,
                      ctrls.sublist(9, 19), // 9–18
                      focusNodes.sublist(9, 19), // 9–18
                      ehSegundaMedicao: true,
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

  Widget _buildSection(
    String periodo,
    String hora,
    Color bg,
    Color accent,
    List<TextEditingController> c,
    List<FocusNode> f, {
    required bool ehSegundaMedicao,
  }) {
    return FocusScope(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accent.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: accent),
                const SizedBox(width: 6),
                Text(
                  '$periodo - $hora',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: accent,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // LINHA 1 — Horário | cm | mm
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTimeField(
                  'Horário Medição',
                  c[0],
                  '',
                  width: 100,
                  focusNode: f[0],
                  nextFocus: f[1],
                ),
                _buildNumberField(
                  'cm*',
                  c[1],
                  '',
                  width: 100,
                  maxLength: 4,
                  focusNode: f[1],
                  nextFocus: f[2],
                ),
                _buildNumberField(
                  'mm*',
                  c[2],
                  '',
                  width: 100,
                  maxLength: 1,
                  focusNode: f[2],
                  nextFocus: f[3],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // LINHA 2 — Temp. Tanque | Densidade | Temp. Amostra
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTemperatureField(
                  'Temp. Tanque*',
                  c[3],
                  '',
                  width: 100,
                  focusNode: f[3],
                  nextFocus: f[4],
                ),
                _buildDensityField(
                  'Densidade Obs.*',
                  c[4],
                  '',
                  width: 100,
                  focusNode: f[4],
                  nextFocus: f[5],
                ),
                _buildTemperatureField(
                  'Temp. Amostra*',
                  c[5],
                  '',
                  width: 100,
                  focusNode: f[5],
                  nextFocus: f[6],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // LINHA 3 — Água cm | Água mm | (Faturado só na 2ª)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNumberField(
                  'Água cm',
                  c[6],
                  '',
                  width: 100,
                  maxLength: 1,
                  focusNode: f[6],
                  nextFocus: f[7],
                ),
                _buildNumberField(
                  'Água mm',
                  c[7],
                  '',
                  width: 100,
                  maxLength: 1,
                  focusNode: f[7],
                  nextFocus: ehSegundaMedicao
                      ? f[8]
                      : f[8],
                ),
                ehSegundaMedicao
                    ? _buildFaturadoField(
                        'Faturado',
                        c[8],
                        '',
                        width: 100,
                        focusNode: f[8],
                        readOnly: _caclVerificacao,
                        nextFocus: f[9],
                      )
                    : _buildGhostField(width: 100),
              ],
            ),

            // OBSERVAÇÕES
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Observações:',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: ehSegundaMedicao ? c[9] : c[8],
                  focusNode: ehSegundaMedicao ? f[9] : f[8],
                  textInputAction: TextInputAction.done,
                  maxLines: 2,
                  maxLength: 140,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Digite suas observações...',
                    isDense: true,
                    contentPadding: const EdgeInsets.all(10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: Colors.grey.shade400),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: accent, width: 1.5),
                    ),
                    counterText: '',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeField(
    String label,
    TextEditingController ctrl,
    String hint, {
    double width = 100,
    FocusNode? focusNode,
    FocusNode? nextFocus,
  }) {
    String valorAntigo = ctrl.text;
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: width,
          height: 36,
          child: TextFormField(
            controller: ctrl,
            focusNode: focusNode,
            textInputAction: nextFocus != null
                ? TextInputAction.next
                : TextInputAction.done,
            onFieldSubmitted: (_) => nextFocus?.requestFocus(),
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 12),
            onChanged: (value) {
              final maskedValue = _aplicarMascaraHorario(value, valorAntigo: valorAntigo);

              if (maskedValue != value) {
                ctrl.value = TextEditingValue(
                  text: maskedValue,
                  selection: TextSelection.collapsed(
                    offset: maskedValue.endsWith(' h') && maskedValue.length > 2 
                        ? maskedValue.length - 2 
                        : maskedValue.length,
                  ),
                );
              }
              valorAntigo = ctrl.text;
            },
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: BorderSide(color: Colors.grey.shade400),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: const BorderSide(
                  color: Color(0xFF0D47A1),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNumberField(
    String label,
    TextEditingController ctrl,
    String hint, {
    double width = 100,
    int maxLength = 3,
    FocusNode? focusNode,
    FocusNode? nextFocus,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: width,
          height: 36,
          child: TextFormField(
            controller: ctrl,
            focusNode: focusNode,
            textInputAction: nextFocus != null
                ? TextInputAction.next
                : TextInputAction.done,
            onFieldSubmitted: (_) => nextFocus?.requestFocus(),
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 12),
            maxLength: maxLength,
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: BorderSide(color: Colors.grey.shade400),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: const BorderSide(
                  color: Color(0xFF0D47A1),
                  width: 1.5,
                ),
              ),
              counterText: '',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTemperatureField(
    String label,
    TextEditingController ctrl,
    String hint, {
    double width = 100,
    FocusNode? focusNode,
    FocusNode? nextFocus,
  }) {
    String valorAntigo = ctrl.text;
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: width,
          height: 36,
          child: TextFormField(
            controller: ctrl,
            focusNode: focusNode,
            textInputAction: nextFocus != null
                ? TextInputAction.next
                : TextInputAction.done,
            onFieldSubmitted: (_) => nextFocus?.requestFocus(),
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 12),
            onChanged: (value) {
              final maskedValue = _aplicarMascaraTemperatura(value, valorAntigo: valorAntigo);

              if (maskedValue != value) {
                ctrl.value = TextEditingValue(
                  text: maskedValue,
                  selection: TextSelection.collapsed(
                    offset: maskedValue.length,
                  ),
                );
              }
              valorAntigo = ctrl.text;
            },
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: BorderSide(color: Colors.grey.shade400),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: const BorderSide(
                  color: Color(0xFF0D47A1),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDensityField(
    String label,
    TextEditingController ctrl,
    String hint, {
    double width = 100,
    FocusNode? focusNode,
    FocusNode? nextFocus,
  }) {
    String valorAntigo = ctrl.text;
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: width,
          height: 36,
          child: TextFormField(
            controller: ctrl,
            focusNode: focusNode,
            textInputAction: nextFocus != null
                ? TextInputAction.next
                : TextInputAction.done,
            onFieldSubmitted: (_) => nextFocus?.requestFocus(),
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 12),
            onChanged: (value) {
              final maskedValue = _aplicarMascaraDensidade(value, valorAntigo: valorAntigo);

              if (maskedValue != value) {
                ctrl.value = TextEditingValue(
                  text: maskedValue,
                  selection: TextSelection.collapsed(
                    offset: maskedValue.length,
                  ),
                );
              }
              valorAntigo = ctrl.text;
            },
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: BorderSide(color: Colors.grey.shade400),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: const BorderSide(
                  color: Color(0xFF0D47A1),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _aplicarMascaraFaturado(String texto) {
    String apenasNumeros = texto.replaceAll(RegExp(r'[^\d]'), '');

    if (apenasNumeros.length > 6) {
      apenasNumeros = apenasNumeros.substring(0, 6);
    }

    if (apenasNumeros.isEmpty) return '';

    if (apenasNumeros.length > 3) {
      String parteMilhar = apenasNumeros.substring(0, apenasNumeros.length - 3);
      String parteCentena = apenasNumeros.substring(apenasNumeros.length - 3);
      return '$parteMilhar.$parteCentena';
    }

    return apenasNumeros;
  }

  Widget _buildFaturadoField(
    String label,
    TextEditingController ctrl,
    String hint, {
    double width = 100,
    FocusNode? focusNode,
    FocusNode? nextFocus,
    bool readOnly = false,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: width,
          height: 36,
          child: TextFormField(
            controller: ctrl,
            focusNode: focusNode,
            readOnly: readOnly,
            textInputAction: nextFocus != null
                ? TextInputAction.next
                : TextInputAction.done,
            onFieldSubmitted: (_) => nextFocus?.requestFocus(),
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            style: TextStyle(
              fontSize: 12,
              color: readOnly ? Colors.grey : Colors.black,
            ),
            onChanged: (value) {
              if (readOnly) return;
              final cursorPosition = ctrl.selection.baseOffset;
              final maskedValue = _aplicarMascaraFaturado(value);

              if (maskedValue != value) {
                ctrl.value = TextEditingValue(
                  text: maskedValue,
                  selection: TextSelection.collapsed(
                    offset:
                        cursorPosition + (maskedValue.length - value.length),
                  ),
                );
              }
            },
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: BorderSide(color: Colors.grey.shade400),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: BorderSide(
                  color: readOnly ? Colors.grey : const Color(0xFF0D47A1),
                  width: readOnly ? 1.0 : 1.5,
                ),
              ),
              enabled: !readOnly,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGhostField({double width = 100}) {
    return Column(
      children: [
        Opacity(
          opacity: 0,
          child: Text(
            ' ',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(width: width, height: 36),
      ],
    );
  }

  void _verificarCamposObrigatorios() {
    if (tanques.isEmpty || _controllers.isEmpty) {
      if (mounted) setState(() => _botaoHabilitado = false);
      return;
    }

    try {
      final controllers = _controllers[_tanqueSelecionadoIndex];

      bool verificado = false;

      if (_caclVerificacao) {
        // --- LÓGICA CACL VERIFICAÇÃO ---
        // Blocos: 1ª Medição (0-5) e 2ª Medição (9-14)
        // Se algum campo de um bloco for preenchido, o bloco todo torna-se obrigatório.
        // Campos obrigatórios do bloco: Horário, cm, mm, Temp Tanque, Densidade, Temp Amostra.

        final indicesBloco1 = [0, 1, 2, 3, 4, 5];
        final indicesBloco2 = [9, 10, 11, 12, 13, 14];

        final bloco1Iniciado = indicesBloco1.any((idx) => controllers[idx].text.trim().isNotEmpty);
        final bloco2Iniciado = indicesBloco2.any((idx) => controllers[idx].text.trim().isNotEmpty);

        final bloco1Completo = indicesBloco1.every((idx) => controllers[idx].text.trim().isNotEmpty);
        final bloco2Completo = indicesBloco2.every((idx) => controllers[idx].text.trim().isNotEmpty);

        // Se o usuário começou o bloco 1, ele tem que terminar. Idem para o bloco 2.
        // E ao menos um bloco deve estar completo para habilitar.
        final erroBloco1 = bloco1Iniciado && !bloco1Completo;
        final erroBloco2 = bloco2Iniciado && !bloco2Completo;

        verificado = (bloco1Completo || bloco2Completo) && !erroBloco1 && !erroBloco2;
      } else if (_caclMovimentacao) {
        // --- LÓGICA CACL MOVIMENTAÇÃO ---
        // Exige 1ª medição completa (0-5) + Faturado (17) > 0
        final camposObrigatorios1 = controllers.sublist(0, 6);
        final primeiraCompleta = camposObrigatorios1.every((c) => c.text.trim().isNotEmpty);
        final faturadoTexto = controllers[17].text.trim();
        final faturadoValido = _parseFaturado(faturadoTexto) > 0;

        verificado = primeiraCompleta && faturadoValido;
      } else {
        // Caso nenhum tipo selecionado, exige ao menos a 1ª medição básica para segurança? 
        // Na verdade, sem tipo selecionado o botão deveria ficar off.
        verificado = false;
      }

      if (mounted) {
        setState(() => _botaoHabilitado = verificado);
      }
    } catch (e) {
      print('Erro na verificação: $e');
      if (mounted) {
        setState(() => _botaoHabilitado = false);
      }
    }
  }

  int _parseFaturado(String valor) {
    if (valor.isEmpty) return 0;
    final somenteNumeros = valor.replaceAll(RegExp(r'[^0-9]'), '');
    if (somenteNumeros.isEmpty) return 0;
    return int.tryParse(somenteNumeros) ?? 0;
  }

  Map<String, int> get _caclsPorTanque => _calcularCaclsPorTanque();

  Map<String, int> _calcularCaclsPorTanque() {
    final Map<String, int> contagem = {};

    if (widget.caclesHoje == null || widget.caclesHoje!.isEmpty) {
      return contagem;
    }

    final caclesEmitidos = widget.caclesHoje!.where((cacl) {
      final status = cacl['status']?.toString().toLowerCase() ?? '';
      return status.contains('emitido');
    }).toList();

    for (final cacl in caclesEmitidos) {
      final tanqueId = cacl['tanque_id']?.toString();
      if (tanqueId != null && tanqueId.isNotEmpty) {
        contagem[tanqueId] = (contagem[tanqueId] ?? 0) + 1;
      }
    }

    return contagem;
  }
}