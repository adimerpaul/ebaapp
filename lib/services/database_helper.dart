import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  static String baseUrl = dotenv.env['API_URL'] ?? 'http://192.168.1.6:8000/api/mobile';

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
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
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

    // PRODUCTORES: con más campos y flag is_synced
    await db.execute('''
      CREATE TABLE productores (
        id INTEGER PRIMARY KEY,
        nombre TEXT,
        apellidos TEXT,
        numcarnet TEXT,
        comunidad TEXT,
        num_celular TEXT,
        direccion TEXT,
        proveedor TEXT,
        estado TEXT,
        is_synced INTEGER DEFAULT 1
      )
    ''');

    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_productores_numcarnet ON productores(numcarnet)',
    );

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

    // índice útil
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_apiarios_productor ON apiarios(productor_id)',
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // intentar agregar columnas si no existen (try/catch para no romper)
      final alters = <String>[
        "ALTER TABLE productores ADD COLUMN comunidad TEXT",
        "ALTER TABLE productores ADD COLUMN num_celular TEXT",
        "ALTER TABLE productores ADD COLUMN direccion TEXT",
        "ALTER TABLE productores ADD COLUMN proveedor TEXT",
        "ALTER TABLE productores ADD COLUMN estado TEXT",
        "ALTER TABLE productores ADD COLUMN is_synced INTEGER DEFAULT 1",
      ];
      for (final sql in alters) {
        try {
          await db.execute(sql);
        } catch (_) {
          // ignorar si ya existe
        }
      }
    }
  }
  /// Devuelve el productor local asociado al usuario logueado (por carnet).
  Future<Map<String, dynamic>?> getProductorActual() async {
    final user = await currentUser();
    if (user == null) return null;

    final carnet = user['username']?.toString();
    if (carnet == null || carnet.trim().isEmpty) return null;

    final db = await database;
    final rows = await db.query(
      'productores',
      columns: [
        'id',
        'nombre',
        'apellidos',
        'numcarnet',
        'comunidad',
        'num_celular',
        'direccion',
        'proveedor',
        'estado',
        'is_synced',
      ],
      where: 'TRIM(numcarnet) = ?',
      whereArgs: [carnet.trim()],
      limit: 1,
    );

    return rows.isEmpty ? null : rows.first;
  }

  /// Devuelve el productor cuyo numcarnet coincida (máx 1 fila)
  /// con el conteo de apiarios ya incluido.
  Future<List<Map<String, dynamic>>> fetchProductoresByCarnet(
      String numcarnet,
      ) async {
    final db = await database;
    final carnetTrim = numcarnet.trim();

    return db.rawQuery('''
      SELECT
        p.id,
        p.nombre,
        p.apellidos,
        p.numcarnet,
        p.comunidad,
        p.num_celular,
        p.direccion,
        p.proveedor,
        p.estado,
        p.is_synced,
        (
          SELECT COUNT(1)
          FROM apiarios a
          WHERE a.productor_id = p.id
        ) AS apiarios_count
      FROM productores p
      WHERE TRIM(p.numcarnet) = ?
      LIMIT 1
    ''', [carnetTrim]);
  }



  Future logout() async {
    final db = await database;
    await db.delete('users_login');
  }

  /// Login por carnet (numcarnet) sobre tabla productores.
  Future<Map<String, dynamic>> loginApicultorByCarnet(String numcarnet) async {
    final db = await database;

    final rows = await db.query(
      'productores',
      where: 'numcarnet = ?',
      whereArgs: [numcarnet],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw Exception('Apicultor no encontrado con ese carnet. Regístrate primero.');
    }

    final p = rows.first;
    final nombreCompleto =
    '${p['nombre'] ?? ''} ${p['apellidos'] ?? ''}'.trim();

    // Reutilizamos users_login como tabla de sesión
    await db.transaction((txn) async {
      await txn.delete('users_login');
      await txn.insert('users_login', {
        'id': p['id'],
        'name': nombreCompleto.isNotEmpty ? nombreCompleto : 'Apicultor ${p['id']}',
        'username': p['numcarnet'], // guardamos el carnet aquí
      });
    });

    return {
      'id': p['id'],
      'name': nombreCompleto,
      'numcarnet': p['numcarnet'],
    };
  }

  /// Usuario logueado (desde users_login).
  Future<Map<String, dynamic>?> currentUser() async {
    final db = await database;
    final rows = await db.query('users_login', limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  // ---------------------------------------------------------------------------
  // CRUD PRODUCTORES LOCAL
  // ---------------------------------------------------------------------------

  /// Crear productor localmente y (si hay internet) intentamos sincronizar.
  Future<int> createProductor({
    required String nombre,
    required String apellidos,
    required String numcarnet,
    String? comunidad,
    String? numCelular,
    String? direccion,
    String? proveedor,
    String? estado,
  }) async {
    final db = await database;

    // Validar que no exista carnet duplicado
    final existe = await db.query(
      'productores',
      where: 'numcarnet = ?',
      whereArgs: [numcarnet],
      limit: 1,
    );
    if (existe.isNotEmpty) {
      throw Exception('Ya existe un apicultor con ese carnet.');
    }

    final id = await db.insert('productores', {
      'nombre': nombre,
      'apellidos': apellidos,
      'numcarnet': numcarnet,
      'comunidad': comunidad,
      'num_celular': numCelular,
      'direccion': direccion,
      'proveedor': proveedor,
      'estado': estado,
      'is_synced': 0,
    });

    // Intentar mandar al servidor (no reventar si falla)
    try {
      await syncProductor(id);
    } catch (_) {}

    return id;
  }

  /// Actualiza datos del productor SOLO en SQLite, marcando is_synced = 0.
  Future<void> updateProductorLocal({
    required int id,
    required String nombre,
    required String apellidos,
    required String numcarnet,
    String? comunidad,
    String? numCelular,
    String? direccion,
    String? proveedor,
    String? estado,
  }) async {
    final db = await database;
    await db.update(
      'productores',
      {
        'nombre': nombre,
        'apellidos': apellidos,
        'numcarnet': numcarnet,
        'comunidad': comunidad,
        'num_celular': numCelular,
        'direccion': direccion,
        'proveedor': proveedor,
        'estado': estado,
        'is_synced': 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Cuenta productores (busca por nombre, apellidos o carnet).
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
         OR numcarnet LIKE ?
    ''', [like, like, like]);

    return Sqflite.firstIntValue(res) ?? 0;
  }

  /// Lista productores con conteo de apiarios (subquery).
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
        p.numcarnet,
        p.comunidad,
        p.num_celular,
        p.direccion,
        p.proveedor,
        p.estado,
        p.is_synced,
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
           OR p.numcarnet LIKE ?
        ORDER BY $orderBy
        LIMIT ? OFFSET ?
      ''', [like, like, like, limit, offset]);
    }
  }

  /// Apiarios por productor.
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
  // SYNC con servidor
  // ---------------------------------------------------------------------------

  /// Envía los datos del productor al servidor (upsert por numcarnet)
  /// y marca is_synced = 1 si todo sale bien.
  Future<void> syncProductor(int id) async {
    final db = await database;

    final rows = await db.query(
      'productores',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw Exception('Productor local no encontrado.');
    }

    final p = rows.first;

    final body = {
      'numcarnet': p['numcarnet'],
      'nombre': p['nombre'],
      'apellidos': p['apellidos'],
      'comunidad': p['comunidad'],
      'num_celular': p['num_celular'],
      'direccion': p['direccion'],
      'proveedor': p['proveedor'],
      'estado': p['estado'],
    };

    final uri = Uri.parse('$baseUrl/productores-sync');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );

    if (res.statusCode != 200) {
      throw Exception('Error ${res.statusCode} al sincronizar productor.');
    }

    await db.update(
      'productores',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------------------------------------------------------------------------
  // IMPORTACIÓN DESDE API
  // ---------------------------------------------------------------------------

  /// Llama a /mobile/export, borra y repuebla tablas (modo "reemplazo").
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

    // Limpiar tablas y reinsertar con batch
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

      // PRODUCTORES (con más campos)
      for (final p in productores) {
        batch.insert(
          'productores',
          {
            'id': p['id'],
            'nombre': p['nombre'],
            'apellidos': p['apellidos'],
            'numcarnet': p['numcarnet'],
            'comunidad': p['comunidad'],
            'num_celular': p['num_celular'],
            'direccion': p['direccion'],
            'proveedor': p['proveedor'],
            'estado': p['estado'],
            'is_synced': 1, // vienen desde el server, ya sincronizados
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
