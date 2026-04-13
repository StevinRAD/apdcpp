import 'package:apdcpp/awal/layar_login_admin.dart';
import 'package:apdcpp/awal/layar_login_karyawan.dart';
import 'package:apdcpp/awal/layar_pilih_peran.dart';
import 'package:apdcpp/tema_aplikasi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpLayarPilihPeran(
  WidgetTester tester, {
  required Future<bool> koneksiAwalFuture,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: TemaAplikasi.tema,
      home: LayarPilihPeran(koneksiAwalFuture: koneksiAwalFuture),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Smoke test UI awal', () {
    testWidgets('menampilkan layar pilih peran', (tester) async {
      await _pumpLayarPilihPeran(tester, koneksiAwalFuture: Future.value(true));

      expect(find.text('Prima Safety Care'), findsOneWidget);
      expect(find.text('Masuk Sebagai'), findsOneWidget);
      expect(find.text('Karyawan'), findsOneWidget);
      expect(find.text('Admin'), findsOneWidget);
      expect(find.text('Server Online'), findsOneWidget);
    });

    testWidgets('navigasi ke login karyawan', (tester) async {
      await _pumpLayarPilihPeran(tester, koneksiAwalFuture: Future.value(true));

      await tester.tap(find.text('Karyawan'));
      await tester.pumpAndSettle();

      expect(find.byType(LayarLoginKaryawan), findsOneWidget);
      expect(find.text('Login Karyawan'), findsOneWidget);
    });

    testWidgets('navigasi ke login admin', (tester) async {
      await _pumpLayarPilihPeran(tester, koneksiAwalFuture: Future.value(true));

      await tester.tap(find.text('Admin'));
      await tester.pumpAndSettle();

      expect(find.byType(LayarLoginAdmin), findsOneWidget);
      expect(find.text('Login Admin'), findsOneWidget);
    });
  });
}
