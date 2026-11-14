import 'node_capability.dart';

class DistributedExecutionPlan {
  final List<String> rpcEndpoints;
  final List<double> tensorSplit;
  final String splitMode;

  const DistributedExecutionPlan({
    required this.rpcEndpoints,
    required this.tensorSplit,
    this.splitMode = 'layer',
  });

  bool get isDistributed =>
      rpcEndpoints.isNotEmpty &&
      rpcEndpoints.length == tensorSplit.length &&
      tensorSplit.every((value) => value > 0);

  Map<String, dynamic> toJson() => {
        'rpcEndpoints': rpcEndpoints,
        'tensorSplit': tensorSplit,
        'splitMode': splitMode,
      };

  factory DistributedExecutionPlan.fromJson(Map<String, dynamic> json) {
    final endpoints = json['rpcEndpoints'];
    final split = json['tensorSplit'];
    if (endpoints is! List ||
        endpoints.any((endpoint) => endpoint is! String) ||
        split is! List ||
        split.any((value) => value is! num) ||
        endpoints.length != split.length ||
        endpoints.isEmpty ||
        split.any((value) => (value as num).toDouble() <= 0)) {
      throw const FormatException('invalid distributed execution plan');
    }
    return DistributedExecutionPlan(
      rpcEndpoints: endpoints.cast<String>(),
      tensorSplit: split.map((value) => (value as num).toDouble()).toList(),
      splitMode:
          json['splitMode'] is String ? json['splitMode'] as String : 'layer',
    );
  }

  /// Builds a plan from workers that expose a llama.cpp RPC endpoint. Weight
  /// fractions follow reported tensor memory, with a safe equal split when
  /// workers do not report memory.
  static DistributedExecutionPlan? fromCapabilities(
      Iterable<NodeCapability> capabilities) {
    final workers = capabilities
        .where((capability) =>
            capability.supportsTensorSplit &&
            capability.rpcEndpoint != null &&
            capability.rpcEndpoint!.isNotEmpty)
        .toList();
    if (workers.isEmpty) return null;
    final weights = workers
        .map((worker) => (worker.tensorMemoryGb ?? 1).toDouble())
        .toList();
    final total = weights.fold<double>(0, (sum, value) => sum + value);
    return DistributedExecutionPlan(
      rpcEndpoints:
          workers.map((worker) => worker.rpcEndpoint!).toList(growable: false),
      tensorSplit: weights
          .map((weight) => total == 0 ? 1.0 : weight / total)
          .toList(growable: false),
    );
  }
}
