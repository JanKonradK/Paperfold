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
    if (!isMobile) {
      return Scaffold(body: Builder(builder: sections));
    }

    // No `SliverOverlapAbsorber` around the app bar.
    //
    // An absorber takes the header's overlap out of the inner viewport and
    // expects a `SliverOverlapInjector` to put it back. The body here is a
    // plain lazy `ListView`, not a CustomScrollView, so nothing ever injected
    // it: on the phone the large title never collapsed and the first section
    // slid underneath it. The "Theme" header and the light/dark control were
    // hidden on every visit until the list was dragged back to the very top.
    //
    // An absorber is only needed for a pinned header over a sliver body. This
    // header is neither, so it goes.
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverAppBar.large(
              title: Text(title),
              forceElevated: innerBoxIsScrolled,
            ),
          ];
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
