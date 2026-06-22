import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_page.dart';

class _FocusDataIntent extends Intent {
  const _FocusDataIntent();
}

class _FocusQtd20Intent extends Intent {
  const _FocusQtd20Intent();
}

class _FocusPrecoIntent extends Intent {
  const _FocusPrecoIntent();
}

class CriarOrdemPage extends StatefulWidget {
  final VoidCallback? onCreated;
  final VoidCallback? onVoltar;
  const CriarOrdemPage({super.key, this.onCreated, this.onVoltar});

  @override
  State<CriarOrdemPage> createState() => _CriarOrdemPageState();
}

class _CriarOrdemPageState extends State<CriarOrdemPage> {
  final _formKey = GlobalKey<FormState>();

  final _origemCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();
  final _dataCtrl = TextEditingController();
  final _qtdAmbCtrl = TextEditingController();
  final _qtd20Ctrl = TextEditingController();
  final _valorUnitCtrl = TextEditingController();
  final _valorNfCtrl = TextEditingController();
  final _placaCtrl = TextEditingController();

  final FocusNode _valorNfFocus = FocusNode();
  final FocusNode _origemFocus = FocusNode();
  final FocusNode _notaFocus = FocusNode();
  final FocusNode _dataFocus = FocusNode();
  final FocusNode _qtdAmbFocus = FocusNode();
  final FocusNode _qtd20Focus = FocusNode();
  final FocusNode _produtoFocus = FocusNode();
  final FocusNode _terminalFocus = FocusNode();
  final FocusNode _placaFocus = FocusNode();
  final FocusNode _valorUnitFocus = FocusNode();

  String? _produtoSelecionado;
  List<Map<String, dynamic>> _produtos = [];
  String? _terminalSelecionado;
  List<Map<String, dynamic>> _terminais = [];
  String _tipoOperacao = 'Entrada';
  String _tipoOp = 'Compra';

  final supabase = Supabase.instance.client;
  bool _dateAlertShown = false;

  @override
  void initState() {
    super.initState();
    _carregarProdutos();
    _carregarTerminais();
    final usuarioInit = UsuarioAtual.instance;
    if (usuarioInit != null && usuarioInit.nivel != 3) {
      _terminalSelecionado = usuarioInit.terminalId;
    }
    _qtd20Ctrl.addListener(_atualizarValorNf);
    _valorUnitCtrl.addListener(_atualizarValorNf);
  }

  Future<void> _carregarTerminais() async {
    final res = await supabase.from('terminais').select('id, nome').order('nome');
    setState(() {
      _terminais = List<Map<String, dynamic>>.from(res);
    });
  }

