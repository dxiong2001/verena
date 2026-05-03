import 'dart:typed_data';

class Capture {
  final int id;
  String name;
  final DateTime dateCreated;
  DateTime dateUpdated;
  String directoryPath;
  Uint8List lastHash;

  Capture({
    required this.id,
    required this.name,
    required this.dateCreated,
    required this.dateUpdated,
    required this.directoryPath,
    required this.lastHash,
  });

  /// Convert DB → Object
  factory Capture.fromMap(Map<String, dynamic> map) {
    return Capture(
      id: map['id'],
      name: map['capture_name'],
      dateCreated: DateTime.fromMillisecondsSinceEpoch(map['date_created']),
      dateUpdated: DateTime.fromMillisecondsSinceEpoch(map['date_updated']),
      directoryPath: map['directory_path'],
      lastHash: map['last_hash'] != null
          ? Uint8List.fromList(map['last_hash'])
          : Uint8List(32),
    );
  }

  /// Convert Object → DB
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'capture_name': name,
      'date_created': dateCreated.millisecondsSinceEpoch,
      'date_updated': dateUpdated.millisecondsSinceEpoch,
      'directory_path': directoryPath,
      "last_hash": lastHash,
    };
  }
}
