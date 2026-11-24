import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Customer reward wallet. Balance is written only by the authenticated Worker.
class CustomerWalletScreen extends StatelessWidget {
  const CustomerWalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('पहले लॉगिन करें।')));
    }
    final db = FirebaseFirestore.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('मेरा रिवॉर्ड वॉलेट')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: db.collection('users').doc(user.uid).snapshots(),
            builder: (context, snapshot) {
              final points = (snapshot.data?.data()?['pointsBalance'] as num?)?.toInt() ?? 0;
              final rupees = points / 100;
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF172B4D), Color(0xFF087F8C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 28),
                      SizedBox(width: 9),
                      Text('सांचौर बाज़ार वॉलेट', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1)),
                    ]),
                    const SizedBox(height: 18),
                    Text('$points पॉइंट', style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text('₹${rupees.toStringAsFixed(2)} की कुल छूट का मूल्य', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    const Text('100 पॉइंट = ₹1 • पूरा विज्ञापन वीडियो देखने पर 1 पॉइंट • प्रति ऑर्डर अधिकतम 25% छूट', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          const Text('पॉइंट हिस्ट्री', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: db.collection('reward_transactions').where('userId', isEqualTo: user.uid).limit(100).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Card(child: Padding(padding: EdgeInsets.all(14), child: Text('हिस्ट्री अभी लोड नहीं हो पाई।')));
              if (!snapshot.hasData) return const Center(child: Padding(padding: EdgeInsets.all(18), child: CircularProgressIndicator()));
              final entries = snapshot.data!.docs.toList()
                ..sort((a, b) {
                  final av = a.data()['createdAt'];
                  final bv = b.data()['createdAt'];
                  final at = av is Timestamp ? av.millisecondsSinceEpoch : 0;
                  final bt = bv is Timestamp ? bv.millisecondsSinceEpoch : 0;
                  return bt.compareTo(at);
                });
              if (entries.isEmpty) return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('अभी कोई पॉइंट नहीं मिले हैं। वीडियो विज्ञापन पूरा देखने पर पॉइंट जुड़ेंगे।')));
              return Column(children: entries.map((doc) {
                final item = doc.data();
                final date = item['createdAt'];
                final dateText = date is Timestamp ? '${date.toDate().day.toString().padLeft(2, '0')}/${date.toDate().month.toString().padLeft(2, '0')}/${date.toDate().year}' : 'अभी';
                final redeemed = item['source'] == 'checkout_redemption';
                final pointsChange = (item['points'] as num?)?.toInt() ?? 0;
                return Card(child: ListTile(
                  leading: CircleAvatar(backgroundColor: redeemed ? const Color(0xFFFFF4E5) : const Color(0xFFEAF6EF), child: Icon(redeemed ? Icons.shopping_bag_outlined : Icons.play_circle_fill, color: redeemed ? const Color(0xFFB56A00) : const Color(0xFF087E58))),
                  title: Text(redeemed ? 'ऑर्डर पर पॉइंट इस्तेमाल' : 'विज्ञापन वीडियो का इनाम', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(redeemed ? '$dateText • ऑर्डर में छूट' : dateText),
                  trailing: Text('${pointsChange > 0 ? '+' : ''}$pointsChange पॉइंट', style: TextStyle(color: redeemed ? const Color(0xFFB56A00) : const Color(0xFF087E58), fontWeight: FontWeight.w900)),
                ));
              }).toList());
            },
          ),
        ],
      ),
    );
  }
}
