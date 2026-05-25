import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_page.dart';
import '../operacao/certificado_apuracao_saida.dart';
import '../operacao/certificado_apuracao_entrada.dart';

/// Flight-controller-style dashboard for the Circuito session.
/// Shows every vehicle as a tiny chip organised in 4 stage columns.
class VisaoGeralCircuitoPage extends StatefulWidget {
  final VoidCallback onVoltar;

  const VisaoGeralCircuitoPage({super.key, required this.onVoltar});

  @override
  State<VisaoGeralCircuitoPage> createState() => _VisaoGeralCircuitoPageState();
}

class _VisaoGeralCircuitoPageState extends State<VisaoGeralCircuitoPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _carregando = true;
  bool _erro = false;
  String _mensagemErro = '';
  String? _usuarioTerminalId;

  // ── Controles ────────────────────────────────────────────────────────────
  bool _mostrarPorProduto = false;
  bool _isDarkMode = false;
  bool _mostrarFilaCarga = true; // true para Carga, false para Descarga
  String _filtroBusca = '';
  String _empresaSelecionada = 'Todas';
  String _tipoOpSelecionada = 'Todos';
  final TextEditingController _searchCtrl = TextEditingController();

  List<String> _empresas = ['Todas'];
  static const List<String> _tiposOp = ['Todos', 'Carga', 'Descarga'];

  // ── Estágios (apenas para UI, não armazena estado) ───────────────────────
  static const List<_ColunaInfo> _colunas = [
    _ColunaInfo(
      titulo: 'Programados',
      cor: Color(0xFF1565C0),
      corFundo: Color(0xFF0D1B2A),
      statusNecessario: '1',
    ),
    _ColunaInfo(
      titulo: 'Em Fila',
      cor: Color(0xFFE65100),
      corFundo: Color(0xFF1A1200),
      statusNecessario: '2',
    ),
    _ColunaInfo(
      titulo: 'Em Operação',
      cor: Color(0xFF4A148C),
      corFundo: Color(0xFF0E001A),
      statusNecessario: '3',
    ),
    _ColunaInfo(
      titulo: 'Liberados',
      cor: Color(0xFF2E7D32),
      corFundo: Color(0xFF001A02),
      statusNecessario: '4',
    ),
  ];

  // ── Dados ─────────────────────────────────────────────────────────────────
  List<_Veiculo> _veiculos = [];

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() {
      _carregando = true;
      _erro = false;
    });

    try {
      final usuario = UsuarioAtual.instance;
      if (usuario == null) throw Exception('Usuário não autenticado');

      _usuarioTerminalId = usuario.terminalId;

      if (_usuarioTerminalId == null || _usuarioTerminalId!.isEmpty) {
        setState(() {
          _veiculos = [];
          _carregando = false;
        });
        return;
      }

      // Carregar empresas vinculadas ao terminal
      final relacoesResponse = await _supabase
          .from('relacoes_terminais')
          .select('empresas!inner(nome_dois)')
          .eq('terminal_id', _usuarioTerminalId!);

      final List<String> empresasVinculadas = ['Todas'];
      for (var item in (relacoesResponse as List)) {
        final nome = item['empresas']?['nome_dois']?.toString();
        if (nome != null && !empresasVinculadas.contains(nome)) {
          empresasVinculadas.add(nome);
        }
      }

      final response = await _supabase
          .from('movimentacoes')
          .select('''
            id,
            ordem_id,
            placa,
            cliente,
            tipo_op,
            status_circuito_orig,
            status_circuito_dest,
            data_mov,
            entrada_amb,
            saida_amb,
            motoristas!motorista_id(nome),
            transportadoras!transportadora_id(nome),
            produtos!produto_id(nome_dois),
            empresas!empresa_id(nome_dois),
            ordens!ordem_id!inner(id, terminal_id_orig, terminal_id_dest, status_term_orig, status_term_dest, posicao_fila)
          ''')
          .or('terminal_id_orig.eq.$_usuarioTerminalId,terminal_id_dest.eq.$_usuarioTerminalId',
              referencedTable: 'ordens')
          .order('ordens(posicao_fila)', ascending: true, nullsFirst: false)
          .order('data_mov', ascending: false);

      final List<dynamic> data = response as List<dynamic>;

      // Agrupando movimentações por ordem_id
      final Map<String, List<dynamic>> ordensAgrupadas = {};
      for (var item in data) {
        final ordemId = item['ordem_id']?.toString() ?? 'sem_ordem';
        if (!ordensAgrupadas.containsKey(ordemId)) {
          ordensAgrupadas[ordemId] = [];
        }
        ordensAgrupadas[ordemId]!.add(item);
      }

      final novosVeiculos = ordensAgrupadas.entries.map((entry) {
        final itens = entry.value;
        final primeiroItem = itens.first;

        // Lógica para cliente: se tipo_op for 'transf', usa o nome_dois da tabela empresas
        final tipoOp = primeiroItem['tipo_op']?.toString() ?? '';
        String clienteFinal = primeiroItem['cliente']?.toString() ?? 'N/A';

        if (tipoOp.toLowerCase() == 'transf') {
          clienteFinal =
              primeiroItem['empresas']?['nome_dois']?.toString() ??
              clienteFinal;
        }

        // Trata o campo placa que é text[] no banco
        final placasRaw = primeiroItem['placa'];
        String placaLinha1 = '';
        String placaLinha2 = 'SEM PLACA';
        String placaCompleta = '';

        if (placasRaw is List && placasRaw.isNotEmpty) {
          placaCompleta = placasRaw.join(' / ');
          if (placasRaw.length >= 3) {
            placaLinha1 = placasRaw.first.toString();
            final ultimas = placasRaw.sublist(placasRaw.length - 2);
            placaLinha2 = ultimas.join(' / ');
          } else {
            placaLinha1 = '';
            placaLinha2 = placasRaw.join(' / ');
          }
        } else if (placasRaw is String) {
          placaLinha1 = '';
          placaLinha2 = placasRaw;
          placaCompleta = placasRaw;
        }

        final isOrigem =
            primeiroItem['ordens']?['terminal_id_orig']?.toString() ==
            _usuarioTerminalId;
        final isDestino =
            primeiroItem['ordens']?['terminal_id_dest']?.toString() ==
            _usuarioTerminalId;

        final statusTermOrig =
            primeiroItem['ordens']?['status_term_orig']?.toString() ?? '1';
        final statusTermDest =
            primeiroItem['ordens']?['status_term_dest']?.toString() ?? '1';

        // Determina o status baseado no terminal do usuário
        String statusAtual = '1';
        if (isOrigem) {
          statusAtual = statusTermOrig;
        } else if (isDestino) {
          statusAtual = statusTermDest;
        }

        // Mapeia produtos e quantidades de todas as movimentações desta ordem
        final numberFormat = NumberFormat.decimalPattern('pt_BR');
        final produtos = itens.map((i) {
          final isSaida =
              i['tipo_mov'] == 'saida' ||
              i['saida_amb'] != null && (i['saida_amb'] as num) > 0;
          final num quantidadeValue = isSaida
              ? (i['saida_amb'] ?? 0)
              : (i['entrada_amb'] ?? 0);

          return _ProdutoItem(
            nome: i['produtos']?['nome_dois']?.toString() ?? 'N/A',
            quantidade: numberFormat.format(quantidadeValue),
          );
        }).toList();

        final vendedor =
            primeiroItem['empresas']?['nome_dois']?.toString() ?? 'N/A';
        final comprador = primeiroItem['cliente']?.toString() ?? 'N/A';

        return _Veiculo(
          id: primeiroItem['id']?.toString() ?? '',
          ordemId: entry.key,
          terminalIdOrig:
              primeiroItem['ordens']?['terminal_id_orig']?.toString(),
          terminalIdDest:
              primeiroItem['ordens']?['terminal_id_dest']?.toString(),
          placa: placaLinha2,
          placaLinha1: placaLinha1,
          placaCompleta: placaCompleta,
          produtos: produtos,
          empresa: clienteFinal,
          tipoOp: tipoOp,
          statusAtual: statusAtual,
          motorista: primeiroItem['motoristas']?['nome']?.toString() ?? 'N/A',
          transportadora:
              primeiroItem['transportadoras']?['nome']?.toString() ?? 'N/A',
          dataCriacao: primeiroItem['data_mov']?.toString() ?? 'N/A',
          posicaoFila: primeiroItem['ordens']?['posicao_fila']?.toString(),
          vendedor: vendedor,
          comprador: comprador,
        );
      }).toList();

      setState(() {
        _empresas = empresasVinculadas;
        // Reset da empresa selecionada caso ela não esteja mais na lista
        if (!_empresas.contains(_empresaSelecionada)) {
          _empresaSelecionada = 'Todas';
        }
        _veiculos = novosVeiculos;
        _carregando = false;
      });
    } catch (e) {
      setState(() {
        _erro = true;
        _mensagemErro = e.toString();
        _carregando = false;
      });
    }
  }

  List<_Veiculo> _veiculosPorStatus(String status, {String? subFila}) {
    return _veiculos.where((v) {
      if (v.statusAtual != status) return false;

      // Se for status "Em Fila" (2) e houver subFila especificada
      if (status == '2' && subFila != null) {
        final isCarga = v.terminalIdOrig == _usuarioTerminalId;
        if (subFila == 'carga' && !isCarga) return false;
        if (subFila == 'descarga' && isCarga) return false;
      }

      // Filtro de Empresa
      if (_empresaSelecionada != 'Todas' && v.empresa != _empresaSelecionada) {
        return false;
      }

      // Filtro de Tipo Op
      if (_tipoOpSelecionada != 'Todos') {
        final isCarga = v.terminalIdOrig == _usuarioTerminalId;
        final tipoSelecionado = _tipoOpSelecionada.toLowerCase();

        if (tipoSelecionado == 'carga' && !isCarga) return false;
        if (tipoSelecionado == 'descarga' && isCarga) return false;
      }

      // Filtro de Busca (Placa ou Produto)
      if (_filtroBusca.isEmpty) return true;
      final busca = _filtroBusca.toLowerCase();
      final placaMatch =
          v.placa.toLowerCase().contains(busca) ||
          v.placaLinha1.toLowerCase().contains(busca);

      final produtoMatch = v.produtos.any(
        (p) => p.nome.toLowerCase().contains(busca),
      );

      return placaMatch || produtoMatch;
    }).toList();
  }

  Future<void> _atualizarStatus(_Veiculo v, String novoStatus) async {
    if (v.ordemId.isEmpty) return;

    try {
      final Map<String, dynamic> updates = {};

      if (_usuarioTerminalId != null && _usuarioTerminalId!.isNotEmpty) {
        if (v.terminalIdOrig == _usuarioTerminalId) {
          updates['status_term_orig'] = novoStatus;
        } else if (v.terminalIdDest == _usuarioTerminalId) {
          updates['status_term_dest'] = novoStatus;
        }
      }

      // Logica de fila baseada na solicitação
      if (v.statusAtual == '1' && novoStatus == '2') {
        // "Enviar para fila"
        updates['posicao_fila'] = DateTime.now().toUtc().toIso8601String();
      } else if ((v.statusAtual == '2' &&
          (novoStatus == '1' || novoStatus == '3'))) {
        // "Sair da fila" ou "Enviar para operação"
        updates['posicao_fila'] = null;
      }

      await _supabase.from('ordens').update(updates).eq('id', v.ordemId);

      if (mounted) {
        Navigator.pop(context);
        _carregarDados();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao atualizar status: $e')));
      }
    }
  }

  Future<bool> _verificarCertificadoEmitido(_Veiculo v) async {
    try {
      final isSaida = v.terminalIdOrig == _usuarioTerminalId;
      final tipoBusca = isSaida ? 'origem' : 'destino';

      final response = await _supabase
          .from('movimentacoes')
          .select('id')
          .eq('ordem_id', v.ordemId)
          .limit(1)
          .maybeSingle();

      if (response == null) return false;
      final movimentacaoId = response['id']?.toString();
      if (movimentacaoId == null) return false;

      final analises = await _supabase
          .from('ordens_analises')
          .select('id')
          .eq('movimentacao_id', movimentacaoId)
          .eq('tipo_analise', tipoBusca)
          .limit(1);

      return (analises as List).isNotEmpty;
    } catch (e) {
      debugPrint('Erro ao verificar certificado: $e');
      return false;
    }
  }

  void _mostrarDetalhesVeiculo(_Veiculo v) async {
    final bool certificadoEmitido = await _verificarCertificadoEmitido(v);

    if (!mounted) return;

    String dataFormatada = v.dataCriacao;
    try {
      final data = DateTime.parse(v.dataCriacao);
      dataFormatada =
          '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
    } catch (_) {}

    String operacaoTexto = v.tipoOp;
    if (v.tipoOp.toLowerCase() == 'transf') {
      operacaoTexto = 'Transferência';
    } else if (v.tipoOp.toLowerCase() == 'compra') {
      operacaoTexto = 'Compra';
    } else if (v.tipoOp.toLowerCase() == 'venda') {
      operacaoTexto = 'Venda comum';
    } else if (v.tipoOp.toLowerCase() == 'carga') {
      operacaoTexto = 'Carga';
    } else if (v.tipoOp.toLowerCase() == 'descarga') {
      operacaoTexto = 'Descarga';
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'DETALHES DO VEÍCULO',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF455A64),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Icon(
                        Icons.close,
                        size: 22,
                        color: Color(0xFFC62828),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              _buildInfoRow('Placa:', v.placaCompleta),
              _buildInfoRow('Motorista:', v.motorista),
              _buildInfoRow('Transportadora:', v.transportadora),
              _buildInfoRow('Empresa:', v.empresa),
              _buildInfoRow('Operação:', operacaoTexto),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Produtos:',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
              ...v.produtos.map(
                (p) => Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _obterCorProduto(p.nome),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${p.nome} — ${p.quantidade}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Color(0xFF263238),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _buildInfoRow('Data Criação:', dataFormatada),
              const SizedBox(height: 20),
              if (v.statusAtual == '1') ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.check_circle_outline,
                        color: Colors.green,
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Check-list ok',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: () => _atualizarStatus(v, '2'),
                    icon: const Icon(Icons.queue, size: 18),
                    label: const Text(
                      'ENVIAR PARA FILA',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade800,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ] else if (v.statusAtual == '2') ...[
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: () => _atualizarStatus(v, '3'),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text(
                      'ENVIAR PARA OPERAÇÃO',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: OutlinedButton.icon(
                    onPressed: () => _atualizarStatus(v, '1'),
                    icon: const Icon(Icons.exit_to_app, size: 18),
                    label: const Text(
                      'SAIR DA FILA',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade700),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ] else if (v.statusAtual == '3') ...[
                if (v.terminalIdOrig == _usuarioTerminalId)
                  _buildTimelineStatus(v),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: () => _abrirCertificadoApuracao(v),
                    icon: Icon(
                      certificadoEmitido
                          ? Icons.check_circle_outline
                          : Icons.description_outlined,
                      size: 18,
                    ),
                    label: Text(
                      certificadoEmitido
                          ? 'CERTIFICADO EMITIDO'
                          : 'EMITIR CERTIFICADO DE APURAÇÃO',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          certificadoEmitido ? Colors.green : Colors.blueGrey,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                if (certificadoEmitido) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Ação de liberar futuramente
                      },
                      icon: const Icon(Icons.local_shipping_outlined, size: 18),
                      label: const Text(
                        'LIBERAR VEÍCULO',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: OutlinedButton.icon(
                    onPressed: certificadoEmitido
                        ? null
                        : () => _confirmarCancelamentoOperacao(v),
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text(
                      'CANCELAR OPERAÇÃO',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade800,
                      disabledForegroundColor: Colors.grey.shade400,
                      side: BorderSide(
                        color: certificadoEmitido
                            ? Colors.grey.shade400
                            : Colors.red.shade800,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ] else if (v.statusAtual == '4') ...[
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.description_outlined, size: 18),
                    label: const Text(
                      'CERTIFICADO DE APURAÇÃO',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                      disabledBackgroundColor: Colors.grey.shade300,
                      disabledForegroundColor: Colors.grey.shade500,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _abrirCertificadoApuracao(_Veiculo v) async {
    try {
      final isSaida = v.terminalIdOrig == _usuarioTerminalId;

      if (isSaida) {
        // FLUXO DE SAÍDA: certificado_apuracao_saida
        final response = await _supabase
            .from('movimentacoes')
            .select(
                'id, produtos!produto_id(id, nome, nome_dois), saida_amb, saida_vinte')
            .eq('ordem_id', v.ordemId)
            .order('id', ascending: true);

        final List<dynamic> movimentacoes = response as List<dynamic>;
        if (movimentacoes.isEmpty) return;

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

        final analises = await _supabase
            .from('ordens_analises')
            .select('id, tipo_analise')
            .eq('movimentacao_id', movimentacaoId)
            .eq('tipo_analise', 'origem');

        bool modoSomenteVisualizacao = false;
        String? idAnaliseExistente;

        for (var analise in analises) {
          final tipoAnalise =
              analise['tipo_analise']?.toString().toLowerCase() ?? '';
          if (tipoAnalise.contains('origem')) {
            modoSomenteVisualizacao = true;
            idAnaliseExistente = analise['id']?.toString();
            break;
          }
        }

        if (!mounted) return;
        Navigator.pop(context);

        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EmitirCertificadoPage(
              idCertificado: idAnaliseExistente,
              idMovimentacao: movimentacaoId,
              tanquesDaOrdem: tanquesDaOrdem,
              terminalId: v.terminalIdOrig,
              tipoOp: v.tipoOp,
              onVoltar: () {
                Navigator.of(context).pop(true);
              },
              modoSomenteVisualizacao: modoSomenteVisualizacao,
            ),
          ),
        );
      } else {
        // FLUXO DE ENTRADA: certificado_apuracao_entrada
        final response = await _supabase
            .from('movimentacoes')
            .select('id')
            .eq('ordem_id', v.ordemId)
            .limit(1)
            .maybeSingle();

        if (response == null) return;
        final movimentacaoId = response['id']?.toString();
        if (movimentacaoId == null) return;

        // Verifica se existe análise com "destino"
        final analises = await _supabase
            .from('ordens_analises')
            .select('id, tipo_analise')
            .eq('movimentacao_id', movimentacaoId)
            .eq('tipo_analise', 'destino');

        bool modoSomenteVisualizacao = false;
        String? idAnaliseExistente;

        for (var analise in analises) {
          final tipoAnalise =
              analise['tipo_analise']?.toString().toLowerCase() ?? '';
          if (tipoAnalise.contains('destino')) {
            modoSomenteVisualizacao = true;
            idAnaliseExistente = analise['id']?.toString();
            break;
          }
        }

        if (!mounted) return;
        Navigator.pop(context);

        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EmitirCertificadoEntrada(
              onVoltar: () {
                Navigator.of(context).pop(true);
              },
              terminalId: v.terminalIdDest ?? '',
              dataFiltro: DateFormat('dd/MM/yyyy').format(DateTime.now()),
              idMovimentacao: movimentacaoId,
              modoSomenteVisualizacao: modoSomenteVisualizacao,
              idAnaliseExistente: idAnaliseExistente,
            ),
          ),
        );
      }

      _carregarDados();
    } catch (e) {
      debugPrint('Erro ao abrir certificado: $e');
    }
  }

  void _confirmarCancelamentoOperacao(_Veiculo v) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.red, width: 1),
        ),
        child: Container(
          width: 200, // Largura reduzida conforme solicitado
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.red,
                size: 32,
              ),
              const SizedBox(height: 12),
              const Text(
                'ATENÇÃO',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Ao cancelar, o veículo voltará para "Programados".',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _atualizarStatus(v, '1');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
                    'SIM, PROSSEGUIR',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    side: BorderSide(color: Colors.grey.shade400),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
                    'VOLTAR',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineStatus(_Veiculo v) {
    bool isVenda = v.tipoOp.toLowerCase() == 'venda';
    // Se isVenda: NF -> Carregamento
    // Se !isVenda (transf): Carregamento -> NF

    String etapa1Label = isVenda ? 'NF emitida' : 'CARREGAMENTO';
    String etapa2Label = isVenda ? 'CARREGAMENTO' : 'NF emitida';

    // Para fins de visualização, como o statusAtual é '3' (Em Operação),
    // vamos assumir que a primeira etapa está ocorrendo ou concluída, 
    // e a segunda ainda vai ocorrer.
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'STATUS DA OPERAÇÃO',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Color(0xFF455A64),
            ),
          ),
        ),
        Row(
          children: [
            _buildTimelineStep(etapa1Label, true, true),
            Container(
              width: 40,
              height: 2,
              color: Colors.grey.shade300,
            ),
            _buildTimelineStep(etapa2Label, false, false),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTimelineStep(String label, bool isCurrent, bool isCompleted) {
    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isCompleted ? Colors.green : (isCurrent ? Colors.blue : Colors.grey.shade300),
            shape: BoxShape.circle,
            border: isCurrent ? Border.all(color: Colors.blue.shade800, width: 2) : null,
          ),
          child: Icon(
            isCompleted ? Icons.check : (isCurrent ? Icons.play_arrow : Icons.schedule),
            size: 14,
            color: isCompleted || isCurrent ? Colors.white : Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            color: isCurrent ? Colors.blue.shade900 : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF263238),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _obterCorProduto(String nomeProduto) {
    final Map<String, Color> mapeamentoExato = {
      'G. Comum': const Color(0xFFFF6B35),
      'G. Aditivada': const Color(0xFF00A8E8),
      'Gasolina A': const Color(0xFFE91E63),
      'S500': const Color(0xFF8D6A9F),
      'S10': const Color(0xFF2E294E),
      'S500 A': const Color(0xFF9C27B0),
      'S10 A': const Color(0xFF673AB7),
      'Hidratado': const Color(0xFF83B692),
      'Anidro': const Color(0xFF4CAF50),
      'B100': const Color(0xFF8BC34A),
    };

    if (mapeamentoExato.containsKey(nomeProduto)) {
      return mapeamentoExato[nomeProduto]!;
    }

    final nomeLower = nomeProduto.toLowerCase();
    for (var entry in mapeamentoExato.entries) {
      if (entry.key.toLowerCase() == nomeLower) {
        return entry.value;
      }
    }

    if (nomeLower.contains('comum')) {
      return const Color(0xFFFF6B35);
    } else if (nomeLower.contains('aditivada')) {
      return const Color(0xFF00A8E8);
    } else if (nomeLower.contains('s500')) {
      if (nomeLower.contains(' a')) {
        return const Color(0xFF9C27B0);
      }
      return const Color(0xFF8D6A9F);
    } else if (nomeLower.contains('s10')) {
      if (nomeLower.contains(' a')) {
        return const Color(0xFF673AB7);
      }
      return const Color(0xFF2E294E);
    } else if (nomeLower.contains('hidratado')) {
      return const Color(0xFF83B692);
    } else if (nomeLower.contains('anidro')) {
      return const Color(0xFF4CAF50);
    } else if (nomeLower.contains('b100')) {
      return const Color(0xFF8BC34A);
    } else if (nomeLower.contains('gasolina a')) {
      return const Color(0xFFE91E63);
    } else if (nomeLower.contains('etanol')) {
      return const Color(0xFF83B692);
    }

    return Colors.grey.shade600;
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_erro) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text('Erro ao carregar dados: $_mensagemErro'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _carregarDados,
                child: const Text('Tentar Novamente'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: widget.onVoltar,
                child: const Text('Voltar'),
              ),
            ],
          ),
        ),
      );
    }

    final bodyColor = _isDarkMode
        ? const Color(0xFF0A0F1A)
        : const Color(0xFFF1F5F9);
    return Scaffold(
      backgroundColor: bodyColor,
      body: Column(
        children: [
          _buildCabecalho(),
          _buildBarraControles(),
          Expanded(child: _buildGrid()),
        ],
      ),
    );
  }

  Widget _buildBarraControles() {
    final bgColor = _isDarkMode ? const Color(0xFF0F172A) : Colors.white;
    final borderColor = _isDarkMode
        ? const Color(0xFF1F2937)
        : const Color(0xFFE2E8F0);
    final textColor = _isDarkMode ? Colors.white : const Color(0xFF1E293B);
    final subTextColor = _isDarkMode ? Colors.white38 : Colors.black45;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: Row(
        children: [
          Text(
            '"Por produto"',
            style: TextStyle(
              color: textColor.withValues(alpha: 0.7),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: _mostrarPorProduto,
              activeThumbColor: const Color(0xFF2196F3),
              onChanged: (val) => setState(() => _mostrarPorProduto = val),
            ),
          ),
          const SizedBox(width: 16),
          _buildDropdown(
            label: 'Empresa',
            value: _empresaSelecionada,
            items: _empresas,
            textColor: textColor,
            subTextColor: subTextColor,
            onChanged: (val) => setState(() => _empresaSelecionada = val!),
          ),
          const SizedBox(width: 16),
          _buildDropdown(
            label: 'Tipo Op.',
            value: _tipoOpSelecionada,
            items: _tiposOp,
            textColor: textColor,
            subTextColor: subTextColor,
            onChanged: (val) => setState(() => _tipoOpSelecionada = val!),
          ),
          const SizedBox(width: 16),
          VerticalDivider(color: borderColor, indent: 12, endIndent: 12),
          const SizedBox(width: 16),
          Text(
            'Pesquisar:',
            style: TextStyle(color: subTextColor, fontSize: 12),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 200,
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => setState(() => _filtroBusca = val),
              style: TextStyle(
                color: _isDarkMode ? Colors.black : textColor,
                fontSize: 13,
              ),
              decoration: InputDecoration(
                filled: _isDarkMode,
                fillColor: _isDarkMode ? Colors.white : Colors.transparent,
                hintText: 'Placa ou produto...',
                hintStyle: TextStyle(
                  color: _isDarkMode
                      ? Colors.black38
                      : subTextColor.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide.none,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 8,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 16,
                  color: _isDarkMode ? Colors.black45 : subTextColor,
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 32),
              ),
            ),
          ),
          if (_filtroBusca.isNotEmpty)
            IconButton(
              icon: Icon(Icons.close, size: 16, color: subTextColor),
              onPressed: () {
                _searchCtrl.clear();
                setState(() => _filtroBusca = '');
              },
            ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required Color textColor,
    required Color subTextColor,
    required ValueChanged<String?> onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label:', style: TextStyle(color: subTextColor, fontSize: 12)),
        const SizedBox(width: 8),
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            dropdownColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            icon: Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: subTextColor,
            ),
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            onChanged: onChanged,
            items: items.map((String item) {
              return DropdownMenuItem<String>(value: item, child: Text(item));
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCabecalho() {
    final total = _veiculos.length;
    final bgColor = _isDarkMode ? const Color(0xFF111827) : Colors.white;
    final textColor = _isDarkMode ? Colors.white : const Color(0xFF1E293B);
    final borderColor = _isDarkMode
        ? const Color(0xFF1F2937)
        : const Color(0xFFE2E8F0);

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: textColor.withValues(alpha: 0.7),
              size: 20,
            ),
            tooltip: 'Voltar',
            onPressed: widget.onVoltar,
          ),
          const SizedBox(width: 8),
          Text(
            'VISÃO GERAL — CIRCUITO',
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: textColor.withValues(alpha: 0.7),
              size: 20,
            ),
            tooltip: 'Atualizar dados',
            onPressed: _carregarDados,
          ),
          const SizedBox(width: 8),
          Row(
            children: [
              Icon(
                _isDarkMode
                    ? Icons.dark_mode_outlined
                    : Icons.light_mode_outlined,
                size: 18,
                color: textColor.withOpacity(0.5),
              ),
              const SizedBox(width: 4),
              Transform.scale(
                scale: 0.7,
                child: Switch(
                  value: _isDarkMode,
                  activeThumbColor: const Color(0xFF2196F3),
                  onChanged: (val) => setState(() => _isDarkMode = val),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          _badgeTotal(total, textColor, borderColor),
        ],
      ),
    );
  }

  Widget _badgeTotal(int total, Color textColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1F2937) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        '$total veículos',
        style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 11),
      ),
    );
  }

  Widget _buildGrid() {
    final borderColor = _isDarkMode
        ? const Color(0xFF1F2937)
        : const Color(0xFFE2E8F0);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(
        _colunas.length,
        (i) => Expanded(child: _buildColuna(i, borderColor)),
      ),
    );
  }

  Widget _buildColuna(int colunaIndex, Color borderColor) {
    final coluna = _colunas[colunaIndex];
    final colColor = _isDarkMode ? coluna.corFundo : Colors.white;

    if (colunaIndex == 1) {
      // Coluna "Em Fila" (status 2) - Filtrada pelo switch
      final veiculosFila = _veiculosPorStatus(
        '2',
        subFila: _mostrarFilaCarga ? 'carga' : 'descarga',
      );

      return Container(
        decoration: BoxDecoration(
          color: colColor,
          border: Border(right: BorderSide(color: borderColor, width: 1)),
        ),
        child: Column(
          children: [
            _buildCabecalhoColunaFila(coluna, veiculosFila.length),
            Expanded(
              child: _buildGridVeiculos(
                veiculosFila,
                coluna,
                borderColor,
                true,
              ),
            ),
          ],
        ),
      );
    }

    final veiculos = _veiculosPorStatus(coluna.statusNecessario);
    return Container(
      decoration: BoxDecoration(
        color: colColor,
        border: Border(
          right: BorderSide(
            color: borderColor,
            width: colunaIndex < _colunas.length - 1 ? 1 : 0,
          ),
        ),
      ),
      child: Column(
        children: [
          _buildCabecalhoColunaWidget(coluna, veiculos.length),
          Expanded(
            child: _buildGridVeiculos(
              veiculos,
              coluna,
              borderColor,
              colunaIndex == 2, // 1 por linha se for "Em Operação"
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCabecalhoColunaFila(_ColunaInfo coluna, int count) {
    return Container(
      decoration: BoxDecoration(
        color: _isDarkMode
            ? Colors.transparent
            : coluna.cor.withValues(alpha: 0.05),
        border: Border(
          bottom: BorderSide(
            color: coluna.cor.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: coluna.cor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    coluna.titulo.toUpperCase(),
                    style: TextStyle(
                      color: coluna.cor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: coluna.cor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: coluna.cor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: coluna.cor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: coluna.cor.withValues(alpha: 0.4),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            color: _isDarkMode ? Colors.white10 : Colors.grey.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'DESCARGA',
                  style: TextStyle(
                    color: !_mostrarFilaCarga
                        ? const Color(0xFF00ACC1)
                        : Colors.grey,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  height: 24,
                  width: 44,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: Switch(
                      value: _mostrarFilaCarga,
                      activeTrackColor: const Color(
                        0xFFD81B60,
                      ).withValues(alpha: 0.3),
                      activeThumbColor: const Color(0xFFD81B60),
                      inactiveThumbColor: const Color(0xFF00ACC1),
                      inactiveTrackColor: const Color(
                        0xFF00ACC1,
                      ).withValues(alpha: 0.3),
                      trackOutlineColor: WidgetStateProperty.all(
                        Colors.transparent,
                      ),
                      onChanged: (val) =>
                          setState(() => _mostrarFilaCarga = val),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'CARGA',
                  style: TextStyle(
                    color: _mostrarFilaCarga
                        ? const Color(0xFFD81B60)
                        : Colors.grey,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridVeiculos(
    List<_Veiculo> veiculos,
    _ColunaInfo coluna,
    Color borderColor,
    bool isSubFila,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isSubFila ? 1 : 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: isSubFila ? 7.0 : 2.0,
      ),
      itemCount: veiculos.length,
      itemBuilder: (context, index) {
        final v = veiculos[index];
        return _buildChip(
          v,
          coluna,
          borderColor,
          indexInFila: isSubFila ? index + 1 : null,
        );
      },
    );
  }

  Widget _buildCabecalhoColunaWidget(_ColunaInfo coluna, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _isDarkMode
            ? Colors.transparent
            : coluna.cor.withValues(alpha: 0.05),
        border: Border(
          bottom: BorderSide(
            color: coluna.cor.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: coluna.cor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              coluna.titulo.toUpperCase(),
              style: TextStyle(
                color: coluna.cor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: coluna.cor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: coluna.cor.withValues(alpha: 0.3)),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: coluna.cor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(
    _Veiculo v,
    _ColunaInfo coluna,
    Color borderColor, {
    int? indexInFila,
  }) {
    final cardColor = _isDarkMode ? const Color(0xFF1E293B) : Colors.white;

    // Cores personalizadas para a tag de posição baseada no terminal do usuário
    Color tagBgColor = coluna.cor;
    Color tagTextColor = Colors.white;

    if (indexInFila != null) {
      final isCarga = v.terminalIdOrig == _usuarioTerminalId;
      if (isCarga) {
        // Carga: amarelo, cinza, branco
        tagBgColor = const Color(0xFFFFD600); // Amarelo vibrante
        tagTextColor = const Color(
          0xFF263238,
        ); // Cinza escuro/preto para contraste
      } else {
        // Descarga: verde e azul
        tagBgColor = const Color(0xFF00B0FF); // Azul brilhante
        tagTextColor = Colors.white;
      }
    }

    return GestureDetector(
      onTap: () => _mostrarDetalhesVeiculo(v),
      child: _ChipHover(
        cor: tagBgColor,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: _isDarkMode
                ? cardColor
                : (indexInFila != null
                    ? Colors.grey[200]
                    : coluna.cor.withValues(alpha: 0.08)),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _isDarkMode
                  ? borderColor
                  : (indexInFila != null
                      ? Colors.grey[400]!
                      : coluna.cor.withValues(alpha: 0.3)),
              width: 1,
            ),
            boxShadow: [
              if (!_isDarkMode)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: indexInFila != null
              ? Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Row(
                      children: [
                        if (v.statusAtual == '2')
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: tagBgColor,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '$indexInFilaº',
                                style: TextStyle(
                                  color: tagTextColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          )
                        else
                          const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Layout específico para FILA (Duas linhas)
                              // Primeira Linha: Placas e Motorista
                              Row(
                                children: [
                                  if (v.placaLinha1.isNotEmpty) ...[
                                    Text(
                                      v.placaLinha1,
                                      style: TextStyle(
                                        color: coluna.cor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    v.placa,
                                    style: TextStyle(
                                      color: coluna.cor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      v.motorista,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: _isDarkMode
                                            ? Colors.white70
                                            : Colors.black87,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              // Segunda Linha: Vendedor > Comprador
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${v.vendedor} → ${v.comprador}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: _isDarkMode
                                            ? Colors.white54
                                            : Colors.black54,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: (v.terminalIdOrig ==
                                              _usuarioTerminalId)
                                          ? const Color(0xFFD81B60)
                                              .withValues(alpha: 0.15)
                                          : const Color(0xFF00ACC1)
                                              .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: (v.terminalIdOrig ==
                                                _usuarioTerminalId)
                                            ? const Color(0xFFD81B60)
                                                .withValues(alpha: 0.3)
                                            : const Color(0xFF00ACC1)
                                                .withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Text(
                                      (v.terminalIdOrig == _usuarioTerminalId)
                                          ? 'SAÍDA'
                                          : 'ENTRADA',
                                      style: TextStyle(
                                        color: (v.terminalIdOrig ==
                                                _usuarioTerminalId)
                                            ? const Color(0xFFD81B60)
                                            : const Color(0xFF00ACC1),
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (v.placaLinha1.isNotEmpty)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          v.placaLinha1,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: coluna.cor,
                            fontWeight: FontWeight.bold,
                            fontSize: 8.5,
                            fontFamily: 'monospace',
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 0),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        v.placa,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: coluna.cor,
                          fontWeight: FontWeight.bold,
                          fontSize: 9.5,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    Text(
                      _mostrarPorProduto
                          ? (v.produtos.length > 1
                              ? '${v.produtos.first.nome} (+${v.produtos.length - 1})'
                              : v.produtos.first.nome)
                          : v.empresa,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _isDarkMode ? Colors.white : Colors.black,
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ChipHover extends StatefulWidget {
  final Widget child;
  final Color cor;

  const _ChipHover({required this.child, required this.cor});

  @override
  State<_ChipHover> createState() => _ChipHoverState();
}

class _ChipHoverState extends State<_ChipHover> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          boxShadow: _hover
              ? [
                  BoxShadow(
                    color: widget.cor.withValues(alpha: 0.5),
                    blurRadius: 6,
                  ),
                ]
              : null,
        ),
        child: widget.child,
      ),
    );
  }
}

class _ProdutoItem {
  final String nome;
  final String quantidade;

  _ProdutoItem({required this.nome, required this.quantidade});
}

class _ColunaInfo {
  final String titulo;
  final Color cor;
  final Color corFundo;
  final String statusNecessario;

  const _ColunaInfo({
    required this.titulo,
    required this.cor,
    required this.corFundo,
    required this.statusNecessario,
  });
}

class _Veiculo {
  final String id;
  final String ordemId;
  final String? terminalIdOrig;
  final String? terminalIdDest;
  final String placa;
  final String placaLinha1;
  final String placaCompleta;
  final List<_ProdutoItem> produtos;
  final String empresa;
  final String tipoOp;
  final String statusAtual;
  final String motorista;
  final String transportadora;
  final String dataCriacao;
  final String? posicaoFila;
  final String vendedor;
  final String comprador;

  _Veiculo({
    required this.id,
    required this.ordemId,
    this.terminalIdOrig,
    this.terminalIdDest,
    required this.placa,
    required this.placaLinha1,
    required this.placaCompleta,
    required this.produtos,
    required this.empresa,
    required this.tipoOp,
    required this.statusAtual,
    required this.motorista,
    required this.transportadora,
    required this.dataCriacao,
    this.posicaoFila,
    required this.vendedor,
    required this.comprador,
  });
}
