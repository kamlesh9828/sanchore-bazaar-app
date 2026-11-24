import '../utils/app_labels.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import '../services/image_service.dart';
import '../services/ad_management_service.dart';
import '../services/payment_service.dart';
import 'paytm_checkout_screen.dart';

// ======================================================
// CUSTOMER ACTIVE AD BANNERS
// ======================================================

class ActiveAdBanners extends StatefulWidget {
  final void Function(String shopId, String shopName) onOpenShop;

  const ActiveAdBanners({
    super.key,
    required this.onOpenShop,
  });

  @override
  State<ActiveAdBanners> createState() => _ActiveAdBannersState();
}

class _ActiveAdBannersState extends State<ActiveAdBanners> {
  final AdManagementService _service = AdManagementService();

  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.activeAds();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 5);
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return _brandFallback();
        }

        final ads = snapshot.data!;

        return SizedBox(
          height: 155,
          child: ListView.separated(
            padding: const EdgeInsets.all(10),
            scrollDirection: Axis.horizontal,
            itemCount: ads.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final ad = ads[index];

              final id = (ad['campaignId'] ?? ad['id'] ?? '').toString();
              final shopId = (ad['shopId'] ?? '').toString();
              final shopName = (ad['shopName'] ?? 'दुकान').toString();
              final imageUrl = (ad['imageUrl'] ?? '').toString();

              return SizedBox(
                width: 285,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
                    if (id.isNotEmpty) {
                      try {
                        await _service.trackEvent(id, 'click');
                      } catch (_) {}
                    }

                    final destination = (ad['destinationUrl'] ?? '').toString();
                    if (shopId.isEmpty && destination.startsWith('https://')) {
                      await launchUrl(Uri.parse(destination), mode: LaunchMode.externalApplication);
                    } else if (shopId.isNotEmpty) {
                      widget.onOpenShop(shopId, shopName);
                    }
                  },
                  child: Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (imageUrl.startsWith('https://'))
                          Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _fallback(shopName),
                          )
                        else
                          _fallback(shopName),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(9),
                            color: Colors.black54,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (ad['title'] ?? shopName).toString(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                                if ((ad['description'] ?? '').toString().trim().isNotEmpty)
                                  Text(ad['description'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 7,
                          right: 7,
                          child: DecoratedBox(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.all(Radius.circular(5)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                              child: Text(
                                ad['placement'] == 'shop_featured' ? 'प्रायोजित दुकान' :
                                ad['placement'] == 'product_featured' ? 'प्रायोजित सामान' :
                                ad['placement'] == 'local_business' ? 'स्थानीय विज्ञापन' : 'विज्ञापन',
                                style: const TextStyle(color: Colors.white, fontSize: 10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _brandFallback() {
    return Container(
      height: 155,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF075E46), Color(0xFF19A875)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          const CircleAvatar(radius: 30, backgroundColor: Colors.white, child: Icon(Icons.storefront, size: 34, color: Color(0xFF087E58))),
          const SizedBox(width: 14),
          const Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('SANCHORE BAZAAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
            SizedBox(height: 6),
            Text('अपने व्यापार को नई पहचान दें!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            SizedBox(height: 3),
            Text('सांचौर बाज़ार पर अपना विज्ञापन लगवाएँ', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ])),
          const Icon(Icons.campaign, color: Colors.white, size: 28),
        ]),
      ),
    );
  }

  Widget _fallback(String name) {
    return Container(
      color: Colors.green.shade100,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.storefront,
            size: 42,
            color: Colors.green,
          ),
          const SizedBox(height: 5),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ======================================================
// ADMIN ADVERTISEMENT MANAGEMENT
// ======================================================

class AdAdminScreen extends StatefulWidget {
  const AdAdminScreen({super.key});

  @override
  State<AdAdminScreen> createState() => _AdAdminScreenState();
}

class _AdAdminScreenState extends State<AdAdminScreen> {
  final AdManagementService _service = AdManagementService();

  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _ads = [];
  List<Map<String, dynamic>> _requests = [];

  Map<String, dynamic> _settings = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final campaigns = await _service.adminCampaigns();
      final requests = await _service.adminAdRequests();
      final settingsResponse = await _service.settings();

      if (!mounted) return;

      _ads = campaigns;
      _requests = requests;

      _settings = Map<String, dynamic>.from(
        settingsResponse['settings'] is Map
            ? settingsResponse['settings']
            : settingsResponse,
      );
    } catch (e) {
      _error = e.toString();
    }

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  double _number(String value) {
    return double.tryParse(value.trim()) ?? 0;
  }

  // ------------------------------------------------------
  // AD PACKAGE SETTINGS
  // ------------------------------------------------------

  Future<void> _settingsDialog() async {
    final prices = Map<String, dynamic>.from(
      (_settings['packagePrices'] as Map?) ?? {},
    );

    final p7 = TextEditingController(
      text: '${prices['7'] ?? ''}',
    );

    final p15 = TextEditingController(
      text: '${prices['15'] ?? ''}',
    );

    final p30 = TextEditingController(
      text: '${prices['30'] ?? ''}',
    );

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('विज्ञापन पैकेज सेटिंग'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _priceField(p7, '7 दिन का शुल्क'),
                _priceField(p15, '15 दिन का शुल्क'),
                _priceField(p30, '30 दिन का शुल्क'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('रद्द करें'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('सहेजें'),
          ),
        ],
      ),
    );

    if (result != true) return;

    try {
      await _service.saveSettings(
        prices: {
          '7': _number(p7.text),
          '15': _number(p15.text),
          '30': _number(p30.text),
        },
      );

      _message('विज्ञापन सेटिंग सहेज दी गई।');
      await _load();
    } catch (e) {
      _message('सेटिंग सेव नहीं हुई: $e');
    }
  }

  Widget _priceField(
    TextEditingController controller,
    String label,
  ) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      validator: (v) {
        if (_number(v ?? '') <= 0) {
          return 'राशि शून्य से अधिक रखें';
        }
        return null;
      },
    );
  }

  // ------------------------------------------------------
  // CREATE AD CAMPAIGN
  // ------------------------------------------------------

  Future<void> _createDialog() async {
    try {
      final shops = await _service.approvedShops().first;

      if (!mounted) return;

      if (shops.isEmpty) {
        _message('कोई स्वीकृत दुकान उपलब्ध नहीं है।');
        return;
      }

      final title = TextEditingController();
      final description = TextEditingController();
      final picker = ImagePicker();
      XFile? selectedImage;

      String shopId =
          (shops.first['id'] ?? shops.first['shopId'] ?? '').toString();

      String placement = 'banner';
      int days = 7;

      final formKey = GlobalKey<FormState>();

      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialog) => AlertDialog(
            title: const Text('नया विज्ञापन बनाएँ'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: shopId.isEmpty ? null : shopId,
                      decoration: const InputDecoration(
                        labelText: 'दुकान चुनें',
                      ),
                      items: shops.map((shop) {
                        final id =
                            (shop['id'] ?? shop['shopId'] ?? '').toString();

                        return DropdownMenuItem<String>(
                          value: id,
                          child: Text(
                            (shop['name'] ?? 'दुकान').toString(),
                          ),
                        );
                      }).where((item) {
                        return item.value != null && item.value!.isNotEmpty;
                      }).toList(),
                      onChanged: (value) {
                        setDialog(() {
                          shopId = value ?? '';
                        });
                      },
                    ),
                    TextFormField(
                      controller: title,
                      decoration: const InputDecoration(
                        labelText: 'विज्ञापन शीर्षक',
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'शीर्षक लिखें' : null,
                    ),
                    TextFormField(
                      controller: description,
                      decoration: const InputDecoration(
                        labelText: 'विवरण',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90, maxWidth: 1800);
                        if (file != null) setDialog(() => selectedImage = file);
                      },
                      icon: const Icon(Icons.photo_library),
                      label: Text(selectedImage == null ? 'गैलरी से विज्ञापन फोटो चुनें' : 'फोटो चुनी गई: ${selectedImage!.name}'),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: placement,
                      decoration: const InputDecoration(
                        labelText: 'विज्ञापन की जगह',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'banner',
                          child: Text('होम बैनर'),
                        ),
                      ],
                      onChanged: (v) {
                        setDialog(() {
                          placement = v ?? 'banner';
                        });
                      },
                    ),
                    DropdownButtonFormField<int>(
                      initialValue: days,
                      decoration: const InputDecoration(
                        labelText: 'पैकेज अवधि',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 7,
                          child: Text('7 दिन'),
                        ),
                        DropdownMenuItem(
                          value: 15,
                          child: Text('15 दिन'),
                        ),
                        DropdownMenuItem(
                          value: 30,
                          child: Text('30 दिन'),
                        ),
                      ],
                      onChanged: (v) {
                        setDialog(() {
                          days = v ?? 7;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('रद्द करें'),
              ),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState!.validate() && shopId.isNotEmpty && selectedImage != null) {
                    Navigator.pop(ctx, {
                      'shopId': shopId,
                      'title': title.text.trim(),
                      'description': description.text.trim(),
                      'selectedImage': selectedImage,
                      'placement': placement,
                      'days': days,
                    });
                  }
                },
                child: const Text('कैंपेन बनाएँ'),
              ),
            ],
          ),
        ),
      );

      if (result == null) return;

      final chosenFile = result['selectedImage'] as XFile;
      final uploadedImageUrl = await ImageService().uploadAdImage(file: chosenFile, adId: DateTime.now().microsecondsSinceEpoch.toString());
      await _service.createAd(
        shopId: result['shopId'],
        title: result['title'],
        description: result['description'],
        imageUrl: uploadedImageUrl,
        placement: result['placement'],
        days: result['days'],
      );

      _message('विज्ञापन कैंपेन बन गई।');
      await _load();
    } catch (e) {
      _message('विज्ञापन नहीं बना: $e');
    }
  }

  Future<void> _rejectRequest(Map<String, dynamic> request) async {
    final requestId = (request['requestId'] ?? request['id'] ?? '').toString();
    final reason = TextEditingController(text: 'अभी विज्ञापन रिक्वेस्ट स्वीकार नहीं की जा सकती।');
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('रिक्वेस्ट अस्वीकार करें'),
      content: TextField(controller: reason, maxLines: 3, decoration: const InputDecoration(labelText: 'कारण')),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('रद्द करें')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('अस्वीकार करें'))],
    ));
    if (ok != true || requestId.isEmpty) return;
    try { await _service.rejectAdRequest(requestId: requestId, reason: reason.text); _message('रिक्वेस्ट अस्वीकार कर दी गई।'); await _load(); }
    catch (e) { _message('रिक्वेस्ट अस्वीकार नहीं हुई: $e'); }
  }

  Future<void> _editDraftAd(Map<String, dynamic> ad) async {
    final id = (ad['campaignId'] ?? ad['id'] ?? '').toString();
    if (id.isEmpty) return;
    final title = TextEditingController(text: (ad['title'] ?? '').toString());
    final description = TextEditingController(text: (ad['description'] ?? '').toString());
    final destination = TextEditingController(text: (ad['destinationUrl'] ?? '').toString());
    final picker = ImagePicker();
    XFile? image;
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) => AlertDialog(
      title: const Text('विज्ञापन में सुधार करें'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: title, decoration: const InputDecoration(labelText: 'शीर्षक')),
        TextField(controller: description, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: 'विवरण')),
        TextField(controller: destination, decoration: const InputDecoration(labelText: 'HTTPS लिंक (वैकल्पिक)')),
        OutlinedButton.icon(onPressed: () async { final f = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90, maxWidth: 1800); if (f != null) setLocal(() => image = f); }, icon: const Icon(Icons.photo), label: Text(image == null ? 'नई फोटो चुनें (वैकल्पिक)' : 'फोटो चुनी गई')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('रद्द करें')), FilledButton(onPressed: () => Navigator.pop(ctx, title.text.trim().isNotEmpty), child: const Text('बदलाव सहेजें'))],
    )));
    if (ok != true) return;
    try {
      final fields = <String, dynamic>{'title': title.text.trim(), 'description': description.text.trim(), 'destinationUrl': destination.text.trim()};
      if (image != null) fields['imageUrl'] = await ImageService().uploadAdImage(file: image!, adId: id);
      await _service.updateAd(campaignId: id, fields: fields);
      _message('विज्ञापन में बदलाव सहेज दिए।');
      await _load();
    } catch (e) { _message('बदलाव सेव नहीं हुए: $e'); }
  }

  Future<void> _createFromRequest(Map<String, dynamic> request) async {
    final requestId = (request['requestId'] ?? request['id'] ?? '').toString();
    final businessName = (request['businessName'] ?? '').toString();
    final brief = (request['brief'] ?? '').toString();
    final title = TextEditingController(text: businessName);
    final description = TextEditingController(text: brief);
    final destination = TextEditingController();
    final picker = ImagePicker();
    XFile? selectedImage;
    String generatedImageUrl = '';
    bool aiBusy = false;
    String placement = 'banner';
    int days = 7;
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: const Text('एडमिन विज्ञापन स्टूडियो'),
        content: SingleChildScrollView(child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('व्यवसाय: $businessName', style: const TextStyle(fontWeight: FontWeight.bold)),
          if ((request['referenceImageUrl'] ?? '').toString().startsWith('https://')) Column(children: [const SizedBox(height: 8), const Text('दुकानदार/ग्राहक की भेजी फोटो'), Image.network(request['referenceImageUrl'].toString(), height: 100, width: double.infinity, cacheHeight: 200, fit: BoxFit.contain), TextButton(onPressed: () => setLocal(() { generatedImageUrl = request['referenceImageUrl'].toString(); selectedImage = null; }), child: const Text('इसी फोटो को विज्ञापन में लगाएँ'))]),
          TextFormField(controller: title, decoration: const InputDecoration(labelText: 'विज्ञापन शीर्षक'), validator: (v) => v == null || v.trim().isEmpty ? 'शीर्षक लिखें' : null),
          TextFormField(controller: description, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: 'विज्ञापन की लिखावट')),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: aiBusy ? null : () async {
              setLocal(() => aiBusy = true);
              try {
                final creative = await _service.generateAiAdCreative(businessName: businessName, brief: brief);
                final base64 = (creative['imageBase64'] ?? '').toString();
                if (base64.isEmpty) throw Exception('AI फोटो नहीं मिली।');
                final bytes = base64Decode(base64);
                final uploaded = await ImageService().uploadAdImageBytes(bytes: bytes, adId: requestId.isEmpty ? DateTime.now().microsecondsSinceEpoch.toString() : requestId);
                if (!mounted) return;
                setLocal(() {
                  title.text = (creative['title'] ?? businessName).toString();
                  description.text = (creative['description'] ?? brief).toString();
                  generatedImageUrl = uploaded;
                  selectedImage = null;
                });
                _message('AI ने विज्ञापन की लिखावट और फोटो तैयार कर दी।');
              } catch (e) {
                if (mounted) _message('AI विज्ञापन नहीं बन पाया: $e');
              } finally {
                if (mounted) setLocal(() => aiBusy = false);
              }
            },
            icon: aiBusy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome),
            label: Text(aiBusy ? 'AI विज्ञापन बना रहा है…' : 'AI से विज्ञापन और फोटो बनाएँ'),
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(onPressed: aiBusy ? null : () async { final f = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90, maxWidth: 1800); if (f != null) setLocal(() { selectedImage = f; generatedImageUrl = ''; }); }, icon: const Icon(Icons.photo_library), label: Text(generatedImageUrl.isNotEmpty ? 'AI फोटो तैयार है — दूसरी चुनें' : selectedImage == null ? 'गैलरी से फोटो चुनें' : 'फोटो चुनी गई: ${selectedImage!.name}')),
          if (generatedImageUrl.isNotEmpty) Column(children: [const Text('AI से तैयार फोटो अपलोड हो गई है।', style: TextStyle(color: Colors.green)), const SizedBox(height: 6), ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(generatedImageUrl, height: 110, width: double.infinity, cacheHeight: 220, fit: BoxFit.cover))]),
          TextFormField(controller: destination, decoration: const InputDecoration(labelText: 'खोलने का लिंक (वैकल्पिक, https://)')),
          DropdownButtonFormField<String>(value: placement, decoration: const InputDecoration(labelText: 'कहाँ दिखाएँ'), items: const [DropdownMenuItem(value: 'banner', child: Text('होम बैनर')), DropdownMenuItem(value: 'shop_featured', child: Text('प्रायोजित दुकान')), DropdownMenuItem(value: 'product_featured', child: Text('प्रायोजित सामान')), DropdownMenuItem(value: 'local_business', child: Text('स्थानीय व्यवसाय विज्ञापन'))], onChanged: (v) => setLocal(() => placement = v ?? 'banner')),
          DropdownButtonFormField<int>(value: days, decoration: const InputDecoration(labelText: 'अवधि'), items: const [DropdownMenuItem(value: 7, child: Text('7 दिन')), DropdownMenuItem(value: 15, child: Text('15 दिन')), DropdownMenuItem(value: 30, child: Text('30 दिन'))], onChanged: (v) => setLocal(() => days = v ?? 7)),
          const SizedBox(height: 6), const Text('प्रायोजित दुकान, सामान और स्थानीय व्यवसाय के विज्ञापन भी होम विज्ञापन सूची में स्पष्ट विज्ञापन टैग के साथ दिखेंगे। कीमत एडमिन तय करेगा।', style: TextStyle(fontSize: 12)),
        ]))),
        actions: [TextButton(onPressed: aiBusy ? null : () => Navigator.pop(ctx, false), child: const Text('रद्द करें')), FilledButton(onPressed: aiBusy ? null : () { if (formKey.currentState!.validate() && (generatedImageUrl.isNotEmpty || selectedImage != null)) Navigator.pop(ctx, true); }, child: const Text('ड्राफ्ट बनाएँ'))],
      ),
    ));
    if (result != true || requestId.isEmpty) return;
    try {
      var imageUrl = generatedImageUrl;
      if (imageUrl.isEmpty && selectedImage != null) imageUrl = await ImageService().uploadAdImage(file: selectedImage!, adId: requestId);
      await _service.createAdFromRequest(requestId: requestId, title: title.text, description: description.text, imageUrl: imageUrl, destinationUrl: destination.text, placement: placement, days: days);
      _message('एडमिन विज्ञापन ड्राफ्ट बना दिया गया। अब राशि तय करें।');
      await _load();
    } catch (e) { _message('विज्ञापन नहीं बना: $e'); }
  }

  // ------------------------------------------------------
  // SET AD PRICE / QUOTE
  // ------------------------------------------------------

  Future<void> _quote(Map<String, dynamic> ad) async {
    final id = (ad['campaignId'] ?? ad['id'] ?? '').toString();

    final amount = TextEditingController(
      text: '${ad['amount'] ?? ad['quotedAmount'] ?? ''}',
    );

    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('भुगतान राशि तय करें'),
        content: TextField(
          controller: amount,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'राशि रुपये में',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('रद्द करें'),
          ),
          FilledButton(
            onPressed: () {
              final n = double.tryParse(amount.text.trim());

              if (n != null && n > 0) {
                Navigator.pop(ctx, n);
              }
            },
            child: const Text('राशि भेजें'),
          ),
        ],
      ),
    );

    if (value == null || id.isEmpty) return;

    try {
      await _service.quote(
        campaignId: id,
        amount: value,
      );

      _message('भुगतान राशि भेज दी गई।');
      await _load();
    } catch (e) {
      _message('राशि तय नहीं हुई: $e');
    }
  }

  // ------------------------------------------------------
  // VERIFY PAYMENT AND ACTIVATE
  // ------------------------------------------------------

  Future<void> _verify(Map<String, dynamic> ad) async {
    final id = (ad['campaignId'] ?? ad['id'] ?? '').toString();

    final utr = TextEditingController(text: (ad['submittedPaymentReference'] ?? '').toString());

    final amount = TextEditingController(
      text: '${ad['amount'] ?? ad['quotedAmount'] ?? ''}',
    );

    final result = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('भुगतान जाँचें'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: utr,
              decoration: const InputDecoration(
                labelText: 'UPI UTR / लेन-देन संदर्भ संख्या',
              ),
            ),
            TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'प्राप्त राशि',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'पहले बैंक या UPI में भुगतान की पुष्टि करें।',
              style: TextStyle(color: Colors.deepOrange),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('रद्द करें'),
          ),
          FilledButton(
            onPressed: () {
              if (utr.text.trim().length >= 6 && _number(amount.text) > 0) {
                Navigator.pop(ctx, [
                  utr.text.trim(),
                  amount.text.trim(),
                ]);
              }
            },
            child: const Text('पुष्टि करके चालू करें'),
          ),
        ],
      ),
    );

    if (result == null || id.isEmpty) return;

    try {
      await _service.verify(
        campaignId: id,
        utr: result[0],
        amount: _number(result[1]),
      );

      _message('भुगतान दर्ज हुआ और विज्ञापन सक्रिय किया गया।');
      await _load();
    } catch (e) {
      _message('विज्ञापन सक्रिय नहीं हुआ: $e');
    }
  }

  // ------------------------------------------------------
  // CHANGE STATUS
  // ------------------------------------------------------

  Future<void> _status(
    Map<String, dynamic> ad,
    String action,
  ) async {
    final id = (ad['campaignId'] ?? ad['id'] ?? '').toString();

    String reason = '';

    if (action == 'reject') {
      final controller = TextEditingController();

      final value = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('विज्ञापन अस्वीकार करें'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'अस्वीकार करने का कारण',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('रद्द करें'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  Navigator.pop(
                    ctx,
                    controller.text.trim(),
                  );
                }
              },
              child: const Text('अस्वीकार करें'),
            ),
          ],
        ),
      );

      if (value == null) return;

      reason = value;
    }

    try {
      await _service.changeStatus(
        campaignId: id,
        action: action,
        reason: reason,
      );

      _message('विज्ञापन की स्थिति बदल दी गई।');
      await _load();
    } catch (e) {
      _message('स्थिति नहीं बदली: $e');
    }
  }

  // ------------------------------------------------------
  // ADMIN SCREEN UI
  // ------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('विज्ञापन प्रबंधन'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _settingsDialog,
            icon: const Icon(Icons.settings),
            tooltip: 'पैकेज सेटिंग',
          ),
          IconButton(
            onPressed: _createDialog,
            icon: const Icon(Icons.add),
            tooltip: 'नया विज्ञापन',
          ),
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'विज्ञापन डेटा लोड नहीं हुआ:\n$_error',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('दोबारा कोशिश करें'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      Card(color: Colors.orange.shade50, child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('नई विज्ञापन रिक्वेस्ट (${_requests.length})', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        if (_requests.isEmpty) const Text('अभी कोई नई रिक्वेस्ट नहीं है।'),
                        ..._requests.map((r) => Column(children: [ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.campaign_outlined), title: Text((r['businessName'] ?? 'व्यवसाय').toString()), subtitle: Text('${r['phone'] ?? ''}\n${r['brief'] ?? ''}', maxLines: 3, overflow: TextOverflow.ellipsis), isThreeLine: true), Wrap(spacing: 8, children: [FilledButton(onPressed: () => _createFromRequest(r), child: const Text('विज्ञापन बनाएँ')), TextButton(onPressed: () => _rejectRequest(r), child: const Text('अस्वीकार'))])])),
                      ]))),
                      const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('बनाए गए विज्ञापन', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
                      if (_ads.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('अभी कोई विज्ञापन कैंपेन नहीं है।'))),
                      ..._ads.map(_adminAdCard),
                    ],
                  ),
                ),
    );
  }

  Widget _adminAdCard(Map<String, dynamic> ad) {
    final status = (ad['status'] ?? 'draft').toString();
    final payment = (ad['paymentStatus'] ?? '').toString();
    final id = (ad['campaignId'] ?? ad['id'] ?? '').toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((ad['imageUrl'] ?? '').toString().startsWith('https://')) ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(ad['imageUrl'].toString(), height: 110, width: double.infinity, cacheHeight: 220, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink())),
            Row(
              children: [
                Expanded(
                  child: Text(
                    (ad['title'] ?? 'विज्ञापन').toString(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Chip(label: Text(AppLabels.adStatus(status))),
              ],
            ),
            Text(
              'विज्ञापनदाता: ${ad['advertiserName'] ?? ad['shopName'] ?? ad['shopId'] ?? '-'}',
            ),
            Text('मोबाइल: ${ad['advertiserPhone'] ?? '-'}'),
            Text(
              'पैकेज: ${ad['packageDays'] ?? '-'} दिन',
            ),
            Text(
              'भुगतान: ${payment.isEmpty ? '-' : AppLabels.paymentStatus(payment)}',
            ),
            if (ad['amount'] != null || ad['quotedAmount'] != null)
              Text('तय राशि: ₹${ad['amount'] ?? ad['quotedAmount']}'),
            if (ad['submittedPaymentReference'] != null)
              Text('ग्राहक द्वारा भेजा UTR: ${ad['submittedPaymentReference']}'),
            if (ad['paymentReference'] != null)
              Text('जाँचा गया UTR: ${ad['paymentReference']}'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 5,
              children: [
                if (status == 'draft') OutlinedButton(onPressed: () => _editDraftAd(ad), child: const Text('संपादित करें')),
                if (status == 'draft' || status == 'rejected' || status == 'pending_admin_review')
                  OutlinedButton(
                    onPressed: () => _quote(ad),
                    child: const Text('राशि तय करें'),
                  ),
                if (status == 'awaiting_payment')
                  FilledButton(
                    onPressed: () => _verify(ad),
                    child: const Text('भुगतान जाँचें / चालू करें'),
                  ),
                if (status == 'active')
                  OutlinedButton(
                    onPressed: () => _status(ad, 'pause'),
                    child: const Text('रोकें'),
                  ),
                if (status == 'paused')
                  OutlinedButton(
                    onPressed: () => _status(ad, 'resume'),
                    child: const Text('फिर चालू करें'),
                  ),
                if (status != 'active')
                  TextButton(
                    onPressed: () => _status(ad, 'reject'),
                    child: const Text('अस्वीकार'),
                  ),
                if (status != 'active')
                  TextButton(
                    onPressed: () => _status(ad, 'delete'),
                    child: const Text('हटाएँ'),
                  ),
              ],
            ),
            if (id.isEmpty)
              const Text(
                'कैंपेन ID उपलब्ध नहीं है।',
                style: TextStyle(color: Colors.red),
              ),
          ],
        ),
      ),
    );
  }
}

