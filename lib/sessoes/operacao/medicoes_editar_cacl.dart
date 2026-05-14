import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_page.dart';
import 'cacl.dart';

class EditarCaclPage extends StatefulWidget {
  final VoidCallback onVoltar;
  final String caclId;
  
  // Parâmetros para navegação de volta para EstoqueTanquePage
  final String? tanqueReferencia;
  final String? filialId;
  final String? filialNome;
  final DateTime? dataReferencia;

  const EditarCaclPage({
    super.key,
    required this.onVoltar,
    required this.caclId,
    this.tanqueReferencia,
    this.filialId,
    this.filialNome,
    this.dataReferencia,
  });

  @override
  State<EditarCaclPage> createState() => _EditarCaclPageState();
}

class _EditarCaclPageState extends State<EditarCaclPage> {
  // Dados do CACL carregado do banco
  Map<String, dynamic> _caclData = {};
  Map<String, dynamic> _tanqueInfo = {};
  
  // Controladores para os campos
  final List<TextEditingController> _controllers = [];
  final List<FocusNode> _focusNodes = [];
  final TextEditingController _dataController = TextEditingController();
  
  // Estado da página
  bool _carregando = true;
  bool _carregandoCacl = true;
  bool _botaoHabilitado = false;
  String? _nomeFilial;
  String? _terminalId;
  
  // Checkboxes (carregar do CACL se existirem)
  bool _caclVerificacao = false;
  bool _caclMovimentacao = false;