  void _atualizarValorNf() {
    if (_valorNfFocus.hasFocus) return;

    final qtdText = _qtd20Ctrl.text.trim();
    final precoText = _valorUnitCtrl.text.trim();

    if (qtdText.isEmpty || precoText.isEmpty) return;

    try {
      final qtd = int.parse(qtdText.replaceAll(RegExp(r'[^0-9]'), ''));
      final precoNormalizado = precoText
          .replaceAll('.', '')
          .replaceAll(',', '.');
      final preco = double.tryParse(precoNormalizado);
      if (preco == null) return;

      final total = qtd * preco;
      final formatted = NumberFormat.currency(
        locale: 'pt_BR',
        symbol: 'R\$',
      ).format(total);

      _valorNfCtrl.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _origemCtrl.dispose();
    _notaCtrl.dispose();
    _dataCtrl.dispose();
    _qtdAmbCtrl.dispose();
    _qtd20Ctrl.dispose();
    _valorUnitCtrl.dispose();
    _valorNfCtrl.dispose();
    _placaCtrl.dispose();
    _valorNfFocus.dispose();
    _origemFocus.dispose();
    _notaFocus.dispose();
    _dataFocus.dispose();
    _qtdAmbFocus.dispose();
    _qtd20Focus.dispose();
    _produtoFocus.dispose();
    _terminalFocus.dispose();
    _placaFocus.dispose();
    _valorUnitFocus.dispose();
    super.dispose();
  }

  Future<void> _carregarProdutos() async {
    final res = await supabase.from('produtos').select('id, nome').order('nome');
    setState(() {
      _produtos = List<Map<String, dynamic>>.from(res);
    });
  }

  String _aplicarMascaraPlaca(String texto) {
    final limpo = texto.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

    if (limpo.length <= 3) return limpo;

    final letras = limpo.substring(0, 3);
    final numeros = limpo.substring(3, limpo.length.clamp(3, 7));

    return '$letras-$numeros';
  }

  String _formatMilhar(String value) {
    final numeric = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (numeric.isEmpty) return '';
    final number = int.parse(numeric);
    return NumberFormat.decimalPattern('pt_BR').format(number);
  }

  String _formatMoeda(String value) {
    final numeric = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (numeric.isEmpty) return '';
    final number = double.parse(numeric) / 100;
    return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(number);
  }

  String _formatData(String value) {
    final v = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (v.isEmpty) return '';
    if (v.length <= 2) return v;
    if (v.length <= 4) return '${v.substring(0, 2)}/${v.substring(2)}';
    final day = v.substring(0, 2);
    final month = v.substring(2, 4);
    final year = v.length >= 8 ? v.substring(4, 8) : v.substring(4);
    return '$day/$month/$year';
  }

  void _validarData(String dataText) {
    try {
      final data = DateFormat('dd/MM/yyyy').parse(dataText);
      final hoje = DateTime.now();
      final hojeSemHora = DateTime(hoje.year, hoje.month, hoje.day);
      final diff = data.difference(hojeSemHora).inDays;
      if (diff > 30 || diff < -30) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_dateAlertShown) {
            _showDateAlert();
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _showDateAlert() async {
    _dateAlertShown = true;
    try {
      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) {
          return Shortcuts(
            shortcuts: <LogicalKeySet, Intent>{
              LogicalKeySet(LogicalKeyboardKey.escape): const ActivateIntent(),
            },
            child: Actions(
              actions: <Type, Action<Intent>>{
                ActivateIntent: CallbackAction<Intent>(
                  onInvoke: (Intent intent) {
                    Navigator.of(ctx).pop();
                    return null;
                  },
                ),
              },
              child: AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Color(0xFF0D47A1), width: 1),
                ),
                content: const Text(
                  'Atenção na data digitada',
                  style: TextStyle(color: Colors.black87),
                ),
                actions: [
                  TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0D47A1),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      minimumSize: const Size(64, 36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                        side: const BorderSide(color: Color(0xFF0D47A1), width: 1),
                      ),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } finally {
      _dateAlertShown = false;
    }
  }

  Future<void> _criarOrdem() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final dataEmissao = DateFormat('dd/MM/yyyy').parse(_dataCtrl.text);
      final agoraSaoPaulo = DateTime.now().toUtc().subtract(const Duration(hours: 3));
      final usuario = UsuarioAtual.instance;
      final quantidadeAmb = int.tryParse(_qtdAmbCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      final quantidadeVinte = int.tryParse(_qtd20Ctrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

      final ordem = await supabase.from('ordens').insert({
        'empresa_id': usuario!.empresaId,
        'filial_id': usuario.filialId,
        'usuario_id': usuario.id,
        'terminal_id': _terminalSelecionado,
        'data_ordem': agoraSaoPaulo.toIso8601String(),
        'tipo': _tipoOp.toLowerCase(),
        'terminal_id_orig': _tipoOperacao == 'Saída' ? _terminalSelecionado : null,
        'terminal_id_dest': _tipoOperacao == 'Entrada' ? _terminalSelecionado : null,
      }).select().single();

      await supabase.from('notas_fiscais').insert({
        'ordem_id': ordem['id'],
        'origem': _origemCtrl.text.isEmpty ? null : _origemCtrl.text,
        'nota_fiscal': _notaCtrl.text.replaceAll('.', ''),
        'data_emissao': dataEmissao.toIso8601String(),
        'quantidade_amb': _qtdAmbCtrl.text.replaceAll('.', ''),
        'quantidade_20': _qtd20Ctrl.text.replaceAll('.', ''),
        'produto_id': _produtoSelecionado,
        'valor_unit': _valorUnitCtrl.text.trim().isEmpty ? null : _valorUnitCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
        'valor_nf': _valorNfCtrl.text.trim().isEmpty ? null : _valorNfCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
      });

      await supabase.from('movimentacoes').insert({
        'filial_id': usuario.filialId,
        'descricao': '$_tipoOp - ${_origemCtrl.text}',
        'cliente': _origemCtrl.text,
        'qtd_faturada': quantidadeVinte,
        'entrada_amb': _tipoOperacao == 'Entrada' ? quantidadeAmb : null,
        'entrada_vinte': null,
        'saida_amb': _tipoOperacao == 'Saída' ? quantidadeAmb : null,
        'saida_vinte': null,
        'status_circuito_orig': 1,
        'filial_origem_id': _tipoOperacao == 'Saída' ? usuario.filialId : null,
        'filial_destino_id': _tipoOperacao == 'Entrada' ? usuario.filialId : null,
        'tipo_mov_orig': _tipoOperacao == 'Saída' ? 'saida' : null,
        'tipo_mov_dest': _tipoOperacao == 'Entrada' ? 'entrada' : null,
        'terminal_orig_id': _tipoOperacao == 'Saída' ? _terminalSelecionado : null,
        'terminal_dest_id': _tipoOperacao == 'Entrada' ? _terminalSelecionado : null,
        'ordem_id': ordem['id'],
        'nota_fiscal': _notaCtrl.text.replaceAll('.', ''),
        'produto_id': _produtoSelecionado,
        'empresa_id': usuario.empresaId,
        'usuario_id': usuario.id,
        'data_mov': dataEmissao.toUtc().toIso8601String(),
        'placa': _placaCtrl.text.isEmpty ? null : [_placaCtrl.text.toUpperCase()],
        'tipo_op': _tipoOp.toLowerCase(),
        'tipo_mov': _tipoOperacao.toLowerCase(),
        'data_carga': dataEmissao.toIso8601String(),
        'seta_carregada': _tipoOperacao == 'Entrada' ? quantidadeAmb : null,
      });

      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFF0D47A1), width: 1),
          ),
          content: const Text(
            'Ordem criada com sucesso',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black87),
          ),
          actions: [
            Center(
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ),
          ],
        ),
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          widget.onCreated?.call();
        } catch (_) {}
      });
    } catch (e) {
      if (mounted) {
        final errorStr = e?.toString() ?? '';
        String userMessage = 'Erro ao criar ordem: $e';
        if (errorStr.contains('empresa_id') || errorStr.contains('null value in column "empresa_id"') || errorStr.contains('23502')) {
          userMessage = 'Apenas usuários vinculados a uma empresa (não apenas ao terminal) podem criar ordens.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userMessage)),
        );
      }
    }
  }

  InputDecoration _decoracaoSlim(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontSize: 14, color: Colors.grey.shade700),
      isDense: true,
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade700),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 1.4),
      ),
    );
  }

  Widget _campo(
    String label,
    TextEditingController controller, {
    bool milhar = false,
    bool moeda = false,
    bool data = false,
    bool placa = false,
    bool maiusculo = false,
    bool letrasOnly = false,
    bool allowDecimalSeparators = false,
    FocusNode? focusNode,
    FocusNode? nextFocus,
    int? max,
    bool fullWidth = false,
  }) {
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: TextFormField(
        focusNode: focusNode,
        controller: controller,
        maxLength: max,
        style: const TextStyle(fontSize: 14),
        inputFormatters: letrasOnly
            ? [
                FilteringTextInputFormatter.allow(RegExp(r"[A-Za-zÀ-ÿ ]")),
              ]
            : placa
                ? [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                    LengthLimitingTextInputFormatter(7),
                  ]
                : allowDecimalSeparators
                    ? [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,]')),
                      ]
                    : [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')),
                      ],
        decoration: _decoracaoSlim(label),
        textInputAction: nextFocus != null ? TextInputAction.next : TextInputAction.done,
        onFieldSubmitted: (_) {
          if (nextFocus != null) FocusScope.of(context).requestFocus(nextFocus);
        },
        onChanged: (v) {
          String novo = v;

          if (maiusculo) novo = v.toUpperCase();
          if (milhar) novo = _formatMilhar(v);
          if (moeda) novo = _formatMoeda(v);
          if (data) novo = _formatData(v);
          if (placa) novo = _aplicarMascaraPlaca(v);

          controller.value = TextEditingValue(
            text: novo,
            selection: TextSelection.collapsed(offset: novo.length),
          );
          if (data && novo.length == 10) {
            _validarData(novo);
          }
        },
        validator: (v) {
          if (label != 'Origem' && label != 'Destino' && label != 'Preço' && label != 'Valor NF' && (v == null || v.isEmpty)) {
            return 'Obrigatório';
          }
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuario = UsuarioAtual.instance;
    return WillPopScope(
      onWillPop: () async {
        if (widget.onVoltar != null) {
          widget.onVoltar!();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Dados da ordem',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0D47A1),
                            ),
                          ),
                          const SizedBox(height: 30),
                          Wrap(
                            spacing: 20,
                            runSpacing: 14,
                            children: [
                              // Linha 1: Terminal e Origem/Destino
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      focusNode: _terminalFocus,
                                      value: _terminalSelecionado,
                                      decoration: _decoracaoSlim('Terminal'),
                                      style: const TextStyle(fontSize: 14, color: Colors.black87),
                                      dropdownColor: Colors.white,
                                      items: _terminais
                                          .map<DropdownMenuItem<String>>(
                                            (t) => DropdownMenuItem<String>(
                                              value: t['id']?.toString(),
                                              child: Text(
                                                t['nome'] ?? '',
                                                style: const TextStyle(fontSize: 14),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: usuario?.nivel == 3
                                          ? (v) => setState(() => _terminalSelecionado = v)
                                          : null,
                                      validator: (v) {
                                        if (usuario?.nivel == 3 && v == null) return 'Obrigatório';
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: _campo(
                                      _tipoOperacao == 'Entrada' ? 'Origem' : 'Destino',
                                      _origemCtrl,
                                      maiusculo: true,
                                      max: 50,
                                      letrasOnly: true,
                                      focusNode: _origemFocus,
                                      nextFocus: _notaFocus,
                                    ),
                                  ),
                                ],
                              ),

                              // Linha 2: Tipo de Op., Placa e Nota Fiscal
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: DropdownButtonFormField<String>(
                                      value: _tipoOp,
                                      decoration: _decoracaoSlim('Tipo Op.'),
                                      style: const TextStyle(fontSize: 14, color: Colors.black87),
                                      items: const [
                                        DropdownMenuItem(value: 'Compra', child: Text('Compra')),
                                        DropdownMenuItem(value: 'Empréstimo', child: Text('Empréstimo')),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          _tipoOp = value!;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    flex: 2,
                                    child: _campo(
                                      'Placa',
                                      _placaCtrl,
                                      placa: true,
                                      focusNode: _placaFocus,
                                      nextFocus: _notaFocus,
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    flex: 1,
                                    child: Shortcuts(
                                      shortcuts: <LogicalKeySet, Intent>{
                                        LogicalKeySet(LogicalKeyboardKey.tab): const _FocusDataIntent(),
                                      },
                                      child: Actions(
                                        actions: <Type, Action<Intent>>{
                                          _FocusDataIntent: CallbackAction<_FocusDataIntent>(
                                            onInvoke: (Intent intent) {
                                              _dataFocus.requestFocus();
                                              return null;
                                            },
                                          ),
                                        },
                                        child: _campo(
                                          'Nota fiscal',
                                          _notaCtrl,
                                          milhar: true,
                                          max: 8,
                                          focusNode: _notaFocus,
                                          nextFocus: _dataFocus,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              Row(
                                children: [
                                  Expanded(
                                    child: _campo(
                                      'Data de emissão',
                                      _dataCtrl,
                                      data: true,
                                      focusNode: _dataFocus,
                                      nextFocus: _qtdAmbFocus,
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: Shortcuts(
                                      shortcuts: <LogicalKeySet, Intent>{
                                        LogicalKeySet(LogicalKeyboardKey.tab): const _FocusQtd20Intent(),
                                      },
                                      child: Actions(
                                        actions: <Type, Action<Intent>>{
                                          _FocusQtd20Intent: CallbackAction<_FocusQtd20Intent>(
                                            onInvoke: (Intent intent) {
                                              _qtd20Focus.requestFocus();
                                              return null;
                                            },
                                          ),
                                        },
                                        child: _campo(
                                          'Quantidade (ambiente)',
                                          _qtdAmbCtrl,
                                          milhar: true,
                                          max: 5,
                                          focusNode: _qtdAmbFocus,
                                          nextFocus: _qtd20Focus,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: _campo(
                                      'Quantidade faturada (20ºC)',
                                      _qtd20Ctrl,
                                      milhar: true,
                                      max: 5,
                                      focusNode: _qtd20Focus,
                                      nextFocus: _produtoFocus,
                                    ),
                                  ),
                                ],
                              ),

                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Shortcuts(
                                      shortcuts: <LogicalKeySet, Intent>{
                                        LogicalKeySet(LogicalKeyboardKey.tab): const _FocusPrecoIntent(),
                                      },
                                      child: Actions(
                                        actions: <Type, Action<Intent>>{
                                          _FocusPrecoIntent: CallbackAction<_FocusPrecoIntent>(
                                            onInvoke: (Intent intent) {
                                              _valorUnitFocus.requestFocus();
                                              return null;
                                            },
                                          ),
                                        },
                                        child: DropdownButtonFormField<String>(
                                          focusNode: _produtoFocus,
                                          decoration: _decoracaoSlim('Produto'),
                                          style: const TextStyle(fontSize: 14, color: Colors.black87),
                                          items: _produtos
                                              .map<DropdownMenuItem<String>>(
                                                (p) => DropdownMenuItem<String>(
                                                  value: p['id']?.toString(),
                                                  child: Text(
                                                    p['nome'] ?? '',
                                                    style: const TextStyle(fontSize: 14),
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                          onChanged: (v) => _produtoSelecionado = v,
                                          validator: (v) => v == null ? 'Obrigatório' : null,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    flex: 1,
                                    child: _campo(
                                      'Preço',
                                      _valorUnitCtrl,
                                      allowDecimalSeparators: true,
                                      max: 6,
                                      focusNode: _valorUnitFocus,
                                      nextFocus: _valorNfFocus,
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    flex: 1,
                                    child: _campo(
                                      'Valor NF',
                                      _valorNfCtrl,
                                      moeda: true,
                                      max: 10,
                                      focusNode: _valorNfFocus,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                Container(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Colors.grey.shade300)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        height: 36,
                        child: OutlinedButton(
                          onPressed: () {
                            if (widget.onVoltar != null) {
                              widget.onVoltar!();
                            } else {
                              Navigator.pop(context);
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            textStyle: const TextStyle(fontSize: 13),
                          ),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 36,
                        child: ElevatedButton(
                          onPressed: _criarOrdem,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            textStyle: const TextStyle(fontSize: 13),
                            backgroundColor: const Color(0xFF0D47A1),
                          ),
                          child: const Text('Criar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}