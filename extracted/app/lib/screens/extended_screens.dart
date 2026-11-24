import '../utils/app_labels.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/order_service.dart';
import '../services/cart_service.dart';
import '../services/support_service.dart';
import '../services/inventory_service.dart';
import '../services/report_service.dart';
import '../services/refund_service.dart';
import '../services/admin_service.dart';
import '../services/order_tracking_service.dart';
import '../services/cancellation_service.dart';
import '../services/customer_service.dart';
import '../services/address_service.dart';
import '../services/review_service.dart';
import '../services/supplier_service.dart';
import '../services/expense_service.dart';
import '../services/delivery_service.dart';
import '../services/payment_service.dart';

class CustomerOrdersScreen extends StatelessWidget {
  const CustomerOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('मेरे ऑर्डर')),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: OrderService().customerOrders(),
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.cloud_off_outlined, size: 48, color: Colors.redAccent),
                  const SizedBox(height: 10),
                  const Text('आपके ऑर्डर लोड नहीं हो सके।', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                  const SizedBox(height: 8),
                  SelectableText(AppLabels.serverError(snap.error), textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
                ]),
              ));
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snap.data!.docs.toList()..sort((a, b) {
              final av = a.data()['createdAt'];
              final bv = b.data()['createdAt'];
              final ad = av is Timestamp ? av.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
              final bd = bv is Timestamp ? bv.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
              return bd.compareTo(ad);
            });
            if (docs.isEmpty) {
              return const Center(child: Text('अभी कोई ऑर्डर नहीं है।'));
            }

            return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, i) {
                final d = docs[i];
                final x = d.data();
                final amount = x['customerTotal'] ??
                    x['subtotal'] ??
                    x['totalAmount'] ??
                    0;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: Color(0xFFE8F4EE), child: Icon(Icons.receipt_long, color: Color(0xFF087E58)),),
                    title: Text(
                      'ऑर्डर ${d.id.length > 9 ? d.id.substring(0, 9) : d.id}',
                    ),
                    subtitle: Text(
                      'स्थिति: ${AppLabels.effectiveOrderStatus(x['status'], deliveryBoyId: x['deliveryBoyId'])}\nराशि: ₹$amount  •  भुगतान: ${AppLabels.paymentMethod(x['paymentMethod'])}',
                      maxLines: 3,
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            CustomerOrderDetailScreen(orderId: d.id),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
}

class CustomerOrderDetailScreen extends StatelessWidget {
  final String orderId;

  const CustomerOrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('ऑर्डर की स्थिति')),
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: OrderTrackingService().trackOrder(orderId),
          builder: (context, snap) {
            if (snap.hasError) {
              return const Center(child: Text('ऑर्डर की जानकारी लोड नहीं हो सकी।'));
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snap.data!.exists) {
              return const Center(child: Text('ऑर्डर नहीं मिला।'));
            }

            final x = snap.data!.data()!;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    title: Text('ऑर्डर संख्या: $orderId'),
                    subtitle: Text('स्थिति: ${AppLabels.effectiveOrderStatus(x['status'], deliveryBoyId: x['deliveryBoyId'])}'),
                    trailing: const Icon(Icons.local_shipping),
                  ),
                ),
                Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('ऑर्डर की स्थिति', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 8),
                  ...[
                    ['placed', 'ऑर्डर मिल गया'],
                    ['accepted', 'दुकान ने ऑर्डर स्वीकार किया'],
                    ['preparing', 'सामान तैयार हो रहा है'],
                    ['ready', 'ऑर्डर तैयार है'],
                    ['assigned', 'डिलीवरी पार्टनर नियुक्त'],
                    ['picked_up', 'डिलीवरी पार्टनर ने सामान ले लिया'],
                    ['delivered', 'ऑर्डर सफलतापूर्वक पहुँच गया'],
                  ].map((step) {
                    const order = ['placed','accepted','preparing','ready','assigned','picked_up','delivered'];
                    final rawCurrent = (x['status'] ?? 'placed').toString();
                    final current = rawCurrent == 'ready' && (x['deliveryBoyId'] ?? '').toString().isNotEmpty ? 'assigned' : rawCurrent;
                    final done = order.indexOf(current) >= order.indexOf(step[0]);
                    return ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, color: done ? Colors.green : Colors.black38), title: Text(step[1], style: TextStyle(fontWeight: done ? FontWeight.w700 : FontWeight.normal)));
                  }),
                  if (['cancelled','rejected','payment_failed'].contains(x['status'])) Text('ऑर्डर स्थिति: ${AppLabels.orderStatus(x['status'])}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                ]))),
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: const Text('अनुमानित डिलीवरी समय'),
                  subtitle: Text((x['estimatedDeliveryMinutes'] is num && (x['estimatedDeliveryMinutes'] as num) > 0) ? 'दुकान के अनुसार लगभग ${x['estimatedDeliveryMinutes']} मिनट' : 'दुकान ने अभी डिलीवरी समय अपडेट नहीं किया है'),
                ),
                ListTile(
                  title: const Text('डिलीवरी का पता'),
                  subtitle: Text(x['address'] ?? '-'),
                ),
                ListTile(
                  title: const Text('भुगतान'),
                  subtitle: Text(
                    '${AppLabels.paymentMethod(x['paymentMethod'])} • ${AppLabels.paymentStatus(x['paymentStatus'])}',
                  ),
                ),
                if (x['status'] == 'delivered' && x['items'] is List)
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      try {
                        final cart = CartService();
                        final shopId = (x['shopId'] ?? '').toString();
                        for (final raw in (x['items'] as List)) {
                          if (raw is! Map) continue;
                          final item = Map<String, dynamic>.from(raw);
                          await cart.addItem(
                            productId: (item['productId'] ?? '').toString(),
                            shopId: shopId,
                            name: (item['name'] ?? 'सामान').toString(),
                            price: (item['price'] as num? ?? 0).toDouble(),
                            quantity: (item['quantity'] as num? ?? 1).toInt(),
                            unit: (item['unit'] ?? 'नग').toString(),
                          );
                        }
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('पुराने ऑर्डर का सामान सूची में जोड़ दिया गया है। कीमत और स्टॉक भुगतान से पहले दोबारा जाँचे जाएँगे।')));
                      } catch (e) {
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLabels.serverError(e))));
                      }
                    },
                    icon: const Icon(Icons.replay),
                    label: const Text('फिर से ऑर्डर करें'),
                  ),
                StreamBuilder<GeoPoint?>(
                  stream: OrderTrackingService().deliveryLocation(orderId),
                  builder: (context, location) {
                    final p = location.data;

                    if (p == null) {
                      return const ListTile(
                        leading: Icon(Icons.location_searching),
                        title:
                            Text('डिलीवरी पार्टनर की लोकेशन अभी उपलब्ध नहीं है।'),
                      );
                    }

                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const ListTile(leading: Icon(Icons.my_location), title: Text('डिलीवरी पार्टनर की लाइव लोकेशन')),
                        SizedBox(
                          height: 220,
                          child: FlutterMap(
                            options: MapOptions(
                              initialCenter: LatLng(p.latitude, p.longitude),
                              initialZoom: 16,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.sanchorebazaar.app',
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: LatLng(p.latitude, p.longitude),
                                    width: 44,
                                    height: 44,
                                    child: const Icon(Icons.delivery_dining, color: Colors.red, size: 38),
                                  ),
                                ],
                              ),
                              RichAttributionWidget(
                                attributions: [
                                  TextSourceAttribution(
                                    '© OpenStreetMap contributors',
                                    onTap: () => launchUrl(Uri.parse('https://www.openstreetmap.org/copyright')),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Padding(padding: EdgeInsets.all(10), child: Text('नक्शे पर डिलीवरी पार्टनर का नवीनतम GPS स्थान दिख रहा है।')),
                      ]),
                    );
                  },
                ),
                const Text(
                  'लोकेशन अपडेट डिलीवरी पार्टनर के GPS और इंटरनेट कनेक्शन पर निर्भर करता है।',
                ),
                const SizedBox(height: 16),
                if (['placed', 'accepted'].contains(x['status']))
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      final reason = TextEditingController();

                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('ऑर्डर रद्द करने का अनुरोध'),
                          content: TextField(
                            controller: reason,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'रद्द करने का कारण',
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('वापस'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('भेजें'),
                            ),
                          ],
                        ),
                      );

                      if (ok == true) {
                        try {
                          await CancellationService().requestCancellation(
                            orderId: orderId,
                            reason: reason.text,
                          );

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('ऑर्डर रद्द करने का अनुरोध भेज दिया गया है।'),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(AppLabels.serverError(e))),
                            );
                          }
                        }
                      }
                    },
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('रद्द करने का अनुरोध'),
                  ),
                if (x['status'] == 'delivered')
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final reason = TextEditingController();

                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('रिफंड का अनुरोध'),
                              content: TextField(
                                controller: reason,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  labelText: 'रिफंड का कारण',
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('वापस'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('भेजें'),
                                ),
                              ],
                            ),
                          );

                          if (ok == true) {
                            try {
                              await RefundService().requestRefund(
                                orderId: orderId,
                                reason: reason.text,
                              );

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('रिफंड का अनुरोध भेज दिया गया है।'),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(AppLabels.serverError(e))),
                                );
                              }
                            }
                          }
                        },
                        icon: const Icon(Icons.currency_rupee),
                        label: const Text('रिफंड'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          int rating = 5;
                          final comment = TextEditingController();

                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => StatefulBuilder(
                              builder: (ctx, setDialog) => AlertDialog(
                                title: const Text('दुकान की समीक्षा'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    DropdownButton<int>(
                                      value: rating,
                                      items: [1, 2, 3, 4, 5]
                                          .map(
                                            (v) => DropdownMenuItem(
                                              value: v,
                                              child: Text('$v सितारे'),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (v) {
                                        setDialog(() {
                                          rating = v ?? 5;
                                        });
                                      },
                                    ),
                                    TextField(
                                      controller: comment,
                                      maxLines: 3,
                                      decoration: const InputDecoration(
                                        labelText: 'अपनी राय लिखें',
                                      ),
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('वापस'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('जमा करें'),
                                  ),
                                ],
                              ),
                            ),
                          );

                          if (ok == true) {
                            try {
                              await ReviewService().addReview(
                                shopId: (x['shopId'] ?? '').toString(),
                                orderId: orderId,
                                rating: rating,
                                comment: comment.text,
                              );

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('आपकी समीक्षा जमा हो गई है।'),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(AppLabels.serverError(e))),
                                );
                              }
                            }
                          }
                        },
                        icon: const Icon(Icons.star_outline),
                        label: const Text('समीक्षा'),
                      ),
                    ],
                  ),
              ],
            );
          },
        ),
      );
}