// ======================================================
// SHOPKEEPER ADVERTISEMENT SCREEN
// ======================================================

class ShopkeeperAdsScreen extends StatefulWidget {
  final bool requestOnly;
  const ShopkeeperAdsScreen({super.key, this.requestOnly = false});

  @override
  State<ShopkeeperAdsScreen> createState() => _ShopkeeperAdsScreenState();
}

class _ShopkeeperAdsScreenState extends State<ShopkeeperAdsScreen> {
  final AdManagementService _service = AdManagementService();

  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _ads = [];
  List<Map<String, dynamic>> _requests = [];


  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final ads = await _service.myCampaigns();
      final requests = await _service.myAdRequests();

      if (!mounted) return;

      _ads = ads;
      _requests = requests;
    } catch (e) {
      _error = e.toString();
    }

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _requestExternalAd() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final brief = TextEditingController();
    final picker = ImagePicker();
    XFile? referencePhoto;
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) => AlertDialog(
      title: const Text('अपने व्यवसाय का विज्ञापन लगवाएँ'),
      content: SingleChildScrollView(child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: name, decoration: const InputDecoration(labelText: 'दुकान / व्यवसाय का नाम'), validator: (v) => v == null || v.trim().length < 2 ? 'नाम लिखें' : null),
        TextFormField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'मोबाइल नंबर'), validator: (v) => v == null || v.trim().length < 8 ? 'मोबाइल नंबर लिखें' : null),
        TextFormField(controller: brief, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: 'क्या प्रचार करवाना चाहते हैं?'), validator: (v) => v == null || v.trim().length < 5 ? 'थोड़ी जानकारी लिखें' : null),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: () async { final f = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1400); if (f != null) setLocal(() => referencePhoto = f); }, icon: const Icon(Icons.photo), label: Text(referencePhoto == null ? 'फोटो जोड़ें (वैकल्पिक)' : 'फोटो चुनी गई')),
        const SizedBox(height: 6), const Text('आपको डिज़ाइन, लिंक, कीमत या अवधि भरने की जरूरत नहीं। विज्ञापन एडमिन बनाएगा।', style: TextStyle(fontSize: 12)),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('रद्द करें')), FilledButton(onPressed: () { if (formKey.currentState!.validate()) Navigator.pop(ctx, true); }, child: const Text('रिक्वेस्ट भेजें'))],
    )));
    if (result != true) return;
    try {
      String referenceUrl = '';
      if (referencePhoto != null) referenceUrl = await ImageService().uploadAdReference(file: referencePhoto!, requestId: DateTime.now().microsecondsSinceEpoch.toString());
      await _service.submitAdRequest(businessName: name.text, phone: phone.text, brief: brief.text, referenceImageUrl: referenceUrl);
      _message('रिक्वेस्ट एडमिन को भेज दी गई। विज्ञापन एडमिन तैयार करेगा।');
      await _load();
    } catch (e) { _message('रिक्वेस्ट नहीं भेजी: $e'); }
  }

  Future<void> _payForAd(Map<String, dynamic> ad) async {
    final id = (ad['campaignId'] ?? ad['id'] ?? '').toString();
    if (id.isEmpty) return;
    try {
      final session = await _service.startAdPayment(id);
      final sessionId = (session['sessionId'] ?? '').toString();
      if (sessionId.isEmpty) throw Exception('Paytm session नहीं मिला।');
      final initiated = await PaymentService().initiatePaytm(sessionId);
      final checkoutUrl = (initiated['checkoutUrl'] ?? '').toString();
      if (!checkoutUrl.startsWith('https://')) throw Exception('Paytm checkout link नहीं मिला।');
      if (!mounted) return;
      final paid = await Navigator.push<bool>(context, MaterialPageRoute(
        builder: (_) => PaytmCheckoutScreen(checkoutUrl: checkoutUrl, sessionId: sessionId),
      ));
      if (paid == true && mounted) {
        _message('भुगतान सफल! विज्ञापन सक्रिय होने की पुष्टि हो गई।');
        await _load();
      }
    } catch (e) {
      _message('भुगतान शुरू नहीं हुआ: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.requestOnly ? 'विज्ञापन रिक्वेस्ट' : 'मेरे विज्ञापन'),
        actions: [
          IconButton(onPressed: _requestExternalAd, icon: const Icon(Icons.add_circle_outline), tooltip: 'विज्ञापन रिक्वेस्ट'),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(
                      'डेटा लोड नहीं हुआ:\n$_error',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'विज्ञापन रिक्वेस्ट',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'आप केवल अपने व्यवसाय की जानकारी भेजें। विज्ञापन का डिज़ाइन, फोटो तैयार करना, जगह, अवधि और शुल्क एडमिन तय करेगा। भुगतान का विवरण स्वीकृति के बाद मिलेगा।',
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_requests.isNotEmpty)
                        Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('आपकी विज्ञापन रिक्वेस्ट', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          ..._requests.map((r) => ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.campaign_outlined), title: Text((r['businessName'] ?? 'व्यवसाय').toString()), subtitle: Text('${r['brief'] ?? ''}${r['rejectionReason'] == null || r['rejectionReason'].toString().isEmpty ? '' : '\nकारण: ${r['rejectionReason']}'}', maxLines: 3, overflow: TextOverflow.ellipsis), trailing: Chip(label: Text(r['status'] == 'converted' ? 'ड्राफ्ट बना' : r['status'] == 'rejected' ? 'अस्वीकृत' : 'जाँच में')))),
                        ]))),
                      if (_ads.any((a) => a['status'] == 'awaiting_payment'))
                        Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('भुगतान के लिए विज्ञापन स्वीकृत', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          const Text('भुगतान दबाने पर Paytm का सुरक्षित भुगतान पृष्ठ खुलेगा। वहाँ उपलब्ध UPI ऐप, QR, कार्ड या नेट बैंकिंग चुनें।'),
                          ..._ads.where((a) => a['status'] == 'awaiting_payment').map((a) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Divider(),
                            Text('${a['title'] ?? 'विज्ञापन'} — ₹${a['amount'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            FilledButton.icon(onPressed: () => _payForAd(a), icon: const Icon(Icons.lock_outline), label: const Text('भुगतान करें')),
                          ])),
                        ]))),
                      if (_ads.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: Text('अभी कोई विज्ञापन कैंपेन नहीं है।')),
                        )
                      else
                        ..._ads.map((ad) {
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.campaign),
                              title: Text(
                                (ad['title'] ?? 'विज्ञापन').toString(),
                              ),
                              subtitle: Text(
                                'स्थिति: ${AppLabels.adStatus(ad['status'])}'
                                ' • भुगतान: ${AppLabels.paymentStatus(ad['paymentStatus'])}',
                              ),
                              trailing: Text(
                                '${ad['packageDays'] ?? '-'} दिन',
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}
