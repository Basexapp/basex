import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_page.dart';

class AutocompleteField<T extends Object> extends StatefulWidget {
  final TextEditingController controller;
  final Future<List<T>> Function(String) buscarItens;
  final String Function(T) obterTextoExibicao;
  final void Function(T)? onSelecionado;
  final bool Function(String)? validarParaBusca;

  const AutocompleteField({
    super.key,
    required this.controller,
    required this.buscarItens,
    required this.obterTextoExibicao,
    this.onSelecionado,
    this.validarParaBusca,
  });

  @override
  State<AutocompleteField<T>> createState() => _AutocompleteFieldState<T>();
}

class _AutocompleteFieldState<T extends Object> extends State<AutocompleteField<T>> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<T>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (TextEditingValue value) async {
        if (widget.validarParaBusca != null &&
            !widget.validarParaBusca!(value.text)) {
          return Iterable<T>.empty();
        }
        final resultados = await widget.buscarItens(value.text);
        return resultados;
      },
      displayStringForOption: widget.obterTextoExibicao,
      onSelected: (T item) {
        widget.controller.text = widget.obterTextoExibicao(item);
        widget.controller.selection = TextSelection.collapsed(
          offset: widget.controller.text.length,
        );

        if (widget.onSelecionado != null) {
          widget.onSelecionado!(item);
        }
      },
      fieldViewBuilder: (context, controller, focusNode, _) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Digite para buscar...',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(4),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.3,
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final item = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(item),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        widget.obterTextoExibicao(item),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class NovaTransferenciaDialog extends StatefulWidget {
  const NovaTransferenciaDialog({super.key});

  @override
  State<NovaTransferenciaDialog> createState() => _NovaTransferenciaDialogState();
}

class _NovaTransferenciaDialogState extends State<NovaTransferenciaDialog> {
  DateTime _dataSelecionada = DateTime.now();
  bool _salvando = false;
  bool _preenchimentoAutomaticoAtivo = false;
  
  final TextEditingController _motoristaController = TextEditingController();
  final TextEditingController _quantidadeController = TextEditingController();
  final TextEditingController _transportadoraController = TextEditingController();
  final TextEditingController _cavaloController = TextEditingController();
  final TextEditingController _reboque1Controller = TextEditingController();
  final TextEditingController _reboque2Controller = TextEditingController();
  
  String? _motoristaId;
  String? _produtoId;
  String? _transportadoraId;
  String? _origemId;
  String? _destinoId;
  String? _empresaId;
  String? _usuarioId;
  
  List<Map<String, dynamic>> _produtos = [];
  List<Map<String, dynamic>> _terminais = [];
  List<String> _datasFormatadas = [];
  List<DateTime> _datasDisponiveis = [];
  
  String? _produtoSelecionado;
  String? _origemSelecionada;
  String? _destinoSelecionado;
  
  bool _mostrarSugestoesCavalo = false;
  bool _carregandoPlacasCavalo = false;
  List<Map<String, dynamic>> _placasCavaloEncontradas = [];
  
  bool _mostrarSugestoesReboque1 = false;
  bool _carregandoPlacasReboque1 = false;
  List<Map<String, dynamic>> _placasReboque1Encontradas = [];
  
  bool _mostrarSugestoesReboque2 = false;
  bool _carregandoPlacasReboque2 = false;
  List<Map<String, dynamic>> _placasReboque2Encontradas = [];
  
  final FocusNode _cavaloFocusNode = FocusNode();
  final FocusNode _reboque1FocusNode = FocusNode();
  final FocusNode _reboque2FocusNode = FocusNode();
  
