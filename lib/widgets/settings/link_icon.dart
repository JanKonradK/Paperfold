import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

Widget linkIcon({
  required Widget icon,
  required String url,
  required LaunchMode mode,
  double size = 30,
}) {
  return IconButton(
    onPressed: () => launchUrl(
      Uri.parse(url),
      mode: mode,
    ),
    icon: SizedBox(
      width: size,
      height: size,
      child: icon,
    ),
  );
}
