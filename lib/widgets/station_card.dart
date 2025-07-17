// lib/widgets/station_card.dart
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

  Widget _getIcon(String type, BuildContext context) {
    String iconPath;
    Color iconColor = Theme.of(context).colorScheme.primary;
    switch (type.toLowerCase()) {
      case 'metro':
        iconPath = 'assets/icons/metro.png';
        break;
      case 'bus':
        iconPath = 'assets/icons/bus.png';
        break;
      default:
        return Icon(Icons.location_on, color: iconColor, size: 24);
    }

    return Image.asset(
      iconPath,
      width: 24,
      height: 24,
      color: iconColor,
      errorBuilder: (context, error, stackTrace) {
        return Icon(Icons.location_on, color: iconColor, size: 24); // Fallback
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _getIcon(station.type, context),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        station.name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  station.type.toUpperCase(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
