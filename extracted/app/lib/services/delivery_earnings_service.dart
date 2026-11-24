
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DeliveryEarningsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw Exception('कृपया पहले लॉगिन करें।');
    return user.uid;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> myEarnings() {
    return _db
        .collection('delivery_earnings')
        .where('deliveryBoyId', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<double> getTotalEarnings() async {
    final result = await _db
        .collection('delivery_earnings')
        .where('deliveryBoyId', isEqualTo: _uid)
        .get();

    double total = 0;

    for (final doc in result.docs) {
      total += (doc.data()['amount'] as num? ?? 0).toDouble();
    }

    return total;
  }

  Future<double> getPendingPayment() async {
    final result = await _db
        .collection('delivery_earnings')
        .where('deliveryBoyId', isEqualTo: _uid)
        .where('paid', isEqualTo: false)
        .get();

    double total = 0;

    for (final doc in result.docs) {
      total += (doc.data()['amount'] as num? ?? 0).toDouble();
    }

    return total;
  }
}
