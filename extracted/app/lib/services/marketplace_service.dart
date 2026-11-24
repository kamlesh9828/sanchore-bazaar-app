
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'worker_api.dart';

class MarketplaceService {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  // GPS permission aur current location
  Future<Position?> getCustomerLocation() async {
    bool enabled = await Geolocator.isLocationServiceEnabled();

    if (!enabled) {
      throw Exception('फ़ोन का GPS चालू करें।');
    }

    LocationPermission permission =
        await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('लोकेशन की अनुमति देना जरूरी है।');
    }

    return await Geolocator.getCurrentPosition();
  }

  // Approved shops
  Stream<QuerySnapshot<Map<String, dynamic>>> getShops() {
    return db.collection('shops')
        .where('approved', isEqualTo: true)
        .snapshots();
  }

  // Shop ke products
  Stream<QuerySnapshot<Map<String, dynamic>>> getProducts(
      String shopId) {
    return db.collection('products')
        .where('shopId', isEqualTo: shopId)
        .where('active', isEqualTo: true)
        .snapshots();
  }

  // Customer order - secure backend function
  Future<Map<String, dynamic>> placeOrder({
    required String shopId,
    required List<Map<String, dynamic>> items,
    required String address,
    String paymentMethod = 'cod',
  }) async {
    if (auth.currentUser == null) {
      throw Exception('कृपया पहले लॉगिन करें।');
    }

    if (items.isEmpty) {
      throw Exception('आपकी सामान सूची खाली है।');
    }

    return WorkerApi.post('/api/createOrder', {
      'shopId': shopId,
      'items': items,
      'address': address,
      'paymentMethod': paymentMethod,
    });
  }

  // Customer ke orders
  Stream<QuerySnapshot<Map<String, dynamic>>> getMyOrders() {
    final uid = auth.currentUser!.uid;

    return db.collection('orders')
        .where('customerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Shopkeeper ke orders
  Stream<QuerySnapshot<Map<String, dynamic>>> getShopOrders() {
    final uid = auth.currentUser!.uid;

    return db.collection('orders')
        .where('shopkeeperId', isEqualTo: uid)
        .snapshots();
  }

  // Delivery boy ke assigned orders
  Stream<QuerySnapshot<Map<String, dynamic>>>
      getDeliveryOrders() {
    final uid = auth.currentUser!.uid;

    return db.collection('orders')
        .where('deliveryBoyId', isEqualTo: uid)
        .snapshots();
  }

  // Complaint submit
  Future<void> submitComplaint({
    required String subject,
    required String description,
  }) async {
    final uid = auth.currentUser!.uid;

    await db.collection('complaints').add({
      'userId': uid,
      'subject': subject,
      'description': description,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Review ek delivered order par; orderId se duplicate reviews rukte hain.
  Future<void> submitReview({
    required String shopId,
    required String orderId,
    required double rating,
    required String comment,
  }) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('कृपया पहले लॉगिन करें।');
    if (rating < 1 || rating > 5) {
      throw Exception('रेटिंग 1 से 5 के बीच होनी चाहिए।');
    }
    final order = await db.collection('orders').doc(orderId).get();
    if (!order.exists || order.data()?['customerId'] != user.uid ||
        order.data()?['shopId'] != shopId || order.data()?['status'] != 'delivered') {
      throw Exception('Sirf apne delivered order par review de sakte hain');
    }
    await db.collection('reviews').doc(orderId).set({
      'customerId': user.uid,
      'shopId': shopId,
      'orderId': orderId,
      'rating': rating.round(),
      'comment': comment.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
}
}
