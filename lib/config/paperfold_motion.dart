import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';

/// The timing of everything in Paperfold that moves the way paper moves.
///
/// One place, because a page turn, a cover swinging and a leaf leaving the
/// screen are the same gesture at three sizes. When they disagree about how
/// fast paper travels, the application stops reading as one object.
///
/// The curves are the Material 3 emphasized set. They are not used because they
/// are Material: they are used because their shape is the shape of a sheet
/// let go of by a hand. The stock `easeOutCubic` this replaced starts at full
/// speed, which paper cannot do, and then spends a third of its time creeping
/// the last two per cent, which reads as the animation being tired.
class PaperfoldMotion {
  const PaperfoldMotion._();

  /// A leaf started from rest and stopped when it lands.
  ///
  /// Still at the beginning, quick through the middle, and arrived. Use it for
  /// any turn the reader starts with a tap.
  static const Curve turn = Cubic(0.2, 0.0, 0.0, 1.0);

  /// A movement that was already going when the clock took it over.
  ///
  /// No acceleration at the head, because the hand supplied that. Use it after
  /// a drag, and for anything catching up to a place it is already headed.
  static const Curve settle = Cubic(0.05, 0.7, 0.1, 1.0);

  /// Something on its way out, which never has to arrive gently.
  static const Curve depart = Cubic(0.3, 0.0, 0.8, 0.15);

  /// A page turned in the reader.
  ///
  /// Short. The reader is going to do this several hundred times in an evening,
  /// and an animation seen that often is measured by how soon it is over.
  static const Duration pageTurn = Duration(milliseconds: 380);

  /// A cover opening. Slower than a page: a board is a heavier thing.
  static const Duration coverTurn = Duration(milliseconds: 560);

  /// The first page growing into the application on a cold start.
  static const Duration pageLeave = Duration(milliseconds: 520);

  /// The first leaf of a book being turned off the reader's screen.
  static const Duration leafLift = Duration(milliseconds: 460);

  /// Where a released page goes.
  ///
  /// Critically damped on purpose. An underdamped spring overshoots, and the
  /// turn is clamped to its two ends, so every millisecond of overshoot is a
  /// frame drawn with the picture standing still. Paper hitting the other side
  /// of a book does not bounce either.
  static final SpringDescription release = SpringDescription.withDampingRatio(
    mass: 1.0,
    stiffness: 620.0,
    ratio: 1.0,
  );

  /// When to stop simulating.
  ///
  /// Looser than the default, in the units of the turn itself, where 1 is the
  /// whole page. The last thousandth of a page is under a pixel wide and the
  /// roll has already tapered away by then, so the frames spent reaching it
  /// show nothing.
  static const Tolerance releaseTolerance = Tolerance(
    distance: 0.0015,
    velocity: 0.02,
  );

  /// The speed, in pages per second, at which a flick decides the turn.
  ///
  /// Below it, the turn goes wherever the page was left. Above it, the page
  /// goes the way it was thrown even if it was let go of early, which is the
  /// difference between a reader who is turning pages and a reader who is
  /// fighting a threshold.
  static const double flickVelocity = 1.1;
}