  @override
  void initState() {
    super.initState();
    _carregarDadosUsuario();
    _carregarProdutos();
    _gerarDatasDisponiveis();
    
    _cavaloFocusNode.addListener(() {
      if (!_cavaloFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            setState(() => _mostrarSugestoesCavalo = false);
          }
        });
      }
    });
    
    _reboque1FocusNode.addListener(() {
      if (!_reboque1FocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            setState(() => _mostrarSugestoesReboque1 = false);
          }
        });
      }
    });
    
    _reboque2FocusNode.addListener(() {
      if (!_reboque2FocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            setState(() => _mostrarSugestoesReboque2 = false);
          }
        });
      }
    });
  }
  
  @override
  void dispose() {
    _cavaloFocusNode.dispose();
    _reboque1FocusNode.dispose();
    _reboque2FocusNode.dispose();
    _motoristaController.dispose();
    _quantidadeController.dispose();
    _transportadoraController.dispose();
    _cavaloController.dispose();
    _reboque1Controller.dispose();
    _reboque2Controller.dispose();
    super.dispose();
  }

  void _gerarDatasDisponiveis() {
    final hoje = DateTime.now();
    final inicio = hoje.subtract(const Duration(days: 10));
    _datasDisponiveis = List.generate(20, (i) => inicio.add(Duration(days: i)));
    _datasFormatadas = _datasDisponiveis.map(_formatarData).toList();
  }

  String _aplicarMascaraPlaca(String texto) {
    final limpo = texto
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');

    if (limpo.length <= 3) return limpo;

    final letras = limpo.substring(0, 3);
    final numeros = limpo.substring(3, limpo.length.clamp(3, 7));

    return '$letras-$numeros';
  }

  void _onEdicaoManualPlaca(String texto, TextEditingController controller) {
    if (_preenchimentoAutomaticoAtivo) {
      _preenchimentoAutomaticoAtivo = false;
      _limparMotoristaEPlacas();
    }

    controller.value = TextEditingValue(
      text: _aplicarMascaraPlaca(texto),
      selection: TextSelection.collapsed(
        offset: _aplicarMascaraPlaca(texto).length,
      ),
    );
  }

  void _limparMotoristaEPlacas() {
    setState(() {
      _motoristaController.clear();
      _motoristaId = null;
      _cavaloController.clear();
      _reboque1Controller.clear();
      _reboque2Controller.clear();
      _transportadoraController.clear();
      _transportadoraId = null;
      _quantidadeController.clear();
    });
  }

  void _aplicarConjuntoNosCampos(Map<String, dynamic> conjunto) {
    setState(() {
      _preenchimentoAutomaticoAtivo = true;
      _cavaloController.text = _aplicarMascaraPlaca(conjunto['cavalo'] ?? '');
      _reboque1Controller.text = _aplicarMascaraPlaca(conjunto['reboque_um'] ?? '');
      _reboque2Controller.text = _aplicarMascaraPlaca(conjunto['reboque_dois'] ?? '');
      
      if (conjunto['capac'] != null) {
        final capacidadeM3 = double.tryParse(conjunto['capac'].toString()) ?? 0;
        final capacidadeLitros = (capacidadeM3 * 1000).toInt();
        _quantidadeController.text = _aplicarMascaraQuantidade(capacidadeLitros.toString());
      }
      
      _transportadoraController.text = 'Petroserra';
      _buscarIdTransportadoraPetroserra();
    });
  }

  Future<void> _buscarIdTransportadoraPetroserra() async {
    try {
      final supabase = Supabase.instance.client;
      
      final response = await supabase
          .from('transportadoras')
          .select('id')
          .eq('nome_dois', 'Petroserra')
          .limit(1)
          .maybeSingle();
      
      if (response != null) {
        _transportadoraId = response['id']?.toString();
      }
    } catch (e) {
      debugPrint('Erro ao buscar ID da Petroserra: $e');
    }
  }

  Future<Map<String, dynamic>?> _buscarConjuntoPorMotorista(String motoristaId) async {
    try {
      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('conjuntos')
          .select('cavalo, reboque_um, reboque_dois, capac')
          .eq('motorista_id', motoristaId)
          .limit(1)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('Erro ao buscar conjunto por motorista: $e');
      return null;
    }
  }

  Future<void> _carregarDadosUsuario() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      
      if (user != null) {
        _usuarioId = user.id;
        
        final usuarioData = await supabase
            .from('usuarios')
            .select('empresa_id')
            .eq('id', user.id)
            .maybeSingle();
            
        if (usuarioData != null) {
          _empresaId = usuarioData['empresa_id']?.toString();
          _carregarTerminais();
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar dados do usuário: $e');
    }
  }
  
  Widget _buildCampoAutocomplete<T extends Object>({
    required TextEditingController controller,
    required String label,
    required Future<List<T>> Function(String) buscarItens,
    required String Function(T) obterTextoExibicao,
    required void Function(T)? onSelecionado,
    double? width,
  }) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0D47A1),
            ),
          ),
          const SizedBox(height: 4),
          
          AutocompleteField<T>(
            controller: controller,
            buscarItens: buscarItens,
            obterTextoExibicao: obterTextoExibicao,
            validarParaBusca: (texto) => texto.length >= 3,
            onSelecionado: onSelecionado,
          ),
        ],
      ),
    );
  }

  Future<void> _carregarProdutos() async {
    try {
      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('produtos')
          .select('id, nome, nome_dois, posicao, grupo')
          .eq('lista_transf', true);

      final listaProdutos = List<Map<String, dynamic>>.from(response);

      // Ordenação manual por posicao (double)
      listaProdutos.sort((a, b) {
        final valA = a['posicao'];
        final valB = b['posicao'];

        double posA;
        if (valA is num) {
          posA = valA.toDouble();
        } else {
          posA = double.tryParse(valA?.toString() ?? '') ?? 999999.0;
        }

        double posB;
        if (valB is num) {
          posB = valB.toDouble();
        } else {
          posB = double.tryParse(valB?.toString() ?? '') ?? 999999.0;
        }

        return posA.compareTo(posB);
      });

      setState(() {
        _produtos = listaProdutos;
      });
    } catch (e) {
      debugPrint('Erro ao carregar produtos: $e');
      setState(() {
        _produtos = [];
      });
    }
  }

  Future<void> _carregarTerminais() async {
    if (_empresaId == null) return;
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('relacoes_terminais')
          .select('terminal_id, terminais!inner(id, nome_dois)')
          .eq('empresa_id', _empresaId!);

      final lista = List<Map<String, dynamic>>.from(response);
      final Map<String, Map<String, dynamic>> uniqueMap = {};

      for (final item in lista) {
        final terminalId = item['terminal_id']?.toString();
        final terminalData = item['terminais'] as Map<String, dynamic>?;
        if (terminalId != null && terminalData != null && !uniqueMap.containsKey(terminalId)) {
          uniqueMap[terminalId] = {
            'id': terminalId,
            'nome': terminalData['nome_dois']?.toString() ?? '',
          };
        }
      }

      final terminais = uniqueMap.values.toList()
        ..sort((a, b) => (a['nome'] as String).compareTo(b['nome'] as String));

      terminais.insert(0, {'id': 'CONSUMO', 'nome': 'Consumo próprio'});

      setState(() {
        _terminais = terminais;
      });
    } catch (e) {
      debugPrint('Erro ao carregar terminais: $e');
    }
  }

  Future<String?> _buscarFilialPorTerminal(String terminalId) async {
    try {
      final supabase = Supabase.instance.client;
      
      final response = await supabase
          .from('relacoes_terminais')
          .select('filial_id_1')
          .eq('terminal_id', terminalId)
          .eq('empresa_id', _empresaId!)
          .limit(1)
          .maybeSingle();
      
      if (response != null && response['filial_id_1'] != null) {
        return response['filial_id_1'].toString();
      }
      
      return null;
    } catch (e) {
      debugPrint('Erro ao buscar filial para terminal $terminalId: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _buscarMotoristas(String texto) async {
    if (texto.length < 3) return [];
    
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('conjuntos')
          .select('motorista, motorista_id')
          .not('reboque_um', 'is', null)
          .ilike('motorista', '%$texto%')
          .order('motorista')
          .limit(10);
      
      final lista = List<Map<String, dynamic>>.from(response);
      final Map<String, Map<String, dynamic>> uniqueMap = {};
      
      for (final item in lista) {
        final motoristaId = item['motorista_id']?.toString();
        if (motoristaId != null && !uniqueMap.containsKey(motoristaId)) {
          uniqueMap[motoristaId] = item;
        }
      }
      
      return uniqueMap.values.toList();
    } catch (e) {
      debugPrint('Erro ao buscar motoristas: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _buscarTransportadoras(String texto) async {
    if (texto.length < 3) return [];
    
    final supabase = Supabase.instance.client;
    final response = await supabase
        .from('transportadoras')
        .select('id, nome_dois')
        .ilike('nome_dois', '%$texto%')
        .order('nome_dois')
        .limit(10);
    
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> _buscarPlacas(String texto) async {
    if (texto.length < 3) return [];
    
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('view_placas_tanques')
          .select('placas, tanques')
          .ilike('placas', '${texto.replaceAll('-', '').toUpperCase()}%')
          .order('placas')
          .limit(10);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Erro ao buscar placas: $e');
      return [];
    }
  }

  Future<void> _buscarPlacasCavalo(String texto) async {
    if (texto.length < 3) {
      setState(() {
        _placasCavaloEncontradas.clear();
        _mostrarSugestoesCavalo = false;
      });
      return;
    }

    setState(() {
      _carregandoPlacasCavalo = true;
    });

    try {
      final placas = await _buscarPlacas(texto);
      setState(() {
        _placasCavaloEncontradas = placas;
        _carregandoPlacasCavalo = false;
        _mostrarSugestoesCavalo = placas.isNotEmpty;
      });
    } catch (e) {
      debugPrint('Erro ao buscar placas cavalo: $e');
      setState(() {
        _placasCavaloEncontradas.clear();
        _carregandoPlacasCavalo = false;
        _mostrarSugestoesCavalo = false;
      });
    }
  }

  Future<void> _buscarPlacasReboque1(String texto) async {
    if (texto.length < 3) {
      setState(() {
        _placasReboque1Encontradas.clear();
        _mostrarSugestoesReboque1 = false;
      });
      return;
    }

    setState(() {
      _carregandoPlacasReboque1 = true;
    });

    try {
      final placas = await _buscarPlacas(texto);
      setState(() {
        _placasReboque1Encontradas = placas;
        _carregandoPlacasReboque1 = false;
        _mostrarSugestoesReboque1 = placas.isNotEmpty;
      });
    } catch (e) {
      debugPrint('Erro ao buscar placas reboque1: $e');
      setState(() {
        _placasReboque1Encontradas.clear();
        _carregandoPlacasReboque1 = false;
        _mostrarSugestoesReboque1 = false;
      });
    }
  }

  Future<void> _buscarPlacasReboque2(String texto) async {
    if (texto.length < 3) {
      setState(() {
        _placasReboque2Encontradas.clear();
        _mostrarSugestoesReboque2 = false;
      });
      return;
    }

    setState(() {
      _carregandoPlacasReboque2 = true;
    });

    try {
      final placas = await _buscarPlacas(texto);
      setState(() {
        _placasReboque2Encontradas = placas;
        _carregandoPlacasReboque2 = false;
        _mostrarSugestoesReboque2 = placas.isNotEmpty;
      });
    } catch (e) {
      debugPrint('Erro ao buscar placas reboque2: $e');
      setState(() {
        _placasReboque2Encontradas.clear();
        _carregandoPlacasReboque2 = false;
        _mostrarSugestoesReboque2 = false;
      });
    }
  }

  void _selecionarPlacaCavalo(Map<String, dynamic> item) {
    setState(() {
      _cavaloController.text = _aplicarMascaraPlaca(item['placas']);
      _mostrarSugestoesCavalo = false;
    });
  }

  void _selecionarPlacaReboque1(Map<String, dynamic> item) {
    setState(() {
      _reboque1Controller.text = _aplicarMascaraPlaca(item['placas']);
      _mostrarSugestoesReboque1 = false;
    });
  }

  void _selecionarPlacaReboque2(Map<String, dynamic> item) {
    setState(() {
      _reboque2Controller.text = _aplicarMascaraPlaca(item['placas']);
      _mostrarSugestoesReboque2 = false;
    });
  }

  String _aplicarMascaraQuantidade(String texto) {
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

  Future<void> _salvar() async {
    if (_produtoId == null ||
        _origemId == null ||
        _destinoId == null ||
        _quantidadeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha os campos obrigatórios'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final bool isConsumo = _destinoId == 'CONSUMO';

    if (!isConsumo && _origemId == _destinoId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Origem e destino não podem ser iguais'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_empresaId == null || _usuarioId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Usuário ou empresa não identificados'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _salvando = true);

    final terminalUsuarioId = UsuarioAtual.instance?.terminalId;
    if (terminalUsuarioId == null || terminalUsuarioId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O seu usuário não possui um terminal vinculado. Contate o suporte.'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _salvando = false);
      return;
    }

    try {
      final supabase = Supabase.instance.client;

      final terminalOrigId = _origemId;
      final terminalDestId = isConsumo ? null : _destinoId;

      // Buscar filiais para origem e destino
      final filialOrigemId = await _buscarFilialPorTerminal(terminalOrigId!);
      final filialDestinoId =
          isConsumo ? null : await _buscarFilialPorTerminal(terminalDestId!);

      // VALIDAÇÃO: Verificar apenas se o terminal de destino possui tanques com o produto selecionado
      if (!isConsumo && _produtoId != null) {
        final tanquesDestino = await supabase
            .from('tanques')
            .select('id')
            .eq('terminal_id', terminalDestId!)
            .eq('id_produto', _produtoId!)
            .limit(1);
        
        if (tanquesDestino.isEmpty) {
          // Terminal de destino não tem tanque para este produto
          final destinoNome = _terminais
              .firstWhere(
                (t) => t['id']?.toString() == _destinoId,
                orElse: () => {'nome': 'Destino'},
              )['nome']
              ?.toString() ?? 'Destino';
          
          final produtoNome = _produtos
              .firstWhere(
                (p) => p['id']?.toString() == _produtoId,
                orElse: () => {'nome': 'produto'},
              )['nome']
              ?.toString() ?? 'produto';
          
          if (mounted) {
            setState(() => _salvando = false);
            
            final confirmar = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                title: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 24),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Atenção',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D47A1),
                        ),
                      ),
                    ),
                  ],
                ),
                content: Padding(
                  padding: const EdgeInsets.only(left: 36),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'O terminal de destino ($destinoNome) não possui tanque em operação para o produto "$produtoNome".',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Tem certeza que deseja prosseguir com a transferência?',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text(
                      'Voltar',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color.fromARGB(255, 95, 95, 95),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: const Text(
                      'Sim, prosseguir',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            );
            
            if (confirmar != true) {
              return; // Usuário escolheu voltar
            }
            
            setState(() => _salvando = true);
          }
        }
      }

      // Obter data/hora atual no fuso de São Paulo
      final agora = DateTime.now();
      final dataHoraSP = agora.toIso8601String(); // Formato: YYYY-MM-DDTHH:MM:SS.mmm

      final ordemResponse = await supabase
          .from('ordens')
          .insert({
            'empresa_id': _empresaId,
            'filial_id': null,
            'usuario_id': _usuarioId,
            'tipo': 'transferencia',
            'data_ordem': dataHoraSP,
            'terminal_id_orig': terminalOrigId,
            'terminal_id_dest': terminalDestId,
          })
          .select('id')
          .single();

      final ordemId = ordemResponse['id'];

      final quantidade = int.parse(_quantidadeController.text.replaceAll('.', ''));

      final origemNome = _terminais
        .firstWhere(
          (t) => t['id']?.toString() == _origemId,
          orElse: () => {'nome': ''},
        )['nome']
        ?.toString() ??
        '';

      final destinoNome = _terminais
        .firstWhere(
          (t) => t['id']?.toString() == _destinoId,
          orElse: () => {'nome': ''},
        )['nome']
        ?.toString() ??
        '';

      final placas = <String>[];
      if (_cavaloController.text.isNotEmpty) placas.add(_cavaloController.text);
      if (_reboque1Controller.text.isNotEmpty) placas.add(_reboque1Controller.text);
      if (_reboque2Controller.text.isNotEmpty) placas.add(_reboque2Controller.text);

      final transferencia = {
        'ordem_id': ordemId,
        'tipo_op': isConsumo ? 'consumo' : 'transf',
        'produto_id': _produtoId,
        'qtd_faturada': quantidade,
        'saida_amb': quantidade,
        'entrada_amb': isConsumo ? 0 : quantidade,
        'descricao': isConsumo ? 'Consumo próprio' : '$origemNome → $destinoNome',
        'placa': placas.isNotEmpty ? placas : null,
        'usuario_id': _usuarioId,
        'empresa_id': _empresaId,
        'motorista_id': _motoristaId,
        'transportadora_id': _transportadoraId,
        'data_mov': _dataSelecionada.toIso8601String().split('T')[0],
        'filial_origem_id': filialOrigemId,
        'filial_destino_id': isConsumo ? null : filialDestinoId,
        'updated_at': DateTime.now().toIso8601String(),
        'filial_id': null,
        'tipo_mov': null,
        'tipo_mov_orig': 'saida',
        'tipo_mov_dest': isConsumo ? null : 'entrada',
        'terminal_orig_id': terminalOrigId,
        'terminal_dest_id': isConsumo ? null : terminalDestId,
      };

      await supabase.from('movimentacoes').insert([transferencia]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transferência registrada com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('Erro ao salvar transferência: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  String _formatarData(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}';
  }

  Widget _buildCampoPlaca({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required bool mostrarSugestoes,
    required bool carregando,
    required List<Map<String, dynamic>> placasEncontradas,
    required Function(String) onChanged,
    required Function(Map<String, dynamic>) onSelecionar,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0D47A1),
          ),
        ),
        const SizedBox(height: 4),
        Stack(
          children: [
            TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: Colors.grey.shade400, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: Colors.grey.shade400, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 1.2),
                ),
                suffixIcon: carregando
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : const Icon(Icons.search, size: 16),
              ),
            ),
            
            if (mostrarSugestoes && placasEncontradas.isNotEmpty)
              Positioned(
                top: 42,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: placasEncontradas.map((item) {
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => onSelecionar(item),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.grey.shade200,
                                  width: 0.5,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.directions_car, 
                                  size: 14, 
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _aplicarMascaraPlaca(item['placas']),
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Container(
        width: 900,
        constraints: const BoxConstraints(maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFF0D47A1),
                borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: Row(
                children: [
                  Icon(Icons.swap_horiz, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  const Text(
                    'Nova Transferência',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 18),
                    onPressed: () => Navigator.of(context).pop(false),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Data',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0D47A1),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.grey.shade400, width: 1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    dropdownColor: Colors.white,
                                    value: _formatarData(_dataSelecionada),
                                    isExpanded: true,
                                    icon: const Icon(Icons.arrow_drop_down, size: 20),
                                    style: const TextStyle(fontSize: 13, color: Colors.black),
                                    onChanged: (dataString) {
                                      if (dataString != null) {
                                        final index = _datasFormatadas.indexOf(dataString);
                                        if (index >= 0) {
                                          setState(() => _dataSelecionada = _datasDisponiveis[index]);
                                        }
                                      }
                                    },
                                    items: _datasFormatadas.map((dataStr) {
                                      return DropdownMenuItem<String>(
                                        value: dataStr,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          child: Text(dataStr),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(width: 16),
                        
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Produto *',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0D47A1),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.grey.shade400, width: 1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _produtoSelecionado,
                                    isExpanded: true,
                                    itemHeight: null,
                                    icon: const Icon(Icons.arrow_drop_down, size: 20),
                                    style: const TextStyle(fontSize: 13, color: Colors.black),
                                    hint: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 12),
                                      child: Text('Selecione um produto'),
                                    ),
                                    onChanged: (id) {
                                      setState(() {
                                        _produtoSelecionado = id;
                                        _produtoId = id;
                                      });
                                    },
                                    dropdownColor: Colors.white,
                                    items: _produtos.map((produto) {
                                      final grupo = produto['grupo']?.toString();
                                      final isEspecial = grupo == '2' || grupo == '3';

                                      return DropdownMenuItem<String>(
                                        value: produto['id']?.toString(),
                                        child: Container(
                                          height: 32, // Altura reduzida para diminuir a distância
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isEspecial ? const Color.fromARGB(255, 255, 195, 195) : null,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            produto['nome_dois']?.toString() ?? produto['nome']?.toString() ?? '',
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                            overflow: TextOverflow.visible,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(width: 16),
                        
                        Expanded(
                          flex: 2,
                          child: _buildCampoAutocomplete<Map<String, dynamic>>(
                            controller: _motoristaController,
                            label: 'Motorista',
                            buscarItens: _buscarMotoristas,
                            obterTextoExibicao: (item) => item['motorista']?.toString() ?? '',
                            onSelecionado: (motorista) async {
                              final motoristaId = motorista['motorista_id']?.toString();
                              _motoristaId = motoristaId;
                              
                              if (motoristaId != null) {
                                final conjunto = await _buscarConjuntoPorMotorista(motoristaId);

                                if (conjunto == null) {
                                  _limparMotoristaEPlacas();
                                  return;
                                }

                                _aplicarConjuntoNosCampos(conjunto);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Quantidade *',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0D47A1),
                                ),
                              ),
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: _quantidadeController,
                                keyboardType: TextInputType.number,
                                maxLength: 7,
                                onChanged: (value) {
                                  final maskedValue = _aplicarMascaraQuantidade(value);
                                  
                                  if (maskedValue != value) {
                                    final cursorPosition = _quantidadeController.selection.baseOffset;
                                    _quantidadeController.value = TextEditingValue(
                                      text: maskedValue,
                                      selection: TextSelection.collapsed(
                                        offset: cursorPosition + (maskedValue.length - value.length),
                                      ),
                                    );
                                  }
                                },
                                style: const TextStyle(fontSize: 13),
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide: BorderSide(color: Colors.grey.shade400, width: 1),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide: BorderSide(color: Colors.grey.shade400, width: 1),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 1.2),
                                  ),
                                  counterText: '',
                                  suffixText: 'litros',
                                  suffixStyle: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(width: 16),
                        
                        Expanded(
                          flex: 1,
                          child: _buildCampoPlaca(
                            controller: _cavaloController,
                            focusNode: _cavaloFocusNode,
                            label: 'Cavalo',
                            mostrarSugestoes: _mostrarSugestoesCavalo,
                            carregando: _carregandoPlacasCavalo,
                            placasEncontradas: _placasCavaloEncontradas,
                            onChanged: (texto) {
                              _onEdicaoManualPlaca(texto, _cavaloController);
                              _buscarPlacasCavalo(texto);
                            },
                            onSelecionar: _selecionarPlacaCavalo,
                          ),
                        ),
                        
                        const SizedBox(width: 16),
                        
                        Expanded(
                          flex: 1,
                          child: _buildCampoPlaca(
                            controller: _reboque1Controller,
                            focusNode: _reboque1FocusNode,
                            label: 'Reboque 1',
                            mostrarSugestoes: _mostrarSugestoesReboque1,
                            carregando: _carregandoPlacasReboque1,
                            placasEncontradas: _placasReboque1Encontradas,
                            onChanged: (texto) {
                              _onEdicaoManualPlaca(texto, _reboque1Controller);
                              _buscarPlacasReboque1(texto);
                            },
                            onSelecionar: _selecionarPlacaReboque1,
                          ),
                        ),
                        
                        const SizedBox(width: 16),
                        
                        Expanded(
                          flex: 1,
                          child: _buildCampoPlaca(
                            controller: _reboque2Controller,
                            focusNode: _reboque2FocusNode,
                            label: 'Reboque 2',
                            mostrarSugestoes: _mostrarSugestoesReboque2,
                            carregando: _carregandoPlacasReboque2,
                            placasEncontradas: _placasReboque2Encontradas,
                            onChanged: (texto) {
                              _onEdicaoManualPlaca(texto, _reboque2Controller);
                              _buscarPlacasReboque2(texto);
                            },
                            onSelecionar: _selecionarPlacaReboque2,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildCampoAutocomplete<Map<String, dynamic>>(
                            controller: _transportadoraController,
                            label: 'Transportadora',
                            buscarItens: _buscarTransportadoras,
                            obterTextoExibicao: (item) => item['nome_dois']?.toString() ?? '',
                            onSelecionado: (transportadora) {
                              _transportadoraId = transportadora['id']?.toString();
                            },
                          ),
                        ),
                        
                        const SizedBox(width: 16),
                        
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Origem *',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0D47A1),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.grey.shade400, width: 1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _origemSelecionada,
                                    isExpanded: true,
                                    icon: const Icon(Icons.arrow_drop_down, size: 20),
                                    style: const TextStyle(fontSize: 13, color: Colors.black),
                                    hint: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 12),
                                      child: Text('Selecione a origem'),
                                    ),
                                    onChanged: (id) {
                                      setState(() {
                                        _origemSelecionada = id;
                                        _origemId = id;
                                      });
                                    },
                                    items: _terminais.map((terminal) {
                                      return DropdownMenuItem<String>(
                                        value: terminal['id']?.toString(),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          child: Text(terminal['nome']?.toString() ?? ''),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(width: 16),
                        
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Destino *',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0D47A1),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.grey.shade400, width: 1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _destinoSelecionado,
                                    isExpanded: true,
                                    icon: const Icon(Icons.arrow_drop_down, size: 20),
                                    style: const TextStyle(fontSize: 13, color: Colors.black),
                                    hint: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 12),
                                      child: Text('Selecione o destino'),
                                    ),
                                    onChanged: (id) {
                                      setState(() {
                                        _destinoSelecionado = id;
                                        _destinoId = id;
                                      });
                                    },
                                    items: _terminais.map((terminal) {
                                      return DropdownMenuItem<String>(
                                        value: terminal['id']?.toString(),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          child: Text(terminal['nome']?.toString() ?? ''),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.orange.shade200, width: 1),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: Colors.orange.shade700, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '* Campos obrigatórios: Produto, Quantidade, Origem e Destino',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 120,
                    height: 36,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        side: BorderSide(color: Colors.grey.shade400, width: 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color.fromARGB(255, 95, 95, 95),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  SizedBox(
                    width: 140,
                    height: 36,
                    child: ElevatedButton(
                      onPressed: _salvando ? null : _salvar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: _salvando
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'Criar Ordem',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
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
}