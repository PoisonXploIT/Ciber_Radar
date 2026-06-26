import 'dart:async';
import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:nsd/nsd.dart' as nsd;
import '../models/host_model.dart';

class LanService {
  final NetworkInfo _networkInfo = NetworkInfo();

  static const List<int> scanPorts = [
       80, 443, 22, 53, // Web/SSH/DNS
       445, 23, // SMB / Telnet
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
  /// Returns a Stream of HostModel with open ports.
  Stream<HostModel> scan(String subnet, {
    List<int> ports = scanPorts,
  }) {
    if (subnet.isEmpty || subnet == "0.0.0.0") {
       throw Exception("Invalid Subnet");
    }

    final controller = StreamController<HostModel>();
    final Map<String, HostModel> _foundHosts = {};

    _startNsdScan(controller, _foundHosts);
    _startTcpScan(subnet, ports, controller, _foundHosts);

    return controller.stream;
  }

  Future<void> _startTcpScan(
      String subnet,
      List<int> ports,
      StreamController<HostModel> controller,
      Map<String, HostModel> foundHosts
  ) async {
    const timeout = Duration(milliseconds: 500);

    for (int i = 1; i < 255; i++) {
        if (controller.isClosed) break;
        final host = '$subnet.$i';

        _scanHostPorts(host, ports, timeout).then((result) async {
          if (result.isNotEmpty && !controller.isClosed) {
            // Try Reverse DNS
            String? hostname;
            try {
              final InternetAddress addr = InternetAddress(host);
              final reverse = await addr.reverse();
              hostname = reverse.host;
            } catch (e) {
              // Lookup failed
            }

            final hostModel = HostModel(
              ip: host,
              name: hostname,
              source: "TCP",
              openPorts: result.keys.toList()..sort(),
              portServices: result.values.toList(),
            );

            foundHosts[host] = hostModel;
            controller.add(hostModel);
          }
        });

        if (i % 10 == 0) await Future.delayed(const Duration(milliseconds: 20));
    }
  }

  /// Scan all ports for a host, return map of port -> service name
  Future<Map<int, String>> _scanHostPorts(String host, List<int> ports, Duration timeout) async {
    final Map<int, String> openPorts = {};

    for (final port in ports) {
      try {
        final socket = await Socket.connect(host, port, timeout: timeout);
        socket.destroy();
        openPorts[port] = HostModel.portToService(port);
      } catch (e) {
        // Port closed or filtered
      }
    }

    return openPorts;
  }

  Future<void> _startNsdScan(
      StreamController<HostModel> controller,
      Map<String, HostModel> foundHosts
  ) async {
    final servicesToScan = [
      '_http._tcp',
      '_googlecast._tcp',
      '_ipp._tcp',
      '_smb._tcp',
      '_ssh._tcp',
    ];

    final List<nsd.Discovery> discoveries = [];

    try {
      for (final serviceType in servicesToScan) {
         if (controller.isClosed) break;

         final discovery = await nsd.startDiscovery(serviceType);
         discoveries.add(discovery);

         discovery.addServiceListener((service, status) async {
            if (status == nsd.ServiceStatus.found) {
               var resolvedService = service;

               // Try to resolve if IP is missing
               if (service.host == null) {
                  try {
                     resolvedService = await nsd.resolve(service);
                  } catch(e) {
                     // resolve fail
                  }
               }

               if (resolvedService.host != null) {
                  String ipStr = resolvedService.host!;

                  bool isIp = InternetAddress.tryParse(ipStr) != null;

                  if (!isIp) {
                     try {
                        final ips = await InternetAddress.lookup(ipStr);
                        if (ips.isNotEmpty) {
                           ipStr = ips.first.address;
                        }
                     } catch(e) {
                        // ignore
                     }
                  }

                  if (InternetAddress.tryParse(ipStr) != null) {
                     // Determine port from NSD service
                     List<int> nsdPorts = [];
                     if (resolvedService.port != null) {
                       nsdPorts.add(resolvedService.port!);
                     }

                     final hostModel = HostModel(
                       ip: ipStr,
                       name: resolvedService.name,
                       source: "NSD (${serviceType.replaceAll('._tcp', '')})",
                       openPorts: nsdPorts,
                       portServices: nsdPorts.map((p) => HostModel.portToService(p)).toList(),
                     );

                     // Merge with existing or add new
                     if (foundHosts.containsKey(ipStr)) {
                       final existing = foundHosts[ipStr]!;
                       final mergedPorts = {...existing.openPorts, ...nsdPorts}.toList()..sort();
                       foundHosts[ipStr] = HostModel(
                         ip: existing.ip,
                         name: hostModel.name ?? existing.name,
                         source: "TCP+NSD",
                         openPorts: mergedPorts,
                         portServices: mergedPorts.map((p) => HostModel.portToService(p)).toList(),
                       );
                       controller.add(foundHosts[ipStr]!);
                     } else {
                       foundHosts[ipStr] = hostModel;
                       controller.add(hostModel);
                     }
                  }
               }
            }
         });
      }
    } catch (e) {
      // NSD Error -- continue silently
    }

    controller.onCancel = () async {
        for (final d in discoveries) {
            await nsd.stopDiscovery(d);
        }
    };
  }
}