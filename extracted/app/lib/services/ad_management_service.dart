import 'package:cloud_firestore/cloud_firestore.dart';

import 'worker_api.dart';

/// Advertisement service.
/// All advertisement writes and privileged reads go through Cloudflare Worker.
/// Firestore is used here only for the approved-shop picker (read-only).
class AdManagementService {
  /// Admin: get all advertisement campaigns.
  Future<List<Map<String, dynamic>>> adminCampaigns() async {
    final response = await WorkerApi.post(
      '/api/admin/listAds',
      <String, dynamic>{},
    );
    return _campaignList(response);
  }

  /// Shopkeeper: get only the signed-in shopkeeper's campaigns.
  Future<List<Map<String, dynamic>>> myCampaigns() async {
    final response = await WorkerApi.post(
      '/api/shopkeeper/myAds',
      <String, dynamic>{},
    );
    return _campaignList(response);
  }

  /// Admin: get advertisement prices and payment settings.
  Future<Map<String, dynamic>> settings() async {
    final response = await WorkerApi.post(
      '/api/admin/getAdSettings',
      <String, dynamic>{},
    );
    final value = response['settings'];
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  /// Shopkeeper: get Admin UPI ID, QR URL and package prices.
  Future<Map<String, dynamic>> paymentInfo() async {
    final response = await WorkerApi.post(
      '/api/shopkeeper/adPaymentInfo',
      <String, dynamic>{},
    );
    return response;
  }

  /// Admin: save package prices and payment destination.
  Future<void> saveSettings({
    required Map<String, double> prices,
  }) async {
    final packagePrices = <String, double>{
      for (final entry in prices.entries) entry.key: entry.value,
    };

    await WorkerApi.post('/api/admin/saveAdSettings', {
      'packagePrices': packagePrices,
    });
  }

  /// Admin: create a draft advertisement for an approved shop.
  Future<String> createAd({
    required String shopId,
    required String title,
    required String description,
    required String imageUrl,
    required String placement,
    required int days,
  }) async {
    final response = await WorkerApi.post('/api/admin/createAd', {
      'shopId': shopId,
      'title': title.trim(),
      'description': description.trim(),
      'imageUrl': imageUrl.trim(),
      'placement': placement,
      'packageDays': days,
    });

    return (response['campaignId'] ?? '').toString();
  }


  /// Start a secure Paytm payment for an approved advertisement campaign.
  Future<Map<String, dynamic>> startAdPayment(String campaignId) async {
    return WorkerApi.post('/api/advertiser/createAdPayment', {'campaignId': campaignId});
  }

  /// Admin: edit a draft campaign only.
  Future<void> updateAd({
    required String campaignId,
    required Map<String, dynamic> fields,
  }) async {
    await WorkerApi.post('/api/admin/updateAd', {
      'campaignId': campaignId,
      ...fields,
    });
  }

  /// Admin: set the amount and send the campaign for payment.
  Future<void> submitAdPaymentReference({required String campaignId, required String reference}) async {
    await WorkerApi.post('/api/advertiser/submitAdPayment', {'campaignId': campaignId, 'paymentReference': reference.trim()});
  }

  Future<void> quote({
    required String campaignId,
    required double amount,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('रकम शून्य से अधिक होनी चाहिए।');
    }

    await WorkerApi.post('/api/admin/quoteAd', {
      'campaignId': campaignId,
      'amount': amount,
    });
  }

  /// Admin: after checking the UPI/bank receipt manually, verify and activate.
  Future<void> verify({
    required String campaignId,
    required String utr,
    required double amount,
  }) async {
    if (utr.trim().length < 6) {
      throw ArgumentError('सही UPI Transaction ID / UTR भरें।');
    }

    if (amount <= 0) {
      throw ArgumentError('प्राप्त रकम सही भरें।');
    }

    await WorkerApi.post('/api/admin/verifyActivateAd', {
      'campaignId': campaignId,
      'paymentReference': utr.trim(),
      'paidAmount': amount,
    });
  }

  /// Admin: pause, resume, reject or delete a campaign.
  Future<void> changeStatus({
    required String campaignId,
    required String action,
    String reason = '',
  }) async {
    const allowed = {'pause', 'resume', 'reject', 'delete'};

    if (!allowed.contains(action)) {
      throw ArgumentError('विज्ञापन की कार्रवाई मान्य नहीं है।');
    }

    if (action == 'reject' && reason.trim().isEmpty) {
      throw ArgumentError('अस्वीकार करने का कारण लिखें।');
    }

    await WorkerApi.post('/api/admin/changeAdStatus', {
      'campaignId': campaignId,
      'action': action,
      if (action == 'reject') 'reason': reason.trim(),
    });
  }

  /// Customer/shopkeeper only submits a brief. Admin creates the actual ad.
  Future<String> submitAdRequest({required String businessName, required String phone, required String brief, String referenceImageUrl = ''}) async {
    final response = await WorkerApi.post('/api/advertiser/requestAd', {
      'businessName': businessName.trim(), 'phone': phone.trim(),
      'brief': brief.trim(), 'referenceImageUrl': referenceImageUrl.trim(),
    });
    return (response['requestId'] ?? '').toString();
  }

  Future<List<Map<String, dynamic>>> myAdRequests() async {
    final response = await WorkerApi.post('/api/advertiser/myAdRequests', <String, dynamic>{});
    final raw = response['requests'];
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<Map<String, dynamic>> generateAiAdCreative({required String businessName, required String brief}) async {
    return WorkerApi.post('/api/admin/generateAdCreative', {'businessName': businessName, 'brief': brief}, timeout: const Duration(seconds: 120));
  }

  Future<List<Map<String, dynamic>>> adminAdRequests() async {
    final response = await WorkerApi.post('/api/admin/listAdRequests', <String, dynamic>{});
    final raw = response['requests'];
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> rejectAdRequest({required String requestId, required String reason}) async {
    await WorkerApi.post('/api/admin/rejectAdRequest', {'requestId': requestId, 'reason': reason});
  }

  Future<String> createAdFromRequest({required String requestId, required String title, required String description, required String imageUrl, required String destinationUrl, required String placement, required int days}) async {
    final response = await WorkerApi.post('/api/admin/createAdFromRequest', {
      'requestId': requestId, 'title': title.trim(), 'description': description.trim(),
      'imageUrl': imageUrl.trim(), 'destinationUrl': destinationUrl.trim(),
      'placement': placement, 'packageDays': days,
    });
    return (response['campaignId'] ?? '').toString();
  }

  /// Signed-in customer: get currently active advertisements.
  Future<List<Map<String, dynamic>>> activeAds() async {
    final response = await WorkerApi.post(
      '/api/activeAds',
      <String, dynamic>{},
    );
    return _campaignList(response);
  }

  /// Record an impression or click through the Worker.
  Future<void> trackEvent(String campaignId, String eventType) async {
    if (!{'impression', 'click'}.contains(eventType)) {
      throw ArgumentError('विज्ञापन इवेंट मान्य नहीं है।');
    }

    await WorkerApi.post('/api/trackAdEvent', {
      'campaignId': campaignId,
      'eventType': eventType,
    });
  }

  /// Read-only approved and active shop list for Admin.
  /// Returns a list of maps instead of QuerySnapshot.
  Stream<List<Map<String, dynamic>>> approvedShops() {
    return FirebaseFirestore.instance
        .collection('shops')
        .where('approved', isEqualTo: true)
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return <String, dynamic>{
          ...doc.data(),
          'id': doc.id,
        };
      }).toList(growable: false);
    });
  }

  List<Map<String, dynamic>> _campaignList(
    Map<String, dynamic> response,
  ) {
    final raw = response['campaigns'];

    if (raw is! List) {
      return <Map<String, dynamic>>[];
    }

    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }
}
