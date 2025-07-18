import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/station.dart';
import '../services/overpass_service.dart';

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
  GoogleMapController? _mapController;
  LatLng? _userLocation;
  LatLng? _lastKnownUserLocation;
  Set<Marker> _markers = {};

  LocationPermission _currentPermission = LocationPermission.denied;
  bool _isInitializing = true;
  bool _isLoadingStations = false;
  bool _locationServiceEnabled = true;
  Timer? _debounce;
  CameraPosition? _lastSearchedCameraPosition;
  CameraPosition? _currentCameraPosition;


  static const double _searchRadiusMeters = 1500;
  static const double _initialZoom = 14.5;

  final OverpassService _overpassService = OverpassService();

  @override
  void initState() {
    super.initState();
    _initializeMapAndLocation();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initializeMapAndLocation() async {
    print("GoogleMiniMap: _initializeMapAndLocation START");
    if (!mounted) return;
    if (!_isInitializing) setState(() => _isInitializing = true);

    try {
      await _handleLocationTasks();
    } catch (e) {
      print("GoogleMiniMap: Error inesperado durante _handleLocationTasks: $e");
      if (mounted) {
        widget.onStationsFound?.call([]);
      }
    } finally {
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }
    print("GoogleMiniMap: _initializeMapAndLocation END");
  }

  Future<bool> _handleLocationPermission() async {
    print("GoogleMiniMap: _handleLocationPermission START");
    _locationServiceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!_locationServiceEnabled) {
      print("GoogleMiniMap: Servicio de ubicación deshabilitado.");
      if (mounted) setState(() => _currentPermission = LocationPermission.denied);
      widget.onPermissionStatusChanged?.call(LocationPermission.denied);
      return false;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (mounted) setState(() => _currentPermission = permission);
    widget.onPermissionStatusChanged?.call(permission);
    return permission == LocationPermission.whileInUse || permission == LocationPermission.always;
  }

  Future<void> _handleLocationTasks() async {
    print("GoogleMiniMap: _handleLocationTasks START");
    if (!mounted) return;

    bool hasPermission = await _handleLocationPermission();
    print("GoogleMiniMap: _handleLocationTasks - hasPermission: $hasPermission");

    if (hasPermission) {
      try {
        Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 20));
        print("GoogleMiniMap: Ubicación obtenida: ${position.latitude}, ${position.longitude}");
        if (mounted) {
          final newLocation = LatLng(position.latitude, position.longitude);
          setState(() {
            _userLocation = newLocation;
            _lastKnownUserLocation = newLocation;
          });
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(newLocation, _initialZoom),
          );
        }
      } catch (e) {
        print("GoogleMiniMap: Error obteniendo ubicación: $e");
        if (mounted && _lastKnownUserLocation != null) {
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(_lastKnownUserLocation!, _initialZoom),
          );
        } else if (mounted) {
          widget.onStationsFound?.call([]);
        }
      }
    } else {
      print("GoogleMiniMap: Permiso NO concedido o servicio deshabilitado.");
      if (mounted) widget.onStationsFound?.call([]);
    }
  }

  Future<void> _updateMarkersWithStations(LatLng target) async {
    if (!mounted) return;
    setState(() => _isLoadingStations = true);

    List<Station> foundStations = [];
    try {
      foundStations = await _overpassService.fetchNearbyStations(target, _searchRadiusMeters);
    } catch (e) {
      print("GoogleMiniMap: Error al llamar a OverpassService: $e");
      if (mounted) {
        widget.onStationsFound?.call([]);
      }
    }

    if (!mounted) return;

    Set<Marker> newMarkers = {};
    for (var station in foundStations) {
      BitmapDescriptor icon = BitmapDescriptor.defaultMarker;
      if (station.type == 'bus') {
        icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      } else if (station.type == 'metro') {
        icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      }
      else if (station.type == 'train') {
        icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      }
      else if (station.type == 'tram') {
        icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
      }
      else if (station.type == 'ferry') {
        icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan);

        newMarkers.add(
          Marker(
            markerId: MarkerId(station.id),
            position: station.location,
            infoWindow: InfoWindow(title: station.name, snippet: 'Tipo: ${station.type.toUpperCase()}'),
            icon: icon,
            onTap: () => print("Marcador tocado: ${station.name} (ID: ${station.id})"),
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _markers = newMarkers;
        _isLoadingStations = false;
      });
      if (foundStations.isNotEmpty || _isLoadingStations == false) {
        widget.onStationsFound?.call(foundStations);
      }
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    if (!mounted) return;
    _mapController = controller;
  }

  void _onCameraMove(CameraPosition position) {
    _currentCameraPosition = position;
  }

  void _onCameraIdle() async {
    print("GoogleMiniMap: Camera is idle.");
    if (!mounted || _mapController == null) return;

    LatLngBounds visibleRegion = await _mapController!.getVisibleRegion();
    final LatLng currentCenter = LatLng(
      (visibleRegion.northeast.latitude + visibleRegion.southwest.latitude) / 2,
      (visibleRegion.northeast.longitude + visibleRegion.southwest.longitude) / 2,
    );
    final double currentZoom = _currentCameraPosition?.zoom ?? _lastSearchedCameraPosition?.zoom ?? _initialZoom;

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), () {
      bool hasMovedSignificantly = true;
      if (_lastSearchedCameraPosition != null) {
        double distance = Geolocator.distanceBetween(
          _lastSearchedCameraPosition!.target.latitude,
          _lastSearchedCameraPosition!.target.longitude,
          currentCenter.latitude,
          currentCenter.longitude,
        );
        if (distance < (_searchRadiusMeters * 0.3) &&
            (_lastSearchedCameraPosition!.zoom - currentZoom).abs() < 0.5) {
          hasMovedSignificantly = false;
        }
      }

      if (hasMovedSignificantly && (currentCenter.latitude != 0.0 || currentCenter.longitude != 0.0)) {
        print("GoogleMiniMap: Actualizando marcadores para el centro: $currentCenter");
        _updateMarkersWithStations(currentCenter); // Esta es la llamada clave
        _lastSearchedCameraPosition = CameraPosition(target: currentCenter, zoom: currentZoom);
      } else {
        print("GoogleMiniMap: No se actualizan marcadores, movimiento no significativo o centro inválido.");
      }
    });
  }

  Widget _buildServiceDisabledUI() { return Container(alignment: Alignment.center, child: const Text("Servicio de ubicación deshabilitado."));}
  Widget _buildPermissionDeniedUI() { return Container(alignment: Alignment.center, child: const Text("Permiso de ubicación denegado."));}

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(child: CircularProgressIndicator(key: ValueKey("loaderInitializing"))),
      );
    }
    if (!_locationServiceEnabled) {
      return _buildServiceDisabledUI();
    }
    if (_currentPermission == LocationPermission.denied || _currentPermission == LocationPermission.deniedForever) {
      return _buildPermissionDeniedUI();
    }

    final LatLng mapInitialCenter = _userLocation ?? _lastKnownUserLocation ?? widget.initialCenter ?? const LatLng(41.3851, 2.1734);

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: CameraPosition(
              target: mapInitialCenter,
              zoom: _initialZoom,
            ),
            onMapCreated: _onMapCreated,
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
              Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer()),
            },
          ),
          if (_isLoadingStations)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.25),
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    key: ValueKey("loaderStationsIndicator"),
                    backgroundColor: Colors.white54,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
