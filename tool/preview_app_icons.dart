// Renders candidate application icons to a PNG contact sheet.
//
//   flutter test tool/preview_app_icons.dart
//
// It writes `tool/preview/app-icon-candidates.png`: four designs, each at the
// sizes a launcher actually draws them (192, 96, 48 and 32 px) beside one large
// master. Nothing in the application reads it, and none of these is shipped
// until one is chosen: the shipping icon is `PaperfoldAppIcon`, next door in
// `lib/widgets/paperfold_logo_mark.dart`.
//
// An icon is judged at 48 px on a crowded home screen, not at 1024 px in a
// design tool, which is the whole reason this sheet exists.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/widgets/paperfold_logo_mark.dart';

const String _outputDirectory = 'tool/preview';
const List<double> _sizes = [176, 96, 48, 32];

const Color _ground = Color(0xFF4A1528);
const Color _foil = Color(0xFFE7C77B);

void main() {
  final GlobalKey boundary = GlobalKey();

  testWidgets('renders the application icon candidates', (tester) async {
    await tester.runAsync(() async {
      await (FontLoader(PaperfoldTypeTokens.journalFamily)
            ..addFont(rootBundle.load('assets/fonts/Philosopher-Bold.ttf')))
          .load();
      await (FontLoader(PaperfoldTypeTokens.chromeFamily)
            ..addFont(rootBundle.load('assets/fonts/SourceSans3-SemiBold.ttf')))
          .load();
    });

    final directory = Directory(_outputDirectory);
    if (!directory.existsSync()) directory.createSync(recursive: true);

    const candidates = <String, _Candidate>{
      'A  today': _Candidate.current,
      'B  stripped': _Candidate.stripped,
      'C  folded page': _Candidate.foldedPage,
      'D  open book': _Candidate.openBook,
    };

    const sheet = Size(760, 4 * 220.0 + 40);
    await tester.binding.setSurfaceSize(sheet);
    tester.view.physicalSize = sheet;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: ColoredBox(
            color: const Color(0xFF161616),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final entry in candidates.entries)
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 120,
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 15,
                                fontFamily:
                                    PaperfoldTypeTokens.chromeFamily,
                              ),
                            ),
                          ),
                          for (final size in _sizes)
                            Padding(
                              padding: const EdgeInsets.only(right: 22),
                              child: _IconTile(
                                candidate: entry.value,
                                side: size,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await render.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) return;
      File('$_outputDirectory/app-icon-candidates.png')
          .writeAsBytesSync(data.buffer.asUint8List());
    });

    await tester.binding.setSurfaceSize(null);
  });
}

enum _Candidate { current, stripped, foldedPage, openBook }

class _IconTile extends StatelessWidget {
  const _IconTile({required this.candidate, required this.side});

  final _Candidate candidate;
  final double side;

  @override
  Widget build(BuildContext context) {
    // Every launcher masks the master, so the sheet masks it too. An icon
    // judged as a square is judged as a shape nobody will ever see.
    return ClipRRect(
      borderRadius: BorderRadius.circular(side * 0.224),
      child: SizedBox.square(
        dimension: side,
        child: switch (candidate) {
          _Candidate.current =>
            PaperfoldAppIcon(size: side, shape: PaperfoldAppIconShape.card),
          _Candidate.stripped => ColoredBox(
              color: _ground,
              child: Center(
                child: PaperfoldLogoMark(size: side * 0.74, tint: _foil),
              ),
            ),
          _Candidate.foldedPage => CustomPaint(
              painter: const _FoldedPagePainter(),
              size: Size.square(side),
            ),
          _Candidate.openBook => CustomPaint(
              painter: const _OpenBookPainter(),
              size: Size.square(side),
            ),
        },
      ),
    );
  }
}

/// One sheet of paper with its corner turned: the application's own name.
///
/// No letters and no ornament. The whole shape survives to 32 px because it is
/// one silhouette with one notch cut out of it, and the notch is the only
/// detail there is.
class _FoldedPagePainter extends CustomPainter {
  const _FoldedPagePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    canvas.drawRect(Offset.zero & size, Paint()..color = _ground);
    double x(double u) => s * u / 100;

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = x(5.5)
      ..strokeJoin = StrokeJoin.round
      ..color = _foil;

    final sheet = Path()
      ..moveTo(x(24), x(16))
      ..lineTo(x(58), x(16))
      ..lineTo(x(76), x(34))
      ..lineTo(x(76), x(84))
      ..lineTo(x(24), x(84))
      ..close();
    canvas.drawPath(sheet, stroke);

    // The fold itself, filled: it is the one part of the mark that has to read
    // as a solid at the smallest size, because it is what says "folded".
    final fold = Path()
      ..moveTo(x(58), x(16))
      ..lineTo(x(76), x(34))
      ..lineTo(x(58), x(34))
      ..close();
    canvas.drawPath(fold, Paint()..color = _foil);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A book lying open, seen from the head: two leaves rising from one gutter.
///
/// The motif the application already uses on its cover, drawn as one heavy
/// stroke instead of a fine one, with nothing round it.
class _OpenBookPainter extends CustomPainter {
  const _OpenBookPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    canvas.drawRect(Offset.zero & size, Paint()..color = _ground);
    double x(double u) => s * u / 100;

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = x(6.5)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = _foil;

    // Each leaf sags away from the gutter, which is what makes it paper rather
    // than a chevron.
    final left = Path()
      ..moveTo(x(50), x(34))
      ..quadraticBezierTo(x(36), x(24), x(17), x(28))
      ..lineTo(x(17), x(70))
      ..quadraticBezierTo(x(36), x(66), x(50), x(76));
    final right = Path()
      ..moveTo(x(50), x(34))
      ..quadraticBezierTo(x(64), x(24), x(83), x(28))
      ..lineTo(x(83), x(70))
      ..quadraticBezierTo(x(64), x(66), x(50), x(76));

    canvas
      ..drawPath(left, stroke)
      ..drawPath(right, stroke)
      ..drawLine(Offset(x(50), x(34)), Offset(x(50), x(76)), stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
