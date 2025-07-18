import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'widgets/flutter_mini_map_widget.dart';
import 'models/station.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Moutrans',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<Station> _foundStations = [];
  LocationPermission? _permissionStatus;
  gmaps.LatLng? _initialMapCenter;
  bool _isLoadingInitialLocation = true;
  String _locationError = "";

  @override
  void initState() {
    super.initState();
    _determineInitialLocation();
  }

  Future<void> _determineInitialLocation() async {
    if (!mounted) return;
    setState(() {
      _isLoadingInitialLocation = true;
      _locationError = "";
    });

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print("Main.dart: Servicio de ubicación deshabilitado.");
      if (mounted) {
        setState(() {
          _permissionStatus = LocationPermission.denied;
          _initialMapCenter = null;
          _isLoadingInitialLocation = false;
          _locationError = "El servicio de ubicación está desactivado. Por favor, actívalo.";
        });
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (mounted) {
      setState(() {
        _permissionStatus = permission;
      });
    }

    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
      print("Main.dart: Obteniendo ubicación actual del usuario...");
      try {
        Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 15));
        if (mounted) {
          setState(() {
            _initialMapCenter = gmaps.LatLng(position.latitude, position.longitude);
            _isLoadingInitialLocation = false;
            _locationError = "";
            print("Main.dart: Ubicación inicial del usuario: $_initialMapCenter");
          });
        }
      } catch (e) {
        print("Main.dart: Error obteniendo ubicación inicial del usuario: $e");
        if (mounted) {
          setState(() {
            _initialMapCenter = null;
            _isLoadingInitialLocation = false;
            _locationError = "No se pudo obtener tu ubicación actual. Intenta de nuevo más tarde.";
          });
        }
      }
    } else {
      print("Main.dart: Permiso de ubicación no concedido adecuadamente.");
      if (mounted) {
        setState(() {
          _initialMapCenter = null;
          _isLoadingInitialLocation = false;
          _locationError = "Se requiere permiso de ubicación para mostrar el mapa y las estaciones cercanas.";
        });
      }
    }
  }

  void _updateFoundStations(List<Station> stations) {
    if (mounted) {
      setState(() {
        _foundStations = stations;
      });
      print("Main.dart: ${stations.length} estaciones encontradas por el widget.");
    }
  }

  void _updatePermissionStatusFromWidget(LocationPermission permission) {
    if (mounted && _permissionStatus != permission) {
      setState(() {
        _permissionStatus = permission;
      });
      print("Main.dart: Estado del permiso desde el widget: $permission");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estaciones Cercanas'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoadingInitialLocation) {
      return const Center(child: CircularProgressIndicator(key: ValueKey("mainPageLoader")));
    }

    if (_locationError.isNotEmpty && _initialMapCenter == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_off, size: 60, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                'Error de Ubicación',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _locationError,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
                onPressed: _determineInitialLocation,
              ),
            ],
          ),
        ),
      );
    }

    if (_initialMapCenter == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 60, color: Colors.orange.shade300),
              const SizedBox(height: 16),
              Text(
                'Ubicación Desconocida',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'No se ha podido determinar una ubicación inicial para el mapa.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
                onPressed: _determineInitialLocation,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Text(
            _permissionStatus != null
                ? 'Permiso General: ${_permissionStatus.toString().split('.').last}'
                : 'Verificando permiso...',
            style: Theme.of(context).textTheme.titleSmall,
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          flex: 2,
          child: FlutterMiniMapWidget(
            key: ValueKey("googleMiniMap_$_initialMapCenter"),
            width: MediaQuery.of(context).size.width,
            height: double.infinity,
            initialCenter: _initialMapCenter,
            onStationsFound: _updateFoundStations,
            onPermissionStatusChanged: _updatePermissionStatusFromWidget,
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            _foundStations.isEmpty ? 'Mueve el mapa para encontrar paradas.' : '${_foundStations.length} Paradas Encontradas:',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        Expanded(
          flex: 1,
          child: _foundStations.isEmpty
              ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  (_permissionStatus == LocationPermission.denied || _permissionStatus == LocationPermission.deniedForever)
                      ? "Se necesitan permisos de ubicación para buscar paradas."
                      : "No se encontraron paradas en el área visible del mapa. Intenta moverte o hacer zoom.",
                  textAlign: TextAlign.center,
                ),
              )
          )
              : ListView.builder(
            itemCount: _foundStations.length,
            itemBuilder: (context, index) {
              final station = _foundStations[index];
              IconData listIcon;
              Color listIconColor;
              switch (station.type) {
                case 'train_rodalies':
                  listIcon = Icons.tram;
                  listIconColor = Colors.orange;
                  break;
                case 'train':
                  listIcon = Icons.train;
                  listIconColor = Colors.blue.shade700;
                  break;
                case 'metro':
                  listIcon = Icons.directions_subway;
                  listIconColor = Colors.red.shade700;
                  break;
                case 'bus':
                  listIcon = Icons.directions_bus;
                  listIconColor = Colors.green.shade700;
                  break;
                case 'tram':
                  listIcon = Icons.tram;
                  listIconColor = Colors.teal;
                  break;
                default:
                  listIcon = Icons.location_pin;
                  listIconColor = Colors.grey.shade600;
              }
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: Icon(listIcon, color: listIconColor, size: 30),
                  title: Text(station.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Tipo: ${station.type.replaceAll("_", " ").toUpperCase()}\nLat: ${station.location.latitude.toStringAsFixed(4)}, Lon: ${station.location.longitude.toStringAsFixed(4)}'),
                  isThreeLine: true,
                  dense: true,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
