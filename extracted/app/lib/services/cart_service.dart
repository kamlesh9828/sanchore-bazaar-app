
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CartService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw Exception('कृपया पहले लॉगिन करें।');
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _cart =>
      _db.collection('carts').doc(_uid).collection('items');

  Stream<QuerySnapshot<Map<String, dynamic>>> getCart() {
    return _cart.snapshots();
  }

  Future<void> addItem({
    required String productId,
    required String shopId,
    required String name,
    required double price,
    required int quantity,
    String unit = 'नग',
    String? imageUrl,
    String? productEmoji,
  }) async {
    if (quantity < 1 || price < 0) {
      throw Exception('मात्रा या कीमत सही नहीं है।');
    }

    // Never trust the product snapshot passed by the list: stock may have changed.
    final productSnap = await _db.collection('products').doc(productId).get();
    final product = productSnap.data();
    final liveStock = (product?['stock'] as num?)?.toInt() ?? 0;
    if (!productSnap.exists || product?['active'] != true || liveStock < 1) {
      throw Exception('यह सामान अभी Out of Stock है।');
    }
    if ((product?['shopId'] ?? '') != shopId) throw Exception('दुकान की जानकारी बदल गई है।');
    final ref = _cart.doc(productId);
    final existing = await ref.get();
    final oldQuantity = (existing.data()?['quantity'] as num?)?.toInt() ?? 0;
    if (oldQuantity + quantity > liveStock) {
      throw Exception('केवल $liveStock $unit उपलब्ध हैं। कार्ट की मात्रा कम करें।');
    }
    final livePrice = (product?['price'] as num?)?.toDouble() ?? price;
    if (existing.exists) {
      await ref.update({'quantity': oldQuantity + quantity, 'price': livePrice, 'name': product?['name'] ?? name, 'unit': product?['unit'] ?? unit, 'productEmoji': product?['productEmoji'] ?? productEmoji ?? '🛍️', 'imageVerified': product?['imageVerified'] == true, if (product?['imageVerified'] == true && (product?['imageUrl'] ?? '').toString().isNotEmpty) 'imageUrl': product?['imageUrl']});
    } else {
      await ref.set({
        'productId': productId, 'shopId': shopId,
        'name': product?['name'] ?? name, 'price': livePrice,
        'unit': product?['unit'] ?? unit,
        if (product?['imageVerified'] == true && ((product?['imageUrl'] ?? imageUrl) ?? '').toString().isNotEmpty) 'imageUrl': product?['imageUrl'] ?? imageUrl,
        'imageVerified': product?['imageVerified'] == true,
        'productEmoji': product?['productEmoji'] ?? productEmoji ?? '🛍️',
        'quantity': quantity, 'addedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> updateQuantity({
    required String productId,
    required int quantity,
  }) async {
    if (quantity <= 0) {
      await removeItem(productId);
      return;
    }

    final productSnap = await _db.collection('products').doc(productId).get();
    final product = productSnap.data();
    final liveStock = (product?['stock'] as num?)?.toInt() ?? 0;
    if (!productSnap.exists || product?['active'] != true || liveStock < 1) {
      throw Exception('यह सामान Out of Stock हो गया है। इसे कार्ट से हटाएँ।');
    }
    if (quantity > liveStock) throw Exception('केवल $liveStock ही उपलब्ध हैं।');
    await _cart.doc(productId).update({'quantity': quantity, 'price': product?['price'] ?? 0});
  }

  Future<void> removeItem(String productId) async {
    await _cart.doc(productId).delete();
  }

  Future<void> clearCart() async {
    final items = await _cart.get();
    final batch = _db.batch();

    for (final item in items.docs) {
      batch.delete(item.reference);
    }

    await batch.commit();
  }
}
