class TrackData {
  final List<TrackPoint> points;
  final double totalDistance;
  final double duration;

  const TrackData({
    required this.points,
    required this.totalDistance,
    required this.duration,
  });

  TrackPoint? get firstPoint => points.isNotEmpty ? points.first : null;
  TrackPoint? get lastPoint => points.isNotEmpty ? points.last : null;
  
  int get pointCount => points.length;
  
  double get averageSpeed => duration > 0 ? totalDistance / duration : 0;
}

class TrackPoint {
  final double timestamp;
  final double latitude;
  final double longitude;
  final double altitude;
  final double distanceFromStart;

  const TrackPoint({
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.distanceFromStart,
  });

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch((timestamp * 1000).round());
}
