import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;




class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform{
    return FirebaseOptions(
      apiKey: 'AIzaSyDJU6Zvu0FjxRWFAM70mDGnDjJWZ76tJlA',
      appId: '1:176664355924:android:0514e8209dec0cd4f5f9c1',
      messagingSenderId: '176664355924',
      projectId: 'foodspot-c6eb2',
      storageBucket: 'foodspot-c6eb2.firebasestorage.app',
    );
  }
}