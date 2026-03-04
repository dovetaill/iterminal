class SftpEntry {
  const SftpEntry({
    required this.path,
    required this.name,
    required this.longname,
    required this.isDirectory,
    this.size,
    this.modifiedAtEpochSeconds,
  });

  final String path;
  final String name;
  final String longname;
  final bool isDirectory;
  final int? size;
  final int? modifiedAtEpochSeconds;
}
