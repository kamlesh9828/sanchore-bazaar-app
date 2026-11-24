import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'worker_api.dart';

/// Inventory writes are routed through the authenticated Worker because
/// Firestore client rules intentionally deny direct product mutations.
class InventoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw Exception('कृपया पहले लॉगिन करें।');
    return user.uid;
  }

  Future<void> updateStock({
    required String productId,
    required int stock,
    required int lowStockLimit,
  }) async {
    if (stock < 0 || lowStockLimit < 0) throw Exception('स्टॉक की मात्रा सही नहीं है।');
    final productRef = _db.collection('products').doc(productId);
    final product = await productRef.get();
    final data = product.data();
    if (!product.exists || data?['ownerId'] != _uid) {
      throw Exception('आप केवल अपनी दुकान का सामान अपडेट कर सकते हैं।');
    }
    await WorkerApi.post('/api/saveProduct', {
      'productId': productId,
      'shopId': data?['shopId'],
      'name': data?['name'],
      'category': data?['category'] ?? 'General',
      'price': (data?['price'] as num?)?.toDouble() ?? 0,
      'stock': stock,
      'lowStockLimit': lowStockLimit,
    });
  }

  Future<void> recordPurchase({
    required String productId,
    required int quantity,
    required double totalCost,
  }) async {
    if (quantity <= 0 || totalCost < 0) throw Exception('Purchase details galat hain');
    final product = await _db.collection('products').doc(productId).get();
    if (!product.exists || product.data()?['ownerId'] != _uid) {
      throw Exception('आप केवल अपनी दुकान का सामान अपडेट कर सकते हैं।');
    }
    await WorkerApi.post('/api/recordPurchase', {
      'productId': productId,
      'quantity': quantity,
      'totalCost': totalCost,
    });
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> lowStockProducts() {
    return _db.collection('products').where('ownerId', isEqualTo: _uid)
        .snapshots().map((snapshot) => snapshot.docs.where((doc) {
          final data = doc.data();
          final stock = (data['stock'] as num?)?.toInt() ?? 0;
          final limit = (data['lowStockLimit'] as num?)?.toInt() ?? 5;
          return stock <= limit;
        }).toList());
  }
}
