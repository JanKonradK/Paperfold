import 'package:flutter/material.dart';
import 'package:paperfold/widgets/settings/settings_title.dart';

class SettingsPageBuilder extends StatelessWidget {
  const SettingsPageBuilder(
      {super.key,
      required this.isMobile,
      required this.id,
      required this.selectedIndex,
      required this.setDetail,
      required this.icon,
      required this.title,
      required this.sections,
      required this.subTitles});

  final bool isMobile;
  final int id;
  final int selectedIndex;
  final void Function(WidgetBuilder detail, int id) setDetail;
  final Icon icon;
  final String title;

  /// A builder, not a widget.
  ///
  /// plan.md Section 11.2 asks for the settings tree to open as lazy routes.
  /// Passing the built section here made every settings screen exist as soon
  /// as the list did, whether or not the reader ever opened it.
  final WidgetBuilder sections;

  final List<String> subTitles;

  @override
  Widget build(BuildContext context) {
    return settingsTitle(
      icon: icon,
      title: title,
      isMobile: isMobile,
      id: id,
      selectedIndex: selectedIndex,
      setDetail: setDetail,
      subPage: (BuildContext context) => SettingsPageBody(
        title: title,
        isMobile: isMobile,
        sections: sections,
      ),
      subtitle: subTitles,
    );
  }
}

class SettingsPageBody extends StatelessWidget {
  const SettingsPageBody({
    super.key,
    required this.title,
    required this.isMobile,
    required this.sections,
  });

  final String title;
  final bool isMobile;
  final WidgetBuilder sections;

  @override
  Widget build(BuildContext context) {
    // Material, not Cupertino. The chrome rule in DESIGN.md is Material
    // behaviour with a custom appearance, and an iOS navigation bar inside a
    // Material application is neither. Behaviour that came free with
    // CupertinoSliverNavigationBar, the large collapsing title, comes free
    // from SliverAppBar.large as well.
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return isMobile
              ? <Widget>[
                  SliverOverlapAbsorber(
                    handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                      context,
                    ),
                    sliver: SliverAppBar.large(
                      title: Text(title),
                      forceElevated: innerBoxIsScrolled,
                    ),
                  ),
                ]
              : <Widget>[];
        },
        body: MediaQuery.removePadding(
          removeTop: true,
          context: context,
          child: Builder(builder: sections),
        ),
      ),
    );
  }
}
