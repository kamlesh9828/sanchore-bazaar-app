import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AddProductDialog extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  const AddProductDialog({super.key, this.initialData});
  bool get isEditing => initialData != null;

  @override
  State<AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<AddProductDialog> {
  final name = TextEditingController();
  final category = TextEditingController(text: 'General');
  final price = TextEditingController();
  final stock = TextEditingController(text: '1');
  final unit = TextEditingController(text: 'नग');
  final picker = ImagePicker();
  String? selectedUrl;
  late String selectedEmoji;
  String _originalName = '';
  bool _nameChanged = false;
  // काजू के लिए अलग vector चित्र है; मूंगफली वाला 🥜 emoji कभी नहीं लगाएँ।
  bool get _isCashew => RegExp(r'काजू|\bkaju\b|\bcashew\b', caseSensitive: false).hasMatch(name.text.trim());
  XFile? selectedFile;

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    selectedEmoji = '';
    if (data != null) {
      name.text = (data['name'] ?? '').toString();
      _originalName = name.text.trim();
      selectedEmoji = _emojiFor(name.text);
      category.text = (data['category'] ?? 'General').toString();
      price.text = ((data['price'] as num?) ?? 0).toString();
      stock.text = ((data['stock'] as num?) ?? 0).toString();
      unit.text = (data['unit'] ?? 'नग').toString();
    }
  }

  void _onProductNameChanged(String value) {
    setState(() {
      selectedEmoji = _emojiFor(value);
      _nameChanged = widget.isEditing && value.trim().toLowerCase() != _originalName.toLowerCase();
      // नाम बदलने पर पुरानी फोटो गलत प्रोडक्ट की हो सकती है, इसलिए उसे हटाएँ।
      if (_nameChanged && selectedUrl == null && selectedFile == null) selectedUrl = '';
    });
  }

  String _emojiFor(String raw) => productEmojiForName(raw);

  Future<void> chooseGallery() async {
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 88, maxWidth: 1800);
    if (file != null && mounted) setState(() { selectedFile = file; selectedUrl = null; });
  }

  Future<void> chooseCamera() async {
    final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 88, maxWidth: 1800);
    if (file != null && mounted) setState(() { selectedFile = file; selectedUrl = null; });
  }

  @override
  void dispose() {
    name.dispose(); category.dispose(); price.dispose(); stock.dispose(); unit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: const Color(0xFFF8FAFC),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    title: Row(children: [
      Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFFE0F2F1), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.add_shopping_cart_rounded, color: Color(0xFF087F8C))),
      const SizedBox(width: 10), Expanded(child: Text(widget.isEditing ? 'सामान की जानकारी बदलें' : 'नया सामान जोड़ें', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18))),
    ]),
    content: SizedBox(width: 560, child: SingleChildScrollView(child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(controller: name, onChanged: _onProductNameChanged, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'सामान का नाम', prefixIcon: Icon(Icons.search_rounded), hintText: 'जैसे: आटा, चावल, दूध, साबुन')),
        const SizedBox(height: 9),
        Container(
          width: double.infinity, padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFE8F4F5), borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            const Text('सामान की पहचान', style: TextStyle(fontSize: 12, color: Color(0xFF24535A), fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Container(width: 132, height: 132, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFB9DCDD))), child: Center(child: _isCashew ? const CustomPaint(size: Size(112, 112), painter: _CashewPainter()) : selectedEmoji.isNotEmpty ? Text(selectedEmoji, style: const TextStyle(fontSize: 82)) : Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.inventory_2_rounded, size: 48, color: Color(0xFF087F8C)), if (name.text.trim().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 5), child: Text(name.text.trim(), maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)))]))),
            const SizedBox(height: 7),
            Text(name.text.trim().isEmpty ? 'नाम लिखते ही सही पहचान दिखेगी' : '${name.text.trim()}  ${_isCashew ? 'काजू' : selectedEmoji}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF174B50))),
            const SizedBox(height: 4),
            const Text('सही फोटो उपलब्ध हो तो फोटो, नहीं तो उसी सामान का सही इमोजी/चित्र दिखेगा।', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Color(0xFF45666A))),
        if (_nameChanged) const Padding(padding: EdgeInsets.only(top: 6), child: Text('सामान का नाम बदला है, इसलिए पुरानी फोटो हटाई गई है। नए सामान की सही फोटो चाहें तो चुनें।', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.deepOrange))),
          ]),
        ),
        const SizedBox(height: 8),
        const Text('चाहें तो गैलरी या कैमरे से भी अपनी फोटो चुन सकते हैं।', style: TextStyle(fontSize: 12, color: Colors.black54)),
        if (widget.isEditing && widget.initialData?['imageVerified'] == true && (widget.initialData?['imageUrl'] ?? '').toString().startsWith('https://') && selectedFile == null && selectedUrl == null)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(widget.initialData!['imageUrl'].toString(), width: 58, height: 58, fit: BoxFit.cover)), const SizedBox(width: 8), const Expanded(child: Text('मौजूदा फोटो बनी रहेगी; आप नई फोटो चुन सकते हैं।')), TextButton(onPressed: () => setState(() { selectedUrl = ''; selectedFile = null; }), child: const Text('गलत फोटो हटाएँ'))])),
        if (widget.isEditing && widget.initialData?['imageVerified'] != true && (widget.initialData?['imageUrl'] ?? '').toString().startsWith('https://') && selectedUrl == null)
          const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('पुरानी फोटो की पुष्टि नहीं है, इसलिए ग्राहकों को नहीं दिखाई जाएगी। सही फोटो गैलरी/कैमरे से चुनें।', style: TextStyle(color: Colors.deepOrange, fontSize: 12))),
        if (selectedUrl == '' && selectedFile == null)
          const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('पुरानी फोटो हटेगी; अब सही इमोजी/चित्र दिखेगा।', style: TextStyle(color: Colors.green, fontSize: 12))),
        Row(children: [Expanded(child: OutlinedButton.icon(onPressed: chooseGallery, icon: const Icon(Icons.photo_library_outlined), label: const Text('गैलरी से चुनें'))), const SizedBox(width: 8), Expanded(child: OutlinedButton.icon(onPressed: chooseCamera, icon: const Icon(Icons.camera_alt_outlined), label: const Text('कैमरा')))]),
        if (selectedFile != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('चुनी गई फोटो: ${selectedFile!.name}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.green))),
        const SizedBox(height: 8),
        TextField(controller: category, decoration: const InputDecoration(labelText: 'श्रेणी')),
        TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'कीमत ₹')),
        TextField(controller: stock, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'स्टॉक')),
        TextField(controller: unit, decoration: const InputDecoration(labelText: 'इकाई: पीस / किलो / ग्राम / लीटर / पैक')),
      ],
    ))),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('रद्द करें')),
      FilledButton(onPressed: () {
        if (name.text.trim().isEmpty || double.tryParse(price.text) == null || int.tryParse(stock.text) == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('सामान का नाम, सही कीमत और स्टॉक भरें।'))); return;
        }
        final existingData = widget.initialData;
        final keepExistingImage = existingData != null &&
            existingData['imageVerified'] == true &&
            selectedUrl == null &&
            !_nameChanged;
        final imageUrl = selectedUrl ??
            (keepExistingImage ? (existingData['imageUrl'] ?? '').toString() : '');
        final imageVerified = selectedFile != null ||
            (selectedUrl == null &&
                !_nameChanged &&
                existingData != null &&
                existingData['imageVerified'] == true);
        Navigator.pop(context, {
          'name': name.text.trim(),
          'category': category.text.trim(),
          'price': double.parse(price.text),
          'stock': int.parse(stock.text),
          'unit': unit.text.trim().toLowerCase(),
          'imageUrl': imageUrl,
          'imageFile': selectedFile,
          'productEmoji': _isCashew ? 'cashew' : selectedEmoji,
          'imageVerified': imageVerified,
        });
      }, child: Text(widget.isEditing ? 'अपडेट करें' : 'सामान सहेजें')),
    ],
  );
}


