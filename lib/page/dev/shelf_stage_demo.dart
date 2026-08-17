import 'package:flutter/material.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/enums/book_binding.dart';
import 'package:paperfold/widgets/bookshelf/shelf_stage.dart';

/// A bench for the shelf.
///
/// The owner judges this kind of work on hardware, not from a description, so
/// the shelf has an entry point that starts in under a second and needs no
/// database, no library and no reader.
class ShelfStageDemoApp extends StatelessWidget {
  const ShelfStageDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Paperfold shelf',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: PaperfoldTokens.colorScheme(Brightness.light),
        fontFamily: PaperfoldTypeTokens.journalFamily,
      ),
      darkTheme: ThemeData(
        colorScheme: PaperfoldTokens.colorScheme(Brightness.dark),
        fontFamily: PaperfoldTypeTokens.journalFamily,
      ),
      home: const ShelfStageDemoPage(),
    );
  }
}

/// A row with one of every case the opening has to handle: a book nobody has
/// started, three at different points through, and one that is finished.
const List<ShelfBook> _shelf = [
  ShelfBook(
    id: 'demo-willows',
    title: 'The Wind in the Willows',
    author: 'Kenneth Grahame',
    blurb: 'Mole, Rat, Badger and the incorrigible Toad of Toad Hall take to '
        'the river bank, the open road and the Wild Wood.',
    binding: BookBinding.hardback,
  ),
  ShelfBook(
    id: 'demo-moonstone',
    title: 'The Moonstone',
    author: 'Wilkie Collins',
    binding: BookBinding.hardback,
    progress: 0.46,
  ),
  ShelfBook(
    id: 'demo-pnp',
    title: 'Pride and Prejudice',
    author: 'Jane Austen',
    binding: BookBinding.hardback,
    progress: 0.18,
  ),
  ShelfBook(
    id: 'demo-dune',
    title: 'Dune',
    author: 'Frank Herbert',
    blurb: 'A desert planet, a spice worth more than empires, and a boy who '
        'is told he is the one who was promised.',
    binding: BookBinding.softback,
    progress: 0.78,
  ),
  ShelfBook(
    id: 'demo-gatsby',
    title: 'The Great Gatsby',
    author: 'F. Scott Fitzgerald',
    binding: BookBinding.softback,
    progress: 1,
    finished: true,
  ),
  ShelfBook(
    id: 'demo-odyssey',
    title: 'The Odyssey',
    author: 'Homer',
    binding: BookBinding.hardback,
  ),
];

class ShelfStageDemoPage extends StatefulWidget {
  const ShelfStageDemoPage({super.key});

  @override
  State<ShelfStageDemoPage> createState() => _ShelfStageDemoPageState();
}

class _ShelfStageDemoPageState extends State<ShelfStageDemoPage> {
  final GlobalKey<ShelfStageState> _stage = GlobalKey<ShelfStageState>();
  bool _dark = true;
  String? _log;

  @override
  Widget build(BuildContext context) {
    final scheme = PaperfoldTokens.colorScheme(
      _dark ? Brightness.dark : Brightness.light,
    );
    return Theme(
      data: ThemeData(
        colorScheme: scheme,
        fontFamily: PaperfoldTypeTokens.journalFamily,
      ),
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ShelfStage(
                  key: _stage,
                  books: _shelf,
                  pickUpHint: 'Take it down',
                  openHint: 'Open it',
                  onIndexChanged: (index) =>
                      setState(() => _log = 'shelf: ${_shelf[index].title}'),
                  onPickedUp: (book) =>
                      setState(() => _log = 'held: ${book.title}'),
                  onReturned: (book) =>
                      setState(() => _log = 'back on the shelf: ${book.title}'),
                  onOpen: _handleOpen,
                  optionsBuilder: _options,
                ),
              ),
              _controls(scheme),
            ],
          ),
        ),
      ),
    );
  }

  void _handleOpen(ShelfBook book) {
    setState(() => _log = 'opened: ${book.title}');
    // The bench has no reader to hand the book to, so it puts it back.
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _stage.currentState?.reset();
    });
  }

  Widget _options(BuildContext context, ShelfBook book) {
    final scheme = Theme.of(context).colorScheme;
    final where = book.finished
        ? 'finished'
        : book.progress == 0
            ? 'not started'
            : '${(book.progress * 100).round()}% through';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            book.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 2),
          Text(
            '${book.author}  ·  $where',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton.filledTonal(
                onPressed: () {},
                icon: const Icon(Icons.tune),
                tooltip: 'Customise',
              ),
              IconButton.filledTonal(
                onPressed: () {},
                icon: const Icon(Icons.info_outline),
                tooltip: 'Details',
              ),
              IconButton.filledTonal(
                onPressed: () {},
                icon: const Icon(Icons.bookmark_border),
                tooltip: 'Shelves',
              ),
              IconButton.filledTonal(
                onPressed: () {},
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Settings',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _controls(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _log ?? 'drag through the shelf, tap to take a book down',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                onPressed: () => _stage.currentState?.pickUp(),
                child: const Text('Take'),
              ),
              TextButton(
                onPressed: () => _stage.currentState?.putBack(),
                child: const Text('Put back'),
              ),
              TextButton(
                onPressed: () => _stage.currentState?.openBook(),
                child: const Text('Open'),
              ),
              IconButton(
                onPressed: () => setState(() => _dark = !_dark),
                icon: Icon(_dark ? Icons.light_mode : Icons.dark_mode),
                tooltip: 'Night',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
