
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
  final List<HostModel> _hosts = [];
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
    
    // Stop previous scan if running
    _stopScan();

    setState(() {
      _hosts.clear();
      _isScanning = true;
    });

    try {
      final stream = _lanService.scan(_subnet);
      
      _scanSubscription = stream.listen((HostModel host) {
        if (mounted) {
          setState(() {
             // Avoid duplicates (handled by == operator in model)
             if (!_hosts.contains(host)) {
                 _hosts.add(host);
             } else {
                 // Update if name appeared primarily
                 final index = _hosts.indexOf(host);
                 if (_hosts[index].name == null && host.name != null) {
                      _hosts[index] = host;
                 }
             }
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
        _hosts.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("RESULTS CLEARED & SCAN STOPPED")));
  }

  @override
  Widget build(BuildContext context) {
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
                    const Text("MY IP ADDRESS", style: TextStyle(color: AppTheme.textMedium, fontSize: 12)),
                    Text(_myIp, style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textHigh)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("TARGET SUBNET", style: TextStyle(color: AppTheme.textMedium, fontSize: 12)),
                    Row(
                      children: [
                        Text("$_subnet.x", style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete_sweep, color: AppTheme.accent, size: 20),
                          onPressed: _clearResults,
                          tooltip: "Clear Results",
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
             child: Text("Scanning 12 common ports (IoT, Web, Media)...", style: TextStyle(color: AppTheme.primary, fontSize: 12)),
          ),

        // Scan Button
        if (_isScanning)
           Padding(
             padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
             child: Column(
                children: [
                    const LinearProgressIndicator(color: AppTheme.primary, backgroundColor: AppTheme.textDim),
                    const SizedBox(height: 8),
                    const Text("Deep Scanning (IoT Ports + Native mDNS)...", style: TextStyle(color: AppTheme.primary, fontSize: 10)),
                    const SizedBox(height: 8),
                    OutlinedButton(
                       onPressed: _stopScan,
                       child: const Text("STOP SCAN"),
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
                 label: const Text("START DEEP SCAN (NSD)"),
               ),
             ),
           ),

        const SizedBox(height: 10),

        // Results List
        Expanded(
          child: _hosts.isEmpty && !_isScanning 
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                        Text("PRESS SCAN TO START", style: TextStyle(color: AppTheme.textMedium)),
                        SizedBox(height: 10),
                        Text("Subnet: $_subnet.0/24", style: TextStyle(color: AppTheme.textDim, fontSize: 10, fontFamily: 'JetBrains Mono')),
                        if (_hosts.isEmpty)
                             Padding(
                               padding: const EdgeInsets.only(top: 8.0),
                               child: Text("No devices found? Check Permissions or AP Isolation.", style: TextStyle(color: AppTheme.accent, fontSize: 10)),
                             )
                    ],
                  )
                )
              : ListView.builder(
                  itemCount: _hosts.length,
                  itemBuilder: (context, index) {
                    final host = _hosts[index];
                    final isGateway = host.ip.endsWith(".1");
                    final isMdns = host.source == "mDNS";
                    final displayName = (host.name != null && host.name != host.ip) ? host.name! : "Generic Device";

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: Icon(
                            isGateway ? Icons.router : (isMdns ? Icons.cast_connected : Icons.desktop_windows), 
                            color: isGateway ? AppTheme.warning : (isMdns ? Colors.pinkAccent : AppTheme.accent)
                        ),
                        title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'JetBrains Mono')),
                        subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Text(host.ip, style: const TextStyle(fontSize: 11, color: AppTheme.textMedium)),
                                Text("Source: ${host.source}", style: TextStyle(fontSize: 10, color: isMdns ? Colors.pinkAccent : Colors.greenAccent)),
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
                            : null,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
