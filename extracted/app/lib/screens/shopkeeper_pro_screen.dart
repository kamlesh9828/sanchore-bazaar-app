import 'package:flutter/material.dart';
import '../services/shopkeeper_pro_service.dart';
import 'paytm_checkout_screen.dart';

class ShopkeeperProScreen extends StatefulWidget {
  const ShopkeeperProScreen({super.key});
  @override
  State<ShopkeeperProScreen> createState() => _ShopkeeperProScreenState();
}

class _ShopkeeperProScreenState extends State<ShopkeeperProScreen> {
  final service = ShopkeeperProService();
  String? selectedShopId;
  Map<String, dynamic>? data;
  bool loading = false;
  String? error;

  Future<void> load(String shopId) async {
    setState(() { loading = true; error = null; });
    try {
      final result = await service.info(shopId);
      if (!mounted) return;
      setState(() { data = result; loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { error = e.toString().replaceFirst('Exception: ', ''); loading = false; });
    }
  }

  Future<void> buy(String planId) async {
    final shopId = selectedShopId;
    if (shopId == null) return;
    setState(() => loading = true);
    try {
      final session = await service.createPayment(shopId: shopId, planId: planId);
      final sessionId = (session['sessionId'] ?? '').toString();
      final checkout = await service.initiatePayment(sessionId);
      if (!mounted) return;
      final paid = await Navigator.push<bool>(context, MaterialPageRoute(
        builder: (_) => PaytmCheckoutScreen(
          checkoutUrl: (checkout['checkoutUrl'] ?? '').toString(),
          sessionId: sessionId,
        ),
      ));
      if (!mounted) return;
      if (paid == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pro सदस्यता सफलतापूर्वक चालू हो गई।')));
        await load(shopId);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('दुकानदार Pro सदस्यता')),
    body: StreamBuilder(
      stream: service.myShops(),
      builder: (context, snap) {
        if (snap.hasError) return const Center(child: Text('दुकान की जानकारी नहीं मिल सकी।'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final shops = snap.data!.docs.where((d) => d.data()['approved'] == true && d.data()['active'] == true).toList();
        if (shops.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Pro सदस्यता लेने के लिए पहले आपकी दुकान का Admin से स्वीकृत होना जरूरी है।', textAlign: TextAlign.center)));
        selectedShopId ??= shops.first.id;
        if (!shops.any((d) => d.id == selectedShopId)) selectedShopId = shops.first.id;
        if (data == null && !loading) WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted && selectedShopId != null && data == null) load(selectedShopId!); });
        final subscription = (data?['subscription'] as Map?)?.cast<String, dynamic>() ?? {};
        final plans = (data?['plans'] as Map?)?.cast<String, dynamic>() ?? {};
        final active = subscription['status'] == 'active';
        return ListView(padding: const EdgeInsets.all(16), children: [
          DropdownButtonFormField<String>(value: selectedShopId, decoration: const InputDecoration(labelText: 'दुकान चुनें', border: OutlineInputBorder()), items: shops.map((d) => DropdownMenuItem(value: d.id, child: Text((d.data()['name'] ?? 'मेरी दुकान').toString()))).toList(), onChanged: (v) { if (v == null) return; setState(() { selectedShopId = v; data = null; }); load(v); }),
          const SizedBox(height: 14),
          Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF18213D), Color(0xFF087E58)]), borderRadius: BorderRadius.circular(20)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Row(children: [Icon(Icons.workspace_premium, color: Colors.amber, size: 30), SizedBox(width: 8), Text('Sanchore Bazaar Pro', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900))]), const SizedBox(height: 8), Text(active ? 'आपकी Pro सदस्यता चालू है' : 'अपनी दुकान को और ग्राहकों तक पहुँचाएँ', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)), if (active) Text('बाकी दिन: ${subscription['remainingDays'] ?? 0} • समाप्ति: ${subscription['until'] ?? '—'}', style: const TextStyle(color: Colors.white70))])),
          const SizedBox(height: 16),
          const Text('Pro में मिलने वाली सुविधाएँ', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const _Benefit(icon: Icons.verified, title: 'दुकान पर Pro बैज', subtitle: 'ग्राहकों को आपकी सदस्यता की पहचान दिखेगी।'),
          const _Benefit(icon: Icons.trending_up, title: 'दुकान सूची में प्राथमिकता', subtitle: 'सक्रिय Pro दुकानें ग्राहक की दुकान सूची में पहले दिखाई देंगी.'),
          const _Benefit(icon: Icons.event_available, title: 'सदस्यता की अवधि पर नियंत्रण', subtitle: 'समाप्ति की तारीख देखें और समय पूरा होने पर नवीनीकरण करें.'),
          const _Benefit(icon: Icons.verified_user, title: 'सुरक्षित भुगतान', subtitle: 'Paytm भुगतान सत्यापित होने के बाद ही Pro चालू होता है.'),
          if (loading) const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
          if (error != null) Padding(padding: const EdgeInsets.all(8), child: Text(error!, style: const TextStyle(color: Colors.red))),
          const SizedBox(height: 8),
          _planCard('monthly', 'मासिक सदस्यता', plans['monthly'], active, () => buy('monthly')),
          _planCard('yearly', 'वार्षिक सदस्यता', plans['yearly'], active, () => buy('yearly')),
          const SizedBox(height: 10),
          const Text('सदस्यता Paytm से भुगतान सफल होने पर ही चालू होगी। यह स्वतः नवीनीकृत नहीं होती; अवधि पूरी होने पर दोबारा भुगतान करना होगा।', style: TextStyle(fontSize: 12, color: Colors.black54)),
        ]);
      },
    ),
  );

  Widget _planCard(String id, String title, dynamic raw, bool active, VoidCallback onTap) {
    final plan = raw is Map ? raw : <String, dynamic>{};
    final benefits = (plan['benefits'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
    return Card(child: Padding(padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
      Text('₹${plan['amount'] ?? (id == 'monthly' ? 299 : 2999)}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF087E58))),
      ...benefits.take(4).map((b) => Padding(padding: const EdgeInsets.only(top: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.check_circle, color: Color(0xFF087E58), size: 17), const SizedBox(width: 7), Expanded(child: Text(b))]))),
      const SizedBox(height: 10),
      SizedBox(width: double.infinity, child: FilledButton(onPressed: loading ? null : onTap, child: Text(active ? 'सदस्यता बढ़ाएँ' : 'अभी सदस्यता लें'))),
    ])));
  }
}

class _Benefit extends StatelessWidget {
  final IconData icon; final String title; final String subtitle;
  const _Benefit({required this.icon, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => ListTile(contentPadding: EdgeInsets.zero, leading: CircleAvatar(backgroundColor: const Color(0xFFE7F5EE), child: Icon(icon, color: const Color(0xFF087E58))), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(subtitle));
}
