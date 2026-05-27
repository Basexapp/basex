import 'package:flutter/material.dart';
import 'dart:js_interop';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'sessoes/operacao/tabelas_de_conversao/tabelasdeconversao.dart';
import 'configuracoes/controle_acesso_usuarios.dart';
import 'login_page.dart';
import 'configuracoes/usuarios.dart';
import 'perfil.dart';
import 'sessoes/operacao/cacl.dart';
import 'sessoes/gestao_de_frota/controle_documentos.dart';
import 'sessoes/operacao/medicoes_emitir_cacl.dart';
import 'sessoes/operacao/tanques.dart';
import 'sessoes/operacao/escolher_terminal.dart';
import 'sessoes/vendas/programacao.dart';
import 'sessoes/estoques/estoque_geral.dart';
import 'sessoes/operacao/estoque_tanques_geral.dart';
import 'sessoes/operacao/historico_cacl.dart';
import 'sessoes/operacao/listar_cacls.dart';
import 'sessoes/estoques/estoque_downloads.dart';
import 'sessoes/relatorios/relatorios_downloads.dart';
import 'sessoes/estoques/filtro_contabil_fisico.dart';
import 'sessoes/estoques/filtro_vendas.dart';
import 'sessoes/estoques/contabil_fisico.dart';
import 'sessoes/estoques/compacto_final.dart';
import 'sessoes/gestao_de_frota/motoristas_page.dart';
import 'sessoes/gestao_de_frota/veiculos.dart';
import 'sessoes/gestao_de_frota/transportadoras.dart';
import 'sessoes/circuito/acompanhamento_ordens.dart';
import 'sessoes/estoques/transferencias.dart';
import 'sessoes/operacao/ordens_analises.dart';
import 'sessoes/laboratorio/temp_dens_media.dart';
import 'sessoes/suporte/desenvolvedor.dart';
import 'sessoes/suporte/suporte.dart';
import 'sessoes/suporte/fila_solic.dart';
import 'sessoes/suporte/acesso_desenvolvedor.dart';
import 'sessoes/circuito/criar_ordem.dart';
import 'sessoes/circuito/radar.dart';
import 'sessoes/circuito/visao_geral.dart';
import 'sessoes/almoxerifado/frascos_amostras.dart';
import 'sessoes/almoxerifado/filtro_estoque_frascos.dart';
import 'sessoes/operacao/estoque_produto.dart';
import 'sessoes/operacao/filtro_estoque_produto.dart';
import 'sessoes/operacao/gestao_bombeios.dart';
import 'sessoes/operacao/resultados.dart';
import 'sessoes/estoques/controle_descargas.dart';
import 'sessoes/bombeios/ordem_bombeio.dart';
import 'sessoes/financeiro/conta_corrente_refinarias.dart';
import 'sessoes/operacao/presets.dart';
import 'sessoes/operacao/calculadora_arqueacao.dart';
import 'sessoes/operacao/controle_aditivo.dart';
import 'sessoes/operacao/filtro_controle_aditivo.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

