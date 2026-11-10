import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class CartDatabase {
  CartDatabase({DatabaseFactory? factory, String? databasePath})
    : _factory = factory,
      _databasePath = databasePath;

  static final CartDatabase instance = CartDatabase();

  static const tableName = 'cart_items';
  static const _databaseName = 'rios_pastries_cart.db';
  static const _databaseVersion = 2;

  final DatabaseFactory? _factory;
  final String? _databasePath;
  Future<Database>? _database;

  Future<Database> get database => _database ??= _openDatabase();

  Future<void> close() async {
    final openDatabase = _database;
    _database = null;
    await openDatabase?.then((db) => db.close());
  }

  Future<Database> _openDatabase() async {
    final databasePath =
        _databasePath ??
        path.join(await getDatabasesPath(), _databaseName);

    final factory = _factory ?? databaseFactory;
    return factory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: _databaseVersion,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE $tableName (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id INTEGER NOT NULL,
              product_id INTEGER NOT NULL,
              name TEXT NOT NULL,
              price TEXT NOT NULL,
              image TEXT,
              quantity INTEGER NOT NULL CHECK (quantity > 0),
              is_available INTEGER NOT NULL DEFAULT 1
                CHECK (is_available IN (0, 1)),
              availability_code TEXT,
              created_at TEXT NOT NULL,
              UNIQUE (user_id, product_id)
            )
          ''');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute(
              'ALTER TABLE $tableName ADD COLUMN availability_code TEXT',
            );
          }
        },
      ),
    );
  }
}
