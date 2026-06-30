import 'package:basex/sessoes/operacao/rateio_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buildRateioMovimentacaoRow includes bombeio_id in payload', () {
    final row = buildRateioMovimentacaoRow(
      tanqueId: 'tanque-1',
      produtoId: 'produto-1',
      bombeioId: 'bombeio-123',
      dataMov: '2026-06-30T10:00:00.000',
      entradaAmb: 15,
      entradaVinte: 30,
      empresaId: 'empresa-1',
      terminalId: 'terminal-1',
    );

    expect(row['bombeio_id'], 'bombeio-123');
    expect(row['tipo_mov'], 'bombeio');
    expect(row['entrada_amb'], 15);
    expect(row['entrada_vinte'], 30);
  });
}
