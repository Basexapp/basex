import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_page.dart';

class FiltroControleAditivoPage extends StatefulWidget {
  final String? terminalId;
  final String? empresaId;
  final String nomeTerminal;
  final String? empresaNome;
  final Function({
    required String? terminalId,
    required String? empresaId,
    required String nomeTerminal,
    String? empresaNome,
    required DateTime dataInicial,
    required DateTime dataFinal,
    required String tipoRelatorio,
  }) onConsultar;
  final VoidCallback onVoltar;

  const FiltroControleAditivoPage({
    super.key,
    this.terminalId,
    this.empresaId,
    required this.nomeTerminal,
    this.empresaNome,
    required this.onConsultar,
    required this.onVoltar,
  });

  @override
  State<FiltroControleAditivoPage> createState() =>
      _FiltroControleAditivoPageState();
}

class _FiltroControleAditivoPageState extends State<FiltroControleAditivoPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  DateTime _dataInicial = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _dataFinal = DateTime.now();
  String? _terminalSelecionadoId;
  String? _terminalSelecionadoNome;
  String? _empresaSelecionadaId;
  String? _empresaSelecionadaNome;
  String _tipoRelatorio = 'sintetico';
  List<Map<String, dynamic>> _terminaisDisponiveis = [];
  List<Map<String, dynamic>> _empresasDisponiveis = [];
  bool _carregandoTerminais = false;
  bool _carregandoEmpresas = false;
  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    _inicializarFiltros();
  }

  Future<void> _inicializarFiltros() async {
    setState(() => _carregando = true);

    await _carregarTerminaisDisponiveis();

    final usuario = UsuarioAtual.instance;
    final terminalIdInicial =
        widget.terminalId ?? usuario?.terminalId ?? '';

    if (terminalIdInicial.isNotEmpty) {
      final encontrado = _terminaisDisponiveis.firstWhere(
        (t) => t['id'] == terminalIdInicial,
        orElse: () => <String, dynamic>{'id': '', 'nome': ''},
      );
      if (encontrado['id'] != '') {
        _terminalSelecionadoId = encontrado['id'];
        _terminalSelecionadoNome = encontrado['nome'];
      } else {
        _selecionarPrimeiroTerminal();
      }
    } else {
      _selecionarPrimeiroTerminal();
    }

    await _carregarEmpresasDisponiveis();

    setState(() => _carregando = false);
  }

  void _selecionarPrimeiroTerminal() {
    final primeiro = _terminaisDisponiveis.firstWhere(
      (t) => t['id'] != '',
      orElse: () => <String, dynamic>{'id': '', 'nome': ''},
    );
    if (primeiro['id'] != '') {
      _terminalSelecionadoId = primeiro['id'];
      _terminalSelecionadoNome = primeiro['nome'];
    } else {
      _terminalSelecionadoId = '';
      _terminalSelecionadoNome = null;
    }
  }

  Future<void> _carregarTerminaisDisponiveis() async {
    setState(() => _carregandoTerminais = true);

    try {
      final usuario = UsuarioAtual.instance;
      final nivelUsuario = usuario?.nivel ?? 0;
      final empresaIdEfetivo =
          (widget.empresaId ?? usuario?.empresaId ?? '').trim();
      List<Map<String, dynamic>> terminais = [];

      if (nivelUsuario == 4) {
        final terminalId =
            (widget.terminalId ?? usuario?.terminalId ?? '').trim();
        if (terminalId.isNotEmpty) {
          final dados = await _supabase
              .from('terminais')
              .select('id, nome')
              .eq('id', terminalId)
              .limit(1);
          if (dados.isNotEmpty) {
            terminais = dados.map<Map<String, dynamic>>((t) => {
              'id': t['id'].toString(),
              'nome': t['nome'].toString(),
            }).toList();
          }
        }
        setState(() {
          _terminaisDisponiveis = terminais.isNotEmpty
              ? terminais
              : <Map<String, dynamic>>[{'id': '', 'nome': '<selecione>'}];
        });
        return;
      }

      if (empresaIdEfetivo.isNotEmpty) {
        final relacoes = await _supabase
            .from('relacoes_terminais')
            .select('terminal_id')
            .eq('empresa_id', empresaIdEfetivo);

        final terminaisIds = relacoes
            .map((r) => r['terminal_id']?.toString())
            .where((id) => id != null && id.isNotEmpty)
            .toSet()
            .toList();

        if (terminaisIds.isNotEmpty) {
          final dados = await _supabase
              .from('terminais')
              .select('id, nome')
              .filter('id', 'in', terminaisIds)
              .order('nome');

          terminais = dados.map<Map<String, dynamic>>((t) => {
            'id': t['id'].toString(),
            'nome': t['nome'].toString(),
          }).toList();
        }
      } else {
        final dados = await _supabase
            .from('terminais')
            .select('id, nome')
            .order('nome');

        terminais = dados
            .map<Map<String, dynamic>>((t) => {
              'id': t['id'].toString(),
              'nome': t['nome'].toString(),
            })
            .toList();
      }

      setState(() {
        _terminaisDisponiveis = <Map<String, dynamic>>[
          {'id': '', 'nome': '<selecione>'}
        ];
        _terminaisDisponiveis.addAll(terminais);
      });
    } catch (e) {
      debugPrint('❌ Erro ao carregar terminais: $e');
      setState(() {
        _terminaisDisponiveis = <Map<String, dynamic>>[
          {'id': '', 'nome': '<selecione>'}
        ];
      });
    } finally {
      setState(() => _carregandoTerminais = false);
    }
  }

  Future<void> _carregarEmpresasDisponiveis() async {
    setState(() => _carregandoEmpresas = true);

    try {
      final usuario = UsuarioAtual.instance;
      final nivelUsuario = usuario?.nivel ?? 0;
      
      final temEmpresaFixa = (nivelUsuario == 1 || nivelUsuario == 2 || nivelUsuario == 3) && 
                            usuario?.empresaId?.isNotEmpty == true;

      if (temEmpresaFixa) {
        final empresaId = usuario?.empresaId ?? '';
        
        final dados = await _supabase
            .from('empresas')
            .select('id, nome_dois')
            .eq('id', empresaId)
            .limit(1);

        if (dados.isNotEmpty) {
          final e = dados.first;
          final nome = (e['nome_dois'] ?? '').toString();
          setState(() {
            _empresaSelecionadaId = empresaId;
            _empresaSelecionadaNome = nome;
            _empresasDisponiveis = [{'id': empresaId, 'nome': nome}];
          });
        }
        return;
      }

      List<Map<String, dynamic>> empresas = [];

      if (nivelUsuario == 4) {
        final terminalId = widget.terminalId ?? usuario?.terminalId ?? '';

        if (terminalId.isNotEmpty) {
          final relacoes = await _supabase
              .from('relacoes_terminais')
              .select('empresa_id')
              .eq('terminal_id', terminalId);

          final empresasIds = relacoes
              .map((r) => r['empresa_id']?.toString())
              .where((id) => id != null && id.isNotEmpty)
              .toSet()
              .toList();

          if (empresasIds.isNotEmpty) {
            final dados = await _supabase
                .from('empresas')
                .select('id, nome_dois')
                .filter('id', 'in', empresasIds)
                .order('nome_dois');

            empresas = dados.map<Map<String, dynamic>>((e) => {
              'id': e['id'].toString(),
              'nome': e['nome_dois'].toString(),
            }).toList();
          }
        }
      } else {
        final dados = await _supabase
            .from('empresas')
            .select('id, nome_dois')
            .order('nome_dois');

        empresas = dados
            .map<Map<String, dynamic>>((e) => {
              'id': e['id'].toString(),
              'nome': e['nome_dois'].toString(),
            })
            .toList();
      }

      setState(() {
        _empresasDisponiveis = <Map<String, dynamic>>[
          {'id': '', 'nome': '<selecione>'}
        ];
        _empresasDisponiveis.addAll(empresas);
        
        if (widget.empresaId != null && widget.empresaId!.isNotEmpty) {
          final encontrada = empresas.firstWhere(
            (e) => e['id'] == widget.empresaId,
            orElse: () => <String, dynamic>{},
          );
          if (encontrada.isNotEmpty) {
            _empresaSelecionadaId = encontrada['id'];
            _empresaSelecionadaNome = encontrada['nome'];
          }
        }
      });

    } catch (e) {
      debugPrint('❌ Erro ao carregar empresas: $e');
      setState(() {
        _empresasDisponiveis = <Map<String, dynamic>>[
          {'id': '', 'nome': '<selecione>'}
        ];
        _empresaSelecionadaId = null;
        _empresaSelecionadaNome = null;
      });
    } finally {
      setState(() => _carregandoEmpresas = false);
    }
  }

  Future<void> _selecionarDataInicial(BuildContext context) async {
     final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dataInicial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null && picked != _dataInicial) {
      setState(() {
        _dataInicial = picked;
        if (_dataInicial.isAfter(_dataFinal)) {
          _dataFinal = _dataInicial;
        }
      });
    }
  }

  Future<void> _selecionarDataFinal(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dataFinal,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null && picked != _dataFinal) {
      setState(() {
        _dataFinal = picked;
        if (_dataFinal.isBefore(_dataInicial)) {
          _dataInicial = _dataFinal;
        }
      });
    }
  }

  void _consultar() {
    if (_dataInicial.isAfter(_dataFinal)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A data inicial não pode ser posterior à data final.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_terminalSelecionadoId == null || _terminalSelecionadoId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecione um terminal.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_empresaSelecionadaId == null || _empresaSelecionadaId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecione uma empresa.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    widget.onConsultar(
      terminalId: _terminalSelecionadoId,
      empresaId: _empresaSelecionadaId,
      nomeTerminal: _terminalSelecionadoNome ?? 'Terminal não selecionado',
      empresaNome: _empresaSelecionadaNome,
      dataInicial: _dataInicial,
      dataFinal: _dataFinal,
      tipoRelatorio: _tipoRelatorio,
    );
  }

  void _resetarFiltros() {
    final agora = DateTime.now();
    setState(() {
      _dataInicial = DateTime(agora.year, agora.month, 1);
      _dataFinal = agora;
      _tipoRelatorio = 'sintetico';
    });
  }

  @override
  Widget build(BuildContext context) {
    final usuario = UsuarioAtual.instance;
    final nivelUsuario = usuario?.nivel ?? 0;
    final temEmpresaFixa = (nivelUsuario == 1 || nivelUsuario == 2 || nivelUsuario == 3) && 
                          usuario?.empresaId?.isNotEmpty == true;
    final temTerminalFixo = nivelUsuario == 4;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0D47A1),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Consulta - Controle de Aditivos',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              widget.nomeTerminal,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onVoltar,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _carregando
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D47A1)))
            : _buildConteudo(temEmpresaFixa, temTerminalFixo),
      ),
    );
  }

  Widget _buildConteudo(bool temEmpresaFixa, bool temTerminalFixo) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardFiltros(temEmpresaFixa, temTerminalFixo),
          const SizedBox(height: 20),
          _buildCardResumo(),
          const SizedBox(height: 20),
          _buildBotoes(),
        ],
      ),
    );
  }

  Widget _buildCardFiltros(bool temEmpresaFixa, bool temTerminalFixo) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.filter_alt, color: Color(0xFF0D47A1), size: 18),
              SizedBox(width: 8),
              Text(
                'Filtros de Pesquisa',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0D47A1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildCampoFiltro(
                    label: 'Terminal *',
                    child: _buildDropdownTerminal(temTerminalFixo),
                    width: constraints.maxWidth > 600 ? (constraints.maxWidth - 32) / 3 : constraints.maxWidth,
                  ),
                  _buildCampoFiltro(
                    label: 'Empresa *',
                    child: _buildDropdownEmpresa(temEmpresaFixa),
                    width: constraints.maxWidth > 600 ? (constraints.maxWidth - 32) / 3 : constraints.maxWidth,
                  ),
                  _buildCampoFiltro(
                    label: 'Tipo de relatório',
                    child: _buildDropdownTipoRelatorio(),
                    width: constraints.maxWidth > 600 ? (constraints.maxWidth - 32) / 3 : constraints.maxWidth,
                  ),
                  _buildCampoFiltro(
                    label: 'Data inicial *',
                    child: _buildDataPicker(
                      '${_dataInicial.day.toString().padLeft(2, '0')}/${_dataInicial.month.toString().padLeft(2, '0')}/${_dataInicial.year}',
                      () => _selecionarDataInicial(context),
                    ),
                    width: constraints.maxWidth > 600 ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth,
                  ),
                  _buildCampoFiltro(
                    label: 'Data final *',
                    child: _buildDataPicker(
                      '${_dataFinal.day.toString().padLeft(2, '0')}/${_dataFinal.month.toString().padLeft(2, '0')}/${_dataFinal.year}',
                      () => _selecionarDataFinal(context),
                    ),
                    width: constraints.maxWidth > 600 ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth,
                  ),
                ],
              );
            }
          ),
        ],
      ),
    );
  }

  Widget _buildCampoFiltro({required String label, required Widget child, required double width}) {
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
          child,
        ],
      ),
    );
  }

  Widget _buildDropdownTerminal(bool temTerminalFixo) {
    if (_carregandoTerminais) {
      return const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)));
    }
    return Container(
      decoration: BoxDecoration(
        color: temTerminalFixo ? Colors.grey.shade100 : Colors.white,
        border: Border.all(color: Colors.grey.shade400, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _terminalSelecionadoId,
          isExpanded: true,
          itemHeight: 50,
          onChanged: temTerminalFixo ? null : (String? novoValor) {
            setState(() {
              _terminalSelecionadoId = novoValor;
              final terminal = _terminaisDisponiveis.firstWhere((t) => t['id'] == novoValor, orElse: () => <String, dynamic>{'id': '', 'nome': ''});
              _terminalSelecionadoNome = terminal['nome'];
            });
          },
          items: _terminaisDisponiveis.map<DropdownMenuItem<String>>((terminal) {
            return DropdownMenuItem<String>(
              value: terminal['id'],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(terminal['nome']),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDropdownEmpresa(bool temEmpresaFixa) {
    if (_carregandoEmpresas) {
      return const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)));
    }
    return Container(
      decoration: BoxDecoration(
        color: temEmpresaFixa ? Colors.grey.shade100 : Colors.white,
        border: Border.all(color: Colors.grey.shade400, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _empresaSelecionadaId,
          isExpanded: true,
          itemHeight: 50,
          onChanged: temEmpresaFixa ? null : (String? novoValor) {
            setState(() {
              _empresaSelecionadaId = novoValor;
              final empresa = _empresasDisponiveis.firstWhere((e) => e['id'] == novoValor, orElse: () => <String, dynamic>{'id': '', 'nome': ''});
              _empresaSelecionadaNome = empresa['nome'];
            });
          },
          items: _empresasDisponiveis.map<DropdownMenuItem<String>>((empresa) {
            return DropdownMenuItem<String>(
              value: empresa['id'],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(empresa['nome']),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDropdownTipoRelatorio() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade400, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _tipoRelatorio,
          isExpanded: true,
          itemHeight: 50,
          onChanged: (String? novoValor) => setState(() => _tipoRelatorio = novoValor!),
          items: const [
            DropdownMenuItem(value: 'sintetico', child: Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Sintético'))),
            DropdownMenuItem(value: 'analitico', child: Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Analítico'))),
          ],
        ),
      ),
    );
  }

  Widget _buildDataPicker(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade400, width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13)),
            Icon(Icons.calendar_today, color: Colors.grey.shade600, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildCardResumo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.summarize, color: Color(0xFF0D47A1), size: 18),
              SizedBox(width: 8),
              Text(
                'Resumo dos Filtros',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0D47A1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 24,
            runSpacing: 16,
            children: [
              _buildItemResumo(Icons.store, 'Terminal', _terminalSelecionadoNome ?? 'Não selecionado'),
              _buildItemResumo(Icons.business, 'Empresa', _empresaSelecionadaNome ?? 'Não selecionada'),
              _buildItemResumo(Icons.calendar_today, 'Período', '${_dataInicial.day.toString().padLeft(2, '0')}/${_dataInicial.month.toString().padLeft(2, '0')}/${_dataInicial.year} a ${_dataFinal.day.toString().padLeft(2, '0')}/${_dataFinal.month.toString().padLeft(2, '0')}/${_dataFinal.year}'),
              _buildItemResumo(Icons.assessment, 'Tipo', _tipoRelatorio == 'sintetico' ? 'Sintético' : 'Analítico'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemResumo(IconData icon, String label, String value) {
    return SizedBox(
      width: 200,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotoes() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 140,
          height: 36,
          child: OutlinedButton(
            onPressed: _resetarFiltros,
            style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.refresh, size: 16), SizedBox(width: 6), Text('Redefinir')]),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 140,
          height: 36,
          child: ElevatedButton(
            onPressed: _consultar,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.search, size: 16), SizedBox(width: 6), Text('Consultar')]),
          ),
        ),
      ],
    );
  }
}
