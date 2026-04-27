// Smoke-Test ohne Firebase/MyApp – verhindert kaputte package:-Imports (vormals dj_og_app_temp).
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Projekt-Basis: Tests laufen', () {
    expect(2 + 2, 4);
  });
}
