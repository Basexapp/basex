import "package:flutter/material.dart";
import "dart:math" as math;

class RadarPage extends StatefulWidget {
  final VoidCallback onVoltar;

  const RadarPage({super.key, required this.onVoltar});

  @override
  State<RadarPage> createState() => _RadarPageState();
}

class _RadarPageState extends State<RadarPage> {
  final PageController _pageController = PageController();
  double _currentPage = 0.0;

  final List<Map<String, dynamic>> _estagios = [
    {
      "titulo": "Programado",
      "cor": const Color(0xFF2196F3),
      "icone": Icons.calendar_today,
      "descricao": "Veículos agendados para chegada.",
      "qtd": 12,
    },
    {
      "titulo": "Em fila",
      "cor": const Color(0xFFFF9800),
      "icone": Icons.hourglass_empty,
      "descricao": "Veículos aguardando entrada no terminal.",
      "qtd": 5,
    },
    {
      "titulo": "Em operação",
      "cor": const Color(0xFF4CAF50),
      "icone": Icons.local_shipping,
      "descricao": "Veículos em processo de carga/descarga.",
      "qtd": 8,
    },
    {
      "titulo": "Liberados",
      "cor": const Color(0xFF9E9E9E),
      "icone": Icons.check_circle_outline,
      "descricao": "Veículos que já concluíram a operação.",
      "qtd": 24,
    },
  ];

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page ?? 0.0;
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0D47A1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onVoltar,
        ),
        title: const Text(
          "Radar de Operações",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          widget.onVoltar();
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            // PageView transparente para capturar gestos
            PageView.builder(
              controller: _pageController,
              itemCount: _estagios.length,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) => const SizedBox.expand(),
            ),
            // Conteúdo Visual Centralizado
            IgnorePointer(
              ignoring: true,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Área do Carrossel Ampliada e SUPER AMPLA
                  SizedBox(
                    height: 350,
                    width: double.infinity, // Garante que use a largura total
                    child: Stack(
                      alignment: Alignment.center,
                      children: List.generate(_estagios.length, (index) {
                        double relativePosition = index - _currentPage;
                        
                        // Arco muito mais aberto (ângulo reduzido para espalhar horizontalmente)
                        double angle = relativePosition * (math.pi / 2.2); 
                        
                        // Raio horizontal (dx) bem maior que o vertical (dy) para achatar o arco
                        double radiusX = 300.0; // Largura extrema
                        double radiusY = 50.0;  // Altura controlada (para não subir muito)
                        
                        double dx = math.sin(angle) * radiusX;
                        // dy calculado para manter uma curva suave mas plana
                        double dy = (1 - math.cos(angle)) * radiusY;

                        double distance = relativePosition.abs();
                        // Escala e opacidade
                        double scale = math.max(0.4, 1.8 - (distance * 0.7));
                        double opacity = math.max(0.1, 1.0 - (distance * 0.7));

                        return Transform.translate(
                          offset: Offset(dx, dy),
                          child: Transform.scale(
                            scale: scale,
                            child: Opacity(
                              opacity: opacity.clamp(0.0, 1.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: index == _currentPage.round()
                                          ? _estagios[index]["cor"]
                                          : Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.15),
                                          blurRadius: 15,
                                          offset: const Offset(0, 8),
                                        )
                                      ],
                                    ),
                                    child: Icon(
                                      _estagios[index]["icone"],
                                      color: index == _currentPage.round()
                                          ? Colors.white
                                          : _estagios[index]["cor"],
                                      size: 50,
                                    ),
                                  ),
                                  if (index == _currentPage.round()) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      "${_estagios[index]["qtd"]}",
                                      style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w900,
                                        color: _estagios[index]["cor"],
                                      ),
                                    ),
                                  ]
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 60),
                  // Informação do Estágio
                  Text(
                    _estagios[_currentPage.round()]["titulo"].toUpperCase(),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                      color: Colors.grey[850],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "VEÍCULOS NESTE ESTÁGIO",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

