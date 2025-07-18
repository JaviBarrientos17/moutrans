import 'package:flutter/material.dart';
import '../models/station.dart';

class StationCard extends StatelessWidget {
  final Station station;
  final VoidCallback? onTap;

  const StationCard({
    super.key,
    required this.station,
    this.onTap,
  });

  Widget _getCardIcon(String typeString) {
    IconData iconData;
    Color color;
    switch (typeString.toLowerCase()) {
      case 'metro': iconData = Icons.directions_subway; color = Colors.red; break;
      case 'bus': iconData = Icons.directions_bus; color = Colors.green; break;
      case 'train': iconData = Icons.train; color = Colors.blue; break;
      case 'tram': iconData = Icons.tram; color = Colors.orange; break;
      default: iconData = Icons.location_pin; color = Colors.grey;
    }
    return Icon(iconData, color: color, size: 24);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.only(right: 10.0),
        child: Container(
          width: 150, // Ancho de la tarjeta
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _getCardIcon(station.type),
              const SizedBox(height: 8),
              Text(
                station.name,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                station.type.toUpperCase(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
