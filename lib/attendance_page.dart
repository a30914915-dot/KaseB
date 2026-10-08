import 'package:flutter/material.dart';
import 'network_service.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final NetworkService _network = NetworkService();
  String _selectedActivity = "ثبت ورود";
  final TextEditingController _cityController = TextEditingController(text: "تهران");
  final TextEditingController _addressController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _cityController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  /// ثبت موقعیت و ساعت کارکرد در شیت گزارش ورود ویزیتورها
  Future<void> _submitAttendance() async {
    final String address = _addressController.text.trim();
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ لطفاً نشانی یا نام خیابان جاری را وارد کنید.")),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final now = DateTime.now();
    final Map<String, dynamic> logData = {
      "action": "recordVisitorLog",
      "date":
          "${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}",
      "time":
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}",
      "workHours": "08:00", // زمان پیشفرض استاندارد قانون کار
      "city": _cityController.text.trim(),
      "address": address,
      "latitude": 35.6892, // مختصات جی‌پی‌اس پیشفرض مرکز تهران (قابل اتصال به پکیج لوکیشن)
      "longitude": 51.3890,
      "activityType": _selectedActivity,
      "isInternetVerified": true,
      "timeSource": "NTP_Network"
    };

    final response = await _network.sendToCloud("recordVisitorLog", logData);

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
    });

    if (response['success'] == true) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => AlertDialog(
          title: const Text("✅ ثبت موفقیت‌آمیز کارکرد", textAlign: TextAlign.center),
          content: Text(
            "وضعیت «$_selectedActivity» شما با موفقیت در شیت ابری ثبت گردید.\n\nزمان ثبت: ${logData['time']}\nشهر و نشانی: ${_cityController.text.trim()} - $address",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogCtx); // بستن دیالوگ
                Navigator.pop(context, true); // برگشت به صفحه قبل
              },
              child: const Text("تایید و بازگشت"),
            )
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ خطا در ثبت گزارش کارکرد: ${response['message'] ?? 'خطای سرور'}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text(
          "📍 ثبت ورود و خروج روزانه",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        centerTitle: true,
      ),
      body: _isSubmitting
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFC58F2A)))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Card(
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "نوع فعالیت جاری خود را انتخاب کنید:",
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            value: _selectedActivity,
                            decoration: const InputDecoration(border: OutlineInputBorder()),
                            items: ["ثبت ورود", "ثبت خروج", "شروع ویزیت", "پایان ویزیت"].map((type) {
                              return DropdownMenuItem(
                                value: type,
                                child: Text(type, textDirection: TextDirection.rtl),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedActivity = val;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 15),
                          TextField(
                            controller: _cityController,
                            textAlign: TextAlign.right,
                            decoration: const InputDecoration(
                              labelText: 'شهر',
                              prefixIcon: Icon(Icons.location_city),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 15),
                          TextField(
                            controller: _addressController,
                            textAlign: TextAlign.right,
                            decoration: const InputDecoration(
                              labelText: 'نام خیابان / نشانی مغازه مشتری',
                              prefixIcon: Icon(Icons.map),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC58F2A),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.check_circle),
                      label: Text(
                        'ارسال وضعیت $_selectedActivity',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      onPressed: _submitAttendance,
                    ),
                  )
                ],
              ),
            ),
    );
  }
}
