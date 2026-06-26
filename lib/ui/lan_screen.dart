import 'dart:async';
import 'package:flutter/material.dart';
import '../services/lan_service.dart';
import '../models/host_model.dart';
import 'theme.dart';

class LanScreen extends StatefulWidget {
  const LanScreen({super.key});

  @override
  State<LanScreen> createState() => _LanScreenState();
}

class _LanScreenState extends State<LanScreen> {
  final LanService _lanService = LanService();
  final Map<String, HostModel> _hostsMap = {};
  bool _isScanning = false;
  String _myIp = "Unknown";
  String _subnet = "Unknown";

  StreamSubscription? _scanSubscription;

  @override
  void initState() {
    super.initState();
    _initNetworkInfo();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initNetworkInfo() async {
    final ip = await _lanService.getIp();
    if (ip != null) {
      if (mounted) {
        setState(() {
           _myIp = ip;
           _subnet = _lanService.getSubnet(ip) ?? "Unknown";
        });
      }
    }
  }

  void _stopScan() {
    _scanSubscription?.cancel();
    _scanSubscription = null;
    if (mounted) {
       setState(() {
         _isScanning = false;
       });
    }
  }

  void _startScan() {
    if (_subnet == "Unknown") {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("NO WIFI CONNECTION"), backgroundColor: AppTheme.accent));
       return;
    }

    _stopScan();

    setState(() {
      _hostsMap.clear();
      _isScanning = true;
    });

    try {
      final stream = _lanService.scan(_subnet);

      _scanSubscription = stream.listen((HostModel host) {
        if (mounted) {
          setState(() {
             _hostsMap[host.ip] = host;
          });
        }
      }, onDone: () {
        if (mounted) {
          setState(() {
             _isScanning = false;
          });
        }
      }, onError: (e) {
         if (mounted) {
           _stopScan();
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("SCAN ERROR: $e"), backgroundColor: AppTheme.accent));
         }
      });
    } catch (e) {
      _stopScan();
    }
  }

  void _clearResults() {
      _stopScan();
      setState(() {
        _hostsMap.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("RESULTADOS BORRADOS")));
  }

  Color _riskColor(String risk) {
    switch (risk) {
      case "HIGH": return AppTheme.accent;
      case "MEDIUM": return AppTheme.warning;
      case "LOW": return AppTheme.primary;
      default: return AppTheme.textMedium;
    }
  }

  IconData _riskIcon(String risk) {
    switch (risk) {
      case "HIGH": return Icons.dangerous;
      case "MEDIUM": return Icons.warning;
      case "LOW": return Icons.check_circle;
      default: return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hosts = _hostsMap.values.toList()
      ..sort((a, b) => b.riskLevel.compareTo(a.riskLevel));

    return Column(
      children: [
        // Header Card
        Card(
          margin: const EdgeInsets.all(16),
          color: AppTheme.secondary.withOpacity(0.2),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("MI IP", style: TextStyle(color: AppTheme.textMedium, fontSize: 12)),
                    Text(_myIp, style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textHigh)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("SUBRED", style: TextStyle(color: AppTheme.textMedium, fontSize: 12)),
                    Row(
                      children: [
                        Text("$_subnet.x", style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete_sweep, color: AppTheme.accent, size: 20),
                          onPressed: _clearResults,
                          tooltip: "Limpiar",
                        )
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        if (_isScanning)
          const Padding(
             padding: EdgeInsets.symmetric(horizontal: 16.0),
             child: Text("Escaneando 15 puertos (IoT, Web, SSH, SMB, Telnet)...", style: TextStyle(color: AppTheme.primary, fontSize: 12)),
          ),

        // Scan Button
        if (_isScanning)
           Padding(
             padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
             child: Column(
                children: [
                    const LinearProgressIndicator(color: AppTheme.primary, backgroundColor: AppTheme.textDim),
                    const SizedBox(height: 8),
                    const Text("Deep scan (TCP + mDNS)...", style: TextStyle(color: AppTheme.primary, fontSize: 10)),
                    const SizedBox(height: 8),
                    OutlinedButton(
                       onPressed: _stopScan,
                       child: const Text("DETENER"),
                    )
                ]
             ),
           )
        else
           Padding(
             padding: const EdgeInsets.symmetric(horizontal: 16.0),
             child: SizedBox(
               width: double.infinity,
               child: ElevatedButton.icon(
                 onPressed: _startScan,
                 icon: const Icon(Icons.radar),
                 label: const Text("INICIAR DEEP SCAN"),
               ),
             ),
           ),

        const SizedBox(height: 10),

        // Results List
        Expanded(
          child: hosts.isEmpty && !_isScanning
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                        Text("PULSA SCAN PARA EMPEZAR", style: TextStyle(color: AppTheme.textMedium)),
                        const SizedBox(height: 10),
                        Text("Subred: $_subnet.0/24", style: const TextStyle(color: AppTheme.textDim, fontSize: 10, fontFamily: 'JetBrains Mono')),
                    ],
                  )
                )
              : ListView.builder(
                  itemCount: hosts.length,
                  itemBuilder: (context, index) {
                    final host = hosts[index];
                    final isGateway = host.ip.endsWith(".1");
                    final hasPorts = host.openPorts.isNotEmpty;
                    final risk = host.riskLevel;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ExpansionTile(
                        leading: Icon(
                            _riskIcon(risk),
                            color: _riskColor(risk),
                        ),
                        title: Text(
                          (host.name != null && host.name != host.ip) ? host.name! : "Dispositivo",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'JetBrains Mono'),
                        ),
                        subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Text(host.ip, style: const TextStyle(fontSize: 11, color: AppTheme.textMedium)),
                                if (hasPorts)
                                  Text("${host.openPorts.length} puertos abiertos",
                                    style: TextStyle(fontSize: 10, color: _riskColor(risk), fontWeight: FontWeight.bold)),
                                Text("Origen: ${host.source}", style: TextStyle(fontSize: 9, color: AppTheme.textDim)),
                            ]
                        ),
                        trailing: isGateway
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.warning.withOpacity(0.2),
                                  border: Border.all(color: AppTheme.warning),
                                  borderRadius: BorderRadius.circular(4)
                                ),
                                child: const Text("GATEWAY", style: TextStyle(
                                  color: AppTheme.warning,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold
                                )),
                              )
                            : (risk != "NONE" ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _riskColor(risk).withOpacity(0.2),
                                  border: Border.all(color: _riskColor(risk)),
                                  borderRadius: BorderRadius.circular(4)
                                ),
                                child: Text(risk, style: TextStyle(color: _riskColor(risk), fontSize: 9, fontWeight: FontWeight.bold)),
                              ) : null),
                        children: [
                          if (hasPorts)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("PUERTOS ABIERTOS", style: TextStyle(fontSize: 10, color: AppTheme.textMedium, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: host.openPorts.map((port) {
                                      final svc = HostModel.portToService(port);
                                      final isRisky = port == 23 || port == 445;
                                      return Chip(
                                        label: Text("$port $svc", style: TextStyle(fontSize: 10, color: isRisky ? AppTheme.accent : AppTheme.textHigh)),
                                        backgroundColor: isRisky ? AppTheme.accent.withOpacity(0.15) : AppTheme.secondary.withOpacity(0.3),
                                        side: BorderSide(color: isRisky ? AppTheme.accent.withOpacity(0.5) : Colors.transparent),
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        visualDensity: VisualDensity.compact,
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            )
                          else
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Text("Sin puertos abiertos detectados", style: TextStyle(fontSize: 11, color: AppTheme.textDim)),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}