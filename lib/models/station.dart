import 'package:latlong2/latlong.dart';

class Station {
  final String id;
  final String name;
  final LatLng location;
  final String type; // 'metro', 'bus', etc. (para el icono)

  Station({
    required this.id,
    required this.name,
    required this.location,
    required this.type,
  });
}