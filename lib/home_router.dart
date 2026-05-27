import 'package:flutter/material.dart';
import 'home1.dart';
import 'home2.dart';
import 'login_page.dart';

/// Roteador de home: escolhe o layout com base no campo `layout` do usuário.
/// - layout == 1 (padrão): [HomePage] (menu lateral retrátil com submenus)
/// - layout == 2: [HomePageLayout1] (layout de cards originais)
class HomeRouter extends StatelessWidget {
  const HomeRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final layout = UsuarioAtual.instance?.layout ?? UsuarioAtual.pendingLayout;
    if (layout == 2) {
      return const HomePageLayout1();
    }
    return const HomePage();
  }
}
