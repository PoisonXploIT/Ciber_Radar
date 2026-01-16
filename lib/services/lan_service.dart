
import 'dart:async';
import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:nsd/nsd.dart' as nsd;
import '../models/host_model.dart';

class LanService {
  final NetworkInfo _networkInfo = NetworkInfo();

  // Expanded IoT Port list
  static const List<int> scanPorts = [
       80, 443, 22, 53, // Web/SSH/DNS
       8080, 8008, 8009, // Web Proxies & Chromecast
       9100, // Printers
       5000, 1900, // UPnP / NAS
       8081, 8888 // Alt Web
  ];

  Future<String?> getIp() async {
    return await _networkInfo.getWifiIP();
  }

  String? getSubnet(String ip) {
    if (ip.isEmpty) return null;
    int lastDot = ip.lastIndexOf('.');
    if (lastDot == -1) return null;
    return ip.substring(0, lastDot);
  }

  /// Scans using both Deep TCP Port check and Native Service Discovery (NSD).
  /// Returns a Stream of HostModel.
  Stream<HostModel> scan(String subnet, {
    List<int> ports = scanPorts, 
  }) {
    if (subnet.isEmpty || subnet == "0.0.0.0") {
       throw Exception("Invalid Subnet");
    }

    final controller = StreamController<HostModel>();
    final Set<String> _foundIps = {};

    print("STARTING DEEP SCAN on Subnet: $subnet. Ports: ${ports.length}");

    // 1. Start NSD (Native Service Discovery)
    _startNsdScan(controller, _foundIps);

    // 2. Start Deep TCP Scan
    _startTcpScan(subnet, ports, controller, _foundIps);

    return controller.stream;
  }

  Future<void> _startTcpScan(
      String subnet, 
      List<int> ports, 
      StreamController<HostModel> controller,
      Set<String> foundIps
  ) async {
    // Timeout increased for reliability
    const timeout = Duration(milliseconds: 500);

    for (int i = 1; i < 255; i++) {
        if (controller.isClosed) break;
        final host = '$subnet.$i';
        
        _checkHost(host, ports, timeout).then((isOpen) async {
          if (isOpen && !controller.isClosed) {
            if (!foundIps.contains(host)) {
               print("FOUND VALID HOST (TCP): $host");
               foundIps.add(host);
               
               // Try Reverse DNS
               String? hostname;
               try {
                  final InternetAddress addr = InternetAddress(host);
                  final reverse = await addr.reverse();
                  hostname = reverse.host;
               } catch (e) {
                  // Lookup failed
               }

               controller.add(HostModel(ip: host, name: hostname, source: "TCP"));
            }
          }
        });
        
        // Slight throttle
        if (i % 10 == 0) await Future.delayed(const Duration(milliseconds: 20));
    }
  }

  Future<bool> _checkHost(String host, List<int> ports, Duration timeout) async {
    for (final port in ports) {
      try {
        final socket = await Socket.connect(host, port, timeout: timeout);
        socket.destroy();
        return true; 
      } catch (e) {
        // next
      }
    }
    return false;
  }

  Future<void> _startNsdScan(StreamController<HostModel> controller, Set<String> foundIps) async {
    final servicesToScan = [
      '_http._tcp',
      '_googlecast._tcp', 
      '_ipp._tcp', // Printers
    ];
    
    final List<nsd.Discovery> discoveries = [];

    try {
      for (final serviceType in servicesToScan) {
         if (controller.isClosed) break;
         
         final discovery = await nsd.startDiscovery(serviceType);
         discoveries.add(discovery);
         
         discovery.addServiceListener((service, status) async {
            if (status == nsd.ServiceStatus.found) {
               // We need to resolve to get IP/Port usually, but nsd sends basic info. 
               // Often we need to stop discovery or resolve explicitly if IP is missing.
               
               // Note: 'nsd' package usually provides service name/host in the discovery object 
               // but sometimes requires explicit resolve.
               
               // Attempt to resolve if we have a handle
               // However, simple discovery might give us the host.
               
               // For this implementation, we mostly get name and host info.
               // We will try to resolve it.
               var resolvedService = service;
               
               // Only resolve if needed (usually IP might be missing)
               if (service.host == null) {
                  // Resolve not explicitly supported on 'found' object in all versions, 
                  // but 'nsd' package has resolve(service).
                  try {
                     // Note: Resolve can take time.
                     // resolvedService = await nsd.resolve(service); // This blocks? 
                     // Let's rely on basic info first or do it async.
                  } catch(e) {
                     // resolve fail
                  }
               }

               // Extract IP
               // 'nsd' 2.0.0: service.host is String?, service.port is int?
               // Some implementations might not give IP in 'host', but hostname.
               // If it's a hostname, we might need InternetAddress.lookup

               if (resolvedService.host != null) {
                  String ipStr = resolvedService.host!;
                  
                  // Check if it's an IP or Hostname.
                  bool isIp = InternetAddress.tryParse(ipStr) != null;
                  
                  if (!isIp) {
                     // Try to resolve hostname to IP
                     try {
                        final ips = await InternetAddress.lookup(ipStr);
                        if (ips.isNotEmpty) {
                           ipStr = ips.first.address;
                        }
                     } catch(e) {
                        // ignore
                     }
                  }

                  if (!foundIps.contains(ipStr) && InternetAddress.tryParse(ipStr) != null) {
                      print("FOUND VALID HOST (NSD): $ipStr (${resolvedService.name})");
                      foundIps.add(ipStr);
                      controller.add(HostModel(
                        ip: ipStr, 
                        name: resolvedService.name, 
                        source: "NSD (${serviceType.replaceAll('._tcp', '')})"
                      ));
                  }
               }
            }
         });
      }
    } catch (e) {
      print("NSD Error: $e");
    }
    
    // Auto-stop NSD when controller closes?
    // We can't easily detect controller close here unless we wrap the controller or check periodically.
    // Instead, we should probably keep track of discoveries and provide a dispose method, 
    // but LanService 'scan' is one-off. 
    // Best effort: Stop after a fixed duration (reasonable for LAN scan) or when loop finishes.
    
    // Let's stop NSD after TCP scan is likely done (e.g. 60 seconds) or if we want continuous, we leave it.
    // But 'scan' returns a stream. The caller can cancel subscription. The controller onCancel can be used!
    
    controller.onCancel = () async {
        for (final d in discoveries) {
            await nsd.stopDiscovery(d);
        }
        print("NSD Stopped.");
    };
  }
}
