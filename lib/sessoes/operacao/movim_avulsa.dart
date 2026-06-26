import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_page.dart';

class MovimentacaoAvulsaDialog extends StatefulWidget {
  final String tanqueId;
  final String? terminalId;
  final VoidCallback onSalvar;

  const MovimentacaoAvulsaDialog({
    super.key,
    required this.tanqueId,
    this.terminalId,
    required this.onSalvar,
  });

  @override
  State<MovimentacaoAvulsaDialog> createState() => _MovimentacaoAvulsaDialogState();
}

class _MovimentacaoAvulsaDialogState extends State<MovimentacaoAvulsaDialog> {
  static const Color _ink = Color(0xFF0E1C2F);

  final TextEditingController _dataController = TextEditingController();
  final TextEditingController _descricaoController = TextEditingController();
  final TextEditingController _quantidadeController = TextEditingController();

  // Empresas vinculadas ao terminal do usuário
  List<Map<String, dynamic>> _empresasDisponiveis = [];
  bool _carregandoEmpresas = false;
  bool _empresaVinculada = false;
  String? _empresaSelecionadaId;
  String? _empresaSelecionadaNome;

  DateTime _dataSelecionada = DateTime.now();
  String _tipoMovimento = 'Entrada';
  bool _carregando = false;

  // Produto e Tanque para exibição "[produto] - [tanque]"
  String? _produtoNome;
  String? _tanqueReferencia;
  bool _carregandoProdutoTanque = false;
  String? _produtoId;

