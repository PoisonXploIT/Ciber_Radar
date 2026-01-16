
import 'package:flutter/material.dart';
import '../services/sensor_service.dart';
import 'theme.dart';

class MagneticScreen extends StatefulWidget {
  const MagneticScreen({super.key});

  @override
  State<MagneticScreen> createState() => _MagneticScreenState();
}

class _MagneticScreenState extends State<MagneticScreen> {
  final SensorService _sensorService = SensorService();

  Color _getStatusColor(double value) {
    if (value < 60) return Colors.greenAccent; // Safe
    if (value < 100) return Colors.amber; // Warning
    return AppTheme.accent; // Danger (Red)
  }

  String _getStatusText(double value) {
    if (value < 60) return "SAFE Environment";
    if (value < 100) return "METALLIC INTERFERENCE";
    return "POSSIBLE DEVICE DETECTED";
  }

  IconData _getStatusIcon(double value) {
    if (value < 60) return Icons.verified_user;
    if (value < 100) return Icons.warning_amber;
    return Icons.error_outline;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "MAGNETIC FIELD SCANNER",
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.textMedium),
        ),
        const SizedBox(height: 40),
        StreamBuilder<double>(
          stream: _sensorService.magneticField,
          initialData: 0.0,
          builder: (context, snapshot) {
            final value = snapshot.data ?? 0.0;
            final color = _getStatusColor(value);
            
            return Column(
              children: [
                Icon(_getStatusIcon(value), size: 100, color: color),
                const SizedBox(height: 20),
                Text(
                  "${value.toStringAsFixed(1)} µT",
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'JetBrains Mono',
                    color: color,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: color),
                    borderRadius: BorderRadius.circular(8),
                    color: color.withOpacity(0.1),
                  ),
                  child: Text(
                    _getStatusText(value),
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                ),
                const SizedBox(height: 50),
                // Visualization Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: LinearProgressIndicator(
                    value: (value / 300).clamp(0.0, 1.0),
                    backgroundColor: AppTheme.secondary,
                    color: color,
                    minHeight: 10,
                  ),
                ),
                 const SizedBox(height: 10),
                 const Text("0 µT                                                  300+ µT", style: TextStyle(color: AppTheme.textMedium, fontSize: 10)),
              ],
            );
          },
        ),
      ],
    );
  }
}
