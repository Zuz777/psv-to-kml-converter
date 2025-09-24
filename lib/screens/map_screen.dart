import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import '../models/track_data.dart';

class MapScreen extends StatefulWidget {
  final TrackData trackData;

  const MapScreen({
    super.key,
    required this.trackData,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  late MapController _mapController;
  late AnimationController _animationController;
  bool _showMarkers = true;
  bool _showTrack = true;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.trackData.points;
    if (points.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Карта трека')),
        body: const Center(
          child: Text('Нет данных для отображения'),
        ),
      );
    }

    // Вычисляем границы карты
    final bounds = _calculateBounds(points);
    final center = LatLng(
      (bounds.north + bounds.south) / 2,
      (bounds.east + bounds.west) / 2,
    );

    // Создаем список точек для отображения трека
    final trackPoints = points
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    // Создаем маркеры для ключевых точек
    final markers = _createMarkers(points);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Карта трека'),
        actions: [
          IconButton(
            icon: Icon(_showMarkers ? Icons.place : Icons.place_outlined),
            onPressed: () {
              setState(() {
                _showMarkers = !_showMarkers;
              });
            },
            tooltip: _showMarkers ? 'Скрыть метки' : 'Показать метки',
          ),
          IconButton(
            icon: Icon(_showTrack ? Icons.route : Icons.route_outlined),
            onPressed: () {
              setState(() {
                _showTrack = !_showTrack;
              });
            },
            tooltip: _showTrack ? 'Скрыть трек' : 'Показать трек',
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'fit_bounds',
                child: ListTile(
                  leading: Icon(Icons.fit_screen),
                  title: Text('Показать весь трек'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'share',
                child: ListTile(
                  leading: Icon(Icons.share),
                  title: Text('Поделиться'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 13.0,
              minZoom: 3.0,
              maxZoom: 18.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.psv_to_kml_converter',
              ),
              if (_showTrack)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: trackPoints,
                      strokeWidth: 4.0,
                      color: Colors.blue.withOpacity(0.8),
                    ),
                  ],
                ),
              if (_showMarkers)
                MarkerLayer(markers: markers),
            ],
          ),
          _buildInfoPanel(),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: "fit_bounds",
            mini: true,
            onPressed: () => _fitBounds(bounds),
            child: const Icon(Icons.fit_screen),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: "my_location",
            mini: true,
            onPressed: _centerOnStart,
            child: const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPanel() {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -1),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeOut,
        )),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Информация о треке',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _InfoChip(
                      icon: Icons.straighten,
                      label: _formatDistance(widget.trackData.totalDistance),
                      subtitle: 'Расстояние',
                    ),
                    _InfoChip(
                      icon: Icons.timer,
                      label: _formatDuration(widget.trackData.duration),
                      subtitle: 'Время',
                    ),
                    _InfoChip(
                      icon: Icons.place,
                      label: '${widget.trackData.pointCount}',
                      subtitle: 'Точек',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Marker> _createMarkers(List<TrackPoint> points) {
    final markers = <Marker>[];
    
    if (points.isEmpty) return markers;

    // Стартовая точка
    markers.add(
      Marker(
        point: LatLng(points.first.latitude, points.first.longitude),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: const Icon(
            Icons.play_arrow,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );

    // Финишная точка
    if (points.length > 1) {
      markers.add(
        Marker(
          point: LatLng(points.last.latitude, points.last.longitude),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(
              Icons.stop,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      );
    }

    // Промежуточные метки каждые 1000 метров
    double lastMarkerDistance = 0;
    const markerInterval = 1000.0; // метров

    for (final point in points) {
      if (point.distanceFromStart - lastMarkerDistance >= markerInterval) {
        markers.add(
          Marker(
            point: LatLng(point.latitude, point.longitude),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: Text(
                '${(point.distanceFromStart / 1000).toStringAsFixed(1)}км',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
        lastMarkerDistance = point.distanceFromStart;
      }
    }

    return markers;
  }

  LatLngBounds _calculateBounds(List<TrackPoint> points) {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      minLat = minLat < point.latitude ? minLat : point.latitude;
      maxLat = maxLat > point.latitude ? maxLat : point.latitude;
      minLng = minLng < point.longitude ? minLng : point.longitude;
      maxLng = maxLng > point.longitude ? maxLng : point.longitude;
    }

    return LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );
  }

  void _fitBounds(LatLngBounds bounds) {
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(50),
      ),
    );
  }

  void _centerOnStart() {
    final firstPoint = widget.trackData.points.first;
    _mapController.move(
      LatLng(firstPoint.latitude, firstPoint.longitude),
      15.0,
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'fit_bounds':
        _fitBounds(_calculateBounds(widget.trackData.points));
        break;
      case 'share':
        _shareTrack();
        break;
    }
  }

  void _shareTrack() {
    final firstPoint = widget.trackData.points.first;
    final distance = _formatDistance(widget.trackData.totalDistance);
    final duration = _formatDuration(widget.trackData.duration);
    
    Share.share(
      'Мой GPS трек:\n'
      'Расстояние: $distance\n'
      'Время: $duration\n'
      'Точек: ${widget.trackData.pointCount}\n'
      'Начальная точка: ${firstPoint.latitude.toStringAsFixed(6)}, ${firstPoint.longitude.toStringAsFixed(6)}',
      subject: 'GPS трек',
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} м';
    } else {
      return '${(meters / 1000).toStringAsFixed(2)} км';
    }
  }

  String _formatDuration(double seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;

    if (hours > 0) {
      return '${hours}ч ${minutes}м';
    } else {
      return '${minutes}м';
    }
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
