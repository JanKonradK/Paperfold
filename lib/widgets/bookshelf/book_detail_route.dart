import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:paperfold/config/paperfold_motion.dart';
import 'package:paperfold/config/paperfold_visual_policy.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/page/book_detail.dart';

Duration bookDetailDuration(BuildContext context) {
  if (MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.highContrastOf(context) ||
      PaperfoldVisualPolicy.batterySaver.value)
    return Duration.zero;
  if (!PaperfoldVisualPolicy.motionAllowed(context)) {
    return MediaQuery.accessibleNavigationOf(context)
        ? PaperfoldMotion.tick
        : Duration.zero;
  }
  return PaperfoldMotion.of(context, PaperfoldMotion.move);
}

PageRouteBuilder<void> bookDetailRoute(
  BuildContext context,
  Book book, {
  bool wishlist = false,
  String? heroId,
}) => PageRouteBuilder<void>(
  settings: RouteSettings(name: '/book/${book.id}'),
  transitionDuration: bookDetailDuration(context),
  reverseTransitionDuration: bookDetailDuration(context),
  pageBuilder: (_, _, _) =>
      BookDetail(book: book, wishlist: wishlist, heroId: heroId),
  transitionsBuilder: (_, animation, _, child) =>
      FadeTransition(opacity: animation, child: child),
);

/// The host stays axis aligned. Only the object inside the flight turns.
class BookDetailHero extends StatelessWidget {
  const BookDetailHero({
    super.key,
    required this.id,
    required this.child,
    required this.cover,
    this.spine = false,
  });
  final String id;
  final Widget child, cover;
  final bool spine;
  @override
  Widget build(BuildContext context) => Hero(
    tag: 'book-detail-$id',
    flightShuttleBuilder: (_, animation, direction, from, to) {
      final source =
          (direction == HeroFlightDirection.push ? from : to).widget as Hero;
      final origin = source.child as _BookHeroObject;
      return AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final raw = animation.value;
          final reduced = !PaperfoldVisualPolicy.motionAllowed(context);

          if (reduced || !origin.spine)
            return Opacity(opacity: reduced ? raw : 1, child: origin.cover);
          final first = raw < .4;
          final curve = direction == HeroFlightDirection.push
              ? PaperfoldMotion.turn
              : PaperfoldMotion.depart;
          final angle = first
              ? math.pi / 2 * curve.transform(raw / .4)
              : -math.pi / 2 * (1 - curve.transform((raw - .4) / .6));
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, .001)
              ..rotateY(angle),
            child: first ? origin.child : origin.cover,
          );
        },
      );
    },
    child: _BookHeroObject(spine: spine, cover: cover, child: child),
  );
}

class _BookHeroObject extends StatelessWidget {
  const _BookHeroObject({
    required this.spine,
    required this.cover,
    required this.child,
  });
  final bool spine;
  final Widget cover, child;
  @override
  Widget build(BuildContext context) => child;
}

/// Shares the route clock with the cover flight; no extra controller.
class BookDetailArrival extends StatelessWidget {
  const BookDetailArrival({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null) return child;
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final spatial = PaperfoldVisualPolicy.motionAllowed(context);
        final t = spatial
            ? const Interval(
                .6,
                1,
                curve: PaperfoldMotion.turn,
              ).transform(animation.value)
            : animation.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, spatial ? 8 * (1 - t) : 0),
            child: child,
          ),
        );
      },
    );
  }
}