class CustomerSupportScreen extends StatefulWidget {
  const CustomerSupportScreen({super.key});

  @override
  State<CustomerSupportScreen> createState() => _CustomerSupportScreenState();
}

class _CustomerSupportScreenState extends State<CustomerSupportScreen> {
  final subject = TextEditingController();
  final message = TextEditingController();
  bool saving = false;

  Future<void> submit() async {
    if (subject.text.trim().isEmpty || message.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('विषय और संदेश भरें।')),
      );
      return;
    }

    setState(() => saving = true);

    try {
      await SupportService().createTicket(
        subject: subject.text,
        message: message.text,
      );

      subject.clear();
      message.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('सहायता अनुरोध भेज दिया गया है।')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('त्रुटि: ${AppLabels.serverError(e)}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('सहायता और संपर्क')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: subject,
              decoration: const InputDecoration(
                labelText: 'विषय',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: message,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'अपनी समस्या लिखें',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: saving ? null : submit,
              child: Text(saving ? 'Sending...' : 'SEND REQUEST'),
            ),
            const SizedBox(height: 20),
            const Text(
              'Meri Requests',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: SupportService().myTickets(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Text('अनुरोध लोड नहीं हो सके।');
                }
                if (!snap.hasData) {
                  return const LinearProgressIndicator();
                }
                if (snap.data!.docs.isEmpty) {
                  return const Text('अभी कोई अनुरोध नहीं है।');
                }

                return Column(
                  children: snap.data!.docs.map((d) {
                    return ListTile(
                      title: Text(d.data()['subject'] ?? 'सहायता'),
                      subtitle: Text(d.data()['message'] ?? ''),
                      trailing: Chip(
                        label: Text(AppLabels.requestStatus(d.data()['status'])),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      );
}

class ShopkeeperToolsScreen extends StatelessWidget {
  const ShopkeeperToolsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('दुकान प्रबंधन')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('डिलीवरी का अनुमान ग्राहक को ऑर्डर करते समय/ऑर्डर विवरण में बताया जाएगा।', style: TextStyle(fontSize: 13, color: Colors.black54)),
            const Divider(),
            const Text(
              'कम स्टॉक वाला सामान',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
              stream: InventoryService().lowStockProducts(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Text('स्टॉक की जानकारी लोड नहीं हो सकी।');
                }
                if (!snap.hasData) {
                  return const LinearProgressIndicator();
                }
                if (snap.data!.isEmpty) {
                  return const ListTile(
                    title: Text('किसी सामान का स्टॉक कम नहीं है।'),
                  );
                }

                return Column(
                  children: snap.data!.map((d) {
                    final x = d.data();
                    return ListTile(
                      title: Text(x['name'] ?? 'सामान'),
                      subtitle: Text(
                        'उपलब्ध स्टॉक: ${x['stock'] ?? 0}  •  कम स्टॉक सीमा: ${x['lowStockLimit'] ?? 5}',
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const Divider(),
            const Text(
              'बिक्री का सारांश',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            FutureBuilder<Map<String, dynamic>>(
              future: ReportService().shopSummary(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Text('रिपोर्ट लोड नहीं हो सकी।');
                }
                if (!snap.hasData) {
                  return const LinearProgressIndicator();
                }

                final x = snap.data!;

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('कुल ऑर्डर: ${x['orders'] ?? 0}'),
                        Text('पूरे हुए ऑर्डर: ${x['delivered'] ?? 0}'),
                        Text(
                            'पूरी हुई बिक्री: ₹${(x['sales'] ?? 0).toString()}'),
                        Text(
                          'दुकानदार को देय: ₹${(x['netSettlement'] ?? 0).toString()}',
                        ),
                        Text(
                          'भुगतान बाकी: ₹${(x['pendingSettlement'] ?? 0).toString()}',
                        ),
                        Text(
                          'भुगतान हो चुका: ₹${(x['paidSettlement'] ?? 0).toString()}',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const Text(
              'खरीद और स्टॉक में बदलाव के लिए सर्वर का नवीनतम संस्करण चालू होना जरूरी है।',
            ),
          ],
        ),
      );
}

class DeliveryEarningsScreen extends StatelessWidget {
  const DeliveryEarningsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('डिलीवरी कमाई')),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: DeliveryService().myEarnings(),
          builder: (context, snap) {
            if (snap.hasError) {
              return const Center(child: Text('कमाई की जानकारी लोड नहीं हो सकी।'));
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            double total = 0;
            for (final d in snap.data!.docs) {
              final x = d.data();
              total += ((x['amount'] ?? 0) as num).toDouble();
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    title: const Text('पूरे हुए ऑर्डर'),
                    trailing: Text('${snap.data!.docs.length}'),
                  ),
                ),
                Card(
                  child: ListTile(
                    title: const Text('कुल अर्जित कमाई'),
                    trailing: Text('₹${total.toStringAsFixed(2)}'),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Payout status tabhi dikhega jab admin/backend payment record banayega.',
                  ),
                ),
                const Text(
                  'पूरे हुए ऑर्डर का इतिहास',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ...snap.data!.docs.map((d) {
                  final x = d.data();
                  final amount = ((x['amount'] ?? 0) as num).toStringAsFixed(2);

                  return ListTile(
                    title: Text('ऑर्डर ${x['orderId'] ?? d.id}'),
                    subtitle: Text(
                      '${AppLabels.paymentStatus(x['status'])} • ${x['paid'] == true ? 'भुगतान हो चुका है' : 'भुगतान बाकी है'}',
                    ),
                    trailing: Text('₹$amount'),
                  );
                }),
              ],
            );
          },
        ),
      );
}

Future<String?> _askPaymentReference(BuildContext context) async {
  final controller = TextEditingController();

  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('भुगतान संदर्भ संख्या'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(labelText: 'UPI या बैंक संदर्भ संख्या'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('रद्द करें'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(dialogContext, controller.text.trim());
          },
          child: const Text('सहेजें'),
        ),
      ],
    ),
  );

  controller.dispose();
  return result;
}

class AdminServiceAreasList extends StatefulWidget {
  const AdminServiceAreasList({super.key});
  @override
  State<AdminServiceAreasList> createState() => _AdminServiceAreasListState();
}

class _AdminServiceAreasListState extends State<AdminServiceAreasList> {
  late Future<List<Map<String, dynamic>>> future;
  @override
  void initState() { super.initState(); future = AdminService().serviceAreas(); }
  void reload() => setState(() => future = AdminService().serviceAreas());

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: future,
    builder: (context, snap) {
      if (snap.hasError) return Text('डिलीवरी क्षेत्र लोड नहीं हो सके।');
      if (!snap.hasData) return const LinearProgressIndicator();
      return Column(children: snap.data!.map((x) {
        final id = (x['areaId'] ?? '').toString();
        return SwitchListTile(
          title: Text((x['name'] ?? 'डिलीवरी क्षेत्र').toString()),
          subtitle: Text(x['pinCode'] != null ? 'PIN कोड: ${x['pinCode']}' : 'पुराना GPS दूरी क्षेत्र'),
          value: x['active'] == true,
          secondary: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async { try { await AdminService().deleteServiceArea(id); reload(); } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLabels.serverError(e)))); } }),
          onChanged: (v) async { try { await AdminService().updateServiceArea(id, v); reload(); } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLabels.serverError(e)))); } },
        );
      }).toList());
    },
  );
}

