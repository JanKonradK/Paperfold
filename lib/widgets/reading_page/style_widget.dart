import 'dart:io';

import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/book_style.dart';
import 'package:paperfold/models/font_model.dart';
import 'package:paperfold/page/reading_page.dart';
import 'package:paperfold/service/book_player/book_player_server.dart';
import 'package:paperfold/service/font.dart';
import 'package:paperfold/utils/font_parser.dart';
import 'package:paperfold/utils/get_path/get_base_path.dart';
import 'package:paperfold/widgets/icon_and_text.dart';
import 'package:paperfold/widgets/reading_page/more_settings/more_settings.dart';
import 'package:paperfold/widgets/reading_page/widget_title.dart';
import 'package:paperfold/dao/theme.dart';
import 'package:paperfold/main.dart';
import 'package:paperfold/models/read_theme.dart';
import 'package:paperfold/page/book_player/epub_player.dart';
import 'package:paperfold/widgets/reading_page/widgets/bgimg_selector.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

/// How a page leaves the screen.
///
/// Slide and fold are drawn by the WebView and stay on its compositor. Curl is
/// drawn by Flutter with the page-curl shader over a captured page, which
/// costs one WebView capture per turn, taken while nothing is animating.
enum PageTurn {
  noAnimation,
  slide,
  fold,
  curl,
  scroll;

  /// Whether Flutter, rather than the WebView, animates this turn.
  bool get isShaderCurl => this == PageTurn.curl;

  String getLabel(BuildContext context) {
    switch (this) {
      case PageTurn.noAnimation:
        return L10n.of(context).noAnimation;
      case PageTurn.slide:
        return L10n.of(context).slide;
      case PageTurn.fold:
        return L10n.of(context).pageTurnFold;
      case PageTurn.curl:
        return L10n.of(context).pageTurnCurl;
      case PageTurn.scroll:
        return L10n.of(context).scroll;
    }
  }

  String getDescription(BuildContext context) {
    switch (this) {
      case PageTurn.noAnimation:
        return L10n.of(context).pageTurnNoneDescription;
      case PageTurn.slide:
        return L10n.of(context).pageTurnSlideDescription;
      case PageTurn.fold:
        return L10n.of(context).pageTurnFoldDescription;
      case PageTurn.curl:
        return L10n.of(context).pageTurnCurlDescription;
      case PageTurn.scroll:
        return L10n.of(context).pageTurnScrollDescription;
    }
  }
}

class StyleWidget extends StatefulWidget {
  const StyleWidget({
    super.key,
    required this.themes,
    required this.epubPlayerKey,
    required this.setCurrentPage,
    required this.hideAppBarAndBottomBar,
  });

  final List<ReadTheme> themes;
  final GlobalKey<EpubPlayerState> epubPlayerKey;
  final Function setCurrentPage;
  final Function hideAppBarAndBottomBar;

  @override
  StyleWidgetState createState() => StyleWidgetState();
}

class StyleWidgetState extends State<StyleWidget> {
  BookStyle bookStyle = Prefs().bookStyle;
  int? currentThemeId = Prefs().readTheme.id;

