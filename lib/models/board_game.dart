enum GameStatus { owned, sold, lended, wishlist, unowned }

extension GameStatusExtension on GameStatus {
  bool get isWishlist => this == GameStatus.wishlist;
}

class BoardGame {
  final String id;
  final String name;
  final String? description;
  final int? yearPublished;
  final int? minPlayers;
  final int? maxPlayers;
  final int? playingTime;
  final int? minPlayTime;
  final int? maxPlayTime;
  final double? averageRating;
  final double? averageWeight;
  final int? minAge;
  final String? customImageUrl;
  final String? customThumbnailUrl;
  final DateTime dateAdded;

  // Purchase details
  final double? price;
  final String? currency;
  final bool? isNew;
  final DateTime? purchaseDate;
  final String? comment;

  // Collection Status
  final GameStatus status;

  bool get isWishlist => status.isWishlist;

  BoardGame({
    required this.id,
    required this.name,
    this.description,
    this.yearPublished,
    this.minPlayers,
    this.maxPlayers,
    this.playingTime,
    this.minAge,
    this.minPlayTime,
    this.maxPlayTime,
    this.averageRating,
    this.averageWeight,
    this.customImageUrl,
    this.customThumbnailUrl,
    required this.dateAdded,
    this.price,
    this.currency,
    this.isNew,
    this.purchaseDate,
    this.comment,
    this.status = GameStatus.owned,
  });

  BoardGame copyWith({
    String? id,
    String? name,
    String? description,
    int? yearPublished,
    int? minPlayers,
    int? maxPlayers,
    int? playingTime,
    int? minAge,
    int? minPlayTime,
    int? maxPlayTime,
    double? averageRating,
    double? averageWeight,
    String? customImageUrl,
    String? customThumbnailUrl,
    DateTime? dateAdded,
    double? price,
    String? currency,
    bool? isNew,
    DateTime? purchaseDate,
    String? comment,
    GameStatus? status,
  }) {
    return BoardGame(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      yearPublished: yearPublished ?? this.yearPublished,
      minPlayers: minPlayers ?? this.minPlayers,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      playingTime: playingTime ?? this.playingTime,
      minAge: minAge ?? this.minAge,
      minPlayTime: minPlayTime ?? this.minPlayTime,
      maxPlayTime: maxPlayTime ?? this.maxPlayTime,
      averageRating: averageRating ?? this.averageRating,
      averageWeight: averageWeight ?? this.averageWeight,
      customImageUrl: customImageUrl ?? this.customImageUrl,
      customThumbnailUrl: customThumbnailUrl ?? this.customThumbnailUrl,
      dateAdded: dateAdded ?? this.dateAdded,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      isNew: isNew ?? this.isNew,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      comment: comment ?? this.comment,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'yearPublished': yearPublished,
      'minPlayers': minPlayers,
      'maxPlayers': maxPlayers,
      'playingTime': playingTime,
      'minPlayTime': minPlayTime,
      'maxPlayTime': maxPlayTime,
      'minAge': minAge,
      'averageRating': averageRating,
      'averageWeight': averageWeight,
      'customImageUrl': customImageUrl,
      'customThumbnailUrl': customThumbnailUrl,
      'dateAdded': dateAdded.toIso8601String(),
      'price': price,
      'currency': currency,
      'isNew': isNew,
      'purchaseDate': purchaseDate?.toIso8601String(),
      'comment': comment,
      'status': status.name,
    };
  }

  factory BoardGame.fromJson(Map<String, dynamic> json) {
    return BoardGame(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      yearPublished: json['yearPublished'],
      minPlayers: json['minPlayers'],
      maxPlayers: json['maxPlayers'],
      playingTime: json['playingTime'],
      minPlayTime: json['minPlayTime'],
      maxPlayTime: json['maxPlayTime'],
      minAge: json['minAge'],
      averageRating: json['averageRating']?.toDouble(),
      averageWeight: json['averageWeight']?.toDouble(),
      customImageUrl: json['customImageUrl'],
      customThumbnailUrl: json['customThumbnailUrl'],
      dateAdded: DateTime.parse(json['dateAdded']),
      price: json['price']?.toDouble(),
      currency: json['currency'],
      isNew: json['isNew'],
      purchaseDate: json['purchaseDate'] != null ? DateTime.parse(json['purchaseDate']) : null,
      comment: json['comment'],
      status: GameStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => GameStatus.owned,
      ),
    );
  }
}
