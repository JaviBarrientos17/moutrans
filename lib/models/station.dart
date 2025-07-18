import 'package:google_maps_flutter/google_maps_flutter.dart';

class Station {
  final String id;
  final String name;
  final LatLng location;
  final String type; // Ej: 'bus', 'metro', 'train', 'tram', 'ferry'

  Station({
    required this.id,
    required this.name,
    required this.location,
    required this.type,
  });

  factory Station.fromJson(Map<String, dynamic> json, String typeOverride) {
    String name = json['tags']?['name'] ?? 'Parada sin nombre';
    if (typeOverride == 'bus' && json['tags']?['official_name'] != null) {
      name = json['tags']['official_name'];
    } else if (typeOverride == 'bus' && json['tags']['ref'] != null) {
      name = 'Parada ${json['tags']['ref']} ($name)';
    }


    return Station(
      id: '${typeOverride}_${json['id'].toString()}',
      name: name,
      location: LatLng(json['lat'], json['lon']),
      type: typeOverride
    );
  }

  @override
  String toString() {
    return 'Station{id: $id, name: $name, location: $location, type: $type}';
  }
}
