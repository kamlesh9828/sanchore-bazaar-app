
import 'package:cloud_firestore/cloud_firestore.dart';

class PromotionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> activePromotions() {
    return _db
        .collection('promotions')
        .where('active', isEqualTo: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> sponsoredShops() {
    return _db
        .collection('shops')
        .where('approved', isEqualTo: true)
        .where('sponsored', isEqualTo: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> activeOffers() {
    return _db
        .collection('offers')
        .where('active', isEqualTo: true)
        .snapshots();
  }
}