@JS()
external JSFunction? atualizarApp;

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  int selectedIndex = 0;
  int _hoveredMenuIndex = -1;
  bool _menuExpanded = true;
  TextEditingController searchController = TextEditingController();

  final List<String> menuItems = [
    'Início',
    'Estoques',
    'Operação',
    'Circuito',
    'Vendas',
    'Gestão de Frota',
    'Suprimentos',
    'Laboratório',
    'Financeiro',
    'Jurídico',
    'Gestão de contratos',
    'Gestão de Projetos',
    'Recursos Humanos',
    'Almoxerifado',
    'Manutenção e ativos',
    'Segurança & Compliance',
    'Relatórios',
    'Configurações',
    'Suporte',
  ];

  // FLAGS GERAIS
  bool showConversaoList = false;
  bool showControleAcesso = false;
  bool showConfigList = false;
  bool carregandoSessoes = false;
  bool showUsuarios = false;
  bool _mostrarAcompanhamentoOrdens = false;
  bool _mostrarSuporte = false;
  bool _mostrarFrascosAmostra = false;
  bool _mostrarResultadoFrascos = false;
  // Parâmetros de filtro para a página de resultado de frascos
  DateTime _frascosDataInicial = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _frascosDataFinal = DateTime.now();
  String _frascosTipoRelatorio = 'sintetico';

  // FLAGS PARA SESSÕES ESPECÍFICAS
  bool _mostrarCalcGerado = false;
  bool _mostrarDownloads = false;
  bool _mostrarMedicaoTanques = false;
  bool _mostrarTanques = false;
  bool _mostrarOrdensAnalise = false;
  bool _mostrarHistorico = false;
  bool _mostrarListarCacls = false;
  bool _mostrarFiltrosEstoque = false;
  bool _mostrarFiltroMovimentacoes = false;
  bool _mostrarEscolherTerminal = false;
  bool _mostrarEstoquePorEmpresa = false;
  bool _mostrarFiliaisDaEmpresa = false;
  bool _mostrarEstoquePorTanque = false;
  bool _mostrarFilaSolicitacoes = false;
  bool _mostrarAcessoDesenvolvedor = false;
  bool _mostrarTempDensMedia = false;
  bool _mostrarEstoqueProduto = false;
  bool _mostrarGestaoBombeios = false;
  bool _mostrarResultadoMensal = false;
  bool _mostrarRegistroPreset = false;
  bool _mostrarCalculadoraArqueacao = false;
  bool _mostrarControleAditivo = false;
  bool _mostrarFiltroControleAditivo = false;
  bool _mostrarCardsFilial = false;

  // Parâmetros de filtro para aditivos
  String? _aditivoTerminalId;
  String? _aditivoEmpresaId;
  String _aditivoNomeTerminal = '';
  String? _aditivoEmpresaNome;
  DateTime? _aditivoDataInicial;
  DateTime? _aditivoDataFinal;
  String? _aditivoTipoRelatorio;
  bool _mostrarContaCorrenteRefinarias = false;
  bool _voltarParaTanquesApoCACL = false; // ← RASTREIA SE VEIO DE TANQUES
  bool _estoquePorTanqueVemDaApuracao =
      false; // ← RASTREIA ORIGEM DO ESTOQUE POR TANQUE

  // NOVAS VARIÁVEIS PARA GESTÃO DE FROTA
  bool _mostrarVeiculos = false;
  int _abaInicialVeiculos = 0;
  bool _mostrarDetalhesVeiculo = false;
  Map<String, dynamic>? _veiculoSelecionado;
  bool _mostrarMotoristas = false;
  bool _mostrarTransportadoras = false;

  // FLAG UNIFICADA PARA MOSTRAR FILHOS DE QUALQUER SESSÃO
  bool _mostrarFilhosSessao = false;
  String? _sessaoAtual;
  List<Map<String, dynamic>> _filhosSessaoAtual = [];
  // Tipo do card filho selecionado (navegação por estado)
  String? _filhoSelecionadoTipo;

  // DADOS PARA NAVEGAÇÃO
  String? _filialSelecionadaNome;
  String? _usuarioFilialNome;
  String? _usuarioTerminalNome;
  Map<String, dynamic>? _dadosCalcGerado;
  String? _filialSelecionadaId;
  String? _terminalSelecionadoId;
  String _contextoEscolhaTerminal = '';
  String? _filialParaFiltroId;
  String? _filialParaFiltroNome;
  String? _empresaParaFiltroId;
  String? _empresaParaFiltroNome;
  String? _terminalParaFiltroId;
  String? _terminalParaFiltroNome;

  // LISTAS DE DADOS
  List<Map<String, dynamic>> sessoes = [];
  List<Map<String, dynamic>> empresas = [];
  List<Map<String, dynamic>> filiaisDaEmpresa = [];

  // FLAGS DE CARREGAMENTO
  bool carregandoEmpresas = false;
  bool carregandoFiliaisEmpresa = false;
  bool _carregandoCards = false;
  String? _empresaSelecionadaNome;
  String? _empresaSelecionadaId;

  // MAPA UNIFICADO DE FILHOS POR SESSÃO
  final Map<String, List<Map<String, dynamic>>> _filhosPorSessao = {};

  // NOVA LISTA PARA ARMAZENAR FILIAIS PARA PROGRAMACAO
  List<Map<String, dynamic>> _filiaisProgramacao = [];

  // Mapa nome normalizado -> UUID real do banco (para match de cards de filiais)
  Map<String, String> _idPorNome = {};
  Set<String> _favoritosIds = {};
  Map<String, int> _ordemPorId = {};

  // NOVO: Mapa de cores por sessão
  final Map<String, Color> _coresSessoes = {
    'Estoques': const Color(0xFFFF9800), // Laranja
    'Operação': const Color(0xFF2196F3), // Azul
    'Circuito': const Color(0xFF9C27B0), // Roxo
    'Vendas': const Color(0xFF4CAF50), // Verde
    'Gestão de Frota': const Color(0xFFF44336), // Vermelho
    'Suprimentos': const Color(0xFF00BCD4), // Ciano
    'Laboratório': const Color(0xFF8BC34A), // Verde claro
    'Financeiro': const Color(0xFF009688), // Verde-água
    'Jurídico': const Color(0xFF3F51B5), // Índigo
    'Gestão de contratos': const Color(0xFF3949AB), // Azul escuro (perto do Jurídico)
    'Gestão de Projetos': const Color(0xFFFF5722), // Laranja profundo
    'Recursos Humanos': const Color(0xFFE91E63), // Rosa
    'Almoxerifado': const Color(0xFF9E9E9E), // Cinza
    'Manutenção e ativos': const Color(0xFF455A64), // Cinza azulado
    'Segurança & Compliance': const Color(0xFFD32F2F), // Vermelho escuro
    'Relatórios': const Color(0xFF795548), // Marrom
    'Configurações': const Color(0xFF607D8B), // Azul cinza
    'Suporte': const Color(0xFF673AB7), // Roxo profundo
    'Perdas e Sobras': const Color(0xFF2196F3), // Azul (mesma da Operação)
  };

  @override
  void initState() {
    super.initState();
    selectedIndex = -1;
    _inicializarFilhosPorSessaoFallback();
    _carregarFilialParaProgramacao();
    _carregarCardsDoBanco();
    _carregarNomeFilialUsuario();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args['openSessao'] == 'Operação') {
        setState(() {
          selectedIndex = menuItems.indexOf('Operação');
        });
        _mostrarFilhosDaSessao('Operação');
      }
    });
  }

  Future<void> _carregarNomeFilialUsuario() async {
    try {
      final usuario = UsuarioAtual.instance;
      if (usuario == null) return;

      final supabase = Supabase.instance.client;

      // Nível 1 ou 2: exibir o nome do terminal vinculado ao usuário
      if (usuario.nivel == 1 || usuario.nivel == 2) {
        final terminalId = usuario.terminalId;
        if (terminalId == null || terminalId.isEmpty) {
          setState(() {
            _usuarioTerminalNome = 'Sem terminal';
            _usuarioFilialNome = null;
          });
          return;
        }

        try {
          final terminalData = await supabase
              .from('terminais')
              .select('nome')
              .eq('id', terminalId)
              .maybeSingle();

          if (!mounted) return;

          setState(() {
            _usuarioTerminalNome =
                terminalData?['nome']?.toString() ?? 'Sem terminal';
            _usuarioFilialNome = null;
          });
        } catch (e) {
          debugPrint('Erro ao carregar nome do terminal do usuário: $e');
          if (!mounted) return;
          setState(() {
            _usuarioTerminalNome = 'Sem terminal';
            _usuarioFilialNome = null;
          });
        }
        return;
      }

      // Nível 3: não exibe terminal nem filial no cabeçalho
      if (usuario.nivel == 3) {
        setState(() {
          _usuarioFilialNome = null;
          _usuarioTerminalNome = null;
        });
        return;
      }

      // Demais níveis: exibir nome da filial
      final filialId = usuario.filialId;
      if (filialId == null || filialId.isEmpty) {
        setState(() {
          _usuarioFilialNome = null;
          _usuarioTerminalNome = null;
        });
        return;
      }

      final filialData = await supabase
          .from('filiais')
          .select('nome')
          .eq('id', filialId)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        _usuarioFilialNome = filialData?['nome']?.toString();
        _usuarioTerminalNome = null;
      });
    } catch (e) {
      debugPrint('Erro ao carregar nome da filial/terminal do usuário: $e');
      if (!mounted) return;
      setState(() {
        _usuarioFilialNome = null;
        _usuarioTerminalNome = null;
      });
    }
  }

  // NOVO: Método para obter cor da sessão atual
  Color _getCorSessaoAtual() {
    return _coresSessoes[_sessaoAtual ?? ''] ?? const Color(0xFF2E7D32);
  }

  // NOVO: Método para obter cor da sessão por nome
  Color _getCorPorSessao(String sessao) {
    return _coresSessoes[sessao] ?? const Color(0xFF2E7D32);
  }  

  void _navegarParaFavorito(Map<String, dynamic> card) {
    final usuario = UsuarioAtual.instance;
    final cardId = card['id']?.toString();

    // Verificação de segurança: se o usuário não tiver permissão, bloqueia a navegação
    if (usuario != null && cardId != null && !usuario.podeAcessarCard(cardId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você não tem permissão para acessar este recurso.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final sessaoPai = card['sessao_pai']?.toString() ?? '';
    final menuIndex = menuItems.indexOf(sessaoPai);
    final filhos = _filhosPorSessao[sessaoPai] ?? [];

    setState(() {
      selectedIndex = menuIndex >= 0 ? menuIndex : 0;
      _sessaoAtual = sessaoPai;
      _mostrarFilhosSessao = true;
      _filhosSessaoAtual = List.from(filhos);
      _filhoSelecionadoTipo = null;
      // Limpa todos os flags de conteúdo
      _mostrarTanques = false;
      _mostrarListarCacls = false;
      showConversaoList = false;
      _mostrarOrdensAnalise = false;
      _mostrarHistorico = false;
      _mostrarEscolherTerminal = false;
      _mostrarEstoquePorTanque = false;
      _mostrarTempDensMedia = false;
      _mostrarVeiculos = false;
      _mostrarDetalhesVeiculo = false;
      _veiculoSelecionado = null;
      _mostrarMotoristas = false;
      _mostrarTransportadoras = false;
      _mostrarFrascosAmostra = false;
      _mostrarEstoqueProduto = false;
      _mostrarFiltrosEstoque = false;
      _mostrarFiltroMovimentacoes = false;
      _mostrarAcompanhamentoOrdens = false;
      _mostrarDownloads = false;
      _mostrarEstoquePorEmpresa = false;
      _mostrarFiliaisDaEmpresa = false;
      _mostrarMedicaoTanques = false;
      _mostrarCardsFilial = false;
      _mostrarContaCorrenteRefinarias = false;
    });

    _navegarParaCardFilho(card);
  }

  Future<void> _carregarCardsDoBanco() async {
    final usuario = UsuarioAtual.instance;
    if (usuario == null) return;

    setState(() => _carregandoCards = true);

    try {
      final supabase = Supabase.instance.client;

      // Buscar id, nome e ordem
      final cardsDb = await supabase
          .from('cards')
          .select('id, nome, ordem')
          .eq('ativo', true);

      // Buscar IDs dos cards favoritados pelo usuário atual
      final favoritosDb = await supabase
          .from('relacoes_cards_favoritos')
          .select('card_id')
          .eq('usuario_id', usuario.id)
          .eq('acesso', true);

      if (!mounted) return;

      final favoritosIds = <String>{
        for (final f in favoritosDb) f['card_id'].toString()
      };

      // Mapear nome normalizado -> id real (UUID) para fazer correspondência por label
      final idPorNome = <String, String>{
        for (final c in cardsDb)
          (c['nome']?.toString().trim().toLowerCase() ?? ''): c['id'].toString(),
      };

      // Mapear id -> ordem
      final ordemPorId = <String, int>{
        for (final c in cardsDb)
          c['id'].toString(): (c['ordem'] as int? ?? 0),
      };

      // Armazenar para uso em _carregarFilialParaProgramacao (que pode rodar depois)
      _idPorNome = idPorNome;
      _favoritosIds = favoritosIds;
      _ordemPorId = ordemPorId;

      // Para cada card do fallback: encontrar o UUID real pelo nome e atualizar id/favorito/label
      for (final cards in _filhosPorSessao.values) {
        for (final card in cards) {
          final labelNorm = card['label']?.toString().trim().toLowerCase() ?? '';
          final realId = idPorNome[labelNorm];
          if (realId != null && realId.isNotEmpty) {
            card['id'] = realId;
          }
          final currentId = card['id']?.toString() ?? '';
          card['favorito'] = favoritosIds.contains(currentId);
          if (ordemPorId.containsKey(currentId)) {
            card['ordem'] = ordemPorId[currentId];
          }
        }
        // Ordenar do menor para o maior
        cards.sort((a, b) =>
            ((a['ordem'] as int?) ?? 0).compareTo((b['ordem'] as int?) ?? 0));
      }

      // Também atualizar _filiaisProgramacao caso já esteja carregado
      _aplicarIdsDoBancoEmFiliais();

      setState(() {
        _carregandoCards = false;
      });
    } catch (e) {
      debugPrint('❌ Erro ao carregar cards do banco: $e');
      setState(() => _carregandoCards = false);
    }
  }

  /// Atualiza os IDs e favoritos dos cards de _filiaisProgramacao usando o mapa do banco.
  void _aplicarIdsDoBancoEmFiliais() {
    if (_idPorNome.isEmpty) return;
    for (final card in _filiaisProgramacao) {
      final labelNorm = card['label']?.toString().trim().toLowerCase() ?? '';
      final realId = _idPorNome[labelNorm];
      if (realId != null && realId.isNotEmpty) {
        card['id'] = realId;
      }
      final currentId = card['id']?.toString() ?? '';
      card['favorito'] = _favoritosIds.contains(currentId);
      if (_ordemPorId.containsKey(currentId)) {
        card['ordem'] = _ordemPorId[currentId];
      }
    }
    _filiaisProgramacao.sort((a, b) =>
        ((a['ordem'] as int?) ?? 0).compareTo((b['ordem'] as int?) ?? 0));
  }

  void _inicializarFilhosPorSessaoFallback() {
    _filhosPorSessao['Operação'] = [
      {
        'id': 'fallback-ordens',
        'icon': Icons.assignment,
        'label': 'Ordens / Análises',
        'descricao': 'Geração e gestão de ordens',
        'tipo': 'ordens_analise',
        'sessao_pai': 'Operação',
      },
      {
        'id': 'fallback-historico',
        'icon': Icons.history,
        'label': 'Histórico de CACLs',
        'descricao': 'Consultar histórico de CACLs emitidos',
        'tipo': 'historico_cacl',
        'sessao_pai': 'Operação',
      },
      {
        'id': 'fallback-tabelas',
        'icon': Icons.table_chart,
        'label': 'Tabelas de Conversão',
        'descricao': 'Tabelas de conversão de densidade e temperatura',
        'tipo': 'tabelas_conversao',
        'sessao_pai': 'Operação',
      },
      {
        'id': 'fallback-tanques',
        'icon': Icons.oil_barrel,
        'label': 'Gerenciamento de Tanques',
        'descricao': 'Gerenciamento de tanques',
        'tipo': 'tanques',
        'sessao_pai': 'Operação',
      },
      {
        'id': 'fallback-estoque-tanque',
        'icon': Icons.water_drop,
        'label': 'Estoque por tanque',
        'descricao': 'Acompanhar estoques por tanque',
        'tipo': 'estoque_por_tanque',
        'sessao_pai': 'Operação',
      },
      {
        'id': 'fallback-perdas-sobras',
        'icon': Icons.insights,
        'label': 'Gestão de perdas e sobras',
        'descricao': 'Controle de perdas e sobras operacionais',
        'tipo': 'perdas_sobras',
        'sessao_pai': 'Operação',
      },
      {
        'id': 'c44f87b1-ab75-4b5f-bacc-f29eefe1a75f',
        'icon': Icons.opacity,
        'label': 'Estoque por produto',
        'descricao': 'Consultar movimentação e estoque por produto',
        'tipo': 'estoque_produto',
        'sessao_pai': 'Operação',
        'favorito': false,
      },
      {
        'id': '7b2fab05-4ce9-4a1e-b1e6-96b3527565d8',
        'icon': Icons.bar_chart,
        'label': 'Resultados',
        'descricao': 'Acompanhamento de resultados operacionais',
        'tipo': 'resultados',
        'sessao_pai': 'Operação',
        'favorito': false,
      },
      {
        'id': 'registro-preset',
        'icon': Icons.device_hub,
        'label': 'Presets',
        'descricao': 'Gerenciamento de registros de preset',
        'tipo': 'registro_preset',
        'sessao_pai': 'Operação',
        'icon_inverted': true,
      },
      {
        'id': '0bc9a8ec-40a0-41c1-a44a-405c64c233a5',
        'icon': Icons.data_saver_off,
        'label': 'Gestão de Bombeios',
        'descricao': 'Controle e acompanhamento de bombeios',
        'tipo': '0bc9a8ec-40a0-41c1-a44a-405c64c233a5',
        'sessao_pai': 'Operação',
        'favorito': false,
      },
      {
        'id': '1ea5e5b8-498b-489b-b02a-b0a3f0aa7c87',
        'icon': Icons.calculate_outlined,
        'label': 'Calculadora de Arqueação',
        'descricao': 'Cálculo de arqueação de tanques e embarcações',
        'tipo': 'calculadora_arqueacao',
        'sessao_pai': 'Operação',
        'favorito': false,
      },
      {
        'id': 'ebd85bc2-3334-4078-a22a-3458fbdad8f1',
        'icon': Icons.style,
        'label': 'Controle de Aditivos',
        'descricao': 'Gestão e monitoramento de aditivos',
        'tipo': 'controle_aditivo',
        'sessao_pai': 'Operação',
        'favorito': false,
      },
    ];

    _filhosPorSessao['Perdas e Sobras'] = [
      {
        'id': 'perdas-sobras-dutoviario',
        'icon': Icons.blur_linear,
        'label': 'Dutoviário',
        'descricao': 'Gestão de perdas e sobras dutoviárias',
        'tipo': 'dutoviario',
        'sessao_pai': 'Perdas e Sobras',
      },
      {
        'id': 'perdas-sobras-rodoviario',
        'icon': Icons.local_shipping,
        'label': 'Rodoviário',
        'descricao': 'Gestão de perdas e sobras rodoviárias',
        'tipo': 'rodoviario',
        'sessao_pai': 'Perdas e Sobras',
      },
    ];

    _filhosPorSessao['Estoques'] = [
      {
        'id': 'fallback-geral',
        'icon': Icons.hub,
        'label': 'Estoque Geral',
        'descricao': 'Visão consolidada dos estoques da base',
        'tipo': 'estoque_geral',
        'sessao_pai': 'Estoques',
      },
      {
        'id': 'fallback-compacto-final',
        'icon': Icons.view_compact,
        'label': 'Compacto final',
        'descricao': 'Visão compacta do final do dia',
        'tipo': 'compacto_final',
        'sessao_pai': 'Estoques',
      },
      {
        'id': 'fallback-empresa',
        'icon': Icons.business,
        'label': 'Movimentação por empresa',
        'descricao': 'Movimentações por empresa',
        'tipo': 'movimentacao_por_empresa',
        'sessao_pai': 'Estoques',
      },

      {
        'id': 'fallback-transf',
        'icon': Icons.low_priority,
        'label': 'Transferências',
        'descricao': 'Gerenciar transferências entre filiais',
        'tipo': 'transferencias',
        'sessao_pai': 'Estoques',
      },
      {
        'id': 'fallback-descargas',
        'icon': Icons.swap_horizontal_circle,
        'label': 'Controle de descargas',
        'descricao': 'Controle de recebimento de produtos',
        'tipo': 'controle_descargas',
        'sessao_pai': 'Estoques',
      },
      {
        'id': 'fallback-estoque-fiscal',
        'icon': Icons.receipt_long,
        'label': 'Estoque Contábil x Físico',
        'descricao': 'Acompanhar estoque fiscal e tributário',
        'tipo': 'estoque_fiscal',
        'sessao_pai': 'Estoques',
      },
    ];

    _filhosPorSessao['Circuito'] = [
      {
        'id': 'fallback-acompanhar',
        'icon': Icons.directions_car,
        'label': 'Acompanhar ordem',
        'descricao': 'Acompanhar situação da ordem',
        'tipo': 'acompanhar_ordem',
        'sessao_pai': 'Circuito',
      },
      {
        'id': 'fallback-visao',
        'icon': Icons.dashboard,
        'label': 'Visão geral',
        'descricao': 'Panorama completo dos circuitos',
        'tipo': 'visao_geral_circuito',
        'sessao_pai': 'Circuito',
      },
      {
        'id': 'criar-ordem',
        'icon': Icons.add_circle_outline,
        'label': 'Criar Ordem',
        'descricao': 'Criar uma nova ordem',
        'tipo': 'criar_ordem',
        'sessao_pai': 'Circuito',
      },
      {
        'id': 'c94451c8-2c41-49b1-9181-be3a5f1e7205',
        'icon': Icons.radar,
        'label': 'Radar',
        'descricao': 'Visualização em radar das ordens',
        'tipo': 'radar',
        'sessao_pai': 'Circuito',
      },
    ];

    _filhosPorSessao['Gestão de Frota'] = [
      {
        'id': 'fallback-veiculos',
        'icon': Icons.directions_car,
        'label': 'Veículos',
        'descricao': 'Gerenciar frota de veículos',
        'tipo': 'veiculos',
        'sessao_pai': 'Gestão de Frota',
      },
      {
        'id': 'fallback-transportadoras',
        'icon': Icons.local_shipping,
        'label': 'Transportadoras',
        'descricao': 'Gerenciar transportadoras',
        'tipo': 'transportadoras',
        'sessao_pai': 'Gestão de Frota',
      },
      {
        'id': 'fallback-motoristas',
        'icon': Icons.people,
        'label': 'Motoristas',
        'descricao': 'Gerenciar cadastro de motoristas',
        'tipo': 'motoristas',
        'sessao_pai': 'Gestão de Frota',
      },
      {
        'id': 'fallback-documentacao',
        'icon': Icons.description,
        'label': 'Documentação',
        'descricao': 'Controle de documentos da frota',
        'tipo': 'documentacao',
        'sessao_pai': 'Gestão de Frota',
      },
    ];

    _filhosPorSessao['Vendas'] = [
      {
        'id': 'fallback-mov',
        'icon': Icons.swap_horiz,
        'label': 'Relatório de Saídas',
        'descricao': 'Acompanhar entradas e saídas em geral',
        'tipo': 'movimentacoes',
        'sessao_pai': 'Vendas',
        'favorito': false,
      },
    ];

    _filhosPorSessao['Suprimentos'] = [
      {
        'id': 'fallback-bombeios',
        'icon': Icons.invert_colors,
        'label': 'Bombeios e Cotas Contratuais',
        'descricao': 'Controle de bombeios',
        'tipo': 'bombeios',
        'sessao_pai': 'Suprimentos',
      },
      {
        'id': 'f4b33579-63ee-415e-925e-32540ebb38e5',
        'icon': Icons.price_change,
        'label': 'Tabela de Preços - Refinaria',
        'descricao': 'Tabela de preços da refinaria',
        'tipo': 'tabela_precos_refinaria',
        'sessao_pai': 'Suprimentos',
        'favorito': false,
      },
    ];

    _filhosPorSessao['Almoxerifado'] = [
      {
        'id': 'fallback-frascos-amostra',
        'icon': Icons.science_outlined,
        'label': 'Frascos de amostras',
        'descricao': 'Controle de frascos de amostras',
        'tipo': 'frascos_amostra',
        'sessao_pai': 'Almoxerifado',
      },
    ];

    _filhosPorSessao['Laboratório'] = [
      {
        'id': 'd1b2c3a4-5e6f-7a8b-9c0d-1e2f3a4b5c6d',
        'icon': Icons.thermostat,
        'label': 'Temperatura e Densidade Média',
        'descricao': 'Temperatura e densidade média por produto',
        'tipo': 'temp_dens_media',
        'sessao_pai': 'Laboratório',
        'favorito': false,
      },
      {
        'id': '2b34cdd6-6f80-4588-8ecd-f22cc954920a',
        'icon': Icons.fact_check,
        'label': 'Análise de conformidade e qualidade',
        'descricao': 'Análise de conformidade e qualidade',
        'tipo': 'analise_conformidade',
        'sessao_pai': 'Laboratório',
        'favorito': false,
      },
    ];

    _filhosPorSessao['Financeiro'] = [
      {
        'id': 'conta-corrente-refinarias',
        'icon': Icons.account_balance,
        'label': 'Conta-corrente Refinarias',
        'descricao': 'Movimentação financeira com refinarias',
        'tipo': 'conta_corrente_refinarias',
        'sessao_pai': 'Financeiro',
        'favorito': false,
      },
    ];

    _filhosPorSessao['Gestão de contratos'] = [
      {
        'id': 'fallback-contratos-etanol',
        'icon': Icons.water_drop,
        'label': 'Contratos de Etanol (RANP 946/2023)',
        'descricao': 'Gestão de contratos de etanol conforme RANP 946/2023',
        'tipo': 'contratos_etanol',
        'sessao_pai': 'Gestão de contratos',
      },
      {
        'id': 'fallback-carregamento-rodoviario',
        'icon': Icons.local_shipping,
        'label': 'Carregamento rodoviário (ANP nº 42/2011)',
        'descricao': 'Gestão de contratos de carregamento rodoviário conforme ANP nº 42/2011',
        'tipo': 'carregamento_rodoviario',
        'sessao_pai': 'Gestão de contratos',
      },
      {
        'id': 'fallback-contratos-particulares',
        'icon': Icons.people,
        'label': 'Contratos com particulares',
        'descricao': 'Gestão de contratos firmados com particulares',
        'tipo': 'contratos_particulares',
        'sessao_pai': 'Gestão de contratos',
      },
      {
        'id': 'fallback-contratos-refinarias',
        'icon': Icons.factory,
        'label': 'Contratos com Refinarias',
        'descricao': 'Gestão de contratos firmados com refinarias',
        'tipo': 'contratos_refinarias',
        'sessao_pai': 'Gestão de contratos',
      },
    ];

    _filhosPorSessao['Relatórios'] = [
      {
        'id': 'fallback-downloads',
        'icon': Icons.download,
        'label': 'Downloads',
        'descricao': 'Baixar relatórios e dados',
        'tipo': 'downloads',
        'sessao_pai': 'Relatórios',
      },
    ];

    _filhosPorSessao['Suporte'] = [
      {
        'id': 'suporte-central',
        'icon': Icons.support_agent,
        'label': 'Suporte',
        'descricao': 'Central de suporte',
        'tipo': 'suporte',
        'sessao_pai': 'Suporte',
      },
      {
        'id': 'suporte-desenvolvedor',
        'icon': Icons.architecture,
        'label': 'O Desenvolvedor',
        'descricao': 'Contribuição para o projeto',
        'tipo': 'desenvolvedor',
        'sessao_pai': 'Suporte',
      },
      {
        'id': 'suporte-fila',
        'icon': Icons.receipt_long,
        'label': 'Fila de Solicitações',
        'descricao': 'Acompanhe suas solicitações',
        'tipo': 'fila_solicitacoes',
        'sessao_pai': 'Suporte',
      },
      {
        'id': 'suporte-dev-access',
        'icon': Icons.developer_mode,
        'label': 'Acesso Desenvolvedor',
        'descricao': 'Acesso de desenvolvedor',
        'tipo': 'acesso_desenvolvedor',
        'sessao_pai': 'Suporte',
      },
    ];
  }    

  Future<void> _carregarFilialParaProgramacao() async {
    final supabase = Supabase.instance.client;

    try {
      // Busca todas as filiais — terminal_id_1 é apenas parâmetro, não critério
      final filiaisData = await supabase
          .from('filiais')
          .select('id, nome, nome_dois, terminal_id_1')
          .order('nome');

      if (!mounted) return;

      if (filiaisData.isEmpty) {
        setState(() {
          _filiaisProgramacao = [];
        });
        return;
      }

      final List<Map<String, dynamic>> filiaisProcessadas = [];

      for (var filial in filiaisData) {
        final filialId = filial['id'];
        final filialNome = filial['nome'] ?? 'Sem nome';
        final filialNomeDois = filial['nome_dois'] ?? filialNome;
        final terminalId = filial['terminal_id_1']; // pode ser null

        filiaisProcessadas.add({
          'id': filialId.toString(),
          'label': filialNomeDois,
          'descricao': '',
          'tipo': 'programacao_filial',
          'filial_id': filialId,
          'filial_nome': filialNome,
          'filial_nome_dois': filialNomeDois,
          'terminal_id': terminalId,
          'icon': Icons.local_gas_station,
          'sessao_pai': 'Vendas',
          'favorito': false,
        });
      }

      filiaisProcessadas.sort((a, b) {
        final nomeA = a['label']?.toString() ?? '';
        final nomeB = b['label']?.toString() ?? '';
        return nomeA.compareTo(nomeB);
      });

      setState(() {
        _filiaisProgramacao = filiaisProcessadas;
      });

      // Aplicar UUIDs do banco caso _carregarCardsDoBanco já tenha rodado
      _aplicarIdsDoBancoEmFiliais();
    } catch (e) {
      debugPrint('❌ ERRO ao carregar filiais: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar filiais: ${e.toString()}'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      setState(() {
        _filiaisProgramacao = [];
      });
    }
  }

  Future<void> _carregarEmpresas() async {
    setState(() => carregandoEmpresas = true);
    final supabase = Supabase.instance.client;
    final usuario = UsuarioAtual.instance;
    final nivelUsuario = usuario?.nivel ?? 0;

    try {
      List<Map<String, dynamic>> dados = [];

      if (nivelUsuario == 3) {
        // Nível 3: apenas a empresa do próprio usuário
        final empresaId = usuario?.empresaId ?? '';
        if (empresaId.isNotEmpty) {
          final result = await supabase
              .from('empresas')
              .select('id, nome, nome_abrev, cnpj')
              .eq('id', empresaId)
              .limit(1);

          if (!mounted) return;

          dados = List<Map<String, dynamic>>.from(result);
        }
      } else if (nivelUsuario == 4) {
        // Nível 4: empresas que operam no terminal do usuário
        final terminalId = usuario?.terminalId ?? '';
        debugPrint('🔍 [Nível 4] terminalId=$terminalId');
        if (terminalId.isNotEmpty) {
          final relacoes = await supabase
              .from('relacoes_terminais')
              .select('empresa_id')
              .eq('terminal_id', terminalId);

          if (!mounted) return;

          debugPrint(
              '🔍 [Nível 4] relacoes_terminais retornou ${relacoes.length} registros');

          final empresasIds = relacoes
              .map((r) => r['empresa_id']?.toString())
              .whereType<String>()
              .where((id) => id.isNotEmpty)
              .toSet()
              .toList();

          debugPrint('🔍 [Nível 4] empresasIds=$empresasIds');

          if (empresasIds.isNotEmpty) {
            final result = await supabase
                .from('empresas')
                .select('id, nome, nome_abrev, cnpj')
                .inFilter('id', empresasIds)
                .order('nome');

            if (!mounted) return;

            dados = List<Map<String, dynamic>>.from(result);
          }
        }
      } else {
        // Demais níveis (administradores): todas as empresas
        final result = await supabase
            .from('empresas')
            .select('id, nome, nome_abrev, cnpj')
            .order('nome');

        if (!mounted) return;

        dados = List<Map<String, dynamic>>.from(result);
      }

      setState(() {
        empresas = dados.map((empresa) {
          return {
            'id': empresa['id'],
            'label': empresa['nome_abrev'] ?? empresa['nome'],
            'descricao': empresa['cnpj'] ?? 'Sem CNPJ',
            'icon': Icons.business,
          };
        }).toList();
      });
    } catch (e) {
      debugPrint("❌ Erro ao carregar empresas: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Erro ao carregar empresas."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => carregandoEmpresas = false);
    }
  }

  Future<void> _carregarFiliaisDaEmpresa(String empresaId) async {
    setState(() {
      carregandoFiliaisEmpresa = true;
      filiaisDaEmpresa.clear();
    });

    final supabase = Supabase.instance.client;
    final usuario = UsuarioAtual.instance;

    try {
      dynamic queryResult;

      if (usuario != null && usuario.nivel < 3) {
        List<String> filiaisPermitidas = [];

        if (usuario.filialId != null) {
          filiaisPermitidas.add(usuario.filialId!);
        }

        if (filiaisPermitidas.isEmpty) {
          queryResult = await supabase
              .from('filiais')
              .select('id, nome, cidade, cnpj')
              .eq('empresa_id', empresaId)
              .eq('id', '00000000-0000-0000-0000-000000000000')
              .order('nome');
        } else {
          queryResult = await supabase
              .from('filiais')
              .select('id, nome, cidade, cnpj')
              .eq('empresa_id', empresaId)
              .inFilter('id', filiaisPermitidas)
              .order('nome');
        }
      } else {
        queryResult = await supabase
            .from('filiais')
            .select('id, nome, cidade, cnpj')
            .eq('empresa_id', empresaId)
            .order('nome');
      }

      if (!mounted) return;

      List<Map<String, dynamic>> dados = [];

      if (queryResult is List) {
        for (var item in queryResult) {
          if (item is Map<String, dynamic>) {
            dados.add(item);
          } else {
            final map = Map<String, dynamic>.from(item as Map);
            dados.add(map);
          }
        }
      }

      setState(() {
        filiaisDaEmpresa = dados.map((filial) {
          return {
            'id': filial['id'],
            'label': filial['nome'],
            'descricao': filial['cidade'],
            'cnpj': filial['cnpj'],
            'icon': Icons.store,
          };
        }).toList();
      });
    } catch (e) {
      debugPrint("Erro ao carregar filiais: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erro ao carregar filiais da empresa."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => carregandoFiliaisEmpresa = false);
    }
  }

  void _resetarFlagsVeiculos() {
    setState(() {
      _mostrarVeiculos = false;
      _mostrarDetalhesVeiculo = false;
      _veiculoSelecionado = null;
    });
  }

  void _resetarFlagsMotoristas() {
    setState(() {
      _mostrarMotoristas = false;
    });
  }

  void _resetarFlagsTransportadoras() {
    setState(() {
      _mostrarTransportadoras = false;
    });
  }

  void _resetarTodasFlagsGestaoFrota() {
    _resetarFlagsVeiculos();
    _resetarFlagsMotoristas();
    _resetarFlagsTransportadoras();
    _mostrarAcompanhamentoOrdens = false;
  }

  void _resetarTodasFlags() {
    setState(() {
      selectedIndex = -1;
      showConversaoList = false;
      showControleAcesso = false;
      showConfigList = false;
      showUsuarios = false;
      _mostrarCalcGerado = false;
      _mostrarDownloads = false;
      _mostrarMedicaoTanques = false;
      _mostrarTanques = false;
      _mostrarOrdensAnalise = false;
      _mostrarHistorico = false;
      _mostrarListarCacls = false;
      _mostrarFiltrosEstoque = false;
      _mostrarFiltroMovimentacoes = false;      
      _mostrarFrascosAmostra = false;
      _mostrarResultadoFrascos = false;
      _mostrarEscolherTerminal = false;
      _mostrarEstoquePorEmpresa = false;
      _mostrarFiliaisDaEmpresa = false;
      _mostrarEstoquePorTanque = false;
      _mostrarTempDensMedia = false;
      _mostrarSuporte = false;
      _mostrarFilaSolicitacoes = false; // Resetar Fila de Solicitações
      _mostrarAcessoDesenvolvedor = false;
      _mostrarEstoqueProduto = false;
      _mostrarRegistroPreset = false;
      _mostrarContaCorrenteRefinarias = false;
      _voltarParaTanquesApoCACL = false;
      _mostrarGestaoBombeios = false;
      _mostrarCalculadoraArqueacao = false;
      _resetarTodasFlagsGestaoFrota();
      _mostrarFilhosSessao = false;
      _sessaoAtual = null;
      _filhosSessaoAtual = [];
      _filhoSelecionadoTipo = null;
      _filialSelecionadaNome = null;
      _dadosCalcGerado = null;
      _filialSelecionadaId = null;
      _contextoEscolhaTerminal = '';
      _filialParaFiltroId = null;
      _filialParaFiltroNome = null;
      _terminalParaFiltroId = null; // ← ADICIONAR
      _terminalParaFiltroNome = null; // ← ADICIONAR
      _empresaParaFiltroId = null;
      _empresaParaFiltroNome = null;
      _empresaSelecionadaId = null;
      _empresaSelecionadaNome = null;
    });
  }

  void _mostrarFilhosDaSessao(String nomeSessao) {
    if (nomeSessao == 'Configurações') {
      final usuario = UsuarioAtual.instance;
      final List<Map<String, dynamic>> configItems = [];
      if (usuario != null && usuario.nivel >= 2) {
        configItems.add({
          'id': 'config-controle-acesso',
          'icon': Icons.admin_panel_settings,
          'label': 'Controle de acesso',
          'tipo': 'controle_acesso',
          'sessao_pai': 'Configurações',
        });
      }
      if (usuario != null && usuario.nivel >= 3) {
        configItems.add({
          'id': 'config-usuarios',
          'icon': Icons.people_alt,
          'label': 'Usuários',
          'tipo': 'usuarios',
          'sessao_pai': 'Configurações',
        });
      }
      if (configItems.isEmpty) {
        _mostrarSemPermissao();
        return;
      }
      setState(() {
        _mostrarFilhosSessao = true;
        _sessaoAtual = 'Configurações';
        _filhosSessaoAtual = configItems;
        showControleAcesso = false;
        showUsuarios = false;
      });
      return;
    }

    if (nomeSessao == 'Vendas') {
      // Combinar cards do banco (ou fallback) + filiais de programação
      // Excluir programacao_filial do banco para evitar duplicação com _filiaisProgramacao
      final cardsVendas = <Map<String, dynamic>>[
        ...(_filhosPorSessao['Vendas'] ?? []).where((c) => c['tipo'] != 'programacao_filial'),
        ..._filiaisProgramacao,
      ];

      setState(() {
        _mostrarFilhosSessao = true;
        _sessaoAtual = nomeSessao;
        _filhosSessaoAtual = List.from(cardsVendas);
      });
      return;
    }

    var filhos = _filhosPorSessao[nomeSessao] ?? [];

    if (nomeSessao == 'Gestão de Frota' &&
        !filhos.any((card) => card['tipo'] == 'transportadoras')) {
      filhos = [
        ...filhos,
        {
          'id': 'transportadoras',
          'icon': Icons.local_shipping,
          'label': 'Transportadoras',
          'descricao': 'Gerenciar transportadoras',
          'tipo': 'transportadoras',
          'sessao_pai': 'Gestão de Frota',
          'favorito': false,
        },
      ];
    }

    // Remover temp_dens_media de Operação (disponível apenas em Laboratório)
    if (nomeSessao == 'Operação') {
      filhos = filhos.where((card) => card['tipo'] != 'temp_dens_media').toList();
    }

    // ATUALIZADO: Filtrar cards de Estoques por nível
    if (nomeSessao == 'Estoques') {
      final usuario = UsuarioAtual.instance;
      if (usuario != null) {
        if (usuario.nivel <= 1) {
          // Nível 1: remover cards de empresa (empresa-level)
          filhos = filhos
              .where(
                (card) =>
                    card['tipo'] != 'estoque_por_empresa' &&
                    card['tipo'] != 'movimentacao_por_empresa',
              )
              .toList();
        } else if (usuario.nivel == 2) {
          // Nível 2: remover apenas cards de empresa, manter movimentacoes
          filhos = filhos
              .where(
                (card) =>
                    card['tipo'] != 'estoque_por_empresa' &&
                    card['tipo'] != 'movimentacao_por_empresa',
              )
              .toList();
        } else {
          // Nível 3: manter cards de empresa, remover o card genérico de movimentações
          filhos = filhos
              .where((card) => card['tipo'] != 'movimentacoes')
              .toList();
        }
      }
    }

    if (filhos.isEmpty) {
      _mostrarSemPermissao();
      return;
    }

    setState(() {
      _mostrarFilhosSessao = true;
      _sessaoAtual = nomeSessao;
      _filhosSessaoAtual = List.from(filhos);
      _filhoSelecionadoTipo = null;

      showConversaoList = false;
      _mostrarDownloads = false;
      _mostrarListarCacls = false;
      _mostrarOrdensAnalise = false;
      _mostrarHistorico = false;
      _mostrarEscolherTerminal = false;
      _mostrarMedicaoTanques = false;
      _mostrarTanques = false;
      _mostrarFiliaisDaEmpresa = false;
      _mostrarEstoquePorEmpresa = false;
      _mostrarFiltrosEstoque = false;
      _mostrarFrascosAmostra = false;
      _mostrarResultadoFrascos = false;
      _mostrarCalcGerado = false;
      _mostrarTempDensMedia = false;
      _mostrarSuporte = false;
      _mostrarFilaSolicitacoes = false;
      _mostrarAcessoDesenvolvedor = false;
      _mostrarControleAditivo = false;
      _mostrarFiltroControleAditivo = false;
      _mostrarCardsFilial = false;
      _mostrarVeiculos = false;
      _mostrarDetalhesVeiculo = false;
      _veiculoSelecionado = null;
      _mostrarMotoristas = false;
      _mostrarTransportadoras = false;
    });
  }

  // NOVO: Método para mostrar mensagem de "Sem permissão"
  void _mostrarSemPermissao() {
    setState(() {
      _mostrarFilhosSessao = true;
      _sessaoAtual = null;
      _filhosSessaoAtual = [];
    });
  }

  void _voltarParaCardsPai() {
    setState(() {
      // Mantém o submenu visível — apenas limpa as flags de conteúdo
      _filhoSelecionadoTipo = null;

      showConversaoList = false;
      _mostrarDownloads = false;
      _mostrarListarCacls = false;
      _mostrarOrdensAnalise = false;
      _mostrarHistorico = false;
      _mostrarEscolherTerminal = false;
      _mostrarMedicaoTanques = false;
      _mostrarTanques = false;
      _mostrarFiliaisDaEmpresa = false;
      _mostrarEstoquePorEmpresa = false;
      _mostrarEstoquePorTanque = false;
      _mostrarFiltrosEstoque = false;
      _mostrarFrascosAmostra = false;
      _mostrarResultadoFrascos = false;
      _mostrarCalcGerado = false;
      _mostrarTempDensMedia = false;
      _mostrarEstoqueProduto = false;
      _mostrarSuporte = false;
      _mostrarFilaSolicitacoes = false;
      _mostrarAcessoDesenvolvedor = false;
      _mostrarCardsFilial = false;
      _mostrarContaCorrenteRefinarias = false;
      _mostrarRegistroPreset = false;
      _mostrarCalculadoraArqueacao = false;
      _mostrarControleAditivo = false;
      _mostrarFiltroControleAditivo = false;
      _mostrarGestaoBombeios = false;
      _mostrarResultadoMensal = false;
      _mostrarAcompanhamentoOrdens = false;
      showControleAcesso = false;
      showUsuarios = false;
      _resetarTodasFlagsGestaoFrota();
      _filialSelecionadaNome = null;
      _dadosCalcGerado = null;
      _filialSelecionadaId = null;
      _contextoEscolhaTerminal = '';
      _filialParaFiltroId = null;
      _filialParaFiltroNome = null;
      _terminalParaFiltroId = null;
      _terminalParaFiltroNome = null;
      _empresaParaFiltroId = null;
      _empresaParaFiltroNome = null;
      _empresaSelecionadaId = null;
      _empresaSelecionadaNome = null;
    });
  }

  void _showLoginDevDialog() {
    final TextEditingController emailController = TextEditingController();
    final TextEditingController senhaController = TextEditingController();
    bool carregando = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Text('Acesso Desenvolvedor'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: senhaController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Senha',
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: carregando
                      ? null
                      : () async {
                          setDialogState(() => carregando = true);
                          try {
                            final response = await Supabase.instance.client.functions.invoke(
                              'validar-dev',
                              body: {
                                'email': emailController.text,
                                'senha': senhaController.text,
                              },
                              headers: {
                                'Content-Type': 'application/json',
                              },
                            );

                            if (!context.mounted) return;

                            if (response.data != null &&
                                response.data['autorizado'] == true) {
                              Navigator.pop(context);
                              if (mounted) {
                                setState(() {
                                  _mostrarAcessoDesenvolvedor = true;
                                });
                              }
                            } else {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Credenciais inválidas'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Erro ao validar: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setDialogState(() => carregando = false);
                            }
                          }
                        },
                  child: carregando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Acessar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuario = UsuarioAtual.instance;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            Container(
              height: 60,
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    offset: Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: InkWell(
                      onTap: _resetarTodasFlags,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Image.asset(
                          'assets/basex-top-home.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: (usuario?.nivel == 3)
                              ? [
                                  Text(
                                    usuario?.nome ?? '',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF0D47A1),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ]
                              : [
                                  Text(
                                    usuario?.nome ?? '',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF0D47A1),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    (usuario?.nivel == 1 || usuario?.nivel == 2)
                                        ? (_usuarioTerminalNome ??
                                              (UsuarioAtual
                                                              .instance
                                                              ?.terminalId ==
                                                          null ||
                                                      UsuarioAtual
                                                          .instance!
                                                          .terminalId!
                                                          .isEmpty
                                                  ? 'Sem terminal'
                                                  : 'Carregando...'))
                                        : (_usuarioFilialNome ??
                                              (UsuarioAtual.instance?.filialId ==
                                                          null ||
                                                      UsuarioAtual
                                                          .instance!
                                                          .filialId!
                                                          .isEmpty
                                                  ? 'Sem filial'
                                                  : 'Carregando...')),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                        ),
                        const SizedBox(width: 10),
                        PopupMenuButton<String>(
                          surfaceTintColor: Colors.white,
                          color: Colors.white,
                          icon: const Icon(
                            Icons.account_circle,
                            color: Color(0xFF0D47A1),
                            size: 30,
                          ),
                          onSelected: (value) async {
                            if (value == 'Perfil') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const PerfilPage(),
                                ),
                              );
                            }

                            if (value == 'Sair') {
                              await Supabase.instance.client.auth.signOut();
                              UsuarioAtual.instance = null;
                              if (context.mounted) {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LoginPage(),
                                  ),
                                  (route) => false,
                                );
                              }
                            }
                          },
                          itemBuilder: (context) {
                            return {'Perfil', 'Sair'}.map((choice) {
                              return PopupMenuItem<String>(
                                value: choice,
                                child: Text(choice),
                              );
                            }).toList();
                          },
                        ),
                        const SizedBox(width: 15),
                        // Lista suspensa de idiomas (agora o último objeto à direita)
                        PopupMenuButton<String>(
                          offset: const Offset(0, 40),
                          tooltip: 'Selecionar Idioma',
                          onSelected: (value) {
                            // Funcionalidade fictícia de troca de idioma
                          },
                          surfaceTintColor: Colors.white,
                          color: Colors.white,
                          elevation: 8,
                          itemBuilder: (BuildContext context) => [
                            const PopupMenuItem<String>(
                              value: 'en',
                              child: Row(
                                children: [
                                  Text('🇺🇸'),
                                  SizedBox(width: 8),
                                  Text('English (US)'),
                                ],
                              ),
                            ),
                            const PopupMenuItem<String>(
                              value: 'es',
                              child: Row(
                                children: [
                                  Text('🇪🇸'),
                                  SizedBox(width: 8),
                                  Text('Español'),
                                ],
                              ),
                            ),
                            const PopupMenuItem<String>(
                              value: 'pt',
                              child: Row(
                                children: [
                                  Text('🇧🇷'),
                                  SizedBox(width: 8),
                                  Text('Português (BR)'),
                                ],
                              ),
                            ),
                          ],
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                '🇧🇷',
                                style: TextStyle(fontSize: 18),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'PT-BR',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0D47A1),
                                ),
                              ),
                              Icon(
                                Icons.arrow_drop_down,
                                size: 20,
                                color: Colors.grey[600],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Row(
                children: [
                  // Collapsible main menu
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    width: _menuExpanded ? 200.0 : 56.0,
                    color: const Color(0xFFF5F5F5),
                    child: Column(
                      children: [
                        // Toggle button
                        Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 4, top: 4),
                          child: Tooltip(
                            message: _menuExpanded ? 'Recolher menu' : 'Expandir menu',
                            child: InkWell(
                              onTap: () => setState(() => _menuExpanded = !_menuExpanded),
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Icon(
                                  _menuExpanded ? Icons.chevron_left : Icons.chevron_right,
                                  color: Colors.grey[500],
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: menuItems.length,
                            itemBuilder: (context, index) {
                              bool isSelected = selectedIndex == index;
                              final nomeItem = menuItems[index];
                              final nomeFormatado = _formatarNomeMenu(nomeItem);

                              return MouseRegion(
                                onEnter: (_) =>
                                    setState(() => _hoveredMenuIndex = index),
                                onExit: (_) =>
                                    setState(() => _hoveredMenuIndex = -1),
                                child: Tooltip(
                                  message: _menuExpanded ? '' : nomeItem,
                                  preferBelow: false,
                                  child: InkWell(
                                  onTap: () {
                                    _resetarTodasFlags();

                                    setState(() {
                                      selectedIndex = index;
                                      _mostrarResultadoMensal = false;
                                    });

                                    final itemSelecionado = menuItems[index];

                                    if (itemSelecionado == 'Vendas' ||
                                        itemSelecionado == 'Configurações' ||
                                        _filhosPorSessao.containsKey(
                                          itemSelecionado,
                                        )) {
                                      _mostrarFilhosDaSessao(itemSelecionado);
                                    }
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                      horizontal: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFFF5F5F5),
                                      border: Border(
                                        left: BorderSide(
                                          color: isSelected
                                              ? const Color(0xFF64A7FF)
                                              : Colors.transparent,
                                          width: 4,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _getMenuIcon(nomeItem),
                                          color: isSelected
                                              ? _getCorPorSessao(nomeItem)
                                              : Colors.grey[700],
                                          size: 20,
                                        ),
                                        if (_menuExpanded) ...[
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 200,
                                              ),
                                              transform: Matrix4.translationValues(
                                                _hoveredMenuIndex == index
                                                    ? 6.0
                                                    : 0.0,
                                                0,
                                                0,
                                              ),
                                              child: AnimatedDefaultTextStyle(
                                                duration: const Duration(
                                                  milliseconds: 200,
                                                ),
                                                style: TextStyle(
                                                  fontWeight:
                                                      (isSelected ||
                                                          _hoveredMenuIndex ==
                                                              index)
                                                      ? FontWeight.bold
                                                      : FontWeight.w500,
                                                  color: isSelected
                                                      ? _getCorPorSessao(nomeItem)
                                                      : Colors.grey[800],
                                                  fontSize: 13,
                                                  height: 1.1,
                                                ),
                                                child: Text(
                                                  nomeFormatado,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.visible,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Submenu panel (shown when a session with children is selected and no child page is open)
                  if (_mostrarFilhosSessao &&
                      _filhosSessaoAtual.isNotEmpty &&
                      !_isAnyChildPageOpen())
                    _buildSubmenuPanel(),

                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                      child: _buildPageContent(usuario),
                    ),
                  ),
                ],
              ),
            ),


            Container(
              height: 50,
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Base X® 2026, All rights reserved.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),                  
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageContent(UsuarioAtual? usuario) {
    if (selectedIndex == -1) {
      return _buildInicioPage(usuario);
    }

    switch (menuItems[selectedIndex]) {
      case 'Início':
        return _buildInicioPage(usuario);

      case 'Relatórios':
        return _buildConteudoSessoes();

      case 'Configurações':
        return _buildConteudoSessoes();

      case 'Suporte':
        return _buildConteudoSessoes();

      case 'Jurídico':
      case 'Gestão de Projetos':
      case 'Recursos Humanos':
      case 'Segurança & Compliance':
      case 'Manutenção e ativos':
        return _buildAreaIndisponivelPage();

      case 'Almoxerifado':
        if (_mostrarFrascosAmostra) {
          if (_mostrarResultadoFrascos) {
            return FrascosAmostraPage(
              onVoltar: () {
                setState(() {
                  _mostrarResultadoFrascos = false;
                });
              },
              terminalId: _terminalParaFiltroId,
              empresaId: _empresaParaFiltroId,
              nomeTerminal: _terminalParaFiltroNome ?? '',
              empresaNome: _empresaParaFiltroNome,
              dataInicial: _frascosDataInicial,
              dataFinal: _frascosDataFinal,
              tipoRelatorio: _frascosTipoRelatorio,
            );
          }
          return FiltroEstoqueFrascosPage(
            terminalId: _terminalParaFiltroId,
            empresaId: _empresaParaFiltroId,
            nomeTerminal: _terminalParaFiltroNome ?? '',
            empresaNome: _empresaParaFiltroNome,
            onConsultarEstoque: ({
              required String? terminalId,
              required String? empresaId,
              required String nomeTerminal,
              String? empresaNome,
              required DateTime dataInicial,
              required DateTime dataFinal,
              required String tipoRelatorio,
            }) {
              setState(() {
                _terminalParaFiltroId = terminalId;
                _empresaParaFiltroId = empresaId;
                _terminalParaFiltroNome = nomeTerminal;
                _empresaParaFiltroNome = empresaNome;
                _frascosDataInicial = dataInicial;
                _frascosDataFinal = dataFinal;
                _frascosTipoRelatorio = tipoRelatorio;
                _mostrarResultadoFrascos = true;
              });
            },
            onVoltar: () {
              setState(() {
                _mostrarFrascosAmostra = false;
                _mostrarFilhosDaSessao('Almoxerifado');
              });
            },
          );
        }
        return _buildConteudoSessoes();

      case 'Estoques':
      case 'Operação':
      case 'Circuito':
      case 'Vendas':
      case 'Gestão de Frota':
      case 'Laboratório':
      case 'Financeiro':
      case 'Gestão de contratos':
      case 'Suprimentos':
        return _buildConteudoSessoes();

      default:
        return const SizedBox.shrink();
    }
  }

  // NOVO: Página padronizada para áreas indisponíveis
  Widget _buildAreaIndisponivelPage() {
    final areaAtual = menuItems[selectedIndex];

    return _buildPaginaPadronizada(
      titulo: areaAtual,
      conteudo: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.do_not_disturb, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 30), // Aumente este espaçamento
            const Text(
              'Em breve! Em processo de adequação à sua organização.',
              style: TextStyle(
                fontSize: 24,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15), // Aumente este espaçamento
            Padding(padding: const EdgeInsets.symmetric(horizontal: 40)),
          ],
        ),
      ),
      mostrarVoltar: false,
    );
  }    

  Widget _buildConteudoSessoes() {
    
    // PRIMEIRO: Obter a sessão atual do menu lateral
    final sessaoAtual = selectedIndex >= 0 && selectedIndex < menuItems.length
        ? menuItems[selectedIndex]
        : null;

    // SEÇÃO: Suporte
    if (sessaoAtual == 'Suporte') {
      if (_mostrarSuporte) {
        return _buildPaginaPadronizada(
          titulo: 'Suporte',
          conteudo: const SuportePage(),
          onVoltar: () => setState(() => _mostrarSuporte = false),
        );
      }
      if (_mostrarFilaSolicitacoes) {
        return FilaSolicitacoesPage(
          onVoltar: () => setState(() => _mostrarFilaSolicitacoes = false),
        );
      }
      if (_mostrarAcessoDesenvolvedor) {
        return AcessoDesenvolvedorPage(
          onVoltar: () => setState(() => _mostrarAcessoDesenvolvedor = false),
        );
      }
      return _buildFilhosSessaoPage();
    }

    // SEÇÃO: Almoxerifado
    if (sessaoAtual == 'Almoxerifado') {
      if (_mostrarFrascosAmostra) {
        if (_mostrarResultadoFrascos) {
          return FrascosAmostraPage(
            onVoltar: () {
              setState(() {
                _mostrarResultadoFrascos = false;
              });
            },
            terminalId: _terminalParaFiltroId,
            empresaId: _empresaParaFiltroId,
            nomeTerminal: _terminalParaFiltroNome ?? '',
            empresaNome: _empresaParaFiltroNome,
            dataInicial: _frascosDataInicial,
            dataFinal: _frascosDataFinal,
            tipoRelatorio: _frascosTipoRelatorio,
          );
        }
        return FiltroEstoqueFrascosPage(
          terminalId: _terminalParaFiltroId,
          empresaId: _empresaParaFiltroId,
          nomeTerminal: _terminalParaFiltroNome ?? '',
          empresaNome: _empresaParaFiltroNome,
          onConsultarEstoque: ({
            required String? terminalId,
            required String? empresaId,
            required String nomeTerminal,
            String? empresaNome,
            required DateTime dataInicial,
            required DateTime dataFinal,
            required String tipoRelatorio,
          }) {
            setState(() {
              _terminalParaFiltroId = terminalId;
              _empresaParaFiltroId = empresaId;
              _terminalParaFiltroNome = nomeTerminal;
              _empresaParaFiltroNome = empresaNome;
              _frascosDataInicial = dataInicial;
              _frascosDataFinal = dataFinal;
              _frascosTipoRelatorio = tipoRelatorio;
              _mostrarResultadoFrascos = true;
            });
          },
          onVoltar: () {
            setState(() {
              _mostrarFrascosAmostra = false;
            });
          },
        );
      }
      
      if (_mostrarFilhosSessao && _sessaoAtual == 'Almoxerifado') {
        return _buildFilhosSessaoPage();
      }
    }

    // SEÇÃO: Estoques
    if (sessaoAtual == 'Estoques') {
      if (_mostrarCardsFilial && _filialParaFiltroId != null) {
        return _buildCardsFilialPage();
      }
      
      if (_mostrarFiltrosEstoque &&
          (_filialParaFiltroId != null || _terminalParaFiltroId != null)) {
        return _buildFiltrosEstoquePage();
      }
      
      if (_mostrarDownloads) {
        return DownloadsPage(
          key: const ValueKey('downloads-page'),
          onVoltar: () {
            setState(() {
              _mostrarDownloads = false;
            });
          },
        );
      }
      
      if (_mostrarFiliaisDaEmpresa) {
        return _buildFiliaisDaEmpresaPage();
      }
      
      if (_mostrarEstoquePorEmpresa) {
        return _buildEstoquePorEmpresaPage();
      }
      
      if (_mostrarEstoquePorTanque) {
        return Container(
          margin: const EdgeInsets.only(left: 12),
          child: EstoquePorTanquePage(
            key: const ValueKey('estoque-por-tanque'),
            terminalSelecionadoId: _terminalSelecionadoId ?? _filialSelecionadaId,
            onVoltar: () {
              setState(() {
                _mostrarEstoquePorTanque = false;
                _terminalSelecionadoId = null;
                _filialSelecionadaId = null;
                
                if (_estoquePorTanqueVemDaApuracao) {
                  _estoquePorTanqueVemDaApuracao = false;
                  _mostrarFilhosDaSessao('Operação');
                } else {
                  _mostrarFilhosDaSessao('Estoques');
                }
              });
            },
          ),
        );
      }
      
      if (_mostrarFilhosSessao && _sessaoAtual == 'Estoques') {
        return _buildFilhosSessaoPage();
      }
    }

    // SEÇÃO: Operação
    if (sessaoAtual == 'Operação') {
      if (_mostrarEstoquePorTanque) {
        return Container(
          margin: const EdgeInsets.only(left: 12),
          child: EstoquePorTanquePage(
            key: const ValueKey('estoque-por-tanque'),
            terminalSelecionadoId:
                _terminalSelecionadoId ?? _filialSelecionadaId,
            onVoltar: () {
              setState(() {
                _mostrarEstoquePorTanque = false;
                _terminalSelecionadoId = null;
                _filialSelecionadaId = null;

                if (_estoquePorTanqueVemDaApuracao) {
                  _estoquePorTanqueVemDaApuracao = false;
                  _mostrarFilhosDaSessao('Operação');
                } else {
                  _mostrarFilhosDaSessao('Operação');
                }
              });
            },
          ),
        );
      }
      if (_mostrarTanques &&
          (_filialSelecionadaId != null || _terminalSelecionadoId != null)) {        
        return GerenciamentoTanquesPage(
          key: const ValueKey('gerenciamento-tanques'),
          onVoltar: () {
            final usuario = UsuarioAtual.instance;
            setState(() {
              _mostrarTanques = false;
              _filialSelecionadaId = null;
              _terminalSelecionadoId = null;
              
              if (usuario!.nivel == 3) {
                _mostrarEscolherTerminal = true;
                _contextoEscolhaTerminal = 'tanques';
              } else {
                _mostrarFilhosDaSessao('Operação');
              }
            });
          },
          terminalSelecionadoId: _terminalSelecionadoId ?? _filialSelecionadaId,
          onAbrirCACL: (terminalId) {
            setState(() {
              _voltarParaTanquesApoCACL = true;
              _mostrarTanques = false;
              _terminalSelecionadoId = terminalId;
              _filialSelecionadaId = null;
              _mostrarListarCacls = true;
            });
          },
        );
      }
      
      if (_mostrarListarCacls && _filialSelecionadaId != null) {
        return ListarCaclsPage(
          key: ValueKey('listar-cacls-$_filialSelecionadaId'),
          onVoltar: () {
            final usuario = UsuarioAtual.instance;
            setState(() {
              _mostrarListarCacls = false;
              _filialSelecionadaNome = null;
              
              if (_voltarParaTanquesApoCACL) {
                _voltarParaTanquesApoCACL = false;
                _mostrarTanques = true;
              } else {
                if (usuario!.nivel == 3) {
                  _mostrarEscolherTerminal = true;
                  _contextoEscolhaTerminal = 'cacl';
                } else {
                  _mostrarFilhosDaSessao('Operação');
                }
              }
            });
          },
          filialId: _filialSelecionadaId!,
          filialNome: _filialSelecionadaNome ?? 'Terminal',
          onIrParaEmissao: () {
            setState(() {
              _mostrarListarCacls = false;
              _mostrarMedicaoTanques = true;
            });
          },
        );
      }
      
      if (showConversaoList) {
        return TabelasDeConversao(
          key: const ValueKey('tabelas'),
          onVoltar: () {
            _mostrarFilhosDaSessao('Operação');
          },
        );
      }
      
      if (_mostrarOrdensAnalise) {
        return Material(
          type: MaterialType.canvas,
          color: Colors.white,
          child: ListarOrdensAnalisesPage(
            key: const ValueKey('listar-ordens-analise'),
            onVoltar: () {
              _mostrarFilhosDaSessao('Operação');
            },
          ),
        );
      }
      
      if (_mostrarHistorico) {
        return HistoricoCaclPage(
          key: const ValueKey('historico-cacl'),
          onVoltar: () {
            _mostrarFilhosDaSessao('Operação');
          },
        );
      }
      
      if (_mostrarEscolherTerminal) {
        return EscolherTerminalPage(
          key: ValueKey('escolher-terminal-$_contextoEscolhaTerminal'),
          onVoltar: () {
            setState(() {
              _mostrarEscolherTerminal = false;
              _contextoEscolhaTerminal = '';
              _mostrarFilhosDaSessao('Operação');
            });
          },
          onSelecionarTerminal: (idTerminal) async {
            final supabase = Supabase.instance.client;
            try {
              final filialData = await supabase
                  .from('filiais')
                  .select('nome')
                  .eq('id', idTerminal)
                  .maybeSingle();

              if (!mounted) return;

              if (filialData != null) {
                setState(() {
                  _filialSelecionadaId = idTerminal;
                  _filialSelecionadaNome = filialData['nome'];
                  _terminalSelecionadoId = null;
                  _mostrarEscolherTerminal = false;
                  
                  if (_contextoEscolhaTerminal == 'cacl') {
                    _mostrarListarCacls = true;
                  } else if (_contextoEscolhaTerminal == 'tanques') {
                    _mostrarTanques = true;
                  } else if (_contextoEscolhaTerminal == 'estoque_por_tanque') {
                    _mostrarEstoquePorTanque = true;
                  }
                  
                  _contextoEscolhaTerminal = '';
                });
                return;
              }
              
              final terminalData = await supabase
                  .from('terminais')
                  .select('nome')
                  .eq('id', idTerminal)
                  .maybeSingle();

              if (!mounted) return;

              if (terminalData != null) {
                setState(() {
                  _terminalSelecionadoId = idTerminal;
                  _filialSelecionadaId = null;
                  _filialSelecionadaNome = null;
                  _mostrarEscolherTerminal = false;
                  
                  if (_contextoEscolhaTerminal == 'tanques') {
                    _mostrarTanques = true;
                  } else if (_contextoEscolhaTerminal == 'estoque_por_tanque') {
                    _mostrarEstoquePorTanque = true;
                  }
                  
                  _contextoEscolhaTerminal = '';
                });
                return;
              }
              
              setState(() {
                _filialSelecionadaId = idTerminal;
                _filialSelecionadaNome = 'Terminal';
                _mostrarEscolherTerminal = false;
                if (_contextoEscolhaTerminal == 'cacl') {
                  _mostrarListarCacls = true;
                }
                if (_contextoEscolhaTerminal == 'tanques') {
                  _mostrarTanques = true;
                }
                if (_contextoEscolhaTerminal == 'estoque_por_tanque') {
                  _mostrarEstoquePorTanque = true;
                }
                _contextoEscolhaTerminal = '';
              });
            } catch (e) {
              setState(() {
                _filialSelecionadaId = idTerminal;
                _filialSelecionadaNome = 'Terminal';
                _mostrarEscolherTerminal = false;

                if (_contextoEscolhaTerminal == 'cacl') {
                  _mostrarListarCacls = true;
                } else if (_contextoEscolhaTerminal == 'tanques') {
                  _mostrarTanques = true;
                } else if (_contextoEscolhaTerminal == 'estoque_por_tanque') {
                  _mostrarEstoquePorTanque = true;
                }

                _contextoEscolhaTerminal = '';
              });
            }
          },
          titulo: _contextoEscolhaTerminal == 'cacl'
              ? 'Selecionar terminal para CACL:'
              : 'Selecionar terminal para gerenciar tanques:',
        );
      }
      
      if (_mostrarMedicaoTanques) {
        return MedicaoTanquesPage(
          key: const ValueKey('medicao-tanques'),
          onVoltar: () {
            setState(() {
              _mostrarMedicaoTanques = false;
              _mostrarListarCacls = true;
            });
          },
          onFinalizarCACL: () {
            setState(() {
              _mostrarMedicaoTanques = false;
              _mostrarListarCacls = false;
              _mostrarFilhosDaSessao('Operação');
            });
          },
        );
      }
      
      if (_mostrarTempDensMedia) {
        return TemperaturaDensidadeMediaPage(
          onVoltar: () {
            setState(() {
              _mostrarTempDensMedia = false;
              _mostrarFilhosDaSessao(_sessaoAtual ?? 'Operação');
            });
          },
        );
      }
      
      if (_mostrarEstoqueProduto) {
        return FiltroEstoqueProdutoPage(
          filialId: _filialParaFiltroId,
          terminalId: _terminalParaFiltroId,
          nomeFilial: _filialParaFiltroNome ?? _terminalParaFiltroNome ?? '',
          empresaId: _empresaParaFiltroId,
          empresaNome: _empresaParaFiltroNome,
          onConsultarEstoqueProduto: ({
            required String? filialId,
            required String? terminalId,
            required String nomeFilial,
            String? empresaId,
            required DateTime dataInicial,
            required DateTime dataFinal,
            required String produtoId,
            required String produtoNome,
            required String tipoRelatorio,
          }) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EstoqueProdutoPage(
                  filialId: filialId,
                  terminalId: terminalId,
                  nomeFilial: nomeFilial,
                  empresaId: empresaId,
                  dataInicial: dataInicial,
                  dataFinal: dataFinal,
                  produtoId: produtoId,
                  produtoNome: produtoNome,
                  tipoRelatorio: tipoRelatorio,
                ),
              ),
            );
          },
          onVoltar: () {
            setState(() {
              _mostrarEstoqueProduto = false;
              _mostrarFilhosDaSessao('Operação');
            });
          },
        );
      }

      if (_mostrarGestaoBombeios) {
        return FiltroGestaoBombeiosPage(
          terminalId: _terminalParaFiltroId,
          empresaId: _empresaParaFiltroId,
          empresaNome: _empresaParaFiltroNome,
          onConsultar: ({
            String? terminalId,
            DateTime? dataInicial,
            DateTime? dataFinal,
            String? produtoId,
            String? produtoNome,
            String? pesquisa,
          }) {
            // Futura implementação da página de resultado
            debugPrint('Consultar bombeios: $terminalId, $dataInicial - $dataFinal, $produtoId, $produtoNome, $pesquisa');
          },
          onVoltar: () {
            setState(() {
              _mostrarGestaoBombeios = false;
              _mostrarFilhosDaSessao('Operação');
            });
          },
        );
      }

      if (_mostrarResultadoMensal) {
        return ResultadosPage(
          onVoltar: () {
            setState(() {
              _mostrarResultadoMensal = false;
              _mostrarFilhosDaSessao('Operação');
            });
          },
        );
      }

      if (_mostrarRegistroPreset) {
        return PresetsPage(
          key: const ValueKey('presets-page'),
          onVoltar: () {
            setState(() {
              _mostrarRegistroPreset = false;
              _mostrarFilhosDaSessao('Operação');
            });
          },
        );
      }

      if (_mostrarCalculadoraArqueacao) {
        return CalculadoraArqueacaoPage(
          key: const ValueKey('calculadora-arqueacao-page'),
          onVoltar: () {
            setState(() {
              _mostrarCalculadoraArqueacao = false;
              _mostrarFilhosDaSessao('Operação');
            });
          },
        );
      }

      if (_mostrarControleAditivo) {
        return ControleAditivoPage(
          key: const ValueKey('controle-aditivo-page'),
          terminalId: _aditivoTerminalId,
          empresaId: _aditivoEmpresaId,
          nomeTerminal: _aditivoNomeTerminal,
          empresaNome: _aditivoEmpresaNome,
          dataInicial: _aditivoDataInicial ?? DateTime(DateTime.now().year, DateTime.now().month, 1),
          dataFinal: _aditivoDataFinal ?? DateTime.now(),
          tipoRelatorio: _aditivoTipoRelatorio ?? 'sintetico',
          onVoltar: () {
            setState(() {
              _mostrarControleAditivo = false;
              _mostrarFiltroControleAditivo = true;
            });
          },
        );
      }

      if (_mostrarFiltroControleAditivo) {
        return FiltroControleAditivoPage(
          key: const ValueKey('filtro-controle-aditivo-page'),
          nomeTerminal: _usuarioTerminalNome ?? 'Terminal',
          terminalId: _aditivoTerminalId,
          empresaId: _aditivoEmpresaId,
          empresaNome: _aditivoEmpresaNome,
          dataInicial: _aditivoDataInicial,
          dataFinal: _aditivoDataFinal,
          tipoRelatorio: _aditivoTipoRelatorio,
          onConsultar: ({
            required String? terminalId,
            required String? empresaId,
            required String nomeTerminal,
            String? empresaNome,
            required DateTime dataInicial,
            required DateTime dataFinal,
            required String tipoRelatorio,
          }) {
            setState(() {
              _aditivoTerminalId = terminalId;
              _aditivoEmpresaId = empresaId;
              _aditivoNomeTerminal = nomeTerminal;
              _aditivoEmpresaNome = empresaNome;
              _aditivoDataInicial = dataInicial;
              _aditivoDataFinal = dataFinal;
              _aditivoTipoRelatorio = tipoRelatorio;

              _mostrarFiltroControleAditivo = false;
              _mostrarControleAditivo = true;
            });
          },
          onVoltar: () {
            setState(() {
              _mostrarFiltroControleAditivo = false;
              _mostrarFilhosDaSessao('Operação');
            });
          },
        );
      }

      if (_sessaoAtual == 'Perdas e Sobras') {
        return _buildFilhosSessaoPage();
      }
      
      if (_mostrarFilhosSessao && _sessaoAtual == 'Operação') {
        return _buildFilhosSessaoPage();
      }
    }

    // SEÇÃO: Circuito
    if (sessaoAtual == 'Circuito') {
      if (_mostrarAcompanhamentoOrdens) {
        return AcompanhamentoOrdensPage(
          key: const ValueKey('acompanhamento-ordens'),
          onVoltar: () {
            setState(() {
              _mostrarAcompanhamentoOrdens = false;
            });
          },
        );
      }
      
      if (_mostrarFilhosSessao && _sessaoAtual == 'Circuito') {
        return _buildFilhosSessaoPage();
      }
    }

    // SEÇÃO: Gestão de Frota
    if (sessaoAtual == 'Gestão de Frota') {
      if (_mostrarVeiculos && !_mostrarDetalhesVeiculo) {
        return VeiculosPage(
          key: const ValueKey('veiculos-page'),
          abaInicial: _abaInicialVeiculos,
          onVoltar: () {
            setState(() {
              _abaInicialVeiculos = 0;
              _resetarTodasFlagsGestaoFrota();
              _mostrarFilhosDaSessao('Gestão de Frota');
            });
          },
          onSelecionarVeiculo: (veiculo) {
            setState(() {
              _veiculoSelecionado = veiculo;
              _mostrarDetalhesVeiculo = true;
            });
          },
        );
      }
      
      if (_mostrarDetalhesVeiculo && _veiculoSelecionado != null) {
        return VeiculoDetalhesPage(
          key: ValueKey('detalhes-${_veiculoSelecionado!['placa']}'),
          id: _veiculoSelecionado!['id'] ?? '',
          placa: _veiculoSelecionado!['placa'] ?? '',
          tanques: List<int>.from(_veiculoSelecionado!['tanques'] ?? []),
          transportadora: _veiculoSelecionado!['transportadora'] ?? '--',
          onVoltar: () {
            setState(() {
              _mostrarDetalhesVeiculo = false;
              _veiculoSelecionado = null;
            });
          },
        );
      }
      
      if (_mostrarMotoristas) {
        return MotoristasPage(
          key: const ValueKey('motoristas-page'),
          onVoltar: () {
            setState(() {
              _resetarTodasFlagsGestaoFrota();
              _mostrarFilhosDaSessao('Gestão de Frota');
            });
          },
        );
      }
      
      if (_mostrarTransportadoras) {
        return _buildPaginaPadronizada(
          titulo: 'Transportadoras',
          conteudo: const TransportadorasPage(),
          onVoltar: () {
            setState(() {
              _mostrarTransportadoras = false;
              _mostrarFilhosDaSessao('Gestão de Frota');
            });
          },
        );
      }
      
      if (_mostrarFilhosSessao && _sessaoAtual == 'Gestão de Frota') {
        return _buildFilhosSessaoPage();
      }
    }

    // SEÇÃO: Vendas
    if (sessaoAtual == 'Vendas') {
      if (_mostrarFiltroMovimentacoes) {
        return FiltroVendasPage(
          filialId: _filialParaFiltroId,
          terminalId: _terminalParaFiltroId,
          nomeFilial: _filialParaFiltroNome ?? _terminalParaFiltroNome ?? '',
          empresaId: _empresaParaFiltroId,
          empresaNome: _empresaParaFiltroNome,
          onVoltar: () {
            setState(() {
              _mostrarFiltroMovimentacoes = false;
              _mostrarFilhosDaSessao('Vendas');
            });
          },
        );
      }

      if (_mostrarFilhosSessao && _sessaoAtual == 'Vendas') {
        return _buildFilhosSessaoPage();
      }
    }

    // SEÇÃO: Suprimentos
    if (sessaoAtual == 'Suprimentos') {
      if (_mostrarFilhosSessao && _sessaoAtual == 'Suprimentos') {
        return _buildFilhosSessaoPage();
      }
    }

    // SEÇÃO: Relatórios
    if (sessaoAtual == 'Relatórios') {
      if (_mostrarDownloads) {
        return RelatoriosDownloadsPage(
          key: const ValueKey('relatorios-downloads-page'),
          onVoltar: () {
            setState(() {
              _mostrarDownloads = false;
              _mostrarFilhosDaSessao('Relatórios');
            });
          },
        );
      }
      if (_mostrarFilhosSessao && _sessaoAtual == 'Relatórios') {
        return _buildFilhosSessaoPage();
      }
    }

    // SEÇÃO: Configurações
    if (sessaoAtual == 'Configurações') {
      if (showControleAcesso) {
        return ControleAcessoUsuarios(
          key: const ValueKey('controle_acesso'),
          onVoltar: () => setState(() => showControleAcesso = false),
        );
      }
      if (showUsuarios) {
        return UsuariosPage(
          key: const ValueKey('usuarios'),
          onVoltar: () => setState(() => showUsuarios = false),
        );
      }
      return _buildFilhosSessaoPage();
    }

    // SEÇÃO: Gestão de contratos
    if (sessaoAtual == 'Gestão de contratos') {
      return _buildFilhosSessaoPage();
    }

    // SEÇÃO: Laboratório
    if (sessaoAtual == 'Laboratório') {
      if (_mostrarTempDensMedia) {
        return TemperaturaDensidadeMediaPage(
          onVoltar: () {
            setState(() {
              _mostrarTempDensMedia = false;
              _mostrarFilhosDaSessao('Laboratório');
            });
          },
        );
      }
      return _buildFilhosSessaoPage();
    }

    // SEÇÃO: Financeiro
    if (sessaoAtual == 'Financeiro') {
      if (_mostrarContaCorrenteRefinarias) {
        return ContaCorrenteRefinariasPage(
          filialId: _filialSelecionadaId,
          nomeFilial: _filialSelecionadaNome ?? 'Geral',
          onVoltar: () {
            setState(() {
              _mostrarContaCorrenteRefinarias = false;
              _mostrarFilhosDaSessao('Financeiro');
            });
          },
        );
      }
      return _buildFilhosSessaoPage();
    }

    // Páginas indisponíveis
    if (sessaoAtual == 'Jurídico' ||
        sessaoAtual == 'Gestão de Projetos' ||
        sessaoAtual == 'Recursos Humanos' ||
        sessaoAtual == 'Segurança & Compliance' ||
        sessaoAtual == 'Manutenção e ativos') {
      return _buildAreaIndisponivelPage();
    }

    // FALLBACK: Se nenhuma condição for atendida
    if (_mostrarFilhosSessao && _sessaoAtual != null) {
      return _buildFilhosSessaoPage();
    }
    
    if (_mostrarFilhosSessao && _sessaoAtual == null) {
      return _buildSemPermissaoPage();
    }

    if (_carregandoCards) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF0D47A1)),
      );
    }

    if (_mostrarCalcGerado) {
      return CalcPage(
        key: const ValueKey('calc-page'),
        dadosFormulario: _dadosCalcGerado ?? {},
      );
    }

    return const SizedBox.shrink();
  }

  // NOVO: Widget padronizado para todas as páginas de cards
  Widget _buildPaginaPadronizada({
    required String titulo,
    required Widget conteudo,
    bool mostrarVoltar = true,
    VoidCallback? onVoltar,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(30, 20, 30, 30),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (mostrarVoltar && onVoltar != null) ...[
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
                  onPressed: onVoltar,
                  tooltip: 'Voltar',
                ),
                const SizedBox(width: 10),
              ],
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 24,
                  color: Color(0xFF0D47A1),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: Colors.grey),
          const SizedBox(height: 20),
          Expanded(child: conteudo),
        ],
      ),
    );
  }

  // NOVO: Página de "Sem permissão" padronizada
  Widget _buildSemPermissaoPage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 20),
          const Text(
            'Sem permissão',
            style: TextStyle(
              fontSize: 24,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Você não tem permissão para acessar nenhum card nesta sessão.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.arrow_back),
            label: const Text('Voltar para o menu'),
            onPressed: _voltarParaCardsPai,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilhosSessaoPage() {
    // Se não houver cards para mostrar
    if (_filhosSessaoAtual.isEmpty) {
      return _buildSemPermissaoPage();
    }

    // Se houver um card filho selecionado, exibe seu conteúdo
    if (_filhoSelecionadoTipo != null) {
      switch (_filhoSelecionadoTipo) {
        case 'dutoviario':
          return _buildPaginaPadronizada(
            titulo: 'Dutoviário',
            conteudo: const Center(
              child: Text(
                'Em breve! Em processo de adequação à sua organização.',
                style: TextStyle(fontSize: 18),
              ),
            ),
            onVoltar: () {
              setState(() {
                _filhoSelecionadoTipo = null;
              });
            },
          );
        case 'rodoviario':
          return _buildPaginaPadronizada(
            titulo: 'Rodoviário',
            conteudo: const Center(
              child: Text(
                'Em breve! Em processo de adequação à sua organização.',
                style: TextStyle(fontSize: 18),
              ),
            ),
            onVoltar: () {
              setState(() {
                _filhoSelecionadoTipo = null;
              });
            },
          );
        case 'criar_ordem':
          return _buildPaginaPadronizada(
            titulo: 'Criar ordem',
            conteudo: CriarOrdemPage(
              onCreated: () {
                setState(() {
                  _filhoSelecionadoTipo = null;
                  _mostrarFilhosSessao = true;
                  _sessaoAtual = 'Circuito';
                  _filhosSessaoAtual = List.from(
                    _filhosPorSessao['Circuito'] ?? [],
                  );
                });
              },
              onVoltar: () {
                setState(() {
                  _filhoSelecionadoTipo = null;
                });
              },
            ),
            mostrarVoltar: true,
            onVoltar: () {
              setState(() {
                _filhoSelecionadoTipo = null;
              });
            },
          );
        case 'radar':
          return RadarPage(
            onVoltar: () {
              setState(() {
                _filhoSelecionadoTipo = null;
              });
            },
          );
        case 'ordem_bombeio':
          return _buildPaginaPadronizada(
            titulo: 'Ordem de Bombeio',
            conteudo: OrdemBombeioPage(
              onVoltar: () {
                setState(() {
                  _filhoSelecionadoTipo = null;
                });
              },
            ),
            mostrarVoltar: true,
            onVoltar: () {
              setState(() {
                _filhoSelecionadoTipo = null;
              });
            },
          );
        case 'tabela_precos_refinaria':
          return _buildPaginaPadronizada(
            titulo: 'Tabela de Preços - Refinaria',
            conteudo: const Center(
              child: Text(
                'Em breve! Em processo de adequação à sua organização.',
                style: TextStyle(fontSize: 18),
              ),
            ),
            mostrarVoltar: true,
            onVoltar: () {
              setState(() {
                _filhoSelecionadoTipo = null;
              });
            },
          );
        default:
          break;
      }
    }

    return _buildPlaceholderSessao();
  }

  Widget _buildEstoquePorEmpresaPage() {
    return _buildPaginaPadronizada(
      titulo: 'Estoque por empresa',
      conteudo: carregandoEmpresas
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0D47A1)),
            )
          : empresas.isEmpty
          ? const Center(
              child: Text(
                'Nenhuma empresa encontrada.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : GridView.count(
              crossAxisCount: 7,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 1.1,
              padding: const EdgeInsets.only(bottom: 20),
              children: empresas
                  .map((empresa) => _buildCardEmpresa(empresa))
                  .toList(),
            ),
      onVoltar: () => _mostrarFilhosDaSessao('Estoques'),
    );
  }

  Widget _buildFiliaisDaEmpresaPage() {
    return _buildPaginaPadronizada(
      titulo: 'Filiais - $_empresaSelecionadaNome',
      conteudo: carregandoFiliaisEmpresa
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0D47A1)),
            )
          : filiaisDaEmpresa.isEmpty
          ? const Center(
              child: Text(
                'Nenhuma filial encontrada para esta empresa.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : GridView.count(
              crossAxisCount: 6, // REDUZIDO DE 7 PARA 6 PARA DAR MAIS ESPAÇO
              crossAxisSpacing: 18, // AUMENTADO DE 15 PARA 18
              mainAxisSpacing: 18, // AUMENTADO DE 15 PARA 18
              childAspectRatio:
                  1.0, // AUMENTADO DE 1.1 PARA 1.0 (MAIS QUADRADO)
              padding: const EdgeInsets.only(bottom: 20),
              children: filiaisDaEmpresa
                  .map((filial) => _buildCardFilial(filial))
                  .toList(),
            ),
      onVoltar: () {
        setState(() {
          _mostrarFiliaisDaEmpresa = false;
          _mostrarEstoquePorEmpresa = true;
        });
      },
    );
  }  

  Widget _buildCardFavoritoInicio(Map<String, dynamic> card) {
    final sessaoPai = card['sessao_pai']?.toString() ?? '';
    final corSessao = _getCorPorSessao(sessaoPai);

    return _HoverScale(
      child: Material(
        elevation: 2,
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          onTap: () => _navegarParaFavorito(card),
          hoverColor: corSessao.withOpacity(0.1),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(card['icon'], color: corSessao, size: 50),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 45, maxHeight: 45),
                  child: Center(
                    child: Text(
                      card['label'] ?? '',
                      style: TextStyle(
                        fontSize: (card['label']?.toString() ?? '').length > 25 ? 10 : 12,
                        color: const Color(0xFF0D47A1),
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sessaoPai,
                  style: TextStyle(
                    fontSize: 9,
                    color: corSessao.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardEmpresa(Map<String, dynamic> empresa) {
    return _HoverScale(
      child: Material(
        elevation: 2,
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          onTap: () async {
            final empresaId = empresa['id'];
            setState(() {
              _empresaSelecionadaId = empresaId;
              _empresaSelecionadaNome = empresa['label'];
            });

            await _carregarFiliaisDaEmpresa(_empresaSelecionadaId!);

            if (!mounted) return;

            setState(() {
              _mostrarEstoquePorEmpresa = false;
              _mostrarFiliaisDaEmpresa = true;
            });
          },
          hoverColor: _getCorPorSessao('Estoques').withOpacity(0.1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  empresa['icon'],
                  color: _getCorPorSessao('Estoques'),
                  size: 55,
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 40, maxHeight: 40),
                  child: Center(
                    child: Text(
                      empresa['label'],
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF0D47A1),
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                // REMOVER A DESCRIÇÃO (CNPJ) AQUI TAMBÉM
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardFilial(Map<String, dynamic> filial) {
    return _HoverScale(
      child: Material(
        elevation: 3, // AUMENTADO DE 2 PARA 3
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          onTap: () {
            setState(() {
              _mostrarFiliaisDaEmpresa = false;
              _filialParaFiltroId = filial['id'];
              _filialParaFiltroNome = filial['label'];
              _empresaParaFiltroId = _empresaSelecionadaId;
              _empresaParaFiltroNome = _empresaSelecionadaNome;
              _mostrarCardsFilial = false;

              // Direciona para o filtro correto baseado no contexto
              if (_contextoEscolhaTerminal == 'movimentacoes' ||
                  _contextoEscolhaTerminal == 'movimentaces') {
                _mostrarFiltroMovimentacoes = true;
              } else {
                _mostrarFiltrosEstoque = true;
              }
            });
          },
          hoverColor: _getCorPorSessao('Estoques').withOpacity(0.1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.grey.shade300,
                width: 1.5,
              ), // AUMENTADO DE 1 PARA 1.5
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  filial['icon'],
                  color: _getCorPorSessao('Estoques'),
                  size: 60, // AUMENTADO DE 55 PARA 60
                ),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: 50,
                    maxHeight: 50,
                  ), // AUMENTADO DE 40 PARA 50
                  child: Center(
                    child: Text(
                      filial['label'],
                      style: const TextStyle(
                        fontSize: 14.5, // AUMENTADO DE 13 PARA 14.5
                        color: Color(0xFF0D47A1),
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navegarParaCardFilho(Map<String, dynamic> card) {
    final usuario = UsuarioAtual.instance;
    final cardId = card['id']?.toString();
    final tipo = card['tipo'];
    final sessaoPai = _sessaoAtual;

    if (usuario != null &&
        cardId != null &&
        !usuario.podeAcessarCard(cardId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você não tem permissão para acessar este recurso.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    switch (sessaoPai) {
      case 'Suporte':
        _navegarParaCardSuporte(tipo);
        break;
      case 'Configurações':
        _navegarParaCardConfiguracoes(tipo);
        break;
      case 'Operação':
        _navegarParaCardApuracao(tipo, usuario);
        break;
      case 'Perdas e Sobras':
        _navegarParaCardPerdasSobras(tipo);
        break;
      case 'Estoques':
        _navegarParaCardEstoques(tipo);
        break;
      case 'Circuito':
        _navegarParaCardCircuito(tipo);
        break;
      case 'Gestão de Frota':
        _navegarParaCardGestaoFrota(tipo);
        break;
      case 'Vendas':
        _navegarParaCardVendas(tipo, card);
        break;
      case 'Suprimentos':
        _navegarParaCardBombeios(tipo);
        break;
      case 'Laboratório':
        _navegarParaCardLaboratorio(tipo);
        break;
      case 'Financeiro':
        _navegarParaCardFinanceiro(tipo);
        break;
      case 'Almoxerifado':
        _navegarParaCardAlmoxerifado(tipo);
        break;
      case 'Gestão de contratos':
        _navegarParaCardGestaoContratos(tipo);
        break;
      case 'Relatórios':
        _navegarParaCardRelatorios(tipo);
        break;
      default:
        debugPrint('Sessão pai não reconhecida: $sessaoPai');
    }
  }

  void _navegarParaCardPerdasSobras(String tipo) {
    switch (tipo) {
      case 'dutoviario':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Em breve! Em processo de adequação à sua organização.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        break;
      case 'rodoviario':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Em breve! Em processo de adequação à sua organização.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        break;
    }
  }

  void _navegarParaCardApuracao(String tipo, UsuarioAtual? usuario) {
    switch (tipo) {
      case 'dutoviario':
        setState(() {
          _filhoSelecionadoTipo = 'dutoviario';
        });
        break;
      case 'rodoviario':
        setState(() {
          _filhoSelecionadoTipo = 'rodoviario';
        });
        break;
      case 'ordens_analise':
        setState(() {
          _mostrarOrdensAnalise = true;
        });
        break;
      case 'historico_cacl':
        setState(() {
          _mostrarHistorico = true;
        });
        break;
      case 'tabelas_conversao':
        setState(() {
          showConversaoList = true;
        });
        break;
      case 'temp_dens_media':
        setState(() {
          _mostrarTempDensMedia = true;
        });
        break;
      case 'estoque_produto':
        setState(() {
          _mostrarEstoqueProduto = true;
        });
        break;
      case '0bc9a8ec-40a0-41c1-a44a-405c64c233a5': // Gestão de Bombeios
        setState(() {
          _mostrarGestaoBombeios = true;
        });
        break;
      case 'controle_aditivo':
        setState(() {
          _mostrarFiltroControleAditivo = true;
        });
        break;
      case 'perdas_sobras':
        setState(() {
          _sessaoAtual = 'Perdas e Sobras';
          _mostrarFilhosSessao = true;
          _filhosSessaoAtual = List.from(_filhosPorSessao['Perdas e Sobras'] ?? []);
        });
        break;
      case 'tanques': // ADICIONADO: Caso para tanques agora em Operação
        final usuario = UsuarioAtual.instance;
        if (usuario!.nivel == 3) {
          setState(() {
            _mostrarEscolherTerminal = true;
            _contextoEscolhaTerminal = 'tanques';
          });
        } else {
          // Nível 1 e 2: vai direto para tanques usando o terminalId vinculado
          _terminalSelecionadoId = usuario.terminalId;
          setState(() {
            _mostrarTanques = true;
          });
        }
        break;
      case 'estoque_por_tanque':
        final usuario = UsuarioAtual.instance;
        if (usuario != null && usuario.nivel == 3) {
          setState(() {
            _mostrarEscolherTerminal = true;
            _contextoEscolhaTerminal = 'estoque_por_tanque';
            _estoquePorTanqueVemDaApuracao = true;
          });
        } else {
          // usuários normais vão direto para a página com sua filial
          _terminalSelecionadoId = usuario?.terminalId;
          setState(() {
            _estoquePorTanqueVemDaApuracao = true;
            _mostrarEstoquePorTanque = true;
          });
        }
        break;
      case 'resultados':
        setState(() {
          _mostrarResultadoMensal = true;
        });
        break;
      case 'registro_preset':
        setState(() {
          _mostrarRegistroPreset = true;
        });
        break;
      case 'calculadora_arqueacao':
        setState(() {
          _mostrarCalculadoraArqueacao = true;
        });
        break;
    }
  }

  void _navegarParaCardEstoques(String tipo) {
    final usuario = UsuarioAtual.instance;

    switch (tipo) {
      case 'estoque_geral':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EstoqueGeralPage()),
        );
        break;

      case 'compacto_final':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CompactoFinalPage()),
        );
        break;

      case 'estoque_por_empresa':
        setState(() {
          _mostrarEstoquePorEmpresa = true;
          _carregarEmpresas();
        });
        break;

      case 'movimentacao_por_empresa':
        setState(() {
          _mostrarEstoquePorEmpresa = true;
          _carregarEmpresas();
        });
        break;

      case 'estoque_por_tanque':
        final usuario = UsuarioAtual.instance;
        if (usuario != null && usuario.nivel == 3) {
          setState(() {
            _mostrarEscolherTerminal = true;
            _contextoEscolhaTerminal = 'estoque_por_tanque';
            _estoquePorTanqueVemDaApuracao = false;
          });
        } else {
          _filialSelecionadaId = usuario?.filialId;
          setState(() {
            _estoquePorTanqueVemDaApuracao = false;
            _mostrarEstoquePorTanque = true;
          });
        }
        break;

      case 'estoque_fiscal':
        // Validar se usuário tem filial OU terminal vinculado
        if (usuario == null) return;

        // Para nível 1 e 2, usar terminal_id
        if (usuario.nivel == 1 || usuario.nivel == 2) {
          if (usuario.terminalId == null || usuario.terminalId!.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Usuário sem terminal vinculado'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
            return;
          }

          setState(() {
            _terminalParaFiltroId = usuario.terminalId;
            _terminalParaFiltroNome = _usuarioTerminalNome ?? 'Seu Terminal';
            _filialParaFiltroId = null;
            _filialParaFiltroNome = null;
            _empresaParaFiltroId = null;
            _empresaParaFiltroNome = null;
            _mostrarFiltrosEstoque = true;
            _mostrarCardsFilial = false;
            _mostrarFiliaisDaEmpresa = false;
          });
          return;
        }

        // Para nível 3, usar filial_id
        if (usuario.nivel == 3) {
          if (usuario.filialId == null || usuario.filialId!.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Usuário sem filial vinculada'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
            return;
          }

          setState(() {
            _filialParaFiltroId = usuario.filialId;
            _filialParaFiltroNome = _usuarioFilialNome ?? 'Sua Filial';
            _terminalParaFiltroId = null;
            _terminalParaFiltroNome = null;
            _empresaParaFiltroId = null;
            _empresaParaFiltroNome = null;
            _mostrarFiltrosEstoque = true;
            _mostrarCardsFilial = false;
            _mostrarFiliaisDaEmpresa = false;
          });
          return;
        }

        // Para nível 4 (Master), mostrar seleção de empresa primeiro
        setState(() {
          _mostrarEstoquePorEmpresa = true;
          _contextoEscolhaTerminal = tipo;
          _carregarEmpresas();
        });
        break;

      case 'transferencias':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TransferenciasPage(
              onVoltar: () {
                Navigator.pop(context);
              },
            ),
          ),
        );
        break;

      case 'controle_descargas':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ControleDescargasPage(
              onVoltar: () => Navigator.pop(context),
            ),
          ),
        );
        break;

      default:
        debugPrint('Tipo de card de estoques não reconhecido: $tipo');
        break;
    }
  }

  void _navegarParaCardCircuito(String tipo) {
    switch (tipo) {
      case 'acompanhar_ordem':
        // Acompanhamento de ordens agora usa terminal_id; não exigir filial vinculada
        setState(() {
          _mostrarAcompanhamentoOrdens = true;
        });
        break;
      case 'visao_geral_circuito':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VisaoGeralCircuitoPage(
              onVoltar: () => Navigator.pop(context),
            ),
          ),
        );
        break;
      case 'criar_ordem':
        setState(() {
          _filhoSelecionadoTipo = 'criar_ordem';
          _mostrarFilhosSessao = true;
          _sessaoAtual = 'Circuito';
          _filhosSessaoAtual = List.from(_filhosPorSessao['Circuito'] ?? []);
        });
        break;
      case 'radar':
        setState(() {
          _filhoSelecionadoTipo = 'radar';
        });
        break;
    }
  }
  // ...existing code...

  void _navegarParaCardGestaoFrota(String tipo) {
    switch (tipo) {
      case 'veiculos':
        setState(() {
          _mostrarVeiculos = true;
          _abaInicialVeiculos = 0;
          _mostrarDetalhesVeiculo = false;
          _veiculoSelecionado = null;
          _mostrarMotoristas = false;
        });
        break;

      case 'transportadoras':
        setState(() {
          _mostrarTransportadoras = true;
          _mostrarVeiculos = false;
          _mostrarDetalhesVeiculo = false;
          _veiculoSelecionado = null;
          _mostrarMotoristas = false;
        });
        break;

      case 'motoristas':
        setState(() {
          _mostrarMotoristas = true;
          _mostrarVeiculos = false;
          _mostrarDetalhesVeiculo = false;
          _veiculoSelecionado = null;
        });
        break;

      case 'documentacao':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ControleDocumentosPage()),
        );
        break;
    }
  }

  void _navegarParaCardVendas(String tipo, Map<String, dynamic> card) {
    switch (tipo) {
      case 'movimentacoes':
      case 'movimentaces':
        _navegarParaMovimentacoesVendas();
        break;

      case 'programacao_filial':
        final filialId = card['filial_id'];
        final filialNome = card['filial_nome'];
        final filialNomeDois = card['filial_nome_dois'];
        final terminalId = card['terminal_id']; // NOVO: pega o terminal_id

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProgramacaoPage(
              onVoltar: () {
                Navigator.pop(context);
              },
              filialId: filialId,
              filialNome: filialNome,
              filialNomeDois: filialNomeDois,
              terminalId: terminalId, // NOVO: passa o terminal_id
            ),
          ),
        );
        break;
    }
  }

  void _navegarParaMovimentacoesVendas() {
    final usuario = UsuarioAtual.instance;
    if (usuario == null) return;

    // Nível 1 e 2 (Operacional/Terminal)
    if (usuario.nivel == 1 || usuario.nivel == 2) {
      setState(() {
        _terminalParaFiltroId = usuario.terminalId;
        _terminalParaFiltroNome = _usuarioTerminalNome ?? 'Seu Terminal';
        _filialParaFiltroId = null;
        _filialParaFiltroNome = null;
        _empresaParaFiltroId = null;
        _empresaParaFiltroNome = null;
        _mostrarFiltroMovimentacoes = true;
        _mostrarCardsFilial = false;
        _mostrarFiliaisDaEmpresa = false;
      });
      return;
    }

    // Nível 3 (Gerencial/Filial)
    if (usuario.nivel == 3) {
      setState(() {
        _filialParaFiltroId = null;
        _filialParaFiltroNome = null;
        _terminalParaFiltroId = null;
        _terminalParaFiltroNome = null;
        _empresaParaFiltroId = null;
        _empresaParaFiltroNome = null;
        _mostrarFiltroMovimentacoes = true;
        _mostrarCardsFilial = false;
        _mostrarFiliaisDaEmpresa = false;
      });
      return;
    }

    // Nível 4 (Master): campos livres, vai direto para filtro
    setState(() {
      _filialParaFiltroId = null;
      _filialParaFiltroNome = null;
      _terminalParaFiltroId = null;
      _terminalParaFiltroNome = null;
      _empresaParaFiltroId = null;
      _empresaParaFiltroNome = null;
      _mostrarFiltroMovimentacoes = true;
      _mostrarCardsFilial = false;
      _mostrarFiliaisDaEmpresa = false;
    });
  }

  void _navegarParaCardBombeios(String tipo) {
    switch (tipo) {
      case 'ordem_bombeio':
        setState(() {
          _filhoSelecionadoTipo = tipo;
        });
        break;
      case 'bombeios':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Em breve! Em processo de adequação à sua organização.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        break;
      case 'tabela_precos_refinaria':
        setState(() {
          _filhoSelecionadoTipo = tipo;
        });
        break;
    }
  }

  void _navegarParaCardAlmoxerifado(String tipo) {
    switch (tipo) {
      case 'frascos_amostra':
        setState(() {
          _mostrarFrascosAmostra = true;
        });
        break;
    }
  }

  void _navegarParaCardGestaoContratos(String tipo) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Em breve! Em processo de adequação à sua organização.'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _navegarParaCardRelatorios(String tipo) {
    switch (tipo) {
      case 'downloads':
        setState(() {
          _mostrarDownloads = true;
        });
        break;
    }
  }

  void _navegarParaCardLaboratorio(String tipo) {
    switch (tipo) {
      case 'temp_dens_media':
        setState(() {
          _mostrarTempDensMedia = true;
        });
        break;
      case 'analise_conformidade':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Em breve! Em processo de adequação à sua organização.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        break;
    }
  }

  void _navegarParaCardFinanceiro(String tipo) {
    switch (tipo) {
      case 'conta_corrente_refinarias':
        setState(() {
          _mostrarContaCorrenteRefinarias = true;
        });
        break;
    }
  }  

  IconData _getMenuIcon(String item) {
    switch (item) {
      case 'Início':
        return Icons.home;
      case 'Estoques':
        return Icons.leaderboard;
      case 'Operação':
        return Icons.analytics;
      case 'Circuito':
        return Icons.route;
      case 'Vendas':
        return Icons.local_gas_station;
      case 'Gestão de Frota':
        return Icons.local_shipping;
      case 'Suprimentos':
        return Icons.invert_colors;
      case 'Laboratório':
        return Icons.science;
      case 'Financeiro':
        return Icons.account_balance_wallet;
      case 'Jurídico':
        return Icons.gavel;
      case 'Gestão de contratos':
        return Icons.handshake;
      case 'Gestão de Projetos':
        return Icons.assignment;
      case 'Recursos Humanos':
        return Icons.people;
      case 'Almoxerifado':
        return Icons.inventory_2;
      case 'Manutenção e ativos':
        return Icons.build;
      case 'Segurança & Compliance':
        return Icons.security;
      case 'Relatórios':
        return Icons.bar_chart;
      case 'Configurações':
        return Icons.settings;
      case 'Suporte':
        return Icons.help_outline;
      default:
        return Icons.circle;
    }
  }

  Widget _buildInicioPage(UsuarioAtual? usuario) {
    final favoritos = <Map<String, dynamic>>[];
    for (final entry in _filhosPorSessao.entries) {
      for (final card in entry.value) {
        if (card['favorito'] == true) {
          // Verifica se o usuário tem permissão para este card
          final cardId = card['id']?.toString();
          if (usuario == null || cardId == null || usuario.podeAcessarCard(cardId)) {
            favoritos.add(card);
          }
        }
      }
    }
    for (final card in _filiaisProgramacao) {
      if (card['favorito'] == true) {
        // Verifica se o usuário tem permissão para este card
        final cardId = card['id']?.toString();
        if (usuario == null || cardId == null || usuario.podeAcessarCard(cardId)) {
          favoritos.add(card);
        }
      }
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.fromLTRB(30, 20, 30, 30),
      decoration: const BoxDecoration(
        color: Colors.white,
        image: DecorationImage(
          image: AssetImage('assets/home-fundo.png'),
          alignment: Alignment.center,
          scale: 1.0, // Mantém o tamanho original
          opacity: 0.1, // Transparência para a imagem de fundo
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            usuario != null
                ? 'Olá, ${usuario.nome}!'
                : 'Bem-vindo ao PowerTank!',
            style: const TextStyle(
              fontSize: 24,
              color: Color(0xFF0D47A1),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Divider(color: Colors.grey),
          const SizedBox(height: 20),
          if (favoritos.isNotEmpty)
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 15,
                  runSpacing: 15,
                  children: favoritos.map((card) {
                    return SizedBox(
                      width: 140,
                      height: 170,
                      child: _buildCardFavoritoInicio(card),
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCardsFilialPage() {
    final cardsFilial = [
      {
        'id': 'movimentacoes-filial',
        'icon': Icons.swap_horiz,
        'label': 'Relatório de Saídas',
        'descricao': 'Consultar movimentações da filial',
        'tipo': 'movimentacoes',
      },
    ];

    return _buildPaginaPadronizada(
      titulo: _filialParaFiltroNome ?? 'Filial',
      conteudo: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Wrap(
            spacing: 15,
            runSpacing: 15,
            alignment: WrapAlignment.start,
            children: cardsFilial.map((card) {
              return SizedBox(
                width: 180,
                height: 180,
                child: _HoverScale(
                  child: Material(
                    elevation: 2,
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.hardEdge,
                    child: InkWell(
                      onTap: () {
                        if (card['tipo'] == 'movimentacoes') {
                          if (_filialParaFiltroId == null ||
                              _filialParaFiltroId!.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Filial nao informada para movimentacoes.',
                                ),
                                backgroundColor: Colors.red,
                                duration: Duration(seconds: 3),
                              ),
                            );
                            return;
                          }

                          setState(() {
                            _mostrarFiltrosEstoque = true;
                            _mostrarCardsFilial = false;
                          });
                        }
                      },
                      hoverColor: _getCorPorSessao('Estoques').withOpacity(0.1),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(15),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              card['icon'] as IconData,
                              color: _getCorPorSessao('Estoques'),
                              size: 55,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              card['label'] as String,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF424242),
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
      onVoltar: () {
        setState(() {
          _mostrarCardsFilial = false;
          _mostrarFiliaisDaEmpresa = true;
        });
      },
    );
  }

  Widget _buildFiltrosEstoquePage() {
    return FiltroContabilFisicoPage(
      key: ValueKey('filtros-${_terminalParaFiltroId ?? _filialParaFiltroId}'),
      filialId: _filialParaFiltroId,
      terminalId: _terminalParaFiltroId,
      nomeFilial: _terminalParaFiltroNome ?? _filialParaFiltroNome ?? 'Local',
      empresaId: _empresaParaFiltroId,
      empresaNome: _empresaParaFiltroNome,
      onVoltar: () {
        if (_empresaParaFiltroId != null) {
          setState(() {
            _mostrarFiltrosEstoque = false;
            _mostrarFiliaisDaEmpresa = true;
            _mostrarCardsFilial = false;
          });
        } else {
          setState(() {
            _mostrarFiltrosEstoque = false;
            _mostrarCardsFilial = false;
          });
          _mostrarFilhosDaSessao('Estoques');
        }
      },
      onConsultarContabilFisico:
          ({
            required String? filialId,
            required String? terminalId,
            required String nomeFilial,
            String? empresaId,
            required DateTime dataInicial,
            required DateTime dataFinal,
            String? produtoFiltro,
            required String tipoRelatorio,
          }) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ContabilFisicoPage(
                  filialId: filialId,
                  terminalId: terminalId,
                  nomeFilial: nomeFilial,
                  empresaId: empresaId,
                  dataInicial: dataInicial,
                  dataFinal: dataFinal,
                  produtoFiltro: produtoFiltro,
                  tipoRelatorio: tipoRelatorio,
                ),
              ),
            );
          },
    );
  }

  // Método para adicionar quebras de linha nos nomes longos
  String _formatarNomeMenu(String nomeOriginal) {
    // Mapeia os nomes que precisam de quebra de linha
    final Map<String, String> quebras = {
      'Recursos Humanos': 'Recursos\nHumanos',
      'Gestão de Projetos': 'Gestão de\nProjetos',
      'Suprimentos': 'Suprimentos',
      'Manutenção e ativos': 'Manutenção\ne ativos',
      'Segurança & Compliance': 'Segurança &\nCompliance',
      'Configurações': 'Configurações', // Mantém igual (opcional)
    };

    return quebras[nomeOriginal] ?? nomeOriginal;
  }

  // ─── Submenu + Placeholder ──────────────────────────────────────────────────

  Widget _buildPlaceholderSessao() {
    final cor = _getCorSessaoAtual();
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_getMenuIcon(_sessaoAtual ?? ''), size: 72, color: cor.withOpacity(0.15)),
          const SizedBox(height: 20),
          Text(_sessaoAtual ?? '', style: TextStyle(fontSize: 22, color: cor.withOpacity(0.4), fontWeight: FontWeight.w300, letterSpacing: 1.0)),
          const SizedBox(height: 8),
          Text('Selecione uma opção no menu lateral', style: TextStyle(fontSize: 14, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  Widget _buildSubmenuPanel() {
    final corSessao = _getCorSessaoAtual();
    final isPerdas = _sessaoAtual == 'Perdas e Sobras';
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Colors.grey.shade200),
          left: BorderSide(color: corSessao.withOpacity(0.4), width: 2),
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(2, 0))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: corSessao.withOpacity(0.08),
              border: Border(bottom: BorderSide(color: corSessao.withOpacity(0.15))),
            ),
            child: Row(
              children: [
                if (isPerdas)
                  InkWell(
                    onTap: () => setState(() {
                      _sessaoAtual = 'Operação';
                      _filhosSessaoAtual = List.from((_filhosPorSessao['Operação'] ?? []).where((c) => c['tipo'] != 'temp_dens_media').toList());
                      _filhoSelecionadoTipo = null;
                    }),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(Icons.arrow_back_ios, color: corSessao, size: 14),
                    ),
                  ),
                Icon(_getMenuIcon(_sessaoAtual ?? ''), color: corSessao, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _sessaoAtual ?? '',
                    style: TextStyle(fontSize: 12, color: corSessao, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: _filhosSessaoAtual.length,
              itemBuilder: (context, index) => _buildSubmenuItem(_filhosSessaoAtual[index], corSessao),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmenuItem(Map<String, dynamic> card, Color corSessao) {
    final usuario = UsuarioAtual.instance;
    final cardId = card['id']?.toString();
    final naoPermitido = usuario != null && cardId != null && !usuario.podeAcessarCard(cardId);
    final tipo = card['tipo']?.toString() ?? '';
    final isActive = _isSubmenuItemActive(tipo);
    return MouseRegion(
      cursor: naoPermitido ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
      child: InkWell(
        onTap: naoPermitido ? null : () => _navegarParaCardFilho(card),
        hoverColor: naoPermitido ? Colors.transparent : corSessao.withOpacity(0.07),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? corSessao.withOpacity(0.08) : Colors.transparent,
            border: Border(left: BorderSide(color: isActive ? corSessao : Colors.transparent, width: 3)),
          ),
          child: Row(
            children: [
              Transform.scale(
                scaleY: card['icon_inverted'] == true ? -1 : 1,
                child: Icon(
                  card['icon'] as IconData,
                  size: 17,
                  color: naoPermitido ? Colors.grey.shade400 : (isActive ? corSessao : Colors.grey.shade600),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  card['label']?.toString() ?? '',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: naoPermitido ? Colors.grey.shade400 : (isActive ? corSessao : Colors.grey.shade800),
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (naoPermitido) Icon(Icons.lock_outline, size: 13, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  bool _isSubmenuItemActive(String tipo) {
    switch (tipo) {
      case 'ordens_analise': return _mostrarOrdensAnalise;
      case 'historico_cacl': return _mostrarHistorico;
      case 'tabelas_conversao': return showConversaoList;
      case 'tanques': return _mostrarTanques;
      case 'estoque_por_tanque': return _mostrarEstoquePorTanque;
      case 'perdas_sobras': return _sessaoAtual == 'Perdas e Sobras';
      case 'estoque_produto': return _mostrarEstoqueProduto;
      case 'controle_aditivo': return _mostrarFiltroControleAditivo || _mostrarControleAditivo;
      case 'resultados': return _mostrarResultadoMensal;
      case 'registro_preset': return _mostrarRegistroPreset;
      case 'calculadora_arqueacao': return _mostrarCalculadoraArqueacao;
      case 'estoque_fiscal': return _mostrarFiltrosEstoque;
      case 'movimentacao_por_empresa': return _mostrarEstoquePorEmpresa;
      case 'acompanhar_ordem': return _mostrarAcompanhamentoOrdens;
      case 'criar_ordem': return _filhoSelecionadoTipo == 'criar_ordem';
      case 'radar': return _filhoSelecionadoTipo == 'radar';
      case 'veiculos': return _mostrarVeiculos;
      case 'motoristas': return _mostrarMotoristas;
      case 'transportadoras': return _mostrarTransportadoras;
      case 'movimentacoes': return _mostrarFiltroMovimentacoes;
      case 'tabela_precos_refinaria': return _filhoSelecionadoTipo == 'tabela_precos_refinaria';
      case 'ordem_bombeio': return _filhoSelecionadoTipo == 'ordem_bombeio';
      case 'frascos_amostra': return _mostrarFrascosAmostra;
      case 'temp_dens_media': return _mostrarTempDensMedia;
      case 'conta_corrente_refinarias': return _mostrarContaCorrenteRefinarias;
      case 'downloads': return _mostrarDownloads;
      case 'suporte': return _mostrarSuporte;
      case 'fila_solicitacoes': return _mostrarFilaSolicitacoes;
      case 'acesso_desenvolvedor': return _mostrarAcessoDesenvolvedor;
      case 'controle_acesso': return showControleAcesso;
      case 'usuarios': return showUsuarios;
      default: return false;
    }
  }

  bool _isAnyChildPageOpen() {
    return _mostrarOrdensAnalise ||
        _mostrarHistorico ||
        showConversaoList ||
        _mostrarTanques ||
        _mostrarEstoquePorTanque ||
        _mostrarEstoqueProduto ||
        _mostrarFiltroControleAditivo ||
        _mostrarControleAditivo ||
        _mostrarResultadoMensal ||
        _mostrarRegistroPreset ||
        _mostrarCalculadoraArqueacao ||
        _mostrarFiltrosEstoque ||
        _mostrarEstoquePorEmpresa ||
        _mostrarAcompanhamentoOrdens ||
        _filhoSelecionadoTipo != null ||
        _mostrarVeiculos ||
        _mostrarDetalhesVeiculo ||
        _mostrarMotoristas ||
        _mostrarTransportadoras ||
        _mostrarFiltroMovimentacoes ||
        _mostrarFrascosAmostra ||
        _mostrarTempDensMedia ||
        _mostrarContaCorrenteRefinarias ||
        _mostrarDownloads ||
        _mostrarSuporte ||
        _mostrarFilaSolicitacoes ||
        _mostrarAcessoDesenvolvedor ||
        showControleAcesso ||
        showUsuarios ||
        _mostrarCardsFilial ||
        _mostrarFiliaisDaEmpresa ||
        _mostrarEscolherTerminal ||
        _mostrarMedicaoTanques ||
        _mostrarListarCacls ||
        _mostrarGestaoBombeios ||
        _mostrarCalcGerado;
  }

  void _navegarParaCardSuporte(String tipo) {
    switch (tipo) {
      case 'suporte': setState(() => _mostrarSuporte = true); break;
      case 'desenvolvedor': Navigator.push(context, MaterialPageRoute(builder: (context) => const DesenvolvedorPage())); break;
      case 'fila_solicitacoes': setState(() => _mostrarFilaSolicitacoes = true); break;
      case 'acesso_desenvolvedor': _showLoginDevDialog(); break;
    }
  }

  void _navegarParaCardConfiguracoes(String tipo) {
    switch (tipo) {
      case 'controle_acesso': setState(() => showControleAcesso = true); break;
      case 'usuarios': setState(() => showUsuarios = true); break;
    }
  }
}

/// Widget para exibir cards de uma sessão específica
class HomeCards extends StatelessWidget {
  final String menuSelecionado;
  final void Function(BuildContext context, String tipo) onCardSelecionado;
  final Function() onVoltar;

  const HomeCards({
    super.key,
    required this.menuSelecionado,
    required this.onCardSelecionado,
    required this.onVoltar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
                onPressed: onVoltar,
                tooltip: 'Voltar ao menu principal',
              ),
              const SizedBox(width: 10),
              Text(
                menuSelecionado,
                style: const TextStyle(
                  fontSize: 24,
                  color: Color(0xFF0D47A1),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: Colors.grey),
          const SizedBox(height: 20),

          Expanded(child: _buildCardsConteudo(context)),
        ],
      ),
    );
  }

  Widget _buildCardsConteudo(BuildContext context) {
    switch (menuSelecionado) {
      case 'Suporte':
        return _buildCardsSuportes(context);
      default:
        return const Center(
          child: Text(
            'Conteúdo em construção...',
            style: TextStyle(color: Colors.grey),
          ),
        );
    }
  }

  Widget _buildCardsSuportes(BuildContext context) {
    final List<Map<String, dynamic>> cards = [
      {
        'titulo': 'Suporte',
        'descricao': 'Central de suporte, FAQs e contato com suporte técnico',
        'icone': Icons.support_agent,
        'cor': const Color(0xFF0D47A1),
        'tipo': 'suporte',
      },
      {
        'titulo': 'O Desenvolvedor',
        'descricao': 'Dê sua contribuição para o projeto',
        'icone': Icons.architecture,
        'cor': const Color(0xFF0D47A1),
        'tipo': 'desenvolvedor',
      },
      {
        'titulo': 'Fila de solicitações',
        'descricao': 'Acompanhe o andamento das suas solicitações',
        'icone': Icons.receipt_long,
        'cor': const Color(0xFF0D47A1),
        'tipo': 'fila_solicitacoes',
      },
      {
        'titulo': 'Acesso Desenvolvedor',
        'descricao': 'Gerenciamento e acesso de desenvolvedor',
        'icone': Icons.developer_mode,
        'cor': const Color(0xFF0D47A1),
        'tipo': 'acesso_desenvolvedor',
      },
    ];

    return GridView.count(
      crossAxisCount: 7,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      childAspectRatio: 1,
      children: cards.map((card) => _buildCardItem(card, context)).toList(),
    );
  }

  Widget _buildCardItem(Map<String, dynamic> card, BuildContext context) {
    return _HoverScale(
      child: Material(
        elevation: 2,
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          onTap: () => _handleCardTap(context, card['tipo']),
          hoverColor: const Color(0xFFE8F5E9),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  card['icone'] as IconData,
                  color: card['cor'] as Color,
                  size: 50,
                ),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 35, maxHeight: 35),
                  child: Center(
                    child: Text(
                      card['titulo'],
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF0D47A1),
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleCardTap(BuildContext context, String tipo) {
    onCardSelecionado(context, tipo);
  }
}

/// Widget privado para efeito de crescimento ao passar o mouse
class _HoverScale extends StatefulWidget {
  final Widget child;

  const _HoverScale({required this.child});

  @override
  State<_HoverScale> createState() => _HoverScaleState();
}

class _HoverScaleState extends State<_HoverScale> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedScale(
        scale: _isHovering ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