class AdminOperationsScreen extends StatelessWidget {
  const AdminOperationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('एडमिन प्रबंधन')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(child: ListTile(leading: const Icon(Icons.manage_accounts), title: const Text('दुकानदार / डिलीवरी पार्टनर और नकद भुगतान नियंत्रण'), subtitle: const Text('अलग-अलग खाते बंद करें और नकद भुगतान चालू/बंद करें'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPeopleControlScreen())))),
          const Text(
            'डैशबोर्ड सारांश',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          FutureBuilder<Map<String, dynamic>>(
            future: ReportService().adminSummary(),
            builder: (context, snap) {
              if (snap.hasError) {
                return const Text(
                  'रिपोर्ट लोड नहीं हो सकी। एडमिन अनुमति जाँचें।',
                );
              }
              if (!snap.hasData) {
                return const LinearProgressIndicator();
              }

              final x = snap.data!;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('कुल ऑर्डर: ${x['orders']}'),
                      Text('कुल दुकानें: ${x['shops']}'),
                      Text('मंज़ूरी की प्रतीक्षा: ${x['pendingApprovals']}'),
                      Text('खुली शिकायतें: ${x['openComplaints']}'),
                    ],
                  ),
                ),
              );
            },
          ),
          const Divider(),
          const Text(
            'रिफंड अनुरोध',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('refundRequests')
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return const Text('रिफंड सूची लोड नहीं हो सकी।');
              }
              if (!snap.hasData) {
                return const LinearProgressIndicator();
              }
              if (snap.data!.docs.isEmpty) {
                return const ListTile(
                  title: Text('अभी कोई रिफंड अनुरोध लंबित नहीं है।'),
                );
              }

              return Column(
                children: snap.data!.docs.map((d) {
                  final x = d.data();

                  return ListTile(
                    title: Text('ऑर्डर: ${x['orderId'] ?? '-'}'),
                    subtitle: Text(x['reason'] ?? ''),
                    trailing: Wrap(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: () async {
                            try {
                              await RefundService().reviewRefund(
                                requestId: d.id,
                                approve: true,
                              );
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(AppLabels.serverError(e))),
                                );
                              }
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () async {
                            try {
                              await RefundService().reviewRefund(
                                requestId: d.id,
                                approve: false,
                              );
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(AppLabels.serverError(e))),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const Divider(),
          const Text(
            'ऑर्डर रद्द करने के अनुरोध',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('cancellationRequests')
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return const Text('रद्दीकरण सूची लोड नहीं हो सकी।');
              }
              if (!snap.hasData) {
                return const LinearProgressIndicator();
              }
              if (snap.data!.docs.isEmpty) {
                return const ListTile(
                  title: Text('अभी कोई रद्दीकरण अनुरोध लंबित नहीं है।'),
                );
              }

              return Column(
                children: snap.data!.docs.map((d) {
                  final x = d.data();

                  return ListTile(
                    title: Text('ऑर्डर: ${x['orderId'] ?? '-'}'),
                    subtitle: Text(x['reason'] ?? ''),
                    trailing: Wrap(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: () async {
                            try {
                              await CancellationService().reviewCancellation(
                                requestId: d.id,
                                approve: true,
                              );

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'ऑर्डर रद्द कर दिया गया और सामान का स्टॉक वापस जोड़ दिया गया।',
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(AppLabels.serverError(e))),
                                );
                              }
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () async {
                            try {
                              await CancellationService().reviewCancellation(
                                requestId: d.id,
                                approve: false,
                              );
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(AppLabels.serverError(e))),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const Divider(),
          const Text(
            'पूरे हुए नकद ऑर्डर – भुगतान की पुष्टि',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .where('status', isEqualTo: 'delivered')
                .where('paymentStatus', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return const Text('नकद भुगतान सूची लोड नहीं हो सकी।');
              }
              if (!snap.hasData) {
                return const LinearProgressIndicator();
              }

              final docs = snap.data!.docs
                  .where((d) => d.data()['paymentMethod'] == 'cod')
                  .toList();

              if (docs.isEmpty) {
                return const ListTile(
                  title: Text('अभी किसी नकद भुगतान की पुष्टि बाकी नहीं है।'),
                );
              }

              return Column(
                children: docs.map((d) {
                  final x = d.data();

                  return ListTile(
                    title: Text('ऑर्डर: ${d.id}'),
                    subtitle: Text(
                      'ग्राहक: ${x['customerId'] ?? '-'} • ₹${x['customerTotal'] ?? x['subtotal'] ?? 0}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.verified_outlined),
                      onPressed: () async {
                        final ref = await _askPaymentReference(context);

                        if (!messenger.mounted || ref == null || ref.isEmpty) {
                          return;
                        }

                        try {
                          await PaymentService().markPaidByAuthorizedStaff(
                            d.id,
                            ref,
                          );
                        } catch (e) {
                          if (messenger.mounted) {
                            messenger.showSnackBar(
                              SnackBar(content: Text(AppLabels.serverError(e))),
                            );
                          }
                        }
                      },
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const Divider(),
          const Text(
            'डिलीवरी पार्टनर का बाकी भुगतान',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('delivery_earnings')
                .where('paid', isEqualTo: false)
                .snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return const Text('डिलीवरी भुगतान सूची लोड नहीं हो सकी।');
              }
              if (!snap.hasData) {
                return const LinearProgressIndicator();
              }
              if (snap.data!.docs.isEmpty) {
                return const ListTile(
                  title: Text('अभी कोई डिलीवरी भुगतान बाकी नहीं है।'),
                );
              }

              return Column(
                children: snap.data!.docs.map((d) {
                  final x = d.data();

                  return ListTile(
                    title: Text('डिलीवरी पार्टनर: ${x['deliveryBoyId'] ?? '-'}'),
                    subtitle: Text(
                      'ऑर्डर: ${x['orderId'] ?? d.id} • ₹${x['amount'] ?? 0}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.payments_outlined),
                      onPressed: () async {
                        final ref = await _askPaymentReference(context);

                        if (!messenger.mounted || ref == null || ref.isEmpty) {
                          return;
                        }

                        try {
                          await AdminService().markDeliveryEarningPaid(
                            recordId: d.id,
                            paymentReference: ref,
                          );
                        } catch (e) {
                          if (messenger.mounted) {
                            messenger.showSnackBar(
                              SnackBar(content: Text(AppLabels.serverError(e))),
                            );
                          }
                        }
                      },
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const Divider(),
          const Text(
            'दुकानदारों का बाकी भुगतान',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('shopkeeper_settlements')
                .where('paid', isEqualTo: false)
                .snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return const Text('दुकानदार भुगतान सूची लोड नहीं हो सकी।');
              }
              if (!snap.hasData) {
                return const LinearProgressIndicator();
              }
              if (snap.data!.docs.isEmpty) {
                return const ListTile(
                  title: Text('अभी कोई दुकानदार भुगतान बाकी नहीं है।'),
                );
              }

              return Column(
                children: snap.data!.docs.map((d) {
                  final x = d.data();

                  return ListTile(
                    title: Text('दुकानदार: ${x['shopkeeperId'] ?? '-'}'),
                    subtitle: Text(
                      'ऑर्डर: ${x['orderId'] ?? d.id} • दुकानदार को देय: ₹${x['netAmount'] ?? 0}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.payments_outlined),
                      onPressed: () async {
                        final ref = await _askPaymentReference(context);

                        if (!messenger.mounted || ref == null || ref.isEmpty) {
                          return;
                        }

                        try {
                          await AdminService().markShopkeeperSettlementPaid(
                            recordId: d.id,
                            paymentReference: ref,
                          );
                        } catch (e) {
                          if (messenger.mounted) {
                            messenger.showSnackBar(
                              SnackBar(content: Text(AppLabels.serverError(e))),
                            );
                          }
                        }
                      },
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const Divider(),
          const Text(
            'रिफंड का बाकी भुगतान',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('refund_obligations')
                .where('status', isEqualTo: 'due')
                .snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return const Text('रिफंड भुगतान सूची लोड नहीं हो सकी।');
              }
              if (!snap.hasData) {
                return const LinearProgressIndicator();
              }
              if (snap.data!.docs.isEmpty) {
                return const ListTile(
                  title: Text('अभी कोई रिफंड भुगतान बाकी नहीं है।'),
                );
              }

              return Column(
                children: snap.data!.docs.map((d) {
                  final x = d.data();

                  return ListTile(
                    title: Text('ग्राहक: ${x['customerId'] ?? '-'}'),
                    subtitle: Text(
                      'ऑर्डर: ${x['orderId'] ?? '-'} • ₹${x['amount'] ?? 0}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.check_circle_outline),
                      onPressed: () async {
                        final ref = await _askPaymentReference(context);

                        if (!messenger.mounted || ref == null || ref.isEmpty) {
                          return;
                        }

                        try {
                          await AdminService().markRefundObligationPaid(
                            recordId: d.id,
                            paymentReference: ref,
                          );
                        } catch (e) {
                          if (messenger.mounted) {
                            messenger.showSnackBar(
                              SnackBar(content: Text(AppLabels.serverError(e))),
                            );
                          }
                        }
                      },
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const Divider(),
          const Text(
            'Open Complaints',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: AdminService().complaints(),
            builder: (context, snap) {
              if (snap.hasError) {
                return const Text('शिकायतें लोड नहीं हो सकीं।');
              }
              if (!snap.hasData) {
                return const LinearProgressIndicator();
              }

              final openDocs = snap.data!.docs
                  .where((d) => (d.data()['status'] ?? 'open') == 'open')
                  .toList();

              if (openDocs.isEmpty) {
                return const ListTile(
                  title: Text('अभी कोई खुली शिकायत नहीं है।'),
                );
              }

              return Column(
                children: openDocs.map((d) {
                  return ListTile(
                    title: Text(d.data()['subject'] ?? 'शिकायत'),
                    subtitle: Text(d.data()['message'] ?? ''),
                    trailing: IconButton(
                      icon: const Icon(Icons.done),
                      onPressed: () async {
                        try {
                          await AdminService().resolveComplaint(d.id);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(AppLabels.serverError(e))),
                            );
                          }
                        }
                      },
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const Text(
            'रिफंड मंज़ूर होने पर भुगतान बाकी की सूची में दर्ज होगा। एडमिन को UPI या बैंक से अलग से राशि भेजनी होगी; ऐप स्वयं बैंक भुगतान नहीं करती।',
          ),
          const Divider(),
          const Text(
            'ग्राहक सहायता अनुरोध',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('support_tickets')
                .where('status', isEqualTo: 'open')
                .snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return const Text('सहायता अनुरोध लोड नहीं हो सके।');
              }
              if (!snap.hasData) {
                return const LinearProgressIndicator();
              }
              if (snap.data!.docs.isEmpty) {
                return const ListTile(
                  title: Text('अभी कोई खुला सहायता अनुरोध नहीं है।'),
                );
              }

              return Column(
                children: snap.data!.docs.map((d) {
                  return ListTile(
                    title: Text(d.data()['subject'] ?? 'सहायता'),
                    subtitle: Text(d.data()['message'] ?? ''),
                    trailing: IconButton(
                      icon: const Icon(Icons.done),
                      onPressed: () async {
                        try {
                          await FirebaseFirestore.instance
                              .collection('support_tickets')
                              .doc(d.id)
                              .update({
                            'status': 'resolved',
                            'resolvedAt': FieldValue.serverTimestamp(),
                          });
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(AppLabels.serverError(e))),
                            );
                          }
                        }
                      },
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminConfigScreen(),
              ),
            ),
            icon: const Icon(Icons.tune),
            label: const Text('प्रचार और डिलीवरी क्षेत्र'),
          ),
        ],
      ),
    );
  }
}

class CustomerAccountScreen extends StatefulWidget {
  const CustomerAccountScreen({super.key});

  @override
  State<CustomerAccountScreen> createState() => _CustomerAccountScreenState();
}

class _CustomerAccountScreenState extends State<CustomerAccountScreen> {
  final name = TextEditingController();
  final phone = TextEditingController();
  final label = TextEditingController(text: 'Home');
  final house = TextEditingController();
  final street = TextEditingController();
  final area = TextEditingController();
  final landmark = TextEditingController();
  final city = TextEditingController();
  final district = TextEditingController();
  final stateName = TextEditingController(text: 'Rajasthan');
  final pinCode = TextEditingController();
  final couponCode = TextEditingController();
  final couponValue = TextEditingController(text: '10');
  final couponMinimum = TextEditingController(text: '199');
  final couponMaximum = TextEditingController(text: '100');
  String couponType = 'percentage';
  bool saving = false;
  double? addressLatitude;
  double? addressLongitude;

  Future<void> useGpsAddress() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) throw Exception('मोबाइल का GPS चालू करें');
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) throw Exception('लोकेशन अनुमति दें');
      final pos = await Geolocator.getCurrentPosition();
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {'format':'jsonv2','lat':'${pos.latitude}','lon':'${pos.longitude}','addressdetails':'1'});
      final response = await http.get(uri, headers: {'User-Agent':'SanchoreBazaar/1.0'}).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) throw Exception('पता नहीं मिल पाया');
      final data = jsonDecode(response.body) as Map<String,dynamic>;
      final a = (data['address'] as Map?)?.cast<String,dynamic>() ?? {};
      house.text = (a['house_number'] ?? '').toString(); street.text = (a['road'] ?? a['pedestrian'] ?? '').toString();
      area.text = (a['suburb'] ?? a['neighbourhood'] ?? a['village'] ?? '').toString();
      city.text = (a['city'] ?? a['town'] ?? a['village'] ?? a['county'] ?? '').toString();
      district.text = (a['state_district'] ?? a['county'] ?? '').toString(); stateName.text = (a['state'] ?? 'Rajasthan').toString();
      pinCode.text = (a['postcode'] ?? '').toString(); addressLatitude = pos.latitude; addressLongitude = pos.longitude;
      if (mounted) { setState(() {}); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pinCode.text.isEmpty ? 'पता मिल गया, PIN Code उपलब्ध नहीं हुआ' : 'GPS से पूरा पता और PIN Code भर गया'))); }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('GPS से पता नहीं मिल सका। ${AppLabels.serverError(e)}'))); }
  }

  Future<void> saveProfile() async {
    setState(() => saving = true);

    try {
      await CustomerService().updateProfile(
        name: name.text,
        phone: phone.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('प्रोफ़ाइल सहेज दी गई है।')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLabels.serverError(e))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  Future<void> addAddress() async {
    try {
      final parts = [house.text, street.text, area.text, city.text, district.text, stateName.text, pinCode.text].where((v) => v.trim().isNotEmpty).toList();
      if (!RegExp(r'^\d{6}$').hasMatch(pinCode.text.trim())) throw Exception('6 अंकों का PIN कोड भरें।');
      await AddressService().addAddress(label: label.text, address: [house.text, street.text, area.text, landmark.text, city.text, district.text, stateName.text, pinCode.text].where((v) => v.trim().isNotEmpty).join(', '), customerName: name.text, phone: phone.text, pinCode: pinCode.text.trim(), house: house.text, street: street.text, area: area.text, landmark: landmark.text, city: city.text, district: district.text, state: stateName.text, latitude: addressLatitude, longitude: addressLongitude);
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) await FirebaseFirestore.instance.collection('users').doc(user.uid).set({'name': name.text.trim(), 'phone': phone.text.trim(), 'defaultAddress': {'house': house.text.trim(), 'street': street.text.trim(), 'area': area.text.trim(), 'landmark': landmark.text.trim(), 'city': city.text.trim(), 'district': district.text.trim(), 'state': stateName.text.trim(), 'pinCode': pinCode.text.trim(), 'latitude': addressLatitude, 'longitude': addressLongitude, 'fullAddress': [house.text, street.text, area.text, landmark.text, city.text, district.text, stateName.text, pinCode.text].where((v) => v.trim().isNotEmpty).join(', ')}, 'profileUpdatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      house.clear(); street.clear(); area.clear(); landmark.clear(); city.clear(); district.clear(); pinCode.clear(); addressLatitude = null; addressLongitude = null;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('पता सहेज दिया गया है।')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('पता सहेजने में समस्या: ${AppLabels.serverError(e)}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('मेरा खाता और पते')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Profile',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: CustomerService().customerProfile(),
              builder: (context, snap) {
                if (snap.hasData && snap.data!.exists) {
                  final d = snap.data!.data()!;

                  if (name.text.isEmpty) {
                    name.text = (d['name'] ?? '').toString();
                  }
                  if (phone.text.isEmpty) {
                    phone.text = (d['phone'] ?? '').toString();
                  }
                  final defaultAddress = d['defaultAddress'];
                  if (defaultAddress is Map && house.text.isEmpty) {
                    house.text = (defaultAddress['house'] ?? '').toString();
                    street.text = (defaultAddress['street'] ?? '').toString();
                    area.text = (defaultAddress['area'] ?? '').toString();
                    landmark.text = (defaultAddress['landmark'] ?? '').toString();
                    city.text = (defaultAddress['city'] ?? '').toString();
                    district.text = (defaultAddress['district'] ?? '').toString();
                    stateName.text = (defaultAddress['state'] ?? 'Rajasthan').toString();
                    pinCode.text = (defaultAddress['pinCode'] ?? '').toString();
                    final lat = defaultAddress['latitude'], lon = defaultAddress['longitude'];
                    if (lat is num && lon is num) { addressLatitude = lat.toDouble(); addressLongitude = lon.toDouble(); }
                  }
                }

                return Column(
                  children: [
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'नाम'),
                    ),
                    TextField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'मोबाइल नंबर'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: saving ? null : saveProfile,
                      child: Text(saving ? 'सहेजा जा रहा है…' : 'प्रोफ़ाइल सहेजें'),
                    ),
                  ],
                );
              },
            ),
            const Divider(height: 30),
            const Text(
              'डिलीवरी का पता जोड़ें',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            FilledButton.tonalIcon(onPressed: useGpsAddress, icon: const Icon(Icons.my_location), label: const Text('GPS से पता और PIN कोड अपने-आप भरें')),
            TextField(controller: label, decoration: const InputDecoration(labelText: 'पते का नाम (घर / ऑफिस)')),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'ग्राहक का नाम')),
            TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'मोबाइल नंबर')),
            TextField(controller: house, decoration: const InputDecoration(labelText: 'मकान / फ्लैट नंबर')),
            TextField(controller: street, decoration: const InputDecoration(labelText: 'गली / सड़क')),
            TextField(controller: area, decoration: const InputDecoration(labelText: 'मोहल्ला / क्षेत्र')),
            TextField(controller: landmark, decoration: const InputDecoration(labelText: 'नज़दीकी पहचान (वैकल्पिक)')),
            TextField(controller: city, decoration: const InputDecoration(labelText: 'गाँव / शहर')),
            TextField(controller: district, decoration: const InputDecoration(labelText: 'जिला')),
            TextField(controller: stateName, decoration: const InputDecoration(labelText: 'राज्य')),
            TextField(controller: pinCode, maxLength: 6, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'PIN कोड')),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: addAddress,
              child: const Text('नया पता जोड़ें'),
            ),
            const Divider(height: 30),
            const Text(
              'Saved Addresses',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: AddressService().watchAddresses(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Text(
                    'पते लोड नहीं हो सके। कृपया Firebase नियम और इंडेक्स जाँचें।',
                  );
                }
                if (!snap.hasData) {
                  return const LinearProgressIndicator();
                }
                if (snap.data!.docs.isEmpty) {
                  return const Text('अभी कोई पता सहेजा नहीं गया है।');
                }

                return Column(
                  children: snap.data!.docs.map((d) {
                    final x = d.data();
                    final gp = x['location'];

                    return ListTile(
                      title: Text(x['label'] ?? 'पता'),
                      subtitle: Text(
                        '${x['address'] ?? ''}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          try {
                            await AddressService().deleteAddress(d.id);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(AppLabels.serverError(e))),
                              );
                            }
                          }
                        },
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      );
}

class ShopkeeperAccountsScreen extends StatefulWidget {
  const ShopkeeperAccountsScreen({super.key});

  @override
  State<ShopkeeperAccountsScreen> createState() =>
      _ShopkeeperAccountsScreenState();
}

class _ShopkeeperAccountsScreenState extends State<ShopkeeperAccountsScreen> {
  final supplierName = TextEditingController();
  final supplierPhone = TextEditingController();
  final supplierAddress = TextEditingController();
  final expenseTitle = TextEditingController();
  final expenseAmount = TextEditingController();
  final expenseCategory = TextEditingController(text: 'General');

  Future<void> addSupplier() async {
    try {
      await SupplierService().addSupplier(
        name: supplierName.text,
        phone: supplierPhone.text,
        address: supplierAddress.text,
      );

      supplierName.clear();
      supplierPhone.clear();
      supplierAddress.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('आपूर्तिकर्ता जोड़ दिया गया है।')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLabels.serverError(e))),
        );
      }
    }
  }

  Future<void> addExpense() async {
    try {
      await ExpenseService().addExpense(
        title: expenseTitle.text,
        amount: double.parse(expenseAmount.text),
        category: expenseCategory.text,
      );

      expenseTitle.clear();
      expenseAmount.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('खर्च का विवरण सहेज दिया गया है।')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLabels.serverError(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('आपूर्तिकर्ता और खर्च')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Add Supplier',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: supplierName,
              decoration: const InputDecoration(labelText: 'आपूर्तिकर्ता का नाम'),
            ),
            TextField(
              controller: supplierPhone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'मोबाइल नंबर'),
            ),
            TextField(
              controller: supplierAddress,
              decoration: const InputDecoration(labelText: 'पता'),
            ),
            FilledButton(
              onPressed: addSupplier,
              child: const Text('आपूर्तिकर्ता सहेजें'),
            ),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: SupplierService().mySuppliers(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Text('आपूर्तिकर्ता सूची लोड नहीं हो सकी।');
                }
                if (!snap.hasData) {
                  return const LinearProgressIndicator();
                }

                return Column(
                  children: snap.data!.docs.map((d) {
                    return ListTile(
                      leading: const Icon(Icons.local_shipping),
                      title: Text(d.data()['name'] ?? 'आपूर्तिकर्ता'),
                      subtitle: Text(
                        '${d.data()['phone'] ?? ''} • ${d.data()['address'] ?? ''}',
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const Divider(height: 30),
            const Text(
              'Record Expense',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: expenseTitle,
              decoration: const InputDecoration(labelText: 'खर्च का नाम'),
            ),
            TextField(
              controller: expenseAmount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'राशि ₹'),
            ),
            TextField(
              controller: expenseCategory,
              decoration: const InputDecoration(labelText: 'श्रेणी'),
            ),
            FilledButton(
              onPressed: addExpense,
              child: const Text('खर्च सहेजें'),
            ),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: ExpenseService().myExpenses(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Text('खर्च का विवरण लोड नहीं हो सका।');
                }
                if (!snap.hasData) {
                  return const LinearProgressIndicator();
                }

                return Column(
                  children: snap.data!.docs.map((d) {
                    return ListTile(
                      title: Text(d.data()['title'] ?? 'खर्च'),
                      subtitle: Text(d.data()['category'] ?? ''),
                      trailing: Text('₹${d.data()['amount'] ?? 0}'),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      );
}

class AdminConfigScreen extends StatefulWidget {
  const AdminConfigScreen({super.key});

  @override
  State<AdminConfigScreen> createState() => _AdminConfigScreenState();
}

class _AdminConfigScreenState extends State<AdminConfigScreen> {
  final title = TextEditingController();
  final description = TextEditingController();
  final discount = TextEditingController(text: '10');
  final areaName = TextEditingController();
  final pinCode = TextEditingController();
  final couponCode = TextEditingController();
  final couponValue = TextEditingController(text: '10');
  final couponMinimum = TextEditingController(text: '199');
  final couponMaximum = TextEditingController(text: '100');
  String couponType = 'percentage';
  bool saving = false;

  Future<void> addPromotion() async {
    setState(() => saving = true);

    try {
      await AdminService().addPromotion(
        title: title.text,
        description: description.text,
        discountPercent: double.parse(discount.text),
      );

      title.clear();
      description.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('प्रचार ऑफर जोड़ दिया गया है।')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLabels.serverError(e))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  Future<void> addCoupon() async {
    setState(() => saving = true);
    try {
      final code = couponCode.text.trim().toUpperCase();
      final value = double.parse(couponValue.text);
      final minimum = double.parse(couponMinimum.text);
      final maximum = double.tryParse(couponMaximum.text);
      if (!RegExp(r'^[A-Z0-9_-]{3,30}$').hasMatch(code) || value <= 0 || minimum < 0 || (couponType == 'percentage' && value > 100)) {
        throw Exception('कूपन कोड, छूट और न्यूनतम ऑर्डर की जानकारी सही भरें।');
      }
      await FirebaseFirestore.instance.collection('coupons').doc(code).set({
        'code': code, 'active': true, 'discountType': couponType,
        'discountValue': value, 'minimumOrder': minimum,
        if (maximum != null && maximum > 0) 'maximumDiscount': maximum,
        'createdAt': FieldValue.serverTimestamp(), 
      });
      couponCode.clear();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('कूपन बना दिया गया है।')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLabels.serverError(e))));
    } finally { if (mounted) setState(() => saving = false); }
  }

  Future<void> addArea() async {
    setState(() => saving = true);

    try {
      await AdminService().addPinCodeArea(name: areaName.text, pinCode: pinCode.text);
      areaName.clear(); pinCode.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('डिलीवरी क्षेत्र जोड़ दिया गया है।')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLabels.serverError(e))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('प्रचार और डिलीवरी क्षेत्र')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('कूपन बनाएं', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextField(controller: couponCode, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'कूपन कोड (जैसे SAVE10)')),
            DropdownButtonFormField<String>(value: couponType, decoration: const InputDecoration(labelText: 'छूट का प्रकार'), items: const [DropdownMenuItem(value: 'percentage', child: Text('प्रतिशत (%)')), DropdownMenuItem(value: 'fixed', child: Text('तय राशि (₹)'))], onChanged: (v) => setState(() => couponType = v ?? 'percentage')),
            TextField(controller: couponValue, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'छूट की राशि')),
            TextField(controller: couponMinimum, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'न्यूनतम ऑर्डर राशि (₹)')),
            TextField(controller: couponMaximum, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'अधिकतम छूट (₹, वैकल्पिक)')),
            FilledButton(onPressed: saving ? null : addCoupon, child: const Text('कूपन सेव करें')),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: FirebaseFirestore.instance.collection('coupons').snapshots(), builder: (context, snap) {
              if (!snap.hasData) return const LinearProgressIndicator();
              if (snap.data!.docs.isEmpty) return const ListTile(title: Text('अभी कोई कूपन नहीं है।'));
              return Column(children: snap.data!.docs.map((d) { final x=d.data(); return SwitchListTile(title: Text(d.id), subtitle: Text('${AppLabels.discountType(x['discountType'])} • ${x['discountValue']} • न्यूनतम ₹${x['minimumOrder'] ?? 0}'), value: x['active'] == true, onChanged: (v) => d.reference.update({'active': v})); }).toList());
            }),
            const Divider(height: 30),
            const Text(
              'प्रचार ऑफर बनाएँ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'प्रचार ऑफर का नाम'),
            ),
            TextField(
              controller: description,
              decoration: const InputDecoration(labelText: 'विवरण'),
            ),
            TextField(
              controller: discount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'छूट (%)'),
            ),
            FilledButton(
              onPressed: saving ? null : addPromotion,
              child: const Text('प्रचार ऑफर बनाएँ'),
            ),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: AdminService().promotions(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Text('प्रचार ऑफर लोड नहीं हो सके।');
                }
                if (!snap.hasData) {
                  return const LinearProgressIndicator();
                }

                return Column(
                  children: snap.data!.docs.map((d) {
                    final x = d.data();

                    return SwitchListTile(
                      title: Text(x['title'] ?? 'प्रचार ऑफर'),
                      subtitle: Text(
                        '${x['discountPercent'] ?? 0}% • ${x['description'] ?? ''}',
                      ),
                      value: x['active'] == true,
                      onChanged: (v) async {
                        try {
                          await AdminService().setPromotionStatus(d.id, v);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(AppLabels.serverError(e))),
                            );
                          }
                        }
                      },
                    );
                  }).toList(),
                );
              },
            ),
            const Divider(height: 32),
            const Text('डिलीवरी PIN Code क्षेत्र', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextField(controller: areaName, decoration: const InputDecoration(labelText: 'एरिया का नाम (जैसे सांचोर)')),
            TextField(controller: pinCode, maxLength: 6, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '6 अंकों का PIN Code')),
            FilledButton(
              onPressed: saving ? null : addArea,
              child: const Text('डिलीवरी क्षेत्र जोड़ें'),
            ),
            const AdminServiceAreasList(),
          ],
        ),
      );
}


class AdminPeopleControlScreen extends StatefulWidget {
  const AdminPeopleControlScreen({super.key});
  @override
  State<AdminPeopleControlScreen> createState() => _AdminPeopleControlScreenState();
}

class _AdminPeopleControlScreenState extends State<AdminPeopleControlScreen> {
  final _admin = AdminService();
  bool _busy = false;
  void _msg(String value) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value))); }
  Future<void> _cod(String type, String id, bool enabled) async {
    setState(() => _busy = true);
    try { await _admin.setCodOverride(targetType: type, targetId: id, enabled: enabled); _msg(enabled ? 'COD चालू कर दिया' : 'COD बंद कर दिया'); }
    catch (e) { _msg('$e'); }
    if (mounted) setState(() => _busy = false);
  }
  Future<void> _disable(String id) async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('खाता बंद करें?'), content: const Text('यह दुकानदार/डिलीवरी बॉय का खाता निष्क्रिय कर देगा।'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('नहीं')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('बंद करें'))]));
    if (ok != true) return;
    setState(() => _busy = true);
    try { await _admin.deactivateStaff(id); _msg('खाता बंद कर दिया गया'); } catch (e) { _msg('$e'); }
    if (mounted) setState(() => _busy = false);
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('लोग और COD नियंत्रण')), body: _busy ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(12), children: [
    const Text('दुकानदार और डिलीवरी बॉय', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream: FirebaseFirestore.instance.collection('users').where('role', whereIn: ['shopkeeper','delivery']).snapshots(), builder: (context, snap) { if (!snap.hasData) return const LinearProgressIndicator(); return Column(children: snap.data!.docs.map((d) { final x=d.data(); final active=x['active'] != false && x['approved'] == true; return Card(child: ListTile(title: Text('${x['name'] ?? 'स्टाफ'}'), subtitle: Text('${AppLabels.userRole(x['role'])} • ${active?'चालू':'बंद'}'), trailing: IconButton(icon: const Icon(Icons.person_off, color: Colors.red), onPressed: active ? () => _disable(d.id) : null))); }).toList()); }),
    const Divider(), const Text('ग्राहक का COD नियंत्रण', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'customer').snapshots(), builder: (context, snap) { if (!snap.hasData) return const LinearProgressIndicator(); return Column(children: snap.data!.docs.map((d) { final x=d.data(); final enabled=x['codEnabled'] != false && x['codDisabled'] != true; return Card(child: SwitchListTile(value: enabled, onChanged: (v) => _cod('customer', d.id, v), title: Text('${x['name'] ?? x['phone'] ?? 'ग्राहक'}'), subtitle: Text('नकद भुगतान वाले ऑर्डर रद्द: ${x['codCancelledCount'] ?? 0} बार'))); }).toList()); }),
    const Divider(), const Text('दुकान का COD नियंत्रण', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream: FirebaseFirestore.instance.collection('shops').snapshots(), builder: (context, snap) { if (!snap.hasData) return const LinearProgressIndicator(); return Column(children: snap.data!.docs.map((d) { final x=d.data(); final enabled=x['codEnabled'] != false && x['codDisabled'] != true; return Card(child: SwitchListTile(value: enabled, onChanged: (v) => _cod('shop', d.id, v), title: Text('${x['name'] ?? 'दुकान'}'), subtitle: Text('दुकान संख्या: ${d.id}'))); }).toList()); }),
  ]));
}