  // Dados para navegação
  String? _tanqueReferencia;
  DateTime _dataFiltro = DateTime.now();

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
    _inicializarControladores();
    _carregarDadosCacl();
  }
  
  void _inicializarControladores() {
    // Inicializar 20 controladores (0-19) para garantir índices
    for (int i = 0; i < 20; i++) {
      _controllers.add(
        TextEditingController(
          text: i == 10 ? _horarioAtualBrasiliaFormatado() : '',
        ),
      );
      _focusNodes.add(FocusNode());
    }
    
    // Configurar listeners para os 6 campos obrigatórios da 2ª medição
    for (int i = 10; i < 16; i++) {
      _focusNodes[i].addListener(() {
        if (!_focusNodes[i].hasFocus && mounted) {
          _verificarCamposObrigatorios();
        }
      });
      
      _controllers[i].addListener(() {
        if (mounted) {
          _verificarCamposObrigatorios();
        }
      });
    }
  }
  
  String _formatarCapacidade(dynamic valor) {
    if (valor == null) return '0 L';
    String str = valor.toString().replaceAll(RegExp(r'[^\d]'), '');
    if (str.isEmpty) return '0 L';
    
    int numero = int.tryParse(str) ?? 0;
    String formatado = numero.toString();
    
    if (formatado.length > 3) {
      final buffer = StringBuffer();
      for (int i = 0; i < formatado.length; i++) {
        if (i > 0 && (formatado.length - i) % 3 == 0) {
          buffer.write('.');
        }
        buffer.write(formatado[i]);
      }
      formatado = buffer.toString();
    }
    
    return '$formatado L';
  }

  Future<void> _carregarDadosCacl() async {
    setState(() {
      _carregando = true;
      _carregandoCacl = true;
    });
    
    try {
      final supabase = Supabase.instance.client;
      
      // 1. Buscar dados do CACL com JOIN nas tabelas relacionadas
      final cacl = await supabase
          .from('cacl')
          .select('''
            *,
            terminais (nome),
            tanques ( 
              referencia,
              capacidade,
              produtos (nome)
            )
          ''')
          .eq('id', widget.caclId)
          .single();
      
      if (cacl['status']?.toString().toLowerCase() != 'pendente') {
        _mostrarErro('Este CACL não está pendente e não pode ser editado.');
        return;
      }
      
      _caclData = cacl;
      _terminalId = cacl['terminal_id']?.toString();
      
      // ✅ CAPTURAR DADOS PARA NAVEGAÇÃO
      if (cacl['data'] != null) {
        try {
          _dataFiltro = DateTime.parse(cacl['data'].toString().split('T')[0]);
        } catch (_) {
          _dataFiltro = DateTime.now();
        }
      }
      
      // 2. Buscar informações do tanque da relação
      if (cacl['tanques'] != null) {
        final tanque = cacl['tanques'];
        _tanqueInfo = {
          'numero': tanque['referencia']?.toString() ?? '',
          'produto': tanque['produtos']?['nome']?.toString() ?? cacl['produto']?.toString() ?? '',
          'capacidade': _formatarCapacidade(tanque['capacidade']),
        };
        
        // ✅ Capturar referência do tanque
        if (tanque['referencia'] != null) {
          _tanqueReferencia = tanque['referencia'].toString();
        }
      } else {
        // Fallback: buscar tanque pelo tanque_id se a relação não funcionar
        final tanqueId = cacl['tanque_id']?.toString();
        if (tanqueId != null && tanqueId.isNotEmpty) {
          final tanqueInfo = await supabase
              .from('tanques')
              .select('''
                referencia,
                capacidade,
                produtos (nome)
              ''')
              .eq('id', tanqueId)
              .maybeSingle();
          
          if (tanqueInfo != null) {
            _tanqueInfo = {
              'numero': tanqueInfo['referencia']?.toString() ?? '',
              'produto': tanqueInfo['produtos']?['nome']?.toString() ?? cacl['produto']?.toString() ?? '',
              'capacidade': _formatarCapacidade(tanqueInfo['capacidade']),
            };
            
            // ✅ Capturar referência do tanque
            if (tanqueInfo['referencia'] != null) {
              _tanqueReferencia = tanqueInfo['referencia'].toString();
            }
          } else {
            // Fallback com dados do CACL
            _tanqueInfo = {
              'numero': cacl['produto']?.toString() ?? '',
              'produto': cacl['produto']?.toString() ?? '',
              'capacidade': 'Capacidade não encontrada',
            };
          }
        } else {
          // Fallback com dados do CACL
          _tanqueInfo = {
            'numero': cacl['produto']?.toString() ?? '',
            'produto': cacl['produto']?.toString() ?? '',
            'capacidade': 'Capacidade não encontrada',
          };
        }
      }
      
      // 3. Preencher dados da interface
      await _preencherDadosInterface();
      
      // 4. Carregar nome do terminal
      if (cacl['terminais'] != null) {
        _nomeFilial = cacl['terminais']['nome']?.toString();
      } else {
        _nomeFilial = cacl['base']?.toString();
      }
      
      setState(() {
        _carregandoCacl = false;
      });
      
      // Verificar campos obrigatórios após preenchimento
      _verificarCamposObrigatorios();
      
    } catch (e) {
      debugPrint('❌ Erro ao carregar CACL: $e');
      _mostrarErro('Erro ao carregar dados do CACL: $e');
    } finally {
      setState(() {
        _carregando = false;
      });
    }
  }
  
  Future<void> _preencherDadosInterface() async {
    // Formatar data
    final dataSql = _caclData['data']?.toString() ?? '';
    if (dataSql.isNotEmpty) {
      try {
        final data = DateTime.parse(dataSql);
        _dataController.text = '${data.day.toString().padLeft(2, '0')}/'
            '${data.month.toString().padLeft(2, '0')}/'
            '${data.year}';
      } catch (_) {
        _dataController.text = dataSql;
      }
    }
    
    // Carregar checkboxes
    final tipo = _caclData['tipo']?.toString();
    if (tipo == 'verificacao') {
      _caclVerificacao = true;
      _caclMovimentacao = false;
    } else if (tipo == 'movimentacao') {
      _caclVerificacao = false;
      _caclMovimentacao = true;
    }
    
    // Preencher 1ª MEDIÇÃO (campos 0-9) - SOMENTE LEITURA
    // Horário Inicial (0)
    _controllers[0].text = _formatarHorarioParaInterface(_caclData['horario_inicial']);
    
    // cm Inicial (1) e mm Inicial (2)
    _controllers[1].text = _caclData['altura_total_cm_inicial']?.toString() ?? '';
    _controllers[2].text = _caclData['altura_total_mm_inicial']?.toString() ?? '';
    
    // Temp Tanque Inicial (3)
    _controllers[3].text = _caclData['temperatura_tanque_inicial']?.toString() ?? '';
    
    // Densidade Inicial (4)
    _controllers[4].text = _caclData['densidade_observada_inicial']?.toString() ?? '';
    
    // Temp Amostra Inicial (5)
    _controllers[5].text = _caclData['temperatura_amostra_inicial']?.toString() ?? '';
    
    // Água cm Inicial (6) e mm Inicial (7)
    final alturaAguaInicial = _caclData['altura_agua_inicial']?.toString() ?? '';
    if (alturaAguaInicial.contains(',')) {
      final partes = alturaAguaInicial.split(',');
      if (partes.length == 2) {
        _controllers[6].text = partes[0];
        _controllers[7].text = partes[1].replaceAll(' cm', '').trim();
      }
    }
    
    // Faturado Inicial (8) - geralmente vazio ou 0
    _controllers[8].text = _caclData['faturado_inicial']?.toString() ?? '';
    
    // Observações Inicial (9)
    _controllers[9].text = _caclData['observacoes_inicial']?.toString() ?? '';
    
    // NÃO PREENCHER 2ª MEDIÇÃO (campos 10-18) - EDITÁVEIS
    // Os controladores já nascem vazios, não preencher nada
  }
  
  String _formatarHorarioParaInterface(String? horarioSql) {
    if (horarioSql == null || horarioSql.isEmpty) return '';
    
    try {
      // Aceita timestamp (ISO) ou "HH:MM:SS"
      if (horarioSql.contains('T')) {
        final dt = DateTime.parse(horarioSql);
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} h';
      }

      if (horarioSql.contains(':')) {
        final partes = horarioSql.split(':');
        if (partes.length >= 2) {
          final horas = int.tryParse(partes[0]) ?? 0;
          final minutos = int.tryParse(partes[1]) ?? 0;
          return '${horas.toString().padLeft(2, '0')}:${minutos.toString().padLeft(2, '0')} h';
        }
      }

      return horarioSql;
    } catch (_) {
      return horarioSql;
    }
  }
  
  void _mostrarErro(String mensagem) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensagem),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      
      // Voltar após mostrar erro
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) widget.onVoltar();
      });
    }
  }
  
  String _aplicarMascaraHorario(String texto) {
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
  
  String _aplicarMascaraTemperatura(String texto) {
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
  
  String _aplicarMascaraDensidade(String texto) {
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
  
  void _verificarCamposObrigatorios() {
    if (_carregandoCacl || _controllers.length < 16) {
      setState(() => _botaoHabilitado = false);
      return;
    }
    
    try {
      // Verificar os 6 campos obrigatórios da 2ª medição
      final camposObrigatorios = _controllers.sublist(10, 16);
      final camposPreenchidos = camposObrigatorios.every((controller) => 
          controller.text.trim().isNotEmpty);
      
      // Verificar checkboxes (pelo menos uma marcada)
      final checkboxMarcada = _caclVerificacao || _caclMovimentacao;
      
      // Verificar se os campos da 1ª medição estão preenchidos (devem estar)
      final primeiraMedicaoCompleta = _controllers.sublist(0, 6).every((c) => 
          c.text.trim().isNotEmpty);
      
      final botaoPodeHabilitar = camposPreenchidos && checkboxMarcada && primeiraMedicaoCompleta;
      
      if (mounted) {
        setState(() => _botaoHabilitado = botaoPodeHabilitar);
      }
    } catch (e) {
      debugPrint('Erro na verificação: $e');
      if (mounted) {
        setState(() => _botaoHabilitado = false);
      }
    }
  }
  
  void _gerarCACLAtualizado() {
    if (_tanqueInfo.isEmpty) return;
    
    // Preparar dados da 1ª medição do banco
    final dadosPrimeiraMedicao = {
      'horarioInicial': _controllers[0].text,
      'cmInicial': _controllers[1].text,
      'mmInicial': _controllers[2].text,
      'tempTanqueInicial': _controllers[3].text,
      'densidadeInicial': _controllers[4].text,
      'tempAmostraInicial': _controllers[5].text,
      'alturaAguaInicial': '${_controllers[6].text},${_controllers[7].text} cm',
      'faturadoInicial': _controllers[8].text,
      'observacoesInicial': _controllers[9].text,
      
      // Dados adicionais do banco
      'volumeProdutoInicial': _caclData['volume_produto_inicial']?.toString() ?? '0',
      'volumeAguaInicial': _caclData['volume_agua_inicial']?.toString() ?? '0',
      'volumeTotalLiquidoInicial': _caclData['volume_total_liquido_inicial']?.toString() ?? '0',
      'alturaProdutoInicial': _caclData['altura_produto_inicial']?.toString() ?? '',
      'densidade20Inicial': _caclData['densidade_20_inicial']?.toString() ?? '',
      'fatorCorrecaoInicial': _caclData['fator_correcao_inicial']?.toString() ?? '',
      'volume20Inicial': _caclData['volume_20_inicial']?.toString() ?? '0',
      'massaInicial': _caclData['massa_inicial']?.toString() ?? '',
    };
    
    // Preparar dados da 2ª medição do formulário
    final cmTotalFinal = _controllers[11].text;
    final mmTotalFinal = _controllers[12].text;
    final cmAguaFinal = _controllers[16].text;
    final mmAguaFinal = _controllers[17].text;
    
    final totalCmFinal = double.tryParse(cmTotalFinal) ?? 0.0;
    final totalMmFinal = double.tryParse(mmTotalFinal) ?? 0.0;
    final aguaCmFinal = double.tryParse(cmAguaFinal) ?? 0.0;
    final aguaMmFinal = double.tryParse(mmAguaFinal) ?? 0.0;
    
    final alturaTotalFinalCm = totalCmFinal + (totalMmFinal / 10);
    final alturaAguaFinalCm = aguaCmFinal + (aguaMmFinal / 10);
    final alturaProdutoFinalCm = alturaTotalFinalCm - alturaAguaFinalCm;
    
    String formatarParaCACL(double alturaCm) {
      final parteInteira = alturaCm.floor();
      final parteDecimal = ((alturaCm - parteInteira) * 10).round();
      return '$parteInteira,$parteDecimal cm';
    }
    
    final alturaProdutoFinalFormatada = formatarParaCACL(alturaProdutoFinalCm);
    
    final dadosSegundaMedicao = {
      'horarioFinal': _controllers[10].text,
      'cmFinal': cmTotalFinal,
      'mmFinal': mmTotalFinal,
      'tempTanqueFinal': _controllers[13].text,
      'densidadeFinal': _controllers[14].text,
      'tempAmostraFinal': _controllers[15].text,
      'alturaAguaFinal': '${cmAguaFinal},${mmAguaFinal} cm',
      'alturaProdutoFinal': alturaProdutoFinalFormatada,
      'faturadoFinal': _controllers[18].text,
      
      // Placeholders que serão calculados no CalcPage
      'volumeProdutoFinal': '0',
      'volumeAguaFinal': '0',
      'volumeTotalLiquidoFinal': '0',
      'fatorCorrecaoFinal': '1.0',
      'volume20Final': '0',
      'densidade20Final': '0.000',
      'massaFinal': '',
    };
    
    // Combinar todas as medições
    final dadosMedicoes = {
      ...dadosPrimeiraMedicao,
      ...dadosSegundaMedicao,
    };
    
    // Determinar dados de navegação (prioridade: parâmetros do widget > dados carregados)
    final String? tanqueRef = widget.tanqueReferencia ?? _tanqueReferencia;
    final String? filialId = widget.filialId ?? _terminalId;
    final String? filialNome = widget.filialNome ?? _nomeFilial;
    final DateTime dataRef = widget.dataReferencia ?? _dataFiltro;
    
    // Preparar dados completos para CalcPage
    final dadosFormulario = {
      'id_cacl': widget.caclId, // ID para atualização
      'data': _dataController.text,
      'base': _nomeFilial ?? _caclData['base'] ?? 'POLO DE COMBUSTÍVEL',
      'produto': _tanqueInfo['produto'] ?? _caclData['produto'] ?? '',
      'tanque': _tanqueInfo['numero'] ?? '',
      'responsavel': UsuarioAtual.instance?.nome ?? 'Usuário',
      'medicoes': dadosMedicoes,
      'terminal_id': _terminalId ?? _caclData['terminal_id'],
      'tanque_id': _caclData['tanque_id'],
      'cacl_verificacao': _caclVerificacao,
      'cacl_movimentacao': _caclMovimentacao,
      
      // Dados adicionais para modo edição
      'modo_edicao': true,
      'dados_cacl_original': _caclData,
      
      // Dados para voltar direto para EstoqueTanquePage
      'tanque_referencia': tanqueRef,
      'filial_id': filialId,
      'filial_nome': filialNome,
      'data_referencia': dataRef.toIso8601String(),
    };
    
    // Navegar para CalcPage em modo edição
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CalcPage(
          dadosFormulario: dadosFormulario,
          modo: CaclModo.emissao,
          onVoltar: () {
            // Se voltar manualmente, volta para EditarCaclPage
            Navigator.pop(context);
          },
          onFinalizar: () {
            // Quando emitir, volta para EstoqueTanquePage
            // Primeiro fecha a CalcPage
            Navigator.pop(context);
            // Depois fecha a EditarCaclPage e retorna para EstoqueTanquePage com refresh
            if (mounted) {
              Navigator.pop(context, {'status': 'cacl_emitido'});
            }
          },
        ),
      ),
    );
  }  
    
  @override
  void dispose() {
    _dataController.dispose();
    for (var c in _controllers) c.dispose();
    for (var f in _focusNodes) f.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: _carregando
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF0D47A1),
              ),
            )
          : _carregandoCacl
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        color: Color(0xFF0D47A1),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Carregando CACL pendente...',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // CABEÇALHO
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8F9FA),
                        border: Border(bottom: BorderSide(color: Colors.grey, width: 1)),
                      ),
                      child: Row(children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1), size: 20),
                          onPressed: widget.onVoltar,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 6),
                        const Text('Editar CACL Pendente',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            border: Border.all(color: Colors.orange),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'PENDENTE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[800],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(_dataController.text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 12),
                        const Icon(Icons.person, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(UsuarioAtual.instance?.nome ?? 'Usuário', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        if (_nomeFilial != null) ...[
                          const SizedBox(width: 12),
                          const Icon(Icons.business, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(_nomeFilial!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green)),
                        ],
                        const Spacer(),
                      ]),
                    ),
                    
                    // CARD DO TANQUE
                    if (_tanqueInfo.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        child: Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                // Badge do tanque
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0D47A1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _tanqueInfo['numero']?.toString() ?? 'N/A',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                
                                // Informações do tanque
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _tanqueInfo['produto']?.toString() ?? '',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _tanqueInfo['capacidade']?.toString() ?? '',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // Status do CACL
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'Status:',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.orange[50],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'AGUARDANDO 2ª MEDIÇÃO',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange[800],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    
                    // FORMULÁRIO DE MEDIÇÕES
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // MENSAGEM INFORMATIVA
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE3F2FD),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF2196F3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    color: Color(0xFF2196F3),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Completando CACL Pendente',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0D47A1),
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '1ª medição já preenchida. Complete os campos da 2ª medição abaixo.',
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // FORMULÁRIO DUPLO
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 1ª MEDIÇÃO (SOMENTE LEITURA)
                                Expanded(
                                  child: FocusTraversalGroup(
                                    descendantsAreFocusable: false,
                                    child: _buildSection(
                                      '1ª Medição',
                                      'Inicial',
                                      Colors.blue[50]!,
                                      Colors.blue,
                                      _controllers.sublist(0, 10),
                                      _focusNodes.sublist(0, 10),
                                      true, // readonly
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                
                                // 2ª MEDIÇÃO (EDITÁVEL)
                                Expanded(
                                  child: FocusTraversalGroup(
                                    policy: OrderedTraversalPolicy(),
                                    child: _buildSection(
                                      '2ª Medição',
                                      'Final',
                                      Colors.green[50]!,
                                      Colors.green,
                                      _controllers.sublist(10, 19),
                                      _focusNodes.sublist(10, 19),
                                      false, // editável
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 20),
                            
                            // CHECKBOXES E BOTÃO
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                                      // CACL verificação
                                      Container(
                                        margin: const EdgeInsets.only(right: 24),
                                        child: Row(
                                          children: [
                                            Checkbox(
                                              value: _caclVerificacao,
                                              onChanged: null,
                                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              visualDensity: VisualDensity.compact,
                                            ),
                                            const Text(
                                              'CACL verificação',
                                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      // CACL movimentação
                                      Row(
                                        children: [
                                          Checkbox(
                                            value: _caclMovimentacao,
                                            onChanged: null,
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            visualDensity: VisualDensity.compact,
                                          ),
                                          const Text(
                                            'CACL movimentação',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 12),
                                  
                                  // Botão Continuar
                                  SizedBox(
                                    width: 200,
                                    child: ElevatedButton(
                                      onPressed: _botaoHabilitado ? _gerarCACLAtualizado : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _botaoHabilitado 
                                            ? Colors.green 
                                            : Colors.grey[400],
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        elevation: 2,
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.edit, 
                                            size: 18,
                                            color: _botaoHabilitado ? Colors.white : Colors.grey[600],
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Continuar Edição',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: _botaoHabilitado ? Colors.white : Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  
                                  // Mensagem de ajuda
                                  if (!_botaoHabilitado)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        'Preencha todos os campos da 2ª medição',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.orange[700],
                                          fontStyle: FontStyle.italic,
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
                  ],
                ),
    );
  }
  
  Widget _buildSection(
    String periodo, 
    String hora, 
    Color bg, 
    Color accent,
    List<TextEditingController> c,
    List<FocusNode> f,
    bool readonly,
  ) {
    final bool ehSegundaMedicao = periodo.contains('2ª');
    
    // Ordem dos campos para TAB navigation (só usado na 2ª medição)
    // 0=Horário, 1=cm, 2=mm, 3=TempTanque, 4=Densidade, 5=TempAmostra, 6=ÁguaCm, 7=ÁguaMm, 8=Faturado
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: readonly ? Colors.grey[50] : bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: readonly ? Colors.grey[300]! : accent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                readonly ? Icons.lock_outline : Icons.access_time,
                size: 14,
                color: readonly ? Colors.grey : accent,
              ),
              const SizedBox(width: 6),
              Text(
                '$periodo - $hora',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: readonly ? Colors.grey : accent,
                  fontSize: 12,
                ),
              ),
              if (readonly) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'SOMENTE LEITURA',
                    style: TextStyle(
                      fontSize: 8,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          
          // PRIMEIRA LINHA: Horário, cm, mm
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildField(
                'Horário Medição', 
                c[0], 
                '', 
                readonly: readonly,
                width: 100, 
                focusNode: f[0], 
                nextFocus: f[1],
                tipo: 'horario',
                ordem: ehSegundaMedicao ? 0 : null,
              ),
              _buildField(
                'cm', 
                c[1], 
                '', 
                readonly: readonly,
                width: 100, 
                maxLength: 4, 
                focusNode: f[1], 
                nextFocus: f[2],
                tipo: 'numero',
                ordem: ehSegundaMedicao ? 1 : null,
              ),
              _buildField(
                'mm', 
                c[2], 
                '', 
                readonly: readonly,
                width: 100, 
                maxLength: 1, 
                focusNode: f[2], 
                nextFocus: f[3],
                tipo: 'numero',
                ordem: ehSegundaMedicao ? 2 : null,
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // SEGUNDA LINHA: Temp. Tanque, Densidade, Temp. Amostra
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildField(
                'Temp. Tanque', 
                c[3], 
                '', 
                readonly: readonly,
                width: 100, 
                focusNode: f[3], 
                nextFocus: f[4],
                tipo: 'temperatura',
                ordem: ehSegundaMedicao ? 3 : null,
              ),
              _buildField(
                'Densidade Obs.', 
                c[4], 
                '', 
                readonly: readonly,
                width: 100, 
                focusNode: f[4], 
                nextFocus: f[5],
                tipo: 'densidade',
                ordem: ehSegundaMedicao ? 4 : null,
              ),
              _buildField(
                'Temp. Amostra', 
                c[5], 
                '', 
                readonly: readonly,
                width: 100, 
                focusNode: f[5], 
                nextFocus: f[6],
                tipo: 'temperatura',
                ordem: ehSegundaMedicao ? 5 : null,
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // TERCEIRA LINHA: Água cm, Água mm, (Faturado ou fantasma)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildField(
                'Água cm', 
                c[6], 
                '', 
                readonly: readonly,
                width: 100, 
                maxLength: 1, 
                focusNode: f[6], 
                nextFocus: f[7],
                tipo: 'numero',
                ordem: ehSegundaMedicao ? 6 : null,
              ),
              _buildField(
                'Água mm', 
                c[7], 
                '', 
                readonly: readonly,
                width: 100, 
                maxLength: 1, 
                focusNode: f[7], 
                nextFocus: f[8],
                tipo: 'numero',
                ordem: ehSegundaMedicao ? 7 : null,
              ),
              // Faturado apenas na segunda medição
              ehSegundaMedicao 
                  ? _buildField(
                      'Faturado', 
                      c[8], // Índice 8 para faturado
                      '', 
                      readonly: readonly || _caclVerificacao,
                      width: 100, 
                      focusNode: f[8], 
                      nextFocus: f.length > 9 ? f[9] : null,
                      tipo: 'faturado',
                      ordem: 8,
                    )
                  : _buildGhostField(width: 100),
            ],
          ),
          const SizedBox(height: 12),
          
          // OBSERVAÇÕES
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
                controller: c.length > (ehSegundaMedicao ? 9 : 8) 
                    ? (ehSegundaMedicao ? c[9] : c[8])
                    : TextEditingController(),
                focusNode: f.length > (ehSegundaMedicao ? 9 : 8)
                    ? (ehSegundaMedicao ? f[9] : f[8])
                    : FocusNode(),
                readOnly: readonly,
                textInputAction: TextInputAction.done,
                maxLines: 2,
                maxLength: 140,
                style: TextStyle(
                  fontSize: 12,
                  color: readonly ? Colors.grey : Colors.black,
                ),
                decoration: InputDecoration(
                  hintText: readonly ? 'Nenhuma observação' : 'Digite suas observações...',
                  isDense: true,
                  contentPadding: const EdgeInsets.all(10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: readonly ? Colors.grey.shade300 : Colors.grey.shade400),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(
                      color: readonly ? Colors.grey : accent, 
                      width: readonly ? 1.0 : 1.5
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: readonly ? Colors.grey.shade300 : Colors.grey.shade400),
                  ),
                  filled: true,
                  fillColor: readonly ? Colors.grey[100] : Colors.white,
                  counterText: '',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildField(
    String label, 
    TextEditingController ctrl, 
    String hint, {
    required bool readonly,
    double width = 100,
    int? maxLength,
    FocusNode? focusNode,
    FocusNode? nextFocus,
    required String tipo,
    int? ordem,
  }) {
    int? maxLengthFinal;
    switch (tipo) {
      case 'horario':
      case 'temperatura':
      case 'densidade':
      case 'faturado':
        maxLengthFinal = null;
        break;
      case 'numero':
        if (label.toLowerCase().contains('água') && label.toLowerCase().contains('mm')) {
          maxLengthFinal = 1;
        } else if (label.toLowerCase().contains('cm')) {
          maxLengthFinal = 4;
        } else if (label.toLowerCase().contains('mm')) {
          maxLengthFinal = 1;
        }
        break;
    }
    
    final fieldWidget = Column(
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
        SizedBox(
          width: width,
          height: 36,
          child: TextFormField(
            controller: ctrl,
            focusNode: focusNode,
            readOnly: readonly,
            textInputAction: nextFocus != null ? TextInputAction.next : TextInputAction.done,
            onFieldSubmitted: (_) => nextFocus?.requestFocus(),
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            style: TextStyle(
              fontSize: 12,
              color: readonly ? Colors.grey : Colors.black,
            ),
            maxLength: maxLengthFinal,
            onChanged: (value) {
              if (readonly) return;
              
              final cursorPosition = ctrl.selection.baseOffset;
              String maskedValue = value;
              
              switch (tipo) {
                case 'horario':
                  maskedValue = _aplicarMascaraHorario(value);
                  break;
                case 'temperatura':
                  maskedValue = _aplicarMascaraTemperatura(value);
                  break;
                case 'densidade':
                  maskedValue = _aplicarMascaraDensidade(value);
                  break;
                case 'faturado':
                  maskedValue = _aplicarMascaraFaturado(value);
                  break;
                default:
                  maskedValue = value;
              }
              
              if (maskedValue != value) {
                ctrl.value = TextEditingValue(
                  text: maskedValue,
                  selection: TextSelection.collapsed(
                    offset: cursorPosition + (maskedValue.length - value.length),
                  ),
                );
              }
            },
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: BorderSide(color: readonly ? Colors.grey.shade300 : Colors.grey.shade400),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: BorderSide(
                  color: readonly ? Colors.grey : const Color(0xFF0D47A1), 
                  width: readonly ? 1.0 : 1.5
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: BorderSide(color: readonly ? Colors.grey.shade300 : Colors.grey.shade400),
              ),
              filled: true,
              fillColor: readonly ? Colors.grey[100] : Colors.white,
              counterText: '',
            ),
          ),
        ),
      ],
    );
    
    // Wrap in FocusTraversalOrder for proper TAB navigation order
    if (ordem != null) {
      return FocusTraversalOrder(
        order: NumericFocusOrder(ordem.toDouble()),
        child: fieldWidget,
      );
    }
    
    return fieldWidget;
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
        SizedBox(
          width: width,
          height: 36,
        ),
      ],
    );
  }
}