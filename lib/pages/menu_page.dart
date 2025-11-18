import 'package:ebaapp/pages/mapa_page.dart';
import 'package:ebaapp/services/database_helper.dart';
import 'package:flutter/material.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  final _db = DatabaseHelper();

  bool _loading = true;
  bool _syncing = false;

  Map<String, dynamic>? _productor;
  List<Map<String, dynamic>> _apiarios = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final productor = await _db.getProductorActual();
      if (productor == null) {
        setState(() {
          _productor = null;
          _apiarios = [];
        });
        return;
      }

      final pid = (productor['id'] ?? 0) as int;
      final apiarios = await _db.fetchApiariosByProductor(pid);

      setState(() {
        _productor = productor;
        _apiarios = apiarios;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando datos: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar salida'),
        content: const Text('¿Seguro que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              await _db.logout();
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

  Future<void> _syncProductor() async {
    if (_productor == null) return;
    final pid = (_productor!['id'] ?? 0) as int;
    if (pid == 0) return;

    setState(() => _syncing = true);
    try {
      await _db.syncProductor(pid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Datos enviados al servidor')),
      );
      await _loadData(); // recarga para reflejar is_synced = 1
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al sincronizar: $e')),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _editProductor() async {
    if (_productor == null) return;

    final p = _productor!;
    final pid = (p['id'] ?? 0) as int;

    final nombreCtrl =
    TextEditingController(text: (p['nombre'] ?? '').toString());
    final apellidosCtrl =
    TextEditingController(text: (p['apellidos'] ?? '').toString());
    final carnetCtrl =
    TextEditingController(text: (p['numcarnet'] ?? '').toString());
    final comunidadCtrl =
    TextEditingController(text: (p['comunidad'] ?? '').toString());
    final celularCtrl =
    TextEditingController(text: (p['num_celular'] ?? '').toString());
    final direccionCtrl =
    TextEditingController(text: (p['direccion'] ?? '').toString());
    final proveedorCtrl =
    TextEditingController(text: (p['proveedor'] ?? '').toString());
    final estadoCtrl =
    TextEditingController(text: (p['estado'] ?? '').toString());

    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Mis datos de apicultor',
                    style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nombreCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Ingresa tu nombre'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: apellidosCtrl,
                    decoration: const InputDecoration(labelText: 'Apellidos'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: carnetCtrl,
                    enabled: false,
                    decoration: const InputDecoration(labelText: 'Carnet'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: comunidadCtrl,
                    decoration:
                    const InputDecoration(labelText: 'Comunidad'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: celularCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Celular'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: direccionCtrl,
                    decoration:
                    const InputDecoration(labelText: 'Dirección'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: proveedorCtrl,
                    decoration:
                    const InputDecoration(labelText: 'Proveedor'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: estadoCtrl,
                    decoration: const InputDecoration(labelText: 'Estado'),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;

                        await _db.updateProductorLocal(
                          id: pid,
                          nombre: nombreCtrl.text.trim(),
                          apellidos: apellidosCtrl.text.trim(),
                          numcarnet: carnetCtrl.text.trim(),
                          comunidad: comunidadCtrl.text.trim(),
                          numCelular: celularCtrl.text.trim(),
                          direccion: direccionCtrl.text.trim(),
                          proveedor: proveedorCtrl.text.trim(),
                          estado: estadoCtrl.text.trim(),
                        );

                        if (!mounted) return;
                        Navigator.of(ctx).pop();
                        await _loadData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                            Text('Datos guardados localmente (offline)'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('Guardar en el teléfono'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openMapAll() {
    if (_productor == null || _apiarios.isEmpty) return;

    final nombre = (_productor!['nombre'] ?? '').toString();
    final apellidos = (_productor!['apellidos'] ?? '').toString();
    final title = '$nombre $apellidos'.trim().isEmpty
        ? 'Mis apiarios'
        : 'Apiarios de $nombre $apellidos';

    final markers = _apiarios.map((a) {
      return {
        'lat': a['latitud']?.toString(),
        'lng': a['longitud']?.toString(),
        'title': a['lugar_apiario'] ?? '(Sin lugar)',
        'subtitle': 'Apiario ID: ${a['id'] ?? ''}',
      };
    }).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapaPage(
          title: title,
          markers: markers,
        ),
      ),
    );
  }

  void _openMapSingle(Map<String, dynamic> a) {
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

  @override
  Widget build(BuildContext context) {
    final p = _productor;
    final synced = (p?['is_synced'] ?? 1) == 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi perfil de apicultor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadData,
            tooltip: 'Recargar',
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : p == null
          ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            const Text(
              'No se encontró un apicultor\npara el carnet del usuario logueado.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _confirmLogout,
              icon: const Icon(Icons.logout),
              label: const Text('Volver al login'),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${p['nombre'] ?? ''} ${p['apellidos'] ?? ''}'
                          .trim()
                          .isEmpty
                          ? 'Apicultor'
                          : '${p['nombre'] ?? ''} ${p['apellidos'] ?? ''}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('CI: ${p['numcarnet'] ?? '-'}'),
                    const SizedBox(height: 4),
                    if ((p['num_celular'] ?? '').toString().isNotEmpty)
                      Text('Celular: ${p['num_celular']}'),
                    if ((p['comunidad'] ?? '').toString().isNotEmpty)
                      Text('Comunidad: ${p['comunidad']}'),
                    if ((p['direccion'] ?? '').toString().isNotEmpty)
                      Text('Dirección: ${p['direccion']}'),
                    if ((p['proveedor'] ?? '').toString().isNotEmpty)
                      Text('Proveedor: ${p['proveedor']}'),
                    if ((p['estado'] ?? '').toString().isNotEmpty)
                      Text('Estado: ${p['estado']}'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Chip(
                          label: Text(
                            synced
                                ? 'Sincronizado con servidor'
                                : 'Pendiente de enviar',
                            style: const TextStyle(fontSize: 11),
                          ),
                          backgroundColor: synced
                              ? Colors.green.shade100
                              : Colors.orange.shade100,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _editProductor,
                            icon: const Icon(Icons.edit),
                            label:
                            const Text('Editar mis datos (offline)'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _syncing ? null : _syncProductor,
                            icon: _syncing
                                ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                              CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                                : const Icon(Icons.cloud_upload),
                            label: Text(
                              _syncing
                                  ? 'Enviando...'
                                  : 'Subir mis datos',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // APIARIOS DEL APICULTOR
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Mis apiarios',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_apiarios.isNotEmpty)
                          TextButton.icon(
                            onPressed: _openMapAll,
                            icon: const Icon(Icons.map_outlined),
                            label: const Text('Ver en mapa'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_apiarios.isEmpty)
                      const Text(
                        'No hay apiarios registrados para este apicultor.',
                        style: TextStyle(color: Colors.grey),
                      )
                    else
                      Column(
                        children: _apiarios.map((a) {
                          final lugar =
                          (a['lugar_apiario'] ?? '').toString();
                          final lat =
                          (a['latitud'] ?? '').toString();
                          final lng =
                          (a['longitud'] ?? '').toString();
                          final aid = a['id'] ?? '';

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.place_outlined),
                            title: Text(
                              lugar.isEmpty
                                  ? '(Sin lugar)'
                                  : lugar,
                            ),
                            subtitle: Text(
                              'Apiario ID: $aid · Lat: $lat · Lng: $lng',
                            ),
                            trailing: TextButton.icon(
                              onPressed: () => _openMapSingle(a),
                              icon: const Icon(
                                Icons.map_outlined,
                                size: 18,
                              ),
                              label: const Text('Mapa'),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
