import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReportService {
  final db = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;
  String get uid => auth.currentUser?.uid ?? (throw Exception('कृपया पहले लॉगिन करें।'));

  Future<Map<String, dynamic>> shopSummary({DateTime? from, DateTime? to}) async {
    final shop = await db.collection('shops').where('ownerId', isEqualTo: uid).get();
    final shopIds = shop.docs.map((d) => d.id).toSet();
    if (shopIds.isEmpty) return {'orders': 0, 'sales': 0.0, 'delivered': 0};
    // Firestore whereIn accepts at most 30 values; query one shop at a time for wider accounts.
    int count = 0, delivered = 0; double sales = 0;
    for (final id in shopIds) {
      Query<Map<String, dynamic>> q = db.collection('orders').where('shopId', isEqualTo: id);
      if (from != null) q = q.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from));
      if (to != null) q = q.where('createdAt', isLessThan: Timestamp.fromDate(to));
      final snap = await q.get();
      for (final d in snap.docs) {
        count++;
        final data = d.data();
        if (data['status'] == 'delivered') {
          delivered++;
          // Shop sales are merchandise subtotal; fees are reported separately.
          final amount = data['subtotal'] ?? data['totalAmount'] ?? data['total'] ?? 0;
          if (amount is num) sales += amount.toDouble();
        }
      }
    }
    final settlements = await db.collection('shopkeeper_settlements')
        .where('shopkeeperId', isEqualTo: uid).get();
    double netSettlement = 0;
    double pendingSettlement = 0;
    double paidSettlement = 0;
    for (final doc in settlements.docs) {
      final data = doc.data();
      final amount = (data['netAmount'] as num? ?? 0).toDouble();
      netSettlement += amount;
      if (data['paid'] == true) {
        paidSettlement += amount;
      } else {
        pendingSettlement += amount;
      }
    }
    return {
      'orders': count,
      'delivered': delivered,
      'sales': sales,
      'netSettlement': netSettlement,
      'pendingSettlement': pendingSettlement,
      'paidSettlement': paidSettlement,
    };
  }

  Future<Map<String, dynamic>> adminSummary() async {
    final profile = await db.collection('users').doc(uid).get();
    if (profile.data()?['role'] != 'admin' || profile.data()?['approved'] != true) {
      throw Exception('Admin permission required');
    }
    final results = await Future.wait([
      db.collection('orders').get(), db.collection('shops').get(),
      db.collection('users').where('approved', isEqualTo: false).get(),
      db.collection('complaints').where('status', isEqualTo: 'open').get(),
    ]);
    return {'orders': results[0].size, 'shops': results[1].size,
      'pendingApprovals': results[2].size, 'openComplaints': results[3].size};
  }
}
