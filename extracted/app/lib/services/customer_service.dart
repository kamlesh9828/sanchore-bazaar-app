import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CustomerService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw Exception('कृपया पहले लॉगिन करें।');
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _userRef =>
      _db.collection('users').doc(_uid).collection('addresses');
  CollectionReference<Map<String, dynamic>> get _favoritesRef =>
      _db.collection('users').doc(_uid).collection('favorites');

  Future<void> updateProfile({required String name, required String phone}) async {
    if (name.trim().length < 2 || phone.trim().length < 8) {
      throw Exception('नाम और मोबाइल नंबर सही भरें।');
    }
    await _db.collection('users').doc(_uid).update({
      'name': name.trim(), 'phone': phone.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> saveAddress({required String label, required String address,
    required double latitude, required double longitude}) async {
    if (address.trim().isEmpty || latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
      throw Exception('पता और लोकेशन सही भरें।');
    }
    final ref = _userRef.doc();
    await ref.set({
      'id': ref.id,
      'label': label.trim(), 'address': address.trim(),
      'location': GeoPoint(latitude, longitude),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteAddress(Map<String, dynamic> address) async {
    final id = address['id']?.toString();
    if (id == null || id.isEmpty) throw Exception('पते की पहचान नहीं मिली।');
    await _userRef.doc(id).delete();
  }

  Future<void> addFavoriteShop(String shopId) async => _setFavorite('shop', shopId, true);
  Future<void> removeFavoriteShop(String shopId) async => _setFavorite('shop', shopId, false);
  Future<void> addFavoriteProduct(String productId) async => _setFavorite('product', productId, true);
  Future<void> removeFavoriteProduct(String productId) async => _setFavorite('product', productId, false);

  Future<void> _setFavorite(String type, String itemId, bool enabled) async {
    if (itemId.trim().isEmpty) throw Exception('सामान चुनें।');
    final ref = _favoritesRef.doc('${type}_$itemId');
    if (enabled) {
      await ref.set({'type': type, 'itemId': itemId, 'createdAt': FieldValue.serverTimestamp()});
    } else {
      await ref.delete();
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> customerProfile() =>
      _db.collection('users').doc(_uid).snapshots();
}
