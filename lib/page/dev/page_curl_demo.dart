import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:paperfold/config/paperfold_motion.dart';
import 'package:paperfold/widgets/page_curl/page_curl.dart';

void main() {
  runApp(const PageCurlDemoApp());
}

class PageCurlDemoApp extends StatelessWidget {
  const PageCurlDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF304A8A),
        ),
        sliderTheme: const SliderThemeData(
          showValueIndicator: ShowValueIndicator.onDrag,
        ),
        useMaterial3: true,
      ),
      home: const PageCurlDemoPage(),
    );
  }
}

/// Direct harness for the reusable page-curl widget.
///
/// Run it with:
/// `flutter run -t lib/dev_curl_main.dart`
class PageCurlDemoPage extends StatefulWidget {
  const PageCurlDemoPage({super.key});

  @override
  State<PageCurlDemoPage> createState() => _PageCurlDemoPageState();
}

class _PageCurlDemoPageState extends State<PageCurlDemoPage> {
  final PageCurlController _controller = PageCurlController();

  double _radius = 72.0;
  double _shadow = 0.78;
  TextDirection _direction = TextDirection.ltr;
  PageCurlEffect _effect = PageCurlEffect.curl;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    unawaited(PageCurl.warmUp());
  }

  Future<void> _playTimedOpen() async {
    _controller.jumpTo(0.0);
    // The turn the application actually runs, so the lab and the reader cannot
    // drift apart on timing.
    await _controller.animate(
      duration: PaperfoldMotion.pageTurn,
      curve: PaperfoldMotion.turn,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Page curl lab'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760.0;
            final preview = _buildPreview();
            final controls = _buildControls(context);

            if (compact) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20.0, 12.0, 20.0, 32.0),
                child: Column(
                  children: [
                    preview,
                    const SizedBox(height: 28.0),
                    controls,
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 64.0,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: Center(child: preview)),
                    const SizedBox(width: 48.0),
                    SizedBox(width: 340.0, child: controls),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360.0),
      child: AspectRatio(
        aspectRatio: 0.72,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18.0),
            boxShadow: const [
              BoxShadow(
                color: Color(0x330E1B3D),
                blurRadius: 28.0,
                offset: Offset(0.0, 16.0),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18.0),
            child: WidgetPageCurl(
              controller: _controller,
              front: const _NightAtlasPage(),
              back: const _FieldNotesPage(),
              textDirection: _direction,
              radius: _radius,
              shadow: _shadow,
              effect: _effect,
              reduceMotion: _reduceMotion,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Drag the page edge',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6.0),
            Text(
              'Release before halfway to spring back. Release after halfway to complete the turn.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24.0),
            // No longer a length. The radius of the roll is set by how much
            // paper has been taken up into it; this is how stiff that paper is,
            // so a low value rolls tight like a leaf and a high one rolls loose
            // and wide like a cover board.
            Text('Stiffness  ${_radius.round()}'),
            Slider(
              value: _radius,
              min: 40.0,
              max: 120.0,
              divisions: 20,
              label: '${_radius.round()}',
              onChanged: (value) => setState(() => _radius = value),
            ),
            const SizedBox(height: 8.0),
            Text('Shadow  ${_shadow.toStringAsFixed(2)}'),
            Slider(
              value: _shadow,
              divisions: 20,
              label: _shadow.toStringAsFixed(2),
              onChanged: (value) => setState(() => _shadow = value),
            ),
            const SizedBox(height: 16.0),
            Text('Reading direction',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8.0),
            SegmentedButton<TextDirection>(
              segments: const [
                ButtonSegment(
                  value: TextDirection.ltr,
                  label: Text('LTR'),
                  icon: Icon(Icons.arrow_back),
                ),
                ButtonSegment(
                  value: TextDirection.rtl,
                  label: Text('RTL'),
                  icon: Icon(Icons.arrow_forward),
                ),
              ],
              selected: {_direction},
              onSelectionChanged: (selection) {
                setState(() => _direction = selection.single);
                _controller.jumpTo(0.0);
              },
            ),
            const SizedBox(height: 16.0),
            Text('Renderer', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8.0),
            SegmentedButton<PageCurlEffect>(
              segments: const [
                ButtonSegment(
                  value: PageCurlEffect.curl,
                  label: Text('Curl'),
                ),
                ButtonSegment(
                  value: PageCurlEffect.fold,
                  label: Text('Fold'),
                ),
              ],
              selected: {_effect},
              onSelectionChanged: (selection) {
                setState(() => _effect = selection.single);
                _controller.jumpTo(0.0);
              },
            ),
            const SizedBox(height: 8.0),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Accessibility cross-fade'),
              subtitle: const Text(
                  'Simulates the caller-provided reduce-motion flag.'),
              value: _reduceMotion,
              onChanged: (value) {
                setState(() => _reduceMotion = value);
                _controller.jumpTo(0.0);
              },
            ),
            const SizedBox(height: 16.0),
            FilledButton.icon(
              onPressed: _playTimedOpen,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Run timed cover open'),
            ),
            const SizedBox(height: 8.0),
            TextButton(
              onPressed: () => _controller.jumpTo(0.0),
              child: const Text('Reset'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NightAtlasPage extends StatelessWidget {
  const _NightAtlasPage();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF243D7A),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30.0, 34.0, 30.0, 30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.nights_stay_outlined,
              size: 42.0,
              color: Color(0xFFFFCF70),
            ),
            const Spacer(),
            Text(
              'THE NIGHT\nATLAS',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 0.94,
                    letterSpacing: -1.4,
                  ),
            ),
            const SizedBox(height: 18.0),
            const SizedBox(
              width: 72.0,
              child: Divider(color: Color(0xFFFFCF70), thickness: 2.0),
            ),
            const SizedBox(height: 12.0),
            const Text(
              'Mira Solberg',
              style: TextStyle(
                color: Color(0xFFDCE5FF),
                fontSize: 16.0,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldNotesPage extends StatelessWidget {
  const _FieldNotesPage();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFE8F0D9),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30.0, 32.0, 30.0, 28.0),
        child: DefaultTextStyle(
          style: const TextStyle(
            color: Color(0xFF203728),
            fontSize: 16.0,
            height: 1.55,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.eco_outlined, color: Color(0xFF2E6845)),
                  SizedBox(width: 10.0),
                  Text(
                    'FIELD NOTES',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28.0),
              Text(
                '11 AUGUST',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: const Color(0xFF467354),
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 10.0),
              Text(
                'The path opened after the rain.',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFF183224),
                      fontWeight: FontWeight.w700,
                      height: 1.12,
                    ),
              ),
              const SizedBox(height: 22.0),
              const Text(
                'A thin line of light crossed the moss. I marked the place where the river bends north, then read until dusk.',
              ),
              const Spacer(),
              const Row(
                children: [
                  Icon(Icons.bookmark_outline, color: Color(0xFF2E6845)),
                  SizedBox(width: 8.0),
                  Text(
                    'PAGE 42',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
