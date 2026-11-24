import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FavoritesService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw Exception('कृपया पहले लॉगिन करें।');
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _ref =>
      _db.collection('users').doc(_uid).collection('favorites');

  Future<void> addFavoriteProduct(String productId) async {
    if (productId.trim().isEmpty) throw Exception('सामान चुनें।');
    await _ref.doc('product_$productId').set({
      'type': 'product', 'itemId': productId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeFavoriteProduct(String productId) async {
    await _ref.doc('product_$productId').delete();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchFavorites() => _ref.snapshots();
}
