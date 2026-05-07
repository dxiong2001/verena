import 'package:flutter/material.dart';

class CapturePainter extends CustomPainter {
  final Rect? rect;

  CapturePainter(this.rect);

  @override
  void paint(Canvas canvas, Size size) {
    final darkPaint = Paint()..color = Colors.black54;
    canvas.drawRect(Offset.zero & size, darkPaint);

    if (rect == null) return;

    final r = rect!;

    // safe paint
    final clearPaint = Paint()..blendMode = BlendMode.clear;

    canvas.drawRect(r, clearPaint);

    final borderPaint = Paint()
      ..color = const Color.fromARGB(255, 255, 255, 255)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRect(r, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CapturePainter oldDelegate) {
    return oldDelegate.rect != rect;
  }
}
