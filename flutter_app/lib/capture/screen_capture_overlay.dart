import 'package:flutter/material.dart';
import 'capture_painter.dart';
import 'capture_region.dart';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:google_fonts/google_fonts.dart';

class ScreenCaptureOverlay extends StatefulWidget {
  const ScreenCaptureOverlay({super.key});

  @override
  State<ScreenCaptureOverlay> createState() => _ScreenCaptureOverlayState();
}

class _ScreenCaptureOverlayState extends State<ScreenCaptureOverlay> {
  Offset? start;
  Offset? current;
  bool selectionComplete = false;
  Offset mousePos = Offset.zero;
  bool dragEnabled = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final display = await screenRetriever.getPrimaryDisplay();
      final screenWidth = display.size.width;
      final screenHeight = display.size.height;
      await windowManager.setSize(Size(screenWidth, screenHeight));
      await windowManager.setPosition(const Offset(0, 0));
      await Future.delayed(const Duration(milliseconds: 500));

      await windowManager.setOpacity(1.0);
    });
  }

  Rect? get selectionRect {
    if (start == null || current == null) return null;
    final r = Rect.fromPoints(start!, current!);

    const minSize = 30.0;
    if (r.width < minSize || r.height < minSize) {
      return null; // treat as invalid selection
    }
    return Rect.fromPoints(start!, current!);
  }

  void confirmCapture() {
    final rect = selectionRect;
    if (rect == null) return;

    final region = CaptureRegion(
      x: rect.left,
      y: rect.top,
      width: rect.width,
      height: rect.height,
    );
    Navigator.pop(context, region);
  }

  void cancelCapture() {
    Navigator.pop(context);
  }

  void clearSelection() {
    setState(() {
      start = null;
      current = null;
    });
  }

  void beginDrag(Offset pos) {
    if (!dragEnabled) return;

    setState(() {
      selectionComplete = false;
      start = pos;
      current = pos;
    });
  }

  void updateDrag(Offset pos) {
    if (!dragEnabled) return;

    setState(() {
      current = pos;
    });
  }

  void endDrag() {
    if (!dragEnabled) return;

    setState(() {
      selectionComplete = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final rect = selectionRect;
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // =========================
          // DRAG LAYER (ONLY AREA)
          // =========================
          GestureDetector(
            behavior: HitTestBehavior.opaque,

            onPanStart: (details) {
              beginDrag(details.globalPosition);
            },

            onPanUpdate: (details) {
              updateDrag(details.globalPosition);
            },

            onPanEnd: (_) {
              endDrag();
            },

            child: CustomPaint(
              size: size,
              painter: CapturePainter(selectionRect),
            ),
          ),

          // =========================
          // UI LAYER (BLOCKS DRAG)
          // =========================
          Positioned(
            left: MediaQuery.of(context).size.width / 2 - 144,
            top: 30,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color.fromARGB(255, 0, 0, 0)),
                borderRadius: BorderRadius.circular(5),
                color: const Color.fromARGB(255, 255, 255, 255),
              ),
              padding: EdgeInsets.all(8),
              alignment: Alignment.center,
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color.fromARGB(255, 0, 0, 0),
                        ),
                        borderRadius: BorderRadius.circular(3),
                        color: Colors.white,
                      ),
                      padding: EdgeInsets.all(5),
                      alignment: Alignment.center,
                      height: 25,
                      child: Text(
                        "SELECT REGION CAPTURE",
                        style: GoogleFonts.montserrat(
                          textStyle: TextStyle(
                            color: const Color.fromARGB(255, 0, 0, 0),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    VerticalDivider(
                      color: const Color.fromARGB(255, 0, 0, 0),
                      width: 22,
                      thickness: 1,
                    ),
                    Opacity(
                      opacity:
                          (rect != null &&
                              selectionComplete &&
                              (rect.topRight.dx - rect.bottomLeft.dx > 20 &&
                                  rect.bottomLeft.dy - rect.topRight.dy > 20))
                          ? 1
                          : 0.4,
                      child: SizedBox(
                        width: 25,
                        height: 25,
                        child: FloatingActionButton(
                          backgroundColor: Colors.white,
                          heroTag: null,
                          mini: true,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadiusGeometry.circular(3),
                          ),
                          onPressed:
                              (rect != null &&
                                  selectionComplete &&
                                  (rect.topRight.dx - rect.bottomLeft.dx > 5 &&
                                      rect.topRight.dy - rect.bottomLeft.dy >
                                          5))
                              ? confirmCapture
                              : null,
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                    VerticalDivider(color: Colors.white, width: 9),
                    Opacity(
                      opacity: (rect != null && selectionComplete) ? 1 : 0.4,
                      child: SizedBox(
                        width: 25,
                        height: 25,
                        child: FloatingActionButton(
                          backgroundColor: Colors.white,
                          heroTag: null,
                          mini: true,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadiusGeometry.circular(3),
                          ),
                          onPressed: (rect != null && selectionComplete)
                              ? clearSelection
                              : null,
                          child: const Icon(
                            Icons.restart_alt_rounded,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                    VerticalDivider(color: Colors.white, width: 9),
                    Container(
                      width: 25,
                      height: 25,
                      child: FloatingActionButton(
                        heroTag: null,
                        mini: true,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadiusGeometry.circular(3),
                        ),
                        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
                        onPressed: cancelCapture,
                        child: const Icon(
                          Icons.close_rounded,
                          color: Color.fromARGB(255, 255, 255, 255),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
