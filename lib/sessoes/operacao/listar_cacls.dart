import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
//import 'cacl.dart';
import 'medicoes_emitir_cacl.dart';
import 'medicoes_editar_cacl.dart';
import 'cacl_visualizacao.dart';

class ListarCaclsPage extends StatefulWidget {
  final VoidCallback onVoltar;
  final String filialId;
  final String filialNome;
  final VoidCallback onIrParaEmissao;
  final VoidCallback? onFinalizarCACL;

  const ListarCaclsPage({
    super.key,
    required this.onVoltar,
    required this.filialId,
    required this.filialNome,
    required this.onIrParaEmissao,
    this.onFinalizarCACL,
  });

  @override
  State<ListarCaclsPage> createState() => _ListarCaclsPageState();
}

class _ListarCaclsPageState extends State<ListarCaclsPage> with WidgetsBindingObserver {
  bool _carregando = true;
  List<Map<String, dynamic>> _cacles = [];
  int? _hoverIndex;
  DateTime? _dataFiltro;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // fixar data inicial
    _dataFiltro = DateTime.now();
    _carregarCaclsSimples();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshData();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _refreshData();
      }
    });
  }

  @override
  void didUpdateWidget(ListarCaclsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filialId != widget.filialId) {
      _refreshData();
    }
  }

  Future<void> _refreshData() async {
    await _carregarCaclsSimples();
  }

  Future<void> _carregarCaclsSimples() async {
    if (_carregando && _cacles.isNotEmpty) return;
    
    setState(() => _carregando = true);

    try {
      final supabase = Supabase.instance.client;
      final dataAtual = _dataFiltro ?? DateTime.now();
      final dataFormatada =
          '${dataAtual.year}-${dataAtual.month.toString().padLeft(2, '0')}-${dataAtual.day.toString().padLeft(2, '0')}';

      final todosCacls = await supabase
          .from('cacl')
          .select('''
            id,
            numero_controle,
            data,
            tanque_id,
            tanques:tanque_id (referencia),
            produto_id,
            produtos:produto_id (nome),
            terminal_id,
            terminais:terminal_id (nome),
            status,
            horario_inicial,
            horario_final,
            volume_produto_inicial,
            volume_produto_final,
            volume_total_liquido_inicial,
            volume_total_liquido_final
          ''')
          .eq('filial_id', widget.filialId)
          .order('created_at', ascending: false);

      // ALTERAÇÃO: Inclui CACLs cancelados na lista
      final caclsFiltrados = todosCacls.where((cacl) {
        final status = cacl['status']?.toString().toLowerCase() ?? '';
        final data = cacl['data']?.toString() ?? '';

        // Regra 1: Qualquer CACL com data de hoje (independente do status)
        if (data == dataFormatada) {
          return true;
        }

        // Regra 2: Qualquer CACL com status pendente (independente da data)
        if (status.contains('pendente') || status.contains('aguardando')) {
          return true;
        }

        return false;
      }).toList();

      setState(() {
        _cacles = List<Map<String, dynamic>>.from(caclsFiltrados);
      });
    } catch (e) {
      debugPrint('❌ Erro ao carregar CACLs: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar dados: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  Future<void> _cancelarCacl(String caclId) async {
    try {
      final supabase = Supabase.instance.client;
      
      await supabase
          .from('cacl')
          .update({'status': 'cancelado'})
          .eq('id', caclId);
      
      if (mounted) {
        setState(() {
          final index = _cacles.indexWhere((c) => c['id'] == caclId);
          if (index != -1) {
            _cacles[index]['status'] = 'cancelado';
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CACL cancelado com sucesso.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erro ao cancelar CACL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao cancelar CACL: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  String _formatarData(dynamic data) {
    if (data == null) return '-';
    try {
      final d = DateTime.parse(data.toString());
      return '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/'
          '${d.year}';
    } catch (_) {
      return data.toString();
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'emitido':
        return Colors.green;
      case 'pendente':
      case 'aguardando':
        return Colors.orange;
      case 'cancelado':
        return const Color.fromARGB(255, 192, 43, 43);
      default:
        return const Color.fromARGB(255, 128, 128, 128);
    }
  }

  Color _getCardColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'emitido':
        return Colors.green.shade50;
      case 'pendente':
      case 'aguardando':
        return Colors.orange.shade50;
      case 'cancelado':
        return Colors.grey.shade50;
      default:
        return Colors.grey.shade50;
    }
  }

  Color _getBorderColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'emitido':
        return Colors.green.shade300;
      case 'pendente':
      case 'aguardando':
        return Colors.orange.shade300;
      case 'cancelado':
        return Colors.grey.shade300;
      default:
        return Colors.grey.shade300;
    }
  }

  String _getStatusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'emitido':
        return 'Emitido';
      case 'pendente':
      case 'aguardando':
        return 'Pendente';
      case 'cancelado':
        return 'Cancelado';
      default:
        return 'Sem status';
    }
  }

  String _formatarHorario(dynamic horarioInicial, dynamic horarioFinal) {
    if (horarioInicial != null && horarioFinal != null) {
      return '$horarioInicial - $horarioFinal';
    } else if (horarioInicial != null) {
      return 'Início: $horarioInicial';
    } else if (horarioFinal != null) {
      return 'Fim: $horarioFinal';
    }
    return 'Sem horário';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ===== CABEÇALHO =====
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
              onPressed: widget.onVoltar,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Listar CACLs',
                    style: TextStyle(
                      fontSize: 20,
                      color: Color(0xFF0D47A1),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    widget.filialNome,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 180,
              child: Builder(builder: (context) {
                final textoData = _dataFiltro != null
                    ? '${_dataFiltro!.day.toString().padLeft(2, '0')}/${_dataFiltro!.month.toString().padLeft(2, '0')}/${_dataFiltro!.year}'
                    : 'Data';

                return InkWell(
                  onTap: () async {
                    DateTime tempDate = _dataFiltro ?? DateTime.now();
                    final dataSelecionada = await showDialog<DateTime>(
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

                    if (dataSelecionada != null) {
                      setState(() {
                        _dataFiltro = DateTime(
                          dataSelecionada.year,
                          dataSelecionada.month,
                          dataSelecionada.day,
                        );
                      });
                      _refreshData();
                    }
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF0D47A1).withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(4),
                      color: Colors.white,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Expanded(
                          child: Text(
                            textoData,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF0D47A1),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF0D47A1)),
              onPressed: _refreshData,
              tooltip: 'Atualizar lista',
            ),
            const SizedBox(width: 10),
          ],
        ),
        const SizedBox(height: 10),
        const Divider(),
        const SizedBox(height: 10),

        // ===== BOTÃO EMITIR CACL =====
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => MedicaoTanquesPage(
                    onVoltar: () {
                      Navigator.pop(context);
                      _refreshData();
                    },
                    onFinalizarCACL: () {
                      widget.onFinalizarCACL?.call();
                      _refreshData();
                    },
                    caclesHoje: _cacles,
                  ),
                ),
              ).then((_) {
                _refreshData();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 45),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, size: 20),
                SizedBox(width: 8),
                Text(
                  'Emitir CACL',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // ===== LISTA DE CACLS =====
        Expanded(
          child: _carregando && _cacles.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF0D47A1),
                  ),
                )
              : _cacles.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 60,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Nenhum CACL encontrado',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Clique em "Emitir CACL" para criar um novo',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _refreshData,
                      color: const Color(0xFF0D47A1),
                      child: ListView.separated(
                        itemCount: _cacles.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemBuilder: (context, index) {
                          final cacl = _cacles[index];
                          final status = cacl['status']?.toString();
                          final isCancelado = status?.toLowerCase() == 'cancelado';
                          final statusColor = _getStatusColor(status);
                          final cardColor = _getCardColor(status);
                          final borderColor = _getBorderColor(status);
                          final statusText = _getStatusText(status);
                          final tanqueNome = cacl['tanques']?['referencia']?.toString();
                          final tanque = tanqueNome ?? '-';
                          final produto = cacl['produtos']?['nome']?.toString() ?? 'Produto não informado';
                          final numeroControle = cacl['numero_controle']?.toString() ?? '';
                          final data = _formatarData(cacl['data']);
                          final horario = _formatarHorario(
                            cacl['horario_inicial'],
                            cacl['horario_final'],
                          );

                          return MouseRegion(
                            cursor: SystemMouseCursors.click,
                            onEnter: (_) {
                              setState(() => _hoverIndex = index);
                            },
                            onExit: (_) {
                              setState(() => _hoverIndex = null);
                            },
                            child: GestureDetector(
                              onTap: () async {
                                final caclId = cacl['id'].toString();

                                if (!context.mounted) return;

                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CaclHistoricoPage(
                                      caclId: caclId,
                                      onVoltar: () {
                                        Navigator.pop(context);
                                      },
                                    ),
                                  ),
                                );
                                
                                _refreshData();
                              },
                              child: Opacity(
                                // Opacidade reduzida para níveis 2 e 3 quando cancelado
                                opacity: isCancelado ? 0.85 : 1.0,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOut,
                                  transform: _hoverIndex == index
                                      ? (Matrix4.identity()..scale(1.01))
                                      : Matrix4.identity(),
                                  decoration: BoxDecoration(
                                    color: _hoverIndex == index
                                        ? cardColor.withOpacity(0.85)
                                        : cardColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: borderColor,
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(
                                          _hoverIndex == index ? 0.15 : 0.05,
                                        ),
                                        blurRadius: _hoverIndex == index ? 12 : 4,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Indicador de status (barra lateral)
                                        Container(
                                          width: 4,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            color: statusColor,
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        
                                        // Informações principais
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Linha 1: Tanque (destaque)
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.storage,
                                                    size: 16,
                                                    color: Colors.black54,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Tanque $tanque',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                      // Texto mais claro para níveis 2 e 3 quando cancelado
                                                      color: isCancelado 
                                                          ? Colors.grey 
                                                          : Colors.black87,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              
                                              // Linha 2: Produto e Número de Controle
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.local_gas_station,
                                                    size: 14,
                                                    color: isCancelado
                                                        ? Colors.grey 
                                                        : Colors.black54,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Flexible(
                                                    child: RichText(
                                                      overflow: TextOverflow.ellipsis,
                                                      maxLines: 1,
                                                      text: TextSpan(
                                                        children: [
                                                          TextSpan(
                                                            text: produto,
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              color: isCancelado 
                                                                  ? Colors.grey 
                                                                  : Colors.black87,
                                                            ),
                                                          ),
                                                          if (numeroControle.isNotEmpty) ...[
                                                            const TextSpan(
                                                              text: '  •  ',
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                color: Colors.grey,
                                                              ),
                                                            ),
                                                            TextSpan(
                                                              text: 'CACL: $numeroControle',
                                                              style: TextStyle(
                                                                fontSize: 13,
                                                                color: isCancelado 
                                                                    ? Colors.grey 
                                                                    : const Color.fromARGB(255, 92, 92, 92),
                                                                fontStyle: FontStyle.italic,
                                                              ),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              
                                              // Linha 3: Data e Horário
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.calendar_today,
                                                    size: 14,
                                                    color: isCancelado
                                                        ? Colors.grey 
                                                        : Colors.black54,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    data,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: isCancelado 
                                                          ? Colors.grey 
                                                          : Colors.black54,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 16),
                                                  Icon(
                                                    Icons.access_time,
                                                    size: 14,
                                                    color: isCancelado 
                                                        ? Colors.grey 
                                                        : Colors.black54,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      horario,
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: isCancelado 
                                                            ? Colors.grey 
                                                            : Colors.black54,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        
                                        // Status e ações
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            // Badge de status
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: statusColor.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                statusText,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: statusColor,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            
                                            // Botões de ação
                                            Row(
                                              children: [
                                                // Botão Editar - SOMENTE se status for 'pendente' e não cancelado
                                                if (!isCancelado && 
                                                    (cacl['status']?.toString().toLowerCase() ?? '').contains('pendente'))
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.edit,
                                                      size: 22,
                                                      color: Color(0xFF0D47A1),
                                                    ),
                                                    onPressed: () {
                                                      Navigator.of(context).push(
                                                        MaterialPageRoute(
                                                          builder: (context) => EditarCaclPage(
                                                            onVoltar: () {
                                                              Navigator.pop(context);
                                                              _refreshData();
                                                            },
                                                            caclId: cacl['id'].toString(),
                                                          ),
                                                        ),
                                                      ).then((_) {
                                                        _refreshData();
                                                      });
                                                    },
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
                                                  ),
                                                
                                                // Botão Cancelar CACL
                                                if (!isCancelado)
                                                  ElevatedButton(
                                                    onPressed: () {
                                                      _showDialogCancelarCacl(cacl);
                                                    },
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.red.shade50,
                                                      foregroundColor: Colors.red.shade800,
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      minimumSize: const Size(0, 0),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(6),
                                                        side: BorderSide(color: Colors.red.shade300),
                                                      ),
                                                      elevation: 0,
                                                    ),
                                                    child: const Text(
                                                      'Cancelar\nCACL',
                                                      textAlign: TextAlign.center,
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w600,
                                                      ),
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
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  void _showDialogCancelarCacl(Map<String, dynamic> cacl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 600,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.dangerous_rounded,
                        color: Colors.red.shade700,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Cancelar CACL',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.only(left: 36),
                    child: Text(
                      'Deseja cancelar este CACL?\n\n⚠️ Esta ação é irreversível e não pode ser desfeita.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text(
                          'Voltar',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color.fromARGB(255, 107, 107, 107),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _cancelarCacl(cacl['id'].toString());
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 2,
                          shadowColor: Colors.red.withOpacity(0.3),
                        ),
                        child: const Text(
                          'Sim, cancelar CACL',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
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