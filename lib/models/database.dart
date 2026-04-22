import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sqflite/sqflite.dart' as sqlite;
import 'dart:io';
import 'package:path/path.dart';

final riddleStore = intMapStoreFactory.store('riddles');

class DatabaseConfig {
  static Future<Database> initDatabase() async {
    final String databasePath = await sqlite.getDatabasesPath();
    final String path = join(databasePath, 'learning_app.db');

    final dbDir = Directory(databasePath);
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }

    return await databaseFactoryIo.openDatabase(path);
  }
}