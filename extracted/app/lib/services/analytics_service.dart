
import 'package:cloud_firestore/cloud_firestore.dart';

class AnalyticsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> getDashboardStats() async {
    final orders = await _db.collection('orders').get();
    final shops = await _db.collection('shops').get();
    final users = await _db.collection('users').get();
    final products = await _db.collection('products').get();

    double revenue = 0;
    double customerCollections = 0;
    double platformCommission = 0;
    int delivered = 0;
    int pending = 0;

    for (final order in orders.docs) {
      final data = order.data();
      final status = data['status'];

      if (status == 'delivered') {
        delivered++;
        // Worker schema: subtotal is merchandise sales; customerTotal includes fees.
        revenue += (data['subtotal'] as num? ?? 0).toDouble();
        customerCollections += (data['customerTotal'] as num? ?? 0).toDouble();
        platformCommission += (data['commissionAmount'] as num? ?? 0).toDouble();
      } else if (status == 'placed' || status == 'accepted') {
        pending++;
      }
    }

    return {
      'totalOrders': orders.size,
      'deliveredOrders': delivered,
      'pendingOrders': pending,
      'totalRevenue': revenue,
      'customerCollections': customerCollections,
      'platformCommission': platformCommission,
      'totalShops': shops.size,
      'totalUsers': users.size,
      'totalProducts': products.size,
    };
  }
}
