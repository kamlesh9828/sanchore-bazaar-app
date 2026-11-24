
import 'package:cloud_firestore/cloud_firestore.dart';

class CatalogService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Approved shops
  Stream<QuerySnapshot<Map<String, dynamic>>> getShops() {
    return _db
        .collection('shops')
        .where('approved', isEqualTo: true)
        .where('active', isEqualTo: true)
        .snapshots();
  }

  // Ek shop ke products
  Stream<QuerySnapshot<Map<String, dynamic>>> getShopProducts(
    String shopId,
  ) {
    return _db
        .collection('products')
        .where('shopId', isEqualTo: shopId)
        .where('active', isEqualTo: true)
        .snapshots();
  }

  // Category ke products
  Stream<QuerySnapshot<Map<String, dynamic>>> getCategoryProducts(
    String category,
  ) {
    return _db
        .collection('products')
        .where('category', isEqualTo: category)
        .where('active', isEqualTo: true)
        .snapshots();
  }

  // Search products
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      searchProducts(String searchText) async {
    final query = searchText.trim().toLowerCase();

    if (query.isEmpty) return [];

    final result = await _db
        .collection('products')
        .where('active', isEqualTo: true)
        .get();

    return result.docs.where((doc) {
      final name = (doc.data()['name'] ?? '')
          .toString()
          .toLowerCase();

      return name.contains(query);
    }).toList();
  }
}
