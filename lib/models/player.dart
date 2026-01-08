class Player {
  final String id;
  final String name;
  final int colorValue; // Hex value of the color

  Player({
    required this.id,
    required this.name,
    required this.colorValue,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'colorValue': colorValue,
    };
  }

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'],
      name: json['name'],
      colorValue: json['colorValue'],
    );
  }
}
