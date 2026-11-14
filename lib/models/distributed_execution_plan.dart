import 'node_capability.dart';

class DistributedExecutionPlan {
  final List<String> rpcEndpoints;
  final List<double>? tensorSplit;
  final String splitMode;

  const DistributedExecutionPlan({
    required this.rpcEndpoints,
    this.tensorSplit,
    this.splitMode = 'layer',
  });

  bool get isDistributed => rpcEndpoints.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'rpcEndpoints': rpcEndpoints,
        if (tensorSplit != null) 'tensorSplit': tensorSplit,
        'splitMode': splitMode,
      };

  factory DistributedExecutionPlan.fromJson(Map<String, dynamic> json) {
    final endpoints = json['rpcEndpoints'];
    final split = json['tensorSplit'];
    if (endpoints is! List ||
        endpoints.any((endpoint) => endpoint is! String) ||
        endpoints.isEmpty) {
      throw const FormatException('invalid distributed execution plan');
    }
    if (split != null &&
        (split is! List ||
            split.any((value) => value is! num) ||
            split.length != endpoints.length ||
            split.any((value) => (value as num).toDouble() <= 0))) {
      throw const FormatException('invalid distributed execution plan');
    }
    return DistributedExecutionPlan(
      rpcEndpoints: endpoints.cast<String>(),
      tensorSplit: split is List
          ? split.map((value) => (value as num).toDouble()).toList()
          : null,
      splitMode:
          json['splitMode'] is String ? json['splitMode'] as String : 'layer',
    );
  }

  /// Builds a plan from workers that expose a llama.cpp RPC endpoint.
  ///
  /// The split is intentionally left null. Current llama.cpp then sizes the
  /// placement from the actual free memory of every device in the entrypoint,
  /// including local CPU/GPU devices and remote RPC devices. The coordinator
  /// does not know the entrypoint's complete local device order, so inventing a
  /// fraction list here would be less correct than letting llama.cpp measure it.
  static DistributedExecutionPlan? fromCapabilities(
      Iterable<NodeCapability> capabilities,
      {Set<String> excludedNodeIds = const {}}) {
    final workers = capabilities
        .where((capability) =>
            !excludedNodeIds.contains(capability.nodeId) &&
            capability.supportsTensorSplit &&
            capability.rpcEndpoint != null &&
            capability.rpcEndpoint!.isNotEmpty)
        .toList();
    if (workers.isEmpty) return null;
    return DistributedExecutionPlan(
      rpcEndpoints:
          workers.map((worker) => worker.rpcEndpoint!).toList(growable: false),
    );
  }
}
