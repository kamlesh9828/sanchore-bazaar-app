import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/worker_api.dart';

/// Admin-only read-only income overview. It separates app income from
/// merchant/delivery amounts that are payable onward and from AdMob payouts.
class AdminRevenueScreen extends StatelessWidget {
  const AdminRevenueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('मेरी कमाई और भुगतान')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db.collection('ad_campaigns').snapshots(),
        builder: (context, adSnap) {
          if (adSnap.hasError) return const _LoadError();
          if (!adSnap.hasData) return const Center(child: CircularProgressIndicator());
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: db.collection('platform_ledger').snapshots(),
            builder: (context, ledgerSnap) {
              if (ledgerSnap.hasError) return const _LoadError();
              if (!ledgerSnap.hasData) return const Center(child: CircularProgressIndicator());
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: db.collection('shopkeeper_settlements').where('paid', isEqualTo: false).snapshots(),
                builder: (context, shopSnap) {
                  if (shopSnap.hasError) return const _LoadError();
                  if (!shopSnap.hasData) return const Center(child: CircularProgressIndicator());
                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: db.collection('delivery_earnings').where('paid', isEqualTo: false).snapshots(),
                    builder: (context, riderSnap) {
                      if (riderSnap.hasError) return const _LoadError();
                      if (!riderSnap.hasData) return const Center(child: CircularProgressIndicator());

                      double adIncome = 0;
                      int paidCampaigns = 0;
                      double pendingAd = 0;
                      for (final doc in adSnap.data!.docs) {
                        final d = doc.data();
                        final status = (d['paymentStatus'] ?? '').toString().toLowerCase();
                        final amount = ((d['paidAmount'] ?? d['amount'] ?? 0) as num).toDouble();
                        if (status == 'paid' || status == 'verified') {
                          adIncome += amount;
                          paidCampaigns++;
                        } else if (status == 'pending' && d['status'] == 'awaiting_payment') {
                          pendingAd += amount;
                        }
                      }

                      double commission = 0;
                      double platformFee = 0;
                      double orderPaidCollection = 0;
                      double onlineOrderCollection = 0;
                      double codOrderCollection = 0;
                      for (final doc in ledgerSnap.data!.docs) {
                        final d = doc.data();
                        commission += ((d['commissionAmount'] ?? 0) as num).toDouble();
                        platformFee += ((d['platformFee'] ?? 0) as num).toDouble();
                        if ((d['paymentStatus'] ?? '').toString() == 'paid') {
                          final paidOrder = ((d['customerTotal'] ?? 0) as num).toDouble();
                          orderPaidCollection += paidOrder;
                          if ((d['paymentMethod'] ?? '').toString() == 'cod') { codOrderCollection += paidOrder; } else { onlineOrderCollection += paidOrder; }
                        }
                      }
                      double pendingShop = 0;
                      for (final doc in shopSnap.data!.docs) {
                        pendingShop += ((doc.data()['netAmount'] ?? 0) as num).toDouble();
                      }
                      double pendingRider = 0;
                      for (final doc in riderSnap.data!.docs) {
                        pendingRider += ((doc.data()['amount'] ?? 0) as num).toDouble();
                      }

                      final orderIncome = commission + platformFee;
                      final recordedIncome = adIncome + orderIncome;
                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _IncomeHero(amount: recordedIncome),
                          const SizedBox(height: 12),
                          _IncomeCard(title: 'विज्ञापन पैकेज से प्राप्त भुगतान', amount: adIncome, subtitle: '$paidCampaigns सफल/सत्यापित कैंपेन • Paytm Merchant', icon: Icons.campaign_rounded),
                          _IncomeCard(title: 'ग्राहकों से प्राप्त ऑर्डर भुगतान', amount: orderPaidCollection, subtitle: 'ऑनलाइन ₹${onlineOrderCollection.toStringAsFixed(2)} • COD ₹${codOrderCollection.toStringAsFixed(2)} — यह पूरी रकम आपकी कमाई नहीं है', icon: Icons.shopping_bag_rounded),
                          _IncomeCard(title: 'ऑर्डर से कमीशन', amount: commission, subtitle: 'डिलीवर हुए ऑर्डर पर आपकी कमीशन आय', icon: Icons.percent_rounded),
                          _IncomeCard(title: 'ऑर्डर से प्लेटफ़ॉर्म शुल्क', amount: platformFee, subtitle: 'डिलीवर हुए ऑर्डर पर ग्राहक से लिया गया प्लेटफ़ॉर्म शुल्क', icon: Icons.account_balance_wallet_outlined),
                          const SizedBox(height: 8),
                          const Text('भुगतान की ज़िम्मेदारियाँ', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                          _IncomeCard(title: 'दुकानदारों को देना बाकी', amount: pendingShop, subtitle: 'लंबित दुकानदार सेटलमेंट', icon: Icons.storefront_rounded, warning: true),
                          _IncomeCard(title: 'डिलीवरी पार्टनर को देना बाकी', amount: pendingRider, subtitle: 'लंबित डिलीवरी भुगतान', icon: Icons.delivery_dining_rounded, warning: true),
                          if (pendingAd > 0) _IncomeCard(title: 'विज्ञापन भुगतान बाकी', amount: pendingAd, subtitle: 'अभी भुगतान सत्यापित नहीं हुआ है', icon: Icons.hourglass_top_rounded, warning: true),
                          const SizedBox(height: 12),
                          Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('AdMob की कमाई', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                            const SizedBox(height: 5),
                            const Text('Google AdMob की वास्तविक कमाई और बैंक भुगतान आपके AdMob Payments खाते में दिखाई देते हैं। यह Paytm विज्ञापन पैकेज और ऑर्डर भुगतान से अलग है; इसे यहाँ स्वतः आयात नहीं किया जाता।', style: TextStyle(color: Colors.black54, height: 1.35)),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(onPressed: () => launchUrl(Uri.parse('https://admob.google.com'), mode: LaunchMode.externalApplication), icon: const Icon(Icons.open_in_new), label: const Text('AdMob कमाई देखें')),
                          ]))),
                          const SizedBox(height: 14),
                          const _AdminShopkeeperProCard(),
                          const Padding(padding: EdgeInsets.only(top: 10, bottom: 18), child: Text('पैसा कहाँ जाएगा: विज्ञापन पैकेज का भुगतान और ग्राहक के ऑनलाइन ऑर्डर का भुगतान—दोनों एक ही PAYTM_MID से प्रोसेस होते हैं, इसलिए दोनों का सेटलमेंट उसी Paytm Merchant खाते में जुड़े बैंक खाते में होगा। अलग बैंक खाते चाहिए तो अलग Merchant MID और अलग भुगतान व्यवस्था जरूरी है। AdMob की कमाई Google आपके AdMob Payments में जुड़े बैंक खाते में भेजता है। यह रिपोर्ट ऐप में दर्ज रकम दिखाती है; बैंक में वास्तविक जमा Paytm/AdMob में मिलाएँ। दुकानदार और डिलीवरी भुगतान आपकी कमाई नहीं, देय रकम हैं।', style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.4))),
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _AdminShopkeeperProCard extends StatefulWidget {
  const _AdminShopkeeperProCard();
  @override
  State<_AdminShopkeeperProCard> createState() => _AdminShopkeeperProCardState();
}

class _AdminShopkeeperProCardState extends State<_AdminShopkeeperProCard> {
  final monthly = TextEditingController(text: '299');
  final yearly = TextEditingController(text: '2999');
  bool saving = false;
  bool loaded = false;

  @override
  void dispose() { monthly.dispose(); yearly.dispose(); super.dispose(); }

  Future<void> loadPrices() async {
    if (loaded) return;
    loaded = true;
    try {
      final result = await WorkerApi.post('/api/admin/shopkeeperProSettings', {});
      final plans = result['plans'] as Map?;
      if (!mounted || plans == null) return;
      monthly.text = ((plans['monthly'] as Map?)?['amount'] ?? 299).toString();
      yearly.text = ((plans['yearly'] as Map?)?['amount'] ?? 2999).toString();
      setState(() {});
    } catch (_) { loaded = false; }
  }

  Future<void> savePrices() async {
    final m = double.tryParse(monthly.text.trim());
    final y = double.tryParse(yearly.text.trim());
    if (m == null || y == null || m <= 0 || y < m) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('मासिक और वार्षिक कीमत सही भरें।')));
      return;
    }
    setState(() => saving = true);
    try {
      await WorkerApi.post('/api/admin/saveShopkeeperProPrices', {'monthly': m, 'yearly': y});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pro सदस्यता की कीमतें सेव हो गईं।')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally { if (mounted) setState(() => saving = false); }
  }

