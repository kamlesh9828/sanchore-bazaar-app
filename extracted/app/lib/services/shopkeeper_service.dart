
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'worker_api.dart';

class ShopkeeperService {
  final db = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;

  String get uid {
    final user = auth.currentUser;
    if (user == null) throw Exception('कृपया पहले लॉगिन करें।');
    return user.uid;
  }

  Future<String> addShop({required String name, required String category, required String address, required String phone, required String ownerName, String? photoUrl}) async {
    final result = await WorkerApi.post('/api/shopkeeper/requestShopAddition', {
      'name': name.trim(), 'category': category.trim(), 'address': address.trim(),
      'phone': phone.trim(), 'ownerName': ownerName.trim(), 'photoUrl': (photoUrl ?? '').trim(),
    });
    return (result['requestId'] ?? '').toString();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> myShopRequests() {
    return db.collection('shop_requests').where('ownerId', isEqualTo: uid).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> myShops() {
    return db.collection('shops')
        .where('ownerId', isEqualTo: uid)
        .snapshots();
  }

  Future<String> addProduct({String? productId, required String shopId, required String name, required double price, required int stock, required String category, String? imageUrl, String? productEmoji, bool imageVerified = false, String unit = 'नग'}) async {
    final result = await WorkerApi.post('/api/saveProduct', {
      if (productId != null) 'productId': productId, 'shopId': shopId, 'name': name.trim(), 'price': price, 'stock': stock, 'category': category.trim(), 'unit': unit, 'imageUrl': imageUrl, 'productEmoji': productEmoji, 'imageVerified': imageVerified,
    });
    return (result['productId'] ?? '').toString();
  }

  Future<void> updateProduct({required String productId, required String name, required double price, required int stock, String? shopId, String? category, String? unit, String? imageUrl, String? productEmoji, bool? imageVerified}) async {
    final ref = db.collection('products').doc(productId);
    final old = await ref.get();
    final data = old.data();
    if (!old.exists || data?['ownerId'] != uid) throw Exception('Product access denied');
    await WorkerApi.post('/api/saveProduct', {
      'productId': productId, 'shopId': shopId ?? data?['shopId'], 'name': name.trim(),
      'price': price, 'stock': stock, 'category': category ?? data?['category'] ?? 'General', 'unit': unit ?? data?['unit'] ?? 'नग', if (imageUrl != null) 'imageUrl': imageUrl, if (productEmoji != null) 'productEmoji': productEmoji, if (imageVerified != null) 'imageVerified': imageVerified,
    });
  }

  Future<void> deleteProduct(String productId) async {
    await WorkerApi.post('/api/deleteProduct', {'productId': productId});
  }

  Future<void> changeStock({required String productId, required int quantity}) async {
    final ref = db.collection('products').doc(productId);
    final old = await ref.get();
    final data = old.data();
    if (!old.exists || data?['ownerId'] != uid) throw Exception('Product access denied');
    await WorkerApi.post('/api/saveProduct', {
      'productId': productId, 'shopId': data?['shopId'], 'name': data?['name'],
      'price': data?['price'], 'stock': quantity, 'category': data?['category'] ?? 'General', 'unit': data?['unit'] ?? 'नग',
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> myProducts(
      String shopId) {
    return db.collection('products')
        .where('shopId', isEqualTo: shopId)
        .where('ownerId', isEqualTo: uid)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> myOrders() {
    return db.collection('orders')
        .where('shopkeeperId', isEqualTo: uid)
        .snapshots();
  }

  Future<void> updateOrderStatus({required String orderId, required String status, String? deliveryMode}) async {
    await WorkerApi.post('/api/updateStaffOrder', {
      'orderId': orderId, 'status': status, if (deliveryMode != null) 'deliveryMode': deliveryMode,
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> salesHistory() {
    return db.collection('orders')
        .where('shopkeeperId', isEqualTo: uid)
        .where('status', isEqualTo: 'delivered')
        .snapshots();
  }
}
