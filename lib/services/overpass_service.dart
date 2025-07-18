import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/station.dart';

class OverpassService {
  static const String _overpassUrl = 'https://overpass-api.de/api/interpreter';
  static const Duration _timeoutDuration = Duration(seconds: 30);

  Future<List<Station>> fetchNearbyStations(LatLng center, double radius) async {
    print("OverpassService: Buscando paradas cerca de $center con radio $radius m");

    String query = """
[out:json][timeout:25];
(
  node[railway="station"](around:${radius},${center.latitude},${center.longitude});
  way[railway="station"](around:${radius},${center.latitude},${center.longitude});
  relation[railway="station"](around:${radius},${center.latitude},${center.longitude});

  node[railway="subway_entrance"](around:$radius,${center.latitude},${center.longitude});
  node[station="subway"][railway](around:$radius,${center.latitude},${center.longitude});

  node[highway="bus_stop"](around:${radius},${center.latitude},${center.longitude});
  node[public_transport="platform"][bus="yes"](around:${radius},${center.latitude},${center.longitude});
  way[public_transport="platform"][bus="yes"](around:${radius},${center.latitude},${center.longitude});

  node[railway="tram_stop"](around:${radius},${center.latitude},${center.longitude});
  way[railway="tram_stop"](around:${radius},${center.latitude},${center.longitude});

  node[amenity="ferry_terminal"](around:${radius},${center.latitude},${center.longitude});
  way[amenity="ferry_terminal"](around:${radius},${center.latitude},${center.longitude});
);
out center;
""";
    List<Station> allFoundStations = [];

    try {
      final response = await http.post(
        Uri.parse(_overpassUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'data': query},
      ).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List elements = data['elements'];
        print("OverpassService: ${elements.length} elementos recibidos.");

        for (var element in elements) {
          String? stationType;
          String name = element['tags']?['name'] ?? 'Parada Desconocida';
          double? lat, lon;

          if (element['type'] == 'node') {
            lat = element['lat'];
            lon = element['lon'];
          } else if (element['type'] == 'way' || element['type'] == 'relation') {
            if (element['center'] != null) {
              lat = element['center']['lat'];
              lon = element['center']['lon'];
            }
          }

          if (lat == null || lon == null) {
            continue;
          }

          if (element['tags']?['railway'] == 'station' || element['tags']?['railway'] == 'halt') {
            if (element['tags']?['station'] == 'subway' || element['tags']?['train'] == 'subway' || element['tags']?['subway'] == 'yes') {
              stationType = 'metro';
            } else if (element['tags']?['station'] == 'light_rail' || element['tags']?['train'] == 'light_rail' || element['tags']?['light_rail'] == 'yes') {
              stationType = 'tram';
            } else {
              stationType = 'train';
            }
            if(element['tags']?['name'] != null) name = element['tags']?['name'];
            else if (element['tags']?['official_name'] != null) name = element['tags']?['official_name'];

          } else if (element['tags']?['railway'] == 'subway_entrance') {
            stationType = 'metro';
            if(element['tags']?['name'] != null) name = element['tags']?['name'];
          } else if (element['tags']?['highway'] == 'bus_stop' || (element['tags']?['public_transport'] == 'platform' && element['tags']?['bus'] == 'yes')) {
            stationType = 'bus';
            if(element['tags']?['name'] != null) name = element['tags']?['name'];
            else if (element['tags']?['official_name'] != null) name = element['tags']?['official_name'];
            else if (element['tags']?['ref'] != null) name = 'Parada ${element['tags']['ref']}';
          } else if (element['tags']?['railway'] == 'tram_stop' || (element['tags']?['public_transport'] == 'platform' && element['tags']?['tram'] == 'yes')) {
            stationType = 'tram';
            if(element['tags']?['name'] != null) name = element['tags']?['name'];
          } else if (element['tags']?['amenity'] == 'ferry_terminal') {
            stationType = 'ferry';
            if(element['tags']?['name'] != null) name = element['tags']?['name'];
          }


          if (stationType != null) {
            allFoundStations.add(Station(
              id: '${element['type']}_${element['id'].toString()}',
              name: name,
              location: LatLng(lat, lon),
              type: stationType,
            ));
          }
        }
      } else {
        print("OverpassService: Error de API: ${response.statusCode} - ${response.body}");
        throw Exception('Error al obtener datos de Overpass API: ${response.statusCode}');
      }
    } on TimeoutException catch (e) {
      print("OverpassService: Timeout durante la petición: $e");
      throw Exception('Timeout al contactar Overpass API');
    } catch (e) {
      print("OverpassService: Excepción durante la petición: $e");
      throw Exception('Error desconocido al obtener estaciones: $e');
    }

    List<Station> inRadiusStations = [];
    if (allFoundStations.isNotEmpty) {
      for (var station in allFoundStations) {
        double distance = Geolocator.distanceBetween(
            center.latitude, center.longitude,
            station.location.latitude, station.location.longitude
        );
        if (distance <= radius) {
          inRadiusStations.add(station);
        }
      }
    }

    final uniqueStations = <String, Station>{};
    for (final station in inRadiusStations) {
      if (!uniqueStations.containsKey(station.id)) {
        uniqueStations[station.id] = station;
      }
    }
    final finalList = uniqueStations.values.toList();
    print("OverpassService: ${finalList.length} estaciones únicas encontradas y procesadas.");
    return finalList;
  }
}
