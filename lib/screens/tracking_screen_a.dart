import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:math';
import '../services/firebase_service.dart';
import '../services/location_service.dart';
import '../models/tracking_session.dart';

class TrackingScreenA extends StatefulWidget {
  final String sessionId;
  final String friendId;
  final String friendName;
  final String myDeviceId;

  const TrackingScreenA({
    super.key,
    required this.sessionId,
    required this.friendId,
    required this.friendName,
    required this.myDeviceId,
  });

  @override
  State<TrackingScreenA> createState() => _TrackingScreenAState();
}

class _TrackingScreenAState extends State<TrackingScreenA>
    with TickerProviderStateMixin {
  StreamSubscription<Position>? _locationSubscription;
  StreamSubscription<CompassEvent>? _compassSubscription;
  StreamSubscription<LocationData?>? _friendLocationSubscription;

  double? myLat;
  double? myLng;
  double myHeading = 0;

  double? friendLat;
  double? friendLng;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startTracking();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 140, end: 180).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _startTracking() async {
    // 1. Request location permission
    final hasPermission = await LocationService.requestPermission();
    if (!hasPermission) {
      if (mounted) _showError('Location permission denied');
      return;
    }

    // 2. Start location updates (My Location)
    _locationSubscription = LocationService.getPositionStream().listen(
      (position) {
        if (!mounted) return;
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
          myHeading,
        );
      },
      onError: (e) {
        print("🔴 [TRACKING_A] Location Error: $e");
      },
    );

    // 3. Start compass updates
    try {
      _compassSubscription = FlutterCompass.events?.listen((event) {
        if (!mounted) return;
        if (event.heading != null) {
          setState(() {
            myHeading = event.heading!;
          });
        }
      });
    } catch (e) {
      print("⚠️ [TRACKING_A] Compass not available: $e");
    }

    // 4. Listen to friend's location
    _friendLocationSubscription = FirebaseService.listenToLocation(
      widget.sessionId,
      widget.friendId,
    ).listen((locationData) {
      if (!mounted) return;
      if (locationData != null) {
        setState(() {
          friendLat = locationData.lat;
          friendLng = locationData.lng;
        });
      }
    }, onError: (e) {
      print("🔴 [TRACKING_A] Firebase Location Error: $e");
    });
  }

  double? _calculateDistance() {
    if (myLat == null || myLng == null || friendLat == null || friendLng == null) return null;
    return LocationService.calculateDistance(
      myLat!,
      myLng!,
      friendLat!,
      friendLng!,
    );
  }

  double? _calculateBearing() {
    if (myLat == null || myLng == null || friendLat == null || friendLng == null) return null;
    return LocationService.calculateBearing(
      myLat!,
      myLng!,
      friendLat!,
      friendLng!,
    );
  }

  double _calculateArrowRotation() {
    final bearing = _calculateBearing();
    if (bearing == null) return 0;
    
    // Arrow rotation = bearing to friend - phone heading
    double rotation = (bearing - myHeading);
    return rotation;
  }

  String _getDirectionText() {
    final bearing = _calculateBearing();
    if (bearing == null) return 'Searching...';
    
    // Calculate relative bearing
    double relativeBearing = (bearing - myHeading + 360) % 360;
    return LocationService.getDirectionText(relativeBearing);
  }

  @override
  Widget build(BuildContext context) {
    final distance = _calculateDistance();
    final arrowRotation = _calculateArrowRotation();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF00D4AA),
              const Color(0xFF00A896),
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
                      onPressed: _stopTracking,
                    ),
                    Expanded(
                      child: Text(
                        widget.friendName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 48),
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
                              'Finding friend\'s location...',
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
                            // ✅ NEW: Bigger, more realistic arrow with pulsing circles
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                // Outer pulse (largest)
                                AnimatedBuilder(
                                  animation: _pulseAnimation,
                                  builder: (context, child) {
                                    return Container(
                                      width: _pulseAnimation.value + 60,
                                      height: _pulseAnimation.value + 60,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white.withOpacity(0.08),
                                      ),
                                    );
                                  },
                                ),
                                // Middle pulse
                                AnimatedBuilder(
                                  animation: _pulseAnimation,
                                  builder: (context, child) {
                                    return Container(
                                      width: _pulseAnimation.value + 30,
                                      height: _pulseAnimation.value + 30,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white.withOpacity(0.15),
                                      ),
                                    );
                                  },
                                ),
                                // Inner circle (background)
                                Container(
                                  width: 140,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(0.25),
                                  ),
                                ),
                                // ✅ CUSTOM REALISTIC ARROW
                                TweenAnimationBuilder<double>(
                                  duration: const Duration(milliseconds: 300),
                                  tween: Tween(begin: 0, end: arrowRotation),
                                  builder: (context, angle, child) {
                                    return Transform.rotate(
                                      angle: angle * pi / 180,
                                      child: CustomPaint(
                                        size: const Size(140, 140),
                                        painter: RealisticArrowPainter(),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),

                            const SizedBox(height: 60),

                            // Distance
                            Text(
                              LocationService.formatDistance(distance),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 56,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Direction
                            Text(
                              _getDirectionText(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
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
                  onPressed: _stopTracking,
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
                    elevation: 5,
                  ),
                  child: const Text(
                    'Stop Tracking',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _stopTracking() async {
    final shouldStop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Session?'),
        content: const Text('Are you sure you want to stop tracking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('End'),
          ),
        ],
      ),
    );

    if (shouldStop == true) {
      await FirebaseService.endTrackingSession(widget.sessionId);
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _compassSubscription?.cancel();
    _friendLocationSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }
}

// ✅ NEW: Custom realistic arrow painter
class RealisticArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final center = Offset(size.width / 2, size.height / 2);
    
    // Arrow dimensions
    final arrowLength = size.height * 0.55; // 55% of container
    final arrowWidth = size.width * 0.25;   // 25% of container
    final headLength = arrowLength * 0.4;   // Arrow head is 40% of total length
    final tailWidth = arrowWidth * 0.35;    // Tail is 35% of arrow width

    final path = Path();

    // Start from top center (arrow tip)
    path.moveTo(center.dx, center.dy - arrowLength / 2);

    // Right side of arrow head
    path.lineTo(
      center.dx + arrowWidth / 2,
      center.dy - arrowLength / 2 + headLength,
    );

    // Right side of arrow tail
    path.lineTo(
      center.dx + tailWidth / 2,
      center.dy - arrowLength / 2 + headLength,
    );

    // Right bottom of tail
    path.lineTo(
      center.dx + tailWidth / 2,
      center.dy + arrowLength / 2,
    );

    // Bottom center (tail end)
    path.lineTo(
      center.dx - tailWidth / 2,
      center.dy + arrowLength / 2,
    );

    // Left bottom of tail
    path.lineTo(
      center.dx - tailWidth / 2,
      center.dy - arrowLength / 2 + headLength,
    );

    // Left side of arrow head
    path.lineTo(
      center.dx - arrowWidth / 2,
      center.dy - arrowLength / 2 + headLength,
    );

    // Close the path back to tip
    path.close();

    // Draw shadow for depth
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    
    canvas.drawPath(path.shift(const Offset(2, 2)), shadowPaint);

    // Draw main arrow
    canvas.drawPath(path, paint);

    // Draw outline
    canvas.drawPath(path, strokePaint);

    // Add inner detail line for more realistic look
    final detailPaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final detailPath = Path();
    detailPath.moveTo(center.dx, center.dy - arrowLength / 2 + 8);
    detailPath.lineTo(center.dx, center.dy + arrowLength / 2 - 8);
    canvas.drawPath(detailPath, detailPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}