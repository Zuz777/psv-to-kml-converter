import 'dart:io';
import 'track_data.dart';

class ConversionResult {
  final File originalFile;
  final File? kmlFile;
  final TrackData? trackData;
  final bool success;
  final String? error;

  const ConversionResult({
    required this.originalFile,
    required this.kmlFile,
    required this.trackData,
    required this.success,
    this.error,
  });

  String get originalFileName => originalFile.path.split('/').last;
  String? get kmlFileName => kmlFile?.path.split('/').last;
}
