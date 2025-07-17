// lib/widgets/flutter_mini_map_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
// No se usa shared_preferences en esta versión
import '../models/station.dart'; // Assuming you have this model

class FlutterMiniMapWidget extends StatefulWidget {
  final double width;
  final double height;
  final LatLng? initialCenter;
  final Function(List<Station> stations)? onStationsFound;
  final Function(LocationPermission permission)? onPermissionStatusChanged;

  const FlutterMiniMapWidget({
    super.key,
    required this.width,
    required this.height,
    this.initialCenter,
    this.onStationsFound,
    this.onPermissionStatusChanged,
  });

  @override
  State<FlutterMiniMapWidget> createState() => _FlutterMiniMapWidgetState();
}

class _FlutterMiniMapWidgetState extends State<FlutterMiniMapWidget> {
  LatLng? _userLocation;
  LatLng? _lastKnownUserLocation; // Solo para la sesión actual
  final MapController _mapController = MapController();
  List<Station> _nearbyStations = [];
  LocationPermission _currentPermission = LocationPermission.denied;
  bool _isInitializing = true;
  bool _locationServiceEnabled = true;

  @override
  void initState() {
    super.initState();
    _initializeMapAndLocation();
  }

  Future<void> _initializeMapAndLocation() async {
    print("FlutterMiniMap: _initializeMapAndLocation START");
    if (!mounted) {
      print("FlutterMiniMap: _initializeMapAndLocation - NOT MOUNTED, returning.");
      return;
    }
    // Establecer _isInitializing a true antes de cualquier operación asíncrona
    // para asegurar que el loader se muestre inmediatamente.
    if (!_isInitializing) { // Solo actualiza si no está ya inicializando
      setState(() {
        _isInitializing = true;
      });
    }


    try {
      await _handleLocationTasks();
      print("FlutterMiniMap: _initializeMapAndLocation - _handleLocationTasks COMPLETED");
    } catch (e) {
      // Captura cualquier error inesperado de _handleLocationTasks directamente aquí
      // aunque _handleLocationTasks ya tiene su propio try-catch interno.
      // Esto es una salvaguarda adicional.
      print("FlutterMiniMap: Error inesperado durante _handleLocationTasks en _initializeMapAndLocation: $e");
    } finally {
      // Este bloque finally ASEGURA que _isInitializing se establezca en false
      // sin importar lo que suceda en el bloque try (éxito, error capturado, o error no capturado).
      if (mounted) {
        print("FlutterMiniMap: _initializeMapAndLocation (finally) - Setting _isInitializing to false");
        setState(() {
          _isInitializing = false;
        });
      } else {
        print("FlutterMiniMap: _initializeMapAndLocation (finally) - NOT MOUNTED when trying to set _isInitializing to false");
      }
    }
    print("FlutterMiniMap: _initializeMapAndLocation END");
  }


  Future<bool> _handleLocationPermission() async {
    print("FlutterMiniMap: _handleLocationPermission START");
    _locationServiceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!_locationServiceEnabled) {
      print("FlutterMiniMap: Servicio de ubicación deshabilitado.");
      if (mounted) {
        setState(() { _currentPermission = LocationPermission.denied; });
      }
      if (widget.onPermissionStatusChanged != null) {
        widget.onPermissionStatusChanged!(LocationPermission.denied);
      }
      print("FlutterMiniMap: _handleLocationPermission END - Service Disabled");
      return false;
    }

    print("FlutterMiniMap: Verificando permiso...");
    LocationPermission permission = await Geolocator.checkPermission();
    print("FlutterMiniMap: Permiso actual: $permission");
    if (permission == LocationPermission.denied) {
      print("FlutterMiniMap: Solicitando permiso...");
      permission = await Geolocator.requestPermission();
      print("FlutterMiniMap: Permiso después de solicitar: $permission");
    }