/// Admin overview of participating shops, staff, delivery-ready/completed orders and low stock.
class AdminMarketplaceReportScreen extends StatelessWidget {
  const AdminMarketplaceReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('व्यवसाय और डिलीवरी रिपोर्ट')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _adminReportPeople(db, 'जुड़ी हुई दुकानें', 'shops', null, Icons.storefront),
          _adminReportPeople(db, 'जुड़े हुए दुकानदार', 'users', 'shopkeeper', Icons.store),
          _adminReportPeople(db, 'जुड़े हुए Delivery Boy', 'users', 'delivery', Icons.delivery_dining),
          _adminReportOrders(db, 'डिलीवरी के लिए तैयार ऑर्डर', const {'ready'}, true),
          _adminReportOrders(db, 'पूरे हुए ऑर्डर', const {'delivered'}, false),
          _adminReportLowStock(db),
        ],
      ),
    );
  }
}

Widget _adminReportPeople(FirebaseFirestore db, String title, String collection, String? role, IconData icon) {
  Query<Map<String, dynamic>> query = db.collection(collection);
  if (role != null) query = query.where('role', isEqualTo: role);
  return Card(
    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return ListTile(leading: Icon(icon), title: Text(title), subtitle: const Text('जानकारी लोड नहीं हो सकी।'));
        if (!snap.hasData) return const ListTile(title: LinearProgressIndicator());
        final docs = snap.data!.docs;
        return ExpansionTile(
          leading: Icon(icon), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('कुल ${docs.length}'),
          children: docs.isEmpty ? const [ListTile(title: Text('अभी कोई रिकॉर्ड नहीं है।'))] : docs.map((d) {
            final x = d.data();
            final isActive = x['active'] != false && (role == null || x['approved'] == true);
            final targetUserId = collection == 'shops' ? (x['ownerId'] ?? '').toString() : d.id;
            return ListTile(
              dense: true,
              title: Text((x['name'] ?? x['shopName'] ?? 'नाम उपलब्ध नहीं').toString()),
              subtitle: Text('मोबाइल: ${x['phone'] ?? '-'}  •  ${x['email'] ?? ''}'),
              trailing: targetUserId.isEmpty ? const Text('—') : TextButton(
                onPressed: () async {
                  final action = isActive ? 'बंद' : 'फिर से चालू';
                  final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                    title: Text('खाता $action करें?'),
                    content: Text('${(x['name'] ?? 'यह खाता').toString()} को ${isActive ? 'बंद' : 'दोबारा सक्रिय'} किया जाएगा। पुराने ऑर्डर और हिसाब सुरक्षित रहेंगे।'),
                    actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('रद्द करें')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action))],
                  ));
                  if (ok != true) return;
                  try {
                    if (isActive) { await AdminService().deactivateStaff(targetUserId); }
                    else { await AdminService().reactivateStaff(targetUserId); }
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('खाता $action कर दिया गया।')));
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLabels.serverError(e))));
                  }
                },
                child: Text(isActive ? 'बंद करें' : 'चालू करें', style: TextStyle(color: isActive ? Colors.red : Colors.green)),
              ),
            );
          }).toList(),
        );
      },
    ),
  );
}