  Future<void> grantPro(String shopId, String shopName) async {
    int days = 30;
    final selected = await showDialog<int>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) => AlertDialog(
      title: Text('$shopName को Pro दें'),
      content: DropdownButtonFormField<int>(value: days, decoration: const InputDecoration(labelText: 'सदस्यता अवधि'), items: const [
        DropdownMenuItem(value: 30, child: Text('1 महीना (30 दिन)')),
        DropdownMenuItem(value: 90, child: Text('3 महीने (90 दिन)')),
        DropdownMenuItem(value: 180, child: Text('6 महीने (180 दिन)')),
        DropdownMenuItem(value: 365, child: Text('12 महीने (365 दिन)')),
      ], onChanged: (v) { if (v != null) setLocal(() => days = v); }),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('रद्द करें')), FilledButton(onPressed: () => Navigator.pop(ctx, days), child: const Text('Pro चालू करें'))],
    )));
    if (selected == null) return;
    try {
      await WorkerApi.post('/api/admin/grantShopkeeperPro', {'shopId': shopId, 'durationDays': selected});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$shopName को $selected दिन की Pro सदस्यता दे दी गई।')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> changeStatus(String shopId, String action) async {
    try {
      await WorkerApi.post('/api/admin/setShopkeeperProStatus', {'shopId': shopId, 'action': action});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(action == 'suspend' ? 'Pro सदस्यता रोक दी गई।' : 'Pro सदस्यता बहाल कर दी गई।')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) {
    loadPrices();
    return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [Icon(Icons.workspace_premium, color: Color(0xFFB87500)), SizedBox(width: 8), Expanded(child: Text('दुकानदार Pro नियंत्रण', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)))]),
      const SizedBox(height: 8),
      const Text('सदस्यता की कीमत तय करें, किसी दुकान को मुफ्त Pro दें, अवधि बढ़ाएँ या Pro सुविधा रोकें/बहाल करें।', style: TextStyle(color: Colors.black54, fontSize: 12)),
      const SizedBox(height: 12),
      Row(children: [Expanded(child: TextField(controller: monthly, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'मासिक कीमत (₹)', border: OutlineInputBorder(), isDense: true))), const SizedBox(width: 8), Expanded(child: TextField(controller: yearly, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'वार्षिक कीमत (₹)', border: OutlineInputBorder(), isDense: true)))]),
      const SizedBox(height: 8),
      SizedBox(width: double.infinity, child: FilledButton(onPressed: saving ? null : savePrices, child: Text(saving ? 'सेव हो रहा है…' : 'कीमतें सेव करें'))),
      const Divider(height: 24),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: FirebaseFirestore.instance.collection('shopkeeper_subscriptions').where('paymentStatus', isEqualTo: 'paid').snapshots(), builder: (context, snap) {
        if (snap.hasError) return const Text('Pro भुगतान का हिसाब लोड नहीं हो सका।');
        if (!snap.hasData) return const LinearProgressIndicator();
        double total = 0;
        for (final doc in snap.data!.docs) { total += ((doc.data()['amount'] ?? 0) as num).toDouble(); }
        return ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.workspace_premium, color: Color(0xFFB87500)), title: const Text('Pro सदस्यता से प्राप्त भुगतान', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${snap.data!.docs.length} सफल सदस्यताएँ • Paytm Merchant'), trailing: Text('₹${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF087E58))));
      }),
      const Divider(height: 24),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: FirebaseFirestore.instance.collection('shops').snapshots(), builder: (context, snap) {
        if (snap.hasError) return const Text('Pro दुकानों की सूची लोड नहीं हो सकी।');
        if (!snap.hasData) return const LinearProgressIndicator();
        final proShops = snap.data!.docs;
        final now = DateTime.now();
        bool isProActive(QueryDocumentSnapshot<Map<String, dynamic>> doc) { final d = doc.data(); final raw = d['proUntil']; final until = raw is Timestamp ? raw.toDate() : DateTime.tryParse((raw ?? '').toString()); return d['proStatus'] == 'active' && (until?.isAfter(now) ?? false); }
        final eligibleShops = proShops.where((d) => d.data()['approved'] == true && d.data()['active'] == true).toList();
        final activeCount = eligibleShops.where(isProActive).length;
        final expiredOrPausedCount = eligibleShops.where((d) => (d.data()['proPlan'] ?? '').toString().isNotEmpty && !isProActive(d)).length;
        final neverProCount = eligibleShops.where((d) => (d.data()['proPlan'] ?? '').toString().isEmpty).length;
        if (proShops.isEmpty) return const Text('अभी कोई दुकान दर्ज नहीं है।');
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('दुकानों की Pro सदस्यता स्थिति', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [Chip(label: Text('Pro चालू: $activeCount')), Chip(label: Text('समाप्त / रोकी: $expiredOrPausedCount')), Chip(label: Text('Pro नहीं लिया: $neverProCount'))]),
          ...proShops.map((doc) { final d = doc.data(); final status = (d['proStatus'] ?? 'inactive').toString(); final rawUntil = d['proUntil']; final expiry = rawUntil is Timestamp ? rawUntil.toDate() : DateTime.tryParse((rawUntil ?? '').toString()); final active = isProActive(doc); final hasPlan = (d['proPlan'] ?? '').toString().isNotEmpty; final eligible = d['approved'] == true && d['active'] == true; final remaining = expiry == null ? null : expiry.difference(now).inDays.clamp(0, 99999); final stateLabel = !eligible ? 'दुकान मंजूर / सक्रिय नहीं' : active ? 'Pro चालू' : hasPlan ? (status == 'suspended' ? 'Admin ने रोकी' : 'समाप्त / बंद') : 'Pro नहीं लिया'; return ListTile(contentPadding: EdgeInsets.zero, title: Text((d['name'] ?? 'दुकान').toString()), subtitle: Text('$stateLabel • ${hasPlan ? (d['proPlan'] == 'yearly' ? 'वार्षिक' : d['proPlan'] == 'monthly' ? 'मासिक' : d['proPlan']) : 'कोई सदस्यता नहीं'} • समाप्ति: ${expiry == null ? '—' : '${expiry.day.toString().padLeft(2, '0')}/${expiry.month.toString().padLeft(2, '0')}/${expiry.year}'}${active ? ' • $remaining दिन बाकी' : ''}'), trailing: Wrap(spacing: 2, children: [TextButton(onPressed: eligible ? () => grantPro(doc.id, (d['name'] ?? 'दुकान').toString()) : null, child: Text(hasPlan ? 'Renew / बढ़ाएँ' : 'Pro दें')), if (hasPlan) TextButton(onPressed: eligible ? () => changeStatus(doc.id, active ? 'suspend' : 'restore') : null, child: Text(active ? 'रोकें' : 'बहाल करें'))])); })]);
      }),
    ])));
  }
}

