import 'package:flutter/material.dart';

/// Widget to show distance measurement stability
class StabilityIndicator extends StatelessWidget {
  final int stabilityPercent; // 0-100
  final bool isStable;

  const StabilityIndicator({
    Key? key,
    required this.stabilityPercent,
    required this.isStable,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _getColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _getColor(), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getIcon(),
            color: _getColor(),
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            _getText(),
            style: TextStyle(
              color: _getColor(),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$stabilityPercent%',
            style: TextStyle(
              color: _getColor(),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Color _getColor() {
    if (stabilityPercent >= 80) return Colors.green;
    if (stabilityPercent >= 60) return Colors.orange;
    return Colors.red;
  }

  IconData _getIcon() {
    if (isStable) return Icons.check_circle;
    if (stabilityPercent >= 60) return Icons.sync;
    return Icons.warning;
  }

  String _getText() {
    if (stabilityPercent >= 80) return 'Stable';
    if (stabilityPercent >= 60) return 'Stabilizing';
    return 'Unstable';
  }
}

/// Linear progress bar for stability
class StabilityBar extends StatelessWidget {
  final int stabilityPercent;

  const StabilityBar({
    Key? key,
    required this.stabilityPercent,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Signal Stability',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            Text(
              '$stabilityPercent%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _getColor(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: stabilityPercent / 100,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(_getColor()),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Color _getColor() {
    if (stabilityPercent >= 80) return Colors.green;
    if (stabilityPercent >= 60) return Colors.orange;
    return Colors.red;
  }
}

/// Distance display with fluctuation warning
class DistanceDisplay extends StatelessWidget {
  final double distance;
  final double? rawDistance;
  final String method;
  final bool isStable;

  const DistanceDisplay({
    Key? key,
    required this.distance,
    this.rawDistance,
    required this.method,
    required this.isStable,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Main distance
        Text(
          _formatDistance(distance),
          style: TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.bold,
            color: isStable ? Colors.black : Colors.orange,
          ),
        ),
        
        // Raw vs filtered indicator
        if (rawDistance != null && (rawDistance! - distance).abs() > 1)
          Text(
            '(raw: ${_formatDistance(rawDistance!)})',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
              fontStyle: FontStyle.italic,
            ),
          ),
        
        // Unstable warning
        if (!isStable)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.sync, color: Colors.orange, size: 14),
                SizedBox(width: 4),
                Text(
                  'Stabilizing...',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1) {
      return '${(meters * 100).round()}cm';
    } else if (meters < 10) {
      return '${meters.toStringAsFixed(1)}m';
    } else {
      return '${meters.round()}m';
    }
  }
}