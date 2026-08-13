// Development entry point for the cold-start opening sequence.
//
// This does not start the database, local reader server, or WebView.
//
//   flutter run -t lib/dev_opening_main.dart
//   flutter run -t lib/dev_opening_main.dart --profile

import 'package:flutter/material.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/page/opening/opening_sequence.dart';

void main() {
  runApp(const OpeningSequenceDemoApp());
}

class OpeningSequenceDemoApp extends StatelessWidget {
  const OpeningSequenceDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Paperfold opening sequence',
      home: _OpeningSequenceDemo(),
    );
  }
}

class _OpeningSequenceDemo extends StatefulWidget {
  const _OpeningSequenceDemo();

  @override
  State<_OpeningSequenceDemo> createState() => _OpeningSequenceDemoState();
}

class _OpeningSequenceDemoState extends State<_OpeningSequenceDemo> {
  int _run = 0;
  bool _finished = false;

  void _replay() {
    setState(() {
      _run += 1;
      _finished = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return OpeningSequence(
      key: ValueKey(_run),
      onFinished: () {
        if (mounted) {
          setState(() => _finished = true);
        }
      },
      child: _PreviewHome(
        canReplay: _finished,
        onReplay: _replay,
      ),
    );
  }
}

class _PreviewHome extends StatelessWidget {
  const _PreviewHome({
    required this.canReplay,
    required this.onReplay,
  });

  final bool canReplay;
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PaperfoldTokens.light.ground,
      appBar: AppBar(
        backgroundColor: PaperfoldTokens.light.ground,
        foregroundColor: PaperfoldTokens.light.ink,
        title: const Text(
          'Paperfold',
          style: TextStyle(fontFamily: 'SourceHanSerif'),
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () {},
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_stories_outlined,
                color: PaperfoldTokens.light.accent,
                size: 42.0,
              ),
              const SizedBox(height: 18.0),
              Text(
                'Your reading journal is ready.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: PaperfoldTokens.light.ink,
                  fontFamily: 'SourceHanSerif',
                  fontSize: 22.0,
                ),
              ),
              const SizedBox(height: 28.0),
              FilledButton.icon(
                onPressed: canReplay ? onReplay : null,
                icon: const Icon(Icons.replay),
                label: const Text('Replay opening'),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.edit_note_outlined),
            selectedIcon: Icon(Icons.edit_note),
            label: 'Journal',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
