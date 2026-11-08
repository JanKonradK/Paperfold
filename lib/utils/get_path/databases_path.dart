import 'dart:io';

import 'package:sqflite/sqflite.dart';

Future<String> getAnxDataBasesPath() async => getDatabasesPath();

Future<Directory> getAnxDataBasesDir() async {
  return Directory(await getAnxDataBasesPath());
}
