
import 'package:cloud_firestore/cloud_firestore.dart';

class CouponService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> validateCoupon({
    required String code,
    required double orderAmount,
  }) async {
    final snapshot = await _db
        .collection('coupons')
        .doc(code.trim().toUpperCase())
        .get();

    if (!snapshot.exists) {
      throw Exception('कूपन नहीं मिला।');
    }

    final data = snapshot.data()!;
    final now = DateTime.now();

    if (data['active'] != true) {
      throw Exception('यह कूपन अभी बंद है।');
    }

    final start = (data['startAt'] as Timestamp?)?.toDate();
    final end = (data['endAt'] as Timestamp?)?.toDate();

    if (start != null && now.isBefore(start)) {
      throw Exception('इस कूपन की अवधि अभी शुरू नहीं हुई है।');
    }

    if (end != null && now.isAfter(end)) {
      throw Exception('इस कूपन की अवधि समाप्त हो गई है।');
    }

    final minimum = (data['minimumOrder'] ?? 0).toDouble();

    if (orderAmount < minimum) {
      throw Exception('Minimum order ₹$minimum hona chahiye');
    }

    final type = data['discountType'];
    final value = (data['discountValue'] ?? 0).toDouble();

    double discount = 0;

    if (type == 'percentage') {
      discount = orderAmount * value / 100;
    } else if (type == 'fixed') {
      discount = value;
    }

    final maxDiscount = data['maximumDiscount'];

    if (maxDiscount != null) {
      discount = discount.clamp(0, (maxDiscount as num).toDouble());
    }

    discount = discount.clamp(0, orderAmount);

    return {
      'code': code.trim().toUpperCase(),
      'discount': discount,
      'finalAmount': orderAmount - discount,
    };
  }
}
