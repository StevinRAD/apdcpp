import 'package:flutter/material.dart';

import 'package:apdcpp/tema_aplikasi.dart';

String _statusAturan(Map<String, dynamic> aturan) =>
    (aturan['status']?.toString() ?? '').trim().toLowerCase();

int _toInt(dynamic value, {int fallback = 0}) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString().trim()) ?? fallback;
}

bool bisaAjukanSekarang(Map<String, dynamic> aturan) {
  final raw = aturan['bisa_ajukan'];
  if (raw is bool) return raw;
  final normalized = (raw?.toString() ?? '').trim().toLowerCase();
  return normalized == 'true' || normalized == '1' || normalized == 'yes';
}

Color warnaAturanPengajuan(Map<String, dynamic> aturan) {
  final status = _statusAturan(aturan);
  if (status == 'menunggu_proses') return Colors.blue;
  if (status == 'cooldown') return TemaAplikasi.emasTua;
  if (status == 'akun_nonaktif' || status == 'ban_sementara') {
    return TemaAplikasi.bahaya;
  }
  return TemaAplikasi.sukses;
}

int cooldownHariAkun(Map<String, dynamic> aturan) {
  return _toInt(aturan['cooldown_pengajuan_hari'], fallback: 30);
}

int sisaHariCooldown(Map<String, dynamic> aturan) {
  return _toInt(aturan['sisa_hari_cooldown']);
}

String labelAturanPengajuan(Map<String, dynamic> aturan) {
  final status = _statusAturan(aturan);
  if (status == 'menunggu_proses') return 'Masih menunggu proses admin';
  if (status == 'cooldown') {
    final sisaHari = sisaHariCooldown(aturan);
    if (sisaHari > 0) return 'Pending $sisaHari hari lagi';
    return 'Sedang pending pengajuan';
  }
  if (status == 'akun_nonaktif') return 'Akun sedang nonaktif';
  if (status == 'ban_sementara') return 'Akun dibatasi sementara';
  return 'Boleh ajukan sekarang';
}
