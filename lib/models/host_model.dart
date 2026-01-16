
class HostModel {
  final String ip;
  final String? name;
  final String source; // "TCP" or "mDNS"

  HostModel({required this.ip, this.name, required this.source});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HostModel && runtimeType == other.runtimeType && ip == other.ip;

  @override
  int get hashCode => ip.hashCode;
}
