
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OrderTrackingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw Exception('कृपया पहले लॉगिन करें।');
    return user.uid;
  }

  // Customer ke sabhi orders
  Stream<QuerySnapshot<Map<String, dynamic>>> myOrders() {
    return _db
        .collection('orders')
        .where('customerId', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Ek order ki live details
  Stream<DocumentSnapshot<Map<String, dynamic>>> trackOrder(
    String orderId,
  ) {
    return _db.collection('orders').doc(orderId).snapshots();
  }

  // Delivery boy ki live location
  Stream<GeoPoint?> deliveryLocation(String orderId) {
    return _db.collection('orders').doc(orderId).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) return null;

      final location = data['deliveryLocation'];
      if (location is GeoPoint) return location;
      // Backward compatibility for orders created by the older map-based GPS code.
      if (location is Map) {
        final latitude = location['latitude'];
        final longitude = location['longitude'];
        if (latitude is num && longitude is num) {
          return GeoPoint(latitude.toDouble(), longitude.toDouble());
        }
      }
      return null;
    });
  }

  // Order history
  Stream<QuerySnapshot<Map<String, dynamic>>> orderHistory() {
    return _db
        .collection('orders')
        .where('customerId', isEqualTo: _uid)
        .where('status', whereIn: [
          'delivered',
          'cancelled',
          'rejected',
        ])
        .snapshots();
  }
}
