import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../services/psv_converter.dart';
import '../services/file_service.dart';
import '../models/conversion_result.dart';
import 'map_screen.dart';

class HomeScreen extends StatefulWidget {
  final ConversionResult? initialConversionResult;

  const HomeScreen({
    super.key,
    this.initialConversionResult,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final PSVConverter _converter = PSVConverter();
  ConversionResult? _currentResult;
  bool _isConverting = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _currentResult = widget.initialConversionResult;
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _pickAndConvertFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['psv'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _isConverting = true;
        });

        final file = File(result.files.single.path!);
        final conversionResult = await _converter.convertPSVToKML(file);

        setState(() {
          _currentResult = conversionResult;
          _isConverting = false;
        });

        if (!conversionResult.success) {
          _showErrorSnackBar(conversionResult.error ?? 'Неизвестная ошибка');
        }
      }
    } catch (e) {
      setState(() {
        _isConverting = false;
      });
      _showErrorSnackBar('Ошибка выбора файла: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PSV to KML Converter',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: _isConverting
            ? const _LoadingWidget()
            : _currentResult == null
                ? _WelcomeWidget(onPickFile: _pickAndConvertFile)
                : _ResultWidget(
                    result: _currentResult!,
                    onNewFile: _pickAndConvertFile,
                    onShowSuccess: _showSuccessSnackBar,
                  ),
      ),
    );
  }
}

class _LoadingWidget extends StatelessWidget {
  const _LoadingWidget();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Конвертирую файл...',
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _WelcomeWidget extends StatelessWidget {
  final VoidCallback onPickFile;

  const _WelcomeWidget({required this.onPickFile});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.map,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Конвертер PSV в KML',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Конвертируйте ваши GPS треки из формата PSV в KML и просматривайте их на карте',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: onPickFile,
              icon: const Icon(Icons.file_upload),
              label: const Text('Выбрать PSV файл'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(
                      Icons.share,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Поделиться файлом',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Вы также можете поделиться PSV файлом с этим приложением из любого файлового менеджера',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
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

class _ResultWidget extends StatelessWidget {
  final ConversionResult result;
  final VoidCallback onNewFile;
  final Function(String) onShowSuccess;

  const _ResultWidget({
    required this.result,
    required this.onNewFile,
    required this.onShowSuccess,
  });

  @override
  Widget build(BuildContext context) {
    if (!result.success) {
      return _ErrorResultWidget(
        error: result.error ?? 'Неизвестная ошибка',
        onTryAgain: onNewFile,
      );
    }

    return _SuccessResultWidget(
      result: result,
      onNewFile: onNewFile,
      onShowSuccess: onShowSuccess,
    );
  }
}

class _ErrorResultWidget extends StatelessWidget {
  final String error;
  final VoidCallback onTryAgain;

  const _ErrorResultWidget({
    required this.error,
    required this.onTryAgain,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Ошибка конвертации',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onTryAgain,
              icon: const Icon(Icons.refresh),
              label: const Text('Попробовать снова'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessResultWidget extends StatelessWidget {
  final ConversionResult result;
  final VoidCallback onNewFile;
  final Function(String) onShowSuccess;

  const _SuccessResultWidget({
    required this.result,
    required this.onNewFile,
    required this.onShowSuccess,
  });

  @override
  Widget build(BuildContext context) {
    final trackData = result.trackData!;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Конвертация завершена успешно!',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _InfoRow(
                    icon: Icons.file_present,
                    label: 'Исходный файл',
                    value: result.originalFileName,
                  ),
                  _InfoRow(
                    icon: Icons.place,
                    label: 'Точек GPS',
                    value: '${trackData.pointCount}',
                  ),
                  _InfoRow(
                    icon: Icons.straighten,
                    label: 'Общее расстояние',
                    value: _formatDistance(trackData.totalDistance),
                  ),
                  _InfoRow(
                    icon: Icons.timer,
                    label: 'Длительность',
                    value: _formatDuration(trackData.duration),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _showOnMap(context),
                  icon: const Icon(Icons.map),
                  label: const Text('Показать на карте'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => _exportKML(context),
                  icon: const Icon(Icons.download),
                  label: const Text('Экспорт KML'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onNewFile,
            icon: const Icon(Icons.add),
            label: const Text('Конвертировать новый файл'),
          ),
        ],
      ),
    );
  }

  void _showOnMap(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreen(trackData: result.trackData!),
      ),
    );
  }

  void _exportKML(BuildContext context) async {
    try {
      if (result.kmlFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('KML файл не найден'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Читаем содержимое KML файла
      final kmlContent = await result.kmlFile!.readAsString();
      final fileName = result.kmlFileName ?? 'track.kml';
      
      // Сохраняем в публичную папку
      final savedFile = await FileService.saveKMLToPublicDirectory(kmlContent, fileName);
      
      // Показываем диалог с опциями
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('KML файл сохранен'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Файл сохранен:\n${savedFile.path}'),
                const SizedBox(height: 16),
                Text('Размер: ${FileService.getFileSize(savedFile)}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Закрыть'),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await FileService.shareKMLFile(savedFile);
                },
                child: const Text('Поделиться'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка сохранения файла: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours}ч ${minutes}м';
    } else if (minutes > 0) {
      return '${minutes}м ${secs.round()}с';
    } else {
      return '${secs.round()}с';
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
