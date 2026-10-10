import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // WRAP IN TRY-CATCH: This prevents the "Duplicate App" error from crashing the app
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'AIzaSyAbhW-G-pZCRJ3UcFIoBomVxNjguIyPmfk', 
          appId: '1:1015374601940:android:7da31c8912457ed5552541',
          messagingSenderId: '1015374601940', 
          projectId: 'friend-finder-hackathon-e9f5f',
          databaseURL: 'https://friend-finder-hackathon-e9f5f-default-rtdb.asia-southeast1.firebasedatabase.app/',
        ),
      );
    }
  } catch (e) {
    // If we get the "duplicate-app" error, we just print it and continue.
    // This ensures runApp() gets called no matter what.
    debugPrint("Firebase initialization error (Ignored): $e");
  }
  
  // This will now run even if Firebase throws an error
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Friend Finder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        brightness: Brightness.light,
      ),
      home: const HomeScreen(),
    );
  }
}