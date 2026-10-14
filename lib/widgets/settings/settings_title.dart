import 'package:paperfold/widgets/settings/settings_section.dart';
import 'package:material_ui/material_ui.dart';

Widget settingsTitle({
  required Icon icon,
  required String title,
  required bool isMobile,
  required int id,
  required int selectedIndex,
  required Function setDetail,

  /// A builder, so the settings screen behind this row is built when the
  /// reader opens it and not when the list draws. plan.md Section 11.2.
  required WidgetBuilder subPage,
  required List<String> subtitle,
}) {
  return Builder(
    builder: (BuildContext context) => ListTile(
      leading: icon,
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      selected: !isMobile && selectedIndex == id,
      subtitle: Text(subtitle.join(' • ')),
      onTap: () {
        if (!isMobile) {
          setDetail(subPage, id);
          return;
        }
        // The route comes from the tapped row's own context, not from a
        // global navigator key. A settings row opened from a dialog or a
        // second navigator used to push onto the root one instead.
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: subPage),
        );
      },
    ),
  );
}

Widget settingsSections({
  required List<AbstractSettingsSection> sections,
}) {
  // return SettingsList(sections: sections);
  return ListView.builder(
    itemCount: sections.length,
    itemBuilder: (context, index) {
      return sections[index];
    },
  );
}