/// काजू का अपना साफ़ vector चित्र — मूंगफली वाला emoji इस्तेमाल नहीं होता।
class _CashewPainter extends CustomPainter {
  const _CashewPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 112;
    canvas.save();
    canvas.scale(scale);
    final shadow = Paint()..color = const Color(0x223B2410)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final cashew = Path()
      ..moveTo(72, 13)
      ..cubicTo(91, 8, 103, 24, 98, 43)
      ..cubicTo(94, 59, 77, 69, 65, 82)
      ..cubicTo(52, 96, 35, 103, 21, 94)
      ..cubicTo(7, 85, 10, 65, 22, 54)
      ..cubicTo(34, 43, 47, 47, 55, 57)
      ..cubicTo(62, 65, 68, 58, 70, 47)
      ..cubicTo(73, 34, 61, 21, 72, 13)
      ..close();
    canvas.drawPath(cashew.shift(const Offset(1.5, 3)), shadow);
    final fill = Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFE6A3), Color(0xFFE9B95F), Color(0xFFC98932)]).createShader(const Rect.fromLTWH(8, 8, 100, 100));
    canvas.drawPath(cashew, fill);
    final edge = Paint()..style = PaintingStyle.stroke..strokeWidth = 2.2..color = const Color(0xFFB8792C);
    canvas.drawPath(cashew, edge);
    final shine = Path()..moveTo(76, 19)..cubicTo(88, 16, 94, 27, 90, 39);
    canvas.drawPath(shine, Paint()..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeWidth = 4..color = const Color(0xFFFFF4D2));
    canvas.restore();
  }
  @override
  bool shouldRepaint(covariant _CashewPainter oldDelegate) => false;
}