  @override
  Widget build(BuildContext context) {
    // The shell bounds this panel, so the content scrolls inside it rather
    // than overflowing when the reader raises the system text size.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          widgetTitle(
            context,
            L10n.of(context).readingPageStyle,
            ReadingSettings.theme,
          ),
          sliders(),
          const SizedBox(height: 12),
          fontAndPageTurn(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: themeSelector()),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onPressed: () {
                  widget.setCurrentPage(const BgimgSelector());
                },
                icon: const Icon(Icons.chevron_right),
                iconAlignment: IconAlignment.end,
                label: Text(L10n.of(context).readingPageStyleBackground),
              )
            ],
          ),
        ],
      ),
    );
  }

  /// The faces Paperfold ships. Philosopher carries the content voice and
  /// Source Sans 3 the plain one, both under the SIL Open Font License.
  static final List<FontModel> bundledFonts = [
    FontModel.bundled(
      label: 'Philosopher',
      name: 'Philosopher',
      fileName: 'Philosopher-Regular.ttf',
    ),
    FontModel.bundled(
      label: 'Source Sans 3',
      name: 'SourceSans3',
      fileName: 'SourceSans3-Regular.ttf',
    ),
    FontModel.bundled(
      label: 'Source Han Serif',
      name: 'SourceHanSerif',
      fileName: 'SourceHanSerifSC-Regular.otf',
    ),
  ];

  /// The reader's choices, in the order they are worth reading: the faces that
  /// are here now, then the ones the reader added, then the two actions that
  /// leave this sheet. The actions used to sit first, which put "download" and
  /// "add" above every font the reader could actually pick.
  List<FontModel> fonts() {
    Directory fontDir = getFontDir();
    List<FontModel> fontList = [
      ...bundledFonts,
      FontModel.builtIn(label: L10n.of(context).followBook, name: 'book'),
      FontModel.builtIn(label: L10n.of(context).systemFont, name: 'system'),
    ];
    // name = 'customFont' + index
    for (int i = 0; i < fontDir.listSync().length; i++) {
      File element = fontDir.listSync()[i] as File;
      fontList.add(FontModel(
        label: getFontNameFromFile(element),
        name: 'customFont$i',
        path:
            'http://127.0.0.1:${Server().port}/fonts/${element.path.split(Platform.pathSeparator).last}',
      ));
    }

    fontList.add(FontModel.builtIn(
      label: L10n.of(context).addNewFont,
      name: 'newFont',
    ));

    return fontList;
  }

  Widget fontAndPageTurn() {
    FontModel? font = fonts().firstWhere(
        (element) => element.path == Prefs().font.path,
        orElse: () => Prefs.defaultFont);

    Widget? leadingIcon(String name) {
      if (name == 'newFont') {
        return const Icon(Icons.add);
      }
      return null;
    }

    final turnStyle = Prefs().pageTurnStyle;
    return Row(children: [
      Expanded(
        child: DropdownMenu<PageTurn>(
          label: Text(L10n.of(context).readingPagePageTurningMethod),
          initialSelection: turnStyle,
          expandedInsets: const EdgeInsetsDirectional.only(end: 5),
          // Each style costs something different, and the curl costs the most,
          // so the reader sees what they picked without opening the list again.
          helperText: turnStyle.getDescription(context),
          inputDecorationTheme: InputDecorationTheme(
            helperMaxLines: 3,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          onSelected: (PageTurn? value) {
            if (value != null) {
              setState(() {
                Prefs().pageTurnStyle = value;
              });
              epubPlayerKey.currentState!.changePageTurnStyle(value);
            }
          },
          dropdownMenuEntries: PageTurn.values
              .map((e) => DropdownMenuEntry(
                    value: e,
                    label: e.getLabel(context),
                  ))
              .toList(),
        ),
      ),
      Expanded(
        child: DropdownMenu<FontModel>(
          label: Text(L10n.of(context).font),
          expandedInsets: const EdgeInsetsDirectional.only(start: 5),
          initialSelection: font,
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          onSelected: (FontModel? font) async {
            if (font == null) return;
            if (font.name == 'newFont') {
              widget.hideAppBarAndBottomBar(false);
              await importFont();
              return;
            } else {
              epubPlayerKey.currentState!.changeFont(font);
              Prefs().font = font;
            }
          },
          dropdownMenuEntries: fonts()
              .map((font) => DropdownMenuEntry(
                    value: font,
                    label: font.label,
                    leadingIcon: leadingIcon(font.name),
                  ))
              .toList(),
        ),
      ),
    ]);
  }

  Padding sliders() {
    return Padding(
      padding: const EdgeInsets.all(3.0),
      child: Column(
        children: [
          fontSizeSlider(),
          lineHeightAndParagraphSpacingSlider(),
        ],
      ),
    );
  }

  Row lineHeightAndParagraphSpacingSlider() {
    bool enabled = !Prefs().useBookStyles;
    return Row(
      children: [
        IconAndText(
          icon: const Icon(Icons.line_weight),
          text: L10n.of(context).readingPageLineSpacing,
        ),
        Expanded(
          child: Slider(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              value: bookStyle.lineHeight,
              onChanged: enabled
                  ? (double value) {
                      setState(() {
                        bookStyle.lineHeight = value;
                        widget.epubPlayerKey.currentState!
                            .changeStyle(bookStyle);
                        Prefs().saveBookStyleToPrefs(bookStyle);
                      });
                    }
                  : null,
              min: 0,
              max: 3,
              divisions: 10,
              label: (bookStyle.lineHeight / 3 * 10).round().toString()),
        ),
        IconAndText(
          icon: const Icon(Icons.height),
          text: L10n.of(context).readingPageParagraphSpacing,
        ),
        Expanded(
          child: Slider(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            value: bookStyle.paragraphSpacing,
            onChanged: enabled
                ? (double value) {
                    setState(() {
                      bookStyle.paragraphSpacing = value;
                      widget.epubPlayerKey.currentState!.changeStyle(bookStyle);
                      Prefs().saveBookStyleToPrefs(bookStyle);
                    });
                  }
                : null,
            min: 0,
            max: 5,
            divisions: 10,
            label: (bookStyle.paragraphSpacing / 5 * 10).round().toString(),
          ),
        ),
      ],
    );
  }

  Row fontSizeSlider() {
    bool enabled = !Prefs().useBookStyles;
    return Row(
      children: [
        IconAndText(
          icon: const Icon(Icons.format_size),
          text: L10n.of(context).readingPageFontSize,
        ),
        Expanded(
          child: Slider(
            value: bookStyle.fontSize,
            onChanged: enabled
                ? (double value) {
                    setState(() {
                      bookStyle.fontSize = value;
                      widget.epubPlayerKey.currentState!.changeStyle(bookStyle);
                      Prefs().saveBookStyleToPrefs(bookStyle);
                    });
                  }
                : null,
            min: 0.5,
            max: 3.0,
            divisions: 25,
            label: bookStyle.fontSize.toStringAsFixed(2),
          ),
        ),
      ],
    );
  }

  /// The saved reading themes, as swatches.
  ///
  /// Each swatch is a 48dp target with 8dp between it and the next, and shows
  /// its own ink over its own ground, so the reader judges the pair as they
  /// will read it. The selection ring takes the scheme accent rather than a
  /// fixed black, because a fixed black disappears on the dark ground.
  SizedBox themeSelector() {
    const size = 48.0;
    final scheme = Theme.of(context).colorScheme;
    const newThemeDark = 'ff121212';
    const newThemeInk = 'ffcccccc';

    return SizedBox(
      height: size + 8,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: widget.themes.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == widget.themes.length) {
            return Semantics(
              button: true,
              label: L10n.of(context).readingPageTheme,
              child: Tooltip(
                message: L10n.of(context).readingPageTheme,
                child: Material(
                  color: Colors.transparent,
                  shape: CircleBorder(
                    side: BorderSide(color: scheme.outline),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () async {
                      int currId = await themeDao.insertTheme(ReadTheme(
                          backgroundColor: newThemeDark,
                          textColor: newThemeInk,
                          backgroundImagePath: ''));
                      widget.setCurrentPage(ThemeChangeWidget(
                        readTheme: ReadTheme(
                            id: currId,
                            backgroundColor: newThemeDark,
                            textColor: newThemeInk,
                            backgroundImagePath: ''),
                        setCurrentPage: widget.setCurrentPage,
                      ));
                    },
                    child: SizedBox(
                      height: size,
                      width: size,
                      child: Icon(Icons.add, color: scheme.onSurfaceVariant),
                    ),
                  ),
                ),
              ),
            );
          }

          final theme = widget.themes[index];
          final selected = index + 1 == currentThemeId;
          void edit() => setState(() {
                widget.setCurrentPage(ThemeChangeWidget(
                  readTheme: theme,
                  setCurrentPage: widget.setCurrentPage,
                ));
              });

          return Semantics(
            button: true,
            selected: selected,
            label: L10n.of(context).readingPageTheme,
            child: Material(
              color: Color(int.parse('0x${theme.backgroundColor}')),
              shape: CircleBorder(
                side: BorderSide(
                  color: selected ? scheme.primary : scheme.outlineVariant,
                  width: selected ? 3 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  Prefs().saveReadThemeToPrefs(theme);
                  widget.epubPlayerKey.currentState!.changeTheme(theme);
                  setState(() {
                    currentThemeId = theme.id;
                  });
                },
                onSecondaryTap: edit,
                onLongPress: edit,
                child: SizedBox(
                  height: size,
                  width: size,
                  child: Center(
                    child: Text(
                      'A',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Color(int.parse('0x${theme.textColor}')),
                          ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ThemeChangeWidget extends StatefulWidget {
  const ThemeChangeWidget({
    super.key,
    required this.readTheme,
    required this.setCurrentPage,
  });

  final ReadTheme readTheme;
  final Function setCurrentPage;

  @override
  State<ThemeChangeWidget> createState() => _ThemeChangeWidgetState();
}

class _ThemeChangeWidgetState extends State<ThemeChangeWidget> {
  late ReadTheme readTheme;

  @override
  void initState() {
    super.initState();
    readTheme = widget.readTheme;
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      IconButton(
        tooltip: L10n.of(context).readingPageBackgroundColour,
        onPressed: () async {
          String? pickingColor =
              await showColorPickerDialog(readTheme.backgroundColor);
          if (pickingColor != '') {
            setState(() {
              readTheme.backgroundColor = pickingColor!;
            });
            themeDao.updateTheme(readTheme);
          }
        },
        icon: Icon(Icons.circle,
            size: 80,
            color: Color(int.parse('0x${readTheme.backgroundColor}'))),
      ),
      IconButton(
          tooltip: L10n.of(context).readingPageTextColour,
          onPressed: () async {
            String? pickingColor =
                await showColorPickerDialog(readTheme.textColor);
            if (pickingColor != '') {
              setState(() {
                readTheme.textColor = pickingColor!;
              });
              themeDao.updateTheme(readTheme);
            }
          },
          icon: Icon(Icons.text_fields,
              size: 60, color: Color(int.parse('0x${readTheme.textColor}')))),
      const Expanded(
        child: SizedBox(),
      ),
      IconButton(
        tooltip: L10n.of(context).readingPageDeleteTheme,
        onPressed: () {
          themeDao.deleteTheme(readTheme.id!);
          widget.setCurrentPage(const SizedBox(height: 1));
          // setState(() {});
        },
        icon: const Icon(
          Icons.delete,
          size: 40,
        ),
      ),
    ]);
  }

  Future<String?> showColorPickerDialog(String currColor) async {
    Color pickedColor = Color(int.parse('0x$currColor'));

    await showDialog<void>(
      context: navigatorKey.currentState!.overlay!.context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: SingleChildScrollView(
            child: ColorPicker(
              hexInputBar: true,
              pickerColor: pickedColor,
              onColorChanged: (Color color) {
                pickedColor = color;
              },
              pickerAreaHeightPercent: 0.8,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(L10n.of(context).commonCancel),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop(pickedColor.value.toRadixString(16));
              },
            ),
          ],
        );
      },
    );

    return pickedColor.value.toRadixString(16);
  }
}
