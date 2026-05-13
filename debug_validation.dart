
import 'package:flutter/material.dart';

void main() {
  // Simulação dos dados que o usuário descreveu
  final medicoes = {
    'cmFinal': '100',
    'mmFinal': '0',
    'alturaAguaFinal': '0,0 cm', // Valor comum quando é zero
    'tempTanqueFinal': '25,5',
    'densidadeFinal': '0,845',
    'tempAmostraFinal': '25,0',
    'horarioFinal': '10:30',
    'volume20Final': '5000'
  };

  print('--- Teste de Validação ---');
  bool resultado = _dadosFinaisEstaoCompletos(medicoes);
  print('Resultado Final: $resultado');
}

bool _dadosFinaisEstaoCompletos(Map<String, dynamic> medicoes) {
  final camposObrigatorios = [
    'cmFinal',
    'mmFinal',
    'alturaAguaFinal',
    'tempTanqueFinal',
    'densidadeFinal',
    'tempAmostraFinal',
    'horarioFinal',
  ];

  for (var campo in camposObrigatorios) {
    final valor = medicoes[campo]?.toString().trim() ?? '';
    print('Validando $campo: "$valor"');

    final bool zeroEhValido = campo == 'mmFinal' && (valor == '0' || valor == '00');
    
    bool isAguaVazia = false;
    if (campo == 'alturaAguaFinal') {
      final limpo = valor.replaceAll('cm', '').trim();
      print('  -> limpo agua: "$limpo"');
      final partes = limpo.split(',');
      if (partes.length == 2) {
        final p1 = partes[0].trim();
        final p2 = partes[1].trim();
        if (p1.isEmpty && p2.isEmpty) isAguaVazia = true;
      } else if (limpo.isEmpty) {
        isAguaVazia = true;
      }
    }

    // O PROBLEMA PODE ESTAR AQUI: Se valor for "0", e não for mmFinal, retorna false.
    // Mas temperatura ou densidade não podem ser 0? Água pode ser 0?
    if (valor.isEmpty || valor == '-' || isAguaVazia || (!zeroEhValido && (valor == '0' || valor == '00'))) {
      print('  -> FALHA no campo $campo');
      return false; 
    }
  }

  final volume20Final = _extrairNumero(medicoes['volume20Final']?.toString());
  print('Volume 20 Final extraído: $volume20Final');
  if (volume20Final <= 0) {
    print('  -> FALHA no volume20Final');
    return false;
  }

  return true;
}

double _extrairNumero(String? valor) {
  if (valor == null) return 0;
  final somenteNumeros = valor.replaceAll(RegExp(r'[^0-9]'), '');
  if (somenteNumeros.isEmpty) return 0;
  return double.tryParse(somenteNumeros) ?? 0;
}