/// नाम से पहचाने जाने वाले आम भारतीय किराना, फल, सब्ज़ी और दैनिक सामान।
/// अंग्रेज़ी, हिंदी और आम बोलचाल की spelling समर्थित हैं।
String productEmojiForName(String raw) {
  final n = raw.toLowerCase().replaceAll(RegExp(r'[-_.,()/]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (n.isEmpty) return '';
  // लंबा नाम पहले जाँचें, ताकि "green chilli" को सामान्य "chilli" से पहले पहचाना जाए।
  const rules = <String, String>{
    // Dry fruits / nuts: केवल वही emoji दें जो सच में उसी चीज़ का हो।
    'मूंगफली':'🥜','moongfali':'🥜','moong phali':'🥜','peanut':'🥜','groundnut':'🥜',
    'काजू':'cashew','kaju':'cashew','cashew':'cashew',
    // Fruits
    'watermelon':'🍉','तरबूज':'🍉','tarbooj':'🍉','muskmelon':'🍈','खरबूजा':'🍈','kharbuja':'🍈',
    'pineapple':'🍍','अनानास':'🍍','ananas':'🍍','pomegranate':'🔴','अनार':'🔴','anar':'🔴',
    'strawberry':'🍓','स्ट्रॉबेरी':'🍓','blueberry':'🫐','ब्लूबेरी':'🫐','coconut':'🥥','नारियल':'🥥','nariyal':'🥥',
    'grapes':'🍇','अंगूर':'🍇','angoor':'🍇','banana':'🍌','केला':'🍌','kela':'🍌',
    'mango':'🥭','आम':'🥭','aam':'🥭','orange':'🍊','संतरा':'🍊','santra':'🍊',
    'apple':'🍎','सेब':'🍎','seb':'🍎','green apple':'🍏','अमरूद':'🍐','amrood':'🍐','guava':'🍐',
    'papaya':'🍈','पपीता':'🍈','papita':'🍈','lemon':'🍋','नींबू':'🍋','nimbu':'🍋',
    'kiwi':'🥝','कीवी':'🥝','chikoo':'🥝','चीकू':'🥝','pear':'🍐','नाशपाती':'🍐',
    'peach':'🍑','आड़ू':'🍑','dates':'🟤','खजूर':'🟤','khajur':'🟤','fig':'🟣','अंजीर':'🟣','anjeer':'🟣',
    // Vegetables
    'cauliflower':'🥦','फूलगोभी':'🥦','phool gobhi':'🥦','cabbage':'🥬','पत्ता गोभी':'🥬','patta gobhi':'🥬',
    'broccoli':'🥦','ब्रोकली':'🥦','spinach':'🥬','पालक':'🥬','palak':'🥬','lettuce':'🥬',
    'brinjal':'🍆','बैंगन':'🍆','baingan':'🍆','eggplant':'🍆','okra':'🥬','भिंडी':'🥬','bhindi':'🥬','ladyfinger':'🥬',
    'carrot':'🥕','गाजर':'🥕','gajar':'🥕','cucumber':'🥒','खीरा':'🥒','kheera':'🥒','ककड़ी':'🥒','kakdi':'🥒',
    'peas':'🫛','मटर':'🫛','matar':'🫛','capsicum':'🫑','शिमला मिर्च':'🫑','shimla mirch':'🫑',
    'green chilli':'🌶️','हरी मिर्च':'🌶️','hari mirch':'🌶️','chilli':'🌶️','मिर्च':'🌶️','mirch':'🌶️',
    'potato':'🥔','आलू':'🥔','aloo':'🥔','sweet potato':'🍠','शकरकंद':'🍠','shakarkand':'🍠',
    'onion':'🧅','प्याज':'🧅','प्याज़':'🧅','pyaj':'🧅','tomato':'🍅','टमाटर':'🍅','tamatar':'🍅',
    'garlic':'🧄','लहसुन':'🧄','lahsun':'🧄','ginger':'🫚','अदरक':'🫚','adrak':'🫚',
    'pumpkin':'🎃','कद्दू':'🎃','kaddu':'🎃','mushroom':'🍄','मशरूम':'🍄','corn':'🌽','मक्का':'🌽','makka':'🌽','भुट्टा':'🌽',
    'radish':'🥕','मूली':'🥕','mooli':'🥕','beetroot':'🟣','चुकंदर':'🟣','chukandar':'🟣',
    'bottle gourd':'🥒','लौकी':'🥒','lauki':'🥒','bitter gourd':'🥒','करेला':'🥒','karela':'🥒',
    'ridge gourd':'🥒','तोरई':'🥒','torai':'🥒','tinda':'🟢','टिंडा':'🟢','tindori':'🟢','टिंडोरी':'🟢',
    'coriander':'🌿','धनिया':'🌿','dhaniya':'🌿','mint':'🌿','पुदीना':'🌿','pudina':'🌿',
    // Dairy / eggs / meat
    'milk':'🥛','दूध':'🥛','doodh':'🥛','curd':'🥣','दही':'🥣','dahi':'🥣','yogurt':'🥣','lassi':'🥛','छाछ':'🥛','chaach':'🥛',
    'cheese':'🧀','मक्खन':'🧈','makhan':'🧈','butter':'🧈',
    'egg':'🥚','अंडा':'🥚','anda':'🥚','eggs':'🥚','chicken':'🍗','चिकन':'🍗','मछली':'🐟','machhli':'🐟','fish':'🐟','prawn':'🦐','झींगा':'🦐',
    // Grains, pulses and kirana staples
    'rice':'🍚','चावल':'🍚','chawal':'🍚','basmati':'🍚','आटा':'🌾','atta':'🌾','aata':'🌾','wheat':'🌾','गेहूं':'🌾','gehu':'🌾',
    'flour':'🌾','maida':'🌾','मैदा':'🌾','suji':'🌾','सूजी':'🌾','semolina':'🌾',
    'dal':'🫘','daal':'🫘','दाल':'🫘','moong dal':'🫘','मूंग दाल':'🫘','masoor dal':'🫘','मसूर दाल':'🫘',
    'urad dal':'🫘','उड़द दाल':'🫘','toor dal':'🫘','अरहर दाल':'🫘','arhar dal':'🫘','chana dal':'🫘','चना दाल':'🫘',
    'rajma':'🫘','राजमा':'🫘','chana':'🫘','चना':'🫘','kabuli chana':'🫘','काबुली चना':'🫘','chole':'🫘','छोले':'🫘',
    'oats':'🥣','ओट्स':'🥣','sabudana':'⚪','साबूदाना':'⚪','makhana':'⚪','मखाना':'⚪',
    'salt':'🧂','नमक':'🧂','namak':'🧂',
    'honey':'🍯','शहद':'🍯','shahad':'🍯','tea':'🍵','चाय':'🍵','chai':'🍵','coffee':'☕','कॉफी':'☕','कॉफ़ी':'☕',
    
    'spices':'🌶️','मसाला':'🌶️','masala':'🌶️',
    'coriander powder':'🌿','धनिया पाउडर':'🌿','garam masala':'🌶️','हींग':'🟡','hing':'🟡','pepper':'⚫','काली मिर्च':'⚫','kali mirch':'⚫',
    // Bakery, snacks and packaged foods
    'bread':'🍞','ब्रेड':'🍞','toast':'🍞','टोस्ट':'🍞','biscuit':'🍪','बिस्कुट':'🍪','cookie':'🍪',
    'chocolate':'🍫','चॉकलेट':'🍫','ice cream':'🍦','आइसक्रीम':'🍦','noodles':'🍜','नूडल्स':'🍜','maggi':'🍜',
    'pizza':'🍕','पिज्जा':'🍕','burger':'🍔','बर्गर':'🍔',
    'juice':'🧃','जूस':'🧃','soft drink':'🥤','cold drink':'🥤','कोल्ड ड्रिंक':'🥤','water':'💧','पानी':'💧','pani':'💧',
    
    // Personal care, cleaning and stationery
    'soap':'🧼','साबुन':'🧼','sabun':'🧼','shampoo':'🧴','शैम्पू':'🧴','toothpaste':'🪥','टूथपेस्ट':'🪥','toothbrush':'🪥','ब्रश':'🪥',
    'phenyl':'🧴','फिनाइल':'🧴','floor cleaner':'🧴','sanitizer':'🧴',
    'tissue':'🧻','टिशू':'🧻','toilet paper':'🧻','diaper':'🧷','डायपर':'🧷','perfume':'🧴','इत्र':'🧴',
    'pen':'🖊️','पेन':'🖊️','pencil':'✏️','पेंसिल':'✏️','notebook':'📒','कॉपी':'📒','copy':'📒','किताब':'📚','book':'📚',
    'battery':'🔋','बैटरी':'🔋','bulb':'💡','बल्ब':'💡','कपड़ा':'👕','kapda':'👕','shirt':'👕','जूता':'👟','juta':'👟','shoes':'👟',
    // अतिरिक्त भारतीय फल, सब्ज़ियाँ और किराना
    'मौसमी':'🍊','mosambi':'🍊','sweet lime':'🍊','जामुन':'🫐','jamun':'🫐','लीची':'🍒','lichi':'🍒','lychee':'🍒',
    'nashpati':'🍐','aadu':'🍑','कच्चा केला':'🍌','raw banana':'🍌',
    'बंद गोभी':'🥬','band gobhi':'🥬','फुलगोभी':'🥦','तुरई':'🥒','परवल':'🥒','parwal':'🥒','मेथी':'🌿','methi':'🌿','सहजन':'🌿','sahjan':'🌿',
    'बेसन':'🟡','besan':'🟡','gram flour':'🟡','चीनी':'🍚','chini':'🍚','sugar':'🍚','गुड़':'🟤','gud':'🟤','jaggery':'🟤',
    'तेल':'🫗','tel':'🫗','oil':'🫗','हल्दी':'🟡','haldi':'🟡','turmeric':'🟡','जीरा':'🌿','jeera':'🌿','cumin':'🌿',
    'राई':'🌱','rai':'🌱','mustard seeds':'🌱','बादाम':'🥜','badam':'🥜','almond':'🥜','किशमिश':'🍇','kishmish':'🍇','raisins':'🍇',
    'अखरोट':'🌰','akhrot':'🌰','walnut':'🌰','पिस्ता':'🥜','pista':'🥜','pistachio':'🥜','सोयाबीन':'🫘','soyabean':'🫘','soybean':'🫘',
    'काला चना':'🫘','kala chana':'🫘','तुअर दाल':'🫘','मुरमुरा':'🍚','murmura':'🍚','रवा':'🌾','rava':'🌾','कॉर्न फ्लेक्स':'🥣','corn flakes':'🥣',
    'डिटर्जेंट':'🧺','detergent':'🧺','सर्फ':'🧺','surf':'🧺','वाशिंग पाउडर':'🧺','माचिस':'🔥','machis':'🔥','matchbox':'🔥',
    'मोमबत्ती':'🕯️','candle':'🕯️','नमकीन':'🥨','namkeen':'🥨','सेव':'🥨','sev':'🥨','चिप्स':'🥔','chips':'🥔',
    'पनीर':'🧀','paneer':'🧀','कॉर्न':'🌽'
  };
  final entries = rules.entries.toList()..sort((a, b) => b.key.length.compareTo(a.key.length));
  for (final entry in entries) {
    final key = entry.key.toLowerCase();
    // पूरे शब्द/नाम का मिलान करें; जैसे 'आमचूर' को 'आम' न समझें।
    if (entry.value.isNotEmpty && RegExp('(^|\\s)' + RegExp.escape(key) + r'(\s|$)').hasMatch(n)) return entry.value;
  }
  return '';
}

class ProductVisual extends StatelessWidget {
  final String? value;
  final String? name;
  final double size;
  const ProductVisual({super.key, this.value, this.name, this.size = 40});
  @override
  Widget build(BuildContext context) {
    final fromName = productEmojiForName(name ?? '');
    final visual = fromName;
    if (visual == 'cashew') {
      return CustomPaint(size: Size(size * 1.2, size * 1.2), painter: const _CashewPainter());
    }
    if (visual.isNotEmpty) return Text(visual, style: TextStyle(fontSize: size));
    return Icon(Icons.inventory_2_outlined, size: size, color: const Color(0xFF087F8C));
  }
}
