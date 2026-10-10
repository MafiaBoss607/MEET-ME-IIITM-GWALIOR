import 'package:geolocator/geolocator.dart';
import 'bluetooth_distance_service.dart';
import 'location_service.dart';
import 'dart:async';

class HybridLocationService {
  // Use Bluetooth for close range (<50m), GPS for far range
  static const double BLUETOOTH_RANGE_THRESHOLD = 50.0;
  
  static StreamSubscription? _bluetoothSubscription;
  static StreamSubscription? _gpsSubscription;
  
  // Get the best distance measurement (Bluetooth or GPS)
  static Future<Map<String, dynamic>> getDistance({
    required String targetDeviceId,
    required double targetLat,
    required double targetLon,
  }) async {
    try {
      // Try Bluetooth first (more accurate for close range)
      final bluetoothAvailable = await BluetoothDistanceService.isBluetoothAvailable();
      
      if (bluetoothAvailable) {
        // Scan for the device
        await BluetoothDistanceService.stopScanning(); // Stop any previous scan
        
        final scanResults = BluetoothDistanceService.scanForDevice(targetDeviceId);
        
        // Wait for first result with timeout
        final result = await scanResults.timeout(
          const Duration(seconds: 5),
          onTimeout: (sink) {
            sink.close();
          },
        ).first;
        
        if (result['distance'] != null && result['distance'] > 0) {
          final distance = result['distance'] as double;
          
          print('✅ Using BLUETOOTH distance: ${distance.toStringAsFixed(1)}m');
          
          return {
            'distance': distance,
            'method': 'bluetooth',
            'accuracy': distance < 10 ? 'high' : 'medium',
            'rssi': result['rssi'],
            'bearing': 0.0, // Bluetooth can't provide direction
          };
        }
      }
      
      // Fallback to GPS if Bluetooth fails
      print('⚠️ Bluetooth unavailable, falling back to GPS');
      return await _getGPSDistance(targetLat, targetLon);
      
    } catch (e) {
      print('❌ Error in hybrid distance: $e');
      // Fallback to GPS
      return await _getGPSDistance(targetLat, targetLon);
    }
  }

  // GPS-based distance (fallback)
  static Future<Map<String, dynamic>> _getGPSDistance(
    double targetLat,
    double targetLon,
  ) async {
    final myPosition = await LocationService.getAveragedPosition(samples: 3);
    
    if (myPosition == null) {
      return {
        'distance': -1.0,
        'method': 'none',
        'accuracy': 'none',
        'error': 'Could not get GPS position',
      };
    }
    
    final distance = LocationService.calculateDistance(
      myPosition.latitude,
      myPosition.longitude,
      targetLat,
      targetLon,
    );
    
    final bearing = LocationService.calculateBearing(
      myPosition.latitude,
      myPosition.longitude,
      targetLat,
      targetLon,
    );
    
    print('✅ Using GPS distance: ${distance.toStringAsFixed(1)}m');
    
    return {
      'distance': distance,
      'method': 'gps',
      'accuracy': myPosition.accuracy <= 10 ? 'medium' : 'low',
      'bearing': bearing,
      'gpsAccuracy': myPosition.accuracy,
    };
  }

  // Stream combined distance updates
  static Stream<Map<String, dynamic>> getDistanceStream({
    required String targetDeviceId,
    required Stream<Position> targetPositionStream,
  }) async* {
    try {
      final bluetoothAvailable = await BluetoothDistanceService.isBluetoothAvailable();
      
      if (bluetoothAvailable) {
        // Use Bluetooth stream
        yield* BluetoothDistanceService.scanForDevice(targetDeviceId).map((result) {
          if (result['distance'] != null && result['distance'] > 0) {
            return {
              'distance': result['distance'],
              'method': 'bluetooth',
              'accuracy': 'high',
              'rssi': result['rssi'],
              'bearing': 0.0,
            };
          }
          return {
            'distance': -1.0,
            'method': 'bluetooth',
            'accuracy': 'none',
          };
        });
      } else {
        // Use GPS stream
        yield* targetPositionStream.asyncMap((targetPosition) async {
          final myPosition = await LocationService.getCurrentPosition();
          
          if (myPosition == null) {
            return {
              'distance': -1.0,
              'method': 'gps',
              'accuracy': 'none',
            };
          }
          
          final distance = LocationService.calculateDistance(
            myPosition.latitude,
            myPosition.longitude,
            targetPosition.latitude,
            targetPosition.longitude,
          );
          
          final bearing = LocationService.calculateBearing(
            myPosition.latitude,
            myPosition.longitude,
            targetPosition.latitude,
            targetPosition.longitude,
          );
          
          return {
            'distance': distance,
            'method': 'gps',
            'accuracy': myPosition.accuracy <= 10 ? 'medium' : 'low',
            'bearing': bearing,
            'gpsAccuracy': myPosition.accuracy,
          };
        });
      }
    } catch (e) {
      print('❌ Error in distance stream: $e');
      yield {
        'distance': -1.0,
        'method': 'error',
        'accuracy': 'none',
        'error': e.toString(),
      };
    }
  }

  // Determine best method based on estimated distance
  static Future<String> getBestMethod({
    required double targetLat,
    required double targetLon,
  }) async {
    final myPosition = await LocationService.getCurrentPosition();
    
    if (myPosition == null) {
      return 'bluetooth'; // Default to Bluetooth if no GPS
    }
    
    final roughDistance = LocationService.calculateDistance(
      myPosition.latitude,
      myPosition.longitude,
      targetLat,
      targetLon,
    );
    
    // Use Bluetooth for close range, GPS for far
    if (roughDistance < BLUETOOTH_RANGE_THRESHOLD) {
      final bluetoothAvailable = await BluetoothDistanceService.isBluetoothAvailable();
      return bluetoothAvailable ? 'bluetooth' : 'gps';
    }
    
    return 'gps';
  }

  // Format distance with method indicator
  static String formatDistanceWithMethod(Map<String, dynamic> result) {
    final distance = result['distance'] as double;
    final method = result['method'] as String;
    final accuracy = result['accuracy'] as String;
    
    if (distance < 0) return 'Unknown';
    
    String distanceStr;
    if (distance < 1) {
      distanceStr = '${(distance * 100).round()}cm';
    } else if (distance < 10) {
      distanceStr = '${distance.toStringAsFixed(1)}m';
    } else {
      distanceStr = '${distance.round()}m';
    }
    
    // Add accuracy indicator
    String accuracyEmoji = '';
    switch (accuracy) {
      case 'high':
        accuracyEmoji = '🎯'; // Very accurate (Bluetooth)
        break;
      case 'medium':
        accuracyEmoji = '📍'; // Good accuracy (GPS good signal)
        break;
      case 'low':
        accuracyEmoji = '⚠️'; // Poor accuracy (GPS poor signal)
        break;
    }
    
    return '$accuracyEmoji $distanceStr';
  }

  // Cleanup
  static Future<void> dispose() async {
    await BluetoothDistanceService.dispose();
    _bluetoothSubscription?.cancel();
    _gpsSubscription?.cancel();
  }
}