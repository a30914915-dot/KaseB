import 'package:flutter/material.dart';
import 'network_service.dart';

class OrderPage extends StatefulWidget {
  final List<dynamic> products;
  final Map<String, Map<String, int>>? cart;
  const OrderPage({super.key, required this.products, this.cart});

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  final NetworkService _network = NetworkService();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _checkDaysController = TextEditingController(text: "30");
  final TextEditingController _notesController = TextEditingController();
  
  String _paymentMethod = "نقدی";
  bool _isSubmitting = false;
  
  // متغیرهای مالی پیش‌فرض هماهنگ با شیت سیستم
  final double _cashDiscountPercent = 3.0; 
  final int _maxCheckDaysAllowed = 30; 

  @override
  void dispose() {
    _customerNameController.dispose();
    _checkDaysController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// استخراج اقلام معتبر سبد خرید بر مبنای بسته‌بندی ۳ سطحی
  List<Map<String, dynamic>> _getOrderItems() {
    final List<Map<String, dynamic>> items = [];
    final cart = widget.cart ?? {};

    for (var prod in widget.products) {
      String code = prod['code']?.toString() ?? '';
      if (!cart.containsKey(code)) continue;

      final unitCounts = cart[code]!;
      double basePrice = double.tryParse(prod['price']?.toString() ?? '0') ?? 0;
      double sub1Ratio = double.tryParse(prod['subUnit1Ratio']?.toString() ?? '1') ?? 1;
      double sub2Ratio = double.tryParse(prod['subUnit2Ratio']?.toString() ?? '1') ?? 1;

      unitCounts.forEach((unitName, qty) {
        if (qty > 0) {
          double unitMultiplier = 1.0;
          if (unitName == prod['subUnit1']) {
            unitMultiplier = sub1Ratio > 0 ? sub1Ratio : 1.0;
          } else if (unitName == prod['subUnit2']) {
            unitMultiplier = sub2Ratio > 0 ? sub2Ratio : 1.0;
          }

          double linePrice = basePrice * unitMultiplier;
          double lineTotal = linePrice * qty;

          items.add({
            'code': code,
            'name': prod['name'] ?? '',
            'unit': unitName,
            'quantity': qty,
            'unitPrice': linePrice,
            'totalPrice': lineTotal,
            'baseUnitEquivalent': qty * unitMultiplier,
          });
        }
      });
    }
    return items;
  }

  double _calculateRawTotal() {
    final items = _getOrderItems();
    if (items.isEmpty) return 0.0;
    return items.fold(0.0, (sum, item) => sum + (item['totalPrice'] as double));
  }

  double _calculateDiscountAmount() {
    double raw = _calculateRawTotal();
    if (_paymentMethod == "نقدی") {
      return raw * (_cashDiscountPercent / 100.0);
    }
    return 0.0;
  }

  double _calculateFinalAmount() {
    double raw = _calculateRawTotal();
    return (raw - _calculateDiscountAmount()).clamp(0.0, double.infinity);
  }

  Future<void> _submitInvoice() async {
    if (_customerNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ لطفاً نام خریدار یا فروشگاه طرف حساب را وارد کنید."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_paymentMethod == "چکی") {
      int days = int.tryParse(_checkDaysController.text.trim()) ?? 0;
      if (days <= 0 || days > _maxCheckDaysAllowed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("🚫 خطا: حداکثر مهلت مجاز چک $_maxCheckDaysAllowed روز می‌باشد."),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    final items = _getOrderItems();
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ سبد خرید خالی است."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() { _isSubmitting = true; });

    final invoicePayload = {
      "invoiceNumber": "INV-${DateTime.now().millisecondsSinceEpoch}",
      "customerName": _customerNameController.text.trim(),
      "paymentMethod": _paymentMethod,
      "checkDays": _paymentMethod == "چکی" ? _checkDaysController.text.trim() : "0",
      "cashDiscountPercent": _paymentMethod == "نقدی" ? _cashDiscountPercent : 0.0,
      "discountAmount": _calculateDiscountAmount(),
      "rawTotal": _calculateRawTotal(),
      "totalAmount": _calculateFinalAmount(),
      "notes": _notesController.text.trim(),
      "itemCount": items.length,
      "items": items,
    };

    final response = await _network.sendToCloud("recordSale", invoicePayload);

    if (!mounted) return;
    setState(() { _isSubmitting = false; });

    if (response['success'] == true || response['status'] == 'success') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ فاکتور ابری با موفقیت ثبت شد و به حسابداری ارسال گردید."),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ خطا در ثبت فاکتور: ${response['message'] ?? 'خطای برقراری ارتباط'}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _getOrderItems();
    double rawTotal = _calculateRawTotal();
    double discount = _calculateDiscountAmount();
    double finalTotal = _calculateFinalAmount();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text("🛒 تسویه و ثبت فاکتور نهایی"),
        centerTitle: true,
        backgroundColor: const Color(0xFFC58F2A),
        foregroundColor: Colors.white,
      ),
      body: _isSubmitting
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFFC58F2A)),
                  SizedBox(height: 16),
                  Text("در حال ارسال فاکتور به شیت مرکزی کاسب...", style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // بخش مشخصات مشتری و شیوه تسویه
                  Card(
                    color: Colors.white,
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.storefront, color: Color(0xFFC58F2A)),
                              SizedBox(width: 8),
                              Text("مشخصات طرف حساب و تسویه", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                          const Divider(height: 20),
                          TextField(
                            controller: _customerNameController,
                            textAlign: TextAlign.right,
                            decoration: InputDecoration(
                              labelText: 'نام خریدار / فروشگاه طرف حساب',
                              hintText: 'مثال: سوپرمارکت بهار',
                              prefixIcon: const Icon(Icons.person),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            value: _paymentMethod,
                            decoration: InputDecoration(
                              labelText: 'نوع تسویه مالی فاکتور',
                              prefixIcon: const Icon(Icons.payments),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            items: const [
                              DropdownMenuItem(value: "نقدی", child: Text("نقدی (۳٪ تخفیف تسویه فوری)")),
                              DropdownMenuItem(value: "چکی", child: Text("چکی (حداکثر ۳۰ روزه)")),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() { _paymentMethod = val; });
                            },
                          ),
                          if (_paymentMethod == "چکی") ...[
                            const SizedBox(height: 14),
                            TextField(
                              controller: _checkDaysController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                labelText: 'تعداد روز مهلت چک (حداکثر $_maxCheckDaysAllowed روز)',
                                prefixIcon: const Icon(Icons.calendar_today),
                                helperText: 'مصوب مالی شرکت دایان: حداکثر $_maxCheckDaysAllowed روز',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          TextField(
                            controller: _notesController,
                            textAlign: TextAlign.right,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: 'توضیحات و یادداشت فاکتور (اختیاری)',
                              prefixIcon: const Icon(Icons.note_alt),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // لیست اقلام سبد خرید
                  Card(
                    color: Colors.white,
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.list_alt, color: Color(0xFFC58F2A)),
                                  SizedBox(width: 8),
                                  Text("اقلام سبد خرید", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                ],
                              ),
                              Chip(
                                label: Text("${items.length} ردیف کالا", style: const TextStyle(fontSize: 11)),
                                backgroundColor: Colors.amber.shade50,
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          if (items.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24.0),
                              child: Center(
                                child: Text("هیچ کالایی در سبد خرید انتخاب نشده است.", style: TextStyle(color: Colors.grey)),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: items.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final it = items[index];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(it['name'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                  subtitle: Text("کد: ${it['code']} | واحد: ${it['unit']} | فی: ${(it['unitPrice'] as double).toStringAsFixed(0)} ریال", style: const TextStyle(fontSize: 11)),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text("${it['quantity']} ${it['unit']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC58F2A))),
                                      Text("${(it['totalPrice'] as double).toStringAsFixed(0)} ریال", style: const TextStyle(fontSize: 11, color: Colors.black87)),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // کارت ریز محاسبات مالی و دکمه تایید
                  Card(
                    color: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("جمع ناخالص اقلام:", style: TextStyle(color: Colors.grey, fontSize: 13)),
                              Text("${rawTotal.toStringAsFixed(0)} ریال", style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                          if (_paymentMethod == "نقدی") ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("تخفیف نقدی ($_cashDiscountPercent٪):", style: const TextStyle(color: Colors.green, fontSize: 13)),
                                Text("- ${discount.toStringAsFixed(0)} ریال", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                          ],
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("مبلغ نهایی فاکتور:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              Text("${finalTotal.toStringAsFixed(0)} ریال", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFFC58F2A))),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFC58F2A),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text("ثبت نهایی و ارسال به شیت مرکزی", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                              onPressed: items.isNotEmpty ? _submitInvoice : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
