import 'package:paperfold/config/paperfold_system.dart';

import 'package:paperfold/enums/excerpt_share_template.dart';
import 'package:paperfold/models/font_model.dart';
import 'package:material_ui/material_ui.dart';

class ExcerptShareCard extends StatelessWidget {
  final String bookTitle;
  final String author;
  final String excerpt;
  final String? chapter;
  final ExcerptShareTemplateEnum template;
  final FontModel font;
  final Color textColor;
  final Color backgroundColor;
  final String? backgroundImage;

  const ExcerptShareCard({
    super.key,
    required this.bookTitle,
    required this.author,
    required this.excerpt,
    this.chapter,
    required this.template,
    required this.font,
    required this.textColor,
    required this.backgroundColor,
    this.backgroundImage,
  });

  @override
  Widget build(BuildContext context) {
    Widget child = switch (template) {
      ExcerptShareTemplateEnum.simpleTemplate => _buildSimpleTemplate(),
      ExcerptShareTemplateEnum.elegantTemplate => _buildElegantTemplate(),
      ExcerptShareTemplateEnum.defaultTemplate => _buildDefaultTemplate(),
    };

    return RepaintBoundary(
      child: Container(
        width: 500,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: PaperfoldShape.controlRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: PaperfoldShape.controlRadius,
          child: child,
        ),
      ),
    );
  }

  TextStyle _getTextStyle() {
    FontWeight weight = FontWeight.normal;
    final path = font.path.split('/').last;
    switch (font.name) {
      case 'system':
        return TextStyle(color: textColor, fontWeight: weight);
      default:
        if (path.contains('SourceHanSerifSC')) {
          return TextStyle(
            color: textColor,
            fontWeight: weight,
            fontFamily: 'SourceHanSerif',
          );
        } else {
          return TextStyle(
            color: textColor,
            fontWeight: weight,
            fontFamily: path,
          );
        }
    }
  }

  Widget _getPaperfoldLogo({double fontSize = 12, Color? color}) {
    color ??= textColor;
    return Text(
      'Paperfold',
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w100,
        color: color,
      ),
    );
  }

  Widget _getContent() {
    return Text(
      excerpt,
      style: _getTextStyle().copyWith(fontSize: 18, height: 2),
    );
  }

  Widget _getTitleText({
    TextAlign textAlign = TextAlign.start,
    TextDirection textDirection = TextDirection.ltr,
    double fontSize = 20,
    Color? color,
  }) {
    color ??= textColor;
    return Text(
      bookTitle,
      textAlign: textAlign,
      textDirection: textDirection,
      style: _getTextStyle().copyWith(
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        color: color,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _getChapterText({
    String leading = '—— ',
    double textSize = 14,
  }) {
    if (chapter == null || chapter!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Text(
      '$leading$chapter',
      style: _getTextStyle().copyWith(fontSize: textSize),
    );
  }

  Widget _getAuthorText({
    double textSize = 14,
    Color? color,
  }) {
    color ??= textColor;
    return Text(
      author,
      style: _getTextStyle().copyWith(fontSize: textSize, color: color),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildDefaultTemplate() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        image: backgroundImage != null
            ? DecorationImage(
                image: AssetImage(backgroundImage!),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  backgroundColor.withAlpha(100),
                  BlendMode.dstATop,
                ),
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _getContent(),
          Row(children: [const Spacer(), _getChapterText()]),
          const SizedBox(height: 16),
          Divider(thickness: 1, color: textColor.withAlpha(80)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _getTitleText(),
                    const SizedBox(height: 4),
                    _getAuthorText(),
                  ],
                ),
              ),
              _getPaperfoldLogo(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleTemplate() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: backgroundColor,
        image: backgroundImage != null
            ? DecorationImage(
                image: AssetImage(backgroundImage!),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  backgroundColor.withAlpha(100),
                  BlendMode.dstATop,
                ),
              )
            : null,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _getTitleText()),
              const SizedBox(width: 16),
              _getChapterText(),
              const SizedBox(width: 16),
              _getAuthorText(),
            ],
          ),
          const SizedBox(height: 20),
          Stack(
            children: [
              Positioned(
                top: -15,
                left: 0,
                child: Icon(
                  Icons.format_quote,
                  size: 64,
                  color: textColor.withAlpha(40),
                ),
              ),
              _getContent(),
              Positioned(
                bottom: 0,
                right: 0,
                child: Transform.rotate(
                  angle: 3.14,
                  child: Icon(
                    Icons.format_quote,
                    size: 64,
                    color: textColor.withAlpha(40),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Column(
            children: [
              Row(children: [Spacer(), _getPaperfoldLogo()]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildElegantTemplate() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: backgroundColor,
            image: backgroundImage != null
                ? DecorationImage(
                    image: AssetImage(backgroundImage!),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      backgroundColor.withAlpha(200),
                      BlendMode.dstATop,
                    ),
                  )
                : null,
          ),
          child: Column(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _getTitleText(
                    fontSize: 38,
                    color: backgroundImage != null ? Colors.white : null,
                  ),
                  const SizedBox(height: 8),
                  _getAuthorText(
                    textSize: 25,
                    color: backgroundImage != null ? Colors.white : null,
                  ),
                ],
              ),
              Row(
                children: [
                  const Spacer(),
                  _getPaperfoldLogo(
                    fontSize: 16,
                    color: backgroundImage != null ? Colors.white : null,
                  ),
                ],
              ),
            ],
          ),
        ),
        Divider(color: textColor.withAlpha(40), height: 1),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              _getContent(),
              const SizedBox(height: 16),
              _getChapterText(textSize: 20),
            ],
          ),
        ),
      ],
    );
  }

}
