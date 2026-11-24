
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReviewService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> addReview({
    required String shopId,
    required String orderId,
    required int rating,
    required String comment,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('कृपया पहले लॉगिन करें।');
    }

    if (rating < 1 || rating > 5) {
      throw Exception('रेटिंग 1 से 5 के बीच होनी चाहिए।');
    }

    final order = await _db.collection('orders').doc(orderId).get();

    if (!order.exists ||
        order.data()?['customerId'] != user.uid ||
        order.data()?['shopId'] != shopId ||
        order.data()?['status'] != 'delivered') {
      throw Exception('Sirf delivered order par review de sakte hain');
    }

    await _db.collection('reviews').doc(orderId).set({
      'customerId': user.uid,
      'shopId': shopId,
      'orderId': orderId,
      'rating': rating,
      'comment': comment.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> shopReviews(
    String shopId,
  ) {
    return _db
        .collection('reviews')
        .where('shopId', isEqualTo: shopId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