  @override
  void initState() {
    super.initState();
    _atualizarDataController();
    // Atualiza estado do botão Salvar quando campos mudam
    _descricaoController.addListener(_atualizarEstadoSalvar);
    _quantidadeController.addListener(_atualizarEstadoSalvar);
    // Inicializa seleção de empresa com base no usuário logado
    final usuario = UsuarioAtual.instance;
    if (usuario?.empresaId != null && usuario!.empresaId!.isNotEmpty) {
      _empresaVinculada = true;
      _empresaSelecionadaId = usuario.empresaId;
      _empresaSelecionadaNome = usuario.empresaNome ?? 'Empresa vinculada';
      _empresasDisponiveis = [
        {'id': _empresaSelecionadaId!, 'nome': _empresaSelecionadaNome!},
      ];
    }

    // Se usuário tem terminal vinculado, carrega empresas relacionadas
    if (usuario?.terminalId != null && usuario!.terminalId!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _carregarEmpresasPorTerminal(usuario.terminalId!);
        _carregarProdutoETanque();
      });
    }
  }

  void _atualizarEstadoSalvar() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _descricaoController.removeListener(_atualizarEstadoSalvar);
    _quantidadeController.removeListener(_atualizarEstadoSalvar);
    _dataController.dispose();
    _descricaoController.dispose();
    _quantidadeController.dispose();
    super.dispose();
  }

  Future<void> _carregarProdutoETanque() async {
    setState(() => _carregandoProdutoTanque = true);
    try {
      final supabase = Supabase.instance.client;

      final tanqueResp = await supabase
          .from('tanques')
          .select('id, referencia, produto_id')
          .eq('id', widget.tanqueId)
          .maybeSingle();

      if (tanqueResp != null) {
        _tanqueReferencia = tanqueResp['referencia']?.toString();
        final produtoId = tanqueResp['produto_id']?.toString();
        _produtoId = produtoId;
        if (produtoId != null && produtoId.isNotEmpty) {
          final produtoResp = await supabase
              .from('produtos')
              .select('id, nome')
              .eq('id', produtoId)
              .maybeSingle();
          if (produtoResp != null) {
            _produtoNome = produtoResp['nome']?.toString();
          }
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar produto/tanque: $e');
    } finally {
      if (mounted) setState(() => _carregandoProdutoTanque = false);
    }
  }

  Future<void> _carregarEmpresasPorTerminal(String terminalId) async {
    setState(() => _carregandoEmpresas = true);

    try {
      final supabase = Supabase.instance.client;

      // Buscar empresas vinculadas ao terminal através de relacoes_terminais
      final response = await supabase
          .from('relacoes_terminais')
          .select('''
            empresa_id,
            empresas!inner (
              id,
              nome_dois
            )
          ''')
          .eq('terminal_id', terminalId);

      List<Map<String, dynamic>> empresas = [];
      empresas.add({'id': '', 'nome': '<selecione>'});

      final Map<String, String> empresasUnicas = {};

      for (var item in response) {
        final empData = item['empresas'] as Map<String, dynamic>?;
        if (empData != null) {
          final id = empData['id']?.toString();
          final nome = empData['nome_dois']?.toString() ?? 'Empresa sem nome';
          if (id != null && !empresasUnicas.containsKey(id)) {
            empresasUnicas[id] = nome;
            empresas.add({'id': id, 'nome': nome});
          }
        }
      }

      setState(() {
        _empresasDisponiveis = empresas;

        // Se só tiver uma empresa além de "selecione", pré-selecionar automaticamente
        if (empresas.length == 2 && (_empresaSelecionadaId == null || _empresaSelecionadaId == '')) {
          _empresaSelecionadaId = empresas[1]['id'];
          _empresaSelecionadaNome = empresas[1]['nome'];
        }
      });
    } catch (e) {
      debugPrint('Erro ao carregar empresas por terminal: $e');
      setState(() {
        _empresasDisponiveis = [
          {'id': '', 'nome': '<erro ao carregar empresas>'},
        ];
        _empresaSelecionadaId = '';
      });
    } finally {
      setState(() => _carregandoEmpresas = false);
    }
  }

  void _atualizarDataController() {
    _dataController.text = DateFormat('dd/MM/yyyy').format(_dataSelecionada);
  }

  String _formatarMilhar(String valor) {
    final digitsOnly = valor.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isEmpty) return '';

    final buffer = StringBuffer();
    for (int i = 0; i < digitsOnly.length; i++) {
      final reverseIndex = digitsOnly.length - i;
      buffer.write(digitsOnly[i]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write('.');
      }
    }
    return buffer.toString();
  }

  Future<void> _selecionarData() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        final borderColor = _tipoMovimento == 'Entrada' ? Colors.blue : Colors.red;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: borderColor,
              onPrimary: Colors.white,
              onSurface: _ink,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dataSelecionada = picked;
        _atualizarDataController();
      });
    }
  }

  Future<void> _salvar() async {
    final descricao = _descricaoController.text.trim();
    final quantidade = _quantidadeController.text.trim();

    if (descricao.isEmpty || quantidade.isEmpty) {
      return;
    }

    setState(() => _carregando = true);

    try {
      final supabase = Supabase.instance.client;
      final valorNumerico = double.tryParse(
        quantidade.replaceAll('.', '').replaceAll(',', '.')
      ) ?? 0;

      await supabase.from('movimentacoes_tanque').insert({
        'tanque_id': widget.tanqueId,
        'produto_id': _produtoId,
        'empresa_id': _empresaSelecionadaId,
        'data_mov': _dataSelecionada.toIso8601String(),
        'descricao': descricao,
        'tipo_mov': _tipoMovimento,
        'entrada_vinte': _tipoMovimento == 'Entrada' ? valorNumerico : 0,
        'saida_vinte': _tipoMovimento == 'Saída' ? valorNumerico : 0,
        'terminal_id': widget.terminalId,
      });

      if (!mounted) return;
      
      // Fecha o dialog e chama o callback
      Navigator.of(context).pop();
      widget.onSalvar();

      // Mostra mensagem de sucesso
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Movimentação lançada com sucesso!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar movimentação: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _tipoMovimento == 'Entrada' ? Colors.blue : Colors.red;
    final backgroundColor = _tipoMovimento == 'Entrada'
        ? const Color(0xFFE3F2FD)
        : const Color(0xFFFCE4EC);

    return Dialog(
      backgroundColor: backgroundColor,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 0.8),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Lançar Movimentação Avulsa',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 12),

              // Linha exibindo [produto] - [tanque]
              _carregandoProdutoTanque
                  ? const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: SizedBox(
                        height: 16,
                        child: Center(
                          child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        '${_produtoNome ?? '-'} - ${_tanqueReferencia ?? '-'}',
                        style: const TextStyle(fontSize: 15, color: Colors.red),
                      ),
                    ),

              // Dropdown de Empresas vinculadas ao terminal do usuário
              const Text(
                'Empresa',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _ink),
              ),
              const SizedBox(height: 6),
              if (_carregandoEmpresas)
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade400, width: 1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade400, width: 1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _empresaSelecionadaId,
                      isExpanded: true,
                      itemHeight: 48,
                      isDense: true,
                      icon: _empresaVinculada ? const SizedBox.shrink() : const Icon(Icons.arrow_drop_down, size: 18),
                      style: const TextStyle(fontSize: 13, color: Colors.black),
                      onChanged: _empresaVinculada
                          ? null
                          : (String? novoValor) {
                              setState(() {
                                _empresaSelecionadaId = novoValor;
                                final selected = _empresasDisponiveis.firstWhere(
                                    (e) => e['id'] == novoValor,
                                    orElse: () => {'id': '', 'nome': ''});
                                _empresaSelecionadaNome = selected['nome'];
                              });
                            },
                      // itens compactos
                      items: _empresasDisponiveis.map<DropdownMenuItem<String>>((empresa) {
                        return DropdownMenuItem<String>(
                          value: empresa['id'],
                          child: Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              empresa['nome'] ?? '',
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                  const SizedBox(height: 12),

              // Seletor de Tipo (Entrada/Saída)
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _tipoMovimento = 'Entrada'),
                      child: Row(
                        children: [
                          Radio<String>(
                            value: 'Entrada',
                            groupValue: _tipoMovimento,
                            activeColor: Colors.blue,
                            onChanged: (value) => setState(() => _tipoMovimento = value!),
                            visualDensity: VisualDensity.compact,
                          ),
                          const Text('Entrada', style: TextStyle(fontSize: 13, color: _ink)),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _tipoMovimento = 'Saída'),
                      child: Row(
                        children: [
                          Radio<String>(
                            value: 'Saída',
                            groupValue: _tipoMovimento,
                            activeColor: Colors.red,
                            onChanged: (value) => setState(() => _tipoMovimento = value!),
                            visualDensity: VisualDensity.compact,
                          ),
                          const Text('Saída', style: TextStyle(fontSize: 13, color: _ink)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Data
              const Text(
                'Data de lançamento',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _ink),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: _selecionarData,
                child: IgnorePointer(
                  child: TextField(
                    controller: _dataController,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'dd/mm/aaaa',
                      prefixIcon: Icon(Icons.calendar_today, size: 16, color: borderColor),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: borderColor.withValues(alpha: 0.5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Quantidade
              const Text(
                'Quantidade (Litros)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _ink),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _quantidadeController,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 13),
                maxLength: 7,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (value) {
                  if (value.isNotEmpty) {
                    final formatted = _formatarMilhar(value);
                    _quantidadeController.value = TextEditingValue(
                      text: formatted,
                      selection: TextSelection.collapsed(offset: formatted.length),
                    );
                  }
                },
                decoration: InputDecoration(
                  hintText: '0',
                  counterText: '',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: borderColor.withValues(alpha: 0.5)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),

              // Descrição
              const Text(
                'Descrição',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _ink),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _descricaoController,
                style: const TextStyle(fontSize: 13),
                maxLines: 4,
                minLines: 4,
                maxLength: 200,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  hintText: 'Digite...',
                  counterText: '',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: borderColor.withValues(alpha: 0.5)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 24),

              // Botões
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _carregando ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: borderColor, width: 0.8),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('Voltar', style: TextStyle(color: borderColor, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                        onPressed: (_carregando ||
                            _quantidadeController.text.trim().isEmpty ||
                            _empresaSelecionadaId == null ||
                            _empresaSelecionadaId!.isEmpty)
                          ? null
                          : _salvar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: borderColor,
                        disabledBackgroundColor: Colors.grey.shade400,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _carregando
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Salvar', style: TextStyle(color: Colors.white, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}