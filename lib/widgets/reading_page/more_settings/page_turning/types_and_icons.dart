import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/enums/page_turn_mode.dart';
import 'package:paperfold/widgets/reading_page/more_settings/page_turning/diagram.dart';

List<PageTurningType> type1 = [
  PageTurningType.prev,
  PageTurningType.menu,
  PageTurningType.next,
  PageTurningType.prev,
  PageTurningType.menu,
  PageTurningType.next,
  PageTurningType.prev,
  PageTurningType.menu,
  PageTurningType.next,
];
List<int> icon1 = [5, 3, 4];

List<PageTurningType> type2 = [
  PageTurningType.prev,
  PageTurningType.prev,
  PageTurningType.next,
  PageTurningType.prev,
  PageTurningType.menu,
  PageTurningType.next,
  PageTurningType.prev,
  PageTurningType.next,
  PageTurningType.next,
];
List<int> icon2 = [5, 3, 4];

List<PageTurningType> type3 = [
  PageTurningType.prev,
  PageTurningType.prev,
  PageTurningType.next,
  PageTurningType.prev,
  PageTurningType.menu,
  PageTurningType.next,
  PageTurningType.next,
  PageTurningType.next,
  PageTurningType.next,
];
List<int> icon3 = [5, 3, 4];

List<PageTurningType> type4 = [
  PageTurningType.menu,
  PageTurningType.menu,
  PageTurningType.menu,
  PageTurningType.prev,
  PageTurningType.next,
  PageTurningType.next,
  PageTurningType.prev,
  PageTurningType.next,
  PageTurningType.next,
];
// next, prev, menu
List<int> icon4 = [5, 3, 1];

List<PageTurningType> type5 = [
  PageTurningType.next,
  PageTurningType.menu,
  PageTurningType.next,
  PageTurningType.next,
  PageTurningType.prev,
  PageTurningType.next,
  PageTurningType.next,
  PageTurningType.next,
  PageTurningType.next,
];
// next, prev, menu from 0
List<int> icon5 = [7, 4, 1];

List<List<PageTurningType>> pageTurningTypes = [
  type1,
  type2,
  type3,
  type4,
  type5,
];
List<List<int>> pageTurningIcons = [icon1, icon2, icon3, icon4, icon5];

/// The effective tap actions, shared by the reader and its guide.
List<PageTurningType> currentPageTurningActions() {
  final prefs = Prefs();
  final simple =
      PageTurnMode.fromCode(prefs.pageTurnMode) == PageTurnMode.simple;
  return List.generate(9, (index) {
    var action = simple
        ? pageTurningTypes[prefs.pageTurningType][index]
        : PageTurningType.values[prefs.customPageTurnConfig[index]];
    if (simple && prefs.swapPageTurnArea) {
      if (action == PageTurningType.prev) {
        action = PageTurningType.next;
      } else if (action == PageTurningType.next) {
        action = PageTurningType.prev;
      }
    }
    return action;
  });
}
