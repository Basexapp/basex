import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../operacao/certificado_apuracao_saida.dart';
import '../operacao/certificado_apuracao_entrada.dart';

enum EtapaCircuito {
  programado,
  aguardando,
  checkList,
  operacao,
  emissaoNF,    // Apenas para Carregamento
  liberacao,    // 5 para ambos os fluxos
}

enum TipoMovimentacao {
  carregamento,  // Veículo saindo
  descarregamento, // Veículo chegando
}

class DetalhesOrdemView extends StatefulWidget {
  final Map<String, dynamic> ordem;
  final String terminalAtualId;
  final String dataFiltro; // Data selecionada no filtro de acompanhamento (dd/mm/aaaa)

  const DetalhesOrdemView({
    super.key,
    required this.ordem,
    required this.terminalAtualId,
    required this.dataFiltro,
  });

  @override
  State<DetalhesOrdemView> createState() => _DetalhesOrdemViewState();
}

class _DetalhesOrdemViewState extends State<DetalhesOrdemView>
    with SingleTickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _carregando = true;
  bool _erro = false;
  String _mensagemErro = '';

  List<Map<String, dynamic>> _movimentacoes = [];
  late EtapaCircuito _etapaAtual;
  TipoMovimentacao _tipoMovimentacao = TipoMovimentacao.carregamento;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  // Adicionado: Variável para armazenar o número de controle da ordem
  String? _numeroControleOrdem;

  // Variáveis para o diálogo do Check-list
  bool _civSelecionado = false;
  bool _cippSelecionado = false;
  bool _mopSelecionado = false;
  bool _nr26Selecionado = false;
  bool _atualizandoChecklist = false;    

  // Histórico de fatos ocorridos - será preenchido dinamicamente
  List<Map<String, String>> _historicoFatos = [];

  // Mapa de cores para produtos - EXPANDIDO PARA TODOS OS PRODUTOS
  final Map<String, Color> _coresProdutos = {
    // Gasolinas
    'gasolina comum': Color(0xFFFF6B35),
    'g comum': Color(0xFFFF6B35),
    'gasolina com': Color(0xFFFF6B35),
    
    'gasolina aditivada': Color(0xFF00A8E8),
    'g aditivada': Color(0xFF00A8E8),
    'gasolina ad': Color(0xFF00A8E8),
    
    'gasolina a': Color(0xFFE91E63),
    'gasolina aditivada a': Color(0xFFE91E63),
    
    // Diesels
    'diesel s500': Color(0xFF8D6A9F),
    'd s500': Color(0xFF8D6A9F),
    'diesel s-500': Color(0xFF8D6A9F),
    
    'diesel s10': Color(0xFF2E294E),
    'd s10': Color(0xFF2E294E),
    'diesel s-10': Color(0xFF2E294E),
    
    's500 a': Color(0xFF9C27B0),
    'diesel s500 a': Color(0xFF9C27B0),
    
    's10 a': Color(0xFF673AB7),
    'diesel s10 a': Color(0xFF673AB7),
    
    // Etanóis
    'etanol': Color(0xFF83B692),
    'etanol hidratado': Color(0xFF83B692),
    'hidratado': Color(0xFF83B692),
    
    'anidro': Color(0xFF4CAF50),
    'etanol anidro': Color(0xFF4CAF50),
    
    // Biodiesel
    'b100': Color(0xFF8BC34A),
    'biodiesel': Color(0xFF8BC34A),
    
    // Padrão para produtos não mapeados
    'desconhecido': Color(0xFF607D8B),
  };

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // 1. Determinar tipo de movimentação PRIMEIRO
    _tipoMovimentacao = _determinarTipoMovimentacao();
    
    _carregarStatusAtualDaOrdem();
    _etapaAtual = _resolverEtapaPorStatus(_obterStatusAtual());
    _carregarNumeroControleOrdem();
    _carregarMovimentacoes();
    _inicializarHistorico();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // NOVO MÉTODO: Obter o campo de status correto baseado no tipo
  dynamic _obterStatusAtual() {
    if (_tipoMovimentacao == TipoMovimentacao.carregamento) {
      return widget.ordem['status_circuito_orig'];
    } else {
      return widget.ordem['status_circuito_dest'];
    }
  }

  TipoMovimentacao _determinarTipoMovimentacao() {
    final origemId = widget.ordem['terminal_origem_id']?.toString();
    final destinoId = widget.ordem['terminal_destino_id']?.toString();
    final terminalAtualId = widget.terminalAtualId; // Recebido como parâmetro    
    
    if (origemId == terminalAtualId) {
      return TipoMovimentacao.carregamento;
    } else if (destinoId == terminalAtualId) {
      return TipoMovimentacao.descarregamento;
    }
    
    return TipoMovimentacao.carregamento;
  }

  // Inicializa o histórico baseado no tipo de movimentação
  void _inicializarHistorico() {
    final tipoOp = widget.ordem['tipo_op']?.toString().toLowerCase() ?? '';
    final isConsumo = tipoOp == 'consumo';

    if (_tipoMovimentacao == TipoMovimentacao.carregamento) {
      _historicoFatos = [
        {
          'data': '15/01/2024',
          'hora': '09:30',
          'descricao': isConsumo 
              ? 'Programação de consumo realizada por Carlos Silva'
              : 'Programação de carregamento realizada por Carlos Silva'
        },
        {
          'data': '15/01/2024',
          'hora': '10:15',
          'descricao': 'Ordem colocada em espera - Aguardando disponibilidade'
        },
        {
          'data': '15/01/2024',
          'hora': '10:45',
          'descricao': 'Veículo deu entrada na base, em fase de check-list.'
        },
        {
          'data': '15/01/2024',
          'hora': '11:00',
          'descricao': isConsumo
              ? 'Check-list finalizado, início do consumo.'
              : 'Check-list finalizado, início do carregamento.'
        },
        {
          'data': '15/01/2024',
          'hora': '12:20',
          'descricao': isConsumo
              ? 'Veículo abastecido para consumo. Aguardando emissão de nota fiscal'
              : 'Veículo carregado. Aguardando emissão de nota fiscal'
        },
        {
          'data': '15/01/2024',
          'hora': '13:05',
          'descricao': 'Nota fiscal entregue ao motorista, liberação realizada.'
        },
      ];
    } else {
      _historicoFatos = [
        {
          'data': '15/01/2024',
          'hora': '09:30',
          'descricao': 'Programação de descarregamento realizada por Carlos Silva'
        },
        {
          'data': '15/01/2024',
          'hora': '10:15',
          'descricao': 'Ordem colocada em espera - Aguardando chegada do veículo'
        },
        {
          'data': '15/01/2024',
          'hora': '10:45',
          'descricao': 'Veículo chegou na base, em fase de check-list.'
        },
        {
          'data': '15/01/2024',
          'hora': '11:00',
          'descricao': 'Check-list finalizado, início do descarregamento.'
        },
        {
          'data': '15/01/2024',
          'hora': '12:20',
          'descricao': 'Descarga concluída, veículo pronto para liberação.'
        },
      ];
    }
  }

  Future<void> _carregarStatusAtualDaOrdem() async {
    final ordemId = widget.ordem['ordem_id'];
    if (ordemId == null) return;

    final dados = await _supabase
        .from('movimentacoes')
        .select('status_circuito_orig, status_circuito_dest')
        .eq('ordem_id', ordemId)
        .order('id', ascending: true)
        .limit(1);

    if (dados.isNotEmpty && mounted) {
      final status = _tipoMovimentacao == TipoMovimentacao.carregamento
          ? dados.first['status_circuito_orig']
          : dados.first['status_circuito_dest'];

      setState(() {
        _etapaAtual = _resolverEtapaPorStatus(status);
      });
    }
  }  

  List<_EtapaInfo> get _etapasAtivas {
    final tipoOp = widget.ordem['tipo_op']?.toString().toLowerCase() ?? '';
    
    // FLUXO PARA VENDA - Etapas invertidas: Check-list → Emissão NF → Operação → Liberação
    if (_tipoMovimentacao == TipoMovimentacao.carregamento && tipoOp == 'venda') {
      return const [
        _EtapaInfo(
          etapa: EtapaCircuito.programado,
          label: 'Programado',
          subtitle: 'Agendamento realizado',
          icon: Icons.calendar_month,
          cor: Color.fromARGB(255, 61, 160, 206),
          statusCodigo: 1,
        ),
        _EtapaInfo(
          etapa: EtapaCircuito.aguardando,
          label: 'Aguardando',
          subtitle: 'Aguardando disponibilidade',
          icon: Icons.hourglass_empty,
          cor: Color.fromARGB(255, 5, 151, 0),
          statusCodigo: 15,
        ),
        _EtapaInfo(
          etapa: EtapaCircuito.checkList,
          label: 'Check-list',
          subtitle: 'Verificação de segurança',
          icon: Icons.checklist_outlined,
          cor: Color(0xFFF57C00),
          statusCodigo: 2,
        ),
        _EtapaInfo(
          etapa: EtapaCircuito.emissaoNF,
          label: 'Emissão NF',
          subtitle: 'Documentação fiscal',
          icon: Icons.description_outlined,
          cor: Color(0xFFC2185B),
          statusCodigo: 3,  // Status 3 no banco (operação original)
        ),
        _EtapaInfo(
          etapa: EtapaCircuito.operacao,
          label: 'Em operação',
          subtitle: 'Carga em transporte',
          icon: Icons.invert_colors,
          cor: Color(0xFF7B1FA2),
          statusCodigo: 4,  // Status 4 no banco (emissão NF original)
        ),
        _EtapaInfo(
          etapa: EtapaCircuito.liberacao,
          label: 'Liberado',
          subtitle: 'Operação concluída',
          icon: Icons.done_outline,
          cor: Color.fromARGB(255, 42, 199, 50),
          statusCodigo: 5,
        ),
      ];
    }
    
    // FLUXO PARA TRANSFERÊNCIA (mantém o original)
    if (_tipoMovimentacao == TipoMovimentacao.carregamento) {
      return const [
        _EtapaInfo(
          etapa: EtapaCircuito.programado,
          label: 'Programado',
          subtitle: 'Agendamento realizado',
          icon: Icons.calendar_month,
          cor: Color.fromARGB(255, 61, 160, 206),
          statusCodigo: 1,
        ),
        _EtapaInfo(
          etapa: EtapaCircuito.aguardando,
          label: 'Aguardando',
          subtitle: 'Aguardando disponibilidade',
          icon: Icons.hourglass_empty,
          cor: Color.fromARGB(255, 5, 151, 0),
          statusCodigo: 15,
        ),
        _EtapaInfo(
          etapa: EtapaCircuito.checkList,
          label: 'Check-list',
          subtitle: 'Verificação de segurança',
          icon: Icons.checklist_outlined,
          cor: Color(0xFFF57C00),
          statusCodigo: 2,
        ),
        _EtapaInfo(
          etapa: EtapaCircuito.operacao,
          label: 'Em operação',
          subtitle: 'Carga em transporte',
          icon: Icons.invert_colors,
          cor: Color(0xFF7B1FA2),
          statusCodigo: 3,
        ),
        _EtapaInfo(
          etapa: EtapaCircuito.emissaoNF,
          label: 'Emissão NF',
          subtitle: 'Documentação fiscal',
          icon: Icons.description_outlined,
          cor: Color(0xFFC2185B),
          statusCodigo: 4,
        ),
        _EtapaInfo(
          etapa: EtapaCircuito.liberacao,
          label: 'Liberado',
          subtitle: 'Operação concluída',
          icon: Icons.done_outline,
          cor: Color.fromARGB(255, 42, 199, 50),
          statusCodigo: 5,
        ),
      ];
    }
    
    // FLUXO PARA DESCARREGAMENTO (mantém o original)
    return const [
      _EtapaInfo(
        etapa: EtapaCircuito.programado,
        label: 'Programado',
        subtitle: 'Agendamento realizado',
        icon: Icons.calendar_month,
        cor: Color.fromARGB(255, 61, 160, 206),
        statusCodigo: 1,
      ),
      _EtapaInfo(
        etapa: EtapaCircuito.aguardando,
        label: 'Aguardando',
        subtitle: 'Aguardando chegada',
        icon: Icons.hourglass_empty,
        cor: Color.fromARGB(255, 5, 151, 0),
        statusCodigo: 15,
      ),
      _EtapaInfo(
        etapa: EtapaCircuito.checkList,
        label: 'Check-list',
        subtitle: 'Verificação de segurança',
        icon: Icons.checklist_outlined,
        cor: Color(0xFFF57C00),
        statusCodigo: 2,
      ),
      _EtapaInfo(
        etapa: EtapaCircuito.operacao,
        label: 'Em operação',
        subtitle: 'Descarga em andamento',
        icon: Icons.invert_colors,
        cor: Color(0xFF7B1FA2),
        statusCodigo: 3,
      ),
      _EtapaInfo(
        etapa: EtapaCircuito.liberacao,
        label: 'Liberado',
        subtitle: 'Descarga concluída',
        icon: Icons.done_outline,
        cor: Color.fromARGB(255, 42, 199, 50),
        statusCodigo: 5,
      ),
    ];
  }

  // NOVO MÉTODO: Carrega o número de controle da ordem da tabela 'ordens'
  Future<void> _carregarNumeroControleOrdem() async {
    try {
      final ordemId = widget.ordem['ordem_id']?.toString();
      if (ordemId == null || ordemId.isEmpty) return;
      
      final resultado = await _supabase
          .from('ordens')
          .select('n_controle')
          .eq('id', ordemId)
          .maybeSingle();
          
      if (resultado != null && resultado['n_controle'] != null) {
        setState(() {
          _numeroControleOrdem = resultado['n_controle']?.toString();
        });
      }
    } catch (e) {
      print('Erro ao carregar número de controle da ordem: $e');
    }
  }

  Future<void> _carregarMovimentacoes() async {
    setState(() {
      _carregando = true;
      _erro = false;
    });

    try {
      final dados = await _supabase
          .from('movimentacoes')
          .select('''
            id,
            placa,
            cliente,
            forma_pagamento,
            entrada_amb,
            entrada_vinte,
            saida_amb,
            saida_vinte,
            data_mov,
            tipo_op,
            descricao,
            produtos!produto_id(id, nome_dois)
          ''')
          .eq('ordem_id', widget.ordem['ordem_id'])
          .order('id');

      setState(() {
        _movimentacoes = List<Map<String, dynamic>>.from(dados);
        _carregando = false;
      });
    } catch (e) {
      setState(() {
        _carregando = false;
        _erro = true;
        _mensagemErro = e.toString();
      });
    }
  }

  EtapaCircuito _resolverEtapaPorStatus(dynamic status) {
    final codigo = status is int ? status : int.tryParse(status.toString()) ?? 1;
    final tipoOp = widget.ordem['tipo_op']?.toString().toLowerCase() ?? '';

    // Mapeamento específico para o fluxo de VENDA no CARREGAMENTO
    if (_tipoMovimentacao == TipoMovimentacao.carregamento && tipoOp == 'venda') {
      switch (codigo) {
        case 1:
          return EtapaCircuito.programado;
        case 15:
          return EtapaCircuito.aguardando;
        case 2:
          return EtapaCircuito.checkList;
        case 3:
          // Status 3 para 'venda' no carregamento deve mostrar como 'Emissão NF'
          return EtapaCircuito.emissaoNF;
        case 4:
          // Status 4 para 'venda' no carregamento deve mostrar como 'Em operação'
          return EtapaCircuito.operacao;
        case 5:
          return EtapaCircuito.liberacao;
        default:
          return EtapaCircuito.programado;
      }
    }

    // Mapeamento simplificado para outros fluxos (Transferência ou Descarregamento)
    switch (codigo) {
      case 1:
        return EtapaCircuito.programado;
      case 15:
        return EtapaCircuito.aguardando;
      case 2:
        return EtapaCircuito.checkList;
      case 3:
        return EtapaCircuito.operacao;
      case 4:
        // Status 4 apenas existe para Carregamento (Emissão NF)
        return EtapaCircuito.emissaoNF;
      case 5:
        // Status 5 para Liberação em ambos os fluxos
        return EtapaCircuito.liberacao;
      default:
        return EtapaCircuito.programado;
    }
  }  
  
  // MÉTODO MODIFICADO: Abrir certificado baseado no tipo de movimentação
  Future<void> _abrirCertificadoApuracao() async {
    final ordemId = widget.ordem['ordem_id']?.toString();
    if (ordemId == null || ordemId.isEmpty) return;

    try {
      // Buscar TODAS as movimentações da ordem para obter os tanques
      final movimentacoes = await _supabase
          .from('movimentacoes')
          .select('id, status_circuito_orig, status_circuito_dest, produtos!produto_id(id, nome, nome_dois), saida_amb, saida_vinte')
          .eq('ordem_id', ordemId)
          .order('id', ascending: true);

      if (!mounted) return;
      if (movimentacoes.isEmpty) return;

      // Criar lista de tanques baseada nas movimentações
      final List<Map<String, dynamic>> tanquesDaOrdem = [];
      for (var mov in movimentacoes) {
        final produtoNome = mov['produtos']?['nome_dois']?.toString() ?? 
                           mov['produtos']?['nome']?.toString() ?? 
                           'Produto não identificado';
        final produtoId = mov['produtos']?['id']?.toString();
        tanquesDaOrdem.add({
          'movimentacao_id': mov['id']?.toString(),
          'produto_nome': produtoNome,
          'produto_id': produtoId,
          'saida_amb': mov['saida_amb'],
          'saida_vinte': mov['saida_vinte'],
        });
      }

      final movimentacaoId = movimentacoes.first['id']?.toString();
      if (movimentacaoId == null) return;

      // VERIFICAÇÃO DO TIPO DE MOVIMENTAÇÃO
      if (_tipoMovimentacao == TipoMovimentacao.carregamento) {
        // FLUXO DE SAÍDA (CARREGAMENTO): Abre EmitirCertificadoPage
        // Verifica se existe análise com "origem" para esta movimentação
        final analises = await _supabase
          .from('ordens_analises')
          .select('id, tipo_analise')
          .eq('movimentacao_id', movimentacaoId)
          .eq('tipo_analise', 'origem');
        
        bool modoSomenteVisualizacao = false;
        String? idAnaliseExistente;
        
        // Verificar se existe análise com tipo_analise contendo "origem"
        for (var analise in analises) {
          final tipoAnalise = analise['tipo_analise']?.toString().toLowerCase() ?? '';
          if (tipoAnalise.contains('origem')) {
            modoSomenteVisualizacao = true;
            idAnaliseExistente = analise['id']?.toString();
            break;
          }
        }

        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EmitirCertificadoPage(
              idCertificado: idAnaliseExistente,
              idMovimentacao: movimentacaoId,
              tanquesDaOrdem: tanquesDaOrdem, // NOVA LISTA DE TANQUES
              terminalId: widget.terminalAtualId, // Terminal da ordem, não do usuário logado
              tipoOp: widget.ordem['tipo_op']?.toString(),
              onVoltar: () {
                Navigator.of(context).pop(true);
              },
              modoSomenteVisualizacao: modoSomenteVisualizacao,
              dataFiltro: widget.dataFiltro,
            ),
          ),
        );

        // Recarregar dados se voltou com sucesso
        if (result == true && mounted) {
          await _atualizarTelaAposCertificado(ordemId);
        }
      } else {
        // FLUXO DE ENTRADA (DESCARREGAMENTO): Abre EmitirCertificadoEntrada
        // Verifica se existe análise com "destino" para esta movimentação
        final analises = await _supabase
          .from('ordens_analises')
          .select('id, tipo_analise')
          .eq('movimentacao_id', movimentacaoId)
          .eq('tipo_analise', 'destino');
        
        bool modoSomenteVisualizacao = false;
        String? idAnaliseExistente;
        
        // Verificar se existe análise com tipo_analise contendo "destino"
        for (var analise in analises) {
          final tipoAnalise = analise['tipo_analise']?.toString().toLowerCase() ?? '';
          if (tipoAnalise.contains('destino')) {
            modoSomenteVisualizacao = true;
            idAnaliseExistente = analise['id']?.toString();
            break;
          }
        }

        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EmitirCertificadoEntrada(
              onVoltar: () {
                Navigator.of(context).pop(true);
              },
              terminalId: widget.terminalAtualId, // Terminal da ordem, não do usuário logado
              idMovimentacao: movimentacaoId,
              modoSomenteVisualizacao: modoSomenteVisualizacao, // NOVO PARÂMETRO
              idAnaliseExistente: idAnaliseExistente, // ID da análise existente
              dataFiltro: widget.dataFiltro, // Data do filtro de acompanhamento
            ),
          ),
        );

        // Recarregar dados se voltou com sucesso
        if (result == true && mounted) {
          await _atualizarTelaAposCertificado(ordemId);
        }
      }
    } catch (e) {
      print('Erro ao abrir certificado: $e');
    }
  }

  // Método auxiliar para atualizar a tela após fechar o certificado
  Future<void> _atualizarTelaAposCertificado(String ordemId) async {
    // Recarregue os dados da tela atual
    await _carregarMovimentacoes();
    
    // Atualize o status local se necessário
    final movimentacoesAtualizadas = await _supabase
        .from('movimentacoes')
        .select('status_circuito_orig, status_circuito_dest')
        .eq('ordem_id', ordemId)
        .order('id', ascending: true)
        .limit(1);

    if (movimentacoesAtualizadas.isNotEmpty && mounted) {
      final novoStatus = _tipoMovimentacao == TipoMovimentacao.carregamento
          ? movimentacoesAtualizadas.first['status_circuito_orig']
          : movimentacoesAtualizadas.first['status_circuito_dest'];
      
      // Atualiza o widget.ordem com o status correto
      if (_tipoMovimentacao == TipoMovimentacao.carregamento) {
        widget.ordem['status_circuito_orig'] = novoStatus;
      } else {
        widget.ordem['status_circuito_dest'] = novoStatus;
      }
      
      setState(() {
        _etapaAtual = _resolverEtapaPorStatus(novoStatus);
      });
    }
  }

  // NOVO MÉTODO: Abrir diálogo do Check-list
  Future<void> _abrirDialogoChecklist() async {
    // Resetar seleções
    setState(() {
      _civSelecionado = false;
      _cippSelecionado = false;
      _mopSelecionado = false;
      _nr26Selecionado = false;
    });

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: Row(
                children: [
                  Icon(
                    Icons.checklist_outlined,
                    color: Color(0xFFF57C00),
                    size: 24,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Check-list de Segurança',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0D47A1),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Marque os itens verificados:',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  // Item 1: CIV
                  _buildChecklistItem(
                    titulo: 'CIV - Certificado de Inspeção Veicular',
                    subtitulo: 'Verificar validade do CIV do veículo',
                    valor: _civSelecionado,
                    onChanged: (value) {
                      setState(() {
                        _civSelecionado = value ?? false;
                      });
                    },
                  ),
                  SizedBox(height: 12),
                  
                  // Item 2: CIPP
                  _buildChecklistItem(
                    titulo: 'CIPP - Certificado de Inspeção para Produtos Perigosos',
                    subtitulo: 'Verificar conformidade para transporte de produtos perigosos',
                    valor: _cippSelecionado,
                    onChanged: (value) {
                      setState(() {
                        _cippSelecionado = value ?? false;
                      });
                    },
                  ),
                  SizedBox(height: 12),
                  
                  // Item 3: MOP
                  _buildChecklistItem(
                    titulo: 'MOP - Manual de Operações',
                    subtitulo: 'Verificar disponibilidade e conformidade',
                    valor: _mopSelecionado,
                    onChanged: (value) {
                      setState(() {
                        _mopSelecionado = value ?? false;
                      });
                    },
                  ),
                  SizedBox(height: 12),
                  
                  // Item 4: NR26
                  _buildChecklistItem(
                    titulo: 'NR26 - Sinalização de Segurança',
                    subtitulo: 'Verificar sinalização do veículo conforme NR26',
                    valor: _nr26Selecionado,
                    onChanged: (value) {
                      setState(() {
                        _nr26Selecionado = value ?? false;
                      });
                    },
                  ),
                  SizedBox(height: 20),
                  
                  // Informação sobre o tipo de operação
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _tipoMovimentacao == TipoMovimentacao.carregamento
                              ? Icons.upload
                              : Icons.download,
                          size: 16,
                          color: Colors.blue.shade700,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _tipoMovimentacao == TipoMovimentacao.carregamento
                                ? 'Operação: Carregamento (Saída)'
                                : 'Operação: Descarregamento (Chegada)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),
                  
                  // Mensagem de validação
                  if (_atualizandoChecklist)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFF57C00),
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Atualizando status...',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'Voltar',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: _atualizandoChecklist
                      ? null
                      : () async {
                          // Verificar se todos os itens foram selecionados
                          final todosSelecionados = _civSelecionado &&
                              _cippSelecionado &&
                              _mopSelecionado &&
                              _nr26Selecionado;
                          
                          if (!todosSelecionados) {
                            return;
                          }
                          
                          // Atualizar status no banco de dados
                          await _concluirChecklist();
                          
                          // Fechar diálogo
                          if (mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFF57C00),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade400,
                    minimumSize: Size(120, 48), // Tamanho mínimo garantido
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: _atualizandoChecklist
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Container(
                          constraints: BoxConstraints(minWidth: 100), // Largura mínima
                          child: Text(
                            'Concluir Check-list',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // NOVO MÉTODO: Widget para item do checklist
  Widget _buildChecklistItem({
    required String titulo,
    required String subtitulo,
    required bool valor,
    required ValueChanged<bool?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: valor ? Color(0xFFF57C00) : Colors.grey.shade300,
          width: valor ? 2 : 1,
        ),
        color: valor ? Color(0xFFF57C00).withOpacity(0.05) : Colors.white,
      ),
      child: CheckboxListTile(
        title: Text(
          titulo,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: valor ? Color(0xFFF57C00) : Colors.grey.shade800,
          ),
        ),
        subtitle: Text(
          subtitulo,
          style: TextStyle(
            fontSize: 12,
            color: valor ? Color(0xFFF57C00).withOpacity(0.8) : Colors.grey.shade600,
          ),
        ),
        value: valor,
        onChanged: onChanged,
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: Color(0xFFF57C00),
        checkColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }

  // NOVO MÉTODO: Concluir checklist e atualizar banco de dados
  Future<void> _concluirChecklist() async {
    setState(() {
      _atualizandoChecklist = true;
    });

    try {
      final ordemId = widget.ordem['ordem_id'];
      if (ordemId != null) {
        final tipoOp = widget.ordem['tipo_op']?.toString().toLowerCase() ?? '';
        final campoStatus = _tipoMovimentacao == TipoMovimentacao.carregamento
            ? 'status_circuito_orig'
            : 'status_circuito_dest';
        
        // VERIFICAR SE É VENDA PARA DEFINIR O PRÓXIMO STATUS
        final isVenda = (_tipoMovimentacao == TipoMovimentacao.carregamento && tipoOp == 'venda');
        
        // Status 3 para ambos os casos, mas a UI interpreta diferente
        await _supabase
            .from('movimentacoes')
            .update({campoStatus: 3})
            .eq('ordem_id', ordemId);

        // Atualizar estado local
        setState(() {
          // Para venda: UI deve mostrar etapa "Emissão NF" (status 3 no banco)
          // Para transferência: UI deve mostrar etapa "Em operação" (status 3 no banco)
          _etapaAtual = isVenda 
              ? EtapaCircuito.emissaoNF 
              : EtapaCircuito.operacao;
          _atualizandoChecklist = false;
          
          // Atualiza também no widget.ordem para manter sincronizado
          if (_tipoMovimentacao == TipoMovimentacao.carregamento) {
            widget.ordem['status_circuito_orig'] = 3;
          } else {
            widget.ordem['status_circuito_dest'] = 3;
          }
        });

        // Adicionar ao histórico local
        final agora = DateTime.now();
        final descricaoChecklist = isVenda
            ? 'Check-list concluído. Aguardando emissão de nota fiscal.'
            : (tipoOp == 'consumo' 
                ? 'Check-list concluído, início do consumo.'
                : 'Check-list concluído, início do carregamento/descarga.');
        
        _historicoFatos.insert(3, {
          'data': '${agora.day.toString().padLeft(2, '0')}/${agora.month.toString().padLeft(2, '0')}/${agora.year}',
          'hora': '${agora.hour.toString().padLeft(2, '0')}:${agora.minute.toString().padLeft(2, '0')}',
          'descricao': descricaoChecklist
        });
      }
    } catch (e) {
      print('Erro ao atualizar checklist: $e');
      setState(() {
        _atualizandoChecklist = false;
      });
    }
  }

  // NOVO MÉTODO: Finalizar emissão NF e avançar para operação (apenas para venda)
  Future<void> _finalizarEmissaoNF() async {
    try {
      final ordemId = widget.ordem['ordem_id'];
      if (ordemId != null) {
        final campoStatus = _tipoMovimentacao == TipoMovimentacao.carregamento
            ? 'status_circuito_orig'
            : 'status_circuito_dest';
        
        // Atualizar para status 4 (operação no banco)
        await _supabase
            .from('movimentacoes')
            .update({campoStatus: 4})
            .eq('ordem_id', ordemId);

        // Atualizar estado local
        setState(() {
          _etapaAtual = EtapaCircuito.operacao;
          
          // Atualiza também no widget.ordem
          if (_tipoMovimentacao == TipoMovimentacao.carregamento) {
            widget.ordem['status_circuito_orig'] = 4;
          } else {
            widget.ordem['status_circuito_dest'] = 4;
          }
        });

        // Adicionar ao histórico local
        final agora = DateTime.now();
        _historicoFatos.insert(4, {
          'data': '${agora.day.toString().padLeft(2, '0')}/${agora.month.toString().padLeft(2, '0')}/${agora.year}',
          'hora': '${agora.hour.toString().padLeft(2, '0')}:${agora.minute.toString().padLeft(2, '0')}',
          'descricao': 'Nota fiscal emitida. Início do carregamento.'
        });
      }
    } catch (e) {
      print('Erro ao finalizar emissão NF: $e');
    }
  }

  // MÉTODO MELHORADO: Dialog para avançar de "Programado" para "Aguardando"
  Future<void> _mostrarDialogProgramadoParaAguardando() async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          constraints: BoxConstraints(maxWidth: 450),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ícone e título
                Icon(
                  Icons.directions_car,
                  color: Color.fromARGB(255, 61, 160, 206),
                  size: 48,
                ),
                const SizedBox(height: 16),
                
                Text(
                  'Veículo Presente?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0D47A1),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Mensagem
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'O veículo está presente no local e pronto para check-list?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Botões
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color.fromARGB(255, 61, 160, 206),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Sim, aguardar check-list'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (resultado == true) {
      await _avancarParaAguardando();
    }
  }

  // NOVO MÉTODO: Dialog para avançar de "Aguardando" para "Check-list"
  Future<void> _mostrarDialogAguardandoParaChecklist() async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          constraints: BoxConstraints(maxWidth: 450),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ícone e título
                Icon(
                  Icons.checklist_outlined,
                  color: Color(0xFFF57C00),
                  size: 48,
                ),
                const SizedBox(height: 16),
                
                Text(
                  'Avançar para Check-list?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0D47A1),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Mensagem
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'O veículo está pronto para iniciar o check-list de segurança?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Botões
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFF57C00),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Sim, avançar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (resultado == true) {
      await _avancarParaChecklist();
      // Após atualizar status, abrir o dialog do checklist
      if (mounted) {
        await _abrirDialogoChecklist();
      }
    }
  }

  // NOVO MÉTODO: Atualizar status para 2 (check-list)
  Future<void> _avancarParaChecklist() async {
    try {
      // Atualizar status_circuito_orig ou status_circuito_dest para 2 (check-list)
      final ordemId = widget.ordem['ordem_id'];
      if (ordemId != null) {
        // Determinar qual campo atualizar
        final campoStatus = _tipoMovimentacao == TipoMovimentacao.carregamento
            ? 'status_circuito_orig'
            : 'status_circuito_dest';
        
        await _supabase
            .from('movimentacoes')
            .update({campoStatus: 2})
            .eq('ordem_id', ordemId);

        // Atualizar estado local
        setState(() {
          _etapaAtual = EtapaCircuito.checkList;
          
          // Atualiza também no widget.ordem
          if (_tipoMovimentacao == TipoMovimentacao.carregamento) {
            widget.ordem['status_circuito_orig'] = 2;
          } else {
            widget.ordem['status_circuito_dest'] = 2;
          }
        });

        // Adicionar ao histórico local
        final agora = DateTime.now();
        _historicoFatos.insert(2, {
          'data': '${agora.day.toString().padLeft(2, '0')}/${agora.month.toString().padLeft(2, '0')}/${agora.year}',
          'hora': '${agora.hour.toString().padLeft(2, '0')}:${agora.minute.toString().padLeft(2, '0')}',
          'descricao': 'Veículo pronto para check-list de segurança'
        });
      }
    } catch (e) {
      print('Erro ao atualizar status para check-list: $e');
    }
  }

  // NOVO MÉTODO: Atualizar status para 15 (aguardando)
  Future<void> _avancarParaAguardando() async {
    try {
      // Atualizar status_circuito_orig ou status_circuito_dest para 15 (aguardando check-list)
      final ordemId = widget.ordem['ordem_id'];
      if (ordemId != null) {
        // Determinar qual campo atualizar
        final campoStatus = _tipoMovimentacao == TipoMovimentacao.carregamento
            ? 'status_circuito_orig'
            : 'status_circuito_dest';
        
        await _supabase
            .from('movimentacoes')
            .update({campoStatus: 15})
            .eq('ordem_id', ordemId);

        // Atualizar estado local
        setState(() {
          _etapaAtual = EtapaCircuito.aguardando;
          
          // Atualiza também no widget.ordem
          if (_tipoMovimentacao == TipoMovimentacao.carregamento) {
            widget.ordem['status_circuito_orig'] = 15;
          } else {
            widget.ordem['status_circuito_dest'] = 15;
          }
        });

        // Adicionar ao histórico local
        final agora = DateTime.now();
        _historicoFatos.insert(1, {
          'data': '${agora.day.toString().padLeft(2, '0')}/${agora.month.toString().padLeft(2, '0')}/${agora.year}',
          'hora': '${agora.hour.toString().padLeft(2, '0')}:${agora.minute.toString().padLeft(2, '0')}',
          'descricao': 'Veículo presente confirmado. Aguardando check-list.'
        });
      }
    } catch (e) {
      print('Erro ao atualizar status para aguardando: $e');
    }
  }
    
  // Agrupar produtos por tipo usando apenas volume ambiente (sem duplicar colunas)
  Map<String, double> _agruparProdutosParaCarregar() {
    final Map<String, double> produtos = {};
    final terminalAtualId = widget.terminalAtualId;

    for (var mov in _movimentacoes) {
      final produtoNome = mov['produtos']?['nome_dois']?.toString() ?? 'desconhecido';

      final terminalDestinoId = mov['terminal_dest_id']?.toString();
      final terminalOrigemId = mov['terminal_orig_id']?.toString();
      final terminalId = mov['terminal_id']?.toString();

      final entradaAmb = (mov['entrada_amb'] ?? 0) as num;
      final saidaAmb = (mov['saida_amb'] ?? 0) as num;

      num quantidade = 0;
      if (terminalAtualId.isNotEmpty && terminalDestinoId == terminalAtualId) {
        quantidade = entradaAmb;
      } else if (terminalAtualId.isNotEmpty &&
          (terminalOrigemId == terminalAtualId || terminalId == terminalAtualId)) {
        quantidade = saidaAmb;
      } else {
        quantidade = saidaAmb > 0 ? saidaAmb : entradaAmb;
      }

      if (quantidade <= 0) continue;

      produtos[produtoNome] = (produtos[produtoNome] ?? 0) + quantidade.toDouble();
    }

    return produtos;
  }

  Future<void> _finalizarCargaExpedicao() async {
    final ordemId = widget.ordem['ordem_id'];
    if (ordemId == null) return;

    final campoStatus = _tipoMovimentacao == TipoMovimentacao.carregamento
        ? 'status_circuito_orig'
        : 'status_circuito_dest';
    
    await _supabase
        .from('movimentacoes')
        .update({campoStatus: 5})
        .eq('ordem_id', ordemId);

    setState(() {
      _etapaAtual = EtapaCircuito.liberacao;
      
      // Atualiza também no widget.ordem
      if (_tipoMovimentacao == TipoMovimentacao.carregamento) {
        widget.ordem['status_circuito_orig'] = 5;
      } else {
        widget.ordem['status_circuito_dest'] = 5;
      }
    });
  }

  bool get _podeReverterEtapa {
    final etapasAtivas = _etapasAtivas;
    final etapaIndex = etapasAtivas.indexWhere((e) => e.etapa == _etapaAtual);
    return etapaIndex > 0;
  }

  Future<void> _reverterEtapaAtual() async {
    final ordemId = widget.ordem['ordem_id'];
    if (ordemId == null) return;

    final etapasAtivas = _etapasAtivas;
    final etapaIndex = etapasAtivas.indexWhere((e) => e.etapa == _etapaAtual);

    if (etapaIndex <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta etapa não pode ser revertida.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final etapaAnterior = etapasAtivas[etapaIndex - 1];
    final campoStatus = _tipoMovimentacao == TipoMovimentacao.carregamento
        ? 'status_circuito_orig'
        : 'status_circuito_dest';

    try {
      await _supabase
          .from('movimentacoes')
          .update({campoStatus: etapaAnterior.statusCodigo})
          .eq('ordem_id', ordemId);

      if (!mounted) return;
      setState(() {
        _etapaAtual = etapaAnterior.etapa;
        if (_tipoMovimentacao == TipoMovimentacao.carregamento) {
          widget.ordem['status_circuito_orig'] = etapaAnterior.statusCodigo;
        } else {
          widget.ordem['status_circuito_dest'] = etapaAnterior.statusCodigo;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao reverter etapa: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatarPlacas(dynamic placasData) {
    if (placasData == null) return 'N/I';
    
    if (placasData is List) {
      return placasData.where((p) => p != null && p.toString().isNotEmpty)
                      .map((p) => p.toString())
                      .join(', ');
    }
    return placasData.toString();
  }

  // NOVO: Formatar número no padrão '999.999'
  String _formatarNumero(double valor) {
    if (valor.isNaN || valor.isInfinite) return '0';
    
    // Arredonda para zero casas decimais
    final valorArredondado = valor.round();
    
    // Converte para string
    String valorStr = valorArredondado.abs().toString();
    
    // Adiciona ponto como separador de milhar
    String resultado = '';
    int contador = 0;
    
    // Percorre de trás para frente
    for (int i = valorStr.length - 1; i >= 0; i--) {
      resultado = valorStr[i] + resultado;
      contador++;
      
      // Adiciona ponto a cada 3 dígitos (exceto no início)
      if (contador == 3 && i > 0) {
        resultado = '.$resultado';
        contador = 0;
      }
    }
    
    // Adiciona sinal negativo se necessário
    if (valorArredondado < 0) {
      resultado = '-$resultado';
    }
    
    return resultado;
  }
  
  // 1️⃣ Card remodelado com produtos organizados - NOVO ESTILO COM CLIENTE/DESCRIÇÃO
  Widget _buildResumoCompacto() {
    final placasFormatadas = _formatarPlacas(widget.ordem['placas']);
    final produtosAgrupados = _agruparProdutosParaCarregar();
    final totalProdutos = produtosAgrupados.values.fold(0.0, (sum, qtd) => sum + qtd);
    
    // ✅ Obter tipo de operação para determinar se é transferência
    final tipoOp = widget.ordem['tipo_op']?.toString() ?? 'venda';
    
    // ✅ Obter informações de clientes/descrições para cada produto
    final Map<String, List<String>> informacoesPorProduto = {};
    
    for (var mov in _movimentacoes) {
      final produto = mov['produtos'] as Map<String, dynamic>?;
      if (produto == null) continue;
      
      final nomeProduto = produto['nome_dois']?.toString();
      if (nomeProduto == null || nomeProduto.isEmpty) continue;
      
      if (!informacoesPorProduto.containsKey(nomeProduto)) {
        informacoesPorProduto[nomeProduto] = [];
      }
      
      // ✅ Para transferências, usar descrição (se disponível) em vez de cliente
      String informacao;
      if (tipoOp == 'transf') {
        // Tentar buscar descrição
        informacao = (mov['descricao'] as String?)?.trim() ?? '';
        if (informacao.isEmpty) {
          // Fallback para cliente se descrição não existir
          informacao = (mov['cliente'] as String?)?.trim() ?? '';
        }
      } else if (tipoOp == 'consumo') {
        informacao = 'Consumo Próprio';
      } else {
        // Para outros tipos, usar cliente
        informacao = (mov['cliente'] as String?)?.trim() ?? '';
      }
      
      if (informacao.isNotEmpty && !informacoesPorProduto[nomeProduto]!.contains(informacao)) {
        informacoesPorProduto[nomeProduto]!.add(informacao);
      }
    }

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Linha 1: Ordem, Placa e Tipo de Operação (alinhado à direita)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Ordem e Placa lado a lado
                Expanded(
                  child: Row(
                    children: [
                      // Ordem
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.confirmation_number,
                                  size: 14,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Ordem nº',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _numeroControleOrdem ?? '--',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0D47A1),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Separador
                      Container(
                        width: 1,
                        height: 40,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        color: Colors.grey.shade300,
                      ),
                      
                      // Placa
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.directions_car,
                                  size: 14,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Placas',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              placasFormatadas,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0D47A1),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Tipo de operação alinhado à direita
                if (_tipoMovimentacao == TipoMovimentacao.carregamento || 
                    _tipoMovimentacao == TipoMovimentacao.descarregamento)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _tipoMovimentacao == TipoMovimentacao.carregamento
                          ? Colors.orange.shade50
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _tipoMovimentacao == TipoMovimentacao.carregamento
                            ? Colors.orange.shade200
                            : Colors.green.shade200,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _tipoMovimentacao == TipoMovimentacao.carregamento
                              ? Icons.upload
                              : Icons.download,
                          size: 12,
                          color: _tipoMovimentacao == TipoMovimentacao.carregamento
                              ? Colors.orange.shade700
                              : Colors.green.shade700,
                        ),
                        SizedBox(width: 4),
                        Text(
                          _tipoMovimentacao == TipoMovimentacao.carregamento
                              ? 'Carga'
                              : 'Descarga',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _tipoMovimentacao == TipoMovimentacao.carregamento
                                ? Colors.orange.shade700
                                : Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Linha 2: Carga Total
            Row(
              children: [
                Icon(
                  _tipoMovimentacao == TipoMovimentacao.carregamento
                      ? Icons.local_shipping
                      : Icons.local_shipping_outlined,
                  size: 16,
                  color: Colors.grey.shade700,
                ),
                const SizedBox(width: 6),
                Text(
                  _tipoMovimentacao == TipoMovimentacao.carregamento
                      ? 'Carga'
                      : 'Descarga',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatarNumero(totalProdutos),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0D47A1),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: produtosAgrupados.isNotEmpty
                      ? Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: produtosAgrupados.entries.map((produtoEntry) {
                            final nomeProduto = produtoEntry.key;
                            final quantidade = produtoEntry.value;
                            final cor = _obterCorProduto(nomeProduto);

                            final informacoesDoProduto = informacoesPorProduto[nomeProduto] ?? [];
                            final textoInfo = informacoesDoProduto.isNotEmpty
                                ? informacoesDoProduto.first
                                : (tipoOp == 'transf' ? 'Sem descrição' : 'N/I');
                            final temMaisInfo = informacoesDoProduto.length > 1;

                            return Container(
                              constraints: BoxConstraints(maxWidth: 180),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: cor,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(4),
                                        bottomLeft: Radius.circular(4),
                                      ),
                                    ),
                                    child: Text(
                                      _formatarNumero(quantidade),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: cor.withOpacity(0.08),
                                      borderRadius: const BorderRadius.only(
                                        topRight: Radius.circular(4),
                                        bottomRight: Radius.circular(4),
                                      ),
                                      border: Border.all(
                                        color: cor.withOpacity(0.15),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _abreviarTexto(nomeProduto, 15),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: cor,
                                          ),
                                        ),
                                        Text(
                                          _abreviarTexto(textoInfo, 20),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade700,
                                            fontStyle: FontStyle.italic,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (temMaisInfo)
                                          Text(
                                            '+${informacoesDoProduto.length - 1}',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 0.8,
                            ),
                          ),
                          child: const Text(
                            'Sem produtos',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  tooltip: 'Ações da etapa',
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    Icons.settings,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  onSelected: (value) {
                    if (value == 'reverter') {
                      _reverterEtapaAtual();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem<String>(
                      value: 'reverter',
                      enabled: _podeReverterEtapa,
                      child: const Text('Reverter etapa'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Adicione este método auxiliar à classe _DetalhesOrdemViewState
  String _abreviarTexto(String texto, int maxLength) {
    if (texto.length <= maxLength) return texto;
    return '${texto.substring(0, maxLength)}...';
  }

  Color _obterCorProduto(String produtoNome) {
    final Map<String, Color> mapeamentoExato = {
      'G. Comum': Color(0xFFFF6B35),
      'G. Aditivada': Color(0xFF00A8E8),
      'Gasolina A': Color(0xFFE91E63),
      'S500': Color(0xFF8D6A9F),
      'S10': Color(0xFF2E294E),
      'S500 A': Color(0xFF9C27B0),
      'S10 A': Color(0xFF673AB7),
      'Hidratado': Color(0xFF83B692),
      'Anidro': Color(0xFF4CAF50),
      'B100': Color(0xFF8BC34A),
    };
    
    if (mapeamentoExato.containsKey(produtoNome)) {
      return mapeamentoExato[produtoNome]!;
    }
    
    final nomeLower = produtoNome.toLowerCase();
    for (var entry in mapeamentoExato.entries) {
      if (entry.key.toLowerCase() == nomeLower) {
        return entry.value;
      }
    }
    
    return _coresProdutos['desconhecido']!;
  }

  Widget _buildTimeline() {
    final etapasAtivas = _etapasAtivas;
    int etapaIndex = etapasAtivas.indexWhere((e) => e.etapa == _etapaAtual);
    if (etapaIndex < 0) etapaIndex = 0;

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título centralizado
            Center(
              child: Text(
                'Status da Ordem',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0D47A1),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Container principal para timeline - CENTRALIZADO
            Center(
              child: Column(
                children: [
                  // Container para linha e ícones
                  SizedBox(
                    height: 80, // Aumentado de 60 para 80
                    child: Stack(
                      children: [
                        Positioned(
                          left: 15,
                          right: 15,
                          top: 29, // Ajustado de 19 para 29
                          child: Container(
                            height: 2,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(etapasAtivas.length, (index) {
                            final etapa = etapasAtivas[index];
                            final isCompleta = index <= etapaIndex;
                            final isAtual = index == etapaIndex;
                            final isProgramado = etapa.etapa == EtapaCircuito.programado;
                            final isAguardando = etapa.etapa == EtapaCircuito.aguardando;
                            final isChecklist = etapa.etapa == EtapaCircuito.checkList;
                            final isEmissaoNF = etapa.etapa == EtapaCircuito.emissaoNF;
                            
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // ÍCONE
                                Container(
                                  height: 40, // Container fixo para o ícone
                                  child: _buildEtapaIconComHover(
                                    etapa: etapa,
                                    index: index,
                                    isCompleta: isCompleta,
                                    isAtual: isAtual,
                                    isProgramado: isProgramado,
                                    isAguardando: isAguardando,
                                    isChecklist: isChecklist,
                                    isEmissaoNF: isEmissaoNF,
                                  ),
                                ),
                                
                                const SizedBox(height: 4), // Reduzido de 8 para 4
                                
                                // LABEL - AGORA VINCULADO AO ÍCONE
                                Container(
                                  width: 70, // Aumentado de 65 para 70
                                  child: Text(
                                    etapa.label,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: isAtual ? FontWeight.bold : FontWeight.w500,
                                      color: isCompleta || isAtual ? etapa.cor : Colors.grey.shade600,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // ESPAÇO EXTRA ABAIXO DA TIMELINE
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
  
  // ✅ MÉTODO MODIFICADO: Widget para etapa com hover e click
  Widget _buildEtapaIconComHover({
    required _EtapaInfo etapa,
    required int index,
    required bool isCompleta,
    required bool isAtual,
    required bool isProgramado,
    required bool isAguardando,
    required bool isChecklist,
    required bool isEmissaoNF,
  }) {
    bool podeClicar = false;
    String tooltip = '';

    if (isProgramado && isAtual) {
      podeClicar = true;
      tooltip = 'Confirmar veículo presente e avançar para aguardando';
    } else if (isAguardando && isAtual) {
      podeClicar = true;
      tooltip = 'Avançar para check-list';
    } else if (isChecklist && isAtual) {
      podeClicar = true;
      tooltip = 'Iniciar check-list de segurança';
    } else if (etapa.etapa == EtapaCircuito.operacao && isCompleta) {
      podeClicar = true;
      tooltip = 'Abrir certificado de apuração';
    } else if (isEmissaoNF && isAtual) {
      final tipoOp = widget.ordem['tipo_op']?.toString().toLowerCase() ?? '';
      final isVenda = (_tipoMovimentacao == TipoMovimentacao.carregamento && tipoOp == 'venda');
      
      if (isVenda) {
        podeClicar = true;
        tooltip = 'Finalizar emissão NF e iniciar operação';
      } else if (_tipoMovimentacao == TipoMovimentacao.carregamento) {
        podeClicar = true;
        tooltip = 'Finalizar emissão NF';
      }
    }

    final Widget iconCore = Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCompleta ? etapa.cor : Colors.grey.shade300,
        border: Border.all(
          color: podeClicar ? etapa.cor.withOpacity(0.3) : Colors.transparent,
          width: podeClicar ? 2 : 0,
        ),
        boxShadow: podeClicar
            ? [
                BoxShadow(
                  color: etapa.cor.withOpacity(0.2),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Center(
        child: Icon(
          etapa.icon,
          color: Colors.white,
          size: 16,
        ),
      ),
    );

    return SizedBox(
      width: 50,
      height: 50,
      child: Center(
        child: Container(
          width: 36,
          height: 36,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: podeClicar
                  ? () {
                      if (isProgramado) {
                        _mostrarDialogProgramadoParaAguardando();
                      } else if (isAguardando) {
                        _mostrarDialogAguardandoParaChecklist();
                      } else if (isChecklist) {
                        _abrirDialogoChecklist();
                      } else if (etapa.etapa == EtapaCircuito.operacao) {
                        _abrirCertificadoApuracao();
                      } else if (isEmissaoNF) {
                        final tipoOp = widget.ordem['tipo_op']?.toString().toLowerCase() ?? '';
                        final isVenda = (_tipoMovimentacao == TipoMovimentacao.carregamento && tipoOp == 'venda');
                        
                        if (isVenda) {
                          _finalizarEmissaoNF();  // Venda: avança para operação
                        } else if (_tipoMovimentacao == TipoMovimentacao.carregamento) {
                          _finalizarCargaExpedicao();  // Transferência: avança para liberação
                        }
                      } else if (etapa.etapa == EtapaCircuito.liberacao) {
                        // Nenhuma ação na liberação
                      }
                    }
                  : null,
              customBorder: const CircleBorder(),
              splashColor: podeClicar ? etapa.cor.withOpacity(0.3) : null,
              highlightColor: podeClicar ? etapa.cor.withOpacity(0.1) : null,
              hoverColor: podeClicar ? etapa.cor.withOpacity(0.05) : null,
              child: Tooltip(
                message: tooltip,
                child: isAtual
                    ? ScaleTransition(
                        scale: _pulseAnimation,
                        child: iconCore,
                      )
                    : iconCore,
              ),
            ),
          ),
        ),
      ),
    );
  }
  

  // 2️⃣ Lista compacta de fatos ocorridos
  Widget _buildHistoricoFatos() {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Histórico',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0D47A1),
                  ),
                ),
                Icon(
                  _tipoMovimentacao == TipoMovimentacao.carregamento
                      ? Icons.history
                      : Icons.history_toggle_off,
                  size: 16,
                  color: Colors.grey.shade500,
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._historicoFatos.map((fato) => _buildItemHistoricoCompacto(fato)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildItemHistoricoCompacto(Map<String, String> fato) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 60,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fato['data']!,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  fato['hora']!,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                fato['descricao']!,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color.fromARGB(255, 65, 65, 65),
                  height: 1.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1️⃣ Card remodelado com produtos
          _buildResumoCompacto(),
          
          // 2️⃣ Timeline compacta
          _buildTimeline(),
          
          // 3️⃣ Histórico compacto
          _buildHistoricoFatos(),
          
          // Estados de carregamento/erro
          if (_carregando)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
            ),
          
          if (_erro && !_carregando)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 30,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Erro ao carregar',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _mensagemErro,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }  
}

class _EtapaInfo {
  final EtapaCircuito etapa;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color cor;
  final int statusCodigo;

  const _EtapaInfo({
    required this.etapa,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.cor,
    required this.statusCodigo,
  });
}