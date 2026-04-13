import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

enum TutorialBentukSorotan { roundedRect, oval }

class TutorialLangkahAplikasi {
  final IconData icon;
  final String judul;
  final String deskripsi;
  final Color warna;
  final GlobalKey? targetKey;
  final EdgeInsets sorotanPadding;
  final double radiusSorotan;
  final TutorialBentukSorotan bentukSorotan;
  final FutureOr<void> Function()? onSebelumTampil;

  const TutorialLangkahAplikasi({
    required this.icon,
    required this.judul,
    required this.deskripsi,
    required this.warna,
    this.targetKey,
    this.sorotanPadding = const EdgeInsets.all(12),
    this.radiusSorotan = 22,
    this.bentukSorotan = TutorialBentukSorotan.roundedRect,
    this.onSebelumTampil,
  });
}

Future<void> tampilkanDialogTutorialAplikasi({
  required BuildContext context,
  required String judul,
  required List<TutorialLangkahAplikasi> langkah,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Tutorial',
    barrierColor: Colors.transparent,
    pageBuilder: (dialogContext, animation, secondaryAnimation) =>
        _DialogTutorialAplikasi(judul: judul, langkah: langkah),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

class _DialogTutorialAplikasi extends StatefulWidget {
  final String judul;
  final List<TutorialLangkahAplikasi> langkah;

  const _DialogTutorialAplikasi({required this.judul, required this.langkah});

  @override
  State<_DialogTutorialAplikasi> createState() =>
      _DialogTutorialAplikasiState();
}

class _DialogTutorialAplikasiState extends State<_DialogTutorialAplikasi> {
  int _indexAktif = 0;
  Rect? _targetRect;
  bool _memuatSorotan = true;
  bool _sedangPindahLangkah = false;

  TutorialLangkahAplikasi get _langkahAktif => widget.langkah[_indexAktif];

  @override
  void initState() {
    super.initState();
    _siapkanLangkah(indexBaru: 0);
  }

  Future<void> _siapkanLangkah({required int indexBaru}) async {
    if (_sedangPindahLangkah ||
        indexBaru < 0 ||
        indexBaru >= widget.langkah.length) {
      return;
    }

    _sedangPindahLangkah = true;
    setState(() {
      _indexAktif = indexBaru;
      _memuatSorotan = true;
    });

    final langkah = widget.langkah[indexBaru];
    try {
      await langkah.onSebelumTampil?.call();
      final targetRect = await _tungguSorotanSiap(langkah);
      if (!mounted) return;

      setState(() {
        _targetRect = targetRect;
        _memuatSorotan = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Gagal menyiapkan sorotan tutorial: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;

      setState(() {
        _targetRect = null;
        _memuatSorotan = false;
      });
    } finally {
      _sedangPindahLangkah = false;
    }
  }

  Future<Rect?> _tungguSorotanSiap(TutorialLangkahAplikasi langkah) async {
    // Tunggu hingga context muncul di tree (terutama untuk tab awal/baru)
    // dan gulir (scroll) ke elemen tersebut agar terlihat di layar.
    for (var percobaan = 0; percobaan < 15; percobaan++) {
      final targetContext = langkah.targetKey?.currentContext;
      if (targetContext != null) {
        if (!targetContext.mounted) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          continue;
        }
        try {
          Scrollable.ensureVisible(
            targetContext,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            alignment: 0.2, // Posisikan agak ke tengah-atas layar
          );
          // Tunggu animasi gulir selesai
          await Future<void>.delayed(const Duration(milliseconds: 350));
        } catch (_) {}
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    final targetRectLangsung = _ukurTargetRect(langkah);
    if (targetRectLangsung != null) {
      return targetRectLangsung;
    }

    for (var percobaan = 0; percobaan < 12; percobaan++) {
      await _tungguFrameBerikutnya();
      if (!mounted) {
        return null;
      }

      final targetRect = _ukurTargetRect(langkah);
      if (targetRect != null) {
        return targetRect;
      }

      await Future<void>.delayed(const Duration(milliseconds: 60));
    }

    return _ukurTargetRect(langkah);
  }

  Future<void> _tungguFrameBerikutnya() {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    WidgetsBinding.instance.scheduleFrame();

    return completer.future.timeout(
      const Duration(milliseconds: 250),
      onTimeout: () {},
    );
  }

  Rect? _ukurTargetRect(TutorialLangkahAplikasi langkah) {
    final targetContext = langkah.targetKey?.currentContext;
    if (targetContext == null) {
      return null;
    }

    final renderObject = targetContext.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }

    final screenSize = MediaQuery.sizeOf(context);
    final offset = renderObject.localToGlobal(Offset.zero);
    final rawRect = Rect.fromLTWH(
      offset.dx,
      offset.dy,
      renderObject.size.width,
      renderObject.size.height,
    );
    final padding = langkah.sorotanPadding;

    return Rect.fromLTRB(
      math.max(8, rawRect.left - padding.left),
      math.max(8, rawRect.top - padding.top),
      math.min(screenSize.width - 8, rawRect.right + padding.right),
      math.min(screenSize.height - 8, rawRect.bottom + padding.bottom),
    );
  }

  Future<void> _langkahBerikutnya() async {
    final indexTerakhir = widget.langkah.length - 1;
    if (_indexAktif >= indexTerakhir) {
      Navigator.of(context).pop();
      return;
    }

    await _siapkanLangkah(indexBaru: _indexAktif + 1);
  }

  Future<void> _langkahSebelumnya() async {
    if (_indexAktif <= 0) {
      return;
    }
    await _siapkanLangkah(indexBaru: _indexAktif - 1);
  }

  @override
  Widget build(BuildContext context) {
    final langkahAktif = _langkahAktif;
    final langkahTerakhir = _indexAktif == widget.langkah.length - 1;
    final mediaQuery = MediaQuery.of(context);

    return PopScope(
      canPop: false,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _TutorialOverlayPainter(
                  targetRect: _targetRect,
                  radiusSorotan: langkahAktif.radiusSorotan,
                  bentukSorotan: langkahAktif.bentukSorotan,
                ),
              ),
            ),
            if (_targetRect != null)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: _targetRect!.left,
                top: _targetRect!.top,
                width: _targetRect!.width,
                height: _targetRect!.height,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius:
                          langkahAktif.bentukSorotan ==
                              TutorialBentukSorotan.roundedRect
                          ? BorderRadius.circular(langkahAktif.radiusSorotan)
                          : null,
                      shape:
                          langkahAktif.bentukSorotan ==
                              TutorialBentukSorotan.oval
                          ? BoxShape.circle
                          : BoxShape.rectangle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.96),
                        width: 2.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: langkahAktif.warna.withValues(alpha: 0.42),
                          blurRadius: 22,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Positioned(
              top: mediaQuery.padding.top + 10,
              right: 12,
              child: SafeArea(
                bottom: false,
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.black.withValues(alpha: 0.28),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Lewati'),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 420),
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 24,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: langkahAktif.warna.withValues(
                                  alpha: 0.14,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                langkahAktif.icon,
                                color: langkahAktif.warna,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.judul,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF687385),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    langkahAktif.judul,
                                    style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: langkahAktif.warna.withValues(
                                  alpha: 0.10,
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${_indexAktif + 1}/${widget.langkah.length}',
                                style: TextStyle(
                                  color: langkahAktif.warna,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          langkahAktif.deskripsi,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: Color(0xFF4C5667),
                          ),
                        ),
                        if (_memuatSorotan) ...[
                          const SizedBox(height: 12),
                          const Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Menyiapkan sorotan tampilan...',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF687385),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else if (_targetRect == null) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Bagian yang disorot belum tersedia, tapi langkah ini tetap menjelaskan fungsi utamanya.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF687385),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(widget.langkah.length, (
                            index,
                          ) {
                            final aktif = index == _indexAktif;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: aktif ? 22 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: aktif
                                    ? langkahAktif.warna
                                    : const Color(0xFFD5DBE5),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed:
                                    _indexAktif == 0 || _sedangPindahLangkah
                                    ? null
                                    : _langkahSebelumnya,
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
                                ),
                                child: const Text('Sebelumnya'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _sedangPindahLangkah
                                    ? null
                                    : _langkahBerikutnya,
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
                                  backgroundColor: langkahAktif.warna,
                                  foregroundColor: Colors.white,
                                ),
                                child: Text(
                                  langkahTerakhir ? 'Selesai' : 'Lanjut',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TutorialOverlayPainter extends CustomPainter {
  final Rect? targetRect;
  final double radiusSorotan;
  final TutorialBentukSorotan bentukSorotan;

  const _TutorialOverlayPainter({
    required this.targetRect,
    required this.radiusSorotan,
    required this.bentukSorotan,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPath = Path()..addRect(Offset.zero & size);
    if (targetRect != null) {
      if (bentukSorotan == TutorialBentukSorotan.oval) {
        overlayPath.addOval(targetRect!);
      } else {
        overlayPath.addRRect(
          RRect.fromRectAndRadius(targetRect!, Radius.circular(radiusSorotan)),
        );
      }
      overlayPath.fillType = PathFillType.evenOdd;
    }

    canvas.drawPath(
      overlayPath,
      Paint()..color = Colors.black.withValues(alpha: 0.72),
    );
  }

  @override
  bool shouldRepaint(covariant _TutorialOverlayPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.radiusSorotan != radiusSorotan ||
        oldDelegate.bentukSorotan != bentukSorotan;
  }
}
