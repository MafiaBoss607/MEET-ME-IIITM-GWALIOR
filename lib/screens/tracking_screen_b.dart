import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../services/firebase_service.dart';
import '../services/location_service.dart';
import '../models/tracking_session.dart';

class TrackingScreenB extends StatefulWidget {
  final String sessionId;
  final String friendId;
  final String friendName;
  final String myDeviceId;

  const TrackingScreenB({
    super.key,
    required this.sessionId,
    required this.friendId,
    required this.friendName,
    required this.myDeviceId,
  });

  @override
  State<TrackingScreenB> createState() => _TrackingScreenBState();
}

class _TrackingScreenBState extends State<TrackingScreenB>
    with SingleTickerProviderStateMixin {
  StreamSubscription<Position>? _locationSubscription;
  StreamSubscription<LocationData?>? _friendLocationSubscription;

  double? myLat;
  double? myLng;

  double? friendLat;
  double? friendLng;

  late AnimationController _iconController;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
    _startTracking();
  }

  void _setupAnimation() {
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  Future<void> _startTracking() async {
    // Request location permission
    final hasPermission = await LocationService.requestPermission();
    if (!hasPermission) {
      _showError('Location permission denied');
      return;
    }

    // Start location updates
    _locationSubscription = LocationService.getPositionStream().listen(
      (position) {
        setState(() {
          myLat = position.latitude;
          myLng = position.longitude;
        });

        // Send my location to Firebase
        FirebaseService.updateLocation(
          widget.sessionId,
          widget.myDeviceId,
          position.latitude,
          position.longitude,
          0, // No heading needed for B
        );
      },
    );

    // Listen to friend's location (to calculate distance)
    _friendLocationSubscription = FirebaseService.listenToLocation(
      widget.sessionId,
      widget.friendId,
    ).listen((locationData) {
      if (locationData != null) {
        setState(() {
          friendLat = locationData.lat;
          friendLng = locationData.lng;
        });
      }
    });
  }

  double? _calculateDistance() {
    if (myLat == null || friendLat == null) return null;
    return LocationService.calculateDistance(
      myLat!,
      myLng!,
      friendLat!,
      friendLng!,
    );
  }

  @override
  Widget build(BuildContext context) {
    final distance = _calculateDistance();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade400,
              Colors.blue.shade700,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: _stopSharing,
                    ),
                    Expanded(
                      child: Text(
                        'Sharing with ${widget.friendName}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48), // Balance the back button
                  ],
                ),
              ),

              // Main content
              Expanded(
                child: Center(
                  child: distance == null || friendLat == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                            SizedBox(height: 24),
                            Text(
                              'Connecting...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Animated location icon
                            AnimatedBuilder(
                              animation: _iconController,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: 1 + (_iconController.value * 0.3),
                                  child: Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withOpacity(0.3),
                                    ),
                                    child: const Icon(
                                      Icons.location_on,
                                      size: 60,
                                      color: Colors.white,
                                    ),
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 48),

                            // Main message
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 40),
                              child: Text(
                                '${widget.friendName} is reaching you',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Instruction
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 40),
                              child: Text(
                                'Please stand where you are',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 18,
                                ),
                              ),
                            ),

                            const SizedBox(height: 48),

                            // Distance display
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    LocationService.formatDistance(distance),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'away',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              // Stop button
              Padding(
                padding: const EdgeInsets.all(32),
                child: ElevatedButton(
                  onPressed: _stopSharing,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'Stop Sharing',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _stopSharing() async {
    await FirebaseService.endTrackingSession(widget.sessionId);
    if (!mounted) return;
    Navigator.pop(context);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _friendLocationSubscription?.cancel();
    _iconController.dispose();
    super.dispose();
  }
}