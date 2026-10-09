import 'package:material_ui/material_ui.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/enums/book_binding.dart';
import 'package:paperfold/widgets/book_model/book_model.dart';
import 'package:paperfold/widgets/book_model/book_model_scene.dart';

/// A bench for the 3D book model.
///
/// The owner judges this kind of work on hardware, not from a description, so
/// the model has an entry point that starts in under a second and needs no
/// database, no library and no reader.
class BookModelDemoApp extends StatelessWidget {
  const BookModelDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Paperfold book model',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: PaperfoldTokens.colorScheme(Brightness.light),
        fontFamily: PaperfoldTypeTokens.journalFamily,
      ),
      darkTheme: ThemeData(
        colorScheme: PaperfoldTokens.colorScheme(Brightness.dark),
        fontFamily: PaperfoldTypeTokens.journalFamily,
      ),
      home: const BookModelDemoPage(),
    );
  }
}

class BookModelDemoPage extends StatefulWidget {
  const BookModelDemoPage({super.key});

  @override
  State<BookModelDemoPage> createState() => _BookModelDemoPageState();
}

class _BookModelDemoPageState extends State<BookModelDemoPage> {
  final BookModelController _controller = BookModelController();
  BookBinding _binding = BookBinding.hardback;
  double _yaw = 0.38;
  double _pitch = -0.26;
  bool _dark = false;
  bool _driven = false;
  double _open = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: BookModel(
                      key: ValueKey('${_binding.code}-$_driven'),
                      title: 'The Wind in the Willows',
                      author: 'Kenneth Grahame',
                      blurb: 'Mole, Rat, Badger and the incorrigible Toad of '
                          'Toad Hall take to the river bank, the open road and '
                          'the Wild Wood.',
                      binding: _binding,
                      stableId: 'demo-book',
                      controller: _controller,
                      open: _driven ? _open : null,
                      camera: BookCamera(yaw: _yaw, pitch: _pitch),
                      semanticLabel: 'The Wind in the Willows, a demonstration',
                    ),
                  ),
                ),
              ),
              _controls(scheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controls(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<BookBinding>(
            segments: const [
              ButtonSegment(
                  value: BookBinding.hardback, label: Text('Hardback')),
              ButtonSegment(
                  value: BookBinding.softback, label: Text('Softback')),
            ],
            selected: {_binding},
            showSelectedIcon: false,
            onSelectionChanged: (value) =>
                setState(() => _binding = value.first),
          ),
          Row(
            children: [
              Expanded(
                child: SwitchListTile(
                  dense: true,
                  title: const Text('Night'),
                  value: _dark,
                  onChanged: (value) => setState(() => _dark = value),
                ),
              ),
              Expanded(
                child: SwitchListTile(
                  dense: true,
                  title: const Text('Scrub'),
                  value: _driven,
                  onChanged: (value) => setState(() => _driven = value),
                ),
              ),
            ],
          ),
          if (_driven)
            _slider('Open', _open, 0, 1, (v) => setState(() => _open = v))
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FilledButton(
                  onPressed: _controller.open,
                  child: const Text('Open'),
                ),
                FilledButton.tonal(
                  onPressed: _controller.close,
                  child: const Text('Close'),
                ),
                OutlinedButton(
                  onPressed: _controller.turnOver,
                  child: const Text('Turn over'),
                ),
              ],
            ),
          _slider('Yaw', _yaw, -1.4, 3.1, (v) => setState(() => _yaw = v)),
          _slider(
              'Pitch', _pitch, -0.7, 0.3, (v) => setState(() => _pitch = v)),
        ],
      ),
    );
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(width: 54, child: Text(label)),
        Expanded(
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
        SizedBox(width: 48, child: Text(value.toStringAsFixed(2))),
      ],
    );
  }
}
