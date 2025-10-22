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
