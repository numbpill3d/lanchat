import 'dart:convert';

class NodeCapability {
  final String nodeId;
  final String displayName;
  final String platform;
  final int memoryGb;
  final List<String> models;
  final List<String> features;
  final int? batteryPercent;
  final String thermalState;

  const NodeCapability({
    required this.nodeId,
    required this.displayName,
    required this.platform,
    required this.memoryGb,
    required this.models,
    required this.features,
    this.batteryPercent,
    this.thermalState = 'unknown',
  });

  Map<String, dynamic> toJson() => {
        'nodeId': nodeId,
        'displayName': displayName,
        'platform': platform,
        'memoryGb': memoryGb,
        'models': models,
        'features': features,
        if (batteryPercent != null) 'batteryPercent': batteryPercent,
        'thermalState': thermalState,
      };

  String encode() => jsonEncode(toJson());

  factory NodeCapability.fromJson(Map<String, dynamic> json) {
    final nodeId = json['nodeId'];
    final displayName = json['displayName'];
    final platform = json['platform'];
    final memoryGb = json['memoryGb'];
    if ([nodeId, displayName, platform].any((value) => value is! String) ||
        memoryGb is! int) {
      throw const FormatException('invalid node capability');
    }
    List<String> strings(String key) {
      final value = json[key];
      if (value is! List || value.any((item) => item is! String)) {
        throw FormatException('invalid capability list: $key');
      }
      return value.cast<String>();
    }

    return NodeCapability(
      nodeId: nodeId,
      displayName: displayName,
      platform: platform,
      memoryGb: memoryGb,
      models: strings('models'),
      features: strings('features'),
      batteryPercent: json['batteryPercent'] is num
          ? (json['batteryPercent'] as num).round()
          : null,
      thermalState: json['thermalState'] is String
          ? json['thermalState'] as String
          : 'unknown',
    );
  }

  factory NodeCapability.decode(String encoded) =>
      NodeCapability.fromJson(jsonDecode(encoded) as Map<String, dynamic>);
}