    if (mounted) {
      setState(() { _currentPermission = permission; });
    }
    if (widget.onPermissionStatusChanged != null) {
      widget.onPermissionStatusChanged!(permission);
    }
    final bool hasPermission = permission == LocationPermission.whileInUse || permission == LocationPermission.always;
    print("FlutterMiniMap: _handleLocationPermission END - Has Permission: $hasPermission");
    return hasPermission;
  }

  Future<void> _handleLocationTasks() async {
    print("FlutterMiniMap: _handleLocationTasks START");
    if (!mounted) {
      print("FlutterMiniMap: _handleLocationTasks - NOT MOUNTED, returning.");
      return;
    }

    bool hasPermission = await _handleLocationPermission();
    print("FlutterMiniMap: _handleLocationTasks - hasPermission: $hasPermission");

    if (hasPermission) {
      print("FlutterMiniMap: Permiso concedido, intentando obtener ubicación...");
      try {
        // Aumenta el timeout para depuración si sospechas que es la causa
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          // timeLimit: const Duration(seconds: 10), // Original
          timeLimit: const Duration(seconds: 20), // Aumentado para prueba
        );
        print("FlutterMiniMap: Ubicación obtenida: ${position.latitude}, ${position.longitude}");
        if (mounted) {
          final newLocation = LatLng(position.latitude, position.longitude);
          setState(() {
            _userLocation = newLocation;
            _lastKnownUserLocation = newLocation;
          });
          print("FlutterMiniMap: UBICACIÓN REAL OBTENIDA POR GEOLOCATOR: $_userLocation");

          if (_userLocation != null) { // Asegurarse que _userLocation no sea null antes de usarlo
            _mapController.move(_userLocation!, 14.0);
            _findNearbyStations(_userLocation!);
          }
        }
      } catch (e) {
        print("FlutterMiniMap: Error obteniendo ubicación: $e");
        // Si falla, _userLocation será null. _lastKnownUserLocation mantendrá su valor anterior (o null si nunca se obtuvo una).
        if (mounted && _lastKnownUserLocation != null) {
          print("FlutterMiniMap: Usando última conocida de esta sesión para estaciones: $_lastKnownUserLocation");
          _findNearbyStations(_lastKnownUserLocation!);
          _mapController.move(_lastKnownUserLocation!, 14.0);
        } else if (widget.onStationsFound != null) {
          widget.onStationsFound!([]);
        }
      }
    } else {
      print("FlutterMiniMap: Permiso NO concedido o servicio deshabilitado.");
      if (widget.onStationsFound != null) {
        widget.onStationsFound!([]);
      }
    }
    print("FlutterMiniMap: _handleLocationTasks END");
  }

  // --- Tus funciones _findNearbyStations y _getStationIcon (reemplazar con tu lógica real) ---
  void _findNearbyStations(LatLng location) {
    print("Buscando estaciones cerca de: $location");
    List<Station> simulatedStations = [
      Station(id: 's1', name: 'Metro Ejemplo', location: LatLng(location.latitude + 0.01, location.longitude + 0.01), type: 'metro'),
      Station(id: 's2', name: 'Bus Cercano', location: LatLng(location.latitude - 0.005, location.longitude - 0.005), type: 'bus'),
    ];
    if (mounted) {
      setState(() { _nearbyStations = simulatedStations; });
      if (widget.onStationsFound != null) { widget.onStationsFound!(_nearbyStations); }
    }
  }

  Widget _getStationIcon(String type) {
    IconData iconData;
    Color iconColor;
    switch (type.toLowerCase()) {
      case 'metro': iconData = Icons.directions_subway; iconColor = Colors.red; break;
      case 'bus': iconData = Icons.directions_bus; iconColor = Colors.green; break;
      default: iconData = Icons.location_pin; iconColor = Colors.grey;
    }
    return Icon(iconData, color: iconColor, size: 25);
  }
  // --- Fin de funciones asumidas ---

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_locationServiceEnabled) {
      return _buildServiceDisabledUI();
    }

    if (_currentPermission == LocationPermission.denied ||
        _currentPermission == LocationPermission.deniedForever) {
      return _buildPermissionDeniedUI();
    }

    final LatLng mapCenterPoint;
    final LatLng? locationForUserMarkerAndStations;

    if (_userLocation != null) {
      mapCenterPoint = _userLocation!;
      locationForUserMarkerAndStations = _userLocation!;
    } else if (_lastKnownUserLocation != null) {
      mapCenterPoint = _lastKnownUserLocation!;
      locationForUserMarkerAndStations = _lastKnownUserLocation!;
      print("Usando última ubicación conocida (de esta sesión) para centrar el mapa: $_lastKnownUserLocation");
    } else if (widget.initialCenter != null) {
      mapCenterPoint = widget.initialCenter!;
      locationForUserMarkerAndStations = null;
      print("Usando initialCenter del widget para centrar el mapa: ${widget.initialCenter}");
    } else {
      mapCenterPoint = LatLng(41.387, 2.170);
      locationForUserMarkerAndStations = null;
      print("Usando fallback codificado (Barcelona) para centrar el mapa");
    }

    List<Marker> stationMarkers = [];
    if (locationForUserMarkerAndStations != null && _nearbyStations.isNotEmpty) {
      stationMarkers = _nearbyStations.map((station) {
        return Marker(point: station.location, child: _getStationIcon(station.type));
      }).toList();
    }

    // Añadir marcador del usuario
    final LatLng? displayUserLocation = _userLocation ?? _lastKnownUserLocation;
    if (displayUserLocation != null) {
      stationMarkers.add(
        Marker(
          point: displayUserLocation,
          width: 30,
          height: 30,
          child: Icon(
            Icons.my_location,
            color: _userLocation != null ? Colors.blueAccent : Colors.orangeAccent,
            size: 25,
          ),
        ),
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: mapCenterPoint,
          initialZoom: 13,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c'],
            userAgentPackageName: 'com.moutrans.app',
          ),
          if (stationMarkers.isNotEmpty) MarkerLayer(markers: stationMarkers),
        ],
      ),
    );
  }

  Widget _buildServiceDisabledUI() {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_off, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text('Servicio de Ubicación Deshabilitado', style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('Por favor, activa los servicios de ubicación en la configuración de tu dispositivo para continuar.', textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.settings),
                label: const Text('Abrir Config. de Ubicación'),
                onPressed: () => Geolocator.openLocationSettings(),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
                onPressed: _initializeMapAndLocation, // Llama directamente
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionDeniedUI() {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_disabled, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                _currentPermission == LocationPermission.deniedForever ? 'Permiso de Ubicación Denegado Permanentemente' : 'Permiso de Ubicación Requerido',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _currentPermission == LocationPermission.deniedForever
                    ? 'Para usar esta función, por favor habilita el permiso de ubicación en la configuración de la aplicación.'
                    : 'Esta aplicación necesita acceso a tu ubicación para mostrar estaciones cercanas y tu posición en el mapa.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (_currentPermission == LocationPermission.denied)
                ElevatedButton.icon(
                  icon: const Icon(Icons.location_on_outlined),
                  label: const Text('Conceder Permiso'),
                  onPressed: _initializeMapAndLocation, // Llama directamente
                ),
              if (_currentPermission == LocationPermission.deniedForever)
                ElevatedButton.icon(
                  icon: const Icon(Icons.settings_applications),
                  label: const Text('Abrir Configuración de App'),
                  onPressed: () => Geolocator.openAppSettings(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
