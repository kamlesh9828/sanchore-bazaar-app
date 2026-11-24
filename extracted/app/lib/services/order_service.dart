import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'worker_api.dart';

class OrderService {
  final db = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;
  String get uid => auth.currentUser?.uid ?? (throw Exception('कृपया पहले लॉगिन करें।'));

  Future<Map<String, dynamic>> createOrder({
    required String shopId,
    required List<Map<String, dynamic>> items,
    required String address,
    String customerName = '',
    String customerPhone = '',
    double? latitude,
    double? longitude,
    String pinCode = '',
    String paymentMethod = 'cod',
  }) async {
    if (items.isEmpty || address.trim().isEmpty) {
      throw Exception('सामान की सूची और पता जाँचें।');
    }
    return WorkerApi.post('/api/createOrder', {
      'shopId': shopId,
      'items': items,
      'address': address.trim(),
      'customerName': customerName.trim(),
      'customerPhone': customerPhone.trim(),
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'pinCode': pinCode.trim(),
      'paymentMethod': paymentMethod,
    });
  }

  /// Multi-shop cart: one order is created per shop in one atomic backend commit.
  Future<Map<String, dynamic>> createMultiShopOrder({
    required List<Map<String, dynamic>> groups,
    required String address,
    String customerName = '',
    String customerPhone = '',
    double? latitude,
    double? longitude,
    String pinCode = '',
    String paymentMethod = 'cod',
    String couponCode = '',
    bool useWalletPoints = false,
  }) async {
    if (groups.isEmpty || address.trim().isEmpty) {
      throw Exception('सामान की सूची और पता जाँचें।');
    }
    return WorkerApi.post('/api/createOrder', {
      'groups': groups,
      'address': address.trim(),
      'customerName': customerName.trim(),
      'customerPhone': customerPhone.trim(),
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'pinCode': pinCode.trim(),
      'paymentMethod': paymentMethod,
      if (couponCode.trim().isNotEmpty) 'couponCode': couponCode.trim().toUpperCase(),
      'useWalletPoints': useWalletPoints,
    });
  }

  // No composite index required; the screen sorts by createdAt locally.
  Stream<QuerySnapshot<Map<String, dynamic>>> customerOrders() => db
      .collection('orders')
      .where('customerId', isEqualTo: uid)
      .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> shopOrders() => db
      .collection('orders')
      .where('shopkeeperId', isEqualTo: uid)
      .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> deliveryOrders() => db
      .collection('orders')
      .where('deliveryBoyId', isEqualTo: uid)
      .snapshots();

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchOrder(String orderId) =>
      db.collection('orders').doc(orderId).snapshots();

  Future<void> requestCancel(String orderId, String reason) async {
    if (reason.trim().isEmpty) throw Exception('रद्द करने का कारण लिखें।');
    final ref = db.collection('orders').doc(orderId);
    final snap = await ref.get();
    if (!snap.exists || snap.data()?['customerId'] != uid) {
      throw Exception('आपको इस ऑर्डर की जानकारी देखने की अनुमति नहीं है।');
    }
    if (!['placed', 'accepted'].contains(snap.data()?['status'])) {
      throw Exception('ऑर्डर की मौजूदा स्थिति में उसे रद्द करने का अनुरोध नहीं किया जा सकता।');
    }
    await db.collection('cancellationRequests').add({
      'orderId': orderId,
      'customerId': uid,
      'reason': reason.trim(),
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
