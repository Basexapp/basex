import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_page.dart';
import '../operacao/escolher_terminal.dart';
import 'detalhes_ordem.dart';

// Formatador de máscara para data dd/mm/aaaa
class DataInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    
    // Remove tudo que não é número
    final digitsOnly = text.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Limita a 8 dígitos (ddmmaaaa)
    final limitedDigits = digitsOnly.length > 8 
        ? digitsOnly.substring(0, 8) 
        : digitsOnly;
    
    // Formata com barras
    String formatted = '';
    for (int i = 0; i < limitedDigits.length; i++) {
      if (i == 2 || i == 4) {
        formatted += '/';
      }
      formatted += limitedDigits[i];
    }
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class AcompanhamentoOrdensPage extends StatefulWidget {
  final VoidCallback onVoltar;

  const AcompanhamentoOrdensPage({
    super.key,
    required this.onVoltar,
  });

  @override
  State<AcompanhamentoOrdensPage> createState() => _AcompanhamentoOrdensPageState();
}

class _AcompanhamentoOrdensPageState extends State<AcompanhamentoOrdensPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _ordens = [];
  List<Map<String, dynamic>> _ordensFiltradas = [];
  List<Map<String, dynamic>> _terminais = [];
  bool _carregando = true;
  bool _erro = false;
  String _mensagemErro = '';
  String? _empresaId;
  
  final TextEditingController _filtroGeralController = TextEditingController();
  String? _terminalFiltroId;
  String? _tipoFiltro;

  bool _mostrarDetalhes = false;
  Map<String, dynamic>? _ordemSelecionada;

  // Novo: controle para escolha de terminal (nível 3)
  bool _mostrarEscolherTerminal = false;
  String? _terminalSelecionadoId;

  // Controladores para os filtros (para reset)
  late TextEditingController _dataInicioController;
  late TextEditingController _dataFimController;

  @override
  void initState() {
    super.initState();

    // Inicializa controladores de data com a data atual (dd/mm/aaaa)
    final hoje = DateTime.now();
    final hojeFormatado =
      '${hoje.day.toString().padLeft(2, '0')}/${hoje.month.toString().padLeft(2, '0')}/${hoje.year}';
    _dataInicioController = TextEditingController(text: hojeFormatado);
    _dataFimController = TextEditingController(text: hojeFormatado);
    

    // Define valores iniciais dos filtros
    // null corresponde a 'Todos' no Dropdown
    _tipoFiltro = null;
    _terminalFiltroId = UsuarioAtual.instance?.terminalId;

    // Determina se devemos mostrar o chooser IMEDIATAMENTE para evitar
    // que a página principal apareça antes do chooser.
    final usuarioSync = UsuarioAtual.instance;
    if (usuarioSync != null && usuarioSync.nivel == 3 &&
        (usuarioSync.terminalId == null || usuarioSync.terminalId!.isEmpty)) {
      _mostrarEscolherTerminal = true;
      _carregando = false;
    } else {
      // Para níveis 1 e 2, pré-popula terminal selecionado se existir
      _terminalSelecionadoId = usuarioSync?.terminalId;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // Se já estamos mostrando o chooser, não prossiga com carregamentos
      if (_mostrarEscolherTerminal) return;

      await _carregarTerminais();
      await _aplicarFiltros();
      if (mounted) setState(() { _carregando = false; });
    });
  }

  Future<void> _carregarTerminais() async {
    try {
      final usuario = UsuarioAtual.instance;
      if (usuario == null) return;

      if (usuario.nivel == 3) {
        final dados = await _supabase
            .from('terminais')
            .select('id, nome')
            .eq('empresa_id', _empresaId!)
            .order('nome');

        setState(() {
          _terminais = List<Map<String, dynamic>>.from(dados);
          if (_terminalFiltroId == null && _terminais.isNotEmpty) {
            _terminalFiltroId = _terminais.first['id'].toString();
          }
        });
      } else if (usuario.terminalId != null) {
        final terminalData = await _supabase
            .from('terminais')
            .select('id, nome')
            .eq('id', usuario.terminalId!)
            .single();

        setState(() {
          _terminais = [terminalData];
          _terminalFiltroId = usuario.terminalId;
        });
      }
    } catch (e) {
      // Erro silencioso
    }
  }

  Future<void> _aplicarFiltros() async {
    setState(() {
      _carregando = true;
      _erro = false;
    });

    try {
      final usuario = UsuarioAtual.instance;
      if (usuario == null) {
        throw Exception('Usuário não autenticado');
      }

      _empresaId = usuario.empresaId;

      if (_empresaId == null || _empresaId!.isEmpty) {
        throw Exception('Empresa não identificada');
      }

      DateTime? dataInicio;
      DateTime? dataFim;

      if (_dataInicioController.text.trim().isNotEmpty) {
        final partes = _dataInicioController.text.split('/');

        if (partes.length == 3) {
          dataInicio = DateTime(
            int.parse(partes[2]),
            int.parse(partes[1]),
            int.parse(partes[0]),
          );

          dataFim = DateTime(
            dataInicio.year,
            dataInicio.month,
            dataInicio.day,
            23,
            59,
            59,
          );
        }
      }

      var query = _supabase
          .from('movimentacoes')
          .select('''
            id,
            placa,
            entrada_amb,
            entrada_vinte,
            saida_amb,
            saida_vinte,
            cliente,
            descricao,
            status_circuito_orig,
            status_circuito_dest,
            data_mov,
            data_descarga,
            motoristas!motorista_id(nome),
            terminal_orig_id,
            terminal_dest_id,
            empresa_id,
            tipo_op,
            produtos!produto_id(id, nome_dois),
            terminal_origem:terminais!movimentacoes_terminal_orig_id_fkey(id, nome),
            terminal_destino:terminais!movimentacoes_terminal_dest_id_fkey(id, nome),
            ordem_id
          ''')
          .eq('empresa_id', _empresaId!);

      final usuarioFiltro = UsuarioAtual.instance;
      String? terminalParaFiltro;

      if (usuarioFiltro != null &&
          (usuarioFiltro.nivel == 1 || usuarioFiltro.nivel == 2)) {
        terminalParaFiltro =
            usuarioFiltro.terminalId ?? _terminalSelecionadoId;
      } else if (usuarioFiltro?.nivel == 3) {
        terminalParaFiltro = _terminalSelecionadoId;
      }

      if (terminalParaFiltro != null && terminalParaFiltro.isNotEmpty) {
        query = query.or(
          'terminal_orig_id.eq.$terminalParaFiltro,terminal_dest_id.eq.$terminalParaFiltro'
        );
      }

      final dados = await query.order('data_mov', ascending: false);

      String? terminalAtualId =
          usuario.nivel < 3 ? usuario.terminalId : _terminalFiltroId;

      List<Map<String, dynamic>> movimentacoesFiltradas = dados.where((item) {

        final tipoOp = (item['tipo_op'] ?? '').toString().toLowerCase();
        final origem = item['terminal_orig_id']?.toString();
        final destino = item['terminal_dest_id']?.toString();

        final statusDest = item['status_circuito_dest'];
        final statusDestInt =
            statusDest is int ? statusDest : int.tryParse(statusDest?.toString() ?? '0');
        
        final statusOrig = item['status_circuito_orig'];
        final statusOrigInt =
            statusOrig is int ? statusOrig : int.tryParse(statusOrig?.toString() ?? '0');

        final dataMovStr = item['data_mov']?.toString();
        final dataDescargaStr = item['data_descarga']?.toString();

        bool d_mov_valida = true;
        if (dataFim != null && dataMovStr != null) {
          try {
            final dataMov = DateTime.parse(dataMovStr);
            // Verifica se data_mov <= data selecionada (limite superior do dia selecionado)
            if (dataMov.isAfter(dataFim)) {
              d_mov_valida = false;
            }
          } catch (_) {}
        }
        if (!d_mov_valida) return false;

        bool dentroDaData = true;

        if (dataInicio != null && dataFim != null) {
          // PRIORIDADE 1: Usar data_descarga se existir
          if (dataDescargaStr != null && dataDescargaStr.isNotEmpty) {
            try {
              final dataDescarga = DateTime.parse(dataDescargaStr);
              final dataDescargaDate = DateTime(dataDescarga.year, dataDescarga.month, dataDescarga.day);
              final dataInicioDate = DateTime(dataInicio.year, dataInicio.month, dataInicio.day);
              final dataFimDate = DateTime(dataFim.year, dataFim.month, dataFim.day);
              
              dentroDaData = dataDescargaDate.isAfter(dataInicioDate.subtract(const Duration(days: 1))) && 
                            dataDescargaDate.isBefore(dataFimDate.add(const Duration(days: 1)));
            } catch (_) {
              dentroDaData = false;
            }
          } 
          // PRIORIDADE 2: Se não tem data_descarga, usar data_mov
          else if (dataMovStr != null) {
            try {
              final dataMov = DateTime.parse(dataMovStr);
              dentroDaData = !(dataMov.isBefore(dataInicio) || dataMov.isAfter(dataFim));
            } catch (_) {
              dentroDaData = false;
            }
          } else {
            dentroDaData = false;
          }
        }

        // NOVA REGRA: Verifica se deve aparecer independente da data selecionada
        bool deveAparecerSempre = false;
        
        // CRITÉRIO 1: Status 1, 2 ou 3 no terminal de destino (quando é entrada no terminal atual)
        if (statusDestInt != null && statusDestInt >= 1 && statusDestInt <= 3 && destino == terminalAtualId) {
          deveAparecerSempre = true;
        }
        
        // CRITÉRIO 2: Status 1, 2 ou 3 no terminal de origem (quando é saída do terminal atual)
        if (statusOrigInt != null && statusOrigInt >= 1 && statusOrigInt <= 3 && origem == terminalAtualId) {
          deveAparecerSempre = true;
        }
        
        // CRITÉRIO 3: Data de descarga igual à data selecionada no filtro
        if (!deveAparecerSempre && dataDescargaStr != null && dataInicio != null && dataFim != null) {
          try {
            final dataDescarga = DateTime.parse(dataDescargaStr);
            final dataDescargaDate = DateTime(dataDescarga.year, dataDescarga.month, dataDescarga.day);
            final dataInicioDate = DateTime(dataInicio.year, dataInicio.month, dataInicio.day);
            final dataFimDate = DateTime(dataFim.year, dataFim.month, dataFim.day);
            
            if (dataDescargaDate.isAfter(dataInicioDate.subtract(const Duration(days: 1))) && 
                dataDescargaDate.isBefore(dataFimDate.add(const Duration(days: 1)))) {
              deveAparecerSempre = true;
            }
          } catch (_) {}
        }

        // Se deve aparecer sempre, ignora o filtro de data
        if (deveAparecerSempre) {
          if (_tipoFiltro == 'saida') return false;
          return true;
        }

        // Se não deve aparecer sempre, aplica o filtro de data normal
        if (!dentroDaData) return false;

        if (_tipoFiltro == 'entrada') {
          if (tipoOp == 'usina' || tipoOp == 'transf') {
            return destino == terminalAtualId;
          }
          return false;
        }

        if (_tipoFiltro == 'saida') {
          if (tipoOp == 'transf' || tipoOp == 'venda' || tipoOp == 'consumo') {
            return origem == terminalAtualId;
          }
          return false;
        }

        return origem == terminalAtualId || destino == terminalAtualId;

      }).toList();

      final Map<String, List<Map<String, dynamic>>> grupos = {};

      for (var mov in movimentacoesFiltradas) {
        final ordemId = mov['ordem_id']?.toString();
        if (ordemId == null) continue;

        grupos.putIfAbsent(ordemId, () => []);
        grupos[ordemId]!.add(mov);
      }

      final List<Map<String, dynamic>> ordensResumidas = [];

      for (var entry in grupos.entries) {
        final primeira = entry.value.first;

        final Set<String> placasSet = {};

        for (var mov in entry.value) {
          final placasFormatadas = _formatarPlacas(mov['placa']);

          if (placasFormatadas.isNotEmpty && placasFormatadas != 'N/I') {
            final placasList =
                placasFormatadas.split(', ').map((p) => p.trim()).toList();
            placasSet.addAll(placasList.where((p) => p.isNotEmpty));
          }
        }

        final produtosAgrupados = agruparProdutosDaOrdem(entry.value);

        final quantidadeTotal = produtosAgrupados.values.fold<double>(
          0,
          (sum, infos) => sum + infos.values.fold<double>(0, (s, v) => s + v),
        );

        ordensResumidas.add({
          'ordem_id': entry.key,
          'data_mov': primeira['data_mov'],
          'data_descarga': primeira['data_descarga'],
          'status_circuito_orig': primeira['status_circuito_orig'],
          'status_circuito_dest': primeira['status_circuito_dest'],
          'tipo_op': primeira['tipo_op'],
          'terminal_origem_id': primeira['terminal_orig_id'],
          'terminal_destino_id': primeira['terminal_dest_id'],
          'motorista_nome': primeira['motoristas'] != null ? primeira['motoristas']['nome'] : null,
          'placas': placasSet.toList(),
          'quantidade_total': quantidadeTotal,
          'produtos_agrupados': produtosAgrupados,
          'itens': entry.value,
        });
      }

      ordensResumidas.sort((a, b) {
        // PRIORIDADE: Ordenar pela data_descarga (se existir), senão por data_mov
        final dataA = a['data_descarga']?.toString() ?? a['data_mov']?.toString() ?? '';
        final dataB = b['data_descarga']?.toString() ?? b['data_mov']?.toString() ?? '';
        return dataB.compareTo(dataA);
      });

      if (mounted) {
        setState(() {
          _ordens = ordensResumidas;
          _ordensFiltradas = List.from(ordensResumidas);
          _carregando = false;
        });

        _aplicarFiltroTexto();
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _carregando = false;
          _erro = true;
          _mensagemErro = e.toString();
        });
      }
    }
  }

  void _aplicarFiltroTexto() {
    final termoBusca = _filtroGeralController.text.toLowerCase().trim();
    
    if (termoBusca.isEmpty) {
      setState(() {
        _ordensFiltradas = List.from(_ordens);
      });
      return;
    }

    final resultado = _ordens.where((ordem) {
      final placasOrdem = (ordem['placas'] as List).map((p) => p.toString().toLowerCase()).join(' ');
      if (placasOrdem.contains(termoBusca)) return true;
      
      final quantidadeTotal = ordem['quantidade_total'].toString();
      if (quantidadeTotal.contains(termoBusca)) return true;
      
      final statusTexto = _obterStatusTexto(ordem, null).toLowerCase();
      if (statusTexto.contains(termoBusca)) return true;
      
      final tipoOpTexto = _obterTipoOpTexto(ordem['tipo_op']?.toString() ?? '').toLowerCase();
      if (tipoOpTexto.contains(termoBusca)) return true;
      
      final produtos = ordem['produtos_agrupados'] as Map<String, Map<String, double>>;
      if (produtos.keys.any((nome) => nome.toLowerCase().contains(termoBusca))) {
        return true;
      }
      
      return ordem['itens'].any((item) {
        final cliente = (item['cliente'] ?? '').toString().toLowerCase();
        final placaItem = _formatarPlacaParaBusca(item['placa']).toLowerCase();
        final terminal = _obterNomeTerminalParaBusca(item).toLowerCase();
        
        return cliente.contains(termoBusca) ||
               placaItem.contains(termoBusca) ||
               terminal.contains(termoBusca);
      });
    }).toList();

    setState(() {
      _ordensFiltradas = resultado;
    });
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
    
    if (nomeProduto.toLowerCase().contains('comum')) {
      return const Color(0xFFFF6B35);
    } else if (nomeProduto.toLowerCase().contains('aditivada')) {
      return const Color(0xFF00A8E8);
    } else if (nomeProduto.toLowerCase().contains('s500')) {
      if (nomeProduto.toLowerCase().contains(' a')) {
        return const Color(0xFF9C27B0);
      }
      return const Color(0xFF8D6A9F);
    } else if (nomeProduto.toLowerCase().contains('s10')) {
      if (nomeProduto.toLowerCase().contains(' a')) {
        return const Color(0xFF673AB7);
      }
      return const Color(0xFF2E294E);
    } else if (nomeProduto.toLowerCase().contains('hidratado')) {
      return const Color(0xFF83B692);
    } else if (nomeProduto.toLowerCase().contains('anidro')) {
      return const Color(0xFF4CAF50);
    } else if (nomeProduto.toLowerCase().contains('b100')) {
      return const Color(0xFF8BC34A);
    } else if (nomeProduto.toLowerCase().contains('gasolina a')) {
      return const Color(0xFFE91E63);
    } else if (nomeProduto.toLowerCase().contains('etanol')) {
      return const Color(0xFF83B692);
    }
    
    return Colors.grey.shade600;
  }

  Map<String, Map<String, double>> agruparProdutosDaOrdem(
      List<Map<String, dynamic>> itens) {
    final Map<String, Map<String, double>> resultado = {};
    final terminalAtualId = _terminalAtualId;

    for (final mov in itens) {
      final produto = mov['produtos'];
      if (produto == null) continue;

      final nome = produto['nome_dois']?.toString();
      if (nome == null) continue;

      final terminalDestinoId = mov['terminal_dest_id']?.toString();
      final terminalOrigemId = mov['terminal_orig_id']?.toString();      

      final entradaAmb = (mov['entrada_amb'] ?? 0) as num;
      final saidaAmb = (mov['saida_amb'] ?? 0) as num;

      num quantidade = 0;
      if (terminalAtualId.isNotEmpty && terminalDestinoId == terminalAtualId) {
        quantidade = entradaAmb;
      } else if (terminalAtualId.isNotEmpty &&
          terminalOrigemId == terminalAtualId) {
        quantidade = saidaAmb;
      } else {
        quantidade = saidaAmb > 0 ? saidaAmb : entradaAmb;
      }

      if (quantidade <= 0) continue;

      final tipoOp = (mov['tipo_op']?.toString() ?? 'venda').toLowerCase();
      String informacao;
      if (tipoOp == 'transf') {
        informacao = (mov['descricao'] as String?)?.trim() ?? '';
        if (informacao.isEmpty) {
          final origem = mov['terminal_origem'] as Map<String, dynamic>?;
          final destino = mov['terminal_destino'] as Map<String, dynamic>?;
          if (origem != null && destino != null) {
            final origemNome = origem['nome']?.toString() ?? 'Origem';
            final destinoNome = destino['nome']?.toString() ?? 'Destino';
            informacao = '$origemNome → $destinoNome';
          } else {
            informacao = 'Transferência';
          }
        }
      } else if (tipoOp == 'consumo') {
        informacao = 'Consumo Próprio';
      } else {
        informacao = (mov['cliente'] as String?)?.trim() ?? '';
        if (informacao.isEmpty) {
          informacao = 'N/I';
        }
      }

      resultado.putIfAbsent(nome, () => {});
      resultado[nome]![informacao] =
          (resultado[nome]![informacao] ?? 0) + quantidade.toDouble();
    }

    return resultado;
  }

  void _abrirDetalhesOrdem(Map<String, dynamic> ordem) {
    setState(() {
      _ordemSelecionada = ordem;
      _mostrarDetalhes = true;
    });
  }

  Future<void> _cancelarOrdem(Map<String, dynamic> ordem) async {
    final ordemId = ordem['ordem_id']?.toString();
    if (ordemId == null) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFDF5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF9C27B0),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabeçalho
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFF9C27B0),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Color(0xFFFFFDF5), size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Cancelar ordem',
                      style: TextStyle(
                        color: Color(0xFFFFFDF5),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              // Conteúdo
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text(
                  'Alerta de consequência permanente:',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Text(
                  'Esta ação gera efeitos em cascata no terminal de origem, alterando estoque e processos. Uma vez confirmada, não será possível revertê-la.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),
              ),
              // Divisor
              const Divider(height: 1, color: Color(0xFFE0D9CC)),
              // Botões
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        side: const BorderSide(color: Color(0xFFBBB5A8)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Voltar',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9C27B0),
                        foregroundColor: const Color(0xFFFFFDF5),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Cancelar ordem',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmar != true) return;

    try {
      await _supabase.from('ordens').delete().eq('id', ordemId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ordem cancelada com sucesso.'),
            backgroundColor: Colors.green,
          ),
        );
        await _aplicarFiltros();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao cancelar ordem: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _voltarParaLista() {
    setState(() {
      _ordemSelecionada = null;
      _mostrarDetalhes = false;
    });
    // Garante atualização ao voltar para a lista
    _aplicarFiltros();
  }

  // Chamado quando o usuário nível 3 seleciona um terminal
  void _onTerminalSelecionado(String id) {
    setState(() {
      _terminalSelecionadoId = id;
      _mostrarEscolherTerminal = false;
      _carregando = true;
    });
    _aplicarFiltros();
  }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Evita chamada duplicada de carregamento ao abrir a página.
    // O carregamento inicial já é tratado em initState via
    // addPostFrameCallback. Aqui só aplicamos filtros quando a
    // página não está carregando e não possui ordens (casos
    // excepcionais ou retorno de navegação).
    if (!_mostrarDetalhes && !_carregando && _ordens.isEmpty) {
      _aplicarFiltros();
    }
  }

  String _obterNomeTerminalParaBusca(Map<String, dynamic> item) {
    final tipoOp = (item['tipo_op']?.toString() ?? 'venda').toLowerCase();
    
    if (tipoOp == 'usina') {
      final terminalDestino = item['terminal_destino'] as Map<String, dynamic>?;
      return terminalDestino?['nome']?.toString() ?? '';
    } else if (tipoOp == 'transf') {
      final terminalOrigem = item['terminal_origem'] as Map<String, dynamic>?;
      final terminalDestino = item['terminal_destino'] as Map<String, dynamic>?;
      final origemNome = terminalOrigem?['nome']?.toString() ?? '';
      final destinoNome = terminalDestino?['nome']?.toString() ?? '';
      return '$origemNome $destinoNome';
    } else if (tipoOp == 'consumo') {
      return 'Consumo Próprio';
    } else {
      final terminal = item['terminais'] as Map<String, dynamic>?;
      return terminal?['nome']?.toString() ?? '';
    }
  }

  String _formatarPlacaParaBusca(dynamic placaData) {
    if (placaData == null) return '';
    
    if (placaData is List) {
      return placaData.join(', ');
    } else if (placaData is String) {
      try {
        if (placaData.startsWith('{') && placaData.endsWith('}')) {
          final limpo = placaData.substring(1, placaData.length - 1);
          return limpo.split(',').map((p) => p.trim()).join(', ');
        }
        return placaData;
      } catch (e) {
        return placaData.toString();
      }
    }
    return placaData.toString();
  }
  
  String _formatarNumero(int valor) {
    if (valor == 0) return '0';
    
    String valorString = valor.toString();
    String resultado = '';
    int contador = 0;
    
    for (int i = valorString.length - 1; i >= 0; i--) {
      contador++;
      resultado = valorString[i] + resultado;
      
      if (contador % 3 == 0 && i > 0) {
        resultado = '.$resultado';
      }
    }
    
    return resultado;
  }

  String _formatarNumeroDouble(double valor) {
    final valorInt = valor.toInt();
    return _formatarNumero(valorInt);
  }

  // MÉTODO CORRIGIDO: Determina qual status usar baseado no tipo de operação e terminal
  String _obterStatusTexto(Map<String, dynamic> ordem, Map<String, dynamic>? movimentacao) {
    final item = movimentacao ?? (ordem['itens'] as List<Map<String, dynamic>>).firstOrNull;
    
    if (item == null) return 'Sem status';
    
    final tipoOp = item['tipo_op']?.toString() ?? 'venda';
    final terminalOrigemId = item['terminal_orig_id']?.toString();
    final terminalDestinoId = item['terminal_dest_id']?.toString();
    
    // Obter o terminal atual do usuário
    final usuario = UsuarioAtual.instance;
    String? terminalAtual;
    
    if (usuario?.nivel == 3) {
      terminalAtual = _terminalFiltroId;
    } else {
      terminalAtual = usuario?.terminalId;
    }
    
    // PRIORIDADE 1: Se o terminal atual é o DESTINO, usa status_circuito_dest
    if (terminalAtual != null && terminalAtual == terminalDestinoId) {
      final statusDest = item['status_circuito_dest'];
      if (statusDest != null) {
        final codigo = statusDest is int ? statusDest : int.tryParse(statusDest.toString());
        switch (codigo) {
          case 1: return 'Programado';
          case 15: return 'Aguardando';
          case 2: return 'Check-list';
          case 3: return 'Em operação';
          case 4: return 'Emissão NF';
          case 5: return 'Liberado';
          default: return 'Sem status';
        }
      }
    }
    
    // PRIORIDADE 2: Se o terminal atual é a ORIGEM, usa status_circuito_orig
    if (terminalAtual != null && terminalAtual == terminalOrigemId) {
      final statusOrig = item['status_circuito_orig'];
      if (statusOrig != null) {
        final codigo = statusOrig is int ? statusOrig : int.tryParse(statusOrig.toString());
        
        // Mapeamento específico para o fluxo de VENDA no CARREGAMENTO
        if (tipoOp == 'venda') {
          switch (codigo) {
            case 1: return 'Programado';
            case 15: return 'Aguardando';
            case 2: return 'Check-list';
            case 3: return 'Emissão NF';   // Status 3 para 'venda' é Emissão NF
            case 4: return 'Em operação';  // Status 4 para 'venda' é Em operação
            case 5: return 'Liberado';
            default: return 'Sem status';
          }
        }

        switch (codigo) {
          case 1: return 'Programado';
          case 15: return 'Aguardando';
          case 2: return 'Check-list';
          case 3: return 'Em operação';
          case 4: return 'Emissão NF';
          case 5: return 'Liberado';
          default: return 'Sem status';
        }
      }
    }
    
    // Fallback: tenta qualquer status disponível
    dynamic statusCodigo;
    
    if (tipoOp == 'transf') {
      if (terminalAtual == terminalOrigemId) {
        statusCodigo = item['status_circuito_orig'];
      } else if (terminalAtual == terminalDestinoId) {
        statusCodigo = item['status_circuito_dest'];
      } else {
        statusCodigo = item['status_circuito_orig'] ?? item['status_circuito_dest'];
      }
    } else if (tipoOp == 'usina') {
      statusCodigo = item['status_circuito_dest'];
    } else {
      statusCodigo = item['status_circuito_orig'];
    }
    
    if (statusCodigo == null) return 'Sem status';
    
    final codigo = statusCodigo is int ? statusCodigo : int.tryParse(statusCodigo.toString());
    
    switch (codigo) {
      case 1: return 'Programado';
      case 15: return 'Aguardando';
      case 2: return 'Check-list';
      case 3: return 'Em operação';
      case 4: return 'Emissão NF';
      case 5: return 'Liberado';
      default: return 'Sem status';
    }
  }  

  String _obterTipoOpTexto(dynamic tipoOp) {
    final tipoOpStr = tipoOp?.toString() ?? 'venda';
    switch (tipoOpStr.toLowerCase()) {
      case 'transf':
        return 'Transferência';
      case 'venda':
        return 'Venda';
      case 'emprestimo':
        return 'Empréstimo';
      case 'outras_op':
        return 'Outras Op.';
      case 'consumo':
        return 'Consumo Próprio';
      default:
        return tipoOpStr;
    }
  }
  
  String _formatarPlacas(dynamic placasData) {
    if (placasData == null) return 'N/I';
    
    if (placasData is List) {
      return placasData.where((p) => p != null && p.toString().isNotEmpty)
                      .map((p) => p.toString())
                      .join(', ');
    } else if (placasData is String) {
      try {
        if (placasData.startsWith('{') && placasData.endsWith('}')) {
          final limpo = placasData.substring(1, placasData.length - 1);
          final placas = limpo.split(',')
                              .map((p) => p.trim())
                              .where((p) => p.isNotEmpty && p != 'null')
                              .toList();
          return placas.join(', ');
        }
        return placasData;
      } catch (e) {
        return placasData;
      }
    }
    return placasData.toString();
  }

  String _formatarData(String? dataString) {
    if (dataString == null) return 'Data não informada';
    
    try {
      final data = DateTime.parse(dataString);
      return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
    } catch (e) {
      return dataString;
    }
  }  

  Widget _buildFiltros() {
    final usuario = UsuarioAtual.instance;
    final mostraFiltroTerminal = usuario?.nivel == 3;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (mostraFiltroTerminal) ...[
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                value: _terminalFiltroId,
                decoration: InputDecoration(
                  labelText: 'Terminal *',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 12,
                  ),
                  suffixIcon: _terminalFiltroId == null 
                      ? Icon(Icons.error, color: Colors.orange, size: 18)
                      : null,
                ),
                items: _terminais.map((terminal) {
                  return DropdownMenuItem(
                    value: terminal['id'].toString(),
                    child: Text(terminal['nome'].toString(), style: const TextStyle(fontSize: 13)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _terminalFiltroId = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Selecione um terminal';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Campo único de Data (botão semelhante ao de historico_cacl)
          SizedBox(
            width: 140,
            child: Builder(builder: (context) {
              final textoData = _dataInicioController.text.trim().isNotEmpty
                  ? _dataInicioController.text
                  : 'Data';

              return InkWell(
                onTap: () async {
                  DateTime inicial = DateTime.now();
                  try {
                    final partes = _dataInicioController.text.split('/');
                    if (partes.length == 3) {
                      inicial = DateTime(
                        int.parse(partes[2]),
                        int.parse(partes[1]),
                        int.parse(partes[0]),
                      );
                    }
                  } catch (_) {}

                  DateTime tempDate = inicial;
                  final data = await showDialog<DateTime>(
                    context: context,
                    builder: (BuildContext context) {
                      return Dialog(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        child: Container(
                          width: 350,
                          padding: const EdgeInsets.all(20),
                          child: StatefulBuilder(
                            builder: (context, setStateDialog) {
                              int? hoveredDay;
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today, color: Color(0xFF0D47A1), size: 24),
                                      const SizedBox(width: 12),
                                      const Text('Filtrar por data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF0D47A1))),
                                      const Spacer(),
                                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop(), color: Colors.grey, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        IconButton(icon: const Icon(Icons.chevron_left, color: Color(0xFF0D47A1)), onPressed: () { setStateDialog(() { tempDate = DateTime(tempDate.year, tempDate.month - 1, tempDate.day); }); }),
                                        Text('${_getMonthName(tempDate.month)} ${tempDate.year}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF0D47A1))),
                                        IconButton(icon: const Icon(Icons.chevron_right, color: Color(0xFF0D47A1)), onPressed: () { setStateDialog(() { tempDate = DateTime(tempDate.year, tempDate.month + 1, tempDate.day); }); }),
                                      ],
                                    ),
                                  ),
                                  GridView.count(
                                    shrinkWrap: true,
                                    crossAxisCount: 7,
                                    childAspectRatio: 1.0,
                                    children: ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'].map((day) {
                                      return Center(child: Text(day, style: const TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.bold)));
                                    }).toList(),
                                  ),
                                  GridView.count(
                                    shrinkWrap: true,
                                    crossAxisCount: 7,
                                    childAspectRatio: 1.0,
                                    children: _getDaysInMonth(tempDate).map((day) {
                                      final isSelected = day != null && day == tempDate.day;
                                      final isToday = day != null && day == DateTime.now().day && tempDate.month == DateTime.now().month && tempDate.year == DateTime.now().year;
                                      return StatefulBuilder(
                                        builder: (context, setDayState) {
                                          return MouseRegion(
                                            cursor: day != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
                                            onEnter: (_) { if (day != null) { setDayState(() => hoveredDay = day); } },
                                            onExit: (_) { if (day != null) { setDayState(() => hoveredDay = null); } },
                                            child: GestureDetector(
                                              onTap: day != null ? () { setStateDialog(() { tempDate = DateTime(tempDate.year, tempDate.month, day); }); } : null,
                                              child: Container(
                                                margin: const EdgeInsets.all(2),
                                                decoration: BoxDecoration(
                                                  color: isSelected ? const Color(0xFF0D47A1)
                                                      : (day != null && hoveredDay == day) ? const Color(0xFF0D47A1).withOpacity(0.1)
                                                      : isToday ? const Color(0x220D47A1) : Colors.transparent,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Center(child: Text(
                                                  day != null ? day.toString() : '',
                                                  style: TextStyle(
                                                    color: isSelected ? Colors.white : isToday || (day != null && hoveredDay == day) ? const Color(0xFF0D47A1) : Colors.black87,
                                                    fontWeight: isSelected || isToday || (day != null && hoveredDay == day) ? FontWeight.bold : FontWeight.normal,
                                                  ),
                                                )),
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(onPressed: () => Navigator.of(context).pop(), style: TextButton.styleFrom(foregroundColor: Colors.black87, padding: const EdgeInsets.symmetric(horizontal: 16)), child: const Text('CANCELAR')),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: () => Navigator.of(context).pop(tempDate),
                                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                        child: const Text('SELECIONAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      );
                    },
                  );

                  if (data != null) {
                    setState(() {
                      _dataInicioController.text = '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
                    });

                    // Aplicar filtros automaticamente ao selecionar nova data
                    await _aplicarFiltros();
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey.shade50,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: Color(0xFF0D47A1)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          textoData,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black87,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),

          const SizedBox(width: 8),

          SizedBox(
            width: 140,
            child: DropdownButtonFormField<String>(
              value: _tipoFiltro,
              decoration: InputDecoration(
                labelText: 'Tipo',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              dropdownColor: Colors.white,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              items: const [
                DropdownMenuItem(
                  value: null,
                  child: Text('Todos'),
                ),
                DropdownMenuItem(
                  value: 'entrada',
                  child: Text('Entrada'),
                ),
                DropdownMenuItem(
                  value: 'saida',
                  child: Text('Saída'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _tipoFiltro = value;
                });
                _aplicarFiltros();
              },
            ),
          ),

          const SizedBox(width: 8),

          Expanded(
            flex: 3,
            child: TextField(
              controller: _filtroGeralController,
              onChanged: (_) => _aplicarFiltroTexto(),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Buscar (placa, cliente, status...)',
                labelStyle: const TextStyle(fontSize: 12),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 1.5),
                ),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF0D47A1), size: 20),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ),

          // Espaço realocado para o campo de pesquisa (botões removidos)
        ],
      ),
    );
  }

  Widget _buildCarregando() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF0D47A1)),
          SizedBox(height: 20),
          Text(
            'Carregando ordens...',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErro() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 60,
          ),
          const SizedBox(height: 20),
          const Text(
            'Erro ao carregar dados',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _mensagemErro,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _aplicarFiltros,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1),
              foregroundColor: Colors.white,
            ),
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  Widget _buildSemDados() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.list_alt_outlined,
            color: Colors.grey,
            size: 60,
          ),
          const SizedBox(height: 20),
          const Text(
            'Nenhuma ordem encontrada',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Tente ajustar os filtros de data.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: 180,
            height: 48,
            child: ElevatedButton(
              onPressed: _aplicarFiltros,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D47A1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 3,
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.refresh, size: 22),
                  SizedBox(width: 10),
                  Text('Nova busca'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _obterCorFundoCard(Map<String, dynamic> ordem) {
    return Colors.white;
  }

  Widget _buildItemOrdem(Map<String, dynamic> ordem, int index) {
    final tipoOp = ordem['tipo_op']?.toString() ?? 'venda';
    final tipoOpTexto = _obterTipoOpTexto(tipoOp);
    final statusTexto = _obterStatusTexto(ordem, null);
    
    final statusCor = _obterCorStatusTimeline(ordem, null);
    
    final placasFormatadas = _formatarPlacas(ordem['placas']);
    final dataMov = _formatarData(ordem['data_mov']?.toString());
    
    final produtosAgrupados =
        ordem['produtos_agrupados'] as Map<String, Map<String, double>>;

    final corFundoCard = _obterCorFundoCard(ordem);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: corFundoCard,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              _abrirDetalhesOrdem(ordem);
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Menu de 3 pontos (lado esquerdo antes do ícone direcional é mantido; o menu vai no final)
                  // Ícone de direção (origem/destino do terminal do usuário)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Builder(builder: (context) {
                      final usuario = UsuarioAtual.instance;
                      final terminalAtual = usuario?.nivel == 3 ? _terminalFiltroId : usuario?.terminalId;

                      final itensLocal = ordem['itens'] as List<dynamic>;

                      final ehOrigem = itensLocal.any((item) =>
                          item['terminal_orig_id']?.toString() == terminalAtual);

                      final ehDestino = itensLocal.any((item) =>
                          item['terminal_dest_id']?.toString() == terminalAtual);

                      if (ehDestino && !ehOrigem) {
                        return Icon(Icons.control_point, size: 30, color: Colors.green.shade700);
                      } else if (ehOrigem && !ehDestino) {
                        return Icon(Icons.subdirectory_arrow_right, size: 30, color: Colors.red.shade700);
                      } else if (ehOrigem && ehDestino) {
                        return Icon(Icons.sync, size: 30, color: Colors.purple.shade400);
                      }

                      return Icon(Icons.remove_circle_outline, size: 26, color: Colors.grey.shade400);
                    }),
                  ),

                  Container(
                    width: 120, // Largura fixa de 120px
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: statusCor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: statusCor.withOpacity(0.25),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          statusTexto,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: statusCor,
                            height: 1.1,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusCor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: statusCor.withOpacity(0.2),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            tipoOpTexto,
                            style: const TextStyle(
                              fontSize: 10, // Tamanho fixo para todos os tipos
                              fontWeight: FontWeight.w600,
                              color: Color.fromARGB(255, 121, 121, 121),
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  dataMov,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(width: 16),
                            
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.directions_car,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      tipoOp == 'transf' && ordem['motorista_nome'] != null
                                          ? '$placasFormatadas - ${ordem['motorista_nome']}'
                                          : placasFormatadas,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black87,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 10),
                        
                        if (produtosAgrupados.isNotEmpty)
                          Wrap(
                            spacing: 10,
                            runSpacing: 6,
                            children: produtosAgrupados.entries
                                .expand((produtoEntry) {
                              final nomeProduto = produtoEntry.key;
                              final cor = _obterCorProduto(nomeProduto);

                              return produtoEntry.value.entries.map((infoEntry) {
                                final textoInfo = infoEntry.key;
                                final quantidade = infoEntry.value;

                                return Container(
                                  constraints: BoxConstraints(
                                    maxWidth: tipoOp == 'transf' ? 400 : 260,
                                  ),
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
                                          _formatarNumeroDouble(quantidade),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),

                                      Flexible(
                                        child: Container(
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
                                                tipoOp == 'transf' 
                                                    ? nomeProduto 
                                                    : _abreviarTexto(nomeProduto, 15),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: cor,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),

                                              Text(
                                                tipoOp == 'transf' 
                                                    ? textoInfo 
                                                    : _abreviarTexto(textoInfo, 20),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey.shade700,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList();
                            }).toList(),
                          ),
                        
                        if (produtosAgrupados.isEmpty)
                          Container(
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
                      ],
                    ),
                  ),

                  // Menu de 3 pontos
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                    color: const Color(0xFFFFFDF5),
                    onSelected: (value) {
                      if (value == 'cancelar') {
                        _cancelarOrdem(ordem);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem<String>(
                        value: 'cancelar',
                        child: Row(
                          children: [
                            Icon(Icons.cancel_outlined, color: Colors.red, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Cancelar ordem',
                              style: TextStyle(color: Colors.red),
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
      ),
    );
  }

  String _abreviarTexto(String texto, int maxLength) {
    if (texto.length <= maxLength) return texto;
    return '${texto.substring(0, maxLength)}...';
  }

  Color _obterCorStatusTimeline(Map<String, dynamic> ordem, Map<String, dynamic>? movimentacao) {
    final statusTexto = _obterStatusTexto(ordem, movimentacao);
    
    switch (statusTexto) {
      case 'Programado': return const Color.fromARGB(255, 61, 160, 206);
      case 'Aguardando': return const Color.fromARGB(255, 5, 151, 0);
      case 'Check-list': return const Color(0xFFF57C00);
      case 'Em operação': return const Color(0xFF7B1FA2);
      case 'Emissão NF': return const Color(0xFFC2185B);
      case 'Liberado': return const Color.fromARGB(255, 42, 199, 50);
      default: return Colors.grey;
    }
  }  

  @override
  void dispose() {
    _filtroGeralController.dispose();
    _dataInicioController.dispose();
    _dataFimController.dispose();
    super.dispose();
  }

  String get _terminalAtualId {
    final usuario = UsuarioAtual.instance;
    
    if (usuario == null) {
      return '';
    }
    
    String terminalId;
    
    if (usuario.nivel == 3) {
      terminalId = _terminalFiltroId ?? '';
      
      if (terminalId.isEmpty && _terminais.isNotEmpty) {
        terminalId = _terminais.first['id'].toString();
        _terminalFiltroId = terminalId;
      }
    } else {
      terminalId = usuario.terminalId ?? '';
    }
    
    return terminalId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0D47A1),
        title: Text(
          _mostrarDetalhes 
              ? 'Detalhes da Ordem' 
              : 'Acompanhamento de Ordens - ${_terminais.firstWhere((f) => f['id'].toString() == _terminalFiltroId, orElse: () => {'nome': ''})['nome'] ?? ''}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_mostrarDetalhes) {
              _voltarParaLista();
            } else {
              widget.onVoltar();
            }
          },
        ),
        actions: [
          if (!_carregando && !_erro && !_mostrarDetalhes)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _aplicarFiltros,
              tooltip: 'Atualizar ordens',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _mostrarDetalhes
            ? DetalhesOrdemView(
                ordem: _ordemSelecionada!,
                terminalAtualId: _terminalAtualId,
                dataFiltro: _dataInicioController.text,
              )
            : _mostrarEscolherTerminal
                ? EscolherTerminalPage(
                    onVoltar: () {
                      setState(() {
                        _mostrarEscolherTerminal = false;
                      });
                      widget.onVoltar();
                    },
                    onSelecionarTerminal: (id) => _onTerminalSelecionado(id),
                    titulo: 'Selecionar terminal',
                    corPrimaria: const Color(0xFF0D47A1),
                  )
                : Column(
                    children: [
                      _buildFiltros(),
                      Expanded(
                        child: _carregando
                            ? _buildCarregando()
                            : _erro
                                ? _buildErro()
                                : _ordensFiltradas.isEmpty
                                    ? _buildSemDados()
                                    : ListView.builder(
                                        itemCount: _ordensFiltradas.length,
                                        itemBuilder: (context, index) {
                                          return _buildItemOrdem(
                                            _ordensFiltradas[index],
                                            index,
                                          );
                                        },
                                      ),
                      ),
                    ],
                  ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    return months[month - 1];
  }

  List<int?> _getDaysInMonth(DateTime date) {
    final firstDay = DateTime(date.year, date.month, 1);
    final lastDay = DateTime(date.year, date.month + 1, 0);
    final firstWeekday = firstDay.weekday;
    final startOffset = firstWeekday == 7 ? 0 : firstWeekday;
    List<int?> days = [];
    for (int i = 0; i < startOffset; i++) {
      days.add(null);
    }
    for (int i = 1; i <= lastDay.day; i++) {
      days.add(i);
    }
    while (days.length < 42) {
      days.add(null);
    }
    return days;
  }
}