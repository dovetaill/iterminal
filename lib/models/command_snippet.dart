class CommandSnippet {
  CommandSnippet({
    required this.id,
    required this.name,
    required this.command,
    this.favorite = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String name;
  final String command;
  final bool favorite;
  final DateTime createdAt;
  final DateTime updatedAt;

  CommandSnippet copyWith({
    String? id,
    String? name,
    String? command,
    bool? favorite,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CommandSnippet(
      id: id ?? this.id,
      name: name ?? this.name,
      command: command ?? this.command,
      favorite: favorite ?? this.favorite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'command': command,
      'favorite': favorite,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory CommandSnippet.fromJson(Map<String, dynamic> json) {
    return CommandSnippet(
      id: json['id'] as String,
      name: json['name'] as String,
      command: json['command'] as String,
      favorite: json['favorite'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }
}
