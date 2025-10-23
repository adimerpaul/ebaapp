import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  static String baseUrl = dotenv.env['API_URL'] ?? 'http://192.168.1.6:8000';

  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = '$dbPath/app_database.db';
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future _onCreate(Database db, int version) async {
    // USERS
    await db.execute('''
      CREATE TABLE users (
        id INTEGER,
        name TEXT,
        username TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE users_login (
        id INTEGER,
        name TEXT,
        username TEXT
      )
    ''');

    // PRODUCTORES (solo campos mínimos)
    await db.execute('''
      CREATE TABLE productores (
        id INTEGER,
        nombre TEXT,
        apellidos TEXT
      )
    ''');

    // APIARIOS (ubicación)
    await db.execute('''
      CREATE TABLE apiarios (
        id INTEGER,
        productor_id INTEGER,
        latitud TEXT,
        longitud TEXT,
        lugar_apiario TEXT,
        FOREIGN KEY(productor_id) REFERENCES productores(id)
      )
    ''');

    // índices útiles
    await db.execute('CREATE INDEX IF NOT EXISTS idx_apiarios_productor ON apiarios(productor_id)');
  }
  Future logout() async {
    final db = await database;
    await db.delete('users_login');
  }
  /// Borra users_login e inserta el usuario cuyo username coincida en users.
  /// Retorna el mapa del usuario guardado en users_login.
  Future<Map<String, dynamic>> loginWithUsername(String username) async {
    final db = await database;

    // Busca el usuario en tabla users (importada del servidor)
    final found = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
      limit: 1,
    );

    if (found.isEmpty) {
      throw Exception('Usuario no encontrado en "users". Importa datos o verifica el username.');
    }

    final user = found.first;

    // Persistir sesión simple en users_login (1 fila)
    await db.transaction((txn) async {
      await txn.delete('users_login'); // mantiene solo 1 "sesión"
      await txn.insert('users_login', {
        'id': user['id'],
        'name': user['name'],
        'username': user['username'],
      });
    });

    return user;
  }

  /// Retorna el usuario actualmente logueado (si existe) desde users_login.
  Future<Map<String, dynamic>?> currentUser() async {
    final db = await database;
    final rows = await db.query('users_login', limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  /// Cuenta productores (con filtro opcional).
  Future<int> countProductores({String search = ''}) async {
    final db = await database;

    if (search.trim().isEmpty) {
      final res = await db.rawQuery('SELECT COUNT(*) as c FROM productores');
      return Sqflite.firstIntValue(res) ?? 0;
    }

    final like = '%${search.trim()}%';
    final res = await db.rawQuery('''
      SELECT COUNT(*) as c
      FROM productores
      WHERE UPPER(nombre) LIKE UPPER(?)
         OR UPPER(apellidos) LIKE UPPER(?)
    ''', [like, like]);

    return Sqflite.firstIntValue(res) ?? 0;
  }

  /// Lista productores paginados con un conteo de apiarios (subquery), con filtro opcional.
  Future<List<Map<String, dynamic>>> fetchProductores({
    String search = '',
    int limit = 50,
    int offset = 0,
    String orderBy = 'id DESC',
  }) async {
    final db = await database;

    final baseSelect = '''
      SELECT
        p.id,
        p.nombre,
        p.apellidos,
        (
          SELECT COUNT(1)
          FROM apiarios a
          WHERE a.productor_id = p.id
        ) AS apiarios_count
      FROM productores p
    ''';

    if (search.trim().isEmpty) {
      return db.rawQuery('''
        $baseSelect
        ORDER BY $orderBy
        LIMIT ? OFFSET ?
      ''', [limit, offset]);
    } else {
      final like = '%${search.trim()}%';
      return db.rawQuery('''
        $baseSelect
        WHERE UPPER(p.nombre) LIKE UPPER(?)
           OR UPPER(p.apellidos) LIKE UPPER(?)
        ORDER BY $orderBy
        LIMIT ? OFFSET ?
      ''', [like, like, limit, offset]);
    }
  }

  /// Apiarios por productor (se cargan al expandir). Si tienes MUCHÍSIMOS apiarios por productor,
  /// puedes añadir paginación aquí también.
  Future<List<Map<String, dynamic>>> fetchApiariosByProductor(int productorId) async {
    final db = await database;
    return db.query(
      'apiarios',
      where: 'productor_id = ?',
      whereArgs: [productorId],
      orderBy: 'id DESC',
    );
  }

  // ---------------------------------------------------------------------------
  // IMPORTACIÓN DESDE API
  // ---------------------------------------------------------------------------

  /// Llama a /api/export, borra y repuebla tablas (modo "reemplazo").
  Future<ImportResult> importFromServer() async {
    final db = await database;

    final uri = Uri.parse('$baseUrl/export');
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Error ${res.statusCode} al consultar $uri');
    }

    final data = json.decode(res.body) as Map<String, dynamic>;
    final users = List<Map<String, dynamic>>.from(data['users'] ?? []);
    final productores = List<Map<String, dynamic>>.from(data['productores'] ?? []);

    // aplanar apiarios
    final List<Map<String, dynamic>> apiarios = [];
    for (final p in productores) {
      final List aps = List.from(p['apiarios'] ?? []);
      for (final a in aps) {
        apiarios.add({
          'id': a['id'],
          'productor_id': a['productor_id'],
          'latitud': a['latitud']?.toString(),
          'longitud': a['longitud']?.toString(),
          'lugar_apiario': a['lugar_apiario'],
        });
      }
    }

    // Limpiar tablas y reinsertar con batch para que sea rápido
    await db.transaction((txn) async {
      await txn.delete('apiarios');
      await txn.delete('productores');
      await txn.delete('users');

      final batch = txn.batch();

      // USERS
      for (final u in users) {
        batch.insert(
          'users',
          {
            'id': u['id'],
            'name': u['name'],
            'username': u['username'],
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // PRODUCTORES
      for (final p in productores) {
        batch.insert(
          'productores',
          {
            'id': p['id'],
            'nombre': p['nombre'],
            'apellidos': p['apellidos'],
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // APIARIOS
      for (final a in apiarios) {
        batch.insert(
          'apiarios',
          a,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
    });

    return ImportResult(
      users: users.length,
      productores: productores.length,
      apiarios: apiarios.length,
    );
  }
}

class ImportResult {
  final int users;
  final int productores;
  final int apiarios;
  ImportResult({required this.users, required this.productores, required this.apiarios});
}
