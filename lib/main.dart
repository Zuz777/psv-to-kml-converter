import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'dart:async';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'screens/home_screen.dart';
import 'services/psv_converter.dart';

void main() {
  runApp(const PSVConverterApp());
}

class PSVConverterApp extends StatelessWidget {
  const PSVConverterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PSV to KML Converter',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      home: const SharingWrapper(),
    );
  }
}

class SharingWrapper extends StatefulWidget {
  const SharingWrapper({super.key});

  @override
  State<SharingWrapper> createState() => _SharingWrapperState();
}

class _SharingWrapperState extends State<SharingWrapper> {
  late StreamSubscription _intentDataStreamSubscription;
  final PSVConverter _converter = PSVConverter();

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _initSharingIntent();
  }

  Future<void> _requestPermissions() async {
    await Permission.storage.request();
    await Permission.manageExternalStorage.request();
  }

  void _initSharingIntent() {
    // Для файлов, переданных при запуске приложения
    ReceiveSharingIntent.getInitialMedia().then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _handleSharedFiles(value);
      }
    });

    // Для файлов, переданных когда приложение уже запущено
    _intentDataStreamSubscription = ReceiveSharingIntent.getMediaStream()
        .listen((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _handleSharedFiles(value);
      }
    });
  }

  void _handleSharedFiles(List<SharedMediaFile> files) {
    for (final file in files) {
      if (file.path.toLowerCase().endsWith('.psv')) {
        _processSharedFile(file.path);
        break; // Обрабатываем только первый PSV файл
      }
    }
  }

  Future<void> _processSharedFile(String filePath) async {
    try {
      final result = await _converter.convertPSVToKML(File(filePath));
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => HomeScreen(
              initialConversionResult: result,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка обработки файла: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _intentDataStreamSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const HomeScreen();
  }
}
