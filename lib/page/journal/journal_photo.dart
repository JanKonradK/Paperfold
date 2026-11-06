import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:paperfold/config/paperfold_system.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/utils/get_path/get_base_path.dart';
import 'package:photo_view/photo_view.dart';

class JournalPhoto extends StatelessWidget {
  const JournalPhoto({super.key, required this.path});
  final String path;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: PaperfoldSpace.xs),
    child: Semantics(
      button: true,
      label: L10n.of(context).entryPhoto,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              appBar: AppBar(title: Text(L10n.of(context).entryPhoto)),
              body: PhotoView(
                imageProvider: FileImage(File(getBasePath(path))),
              ),
            ),
          ),
        ),
        child: ClipRRect(
          borderRadius: PaperfoldShape.objectRadius,
          child: Image.file(
            File(getBasePath(path)),
            height: 120,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const SizedBox(
              height: PaperfoldSize.target,
              child: Icon(Icons.broken_image_outlined),
            ),
          ),
        ),
      ),
    ),
  );
}