Widget _adminReportOrders(FirebaseFirestore db, String title, Set<String> statuses, bool assignReady) {
  return Card(
    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db.collection('orders').snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return ListTile(title: Text(title), subtitle: const Text('ऑर्डर लोड नहीं हो सके।'));
        if (!snap.hasData) return const ListTile(title: LinearProgressIndicator());
        final docs = snap.data!.docs.where((d) => statuses.contains((d.data()['status'] ?? '').toString().toLowerCase())).toList();
        docs.sort((a, b) {
          final av = a.data()['createdAt']; final bv = b.data()['createdAt'];
          final ad = av is Timestamp ? av.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
          final bd = bv is Timestamp ? bv.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
          return bd.compareTo(ad);
        });
        return ExpansionTile(
          leading: Icon(assignReady ? Icons.local_shipping : Icons.task_alt),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('कुल ${docs.length}'),
          children: docs.isEmpty ? const [ListTile(title: Text('अभी कोई ऑर्डर नहीं है।'))] : docs.map((d) {
            final x = d.data();
            return ListTile(
              title: Text('ऑर्डर ${d.id.substring(0, d.id.length > 9 ? 9 : d.id.length)}'),
              subtitle: Text('दुकान: ${x['shopName'] ?? x['shopId'] ?? '-'}  •  ₹${x['customerTotal'] ?? x['subtotal'] ?? 0}\nग्राहक: ${x['customerName'] ?? x['customerId'] ?? '-'}  •  डिलीवरी: ${x['deliveryBoyId'] ?? (assignReady ? 'अभी नियुक्त नहीं' : '-') }'),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminOrderInspectScreen(orderId: d.id))),
            );
          }).toList(),
        );
      },
    ),
  );
}

