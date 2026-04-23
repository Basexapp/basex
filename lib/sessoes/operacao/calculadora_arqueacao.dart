import 'package:flutter/material.dart';

class CalculadoraArqueacaoPage extends StatefulWidget {
  final VoidCallback? onVoltar;

  const CalculadoraArqueacaoPage({super.key, this.onVoltar});

  @override
  State<CalculadoraArqueacaoPage> createState() =>
      _CalculadoraArqueacaoPageState();
}

class _CalculadoraArqueacaoPageState extends State<CalculadoraArqueacaoPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (widget.onVoltar != null) {
              widget.onVoltar!();
            } else {
              Navigator.of(context).maybePop();
            }
          },
        ),
        title: const Text(
          'Calculadora de Arqueação',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calculate_outlined,
              size: 64,
              color: Color(0xFF2196F3),
            ),
            SizedBox(height: 16),
            Text(
              'Calculadora de Arqueação',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1565C0),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Em desenvolvimento',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
