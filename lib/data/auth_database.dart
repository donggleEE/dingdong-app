import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AuthDatabase {
  AuthDatabase._();

  static final AuthDatabase instance = AuthDatabase._();

  Database? _database;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) {
      return existing;
    }

    final dbPath = await getDatabasesPath();
    final database = await openDatabase(
      p.join(dbPath, 'fetal_movement_auth.db'),
      version: 1,
      onCreate: _createSchema,
    );
    _database = database;
    return database;
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT NOT NULL UNIQUE,
        display_name TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        password_salt TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE auth_session (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        user_id INTEGER NOT NULL,
        logged_in_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('CREATE INDEX idx_users_email ON users (email)');
  }
}
