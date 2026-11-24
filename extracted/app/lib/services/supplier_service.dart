
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SupplierService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw Exception('कृपया पहले लॉगिन करें।');
    return user.uid;
  }

  Future<String> addSupplier({
    required String name,
    required String phone,
    required String address,
  }) async {
    final ref = await _db.collection('suppliers').add({
      'shopkeeperId': _uid,
      'name': name.trim(),
      'phone': phone.trim(),
      'address': address.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return ref.id;
  }

  Future<void> addTransaction({
    required String supplierId,
    required double amount,
    required String type,
    required String note,
  }) async {
    if (amount <= 0) throw Exception('सही राशि दर्ज करें।');

    if (type != 'purchase' && type != 'payment') {
      throw Exception('लेन-देन का प्रकार सही नहीं है।');
    }

    final supplier = await _db
        .collection('suppliers')
        .doc(supplierId)
        .get();

    if (!supplier.exists ||
        supplier.data()?['shopkeeperId'] != _uid) {
      throw Exception('आपूर्तिकर्ता नहीं मिला।');
    }

    await _db.collection('supplier_transactions').add({
      'shopkeeperId': _uid,
      'supplierId': supplierId,
      'amount': amount,
      'type': type,
      'note': note.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> mySuppliers() {
    return _db
        .collection('suppliers')
        .where('shopkeeperId', isEqualTo: _uid)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> supplierLedger(
    String supplierId,
  ) {
    return _db
        .collection('supplier_transactions')
        .where('shopkeeperId', isEqualTo: _uid)
        .where('supplierId', isEqualTo: supplierId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
