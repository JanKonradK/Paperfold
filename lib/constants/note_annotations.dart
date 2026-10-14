import 'package:material_ui/material_ui.dart';

class NoteTypeOption {
  final String type;
  final IconData icon;

  const NoteTypeOption({
    required this.type,
    required this.icon,
  });
}

const List<String> notesColors = [
  '66CCFF',
  'FF0000',
  '00FF00',
  'EB3BFF',
  'FFD700',
];

const List<NoteTypeOption> notesType = [
  NoteTypeOption(
    type: 'highlight',
    icon: Icons.border_color_outlined,
  ),
  NoteTypeOption(
    type: 'underline',
    icon: Icons.format_underline,
  ),
];