Widget _adminReportLowStock(FirebaseFirestore db) {
  return Card(
    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db.collection('products').snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return const ListTile(title: Text('कम स्टॉक रिपोर्ट'), subtitle: Text('स्टॉक लोड नहीं हो सका।'));
        if (!snap.hasData) return const ListTile(title: LinearProgressIndicator());
        final docs = snap.data!.docs.where((d) {
          final x = d.data(); if (x['active'] == false) return false;
          final stock = (x['stock'] as num?)?.toInt() ?? 0;
          final limit = (x['lowStockLimit'] as num?)?.toInt() ?? 5;
          return stock <= limit;
        }).toList();
        return ExpansionTile(
          leading: const Icon(Icons.inventory_2_outlined, color: Colors.deepOrange),
          title: const Text('कम स्टॉक वाले सामान', style: TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('कुल ${docs.length} प्रोडक्ट'),
          children: docs.isEmpty ? const [ListTile(title: Text('अभी कोई कम स्टॉक वाला सामान नहीं है।'))] : docs.map((d) {
            final x = d.data();
            final shopId = (x['shopId'] ?? '').toString();
            return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: shopId.isEmpty ? null : db.collection('shops').doc(shopId).get(),
              builder: (context, shopSnap) {
                final shopName = shopSnap.data?.data()?['name'] ?? shopId;
                return ListTile(
                  title: Text((x['name'] ?? 'सामान').toString()),
                  subtitle: Text('दुकान: ${shopName.isEmpty ? 'नाम उपलब्ध नहीं' : shopName}  •  बचा स्टॉक: ${x['stock'] ?? 0} ${x['unit'] ?? ''}'),
                  trailing: const Icon(Icons.warning_amber_rounded, color: Colors.deepOrange),
                );
              },
            );
          }).toList(),
        );
      },
    ),
  );
}

