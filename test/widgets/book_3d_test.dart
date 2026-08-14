import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/widgets/book3d/book_3d.dart';
import 'package:paperfold/widgets/book3d/book_geometry.dart';
import 'package:paperfold/widgets/book3d/book_model.dart';

const _materials = BookMaterials(
  cloth: Color(0xFF7B2233),
  foil: Color(0xFFE7C87A),
);

/// Roughly the middle of the book, for asking which way is "out".
V3 _centre(BookGeometry g) => V3(g.thickness / 2, g.height / 2, g.depth / 2);

double _dot(V3 a, V3 b) => a.x * b.x + a.y * b.y + a.z * b.z;

void main() {
  // Winding is the one mistake in this model that does not look like a
  // mistake. A face wound the wrong way has its normal pointing into the book,
  // gets culled as a back face, and simply is not drawn - so the symptom is a
  // missing page block, which reads as a painting bug. Both the head and the
  // tail of the block were wound backwards on the first build and neither was
  // visible in the code.
  test('every facet of a closed book faces outwards', () {
    const geometry = BookGeometry();
    final model = BookModel(geometry: geometry);
    final centre = _centre(geometry);

    for (final facet in model.facets()) {
      final normal = BookModel.normalOf(facet.face);
      // From the middle of the book out to the middle of this face.
      final mid = facet.face.corners.reduce((a, b) => a + b) * 0.25;
      final outward = mid - centre;

      // The pastedown is the inside of a board. On a closed book it faces the
      // page block, so it is correctly wound pointing inward and correctly
      // culled - it only comes into view once the cover swings.
      if (facet.surface == Surface.pastedown) {
        expect(
          _dot(normal, outward),
          lessThan(0),
          reason: 'the pastedown should face into the book while it is shut',
        );
        continue;
      }

      expect(
        _dot(normal, outward),
        greaterThan(0),
        reason: 'a ${facet.surface.name} facet is wound inside out, so it '
            'will be culled and never drawn',
      );
    }
  });

  test('the boards overhang the page block on all three free edges', () {
    const g = BookGeometry();
    final block = BookModel(geometry: g)
        .facets()
        .where((facet) => facet.surface == Surface.pageBlock)
        .expand((facet) => facet.face.corners);

    // The square is what makes a hardback read as one: every leaf edge sits
    // inside the boards at head, tail and fore-edge.
    expect(block.map((p) => p.y).reduce(math.min), greaterThanOrEqualTo(g.square - 0.01));
    expect(block.map((p) => p.y).reduce(math.max),
        lessThanOrEqualTo(g.height - g.square + 0.01));
    expect(block.map((p) => p.z).reduce(math.max),
        lessThanOrEqualTo(g.depth - g.square + 0.01));
    // And between the two boards across the thickness.
    expect(block.map((p) => p.x).reduce(math.min),
        greaterThanOrEqualTo(g.boardThickness - 0.01));
    expect(block.map((p) => p.x).reduce(math.max),
        lessThanOrEqualTo(g.thickness - g.boardThickness + 0.01));
  });

  test('the spine is rounded, not flat', () {
    const g = BookGeometry();
    final spine = BookModel(geometry: g)
        .facets()
        .where((facet) => facet.surface == Surface.spine)
        .expand((facet) => facet.face.corners);

    // The middle of the spine stands proud of its joints.
    final nearest = spine.map((p) => p.z).reduce(math.min);
    expect(nearest, lessThan(-g.spineBulge * 0.9),
        reason: 'the spine did not round');

    // And the light travels around it rather than stepping: no two adjacent
    // strips are lit the same, and the range across them is real.
    final shades = BookModel(geometry: g)
        .facets()
        .where((facet) => facet.surface == Surface.spine)
        .map((facet) => facet.shade)
        .toList();
    expect(shades.toSet().length, greaterThan(4));
    expect(shades.reduce(math.max) - shades.reduce(math.min),
        greaterThan(0.08));
  });

  test('opening swings the front board and leaves the rest alone', () {
    const g = BookGeometry();
    final closed = BookModel(geometry: g, openAmount: 0);
    final open = BookModel(geometry: g, openAmount: 1);

    V3 foreEdgeOfCover(BookModel model) => model
        .facets()
        .firstWhere((facet) => facet.surface == Surface.frontCover)
        .face
        .c;

    // The cover's outer corner travels a long way.
    final from = foreEdgeOfCover(closed);
    final to = foreEdgeOfCover(open);
    final travelled = math.sqrt(
      math.pow(to.x - from.x, 2) + math.pow(to.z - from.z, 2),
    );
    expect(travelled, greaterThan(g.depth),
        reason: 'the cover barely moved, so the book does not read as opening');

    // The hinge itself does not move: a cover that opens by sliding is a lid.
    V3 hingeOfCover(BookModel model) => model
        .facets()
        .firstWhere((facet) => facet.surface == Surface.frontCover)
        .face
        .a;
    final hingeClosed = hingeOfCover(closed);
    final hingeOpen = hingeOfCover(open);
    expect((hingeOpen.x - hingeClosed.x).abs(), lessThan(0.01));
    expect((hingeOpen.z - hingeClosed.z).abs(), lessThan(0.01));

    // The back board stays where it was.
    V3 backCorner(BookModel model) => model
        .facets()
        .firstWhere((facet) => facet.surface == Surface.backCover)
        .face
        .a;
    expect(backCorner(open).x, backCorner(closed).x);
    expect(backCorner(open).z, backCorner(closed).z);
  });

  test('a closed book shows one page; an open one fans several', () {
    const g = BookGeometry();
    int leaves(double open) => BookModel(geometry: g, openAmount: open)
        .facets()
        .where((facet) => facet.surface == Surface.page)
        .length;

    // Closed, the only page face is the top of the block - the recto of the
    // first leaf, sitting under the board. Opening lifts more off it.
    expect(leaves(0), 1);
    expect(leaves(1), greaterThan(3));

    // They fan: no two are at the same angle, so the block opens rather than
    // the whole stack lifting as one slab.
    final fanned = BookModel(geometry: g, openAmount: 0.6)
        .facets()
        .where((facet) => facet.surface == Surface.page)
        .map((facet) => facet.face.b.x.toStringAsFixed(3))
        .toSet();
    expect(fanned.length, greaterThan(2));
  });

  test('the book box is stable across the whole opening', () {
    // A box that grew mid-animation would make the book jump in its row.
    const g = BookGeometry();
    const camera = BookCamera(scale: 0.8);
    final size = Book3D.sizeFor(g, camera, reserveOpenSpace: true);

    for (var step = 0; step <= 10; step++) {
      final model = BookModel(geometry: g, openAmount: step / 10);
      for (final facet in model.facets()) {
        for (final corner in facet.face.corners) {
          final point = camera.project(corner);
          expect(point.dx.abs(), lessThanOrEqualTo(size.width + 1));
          expect(point.dy.abs(), lessThanOrEqualTo(size.height + 1));
        }
      }
    }
  });

  testWidgets('the book paints, and grows with its geometry', (tester) async {
    Future<Size> render(BookGeometry geometry) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Book3D(
                geometry: geometry,
                camera: const BookCamera(scale: 0.7),
                materials: _materials,
                title: 'Piranesi',
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      return tester.getSize(find.byType(Book3D));
    }

    final ordinary = await render(const BookGeometry());
    final thick = await render(const BookGeometry(thickness: 60));
    final tall = await render(const BookGeometry(height: 300));

    expect(thick.width, greaterThan(ordinary.width));
    expect(tall.height, greaterThan(ordinary.height));
  });
}
