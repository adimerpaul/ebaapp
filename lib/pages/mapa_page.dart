import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class MapaPage extends StatefulWidget {
  final String title;
  /// Lista de mapas: { 'lat': '...', 'lng': '...', 'title': '...', 'subtitle': '...' }
  final List<Map<String, dynamic>> markers;

  const MapaPage({
    super.key,
    this.title = 'Mapa',
    this.markers = const [],
  });

  @override
  State<MapaPage> createState() => _MapaPageState();
}

class _MapaPageState extends State<MapaPage> {
  final MapController _mapController = MapController();
  LatLng _initialCenter = const LatLng(-16.5, -68.15); // fallback
  double _initialZoom = 8.5;

  // Tipos de mapa (tu lista)
  final List<Map<String, String>> _mapTypes = const [
    {'name': 'Normal',  'url': 'https://mt1.google.com/vt/lyrs=r&x={x}&y={y}&z={z}'},
    {'name': 'Satélite','url': 'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}'},
    {'name': 'Híbrido', 'url': 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}'},
    {'name': 'Terreno', 'url': 'https://mt1.google.com/vt/lyrs=p&x={x}&y={y}&z={z}'},
  ];
  int _currentTypeIndex = 0; // Normal por defecto

  @override
  void initState() {
    super.initState();
    final first = _firstValidLatLng(widget.markers);
    if (first != null) {
      _initialCenter = first;
      _initialZoom = 11.5;
    }
  }

  LatLng? _firstValidLatLng(List<Map<String, dynamic>> list) {
    for (final m in list) {
      final lat = double.tryParse((m['lat'] ?? '').toString());
      final lng = double.tryParse((m['lng'] ?? '').toString());
      if (lat != null && lng != null) return LatLng(lat, lng);
    }
    return null;
  }

  List<Marker> _buildMarkers() {
    return widget.markers.map((m) {
      final lat = double.tryParse((m['lat'] ?? '').toString());
      final lng = double.tryParse((m['lng'] ?? '').toString());
      if (lat == null || lng == null) {
        return const Marker(point: LatLng(0, 0), child: SizedBox.shrink());
      }
      final title = (m['title'] ?? '').toString();
      final subtitle = (m['subtitle'] ?? '').toString();
      final point = LatLng(lat, lng);

      return Marker(
        point: point,
        width: 38,
        height: 38,
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: () => _showMarkerSheet(point, title, subtitle),
          child: const Icon(Icons.location_on, size: 36, color: Colors.redAccent),
        ),
      );
    }).toList();
  }

  void _showMarkerSheet(LatLng point, String title, String subtitle) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.place, color: Colors.redAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title.isEmpty ? 'Ubicación' : title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (subtitle.isNotEmpty) Text(subtitle),
            const SizedBox(height: 8),
            Text(
              'Lat: ${point.latitude.toStringAsFixed(6)}  ·  Lng: ${point.longitude.toStringAsFixed(6)}',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openInGoogleMaps(point, label: title),
                icon: const Icon(Icons.directions),
                label: const Text('Abrir en Google Maps'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _fitToMarkers() {
    final valid = widget.markers
        .map((m) {
      final lat = double.tryParse((m['lat'] ?? '').toString());
      final lng = double.tryParse((m['lng'] ?? '').toString());
      if (lat == null || lng == null) return null;
      return LatLng(lat, lng);
    })
        .whereType<LatLng>()
        .toList();

    if (valid.isEmpty) return;

    if (valid.length == 1) {
      _mapController.move(valid.first, 14);
      return;
    }

    double minLat = valid.first.latitude, maxLat = valid.first.latitude;
    double minLng = valid.first.longitude, maxLng = valid.first.longitude;
    for (final p in valid.skip(1)) {
      minLat = p.latitude < minLat ? p.latitude : minLat;
      maxLat = p.latitude > maxLat ? p.latitude : maxLat;
      minLng = p.longitude < minLng ? p.longitude : minLng;
      maxLng = p.longitude > maxLng ? p.longitude : maxLng;
    }

    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    _mapController.move(center, 10);
  }

  Future<void> _openInGoogleMaps(LatLng point, {String? label}) async {
    final lat = point.latitude;
    final lng = point.longitude;
    // final Uri uriNav = Uri.parse('google.navigation:q=$lat,$lng');
    // final Uri uriGeo = Uri.parse('geo:$lat,$lng?q=${Uri.encodeComponent(label ?? '$lat,$lng')}');
    final Uri uriWeb = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');

    if (!await launchUrl(uriWeb, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $uriWeb');
    }
    // print('aa');
    //
    // try {
    //   await launchUrl(uriNav, mode: LaunchMode.externalApplication);
    // } catch (_) {
    //   try {
    //     await launchUrl(uriGeo, mode: LaunchMode.externalApplication);
    //   } catch (_) {
    //     await launchUrl(uriWeb, mode: LaunchMode.externalApplication);
    //   }
    // }
  }

  void _openDirectionsToFirst() {
    final first = _firstValidLatLng(widget.markers) ?? _initialCenter;
    _openInGoogleMaps(first, label: widget.title);
  }

  @override
  Widget build(BuildContext context) {
    final markers = _buildMarkers();
    final tileUrl = _mapTypes[_currentTypeIndex]['url']!;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          // Selector de tipo de mapa en AppBar
          PopupMenuButton<int>(
            tooltip: 'Tipo de mapa',
            icon: const Icon(Icons.layers_outlined),
            onSelected: (i) => setState(() => _currentTypeIndex = i),
            itemBuilder: (context) => List.generate(_mapTypes.length, (i) {
              final name = _mapTypes[i]['name']!;
              final selected = i == _currentTypeIndex;
              return PopupMenuItem<int>(
                value: i,
                child: Row(
                  children: [
                    if (selected) const Icon(Icons.check, size: 18),
                    if (selected) const SizedBox(width: 6),
                    Text(name),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _initialCenter,
          initialZoom: _initialZoom,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: tileUrl,
            subdomains: const ['a', 'b', 'c'],
            userAgentPackageName: 'com.example.app',
          ),
          MarkerLayer(markers: markers),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'fit',
            onPressed: _fitToMarkers,
            label: const Text('Ajustar'),
            icon: const Icon(Icons.center_focus_strong),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'gmaps',
            onPressed: _openDirectionsToFirst,
            label: const Text('Google Maps'),
            icon: const Icon(Icons.directions),
          ),
        ],
      ),
    );
  }
}
