import 'dart:io';
import 'dart:math' as math;
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/track_data.dart';
import '../models/conversion_result.dart';

class PSVConverter {
  static const double earthRadius = 6371000; // Радиус Земли в метрах
  final Set<String> _usedColors = <String>{};

  /// Конвертирует PSV файл в KML и возвращает результат
  Future<ConversionResult> convertPSVToKML(File psvFile) async {
    try {
      final lines = await psvFile.readAsLines();
      final trackData = _parsePSVData(lines);
      
      if (trackData.points.isEmpty) {
        throw Exception('PSV файл не содержит валидных GPS точек');
      }

      final kmlContent = _generateKMLContent(trackData);
      final kmlFile = await _saveKMLFile(kmlContent, psvFile.path);

      return ConversionResult(
        originalFile: psvFile,
        kmlFile: kmlFile,
        trackData: trackData,
        success: true,
      );
    } catch (e) {
      return ConversionResult(
        originalFile: psvFile,
        kmlFile: null,
        trackData: null,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Парсит данные из PSV файла
  TrackData _parsePSVData(List<String> lines) {
    final points = <TrackPoint>[];
    double totalDistance = 0;
    TrackPoint? lastPoint;

    for (final line in lines) {
      final parts = line.trim().split('\t');
      if (parts.length >= 4) {
        try {
          final timestamp = double.parse(parts[0]);
          final lat = double.parse(parts[1]);
          final lon = double.parse(parts[2]);
          final alt = double.parse(parts[3]);

          if (lastPoint != null) {
            final distance = _calculateDistance(
              lastPoint.latitude,
              lastPoint.longitude,
              lat,
              lon,
            );
            totalDistance += distance;
          }

          final point = TrackPoint(
            timestamp: timestamp,
            latitude: lat,
            longitude: lon,
            altitude: alt,
            distanceFromStart: totalDistance,
          );

          points.add(point);
          lastPoint = point;
        } catch (e) {
          // Пропускаем некорректные строки
          continue;
        }
      }
    }

    return TrackData(
      points: points,
      totalDistance: totalDistance,
      duration: points.isNotEmpty 
          ? points.last.timestamp - points.first.timestamp 
          : 0,
    );
  }

  /// Генерирует содержимое KML файла
  String _generateKMLContent(TrackData trackData) {
    final color = _getRandomColor();
    final coordinates = trackData.points
        .map((p) => '${p.longitude},${p.latitude},${p.altitude}')
        .join(' ');

    final placemarks = _generatePlacemarks(trackData);
    final fileName = 'GPS_Track_${DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now())}';

    return '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <name>$fileName</name>
    <Style id="trackStyle">
      <LineStyle>
        <color>$color</color>
        <width>4</width>
      </LineStyle>
      <PolyStyle>
        <color>$color</color>
      </PolyStyle>
    </Style>
    <Placemark>
      <name>$fileName Track</name>
      <styleUrl>#trackStyle</styleUrl>
      <LineString>
        <extrude>1</extrude>
        <tessellate>1</tessellate>
        <altitudeMode>absolute</altitudeMode>
        <coordinates>$coordinates</coordinates>
      </LineString>
    </Placemark>
    <Folder>
      <name>Временные метки</name>
      $placemarks
    </Folder>
  </Document>
</kml>''';
  }

  /// Генерирует метки для KML
  String _generatePlacemarks(TrackData trackData) {
    final buffer = StringBuffer();
    final points = trackData.points;
    
    if (points.isEmpty) return '';

    final startTime = points.first.timestamp;
    
    // Стартовая метка
    final firstPoint = points.first;
    buffer.writeln('''
    <Placemark>
      <name>00:00 (0м)</name>
      <Point>
        <coordinates>${firstPoint.longitude},${firstPoint.latitude},${firstPoint.altitude}</coordinates>
      </Point>
    </Placemark>''');

    // Метки каждые 5 минут или 1000 метров
    const timeInterval = 300; // 5 минут в секундах
    const distanceInterval = 1000; // 1000 метров

    double lastMarkTime = startTime;
    double lastMarkDistance = 0;

    for (final point in points) {
      final relativeTime = point.timestamp - startTime;
      final shouldAddTimeMarker = relativeTime - (lastMarkTime - startTime) >= timeInterval;
      final shouldAddDistanceMarker = point.distanceFromStart - lastMarkDistance >= distanceInterval;

      if (shouldAddTimeMarker || shouldAddDistanceMarker) {
        final timeStr = _formatRelativeTime(relativeTime);
        final distanceStr = _formatDistance(point.distanceFromStart);

        buffer.writeln('''
    <Placemark>
      <name>$timeStr ($distanceStr)</name>
      <Point>
        <coordinates>${point.longitude},${point.latitude},${point.altitude}</coordinates>
      </Point>
    </Placemark>''');

        lastMarkTime = point.timestamp;
        lastMarkDistance = point.distanceFromStart;
      }
    }

    // Финальная метка
    final lastPoint = points.last;
    final finalTime = lastPoint.timestamp - startTime;
    final finalTimeStr = _formatRelativeTime(finalTime);
    final finalDistanceStr = _formatDistance(lastPoint.distanceFromStart);

    if (lastPoint.timestamp != lastMarkTime) {
      buffer.writeln('''
    <Placemark>
      <name>$finalTimeStr ($finalDistanceStr)</name>
      <Point>
        <coordinates>${lastPoint.longitude},${lastPoint.latitude},${lastPoint.altitude}</coordinates>
      </Point>
    </Placemark>''');
    }

    return buffer.toString();
  }

  /// Сохраняет KML файл
  Future<File> _saveKMLFile(String kmlContent, String originalPath) async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'converted_${DateTime.now().millisecondsSinceEpoch}.kml';
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(kmlContent, encoding: utf8);
    return file;
  }

  /// Вычисляет расстояние между двумя точками
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    final lat1Rad = lat1 * math.pi / 180;
    final lon1Rad = lon1 * math.pi / 180;
    final lat2Rad = lat2 * math.pi / 180;
    final lon2Rad = lon2 * math.pi / 180;

    final dLat = lat2Rad - lat1Rad;
    final dLon = lon2Rad - lon1Rad;

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) * 
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  /// Форматирует время в формат ММ:СС
  String _formatRelativeTime(double seconds) {
    final totalMinutes = (seconds ~/ 60);
    final remainingSeconds = (seconds % 60).round();
    return '${totalMinutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  /// Форматирует расстояние
  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()}м';
    } else {
      return '${(meters / 1000).toStringAsFixed(2)}км';
    }
  }

  /// Генерирует случайный яркий цвет в формате ABGR
  String _getRandomColor() {
    if (_usedColors.length > 1000) {
      _usedColors.clear();
    }

    String color;
    do {
      final hue = math.Random().nextDouble();
      final saturation = 0.8 + math.Random().nextDouble() * 0.2;
      final value = 0.8 + math.Random().nextDouble() * 0.2;
      
      final rgb = _hsvToRgb(hue, saturation, value);
      final red = (rgb[0] * 255).round();
      final green = (rgb[1] * 255).round();
      final blue = (rgb[2] * 255).round();
      const alpha = 255;

      color = '${alpha.toRadixString(16).padLeft(2, '0')}'
              '${blue.toRadixString(16).padLeft(2, '0')}'
              '${green.toRadixString(16).padLeft(2, '0')}'
              '${red.toRadixString(16).padLeft(2, '0')}';
    } while (_usedColors.contains(color));

    _usedColors.add(color);
    return color;
  }

  /// Конвертирует HSV в RGB
  List<double> _hsvToRgb(double h, double s, double v) {
    final c = v * s;
    final x = c * (1 - ((h * 6) % 2 - 1).abs());
    final m = v - c;

    double r, g, b;
    
    if (h < 1/6) {
      r = c; g = x; b = 0;
    } else if (h < 2/6) {
      r = x; g = c; b = 0;
    } else if (h < 3/6) {
      r = 0; g = c; b = x;
    } else if (h < 4/6) {
      r = 0; g = x; b = c;
    } else if (h < 5/6) {
      r = x; g = 0; b = c;
    } else {
      r = c; g = 0; b = x;
    }

    return [r + m, g + m, b + m];
  }
}
