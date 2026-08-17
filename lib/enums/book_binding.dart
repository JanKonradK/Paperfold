/// How a book is bound.
///
/// The two bindings are not two skins on one shape. A hardback is a case: two
/// stiff boards and a spine strip glued to a cloth, with the boards standing
/// proud of the paper on three edges. A softback is one sheet of card wrapped
/// round the block and trimmed flush with it. Every difference in the model
/// follows from that one fact.
enum BookBinding {
  /// A cased book. Boards overhang the page block, the spine is rounded and
  /// hollow, the head and tail carry headbands, and the inside of each board
  /// is covered by an endpaper.
  hardback('hardback'),

  /// A perfect-bound book. The cover is flush with the block, the spine is
  /// flat with two score lines at the joints, and the laminate takes a
  /// highlight. This is the binding for manga, light novels and modern trade
  /// paperbacks.
  softback('softback');

  const BookBinding(this.code);

  /// The stored value. Names are stable; do not rename these.
  final String code;

  static BookBinding fromCode(String? code) {
    return BookBinding.values.firstWhere(
      (binding) => binding.code == code,
      orElse: () => BookBinding.hardback,
    );
  }
}

/// What the reader asked for, which is not the same as what a book gets.
///
/// [automatic] leaves the choice to the metadata. The other two are the
/// reader's own decision and always win.
enum BookBindingChoice {
  automatic('automatic'),
  hardback('hardback'),
  softback('softback');

  const BookBindingChoice(this.code);

  final String code;

  /// The binding this choice forces, or null when the metadata decides.
  BookBinding? get forced => switch (this) {
        BookBindingChoice.automatic => null,
        BookBindingChoice.hardback => BookBinding.hardback,
        BookBindingChoice.softback => BookBinding.softback,
      };

  static BookBindingChoice fromCode(String? code) {
    return BookBindingChoice.values.firstWhere(
      (choice) => choice.code == code,
      orElse: () => BookBindingChoice.automatic,
    );
  }
}
