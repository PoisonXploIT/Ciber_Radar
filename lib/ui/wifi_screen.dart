
import 'package:flutter/material.dart';
import '../services/scanner_service.dart';
import '../models/wifi_entity.dart';
import 'theme.dart';

class WifiScreen extends StatefulWidget {
  final ScannerService scannerService;
  const WifiScreen({super.key, required this.scannerService});

  @override
  State<WifiScreen> createState() => _WifiScreenState();
}

class _WifiScreenState extends State<WifiScreen> {
  // Store results locally for persistence during session
  // List<WifiEntity> _results = []; 
  Stream<List<WifiEntity>>? _stream;
  bool _onlyVulnerable = false;

  @override
  void initState() {
    super.initState();
    _stream = widget.scannerService.wifiResultsStream;
  }

  Color _getSecurityColor(WifiEntity wifi) {
    final caps = wifi.capabilities.toUpperCase();
    if (caps.contains("WEP") || (caps.contains("ESS") && !caps.contains("WPA") && !caps.contains("SAE") && !caps.contains("RSN"))) {
       return AppTheme.accent; // Red - Insegura (Open/WEP)
    }
    if (caps.contains("SAE")) return Colors.greenAccent; // Green - WPA3
    return AppTheme.textHigh; // White/Standard - WPA2/Otherwise
  }
  
  String _getSecurityText(WifiEntity wifi) {
    if (wifi.isOpen) return "OPEN NETWORK";
    if (wifi.isWep) return "WEP - LEGACY";
    final caps = wifi.capabilities.toUpperCase();
    if (caps.contains("SAE")) return "WPA3 - SECURE";
    if (caps.contains("WPA")) return "WPA/WPA2";
    return wifi.capabilities;
  }
  
  IconData _getSecurityIcon(WifiEntity wifi) {
    if (wifi.isOpen) return Icons.lock_open;
    if (wifi.isWep) return Icons.no_encryption;
    final caps = wifi.capabilities.toUpperCase();
    if (caps.contains("SAE")) return Icons.verified_user;
    return Icons.lock;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Expanded(
                 child: Text("WIFI NETWORKS", style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 18), overflow: TextOverflow.ellipsis),
               ),
               Row(
                 mainAxisSize: MainAxisSize.min, // Essential for Row inside Row/SpaceBetween
                 children: [
                    const Icon(Icons.warning, color: AppTheme.accent, size: 16),
                    const SizedBox(width: 4),
                    const Text("VULN ONLY", style: TextStyle(color: AppTheme.textHigh, fontWeight: FontWeight.bold, fontSize: 12)),
                    Switch(
                      value: _onlyVulnerable,
                      onChanged: (val) => setState(() => _onlyVulnerable = val),
                      activeColor: AppTheme.accent,
                      activeTrackColor: AppTheme.accent.withOpacity(0.3),
                    ),
                 ],
               )
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<WifiEntity>>(
            stream: _stream,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                var list = snapshot.data!;
                
                if (_onlyVulnerable) {
                   list = list.where((w) => w.isOpen || w.isWep).toList();
                }

                if (list.isEmpty) {
                   return const Center(child: Text("NO NETWORKS FOUND"));
                }
                
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final wifi = list[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: Icon(_getSecurityIcon(wifi), color: _getSecurityColor(wifi)),
                        title: Text(wifi.ssid.isEmpty ? "<HIDDEN>" : wifi.ssid, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis, maxLines: 1),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("BSSID: ${wifi.bssid}", style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 11)),
                            if (wifi.manufacturer != null)
                               Text("Mfr: ${wifi.manufacturer}", style: const TextStyle(color: Colors.cyanAccent, fontSize: 11), overflow: TextOverflow.ellipsis, maxLines: 1),
                            Text("RSSI: ${wifi.rssi} dBm", style: TextStyle(color: _getSecurityColor(wifi), fontSize: 11)),
                            Text(_getSecurityText(wifi), style: TextStyle(fontSize: 10, color: _getSecurityColor(wifi))),
                          ],
                        ),
                        trailing: Text("${wifi.frequency} MHz"),
                      ),
                    );
                  },
                );
              }
              return const Center(child: Text("SCANNING..."));
            },
          ),
        ),
      ],
    );
  }
}
