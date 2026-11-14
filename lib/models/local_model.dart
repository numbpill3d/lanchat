class LocalModel {
  final String name;
  final String? path;
  final int sizeBytes;

  const LocalModel({required this.name, this.path, this.sizeBytes = 0});

  String get extension {
    final dot = name.lastIndexOf('.');
    return dot == -1 ? '' : name.substring(dot + 1).toLowerCase();
  }
}
