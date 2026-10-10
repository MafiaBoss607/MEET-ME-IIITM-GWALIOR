import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/tracking_session.dart';

class FirebaseService {
  // ✅ FIXED: Using the correct Asia-Southeast region database URL
  static final DatabaseReference _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://friend-finder-hackathon-e9f5f-default-rtdb.asia-southeast1.firebasedatabase.app',
  ).ref();

  // 1. REGISTER DEVICE (So you appear in the global list)
  static Future<void> registerDevice(String deviceId, String deviceName) async {
    print("💾 [FIREBASE] Registering device: $deviceId");
    await _db.child('devices/$deviceId').set({
      'name': deviceName,
      'online': true,
      'lastSeen': ServerValue.timestamp,
    });
  }

  // 2. GET ALL DEVICES (Global Discovery)
  static Stream<List<Map<String, dynamic>>> getAllDevicesStream() {
    return _db.child('devices').onValue.map((event) {
      final List<Map<String, dynamic>> devices = [];
      if (event.snapshot.value != null) {
        final Map<dynamic, dynamic> data =
            event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          final deviceData = Map<String, dynamic>.from(value as Map);
          deviceData['id'] = key;
          devices.add(deviceData);
        });
      }
      return devices;
    });
  }

  // 3. START SESSION (For the Tracker)
  static Future<String> startDirectSession(String myDeviceId, String targetId) async {
    // Create the session
    final sessionRef = _db.child('tracking_sessions').push();
    final String sessionId = sessionRef.key!;

    await sessionRef.set({
      'deviceA': myDeviceId, // Tracker
      'deviceB': targetId,   // Target
      'active': true,
      'createdAt': ServerValue.timestamp,
    });

    // Force-write an invite to the target's folder
    await _db.child('users/$targetId/instant_invite').set({
      'sessionId': sessionId,
      'fromId': myDeviceId,
      'timestamp': ServerValue.timestamp,
    });

    return sessionId;
  }

  // 4. LISTEN FOR SESSION (For the Target)
  static Stream<Map<String, dynamic>?> listenForInstantInvite(String myDeviceId) {
    return _db.child('users/$myDeviceId/instant_invite').onValue.map((event) {
      if (event.snapshot.value != null) {
        return Map<String, dynamic>.from(event.snapshot.value as Map);
      }
      return null;
    });
  }

  // 5. CLEANUP INVITE
  static Future<void> clearInstantInvite(String myDeviceId) async {
    await _db.child('users/$myDeviceId/instant_invite').remove();
  }
  
  // 6. TRACKING UPDATES
  static Future<void> updateLocation(String sessionId, String deviceId,
      double lat, double lng, double heading) async {
    await _db.child('tracking_sessions/$sessionId/$deviceId').set({
      'lat': lat,
      'lng': lng,
      'heading': heading,
      'timestamp': ServerValue.timestamp,
    });
  }

  static Stream<LocationData?> listenToLocation(String sessionId, String deviceId) {
    return _db.child('tracking_sessions/$sessionId/$deviceId').onValue.map((event) {
      if (event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        return LocationData.fromMap(data);
      }
      return null;
    });
  }

  // 7. END SESSION
  static Future<void> endTrackingSession(String sessionId) async {
    await _db.child('tracking_sessions/$sessionId').remove();
  }

  // 8. UPDATE DEVICE ONLINE STATUS
  static Future<void> setDeviceOnline(String deviceId, bool online) async {
    await _db.child('devices/$deviceId').update({
      'online': online,
      'lastSeen': ServerValue.timestamp,
    });
  }

  // 9. CLEANUP ON DISCONNECT (Optional but recommended)
  static Future<void> setupDisconnectHandlers(String deviceId) async {
    // This will automatically set the device offline when disconnected
    await _db.child('devices/$deviceId/online').onDisconnect().set(false);
    await _db.child('devices/$deviceId/lastSeen').onDisconnect().set(ServerValue.timestamp);
  }

  // ✅ NEW: 10. STORE BLUETOOTH DEVICE ID (For Bluetooth tracking)
  static Future<void> updateBluetoothId(String sessionId, String deviceId, String bluetoothId) async {
    print("📡 [FIREBASE] Storing Bluetooth ID for $deviceId: $bluetoothId");
    await _db.child('tracking_sessions/$sessionId/$deviceId/bluetoothId').set(bluetoothId);
  }

  // ✅ NEW: 11. GET OTHER DEVICE'S BLUETOOTH ID
  static Stream<String?> listenToBluetoothId(String sessionId, String deviceId) {
    return _db.child('tracking_sessions/$sessionId/$deviceId/bluetoothId').onValue.map((event) {
      if (event.snapshot.value != null) {
        final bluetoothId = event.snapshot.value.toString();
        print("📡 [FIREBASE] Got Bluetooth ID for $deviceId: $bluetoothId");
        return bluetoothId;
      }
      return null;
    });
  }

  // ✅ NEW: 12. GET BLUETOOTH ID (One-time fetch, not stream)
  static Future<String?> getBluetoothId(String sessionId, String deviceId) async {
    final snapshot = await _db.child('tracking_sessions/$sessionId/$deviceId/bluetoothId').get();
    if (snapshot.exists) {
      return snapshot.value.toString();
    }
    return null;
  }
}