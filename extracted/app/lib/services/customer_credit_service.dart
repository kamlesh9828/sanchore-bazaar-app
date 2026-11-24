
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CustomerCreditService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw Exception('कृपया पहले लॉगिन करें।');
    return user.uid;
  }

  Future<void> addCredit({
    required String customerName,
    required String phone,
    required double amount,
    required String note,
  }) async {
    if (amount <= 0) throw Exception('सही राशि दर्ज करें।');

    await _db.collection('customer_credit').add({
      'shopkeeperId': _uid,
      'customerName': customerName.trim(),
      'phone': phone.trim(),
      'amount': amount,
      'type': 'credit',
      'note': note.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addPayment({
    required String creditId,
    required double amount,
    required String note,
  }) async {
    if (amount <= 0) throw Exception('सही राशि दर्ज करें।');

    final ref = _db.collection('customer_credit').doc(creditId);
    final doc = await ref.get();

    if (!doc.exists || doc.data()?['shopkeeperId'] != _uid) {
      throw Exception('रिकॉर्ड नहीं मिला।');
    }

    await _db.collection('customer_credit_payments').add({
      'shopkeeperId': _uid,
      'creditId': creditId,
      'amount': amount,
      'note': note.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> myCredits() {
    return _db
        .collection('customer_credit')
        .where('shopkeeperId', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
