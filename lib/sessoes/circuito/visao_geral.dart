import 'package:flutter/material.dart';

/// Flight-controller-style dashboard for the Circuito session.
/// Shows every vehicle as a tiny chip organised in 4 stage columns.
class VisaoGeralCircuitoPage extends StatefulWidget {
  final VoidCallback onVoltar;

  const VisaoGeralCircuitoPage({super.key, required this.onVoltar});

  @override
  State<VisaoGeralCircuitoPage> createState() => _VisaoGeralCircuitoPageState();
}

class _VisaoGeralCircuitoPageState extends State<VisaoGeralCircuitoPage> {
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
      cor: Color(0xFF00ACC1), // Ciano Escuro / Teal
      corFundo: Color(0xFF002025), // Fundo Ciano muito escuro
    ),
    _Estagio(
      titulo: 'Em Operação',
      cor: Color(0xFF2E7D32),
      corFundo: Color(0xFF001A02),
    ),
    _Estagio(
      titulo: 'Liberados',
      cor: Color(0xFF4A148C),
      corFundo: Color(0xFF0E001A),
    ),
  ];

  // ── Dados fictícios ───────────────────────────────────────────────────────
  late List<_Veiculo> _veiculos;

  @override
  void initState() {
    super.initState();
    _veiculos = _gerarVeiculosFicticios();
  }

  List<_Veiculo> _gerarVeiculosFicticios() {
    const placasProgramados = [
      'ABC-1234', 'XYZ-9010', 'TRK-5444', 'CAM-2788', 'FOG-3911',
      'GTX-7555', 'MNO-4622', 'PQR-8111', 'STU-6333', 'VWX-1999',
      'CML-9077', 'BRS-4888', 'PAR-2300', 'JAP-6222', 'RIO-5144',
    ];
    const placasEmFila = [
      'SFR-3455', 'BHZ-8600', 'MNS-1711', 'TAU-7022', 'FLN-4388',
      'GYN-0199', 'POA-2844', 'MAC-9666', 'CRU-5533', 'NAT-6277',
    ];
    const placasEmOperacao = [
      'VIT-1900', 'MAO-3188', 'LDB-7433', 'FZO-2566', 'AJU-8355',
      'BOA-4722', 'PET-6088', 'SAL-0644', 'MOC-9155', 'ARA-5811',
    ];
    const placasLiberados = [
      'CGB-1500', 'TBA-7266', 'IPT-3977', 'ATI-6311', 'LNS-2744',
      'CXS-8099', 'TFC-4833', 'SBR-0477', 'COD-9622', 'REC-5288',
      'FOR-1155', 'NTL-7399', 'MCA-3677', 'VDE-6422', 'JPE-2888',
    ];

    final veiculos = <_Veiculo>[];

    // Usaremos tempos diferentes para simular a ordem de chegada
    DateTime baseTime = DateTime.now();

    for (int i = 0; i < placasProgramados.length; i++) {
      final p = placasProgramados[i];
      veiculos.add(_Veiculo(
        placa: p,
        estagio: 0,
        produto: _getProdutoFicticio(p),
        empresa: _getEmpresaFicticia(p),
        tipoOp: _getTipoOpFicticio(p),
        entrada: baseTime.add(Duration(minutes: i)),
      ));
    }
    for (int i = 0; i < placasEmFila.length; i++) {
      final p = placasEmFila[i];
      veiculos.add(_Veiculo(
        placa: p,
        estagio: 1,
        produto: _getProdutoFicticio(p),
        empresa: _getEmpresaFicticia(p),
        tipoOp: _getTipoOpFicticio(p),
        entrada: baseTime.add(Duration(minutes: i)),
      ));
    }
    for (int i = 0; i < placasEmOperacao.length; i++) {
      final p = placasEmOperacao[i];
      veiculos.add(_Veiculo(
        placa: p,
        estagio: 2,
        produto: _getProdutoFicticio(p),
        empresa: _getEmpresaFicticia(p),
        tipoOp: _getTipoOpFicticio(p),
        entrada: baseTime.add(Duration(minutes: i)),
      ));
    }
    for (int i = 0; i < placasLiberados.length; i++) {
      final p = placasLiberados[i];
      veiculos.add(_Veiculo(
        placa: p,
        estagio: 3,
        produto: _getProdutoFicticio(p),
        empresa: _getEmpresaFicticia(p),
        tipoOp: _getTipoOpFicticio(p),
        entrada: baseTime.add(Duration(minutes: i)),
      ));
    }

    return veiculos;
  }

  String _getProdutoFicticio(String placa) {
    final rand = placa.hashCode % 4;
    return ['GAS', 'S10', 'S500', 'A.H.'][rand];
  }

  String _getEmpresaFicticia(String placa) {
    final rand = placa.hashCode % 3;
    return ['Larco', 'Zema', 'Ale Comb.'][rand];
  }

  String _getTipoOpFicticio(String placa) {
    final rand = placa.hashCode % 2;
    return ['Carga', 'Descarga'][rand];
  }

  List<_Veiculo> _veiculosPorEstagio(int estagio) {
    final list = _veiculos.where((v) {
      if (v.estagio != estagio) return false;

      // Filtro de Empresa
      if (_empresaSelecionada != 'Todas' && v.empresa != _empresaSelecionada) {
        return false;
      }

      // Filtro de Tipo Op
      if (_tipoOpSelecionada != 'Todos' && v.tipoOp != _tipoOpSelecionada) {
        return false;
      }

      // Filtro de Busca (Placa ou Produto)
      if (_filtroBusca.isEmpty) return true;
      final busca = _filtroBusca.toLowerCase();
      return v.placa.toLowerCase().contains(busca) ||
          v.produto.toLowerCase().contains(busca);
    }).toList();

    // Ordenação por antiguidade (entrada)
    list.sort((a, b) => a.entrada.compareTo(b.entrada));
    return list;
  }

  void _avancarEstagio(_Veiculo v) {
    if (v.estagio >= _estagios.length - 1) return;
    setState(() => v.estagio++);
  }

  void _retrocederEstagio(_Veiculo v) {
    if (v.estagio <= 0) return;
    setState(() => v.estagio--);
  }

  void _mostrarDialogDetalhesVeiculo(BuildContext context, _Veiculo v) {
    final textColor = _isDarkMode ? Colors.white : const Color(0xFF1E293B);
    final subTextColor = _isDarkMode ? Colors.white70 : Colors.black54;
    final bgColor = _isDarkMode ? const Color(0xFF1E293B) : Colors.white;

    // Dados fictícios para o dialog
    const motorista = 'João da Silva';
    const transportadora = 'TransLog Express';
    final produtos = v.tipoOp == 'Carga' ? ['GAS', 'S10', 'S500'] : [v.produto];
    final dataCriacao =
        '${v.entrada.day.toString().padLeft(2, '0')}/${v.entrada.month.toString().padLeft(2, '0')}/${v.entrada.year}';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: bgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'DETALHES DO VEÍCULO',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: subTextColor),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const Divider(),
              _itemDetalhe('Placa', v.placa, textColor, subTextColor),
              _itemDetalhe('Motorista', motorista, textColor, subTextColor),
              _itemDetalhe('Transportadora', transportadora, textColor, subTextColor),
              _itemDetalhe('Empresa', v.empresa, textColor, subTextColor),
              _itemDetalhe('Operação', v.tipoOp, textColor, subTextColor),
              _itemDetalhe('Produto(s)', produtos.join(', '), textColor, subTextColor),
              _itemDetalhe('Data Criação', dataCriacao, textColor, subTextColor),
              const SizedBox(height: 12),
              _buildStatusDocumentos(v),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('FECHAR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusDocumentos(_Veiculo v) {
    // Aumentado para 30% com documentos vencidos (usando mod 10 < 3)
    final int hash = v.placa.hashCode;
    final bool documentoVencido = hash % 10 < 3;

    String mensagem = 'Check-list ok';
    Color cor = Colors.green;
    IconData icone = Icons.check_circle_outline;

    if (documentoVencido) {
      cor = Colors.red;
      icone = Icons.error_outline;
      final pendencias = ['CIV vencido', 'IBAMA Vencido', 'Aferição vencida'];
      mensagem = pendencias[hash % pendencias.length];
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 16, color: cor),
          const SizedBox(width: 8),
          Text(
            mensagem,
            style: TextStyle(
              color: cor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemDetalhe(String label, String valor, Color textColor, Color subTextColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: TextStyle(color: subTextColor, fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarMenuVeiculo(BuildContext context, _Veiculo v, Offset posicao) {
    final podeAvancar = v.estagio < _estagios.length - 1;
    final podeRetroceder = v.estagio > 0;

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
            v.placa,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const PopupMenuDivider(),
        if (podeAvancar)
          PopupMenuItem<String>(
            value: 'avancar',
            child: Row(
              children: [
                Icon(Icons.arrow_forward, size: 14, color: _estagios[v.estagio + 1].cor),
                const SizedBox(width: 8),
                Text(
                  'Mover para ${_estagios[v.estagio + 1].titulo}',
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
                Icon(Icons.arrow_back, size: 14, color: _estagios[v.estagio - 1].cor),
                const SizedBox(width: 8),
                Text(
                  'Voltar para ${_estagios[v.estagio - 1].titulo}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
      ],
    ).then((value) {
      if (value == 'avancar') _avancarEstagio(v);
      if (value == 'retroceder') _retrocederEstagio(v);
    });
  }

  @override
  Widget build(BuildContext context) {
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
            'Por produto',
            style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w500),
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
          // Seletor de Tema
          Row(
            children: [
              Icon(
                _isDarkMode ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                size: 18,
                color: textColor.withValues(alpha: 0.5),
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
    final borderColor = _isDarkMode ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(
        _estagios.length,
        (i) => Expanded(child: _buildColuna(i, borderColor)),
      ),
    );
  }

  Widget _buildColuna(int estagioIndex, Color borderColor) {
    final estagio = _estagios[estagioIndex];
    final veiculos = _veiculosPorEstagio(estagioIndex);
    final colColor = _isDarkMode ? estagio.corFundo : Colors.white;

    // Configuração específica para estágio "Em Fila" (Index 1)
    final isFila = estagioIndex == 1;

    return Container(
      decoration: BoxDecoration(
        color: colColor,
        border: Border(
          right: BorderSide(
            color: borderColor,
            width: estagioIndex < _estagios.length - 1 ? 1 : 0,
          ),
        ),
      ),
      child: Column(
        children: [
          _buildCabecalhoColunaWidget(estagio, veiculos.length),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isFila ? 1 : 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: isFila ? 8.0 : 2.2,
              ),
              itemCount: veiculos.length,
              itemBuilder: (context, index) {
                return _buildChip(
                  veiculos[index],
                  estagio,
                  borderColor,
                  posicao: isFila ? index + 1 : null,
                );
              },
            ),
          ),
        ],
      ),
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

  Widget _buildChip(_Veiculo v, _Estagio estagio, Color borderColor, {int? posicao}) {
    final textColor = _isDarkMode ? Colors.white : const Color(0xFF1E293B);
    var cardColor = _isDarkMode ? const Color(0xFF1E293B) : Colors.white;

    final isProgramado = v.estagio == 0;
    // Aumentado para 30% com documentos vencidos (usando mod 10 < 3)
    final bool documentoVencido = isProgramado && (v.placa.hashCode % 10 < 3);

    if (documentoVencido) {
      cardColor = _isDarkMode ? Colors.red.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.1);
      borderColor = Colors.red.withValues(alpha: 0.5);
    }

    return GestureDetector(
      onSecondaryTapDown: (details) => isProgramado
          ? _mostrarDialogDetalhesVeiculo(context, v)
          : _mostrarMenuVeiculo(context, v, details.globalPosition),
      onLongPressStart: (details) => isProgramado
          ? _mostrarDialogDetalhesVeiculo(context, v)
          : _mostrarMenuVeiculo(context, v, details.globalPosition),
      onTapDown: (details) => isProgramado
          ? _mostrarDialogDetalhesVeiculo(context, v)
          : _mostrarMenuVeiculo(context, v, details.globalPosition),
      child: _ChipHover(
        cor: estagio.cor,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: documentoVencido ? cardColor : (_isDarkMode ? cardColor : estagio.cor.withValues(alpha: 0.08)),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: documentoVencido ? borderColor : (_isDarkMode ? borderColor : estagio.cor.withValues(alpha: 0.3)),
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (posicao != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: estagio.cor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$posicaoº',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: posicao != null ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                  children: [
                    Text(
                      v.placa,
                      style: TextStyle(
                        color: _isDarkMode ? textColor : estagio.cor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _mostrarPorProduto ? v.produto : v.empresa,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _isDarkMode ? textColor.withValues(alpha: 0.9) : Colors.black54,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
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
  final String placa;
  final String produto;
  final String empresa;
  final String tipoOp;
  final DateTime entrada;
  int estagio;

  _Veiculo({
    required this.placa,
    required this.produto,
    required this.empresa,
    required this.tipoOp,
    required this.entrada,
    required this.estagio,
  });
}