class _IncomeHero extends StatelessWidget {
  final double amount;
  const _IncomeHero({required this.amount});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF17213C), Color(0xFF087E58)]), borderRadius: BorderRadius.circular(22)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('विज्ञापन और ऑर्डर से दर्ज आय', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
      const SizedBox(height: 7),
      Text('₹${amount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
      const SizedBox(height: 4),
      const Text('Pro सदस्यता की कमाई नीचे अलग दिखाई गई है' , style: TextStyle(color: Colors.white70, fontSize: 11)),
    ]),
  );
}

class _IncomeCard extends StatelessWidget {
  final String title;
  final double amount;
  final String subtitle;
  final IconData icon;
  final bool warning;
  const _IncomeCard({required this.title, required this.amount, required this.subtitle, required this.icon, this.warning = false});
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: CircleAvatar(backgroundColor: warning ? const Color(0xFFFFF0D8) : const Color(0xFFE6F5EE), child: Icon(icon, color: warning ? const Color(0xFFB87500) : const Color(0xFF087E58))),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
      trailing: Text('₹${amount.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.w900, color: warning ? const Color(0xFFB87500) : const Color(0xFF087E58))),
    ),
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError();
  @override
  Widget build(BuildContext context) => const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('कमाई का विवरण लोड नहीं हो सका। कृपया इंटरनेट और एडमिन अनुमति जाँचें।', textAlign: TextAlign.center)));
}