class AdminOrderInspectScreen extends StatelessWidget {
  final String orderId;
  const AdminOrderInspectScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('ऑर्डर की पूरी जानकारी')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: db.collection('orders').doc(orderId).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return const Center(child: Text('ऑर्डर की जानकारी नहीं मिली।'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          if (!snap.data!.exists) return const Center(child: Text('ऑर्डर उपलब्ध नहीं है।'));
          final x = snap.data!.data()!;
          final items = x['items'] is List ? (x['items'] as List) : const [];
          final shopId = (x['shopId'] ?? '').toString();
          final deliveryId = (x['deliveryBoyId'] ?? '').toString();
          return ListView(padding: const EdgeInsets.all(16), children: [
            Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ऑर्डर ID: $orderId', style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('स्थिति: ${x['status'] ?? '-'}'),
              Text('ग्राहक: ${x['customerName'] ?? x['customerId'] ?? '-'}'),
              Text('मोबाइल: ${x['customerPhone'] ?? '-'}'),
              FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: shopId.isEmpty ? null : db.collection('shops').doc(shopId).get(),
                builder: (context, shopSnap) => Text('दुकान: ${shopSnap.data?.data()?['name'] ?? shopId}'),
              ),
              FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: deliveryId.isEmpty ? null : db.collection('users').doc(deliveryId).get(),
                builder: (context, deliverySnap) => Text('Delivery Boy: ${deliveryId.isEmpty ? 'अभी नियुक्त नहीं' : (deliverySnap.data?.data()?['name'] ?? deliveryId)}'),
              ),
              Text('भुगतान: ${x['paymentMethod'] ?? '-'} / ${x['paymentStatus'] ?? '-'}'),
              Text('कुल राशि: ₹${x['customerTotal'] ?? x['subtotal'] ?? 0}'),
              if (x['address'] != null) Text('पता: ${x['address']}'),
            ]))),
            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('ऑर्डर के सामान', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
            if (items.isEmpty) const Card(child: ListTile(title: Text('इस ऑर्डर में सामान की सूची उपलब्ध नहीं है।'))),
            ...items.whereType<Map>().map((raw) {
              final item = Map<String, dynamic>.from(raw);
              return Card(child: ListTile(
                title: Text((item['name'] ?? item['productName'] ?? 'सामान').toString()),
                subtitle: Text('मात्रा: ${item['quantity'] ?? '-'} ${item['unit'] ?? ''}  •  कीमत: ₹${item['price'] ?? '-'}'),
                trailing: Text('₹${item['total'] ?? ((item['price'] is num && item['quantity'] is num) ? (item['price'] as num) * (item['quantity'] as num) : '-')}'),
              ));
            }),
          ]);
        },
      ),
    );
  }
}
