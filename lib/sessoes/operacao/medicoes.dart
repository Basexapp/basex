import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_page.dart';
import 'dialog_medicoes_gasol.dart';
import 'dialog_medicoes_alcool.dart';

class MedicoesPage extends StatefulWidget {
  final VoidCallback onVoltar;
  final String? produtoNome;
  final String? tanqueReferencia;

  const MedicoesPage({
    super.key,
    required this.onVoltar,
    this.produtoNome,
    this.tanqueReferencia,
  });

  @override
  State<MedicoesPage> createState() => _MedicoesPageState();
}

class _MedicoesPageState extends State<MedicoesPage> {
  int? _hoverIndex;
  List<Map<String, dynamic>> _medicoesReais = [];
  bool _carregandoLista = false;
  bool _ehAlcool = false;

  @override
  void initState() {
    super.initState();
    _verificarTipoProduto();
    _carregarMedicoes();
  }

  // ── Persistência e busca de dados ─────────────────────────────────────────

  Future<void> _verificarTipoProduto() async {
    if (widget.produtoNome == null) return;
    final supabase = Supabase.instance.client;
    try {
      final prodRes = await supabase
          .from('produtos')
          .select('tabela_alcool')
          .eq('nome', widget.produtoNome!)
          .maybeSingle();
      if (prodRes != null && mounted) {
        setState(() {
          _ehAlcool = prodRes['tabela_alcool'] == true;
        });
      }
    } catch (e) {
      print('Erro ao verificar tipo de produto: $e');
    }
  }

  Future<void> _carregarMedicoes() async {
    if (mounted) setState(() => _carregandoLista = true);
    final supabase = Supabase.instance.client;
    try {
      final terminalId = UsuarioAtual.instance?.terminalId;
      if (terminalId == null) return;

      String? tanqueId;
      if (widget.tanqueReferencia != null) {
        final tanqueRes = await supabase
            .from('tanques')
            .select('id')
            .eq('terminal_id', terminalId)
            .eq('referencia', widget.tanqueReferencia!)
            .maybeSingle();
        if (tanqueRes != null) {
          tanqueId = tanqueRes['id'] as String?;
        }
      }

      var query = supabase
          .from('medicoes')
          .select('*, tanques(referencia)')
          .eq('terminal_id', terminalId);

      if (tanqueId != null) {
        query = query.eq('tanque_id', tanqueId);
      }

      final res = await query
          .order('data', ascending: false)
          .order('horario', ascending: false);

      if (mounted) {
        setState(() {
          _medicoesReais = List<Map<String, dynamic>>.from(res);
          _carregandoLista = false;
        });
      }
    } catch (e) {
      print('Erro ao carregar medições: $e');
      if (mounted) setState(() => _carregandoLista = false);
    }
  }

  String _formatarVolume(double volume) {
    final inteiro = volume.round();
    String str = inteiro.toString();
    if (str.length > 3) {
      final buf = StringBuffer();
      int contador = 0;
      for (int i = str.length - 1; i >= 0; i--) {
        buf.write(str[i]);
        contador++;
        if (contador == 3 && i > 0) {
          buf.write('.');
          contador = 0;
        }
      }
      str = buf.toString().split('').reversed.join('');
    }
    return '$str L';
  }

