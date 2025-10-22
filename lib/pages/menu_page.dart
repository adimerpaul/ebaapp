import 'dart:async';
import 'package:ebaapp/services/database_helper.dart';
import 'package:flutter/material.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  bool _loading = true;
  int _page = 1;
  int _pageSize = 50;
  int _total = 0;

  List<Map<String, dynamic>> _productores = [];
  final Map<int, List<Map<String, dynamic>>> _apiariosCache = {}; // productorId -> apiarios

  @override
  void initState() {
    super.initState();
    _loadPage();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _page = 1; // reset
      _loadPage();
    });
  }

  Future<void> _loadPage() async {
    setState(() => _loading = true);
    try {
      final search = _searchCtrl.text.trim();
      final total = await DatabaseHelper().countProductores(search: search);
      final offset = (_page - 1) * _pageSize;
      final rows = await DatabaseHelper().fetchProductores(
        search: search,
        limit: _pageSize,
        offset: offset,
        orderBy: 'id DESC',
      );
      setState(() {
        _total = total;
        _productores = rows;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _totalPages {
    if (_pageSize <= 0) return 1;
    final tp = (_total / _pageSize).ceil();
    return tp == 0 ? 1 : tp;
  }

  Future<void> _loadApiariosFor(int productorId) async {
    if (_apiariosCache.containsKey(productorId)) return;
    try {
      final apiarios = await DatabaseHelper().fetchApiariosByProductor(productorId);
      _apiariosCache[productorId] = apiarios;
      if (mounted) setState(() {}); // refresca expansión
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error apiarios: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final showingStart = _total == 0 ? 0 : ((_page - 1) * _pageSize) + 1;
    final showingEnd = (_page * _pageSize) > _total ? _total : (_page * _pageSize);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Productores & Apiarios'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadPage,
          )
        ],
        foregroundColor: Colors.white,
        backgroundColor: Colors.blueAccent,
      ),
      body: Column(
        children: [
          // Filtros
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Buscar productor (nombre/apellidos)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _pageSize,
                  items: const [
                    DropdownMenuItem(value: 25, child: Text('25')),
                    DropdownMenuItem(value: 50, child: Text('50')),
                    DropdownMenuItem(value: 100, child: Text('100')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _pageSize = v;
                      _page = 1;
                    });
                    _loadPage();
                  },
                ),
              ],
            ),
          ),

          // Info de paginación
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Mostrando $showingStart–$showingEnd de $_total'),
            ),
          ),

          const SizedBox(height: 6),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _productores.isEmpty
                ? const Center(child: Text('Sin resultados'))
                : ListView.builder(
              itemCount: _productores.length,
              itemBuilder: (context, index) {
                final p = _productores[index];
                final pid = p['id'] as int;
                final title = '${p['nombre'] ?? ''} ${p['apellidos'] ?? ''}'.trim();
                final count = p['apiarios_count'] ?? 0;

                return ExpansionTile(
                  title: Text(title.isEmpty ? '(Sin nombre)' : title),
                  subtitle: Text('ID: $pid · Apiarios: $count'),
                  onExpansionChanged: (isOpen) {
                    if (isOpen) _loadApiariosFor(pid);
                  },
                  children: [
                    if (!_apiariosCache.containsKey(pid))
                      const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: LinearProgressIndicator(),
                      )
                    else
                      ..._apiariosCache[pid]!.map((a) {
                        final lat = a['latitud'] ?? '';
                        final lng = a['longitud'] ?? '';
                        final lugar = a['lugar_apiario'] ?? '';
                        final aid = a['id'] ?? '';
                        return ListTile(
                          dense: true,
                          title: Text(lugar.isEmpty ? '(Sin lugar)' : lugar),
                          subtitle: Text('Apiario ID: $aid · Lat: $lat · Lng: $lng'),
                          leading: const Icon(Icons.hive_outlined),
                        );
                      }).toList(),
                  ],
                );
              },
            ),
          ),

          // Controles de paginación
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Página $_page de $_totalPages'),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.first_page),
                      onPressed: (_page > 1 && !_loading)
                          ? () {
                        setState(() => _page = 1);
                        _loadPage();
                      }
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: (_page > 1 && !_loading)
                          ? () {
                        setState(() => _page -= 1);
                        _loadPage();
                      }
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: (_page < _totalPages && !_loading)
                          ? () {
                        setState(() => _page += 1);
                        _loadPage();
                      }
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.last_page),
                      onPressed: (_page < _totalPages && !_loading)
                          ? () {
                        setState(() => _page = _totalPages);
                        _loadPage();
                      }
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
