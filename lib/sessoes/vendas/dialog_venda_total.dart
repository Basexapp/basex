import 'package:flutter/material.dart';

class DialogVendaTotal extends StatelessWidget {
  final List<Map<String, dynamic>> movimentacoes;
  final Map<String, Map<String, dynamic>> mapaProdutosColuna;

  const DialogVendaTotal({
    super.key,
    required this.movimentacoes,
    required this.mapaProdutosColuna,
  });

  @override
  Widget build(BuildContext context) {
    // Totais por coluna (índice 0 a 9)
    final totais = List.filled(10, 0.0);
    
    for (final t in movimentacoes) {
      if (t['isSpacer'] == true) continue;
      final produtoId = t['produto_id']?.toString();
      if (produtoId == null) continue;
      final info = mapaProdutosColuna[produtoId];
      if (info == null) continue;
      final col = info['coluna'] as int;
      if (col < 0 || col >= 10) continue;
      totais[col] += double.tryParse(t['saida_amb']?.toString() ?? '0') ?? 0;
    }

    // Configuração dos produtos baseada no mapa da tabela
    final produtos = [
      {'nome': 'G. COM.', 'cor': Colors.orange.shade400, 'index': 0},
      {'nome': 'G. ADITIV.', 'cor': Colors.orange.shade700, 'index': 1},
      {'nome': 'D. S10', 'cor': Colors.blueGrey.shade400, 'index': 2},
      {'nome': 'D. S500', 'cor': Colors.blueGrey.shade700, 'index': 3},
      {'nome': 'ETANOL', 'cor': Colors.green.shade600, 'index': 4},
      {'nome': 'G. A', 'cor': Colors.amber.shade600, 'index': 5},
      {'nome': 'S500 A', 'cor': Colors.brown.shade400, 'index': 6},
      {'nome': 'S10 A', 'cor': Colors.purple.shade400, 'index': 7},
      {'nome': 'ANIDRO', 'cor': Colors.teal.shade600, 'index': 8},
      {'nome': 'B100', 'cor': Colors.cyan.shade700, 'index': 9},
    ];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
      child: Container(
        width: 300,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF0D47A1), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF0D47A1),
                borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.summarize, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Totais do Dia',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  _buildSecao('PRODUTOS TERMINAL', produtos.sublist(0, 5), totais),
                  const Divider(height: 16, thickness: 1, indent: 16, endIndent: 16),
                  _buildSecao('MATÉRIAS PRIMAS', produtos.sublist(5, 10), totais),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('FECHAR', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecao(String titulo, List<Map<String, dynamic>> listaProdutos, List<double> totais) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            titulo,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ...listaProdutos.map((p) => _buildLinhaProduto(p['nome'], totais[p['index']], p['cor'])),
      ],
    );
  }

  Widget _buildLinhaProduto(String nome, double total, Color cor) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 12,
                decoration: BoxDecoration(
                  color: cor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                nome,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          Text(
            total > 0 ? _formatarQuantidade(total.toStringAsFixed(0)) : '0',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
          ),
        ],
      ),
    );
  }

  String _formatarQuantidade(String quantidade) {
    try {
      final apenasNumeros = quantidade.replaceAll(RegExp(r'[^\d]'), '');
      if (apenasNumeros.isEmpty || apenasNumeros == '0') return '0';
      
      final valor = int.parse(apenasNumeros);
      if (valor == 0) return '0';
      
      if (valor > 999) {
        final parteMilhar = (valor ~/ 1000).toString();
        final parteCentena = (valor % 1000).toString().padLeft(3, '0');
        return '$parteMilhar.$parteCentena';
      }
      
      return valor.toString();
    } catch (e) {
      return quantidade;
    }
  }
}
