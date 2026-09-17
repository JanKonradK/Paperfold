import 'package:flutter/material.dart';

/// The supplied cover lettering, extracted as a transparent image.
class PaperfoldWordmark extends StatelessWidget {
  const PaperfoldWordmark({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Paperfold',
      image: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: 176,
          height: 40,
          child: ClipRect(
            child: OverflowBox(
              maxWidth: 176,
              maxHeight: 176 / 3,
              child: Image.asset(
                'assets/images/paperfold_wordmark.png',
                width: 176,
                height: 176 / 3,
                color: Theme.of(context).colorScheme.primary,
                colorBlendMode: BlendMode.srcIn,
                excludeFromSemantics: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
