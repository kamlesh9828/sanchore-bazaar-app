
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ExpenseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw Exception('कृपया पहले लॉगिन करें।');
    return user.uid;
  }

  Future<void> addExpense({
    required String title,
    required double amount,
    required String category,
    String? note,
  }) async {
    if (amount <= 0) {
      throw Exception('सही राशि दर्ज करें।');
    }

    await _db.collection('expenses').add({
      'shopkeeperId': _uid,
      'title': title.trim(),
      'amount': amount,
      'category': category,
      'note': note?.trim() ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> myExpenses() {
    return _db
        .collection('expenses')
        .where('shopkeeperId', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
