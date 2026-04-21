import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

/// Dialog untuk meminta izin notifikasi saat pertama kali aplikasi dibuka
/// Khusus untuk Android 13+ yang memerlukan izin POST_NOTIFICATIONS
class DialogIzinNotifikasi extends StatelessWidget {
  const DialogIzinNotifikasi({super.key});

  /// Tampilkan dialog dan minta izin notifikasi
  static Future<void> tampilkan(BuildContext context) async {
    // Cek apakah perlu minta izin (hanya Android)
    if (!Platform.isAndroid) return;

    // Cek status izin saat ini
    final status = await Permission.notification.status;

    // Jika sudah diberikan atau sudah pernah ditolak permanen, jangan tampilkan dialog
    if (status.isGranted || status.isPermanentlyDenied) {
      return;
    }

    // Tampilkan dialog
    if (context.mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const DialogIzinNotifikasi(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.notifications_active_rounded,
              color: Colors.orange.shade700,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Aktifkan Notifikasi',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Aktifkan notifikasi untuk mendapatkan update terbaru:',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 12),
          _PermissionItem(
            icon: Icons.description_rounded,
            title: 'Status Pengajuan',
            color: Colors.blue,
          ),
          _PermissionItem(
            icon: Icons.check_circle_rounded,
            title: 'Persetujuan APD',
            color: Colors.green,
          ),
          _PermissionItem(
            icon: Icons.announcement_rounded,
            title: 'Pengumuman Penting',
            color: Colors.orange,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => _tolak(context),
          child: const Text(
            'Nanti Saja',
            style: TextStyle(color: Colors.grey),
          ),
        ),
        ElevatedButton(
          onPressed: () => _izinkan(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Aktifkan',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  void _izinkan(BuildContext context) async {
    Navigator.of(context).pop();

    // Request izin notifikasi
    final status = await Permission.notification.request();

    // Jika izin diberikan, tampilkan snackbar
    if (status.isGranted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Notifikasi berhasil diaktifkan'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    // Jika ditolak permanen, arahkan ke settings
    else if (status.isPermanentlyDenied) {
      if (context.mounted) {
        _tampilkanDialogSettings(context);
      }
    }
  }

  void _tolak(BuildContext context) {
    Navigator.of(context).pop();
  }

  void _tampilkanDialogSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.settings_rounded, color: Colors.orange),
            SizedBox(width: 12),
            Text('Buka Pengaturan'),
          ],
        ),
        content: const Text(
          'Izin notifikasi diperlukan untuk mendapatkan update status pengajuan dan pengumuman penting. Buka pengaturan aplikasi untuk mengaktifkannya.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // Buka settings aplikasi
              await openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Buka Pengaturan'),
          ),
        ],
      ),
    );
  }
}

class _PermissionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _PermissionItem({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}
