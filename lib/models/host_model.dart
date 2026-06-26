class HostModel {
  final String ip;
  final String? name;
  final String source;
  final List<int> openPorts;
  final List<String> portServices;

  HostModel({
    required this.ip,
    this.name,
    required this.source,
    this.openPorts = const [],
    this.portServices = const [],
  });

  /// Common port to service name mapping
  static String portToService(int port) {
    const Map<int, String> services = {
      22: "SSH",
      23: "Telnet",
      53: "DNS",
      80: "HTTP",
      443: "HTTPS",
      445: "SMB",
      5000: "UPnP/NAS",
      1900: "SSDP/UPnP",
      8008: "HTTP-Alt",
      8009: "Chromecast",
      8080: "HTTP-Proxy",
      8081: "HTTP-Alt",
      8443: "HTTPS-Alt",
      8888: "HTTP-Alt",
      9100: "Printer",
    };
    return services[port] ?? "Port $port";
  }

  /// Risk level based on open ports
  String get riskLevel {
    if (openPorts.contains(23)) return "HIGH"; // Telnet
    if (openPorts.contains(445)) return "MEDIUM"; // SMB
    if (openPorts.contains(22) && openPorts.contains(80)) return "MEDIUM"; // SSH + Web
    if (openPorts.isNotEmpty) return "LOW";
    return "NONE";
  }

  /// Summary of open ports
  String get portsSummary {
    if (openPorts.isEmpty) return "No open ports";
    return openPorts.map((p) => "$p (${portToService(p)})").join(", ");
  }

  Map<String, dynamic> toMap() {
    return {
      'ip': ip,
      'name': name,
      'source': source,
      'open_ports': openPorts,
      'port_services': portServices,
      'risk_level': riskLevel,
      'ports_summary': portsSummary,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HostModel && runtimeType == other.runtimeType && ip == other.ip;

  @override
  int get hashCode => ip.hashCode;
}