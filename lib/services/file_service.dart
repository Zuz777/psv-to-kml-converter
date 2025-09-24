import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

class FileService {
  /// Проверяет и запрашивает необходимые разрешения
  static Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final storagePermission = await Permission.storage.request();
      final manageExternalStoragePermission = 
          await Permission.manageExternalStorage.request();
      
      return storagePermission.isGranted || 
             manageExternalStoragePermission.isGranted;
    }
    return true; // На iOS разрешения не требуются для Documents Directory
  }

  /// Сохраняет KML файл в доступную для пользователя папку
  static Future<File> saveKMLToPublicDirectory(String kmlContent, String fileName) async {
    Directory? directory;
    
    if (Platform.isAndroid) {
      // Попробуем сохранить в Downloads
      directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) {
        // Если Downloads недоступна, используем external storage
        directory = await getExternalStorageDirectory();
      }
    } else {
      // На iOS используем Documents Directory
      directory = await getApplicationDocumentsDirectory();
    }

    if (directory == null) {
      throw Exception('Не удалось получить доступ к хранилищу');
    }

    // Убеждаемся что папка существует
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    // Создаем уникальное имя файла если такой уже существует
    String finalFileName = fileName;
    int counter = 1;
    File file = File('${directory.path}/$finalFileName');
    
    while (await file.exists()) {
      final nameWithoutExtension = fileName.replaceAll('.kml', '');
      finalFileName = '${nameWithoutExtension}_$counter.kml';
      file = File('${directory.path}/$finalFileName');
      counter++;
    }

    await file.writeAsString(kmlContent);
    return file;
  }

  /// Поделиться KML файлом
  static Future<void> shareKMLFile(File kmlFile) async {
    try {
      await Share.shareXFiles(
        [XFile(kmlFile.path)],
        text: 'GPS трек в формате KML',
        subject: 'GPS трек',
      );
    } catch (e) {
      throw Exception('Ошибка при попытке поделиться файлом: $e');
    }
  }

  /// Получает размер файла в читаемом формате
  static String getFileSize(File file) {
    final bytes = file.lengthSync();
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  /// Проверяет является ли файл PSV файлом
  static bool isPSVFile(String filePath) {
    return filePath.toLowerCase().endsWith('.psv');
  }

  /// Читает первые несколько строк файла для валидации
  static Future<bool> validatePSVFile(File file) async {
    try {
      final lines = await file.readAsLines();
      
      if (lines.isEmpty) return false;
      
      // Проверяем первые несколько строк на корректный формат PSV
      int validLines = 0;
      for (int i = 0; i < (lines.length < 5 ? lines.length : 5); i++) {
        final parts = lines[i].trim().split('\t');
        if (parts.length >= 4) {
          try {
            double.parse(parts[0]); // timestamp
            double.parse(parts[1]); // latitude
            double.parse(parts[2]); // longitude  
            double.parse(parts[3]); // altitude
            validLines++;
          } catch (e) {
            // Пропускаем некорректные строки
          }
        }
      }
      
      // Считаем файл валидным если хотя бы половина проверенных строк корректны
      return validLines > 0 && (validLines / (lines.length < 5 ? lines.length : 5)) >= 0.5;
    } catch (e) {
      return false;
    }
  }

  /// Создает временный файл для обработки
  static Future<File> createTempFile(String content, String fileName) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsString(content);
    return file;
  }

  /// Очищает временные файлы
  static Future<void> cleanupTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final files = tempDir.listSync();
      
      for (final file in files) {
        if (file is File && 
            (file.path.endsWith('.psv') || file.path.endsWith('.kml'))) {
          await file.delete();
        }
      }
    } catch (e) {
      // Игнорируем ошибки при очистке
    }
  }
}
