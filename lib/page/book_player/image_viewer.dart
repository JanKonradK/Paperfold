import 'dart:convert';
import 'dart:typed_data';

import 'package:paperfold/utils/save_img.dart';
import 'package:paperfold/utils/get_path/get_temp_dir.dart';
import 'package:paperfold/utils/log/common.dart';
import 'package:paperfold/utils/save_image_to_path.dart';
import 'package:paperfold/utils/share_file.dart';
import 'package:flutter/gestures.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

class ImageViewer extends StatefulWidget {
  final String image;
  final String bookName;

  const ImageViewer({
    super.key,
    required this.image,
    required this.bookName,
  });

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer> {
  late PhotoViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PhotoViewController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleScroll(PointerScrollEvent event) {
    final double scrollDelta = event.scrollDelta.dy;
    final double currentScale = _controller.scale ?? 1.0;

    // Adjust sensitivity: negative delta = zoom in, positive = zoom out
    final double scaleFactor = scrollDelta > 0 ? 0.95 : 1.05;
    final double newScale = currentScale * scaleFactor;

    // Apply the new scale with constraints
    _controller.scale = newScale;
  }

  @override
  Widget build(BuildContext context) {
    Uint8List? imageBytes;
    String? imgType;

    try {
      final List<String> parts = widget.image.split(',');
      String base64 = parts[1];
      imageBytes = base64Decode(base64);
      imgType = parts[0].split('/')[1].split(';')[0];
    } catch (e) {
      AnxLog.severe('Error decoding image: $e');
      return Center(child: Text(L10n.of(context).commonError));
    }

    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          _handleScroll(event);
        }
      },
      child: Stack(
        children: [
          PhotoView(
            imageProvider: MemoryImage(imageBytes),
            controller: _controller,
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            loadingBuilder: (context, event) => const Center(
              child: CircularProgressIndicator(),
            ),
            minScale: PhotoViewComputedScale.contained * 0.8,
            maxScale: PhotoViewComputedScale.covered * 3,
          ),
          Positioned.fill(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        IconButton(
                          // Icon-only, over a photograph. Without a name a
                          // screen reader announced three unlabelled buttons.
                          tooltip: L10n.of(context).commonClose,
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          tooltip: L10n.of(context).commonDownload,
                          onPressed: () {
                            SaveImg.downloadImg(
                                imageBytes!, imgType!, widget.bookName);
                          },
                          icon:
                              const Icon(Icons.download, color: Colors.white),
                        ),
                        IconButton(
                          tooltip: L10n.of(context).readingPageShareShare,
                          onPressed: () async {
                            final path = await saveB64ImageToPath(
                              widget.image,
                              (await getAnxTempDir()).path,
                              "Paperfold_${widget.bookName}",
                            );

                            await shareFile(filePath: path);
                          },
                          icon: const Icon(Icons.share, color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