  void _abrirDialogOInserirMedicao() async {
    final supabase = Supabase.instance.client;
    bool usarTabelaAlcool = false;

    if (widget.produtoNome != null) {
      try {
        final prodRes = await supabase
            .from('produtos')
            .select('tabela_alcool')
            .eq('nome', widget.produtoNome!)
            .maybeSingle();
        if (prodRes != null && prodRes['tabela_alcool'] == true) {
          usarTabelaAlcool = true;
        }
      } catch (e) {
        print('Erro ao verificar tabela_alcool: $e');
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => usarTabelaAlcool
          ? DialogMedicoesAlcool(
              produtoNome: widget.produtoNome,
              tanqueReferencia: widget.tanqueReferencia,
              onSaved: (_) => _carregarMedicoes(),
            )
          : DialogMedicoesGasol(
              produtoNome: widget.produtoNome,
              tanqueReferencia: widget.tanqueReferencia,
              onSaved: (_) => _carregarMedicoes(),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15.0),
        child: Column(
          children: [
            // Cabeçalho similar ao HistoricoCaclPage
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(0, 8, 16, 8),
              decoration: const BoxDecoration(
                color: Color(0xFFF8F9FA),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
                    onPressed: widget.onVoltar,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.produtoNome != null 
                              ? 'Medições - ${widget.tanqueReferencia ?? ""} - ${widget.produtoNome}'
                              : 'Medições',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                        const Text(
                          'Lista de medições realizadas',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Cabeçalho da Tabela
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Container(width: 4), // Espaço para barra colorida
                  const SizedBox(width: 12),
                  _buildHeaderCell('Tanque', flex: 2),
                  _buildHeaderCell('Data', flex: 2),
                  _buildHeaderCell('Horário', flex: 2),
                  _buildHeaderCell('Nº controle', flex: 2),
                  _buildHeaderCell('Alt. cm', flex: 2),
                  _buildHeaderCell('Alt. mm', flex: 2),
                  _buildHeaderCell('Vol. Amb', flex: 3),
                  _buildHeaderCell('Temp. Tq', flex: 2),
                  _buildHeaderCell('Dens. Obs', flex: 2),
                  if (!_ehAlcool) _buildHeaderCell('Temp. Obs', flex: 2),
                  if (!_ehAlcool) _buildHeaderCell('Dens. 20°C', flex: 2),
                  if (_ehAlcool) _buildHeaderCell('Grau GL', flex: 2),
                  _buildHeaderCell('FCV', flex: 2),
                  _buildHeaderCell('Massa', flex: 3),
                  _buildHeaderCell('Vol. 20°C', flex: 3),
                  const SizedBox(width: 24), // Espaço para o ícone
                ],
              ),
            ),

            const Divider(height: 1),

            // Lista de Medições
            Expanded(
              child: _carregandoLista
                  ? const Center(child: CircularProgressIndicator())
                  : _medicoesReais.isEmpty
                      ? const Center(child: Text('Nenhuma medição encontrada.'))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: _medicoesReais.length,
                          itemBuilder: (context, index) {
                            final medicao = _medicoesReais[index];
                            return MouseRegion(
                              cursor: SystemMouseCursors.click,
                              onEnter: (_) => setState(() => _hoverIndex = index),
                              onExit: (_) => setState(() => _hoverIndex = null),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                color: _hoverIndex == index
                                    ? Colors.grey.shade200
                                    : (index.isEven ? Colors.white : Colors.grey.shade50),
                                child: Row(
                                  children: [
                                    // Indicador de status (decorativo)
                                    Container(
                                      width: 4,
                                      height: 24,
                                      color: const Color(0xFF0D47A1).withOpacity(0.5),
                                    ),
                                    const SizedBox(width: 12),
                                    _buildDataCell(medicao['tanques']?['referencia'], flex: 2),
                                    _buildDataCell(
                                        medicao['data'] != null
                                            ? DateFormat('dd/MM/yyyy').format(DateTime.parse(medicao['data']))
                                            : '-',
                                        flex: 2),
                                    _buildDataCell(
                                        medicao['horario'] != null ? '${medicao['horario'].toString().substring(0, 5)} h' : '-',
                                        flex: 2),
                                    _buildDataCell(medicao['num_controle']?.toString(), flex: 2),
                                    _buildDataCell(medicao['altura_total_cm']?.toString(), flex: 2),
                                    _buildDataCell(medicao['altura_total_mm']?.toString(), flex: 2),
                                    _buildDataCell(
                                        medicao['volume_ambiente'] != null
                                            ? _formatarVolume(medicao['volume_ambiente'].toDouble()).replaceAll(' L', '')
                                            : '-',
                                        flex: 3),
                                    _buildDataCell(
                                        medicao['temperatura_tanque'] != null
                                            ? '${medicao['temperatura_tanque'].toString().replaceAll('.', ',')} °C'
                                            : '-',
                                        flex: 2),
                                    _buildDataCell(
                                        medicao['densidade_observada'] != null
                                            ? double.parse(medicao['densidade_observada'].toString())
                                                .toStringAsFixed(4)
                                                .replaceAll('.', ',')
                                            : '-',
                                        flex: 2),
                                    if (!_ehAlcool)
                                      _buildDataCell(
                                          medicao['temperatura_amostra'] != null
                                              ? '${medicao['temperatura_amostra'].toString().replaceAll('.', ',')} °C'
                                              : '-',
                                          flex: 2),
                                    if (!_ehAlcool)
                                      _buildDataCell(
                                          medicao['densidade_20'] != null
                                              ? double.parse(medicao['densidade_20'].toString())
                                                  .toStringAsFixed(4)
                                                  .replaceAll('.', ',')
                                              : '-',
                                          flex: 2),
                                    if (_ehAlcool)
                                      _buildDataCell(
                                          medicao['grau_alcolico_gl'] != null
                                              ? '${medicao['grau_alcolico_gl'].toString().replaceAll('.', ',')} °GL'
                                              : '-',
                                          flex: 2),
                                    _buildDataCell(medicao['fcv']?.toString().replaceAll('.', ','), flex: 2),
                                    _buildDataCell(
                                        medicao['massa'] != null
                                            ? _formatarVolume(medicao['massa'].toDouble()).replaceAll(' L', '')
                                            : '-',
                                        flex: 3),
                                    _buildDataCell(
                                        medicao['volume_20'] != null
                                            ? _formatarVolume(medicao['volume_20'].toDouble()).replaceAll(' L', '')
                                            : '-',
                                        flex: 3),
                                    const SizedBox(width: 24), // Espaço para manter alinhamento
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _abrirDialogOInserirMedicao,
        backgroundColor: const Color(0xFF0D47A1),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildHeaderCell(String label, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildDataCell(String? value, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        (value == null || value == 'null') ? '-' : value,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
