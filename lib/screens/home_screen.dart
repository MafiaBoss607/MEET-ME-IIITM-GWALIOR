import 'package:flutter/material.dart';
import 'dart:async';
import '../services/device_service.dart';
import '../services/firebase_service.dart';
import 'tracking_screen_a.dart'; // Arrow View
import 'tracking_screen_b.dart'; // Map View

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? deviceId;
  String? deviceName;
  StreamSubscription? _inviteListener;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    deviceId = await DeviceService.getDeviceId();
    deviceName = await DeviceService.getDeviceName();

    if (deviceId == null) return;

    // Register so we appear in the list
    await FirebaseService.registerDevice(deviceId!, deviceName!);

    if (!mounted) return;
    setState(() {});

    // Start listening for incoming connections immediately
    _listenForAutoConnect();
  }

  void _listenForAutoConnect() {
    _inviteListener = FirebaseService.listenForInstantInvite(deviceId!).listen(
      (inviteData) async {
        if (inviteData != null) {
          // 1. Stop listening to prevent double-trigger
          _inviteListener?.cancel(); 

          // 2. Clear the invite from Firebase
          await FirebaseService.clearInstantInvite(deviceId!);

          if (!mounted) return;

          // ✅ 3. Show FAKE popup for 2-3 seconds
          _showFakeConnectionPopup(inviteData['fromId'], inviteData['sessionId']);
        }
      },
    );
  }

  // ✅ NEW: Show fake "Accept Request" popup on Person B
  void _showFakeConnectionPopup(String fromId, String sessionId) {
    showDialog(
      context: context,
      barrierDismissible: false, // Can't dismiss by tapping outside
      builder: (BuildContext context) {
        // Auto-dismiss after 2.5 seconds
        Timer(const Duration(milliseconds: 2500), () {
          if (mounted) {
            Navigator.of(context).pop(); // Close popup
            
            // Navigate to tracking screen
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TrackingScreenB(
                  sessionId: sessionId,
                  friendId: fromId,
                  friendName: "Tracker",
                  myDeviceId: deviceId!,
                ),
              ),
            ).then((_) {
              // Restart listener when we come back
              _listenForAutoConnect();
            });
          }
        });

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.teal.shade400, Colors.teal.shade600],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated icon
                TweenAnimationBuilder(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 500),
                  builder: (context, double value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.people_alt,
                          size: 50,
                          color: Colors.teal.shade600,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                
                // Title
                const Text(
                  'Connection Request',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Message
                Text(
                  'Someone wants to track you',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                
                // Device ID (shortened)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'ID: ${fromId.substring(0, 8).toUpperCase()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Fake buttons (non-functional, just for show)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {}, // Does nothing
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Decline',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {}, // Does nothing
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.teal.shade600,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Accept',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Auto-connecting message
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Auto-connecting...',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _startInstantTracking(String targetId, String targetName) async {
    // 1. Create Session & Force Invite
    final sessionId = await FirebaseService.startDirectSession(deviceId!, targetId);

    if (!mounted) return;

    // 2. Go straight to Tracker Screen (Person A - no popup)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TrackingScreenA(
          sessionId: sessionId,
          friendId: targetId,
          friendName: targetName,
          myDeviceId: deviceId!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (deviceId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends Nearby'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.teal.shade50,
            child: Row(
              children: [
                const Icon(Icons.my_location, color: Colors.teal, size: 30),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deviceName ?? 'My Device',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      deviceId!.substring(0, 8).toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // DEMO SEARCH BOX (Non-functional, decorative only)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: Colors.grey.shade400, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Search for contacts here',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // GLOBAL LIST
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: FirebaseService.getAllDevicesStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final devices = snapshot.data!;
                // Filter out myself
                final otherDevices = devices.where((d) => d['id'] != deviceId).toList();

                if (otherDevices.isEmpty) {
                  return const Center(
                    child: Text("No other devices online."),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: otherDevices.length,
                  itemBuilder: (context, index) {
                    final device = otherDevices[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.phone_android),
                        title: Text(device['name'] ?? 'Unknown'),
                        subtitle: Text(
                          device['id'].toString().substring(0, 8).toUpperCase(),
                        ),
                        trailing: ElevatedButton.icon(
                          onPressed: () => _startInstantTracking(
                            device['id'],
                            device['name'],
                          ),
                          icon: const Icon(Icons.bolt, size: 18),
                          label: const Text("CONNECT"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _inviteListener?.cancel();
    super.dispose();
  }
}