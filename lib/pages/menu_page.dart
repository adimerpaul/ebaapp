import 'dart:async';
import 'package:ebaapp/services/database_helper.dart';
import 'package:flutter/material.dart';
import 'mapa_page.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
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
    _scrollCtrl.dispose();
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error apiarios: $e')));
    }
  }

  Future<void> _goToMapForProducer(Map<String, dynamic> p) async {
    final pid = p['id'] as int;
    final title = '${p['nombre'] ?? ''} ${p['apellidos'] ?? ''}'.trim().isEmpty
        ? 'Productor $pid'
        : '${p['nombre'] ?? ''} ${p['apellidos'] ?? ''}'.trim();

    // Asegurar apiarios cargados
    if (!_apiariosCache.containsKey(pid)) {
      await _loadApiariosFor(pid);
    }
    final aps = _apiariosCache[pid] ?? [];

    // Mapear a marcadores
    final markers = aps.map((a) {
      return {
        'lat': a['latitud']?.toString(),
        'lng': a['longitud']?.toString(),
        'title': a['lugar_apiario'] ?? '(Sin lugar)',
        'subtitle': 'Apiario ID: ${a['id'] ?? ''}',
      };
    }).toList();

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapaPage(
          title: 'Apiarios de $title',
          markers: markers,
        ),
      ),
    );
  }

  void _goToMapForSingleApiario(Map<String, dynamic> a) {
    final markers = [
      {
        'lat': a['latitud']?.toString(),
        'lng': a['longitud']?.toString(),
        'title': a['lugar_apiario'] ?? '(Sin lugar)',
        'subtitle': 'Apiario ID: ${a['id'] ?? ''}',
      }
    ];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapaPage(
          title: a['lugar_apiario'] ?? 'Apiario',
          markers: markers,
        ),
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar salida'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              await DatabaseHelper().logout(); // asegúrate de tener este método
              if (!mounted) return;
              Navigator.of(context).pop();
              Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
            },
            child: const Text('Salir'),
          ),
        ],
      ),
    );
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
            tooltip: 'Refrescar',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _confirmLogout,
            tooltip: 'Salir',
          ),
        ],
        foregroundColor: Colors.white,
        backgroundColor: Colors.blueAccent,
      ),

      body: RefreshIndicator(
        onRefresh: _loadPage,
        child: ListView(
          controller: _scrollCtrl,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          children: [
            // Buscador + tamaño de página
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Buscar productor (nombre/apellidos)',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    PopupMenuButton<int>(
                      tooltip: 'Tamaño de página',
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 25, child: Text('25 por página')),
                        PopupMenuItem(value: 50, child: Text('50 por página')),
                        PopupMenuItem(value: 100, child: Text('100 por página')),
                      ],
                      onSelected: (v) {
                        setState(() {
                          _pageSize = v;
                          _page = 1;
                        });
                        _loadPage();
                      },
                      child: Chip(
                        label: Text('$_pageSize'),
                        avatar: const Icon(Icons.list_alt, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Info de paginación
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
              child: Text(
                'Mostrando $showingStart–$showingEnd de $_total',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),

            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_productores.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: Column(
                  children: [
                    Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade500),
                    const SizedBox(height: 10),
                    Text('Sin resultados', style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              )
            else
              ..._productores.map((p) {
                final pid = p['id'] as int;
                final nombre = (p['nombre'] ?? '').toString();
                final apellidos = (p['apellidos'] ?? '').toString();
                final title = '$nombre $apellidos'.trim().isEmpty ? '(Sin nombre)' : '$nombre $apellidos'.trim();
                final count = p['apiarios_count'] ?? 0;

                final initials = [
                  if (nombre.isNotEmpty) nombre.trim()[0].toUpperCase(),
                  if (apellidos.isNotEmpty) apellidos.trim()[0].toUpperCase(),
                ].join();

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                      leading: CircleAvatar(
                        child: Text(initials.isEmpty ? '?' : initials),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _goToMapForProducer(p),
                              child: Text(
                                title,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Chip(
                            label: Text('Apiarios: $count'),
                            avatar: const Icon(Icons.hive_outlined, size: 18),
                          ),
                        ],
                      ),
                      subtitle: Text('ID: $pid'),
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
                              leading: const Icon(Icons.place_outlined),
                              dense: true,
                              title: Text(lugar.isEmpty ? '(Sin lugar)' : lugar),
                              subtitle: Text('Apiario ID: $aid · Lat: $lat · Lng: $lng'),
                              trailing: TextButton.icon(
                                onPressed: () => _goToMapForSingleApiario(a),
                                icon: const Icon(Icons.map_outlined, size: 18),
                                label: const Text('Ver en mapa'),
                              ),
                              onTap: () => _goToMapForSingleApiario(a),
                            );
                          }).toList(),
                        // Botón ver todos en mapa
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 6, right: 6),
                            child: OutlinedButton.icon(
                              onPressed: () => _goToMapForProducer(p),
                              icon: const Icon(Icons.travel_explore_outlined),
                              label: const Text('Ver todos en mapa'),
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                );
              }),

            // Paginación
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Página $_page de $_totalPages'),
                  Wrap(
                    spacing: 6,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.first_page),
                        onPressed: (_page > 1 && !_loading)
                            ? () { setState(() => _page = 1); _loadPage(); }
                            : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: (_page > 1 && !_loading)
                            ? () { setState(() => _page -= 1); _loadPage(); }
                            : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: (_page < _totalPages && !_loading)
                            ? () { setState(() => _page += 1); _loadPage(); }
                            : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.last_page),
                        onPressed: (_page < _totalPages && !_loading)
                            ? () { setState(() => _page = _totalPages); _loadPage(); }
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
