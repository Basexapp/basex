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
  bool _isDarkMode = true;
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
      'ABC1D23', 'XYZ9A10', 'TRK5B44', 'CAM2E78', 'FOG3C91',
      'GTX7A55', 'MNO4F62', 'PQR8G11', 'STU6H33', 'VWX1I99',
      'CML9J07', 'BRS4K88', 'PAR2L30', 'JAP6M22', 'RIO5N14',
    ];
    const placasEmFila = [
      'SFR3O45', 'BHZ8P60', 'MNS1Q71', 'TAU7R02', 'FLN4S38',
      'GYN0T19', 'POA2U84', 'MAC9V66', 'CRU5W53', 'NAT6X27',
    ];
    const placasEmOperacao = [
      'VIT1Y90', 'MAO3Z18', 'LDB7A43', 'FZO2B56', 'AJU8C35',
      'BOA4D72', 'PET6E08', 'SAL0F64', 'MOC9G15', 'ARA5H81',
    ];
    const placasLiberados = [
      'CGB1I50', 'TBA7J26', 'IPT3K97', 'ATI6L31', 'LNS2M74',
      'CXS8N09', 'TFC4O83', 'SBR0P47', 'COD9Q62', 'REC5R28',
      'FOR1S15', 'NTL7T39', 'MCA3U67', 'VDE6V42', 'JPE2W88',
    ];

    final veiculos = <_Veiculo>[];

    for (final p in placasProgramados) {
      veiculos.add(_Veiculo(
        placa: p,
        estagio: 0,
        produto: _getProdutoFicticio(p),
        empresa: _getEmpresaFicticia(p),
        tipoOp: _getTipoOpFicticio(p),
      ));
    }
    for (final p in placasEmFila) {
      veiculos.add(_Veiculo(
        placa: p,
        estagio: 1,
        produto: _getProdutoFicticio(p),
        empresa: _getEmpresaFicticia(p),
        tipoOp: _getTipoOpFicticio(p),
      ));
    }
    for (final p in placasEmOperacao) {
      veiculos.add(_Veiculo(
        placa: p,
        estagio: 2,
        produto: _getProdutoFicticio(p),
        empresa: _getEmpresaFicticia(p),
        tipoOp: _getTipoOpFicticio(p),
      ));
    }
    for (final p in placasLiberados) {
      veiculos.add(_Veiculo(
        placa: p,
        estagio: 3,
        produto: _getProdutoFicticio(p),
        empresa: _getEmpresaFicticia(p),
        tipoOp: _getTipoOpFicticio(p),
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
    return _veiculos.where((v) {
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
  }

  void _avancarEstagio(_Veiculo v) {
    if (v.estagio >= _estagios.length - 1) return;
    setState(() => v.estagio++);
  }

  void _retrocederEstagio(_Veiculo v) {
    if (v.estagio <= 0) return;
    setState(() => v.estagio--);
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
            '"Por produto"',
            style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 13, fontWeight: FontWeight.w500),
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
                  color: _isDarkMode ? Colors.black38 : subTextColor.withOpacity(0.5),
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
            icon: Icon(Icons.arrow_back, color: textColor.withOpacity(0.7), size: 20),
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
        style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 11),
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
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 2.2,
              ),
              itemCount: veiculos.length,
              itemBuilder: (context, index) {
                return _buildChip(veiculos[index], estagio, borderColor);
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
        color: _isDarkMode ? Colors.transparent : estagio.cor.withOpacity(0.05),
        border: Border(
          bottom: BorderSide(color: estagio.cor.withOpacity(0.4), width: 1),
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
              color: estagio.cor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: estagio.cor.withOpacity(0.3)),
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
    final textColor = _isDarkMode ? Colors.white : const Color(0xFF1E293B);
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _isDarkMode ? cardColor : estagio.cor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _isDarkMode ? borderColor : estagio.cor.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              if (!_isDarkMode)
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                v.placa,
                style: TextStyle(
                  color: _isDarkMode ? textColor : estagio.cor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _mostrarPorProduto ? v.produto : v.empresa,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor.withOpacity(0.5),
                  fontSize: 9,
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
              ? [BoxShadow(color: widget.cor.withOpacity(0.5), blurRadius: 6)]
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
  int estagio;

  _Veiculo({
    required this.placa,
    required this.produto,
    required this.empresa,
    required this.tipoOp,
    required this.estagio,
  });
}
