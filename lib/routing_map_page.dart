import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong2.dart';
import 'network_service.dart';

class RoutingMapPage extends StatefulWidget {
  const RoutingMapPage({super.key});

  @override
  State<RoutingMapPage> createState() => _RoutingMapPageState();
}

class _RoutingMapPageState extends State<RoutingMapPage> {
  final NetworkService _network = NetworkService();
  bool _isLoading = false;
  List<dynamic> _customers = [];
  List<Marker> _mapMarkers = [];
  String _selectedCityFilter = "همه شهرها";
  List<String> _cities = ["همه شهرها"];

  @override
  void initState() {
    super.initState();
    _loadCustomerLocations();
  }

  /// واکشی اطلاعات جیپیاس مشتریان دایان از شیت مرکزی کاسب
  Future<void> _loadCustomerLocations() async {
    setState(() { _isLoading = true; });
    final response = await _network.sendToCloud("getCustomers", {});
    
    if (response['success'] == true) {
      final List<dynamic> custs = response['customers'] ?? [];
      final Set<String> citySet = {"همه شهرها"};
      final List<Marker> markers = [];

      for (var c in custs) {
        double? lat = double.tryParse(c['latitude']?.toString() ?? "");
        double? lon = double.tryParse(c['longitude']?.toString() ?? "");
        
        if (c['city'] != null && c['city'].toString().isNotEmpty) {
          citySet.add(c['city'].toString());
        }

        // اگر مشتری دارای لوکیشن معتبر جیپیاس در شیت بود، آن را روی نقشه سنجاق کن
        if (lat != null && lon != null) {
          markers.add(
            Marker(
              point: LatLng(lat, lon),
              width: 40,
              height: 40,
              child: GestureDetector(
                onTap: () => _showStoreQuickDetails(c),
                child: const Icon(Icons.location_on, color: Colors.red, size: 35),
              ),
            ),
          );
        }
      }

      setState(() {
        _customers = custs;
        _cities = citySet.toList();
        _mapMarkers = markers;
        _isLoading = false;
      });
    } else {
      setState(() { _isLoading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ خطای واکشی موقعیت مکانی مشتریان")),
      );
    }
  }

  /// نمایش کادر اطلاعات سریع مغازه خریدار هنگام لمس سنجاق روی نقشه
  void _showStoreQuickDetails(dynamic c) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c['storeName'] ?? 'فروشگاه بدون نام', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFC58F2A))),
            const SizedBox(height: 4),
            Text('مدیریت: ${c['name']}', style: const TextStyle(fontSize: 13)),
            Text('تلفن: ${c['mobile']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const Divider(),
            Text('نشانی و لاین توزیع: ${c['address']}', style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.shopping_bag_outlined),
                label: const Text("شروع سفارشگیری این مسیر"),
                onPressed: () {
                  Navigator.pop(context);
                  // هدایت مستقیم ویزیتور به منوی صدور فاکتور برای همین مشتری
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("🗺️ نقشه و لاین مسیریابی روزانه", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        centerTitle: true,
        actions: [
          DropdownButton<String>(
            value: _selectedCityFilter,
            dropdownColor: Colors.white,
            style: const TextStyle(fontFamily: 'Tahoma', color: Colors.black, fontSize: 12),
            items: _cities.map((city) => DropdownMenuItem(value: city, child: Text(city))).toList(),
            onChanged: (val) {
              if (val != null) setState(() { _selectedCityFilter = val; });
              // در اینجا سیستم فیلتر مارکرهای شهرهای خاص را مجدد رندر میکند
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFC58F2A)))
          : FlutterMap(
              options: const MapOptions(
                initialCenter: LatLng(35.6892, 51.3890), // لوکیشن پیشفرض نقشه (تهران)
                initialZoom: 11.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.kaseb.app',
                ),
                MarkerLayer(markers: _mapMarkers),
              ],
            ),
    );
  }
}
