import 'package:firebase_core/firebase_core.dart';

/// Shared Firebase project configuration for Flutter Web.
/// Android/iOS continue using their native Firebase configuration files.
/// These Web client values are public Firebase app configuration, not secrets.
class DefaultFirebaseOptions {
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAZEBjbfX2E4PGWY6SJKM6uIwRZe8b3os',
    appId: '1:427408783867:web:f3d1ad4f2138573bbaf35e',
    messagingSenderId: '427408783867',
    projectId: 'sanchore-bazaar',
    authDomain: 'sanchore-bazaar.firebaseapp.com',
    storageBucket: 'sanchore-bazaar.firebasestorage.app',
  );

  static const bool isWebConfigured = true;
}
