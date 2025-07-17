import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart'; // Para LatLng
import 'package:geolocator/geolocator.dart'; // Para LocationPermission

import 'widgets/flutter_mini_map_widget.dart';
import 'models/station.dart';
import 'widgets/station_card.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Moutrans'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<Station> _foundStations = [];
  bool _isLoadingStations = true; // Para el indicador de carga del scroll horizontal
  LocationPermission _mapPermissionStatus = LocationPermission.denied; // Para saber el estado del permiso

  @override
  Widget build(BuildContext context) {
    final LatLng defaultInitialCenter = LatLng(41.387, 2.170); // Barcelona por defecto

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          // Asegúrate de tener esta imagen en assets/moutrans_logo.png
          // y declarada en pubspec.yaml
          child: Image.asset('assets/moutrans_logo.png', errorBuilder: (context, error, stacktrace) {
            return const Icon(Icons.directions_bus); // Icono de fallback
          }),
        ),
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0), // Padding solo vertical para el Column principal
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding( // Padding horizontal para los títulos
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Mapa de Estaciones Cercanas:',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: 10),
            // El mapa no necesita padding horizontal si su width es MediaQuery
            Center( // El Center no es estrictamente necesario si el width es completo
              child: FlutterMiniMapWidget(
                width: MediaQuery.of(context).size.width, // Ancho completo
                height: 250.0,
                initialCenter: defaultInitialCenter,
                onStationsFound: (stations) {
                  if (mounted) {
                    setState(() {
                      _foundStations = stations;
                      // Solo ponemos isLoadingStations a false si el permiso no fue denegado,
                      // ya que si fue denegado, no esperamos estaciones.
                      if (_mapPermissionStatus == LocationPermission.whileInUse || _mapPermissionStatus == LocationPermission.always) {
                        _isLoadingStations = false;
                      }
                    });
                  }
                },
                onPermissionStatusChanged: (permission) {
                  print("Estado del permiso desde MyHomePage: $permission");
                  if (mounted) {
                    setState(() {
                      _mapPermissionStatus = permission;
                      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
                        _isLoadingStations = false; // No hay estaciones que cargar
                        _foundStations = [];     // Limpiar estaciones
                      } else {
                        // Si el permiso se concede o ya estaba concedido,
                        // FlutterMiniMapWidget intentará cargar.
                        // Podemos volver a poner isLoadingStations a true aquí
                        // si queremos que el scroll muestre "cargando"
                        _isLoadingStations = true;
                      }
                    });
                  }
                },
              ),
            ),
            const SizedBox(height: 20),
            Padding( // Padding horizontal para los títulos
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Estaciones Cercanas:',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: 10),
            _buildStationsHorizontalScroll(),
            // Espacio flexible para empujar el contenido hacia arriba si es poco
            const Expanded(child: SizedBox(height: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildStationsHorizontalScroll() {
    // Si el permiso está denegado, no mostramos ni "cargando" ni "no encontradas" para el scroll.
    // El widget del mapa ya informa sobre el estado del permiso.
    // Solo mostramos el scroll si el permiso está concedido.
    if (_mapPermissionStatus == LocationPermission.denied || _mapPermissionStatus == LocationPermission.deniedForever) {
      return const SizedBox.shrink(); // No mostrar nada para el scroll si no hay permiso
    }

    if (_isLoadingStations) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_foundStations.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No se encontraron estaciones cercanas.'),
        ),
      );
    }

    return SizedBox(
      height: 130, // Altura para el scroll horizontal de tarjetas
      child: ListView.builder(
        // Padding horizontal para el contenido del ListView
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        scrollDirection: Axis.horizontal,
        itemCount: _foundStations.length,
        itemBuilder: (context, index) {
          final station = _foundStations[index];
          return StationCard(
            station: station,
            onTap: () {
              print('Tarjeta tocada: ${station.name}');
              // Acción al tocar la tarjeta, como centrar el mapa (requeriría más lógica)
            },
          );
        },
      ),
    );
  }
}
