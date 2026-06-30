Map<String, dynamic> buildRateioMovimentacaoRow({
  required String? tanqueId,
  required String? produtoId,
  required String? bombeioId,
  required String? dataMov,
  required int entradaAmb,
  required int entradaVinte,
  required String? empresaId,
  required String? terminalId,
}) {
  final row = <String, dynamic>{
    'tanque_id': tanqueId,
    if (produtoId != null && produtoId.isNotEmpty) 'produto_id': produtoId,
    'data_mov': dataMov,
    'entrada_amb': entradaAmb,
    'entrada_vinte': entradaVinte,
    'descricao': 'Cota Bombeio',
    'empresa_id': empresaId,
    'tipo_mov': 'bombeio',
    'terminal_id': terminalId,
  };

  if (bombeioId != null && bombeioId.isNotEmpty) {
    row['bombeio_id'] = bombeioId;
  }

  return row;
}
