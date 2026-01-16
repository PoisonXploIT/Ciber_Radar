
import 'package:flutter/material.dart';
import '../services/scanner_service.dart';
import '../models/bluetooth_entity.dart';
import 'theme.dart';

class BluetoothScreen extends StatefulWidget {
  final ScannerService scannerService;
  const BluetoothScreen({super.key, required this.scannerService});

  @override
  State<BluetoothScreen> createState() => _BluetoothScreenState();
}

class _BluetoothScreenState extends State<BluetoothScreen> {
  Stream<List<BluetoothEntity>>? _stream;

  @override
  void initState() {
    super.initState();
    _stream = widget.scannerService.bleResultsStream;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text("DISPOSITIVOS BLUETOOTH", style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 18)),
        ),
        Expanded(
          child: StreamBuilder<List<BluetoothEntity>>(
            stream: _stream,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final list = snapshot.data!;
                 if (list.isEmpty) {
                   return const Center(child: Text("ESCANEA PARA VER DISPOSITIVOS..."));
                }
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final device = list[index];
                    final isRandom = device.manufacturer == "Private/Random";
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: Icon(isRandom ? Icons.lock_outline : Icons.bluetooth, color: isRandom ? Colors.amber : AppTheme.primary),
                        title: Text(device.name, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis, maxLines: 1),
                        subtitle: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text("MAC: ${device.mac}", style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 11)),
                             if (device.manufacturer != null)
                                Row(
                                  children: [
                                    if (isRandom) const Icon(Icons.privacy_tip, size: 12, color: Colors.amber),
                                    if (isRandom) const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        isRandom ? "Private Address" : "Mfr: ${device.manufacturer}", 
                                        style: TextStyle(
                                          color: isRandom ? Colors.amber : Colors.cyanAccent, 
                                          fontSize: 11,
                                          fontWeight: isRandom ? FontWeight.bold : FontWeight.normal,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                  ],
                                ),
                             Text("Type: ${device.type}", style: const TextStyle(fontSize: 10)),
                           ],
                        ),
                        trailing: Text("${device.rssi} dBm", style: const TextStyle(color: AppTheme.primary)),
                      ),
                    );
                  },
                );
              }
              return const Center(child: Text("ESPERANDO DATOS..."));
            },
          ),
        ),
      ],
    );
  }
}
