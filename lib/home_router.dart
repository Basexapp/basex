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
    // Se não houver usuário logado (ex: após um refresh de página), volta para o login
    if (UsuarioAtual.instance == null) {
      return const LoginPage();
    }
    
    final layout = UsuarioAtual.instance!.layout;
    if (layout == 2) {
      return const HomePageCards();
    }
    return const HomePage();
  }
}
