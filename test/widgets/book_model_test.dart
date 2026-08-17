import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/enums/book_binding.dart';
import 'package:paperfold/service/book_art.dart';
import 'package:paperfold/widgets/book_model/book_model.dart';
import 'package:paperfold/widgets/book_model/book_model_builder.dart';
import 'package:paperfold/widgets/book_model/book_model_scene.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  BookModelSpec spec({
    BookBinding binding = BookBinding.hardback,
    double open = 0,
    double openAt = 0,
    BookArt? art,
    int seed = 12345,
    String title = 'The Wind in the Willows',
    String author = 'Kenneth Grahame',
  }) {
    final scheme = PaperfoldTokens.colorScheme(Brightness.light);
    return BookModelSpec(
      binding: binding,
      title: title,
      author: author,
      blurb: 'Mole, Rat, Badger and the incorrigible Toad of Toad Hall.',
      open: open,
      openAt: openAt,
      art: art,
      seed: seed,
      palette: BookModelPalette.resolve(
        scheme: scheme,
        binding: binding,
        seed: seed,
        art: art,
      ),
      typography: const BookModelTypography(
        title: TextStyle(),
        author: TextStyle(),
        label: TextStyle(),
      ),
    );
  }

  BookFace faceNamed(List<BookFace> faces, String name) =>
      faces.firstWhere((face) => face.debugName == name);

  group('geometry', () {
    test('a hardback stands proud of its paper on three edges', () {
      final metrics = BookMetrics.from(BookBindingProfile.hardback, 1);

      expect(metrics.boardWidth, greaterThan(metrics.blockWidth));
      expect(metrics.boardHeight, greaterThan(metrics.blockHeight));
      expect(metrics.boardTop, lessThan(metrics.blockTop));
      expect(metrics.boardBottom, greaterThan(metrics.blockBottom));
      // The squares are the same all the way round.
      expect(
        metrics.boardBottom - metrics.blockBottom,
        closeTo(metrics.boardWidth - metrics.blockWidth, 1e-9),
      );
    });

    test('a softback is trimmed flush with its block', () {
      final metrics = BookMetrics.from(BookBindingProfile.softback, 1);

      expect(metrics.boardWidth, metrics.blockWidth);
      expect(metrics.boardHeight, metrics.blockHeight);
      expect(BookBindingProfile.softback.squares, 0);
      // And its cover is card, not board.
      expect(
        BookBindingProfile.softback.boardThickness,
        lessThan(BookBindingProfile.hardback.boardThickness / 2),
      );
    });

    test('a hardback spine bows out and a softback spine does not', () {
      final hard = BookMetrics.from(BookBindingProfile.hardback, 1);
      final soft = BookMetrics.from(BookBindingProfile.softback, 1);

      // A hint of round at the joints, not a bow. The title is painted on the
      // middle of this strip and has to stay flat enough to read.
      expect(hard.spineBulge, greaterThan(hard.totalDepth * 0.05));
      expect(hard.spineBulge, lessThan(hard.totalDepth * 0.15));
      expect(soft.spineBulge, lessThan(soft.totalDepth * 0.07));
      // Rounding the spine hollows the fore-edge to match.
      expect(hard.foreEdgeHollow, greaterThan(soft.foreEdgeHollow));
    });

    test('the same book is always the same thickness', () {
      final first = BookMetrics.from(BookBindingProfile.hardback, 90210);
      final second = BookMetrics.from(BookBindingProfile.hardback, 90210);
      final other = BookMetrics.from(BookBindingProfile.hardback, 4242);

      expect(first.blockDepth, second.blockDepth);
      expect(first.blockDepth, isNot(other.blockDepth));
      for (final seed in [0, 1, 77, 1024, 65535]) {
        final metrics = BookMetrics.from(BookBindingProfile.hardback, seed);
        expect(
          metrics.blockDepth,
          inInclusiveRange(
            BookBindingProfile.hardback.minimumDepth,
            BookBindingProfile.hardback.maximumDepth,
          ),
        );
      }
    });

    test('every face looks out of the book, not into it', () {
      final faces = BookModelBuilder.build(spec());

      expect(faceNamed(faces, 'front-board-outer').normal.z, greaterThan(0.9));
      expect(faceNamed(faces, 'back-board-outer').normal.z, lessThan(-0.9));
      expect(faceNamed(faces, 'front-board-inner').normal.z, lessThan(-0.9));
      expect(faceNamed(faces, 'back-board-inner').normal.z, greaterThan(0.9));
      expect(faceNamed(faces, 'page-head').normal.y, lessThan(-0.9));
      expect(faceNamed(faces, 'page-tail').normal.y, greaterThan(0.9));
      expect(faceNamed(faces, 'page-fore-edge-0').normal.x, greaterThan(0.5));
      expect(faceNamed(faces, 'spine-0').normal.x, lessThan(0));
      expect(
        faceNamed(faces, 'front-board-fore-edge').normal.x,
        greaterThan(0.9),
      );
    });

    test('the back cover reads from its own fore-edge inward', () {
      // Turning a book over puts the spine on the other side. The back board's
      // own leading edge is therefore the fore-edge, or everything printed on
      // it comes out mirrored.
      final back =
          faceNamed(BookModelBuilder.build(spec()), 'back-board-outer');

      expect(back.u.x, lessThan(0));
      expect(back.origin.x, greaterThan(0));
      expect(back.origin.z, 0);
    });

    test('a shut book hides its paper behind its boards', () {
      final metrics = BookMetrics.from(BookBindingProfile.hardback, 12345);
      final faces = BookModelBuilder.build(spec());
      final page = faceNamed(faces, 'page-top');
      final cover = faceNamed(faces, 'front-board-outer');

      expect(page.origin.z, lessThan(cover.origin.z));
      expect(page.width, lessThan(cover.width));
      expect(metrics.blockFrontZ, lessThan(metrics.frontBoardOuterZ));
    });
  });

  group('the object is closed', () {
    test('openAt zero keeps the original face names for both bindings', () {
      final expected = <String>{
        'drop-shadow',
        for (final board in ['back-board', 'front-board']) ...{
          '$board-outer',
          '$board-inner',
          '$board-fore-edge',
          '$board-joint',
          '$board-head',
          '$board-tail',
        },
        'page-top',
        'page-bottom',
        'page-spine',
        'page-head',
        'page-tail',
        // The tessellation of the two curved strips. Raised from 5 and 8 so
        // the hollow of the fore-edge and the bow of the spine read as curves
        // rather than as a run of flats.
        for (var index = 0; index < 12; index++) 'page-fore-edge-$index',
        for (var index = 0; index < 20; index++) 'spine-$index',
      };
      final expectedOpen = <String>{
        ...expected,
        'cast-shadow',
        for (var leaf = 0; leaf < BookModelBuilder.leafFollow.length; leaf++)
          for (var panel = 0; panel < 3; panel++) 'leaf-$leaf-$panel',
      };

      for (final binding in BookBinding.values) {
        final shutNames = BookModelBuilder.build(
          spec(binding: binding, openAt: 0),
        ).map((face) => face.debugName).toSet();
        final openNames = BookModelBuilder.build(
          spec(binding: binding, open: 0.55, openAt: 0),
        ).map((face) => face.debugName).toSet();

        expect(shutNames, expected, reason: '$binding changed the shut path');
        expect(
          openNames,
          expectedOpen,
          reason: '$binding changed the opening path',
        );
      }
    });

    test('the paper is a box of six faces, including its bound edge', () {
      final faces = BookModelBuilder.build(spec());
      final block = faces
          .where((face) => face.debugName.startsWith('page-'))
          .map((face) => face.debugName)
          .toSet();

      expect(block, contains('page-top'));
      expect(block, contains('page-bottom'));
      expect(block, contains('page-spine'));
      expect(block, contains('page-head'));
      expect(block, contains('page-tail'));
      expect(
          block.where((name) => name.startsWith('page-fore-edge')), isNotEmpty);
      // The bound edge looks back at the spine, which is the direction the
      // hollow of a cased spine is seen from.
      expect(faceNamed(faces, 'page-spine').normal.x, lessThan(-0.9));
    });

    test('a board has four edges, not three', () {
      final faces =
          BookModelBuilder.build(spec()).map((face) => face.debugName).toSet();

      for (final board in ['front-board', 'back-board']) {
        expect(faces, contains('$board-fore-edge'));
        expect(faces, contains('$board-joint'));
        expect(faces, contains('$board-head'));
        expect(faces, contains('$board-tail'));
      }
    });

    test('no angle of the turn opens a hole in the spine', () {
      // A rounded spine turns away from the reader like a cylinder, so half
      // its facets face away at any moment. Dropping them leaves a gap with
      // nothing behind it, because a book is hollow at the spine.
      final faces = BookModelBuilder.build(spec());
      final spine = faces.where((f) => f.debugName.startsWith('spine-'));
      expect(spine, isNotEmpty);
      expect(spine.every((face) => face.doubleSided), isTrue);

      for (final yaw in [-0.4, 0.0, 0.38, 0.85, 0.92, 1.0, 1.75, 2.4, 3.52]) {
        final camera = BookCamera(yaw: yaw, pitch: -0.35);
        final drawn = BookModelRenderer.order(faces, camera)
            .map((entry) => entry.face.debugName)
            .where((name) => name.startsWith('spine-'))
            .length;
        expect(drawn, spine.length, reason: 'a facet went missing at yaw $yaw');
      }
    });

    test('every solid face carries a colour to bleed into its own seams', () {
      // Every face except the joints inside a curved strip. A skirt is a flat
      // rectangle laid down before a face's content, so inside a strip it lands
      // on the content of the facet beside it: with one on every facet, the
      // foil rules running across a spine came out dashed, a gap per joint.
      // Those joints are closed by the facets overdrawing each other with real
      // content instead, and the two ends of a strip still carry a skirt,
      // because what lies past them is a board.
      bool isStrip(String name) =>
          name == 'spine' || name.endsWith('fore-edge');
      final facet = RegExp(r'^(.*)-(\d+)$');
      final faces = BookModelBuilder.build(spec(open: 0.5));
      final stripCounts = <String, int>{};
      for (final face in faces) {
        final match = facet.firstMatch(face.debugName);
        if (match == null || !isStrip(match.group(1)!)) continue;
        stripCounts.update(
          match.group(1)!,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
      expect(stripCounts, isNotEmpty, reason: 'no curved strip was built');

      for (final face in faces) {
        if (!face.lit) continue;
        final match = facet.firstMatch(face.debugName);
        if (match != null && isStrip(match.group(1)!)) {
          final index = int.parse(match.group(2)!);
          final last = stripCounts[match.group(1)!]! - 1;
          if (index != 0 && index != last) continue;
        }
        expect(
          face.bleed,
          isNotNull,
          reason: '${face.debugName} would show a hairline at its edges',
        );
      }
    });

    test('a half split keeps all gathered paper closed at full depth', () {
      for (final binding in BookBinding.values) {
        final metrics = BookMetrics.from(
          BookBindingProfile.of(binding),
          12345,
        );
        final faces = BookModelBuilder.build(
          spec(binding: binding, open: 0.55, openAt: 0.5),
        );
        final resting = faceNamed(faces, 'page-resting-spine');
        final lifted = [
          for (var index = 0; index < 3; index++)
            faceNamed(faces, 'page-lifted-$index-spine'),
        ];

        expect(
          resting.width + lifted.fold(0.0, (depth, face) => depth + face.width),
          closeTo(metrics.blockDepth, 1e-9),
        );
        for (final stack in [
          'page-resting',
          for (var index = 0; index < 3; index++) 'page-lifted-$index',
        ]) {
          final names = faces
              .where((face) => face.debugName.startsWith(stack))
              .map((face) => face.debugName)
              .toSet();
          expect(names, contains('$stack-top'));
          expect(names, contains('$stack-bottom'));
          expect(names, contains('$stack-spine'));
          expect(names, contains('$stack-head'));
          expect(names, contains('$stack-tail'));
          expect(
            names.where((name) => name.startsWith('$stack-fore-edge-')),
            isNotEmpty,
          );
        }
      }
    });

    test('every split-stack face sorts from its bound edge', () {
      const opening = 0.55;
      for (final binding in BookBinding.values) {
        final profile = BookBindingProfile.of(binding);
        final metrics = BookMetrics.from(profile, 12345);
        final faces = BookModelBuilder.build(
          spec(binding: binding, open: opening, openAt: 0.5),
        );

        for (final face in faces
            .where((face) => face.debugName.startsWith('page-resting'))) {
          expect(face.depthAnchor, isNotNull, reason: face.debugName);
          expect(face.depthAnchor!.x, closeTo(0, 1e-9), reason: face.debugName);
        }
        for (var index = 0; index < 3; index++) {
          final prefix = 'page-lifted-$index';
          final top = faceNamed(faces, '$prefix-top');
          final stackAngle = math.atan2(top.u.z, top.u.x);
          final inverseHinge = BookTransform.hinge(
            axisX: profile.grooveWidth,
            axisZ: (metrics.frontBoardInnerZ + metrics.frontBoardOuterZ) / 2,
            angle: -stackAngle,
          );
          for (final face
              in faces.where((face) => face.debugName.startsWith(prefix))) {
            expect(face.depthAnchor, isNotNull, reason: face.debugName);
            expect(
              inverseHinge.point(face.depthAnchor!).x,
              closeTo(0, 1e-9),
              reason: face.debugName,
            );
          }
        }
      }
    });

    test('openAt one leaves no unrotated paper on the back board', () {
      for (final binding in BookBinding.values) {
        final faces = BookModelBuilder.build(
          spec(binding: binding, open: 0.55, openAt: 1),
        );
        final paper =
            faces.where((face) => face.debugName.startsWith('page-')).toList();

        expect(paper, isNotEmpty);
        expect(
          paper.every((face) => face.debugName.startsWith('page-lifted-')),
          isTrue,
        );
        expect(
          faceNamed(faces, 'page-lifted-0-top').origin.x,
          isNot(closeTo(0, 1e-9)),
        );
        expect(
          faces.any((face) => face.debugName == 'cast-shadow'),
          isFalse,
        );
      }
    });
  });

  group('opening', () {
    test('copyWith carries the opening point', () {
      final original = spec(openAt: 0.25);
      final moved = original.copyWith(openAt: 0.75);

      expect(original.openAt, 0.25);
      expect(moved.openAt, 0.75);
      expect(moved.open, original.open);
    });

    test('a split replaces the flyleaves and moves the cast shadow', () {
      for (final binding in BookBinding.values) {
        final metrics = BookMetrics.from(
          BookBindingProfile.of(binding),
          12345,
        );
        final faces = BookModelBuilder.build(
          spec(binding: binding, open: 0.55, openAt: 0.25),
        );

        expect(
          faces.any((face) => face.debugName.startsWith('leaf-')),
          isFalse,
        );
        expect(
          faceNamed(faces, 'cast-shadow').origin.z,
          closeTo(metrics.blockBackZ + metrics.blockDepth * 0.75, 1e-9),
        );
      }
    });

    test('the lifted paper has a visible angular gap behind the board', () {
      const opening = 0.68;
      for (final binding in BookBinding.values) {
        final faces = BookModelBuilder.build(
          spec(binding: binding, open: opening, openAt: 0.5),
        );
        final board = faceNamed(faces, 'front-board-outer');
        final separations = <double>[];

        for (var index = 0; index < 3; index++) {
          final paper = faceNamed(faces, 'page-lifted-$index-top');
          final dot = board.normal.dot(paper.normal).clamp(-1.0, 1.0);
          final separation = math.acos(dot);
          separations.add(separation);
          expect(
            separation,
            greaterThan(0.15),
            reason: '$binding stack $index disappeared behind the board',
          );
        }
        expect(separations[1], greaterThan(separations[0] + 0.05));
        expect(separations[2], greaterThan(separations[1] + 0.05));
      }
    });

    test('the lifted paper shows more of itself the deeper it opens', () {
      const opening = 0.68;
      for (final binding in BookBinding.values) {
        final quarter = spec(binding: binding, open: opening, openAt: 0.25);
        final threeQuarter = spec(
          binding: binding,
          open: opening,
          openAt: 0.75,
        );
        // The centroid of the cut edge is the wrong thing to measure. It can
        // sit in almost the same place whether a quarter of the book has come
        // up or three quarters of it, because the sections fan about a hinge
        // the centroid barely leaves. What has to grow is the amount of paper
        // the reader can see edge on, so the measure is the outline the lifted
        // cut edges cast on the screen.
        double projectedForeEdgeArea(BookModelSpec model) {
          final faces = BookModelBuilder.build(model);
          // Every gathered section, not one named one. The deepest section
          // lies almost flat on the block, and a fore-edge is a single-sided
          // strip, so its facets are turned away and culled at some cameras.
          // That is the culling working, not a hole: what has to hold is that
          // the reader can see the cut edge of the lifted paper somewhere,
          // because that edge is the only thing that says how much of the book
          // has come up.
          final foreEdge = faces
              .where(
                (face) => RegExp(r'^page-lifted-\d+-fore-edge-')
                    .hasMatch(face.debugName),
              )
              .toList();
          expect(foreEdge, isNotEmpty, reason: '$binding built no lifted '
              'fore-edge at all');
          final visibleNames = BookModelRenderer.order(faces, model.camera)
              .map((entry) => entry.face.debugName)
              .toSet();
          expect(
            foreEdge.any((face) => visibleNames.contains(face.debugName)),
            isTrue,
            reason: '$binding hid every facet of the lifted fore-edge, so the '
                'thickness of the lifted paper cannot be read',
          );

          final view = BookModelRenderer.viewOf(model);
          var left = double.infinity;
          var top = double.infinity;
          var right = double.negativeInfinity;
          var bottom = double.negativeInfinity;
          for (final face in foreEdge) {
            for (final corner in [
              face.origin,
              face.origin + face.u * face.width,
              face.origin + face.v * face.height,
              face.origin + face.u * face.width + face.v * face.height,
            ]) {
              final point = applyMatrix(view, corner);
              if (point.w <= 0) continue;
              final x = point.x / point.w;
              final y = point.y / point.w;
              if (x < left) left = x;
              if (x > right) right = x;
              if (y < top) top = y;
              if (y > bottom) bottom = y;
            }
          }
          if (left > right || top > bottom) return 0;
          return (right - left) * (bottom - top);
        }

        final shallow = projectedForeEdgeArea(quarter);
        final deep = projectedForeEdgeArea(threeQuarter);
        // 1.2 is not an ideal, it is the floor the approved contact sheet
        // clears with a little room. The failure this guards against is the
        // one that already happened once: the lifted paper hinged at the
        // cover's own angle, flush behind the board, where three times the
        // paper showed no more of itself and every split looked alike. The
        // outline is mostly the height of the book either way, so the ratio
        // moves less than the paper does. Regenerate the sheet and look before
        // changing this number in either direction.
        expect(
          deep,
          greaterThan(shallow * 1.2),
          reason: '$binding showed a book three quarters open as barely more '
              'lifted paper than one a quarter open, so the reader cannot see '
              'how far through the book they are',
        );
      }
    });

    test('the cover swings and carries the leaves less far', () {
      final shut = BookModelBuilder.build(spec());
      final open = BookModelBuilder.build(spec(open: 1));

      // Shut, the cover is where it was built.
      expect(faceNamed(shut, 'front-board-outer').origin.x, 0);
      expect(shut.any((face) => face.debugName.startsWith('leaf-')), isFalse);

      // Open, the free edge has passed over the spine.
      final cover = faceNamed(open, 'front-board-outer');
      final free = cover.origin + cover.u * cover.width;
      expect(free.x, lessThan(0));
      expect(free.z, greaterThan(cover.origin.z));

      double lifted(BookFace face) => math.atan2(face.u.z, face.u.x);
      expect(lifted(cover), closeTo(BookModelBuilder.maximumCoverAngle, 1e-9));

      // Each leaf lifts less than the one above it, and all less than the
      // cover: paper follows a board, it does not lead it. Height is the wrong
      // measure past square, where a swinging edge is on its way back down.
      final roots = [
        for (var index = 0; index < BookModelBuilder.leafFollow.length; index++)
          faceNamed(open, 'leaf-$index-0'),
      ];
      for (var index = 1; index < roots.length; index++) {
        expect(lifted(roots[index]), lessThan(lifted(roots[index - 1])));
      }
      expect(lifted(roots.first), lessThan(lifted(cover)));

      // A leaf is paper, so it bends: each panel along it lies flatter than
      // the one before, and the panels join end to end.
      final panels =
          open.where((face) => face.debugName.startsWith('leaf-0-')).toList();
      expect(panels.length, greaterThan(1));
      for (var index = 1; index < panels.length; index++) {
        expect(lifted(panels[index]), lessThan(lifted(panels[index - 1])));
        final previous = panels[index - 1].origin +
            panels[index - 1].u * panels[index - 1].width;
        expect(panels[index].origin.x, closeTo(previous.x, 1e-9));
        expect(panels[index].origin.z, closeTo(previous.z, 1e-9));
      }
    });

    test('the cover uncovers the page it was lying on', () {
      final shutOrder = BookModelRenderer.order(
        BookModelBuilder.build(spec()),
        const BookCamera(),
      );
      final openOrder = BookModelRenderer.order(
        BookModelBuilder.build(spec(open: 1)),
        const BookCamera(),
      );

      bool shows(List<BookDrawable> order, String name) =>
          order.any((entry) => entry.face.debugName == name);

      // Shut: the front board is in view, its lining and the back board are
      // not, and neither is the page under it.
      expect(shows(shutOrder, 'front-board-outer'), isTrue);
      expect(shows(shutOrder, 'front-board-inner'), isFalse);
      expect(shows(shutOrder, 'back-board-outer'), isFalse);
      expect(shows(shutOrder, 'page-top'), isTrue);

      // Open: the lining of the board is now facing the reader, and so is the
      // first page.
      expect(shows(openOrder, 'front-board-inner'), isTrue);
      expect(shows(openOrder, 'page-top'), isTrue);
      expect(shows(openOrder, 'cast-shadow'), isTrue);

      // The page is drawn before the cover that hangs over it.
      final page =
          openOrder.indexWhere((entry) => entry.face.debugName == 'page-top');
      final lining = openOrder
          .indexWhere((entry) => entry.face.debugName == 'front-board-inner');
      expect(page, lessThan(lining));
    });

    test('a lifting leaf is never lost behind the page it uncovers', () {
      // The leaves are the top sheets of the block, so they sit above the
      // printed page, not below it. Below it, a leaf lying nearly flat shared
      // a depth with the page and the sort decided between the two differently
      // from one angle and one frame to the next.
      for (final open in [0.05, 0.15, 0.3, 0.6, 1.0]) {
        for (final camera in [
          const BookCamera(),
          BookCamera.threeQuarter,
          const BookCamera(yaw: 1.0, pitch: -0.5),
        ]) {
          final order = BookModelRenderer.order(
            BookModelBuilder.build(spec(open: open)),
            camera,
          ).map((entry) => entry.face.debugName).toList();
          final page = order.indexOf('page-top');
          final leaves = order
              .where((name) => name.startsWith('leaf-'))
              .map(order.indexOf)
              .toList();
          expect(leaves, isNotEmpty, reason: 'no leaf at $open');
          for (final leaf in leaves) {
            expect(leaf, greaterThan(page), reason: 'a leaf sank at $open');
          }
        }
      }
    });

    test('the leaves fall back once the cover passes square', () {
      double topLeafAngle(double open) {
        final leaf =
            faceNamed(BookModelBuilder.build(spec(open: open)), 'leaf-0-0');
        return math.atan2(leaf.u.z, leaf.u.x);
      }

      // The cover holds the leaves up on the way to square and stops holding
      // them after it, so the fan rises and then settles.
      final atSquare = topLeafAngle(0.68);
      expect(topLeafAngle(0.3), lessThan(atSquare));
      expect(topLeafAngle(1), lessThan(atSquare));
    });

    test('an opening book is measured where it stands', () {
      Rect extent(double open) {
        final model = spec(open: open);
        return BookModelRenderer.extentOf(
          BookModelBuilder.build(model),
          BookModelRenderer.viewOf(model),
        );
      }

      final shut = extent(0);
      final open = extent(1);

      // A cover swung past square reaches out beyond the spine, and the
      // measurement has to follow it or the widget crops its own book.
      expect(open.width, greaterThan(shut.width));
      expect(open.left, lessThan(shut.left));
      expect(shut.width, greaterThan(0));
      expect(shut.height, greaterThan(shut.width));
      for (final value in [0.0, 0.25, 0.5, 0.75, 1.0]) {
        expect(extent(value).isFinite, isTrue);
      }
    });

    test('a small overshoot is allowed and a large one is not', () {
      final overshot = BookModelBuilder.build(spec(open: 4));
      final limit = BookModelBuilder.build(
        spec(open: BookModelBuilder.overshootLimit),
      );
      final cover = faceNamed(overshot, 'front-board-outer');
      final capped = faceNamed(limit, 'front-board-outer');

      expect(cover.origin.z, closeTo(capped.origin.z, 1e-9));
    });
  });

  group('camera', () {
    test('the spine falls on the leading side and the near edge grows', () {
      const camera = BookCamera();
      final rotation = camera.rotation;
      final metrics = BookMetrics.from(BookBindingProfile.hardback, 12345);

      final spine = applyMatrix(
        rotation,
        BookVector(-metrics.spineBulge, 0, metrics.totalDepth / 2),
      );
      final foreEdge = applyMatrix(
        rotation,
        BookVector(metrics.boardWidth, 0, metrics.totalDepth / 2),
      );
      expect(spine.x, lessThan(foreEdge.x));
      // Turning the fore-edge away is what brings the spine into view.
      expect(foreEdge.z, lessThan(spine.z));

      // A point nearer the camera projects further from the centre, which is
      // the whole of what perspective is.
      final projection = camera.projection;
      final near = applyMatrix(projection, const BookVector(1, 0, 0.2));
      final far = applyMatrix(projection, const BookVector(1, 0, -0.2));
      expect(near.x / near.w, greaterThan(far.x / far.w));
    });

    test('a shut book shows its front, its spine and no lining', () {
      final order = BookModelRenderer.order(
        BookModelBuilder.build(spec()),
        const BookCamera(),
      );
      final names = order.map((entry) => entry.face.debugName).toList();

      expect(names, contains('front-board-outer'));
      expect(names.where((name) => name.startsWith('spine-')), isNotEmpty);
      // Nothing that faces away from the reader is drawn.
      expect(names, isNot(contains('back-board-outer')));
      expect(names, isNot(contains('front-board-inner')));
      expect(names, isNot(contains('page-bottom')));
      // The front board covers the paper and the lining under it, so it is
      // drawn after both.
      expect(
        names.indexOf('front-board-outer'),
        greaterThan(names.indexOf('page-top')),
      );
      expect(
        names.indexOf('front-board-outer'),
        greaterThan(names.indexOf('back-board-inner')),
      );
    });

    test('the covering is drawn over the block it wraps, not under it', () {
      // The defect this guards, found on the phone on 2026-08-16: the block's
      // bound edge was the one face of the paper with no depth anchor, so it
      // sorted on the nearest-corner rule. It runs the whole thickness of the
      // book, so its far corner reaches nearer the camera than any one of the
      // twenty short facets the spine is cut into, and the paper was painted
      // over most of the spine. A hardback kept about half its title that way
      // and a softback about a fifth, so a paperback with no cover artwork
      // came out as a blank panel with one stray letter on it.
      //
      // Checked at the shelf's own camera, which is where nearly every book in
      // the application is seen and where the fault showed.
      const shelf = BookCamera(yaw: 1.30, pitch: -0.16, focalLength: 11);
      for (final binding in BookBinding.values) {
        final order = BookModelRenderer.order(
          BookModelBuilder.build(spec(binding: binding)),
          shelf,
        );
        final names = order.map((entry) => entry.face.debugName).toList();
        final boundEdge = names.indexOf('page-spine');
        final facets = [
          for (var index = 0; index < names.length; index++)
            if (names[index].startsWith('spine-')) index,
        ];

        expect(facets, isNotEmpty, reason: binding.code);
        expect(boundEdge, isNot(-1), reason: binding.code);
        // Every facet of the covering, not most of them.
        expect(
          facets.every((index) => index > boundEdge),
          isTrue,
          reason: '${binding.code}: the block is covering its own spine',
        );

        // The head and the tail of the block are the same argument, and were
        // the same fault: both run the whole width of the book, so on the
        // nearest-corner rule they sorted by their fore-edge corner, which
        // reaches half way along the bow. The covering was drawn over the paper
        // for its far ten facets and under it for its near ten, and every book
        // on the shelf wore a square staircase bitten out of its head.
        for (final edge in ['page-head', 'page-tail']) {
          final index = names.indexOf(edge);
          if (index == -1) continue;
          expect(
            facets.every((facet) => facet > index),
            isTrue,
            reason: '${binding.code}: the covering is cut into by $edge',
          );
        }
      }
    });

    test('the light reaches the front board and misses the far edges', () {
      final order = BookModelRenderer.order(
        BookModelBuilder.build(spec()),
        const BookCamera(),
      );
      double shadeOf(String name) => order
          .firstWhere((entry) => entry.face.debugName.startsWith(name))
          .shade;

      expect(shadeOf('front-board-outer'), greaterThan(0.5));
      // A face turned away from the key light is darker than the board that
      // faces it. One light, one rule, every surface. The spine rather than
      // the fore-edge: the fore-edge is behind the book at this camera, and a
      // flat-backed spine no longer bows any of it back into view.
      expect(shadeOf('spine'), lessThan(shadeOf('front-board-outer')));
      for (final entry in order) {
        expect(entry.shade, inInclusiveRange(0, 1));
      }
    });
  });

  group('the two bindings differ where a reader can see it', () {
    test('a hardback carries the craft a softback does not', () {
      const hard = BookBindingProfile.hardback;
      const soft = BookBindingProfile.softback;

      expect(hard.headbands, isTrue);
      expect(hard.endpapers, isTrue);
      expect(hard.raisedHubs, isTrue);
      expect(hard.grooveWidth, greaterThan(0));
      expect(hard.turnIn, greaterThan(0));
      expect(hard.printedBack, isFalse);

      expect(soft.headbands, isFalse);
      expect(soft.endpapers, isFalse);
      expect(soft.laminate, isTrue);
      expect(soft.spineCreases, isTrue);
      expect(soft.grooveWidth, 0);
      // A softback prints its blurb and its barcode on the back; a cased book
      // keeps a plain cloth board, because the blurb belongs on a jacket.
      expect(soft.printedBack, isTrue);
    });

    test('a cased spine covers the whole case and a flush one does not', () {
      final hardSpine = BookParts(
        spec(),
        BookMetrics.from(BookBindingProfile.hardback, 12345),
      ).spine();
      final softSpine = BookParts(
        spec(binding: BookBinding.softback),
        BookMetrics.from(BookBindingProfile.softback, 12345),
      ).spine();

      final hardMetrics = BookMetrics.from(BookBindingProfile.hardback, 12345);
      expect(hardSpine.first.height, closeTo(hardMetrics.boardHeight, 1e-9));
      expect(softSpine.first.height, closeTo(1, 1e-9));
      // A round spine takes several facets; a flat one does not.
      expect(hardSpine.length, greaterThan(4));
      expect(softSpine.length, greaterThan(0));
    });
  });

  group('art insert', () {
    late ui.Image frontOnly;
    late ui.Image jacket;

    setUpAll(() async {
      frontOnly = await _solid(120, 180, const [_Band(0, 1, 0xFFCC2244)]);
      // A complete jacket: red back, gold spine, blue front.
      jacket = await _solid(300, 200, const [
        _Band(0, 0.46, 0xFFCC2244),
        _Band(0.46, 0.54, 0xFFE7C77B),
        _Band(0.54, 1, 0xFF2244CC),
      ]);
    });

    test('a front-only cover gives a spine and a back that agree with it',
        () async {
      final art = await BookArtCache.describe(frontOnly);

      expect(art.layout, BookArtLayout.frontOnly);
      expect(art.front, Rect.fromLTWH(0, 0, 120, 180));
      // The spine takes the edge of the artwork that meets the hinge.
      expect(art.spine.left, 0);
      expect(art.spine.width, closeTo(120 * BookArtCache.stripFraction, 0.01));
      expect(art.back.right, 120);
      expect(art.coverAverage.r, greaterThan(art.coverAverage.b));
      // The printed title is tested against the field it sits on.
      expect(
        BookArtCache.contrast(art.coverInk, art.coverAverage),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        BookArtCache.contrast(art.spineInk, art.spineAverage),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('a wrap-around jacket is cut into back, spine and front', () async {
      final art = await BookArtCache.describe(jacket);

      expect(art.layout, BookArtLayout.wrapAround);
      expect(art.isWrapAround, isTrue);
      expect(art.back.left, 0);
      expect(art.front.right, 300);
      expect(art.spine.left, greaterThan(art.back.left));
      expect(art.spine.right, lessThan(art.front.right));
      // The three pieces are the three fields of the jacket, in order.
      expect(art.backAverage.r, greaterThan(art.backAverage.b));
      expect(art.coverAverage.b, greaterThan(art.coverAverage.r));
      expect(art.spineAverage.g, greaterThan(art.spineAverage.b));
    });

    test('a right-to-left jacket puts the front on the other side', () async {
      final art = await BookArtCache.describe(jacket, mirror: true);

      expect(art.front.left, 0);
      expect(art.back.right, 300);
      expect(art.coverAverage.r, greaterThan(art.coverAverage.b));
    });

    test('the artwork reaches the cover, the spine and the back', () async {
      final art = await BookArtCache.describe(jacket);

      // The front board is blue, the spine gold, the back red. Reading the
      // rendered pixels is the only way to know the art really is wrapped
      // round the object rather than pasted on one face of it.
      final front = await _render(spec(art: art), const Size(400, 460));
      expect(_dominant(front), _Hue.blue);

      final fromBehind = await _render(
        spec(art: art),
        const Size(400, 460),
        camera: const BookCamera(yaw: 2.9),
      );
      expect(_dominant(fromBehind), _Hue.red);

      // Set with no type on it. The spine title is now printed large enough to
      // read across a room, and a long one covers enough of a 12 mm spine to
      // outvote the artwork under it. This assertion is about where the
      // artwork lands, not about how much of it the title leaves showing.
      final edgeOn = await _render(
        spec(art: art, title: '', author: ''),
        const Size(400, 460),
        camera: const BookCamera(yaw: 1.45),
      );
      expect(_dominant(edgeOn), _Hue.gold);
    });

    test('a book with no artwork still prints a cover', () async {
      final printed = await _render(spec(), const Size(400, 460));
      final withArt = await _render(
        spec(art: await BookArtCache.describe(frontOnly)),
        const Size(400, 460),
      );

      expect(_isBlank(printed), isFalse);
      expect(_isBlank(withArt), isFalse);
      expect(printed, isNot(withArt));
    });

    test('every opening of both bindings paints without complaint', () async {
      for (final binding in BookBinding.values) {
        for (final open in [0.0, 0.15, 0.5, 0.85, 1.0, 1.1]) {
          final image = await _render(
            spec(binding: binding, open: open),
            const Size(240, 300),
          );
          expect(_isBlank(image), isFalse,
              reason: '$binding at $open painted nothing');
        }
      }
    });
  });
}

// --------------------------------------------------------------------- tools

/// Renders the model to raw pixels, which is the only honest way to test that
/// something reached the screen.
Future<Uint8List> _render(
  BookModelSpec spec,
  Size size, {
  BookCamera? camera,
  bool mirror = false,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Offset.zero & size,
    Paint()..color = const Color(0xFF101010),
  );
  BookModelRenderer.paint(
    canvas,
    size,
    camera == null ? spec : spec.copyWith(camera: camera),
    mirror: mirror,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.round(), size.height.round());
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  picture.dispose();
  image.dispose();
  return data!.buffer.asUint8List();
}

enum _Hue { red, gold, blue, none }

/// The strongest hue in the middle of the frame, where the object is.
_Hue _dominant(Uint8List pixels) {
  var red = 0, gold = 0, blue = 0;
  for (var i = 0; i < pixels.length; i += 4) {
    final r = pixels[i], g = pixels[i + 1], b = pixels[i + 2];
    if (r < 40 && g < 40 && b < 40) continue;
    if (r > b + 30 && r > g + 30) red++;
    if (b > r + 30) blue++;
    if (r > b + 30 && g > b + 20 && g > 90) gold++;
  }
  if (red == 0 && gold == 0 && blue == 0) return _Hue.none;
  if (blue >= red && blue >= gold) return _Hue.blue;
  return gold > red ? _Hue.gold : _Hue.red;
}

bool _isBlank(Uint8List pixels) {
  for (var i = 0; i < pixels.length; i += 4) {
    if (pixels[i] != 0x10 || pixels[i + 1] != 0x10 || pixels[i + 2] != 0x10) {
      return false;
    }
  }
  return true;
}

class _Band {
  const _Band(this.from, this.to, this.color);
  final double from;
  final double to;
  final int color;
}

/// Builds an image of vertical bands, which stands in for cover artwork.
Future<ui.Image> _solid(int width, int height, List<_Band> bands) async {
  final pixels = Uint8List(width * height * 4);
  for (final band in bands) {
    final start = (band.from * width).round();
    final end = (band.to * width).round();
    for (var y = 0; y < height; y++) {
      for (var x = start; x < end; x++) {
        final i = (y * width + x) * 4;
        pixels[i] = (band.color >> 16) & 0xFF;
        pixels[i + 1] = (band.color >> 8) & 0xFF;
        pixels[i + 2] = band.color & 0xFF;
        pixels[i + 3] = 0xFF;
      }
    }
  }
  final buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
  final descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: width,
    height: height,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final codec = await descriptor.instantiateCodec();
  final frame = await codec.getNextFrame();
  codec.dispose();
  descriptor.dispose();
  return frame.image;
}
