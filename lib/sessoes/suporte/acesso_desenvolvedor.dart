import 'package:flutter/material.dart';

class AcessoDesenvolvedorPage extends StatefulWidget {
  final VoidCallback onVoltar;

  const AcessoDesenvolvedorPage({super.key, required this.onVoltar});

  @override
  State<AcessoDesenvolvedorPage> createState() =>
      _AcessoDesenvolvedorPageState();
}

class _AcessoDesenvolvedorPageState extends State<AcessoDesenvolvedorPage> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onVoltar,
                tooltip: 'Voltar',
              ),
              const SizedBox(width: 8),
              const Text(
                'Acesso Desenvolvedor',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1),
        const Expanded(child: SizedBox.shrink()),
      ],
    );
  }
}
