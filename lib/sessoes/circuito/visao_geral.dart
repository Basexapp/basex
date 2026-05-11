import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_page.dart';

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
  String _filtroBusca = '';
  String _empresaSelecionada = 'Todas';
  String _tipoOpSelecionada = 'Todos';
  final TextEditingController _searchCtrl = TextEditingController();

  static const List<String> _empresas = ['Todas', 'Larco', 'Zema', 'Ale Comb.'];
  static const List<String> _tiposOp = ['Todos', 'Carga', 'Descarga'];

  // ── Estágios ─────────────────────────────────────────────────────────────
  static const List<_Estagio> _estagios = [
    _Estagio(
      titulo: 'Programados',
      cor: Color(0xFF1565C0),
      corFundo: Color(0xFF0D1B2A),
    ),
    _Estagio(
      titulo: 'Em Fila',
      cor: Color(0xFFE65100),
      corFundo: Color(0xFF1A1200),
    ),
    _Estagio(
      titulo: 'Em Operação',
      cor: Color(0xFF4A148C),
      corFundo: Color(0xFF0E001A),
    ),
    _Estagio(
      titulo: 'Liberados',
      cor: Color(0xFF2E7D32),
      corFundo: Color(0xFF001A02),
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

      final empresaId = usuario.empresaId;
      if (empresaId == null || empresaId.isEmpty) {
        throw Exception('Empresa não identificada');
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
            ordens!ordem_id(em_fila, terminal_id_orig, terminal_id_dest, status_term_orig, status_term_dest)
          ''')
          .eq('empresa_id', empresaId)
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
          clienteFinal = primeiroItem['empresas']?['nome_dois']?.toString() ?? clienteFinal;
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

        final status = primeiroItem['status_circuito_orig']?.toString() ?? '0';
        final emFila = primeiroItem['ordens']?['em_fila'] == true;
        final statusTermOrig = primeiroItem['ordens']?['status_term_orig']?.toString() ?? '0';
        final statusTermDest = primeiroItem['ordens']?['status_term_dest']?.toString() ?? '0';
        
        int estagio = -1;
        if (status == '1') {
          // Lógica de estágios baseada no terminal do usuário
          final isOrigem = primeiroItem['ordens']?['terminal_id_orig']?.toString() == _usuarioTerminalId;
          final isDestino = primeiroItem['ordens']?['terminal_id_dest']?.toString() == _usuarioTerminalId;

          if ((isOrigem && statusTermOrig == '3') || (isDestino && statusTermDest == '3')) {
            estagio = 3; // Em Operação (antes era 2)
          } else if (emFila) {
            estagio = 2; // Em Fila (antes era 1)
          } else {
            estagio = 1; // Programados (antes era 0)
          }
        } else if (status == '2') {
          estagio = 2; // Em Fila (antes era 1)
        } else if (status == '3') {
          estagio = 3; // Em Operação (antes era 2)
        } else if (status == '4') {
          estagio = 4; // Liberados (antes era 3)
        }

        // Mapeia produtos e quantidades de todas as movimentações desta ordem
        final numberFormat = NumberFormat.decimalPattern('pt_BR');
        final produtos = itens.map((i) {
          final isSaida = i['tipo_mov'] == 'saida' || i['saida_amb'] != null && (i['saida_amb'] as num) > 0;
          final num quantidadeValue = isSaida ? (i['saida_amb'] ?? 0) : (i['entrada_amb'] ?? 0);
          
          return _ProdutoItem(
            nome: i['produtos']?['nome_dois']?.toString() ?? 'N/A',
            quantidade: numberFormat.format(quantidadeValue),
          );
        }).toList();

        return _Veiculo(
          id: primeiroItem['id']?.toString() ?? '',
          ordemId: entry.key,
          terminalIdOrig: primeiroItem['ordens']?['terminal_id_orig']?.toString(),
          terminalIdDest: primeiroItem['ordens']?['terminal_id_dest']?.toString(),
          placa: placaLinha2,
          placaLinha1: placaLinha1,
          placaCompleta: placaCompleta,
          produtos: produtos,
          empresa: clienteFinal,
          tipoOp: tipoOp,
          estagio: estagio,
          motorista: primeiroItem['motoristas']?['nome']?.toString() ?? 'N/A',
          transportadora: primeiroItem['transportadoras']?['nome']?.toString() ?? 'N/A',
          dataCriacao: primeiroItem['data_mov']?.toString() ?? 'N/A',
        );
      }).where((v) => v.estagio != -1).toList();

      setState(() {
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

  List<_Veiculo> _veiculosPorEstagio(int estagio, {String? subFila}) {
    return _veiculos.where((v) {
      if (v.estagio != estagio) return false;

      // Se for estágio "Em Fila" (índice 2) e houver subFila especificada
      if (estagio == 2 && subFila != null) {
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
      final placaMatch = v.placa.toLowerCase().contains(busca) ||
          v.placaLinha1.toLowerCase().contains(busca);
      
      final produtoMatch = v.produtos.any((p) => p.nome.toLowerCase().contains(busca));
      
      return placaMatch || produtoMatch;
    }).toList();
  }

  void _avancarEstagio(_Veiculo v) {
    if (v.estagio >= _estagios.length) return;
    setState(() => v.estagio++);
  }

  void _retrocederEstagio(_Veiculo v) {
    if (v.estagio <= 1) return;
    setState(() => v.estagio--);
  }

  Future<void> _enviarParaFila(_Veiculo v) async {
    if (v.ordemId.isEmpty) return;

    try {
      // 1. Atualiza ordens.em_fila = true
      final Map<String, dynamic> updates = {'em_fila': true};

      // 2. Verifica se é Saída (usuário = origem) ou Entrada (usuário = destino)
      if (_usuarioTerminalId != null && _usuarioTerminalId!.isNotEmpty) {
        if (v.terminalIdOrig == _usuarioTerminalId) {
          updates['status_term_orig'] = 2;
        } else if (v.terminalIdDest == _usuarioTerminalId) {
          updates['status_term_dest'] = 2;
        }
      }

      await _supabase
          .from('ordens')
          .update(updates)
          .eq('id', v.ordemId);

      // Feedback visual e fecha dialog
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veículo enviado para a fila!')),
        );
        _carregarDados();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar para fila: $e')),
        );
      }
    }
  }

  Future<void> _sairDaFila(_Veiculo v) async {
    if (v.ordemId.isEmpty) return;
    try {
      // 1. Atualiza em_fila para false e status_term_orig para 1
      await _supabase
          .from('ordens')
          .update({
            'em_fila': false,
            'status_term_orig': 1,
          })
          .eq('id', v.ordemId);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veículo removido da fila!')),
        );
        _carregarDados();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao sair da fila: $e')),
        );
      }
    }
  }

  Future<void> _enviarParaOperacao(_Veiculo v) async {
    if (v.ordemId.isEmpty) return;
    try {
      // 1. Atualiza em_fila para false
      final Map<String, dynamic> updates = {'em_fila': false};

      // 2. Verifica se é Saída (usuário = origem) ou Entrada (usuário = destino)
      if (_usuarioTerminalId != null && _usuarioTerminalId!.isNotEmpty) {
        if (v.terminalIdOrig == _usuarioTerminalId) {
          updates['status_term_orig'] = 3;
        } else if (v.terminalIdDest == _usuarioTerminalId) {
          updates['status_term_dest'] = 3;
        }
      }

      await _supabase
          .from('ordens')
          .update(updates)
          .eq('id', v.ordemId);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veículo enviado para operação!')),
        );
        _carregarDados();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar para operação: $e')),
        );
      }
    }
  }

  void _mostrarMenuVeiculo(BuildContext context, _Veiculo v, Offset posicao) {
    if (v.estagio == 1 || v.estagio == 2 || v.estagio == 3 || v.estagio == 4) {
      _mostrarDetalhesVeiculo(v);
      return;
    }

    final podeAvancar = v.estagio < _estagios.length;
    final podeRetroceder = v.estagio > 1;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        posicao.dx,
        posicao.dy,
        posicao.dx + 1,
        posicao.dy + 1,
      ),
      color: const Color(0xFF1E2A38),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      items: [
        PopupMenuItem<String>(
          enabled: false,
          child: Text(
            v.placaCompleta,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'detalhes',
          child: Row(
            children: const [
              Icon(Icons.info_outline, size: 14, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                'Ver detalhes',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ),
        if (podeAvancar)
          PopupMenuItem<String>(
            value: 'avancar',
            child: Row(
              children: [
                Icon(Icons.arrow_forward, size: 14, color: _estagios[v.estagio].cor),
                const SizedBox(width: 8),
                Text(
                  'Mover para ${_estagios[v.estagio].titulo}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        if (podeRetroceder)
          PopupMenuItem<String>(
            value: 'retroceder',
            child: Row(
              children: [
                Icon(Icons.arrow_back, size: 14, color: _estagios[v.estagio - 2].cor),
                const SizedBox(width: 8),
                Text(
                  'Voltar para ${_estagios[v.estagio - 2].titulo}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
      ],
    ).then((value) {
      if (value == 'detalhes') _mostrarDetalhesVeiculo(v);
      if (value == 'avancar') _avancarEstagio(v);
      if (value == 'retroceder') _retrocederEstagio(v);
    });
  }

  void _mostrarDetalhesVeiculo(_Veiculo v) {
    String dataFormatada = v.dataCriacao;
    try {
      final data = DateTime.parse(v.dataCriacao);
      dataFormatada = '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
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
                      child: Icon(Icons.close, size: 22, color: Color(0xFFC62828)), // Vermelho mais forte
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
              ...v.produtos.map((p) => Padding(
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
              )),
              _buildInfoRow('Data Criação:', dataFormatada),
              const SizedBox(height: 20),
              if (v.estagio == 1) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Check-list ok',
                        style: TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: () => _enviarParaFila(v),
                    icon: const Icon(Icons.queue, size: 18),
                    label: const Text('ENVIAR PARA FILA', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade800,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ] else if (v.estagio == 2) ...[
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: () => _enviarParaOperacao(v),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('ENVIAR PARA OPERAÇÃO', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: OutlinedButton.icon(
                    onPressed: () => _sairDaFila(v), // Ativado conforme solicitado
                    icon: const Icon(Icons.exit_to_app, size: 18),
                    label: const Text('SAIR DA FILA', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade700),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ] else if (v.estagio == 3 || v.estagio == 4) ...[
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: null, // Inativo por enquanto
                    icon: const Icon(Icons.description_outlined, size: 18),
                    label: const Text('CERTIFICADO DE APURAÇÃO', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                      disabledBackgroundColor: Colors.grey.shade300,
                      disabledForegroundColor: Colors.grey.shade500,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
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
              TextButton(onPressed: widget.onVoltar, child: const Text('Voltar')),
            ],
          ),
        ),
      );
    }

    final bodyColor = _isDarkMode ? const Color(0xFF0A0F1A) : const Color(0xFFF1F5F9);
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
    final borderColor = _isDarkMode ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);
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
            style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 4),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: _mostrarPorProduto,
              activeColor: const Color(0xFF2196F3),
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
                  color: _isDarkMode ? Colors.black38 : subTextColor.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide.none,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
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
        Text(
          '$label:',
          style: TextStyle(color: subTextColor, fontSize: 12),
        ),
        const SizedBox(width: 8),
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            dropdownColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            icon: Icon(Icons.keyboard_arrow_down, size: 16, color: subTextColor),
            style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w500),
            onChanged: onChanged,
            items: items.map((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(item),
              );
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
    final borderColor = _isDarkMode ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);

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
            icon: Icon(Icons.arrow_back, color: textColor.withValues(alpha: 0.7), size: 20),
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
          // Botão Atualizar
          IconButton(
            icon: Icon(Icons.refresh, color: textColor.withValues(alpha: 0.7), size: 20),
            tooltip: 'Atualizar dados',
            onPressed: _carregarDados,
          ),
          const SizedBox(width: 8),
          // Seletor de Tema
          Row(
            children: [
              Icon(
                _isDarkMode ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                size: 18,
                color: textColor.withOpacity(0.5),
              ),
              const SizedBox(width: 4),
              Transform.scale(
                scale: 0.7,
                child: Switch(
                  value: _isDarkMode,
                  activeColor: const Color(0xFF2196F3),
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
    final borderColor = _isDarkMode ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(
        _estagios.length,
        (i) => Expanded(child: _buildColuna(i + 1, borderColor)), // i+1 porque estágios começam em 1
      ),
    );
  }

  Widget _buildColuna(int estagioIndex, Color borderColor) {
    final estagio = _estagios[estagioIndex - 1]; // -1 porque lista começa no 0
    final colColor = _isDarkMode ? estagio.corFundo : Colors.white;

    if (estagioIndex == 2) {
      // Estágio "Em Fila" - subdividido
      final veiculosCarga = _veiculosPorEstagio(2, subFila: 'carga');
      final veiculosDescarga = _veiculosPorEstagio(2, subFila: 'descarga');

      return Container(
        decoration: BoxDecoration(
          color: colColor,
          border: Border(
            right: BorderSide(color: borderColor, width: 1),
          ),
        ),
        child: Column(
          children: [
            _buildCabecalhoColunaWidget(estagio, veiculosCarga.length + veiculosDescarga.length),
            Expanded(
              child: Row(
                children: [
                  // Sub-coluna DESCARGA (Entrada)
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(right: BorderSide(color: borderColor.withValues(alpha: 0.5), width: 1)),
                      ),
                      child: Column(
                        children: [
                          _buildSubCabecalho('DESCARGA', const Color(0xFFD81B60)), // Rosa escuro/Vibrante
                          Expanded(child: _buildGridVeiculos(veiculosDescarga, estagio, borderColor, true)),
                        ],
                      ),
                    ),
                  ),
                  // Sub-coluna CARGA (Saída)
                  Expanded(
                    child: Column(
                      children: [
                        _buildSubCabecalho('CARGA', const Color(0xFF00ACC1)), // Ciano escuro/Vibrante
                        Expanded(child: _buildGridVeiculos(veiculosCarga, estagio, borderColor, true)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final veiculos = _veiculosPorEstagio(estagioIndex);
    return Container(
      decoration: BoxDecoration(
        color: colColor,
        border: Border(
          right: BorderSide(
            color: borderColor,
            width: estagioIndex < _estagios.length ? 1 : 0,
          ),
        ),
      ),
      child: Column(
        children: [
          _buildCabecalhoColunaWidget(estagio, veiculos.length),
          Expanded(child: _buildGridVeiculos(veiculos, estagio, borderColor, false)),
        ],
      ),
    );
  }

  Widget _buildSubCabecalho(String titulo, Color cor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.1),
      ),
      child: Text(
        titulo,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: cor,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildGridVeiculos(List<_Veiculo> veiculos, _Estagio estagio, Color borderColor, bool isSubFila) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isSubFila ? 1 : 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: isSubFila ? 2.8 : 2.0,
      ),
      itemCount: veiculos.length,
      itemBuilder: (context, index) {
        final v = veiculos[index];
        return _buildChip(v, estagio, borderColor);
      },
    );
  }

  Widget _buildCabecalhoColunaWidget(_Estagio estagio, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _isDarkMode ? Colors.transparent : estagio.cor.withValues(alpha: 0.05),
        border: Border(
          bottom: BorderSide(color: estagio.cor.withValues(alpha: 0.4), width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: estagio.cor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              estagio.titulo.toUpperCase(),
              style: TextStyle(
                color: estagio.cor,
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
              color: estagio.cor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: estagio.cor.withValues(alpha: 0.3)),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: estagio.cor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(_Veiculo v, _Estagio estagio, Color borderColor) {
    final cardColor = _isDarkMode ? const Color(0xFF1E293B) : Colors.white;

    return GestureDetector(
      onSecondaryTapDown: (details) =>
          _mostrarMenuVeiculo(context, v, details.globalPosition),
      onLongPressStart: (details) =>
          _mostrarMenuVeiculo(context, v, details.globalPosition),
      onTapDown: (details) => _mostrarMenuVeiculo(
        context,
        v,
        details.globalPosition,
      ),
      child: _ChipHover(
        cor: estagio.cor,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: _isDarkMode ? cardColor : estagio.cor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _isDarkMode ? borderColor : estagio.cor.withValues(alpha: 0.3),
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, // Distribui as linhas uniformemente
            children: [
              if (v.placaLinha1.isNotEmpty)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    v.placaLinha1,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: estagio.cor,
                      fontWeight: FontWeight.bold,
                      fontSize: 8.5, // Reduzido levemente para ganhar espaço
                      fontFamily: 'monospace',
                    ),
                  ),
                )
              else
                const SizedBox(height: 0), // Espaçador neutro se não houver linha 1
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  v.placa, // Segunda linha (com as 2 últimas placas)
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: estagio.cor,
                    fontWeight: FontWeight.bold,
                    fontSize: 9.5, // Reduzido levemente para ganhar espaço
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              Text(
                _mostrarPorProduto 
                    ? (v.produtos.length > 1 ? '${v.produtos.first.nome} (+${v.produtos.length - 1})' : v.produtos.first.nome)
                    : v.empresa,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _isDarkMode ? Colors.white : Colors.black,
                  fontSize: 8, // Reduzido levemente para ganhar espaço
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

// ── Hover helper ────────────────────────────────────────────────────────────

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
              ? [BoxShadow(color: widget.cor.withValues(alpha: 0.5), blurRadius: 6)]
              : null,
        ),
        child: widget.child,
      ),
    );
  }
}

// ── Data models ─────────────────────────────────────────────────────────────

class _ProdutoItem {
  final String nome;
  final String quantidade;

  _ProdutoItem({required this.nome, required this.quantidade});
}

class _Estagio {
  final String titulo;
  final Color cor;
  final Color corFundo;

  const _Estagio({
    required this.titulo,
    required this.cor,
    required this.corFundo,
  });
}

class _Veiculo {
  final String id;
  final String ordemId;
  final String? terminalIdOrig;
  final String? terminalIdDest;
  final String placa; // Agora representa a linha 2 de placas
  final String placaLinha1;
  final String placaCompleta;
  final List<_ProdutoItem> produtos;
  final String empresa;
  final String tipoOp;
  int estagio;
  final String motorista;
  final String transportadora;
  final String dataCriacao;

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
    required this.estagio,
    required this.motorista,
    required this.transportadora,
    required this.dataCriacao,
  });
}