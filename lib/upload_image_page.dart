import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'network_service.dart';

class UploadImagePage extends StatefulWidget {
  const UploadImagePage({super.key});

  @override
  State<UploadImagePage> createState() => _UploadImagePageState();
}

class _UploadImagePageState extends State<UploadImagePage> {
  final NetworkService _network = NetworkService();
  late TextEditingController _codeController;
  late TextEditingController _minQtyController;
  late TextEditingController _minUnitController;
  late TextEditingController _discountController;
  
  String _productName = "کالای انتخاب نشده";
  File? _selectedImage;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final prod = NetworkService.currentProduct;
    String initialCode = "";
    String minQty = "0";
    String minUnit = "عدد";
    String discount = "0";

    if (prod != null) {
      initialCode = (prod['code'] ?? "").toString();
      _productName = (prod['name'] ?? "").toString();
      minQty = (prod['minDiscountQuantity'] ?? "0").toString();
      minUnit = (prod['minDiscountUnit'] ?? "عدد").toString();
      discount = (prod['specialDiscountPercent'] ?? "0").toString();
    }

    _codeController = TextEditingController(text: initialCode);
    _minQtyController = TextEditingController(text: minQty);
    _minUnitController = TextEditingController(text: minUnit);
    _discountController = TextEditingController(text: discount);
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source, imageQuality: 50, maxWidth: 800);
    if (pickedFile != null) { setState(() { _selectedImage = File(pickedFile.path); }); }
  }

  Future<void> _saveProductData() async {
    setState(() { _isUploading = true; });
    try {
      String? base64Image;
      if (_selectedImage != null) {
        final bytes = await _selectedImage!.readAsBytes();
        base64Image = base64Encode(bytes);
      }

      // ارسال ۴ پارامتر کالا به صورت همزمان به سرور ابری گوگل شیت کاسب
      final response = await _network.sendToCloud("updateProduct", {
        "code": _codeController.text,
        "productCode": _codeController.text,
        "minDiscountQuantity": int.tryParse(_minQtyController.text) ?? 0,
        "minDiscountUnit": _minUnitController.text,
        "specialDiscountPercent": double.tryParse(_discountController.text) ?? 0.0,
        "base64Data": base64Image ?? "",
      });

      setState(() { _isUploading = false; });

      if (response['success'] == true) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text("📝 بروزرسانی کالا انجام شد", textAlign: TextAlign.center),
            content: Text("مشخصات تصویر و آفر تخفیف کالا با موفقیت در شیت ابری ثبت و اعمال شد.\nکالا: $_productName"),
            actions: [
              TextButton(
                onPressed: () { Navigator.pop(context); Navigator.pop(context); },
                child: const Text("تایید و بازگشت"),
              )
            ],
          ),
        );
      } else { throw Exception(); }
    } catch (e) {
      setState(() { _isUploading = false; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("❌ خطای ارتباط با سرور ابری شیت")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(title: const Text("✏️ تنظیمات تصاویر و پروموشن کالا"), centerTitle: true),
      body: _isUploading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Card(
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text(_productName, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC58F2A))),
                          const SizedBox(height: 10),
                          TextField(controller: _codeController, enabled: false, textAlign: TextAlign.center, decoration: const InputDecoration(labelText: 'شناسه ثابت دایان (قفل 🔒)', border: OutlineInputBorder(), fillColor: Color(0xFFEEEEEE), filled: true)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(child: TextField(controller: _minUnitController, textAlign: TextAlign.center, decoration: const InputDecoration(labelText: 'واحد پروموشن (مثلا کارتن)', border: OutlineInputBorder()))),
                              const SizedBox(width: 10),
                              Expanded(child: TextField(controller: _minQtyController, keyboardType: TextInputType.number, textAlign: TextAlign.center, decoration: const InputDecoration(labelText: 'تعداد حداقل خرید آفر', border: OutlineInputBorder()))),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(controller: _discountController, keyboardType: TextInputType.number, textAlign: TextAlign.center, decoration: const InputDecoration(labelText: 'درصد تخفیف ویژه پلهای (٪)', border: OutlineInputBorder())),
                          const SizedBox(height: 15),
                          Container(
                            height: 150, width: double.infinity,
                            decoration: BoxDecoration(color: const Color(0xFFF4F6F9), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                            child: _selectedImage != null ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(_selectedImage!, fit: BoxFit.cover)) : const Center(child: Text("تصویر کالا تغییر نکرده است", style: TextStyle(color: Colors.grey, fontSize: 12))),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton.icon(icon: const Icon(Icons.camera_alt), label: const Text("دوربین"), onPressed: () => _pickImage(ImageSource.camera)),
                              ElevatedButton.icon(icon: const Icon(Icons.photo_library), label: const Text("گالری"), onPressed: () => _pickImage(ImageSource.gallery)),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(width: double.infinity, height: 48, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC58F2A), foregroundColor: Colors.white), onPressed: _saveProductData, child: const Text("ذخیره و ارسال اطلاعات کالا به شیت", style: TextStyle(fontWeight: FontWeight.bold)))),
                ],
              ),
            ),
    );
  }
}
