import 'dart:math';
import 'package:flutter/material.dart';
import 'network_service.dart';
import 'order_page.dart';
import 'attendance_page.dart';
import 'upload_image_page.dart';
import 'routing_map_page.dart';

void main() {
  runApp(const KasebApp());
}

class KasebApp extends StatelessWidget {
  const KasebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'سامانه ابری کاسب',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFFC58F2A),
        fontFamily: 'Tahoma',
      ),
      home: const MainDashboard(),
    );
  }
}

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  final NetworkService _network = NetworkService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _stockFilterController = TextEditingController(text: "0");
  
  bool _isLoading = false;
  bool _isAuthorized = false;
  bool _isManager = false; 
  bool _showFloatingBar = true;
  
  String _statusMessage = "🔒 در انتظار بررسی سختافزاری دستگاه...";
  String _storeName = "فروشگاه و پخش کاسب";
  String _visitorName = "ویزیتور";
  
  List<dynamic> _rawProducts = [];
  List<dynamic> _displayProducts = [];
  List<String> _categories = ["همه گروهها"];
  
  final Map<String, Map<String, int>> _globalCart = {};
  String _currentSort = "پیشفرض";
  String _selectedCategory = "همه گروهها";
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _checkDeviceAndConnect();
  }

  Future<void> _checkDeviceAndConnect() async {
    setState(() { _isLoading = true; });
    final authRes = await _network.sendToCloud("resolveAuthorizedStore", {});
    
    if (authRes['success'] == true && authRes['authorized'] == true) {
      final prodRes = await _network.sendToCloud("getProducts", {"sheetId": authRes['sheetId']});
      final List<dynamic> prods = prodRes['products'] ?? [];
      final Set<String> cats = {"همه گروهها"};
      for (var p in prods) {
        if (p['category'] != null && p['category'].toString().isNotEmpty) {
          cats.add(p['category'].toString());
        }
      }

      setState(() {
        _isAuthorized = true;
        _isManager = (authRes['visitorName'] ?? "").toString().contains("مدیر");
        _storeName = authRes['storeName'] ?? "فروشگاه کاسب";
        _visitorName = authRes['visitorName'] ?? "ویزیتور";
        _rawProducts = prods;
        _categories = cats.toList();
        _applyFiltersAndSorting();
        _statusMessage = "🟢 انبار دایان متصل و هماهنگ است.";
        _isLoading = false;
      });
    } else {
      setState(() {
        _isAuthorized = false;
        _statusMessage = authRes['message'] ?? "🚫 دسترسی دستگاه تایید نشده است.";
        _isLoading = false;
      });
    }
  }

  void _applyFiltersAndSorting() {
    List<dynamic> temp = List.from(_rawProducts);
    if (_searchQuery.isNotEmpty) {
      temp = temp.where((p) => p['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) || p['code'].toString().contains(_searchQuery)).toList();
    }
    if (_selectedCategory != "همه گروهها") {
      temp = temp.where((p) => p['category'].toString() == _selectedCategory).toList();
    }
    double minStock = double.tryParse(_stockFilterController.text) ?? -1.0;
    if (minStock >= 0) {
      temp = temp.where((p) => (double.tryParse(p['stock'].toString()) ?? 0.0) >= minStock).toList();
    }
    if (_currentSort == "تاسی (شانسی)") {
      temp.shuffle(Random());
    } else if (_currentSort == "نام کالا") {
      temp.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
    } else if (_currentSort == "بیشترین موجودی") {
      temp.sort((a, b) => (double.tryParse(b['stock'].toString()) ?? 0).compareTo(double.tryParse(a['stock'].toString()) ?? 0));
    }
    setState(() { _displayProducts = temp; });
  }

  double _calculateCartTotal() {
    double total = 0;
    _globalCart.forEach((code, unitsMap) {
      final prod = _rawProducts.firstWhere((p) => p['code'].toString() == code, orphan: () => null);
      if (prod != null) {
        double basePrice = double.tryParse(prod['price'].toString()) ?? 0;
        unitsMap.forEach((unitName, qty) {
          double ratio = 1.0;
          if (unitName == prod['subUnit1']) ratio = double.tryParse(prod['subUnit1Ratio'].toString()) ?? 1.0;
          if (unitName == prod['subUnit2']) ratio = double.tryParse(prod['subUnit2Ratio'].toString()) ?? 1.0;
          total += (basePrice * ratio) * qty;
        });
      }
    });
    return total;
  }

  void _simulateBarcodeScan() {
    if (_rawProducts.isEmpty) return;
    final code = _rawProducts[Random().nextInt(_rawProducts.length)]['code'].toString();
    setState(() { _searchController.text = code; _searchQuery = code; _applyFiltersAndSorting(); });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFC58F2A),
        foregroundColor: Colors.white,
        title: Column(
          children: [
            Text(_storeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text('ویزیتور: $_visitorName ${_isManager ? "(مدیر)" : ""}', style: const TextStyle(fontSize: 10, color: Colors.white70)),
          ],
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.pin_drop),
          tooltip: 'نقشه لاین مسیریابی',
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RoutingMapPage())),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _checkDeviceAndConnect,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFC58F2A)))
          : Stack(
              children: [
                Column(
                  children: [
                    _buildSearchAndFilterGrid(),
                    Expanded(
                      child: _isAuthorized
                          ? ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.fromLTRB(10, 10, 10, 90),
                              itemCount: _displayProducts.length,
                              itemBuilder: (context, index) => _buildProductRow(_displayProducts[index]),
                            )
                          : Center(child: Text(_statusMessage)),
                    ),
                  ],
                ),
                if (_globalCart.isNotEmpty && _showFloatingBar) _buildFloatingSummaryBar(),
              ],
            ),
      floatingActionButton: _isAuthorized ? _buildActionButtons() : null,
    );
  }

  Widget _buildSearchAndFilterGrid() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              labelText: 'جستجوی نام یا کد کالا...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(icon: const Icon(Icons.qr_code_scanner), onPressed: _simulateBarcodeScan),
              border: const OutlineInputBorder(),
            ),
            onChanged: (val) { setState(() { _searchQuery = val; _applyFiltersAndSorting(); }); },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.filter_alt),
                label: Text("حداقل موجودی: ${_stockFilterController.text}"),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("فیلتر فیزیکی انبار"),
                      content: TextField(controller: _stockFilterController, keyboardType: TextInputType.number, textAlign: TextAlign.center),
                      actions: [
                        TextButton(child: const Text("حذف"), onPressed: () { _stockFilterController.text = "0"; Navigator.pop(context); _applyFiltersAndSorting(); }),
                        ElevatedButton(child: const Text("اعمال"), onPressed: () { Navigator.pop(context); _applyFiltersAndSorting(); }),
                      ],
                    ),
                  );
                },
              ),
              DropdownButton<String>(
                value: _currentSort,
                items: ["پیشفرض", "تاسی (شانسی)", "نام کالا", "بیشترین موجودی"].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                onChanged: (val) { if (val != null) { setState(() { _currentSort = val; }); _applyFiltersAndSorting(); } },
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildProductRow(dynamic p) {
    double price = double.tryParse(p['price'].toString()) ?? 0;
    double stock = double.tryParse(p['stock'].toString()) ?? 0;
    String code = p['code'].toString();

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        onTap: () => _showFullScreenProduct(p),
        leading: const Icon(Icons.shopping_bag, color: Color(0xFFC58F2A)),
        title: Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text('کد: $code | موجودی: $stock | فی: $price', style: const TextStyle(fontSize: 11)),
        trailing: _isManager 
            ? IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                onPressed: () { NetworkService.currentProduct = p; Navigator.push(context, MaterialPageRoute(builder: (context) => const UploadImagePage())); },
              )
            : const Icon(Icons.arrow_forward_ios, size: 12),
      ),
    );
  }

  void _showFullScreenProduct(dynamic p) {
    String code = p['code'].toString();
    List<String> units = [p['unit'] ?? 'عدد'];
    if (p['subUnit1'] != null) units.add(p['subUnit1']);
    if (p['subUnit2'] != null) units.add(p['subUnit2']);
    String selectedUnit = units.first;
    int minReq = int.tryParse(p['minDiscountQuantity']?.toString() ?? "0") ?? 0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          int count = _globalCart[code]?[selectedUnit] ?? 0;
          double progress = minReq > 0 ? (count / minReq).clamp(0.0, 1.0) : 0.0;

          return Dialog.fullscreen(
            child: Scaffold(
              appBar: AppBar(title: Text(p['name'] ?? ''), leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))),
              body: Column(
                children: [
                  const Expanded(child: Center(child: Icon(Icons.image, size: 100, color: Colors.grey))),
                  if (minReq > 0)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          LinearProgressIndicator(value: progress, color: Colors.amber, backgroundColor: Colors.grey.shade200),
                          Text('پیشرفت تخفیف ویژه: $count از $minReq', style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                  Wrap(
                    spacing: 8,
                    children: units.map((u) => ChoiceChip(
                      label: Text(u),
                      selected: selectedUnit == u,
                      onSelected: (selected) {
                        if (selected) setDialogState(() { selectedUnit = u; });
                      },
                    )).toList(),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.red, size: 36),
                          onPressed: () {
                            if (count > 0) {
                              setDialogState(() {
                                _globalCart[code]![selectedUnit] = count - 1;
                                if (_globalCart[code]![selectedUnit] == 0) _globalCart[code]!.remove(selectedUnit);
                                if (_globalCart[code]!.isEmpty) _globalCart.remove(code);
                              });
                              setState(() {});
                            }
                          },
                        ),
                        Text('$count', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: Colors.green, size: 36),
                          onPressed: () {
                            setDialogState(() {
                              _globalCart.putIfAbsent(code, () => {});
                              _globalCart[code]![selectedUnit] = count + 1;
                            });
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomAppBar() {
    int totalItems = _globalCart.values.fold(0, (sum, uMap) => sum + uMap.values.fold(0, (subSum, qty) => subSum + qty));
    int factorLines = _globalCart.keys.length;
    double totalPrice = _calculateCartTotal();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC58F2A), foregroundColor: Colors.white),
            icon: const Icon(Icons.receipt_long),
            label: Text('ثبت فاکتور ($factorLines ردیف | $totalItems قلم)'),
            onPressed: totalItems > 0
                ? () => Navigator.push(context, MaterialPageRoute(builder: (context) => OrderPage(cart: _globalCart, products: _rawProducts)))
                : null,
          ),
          Text('${totalPrice.toStringAsFixed(0)} ریال', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildFloatingScrollButton() {
    return FloatingActionButton.small(
      backgroundColor: const Color(0xFFC58F2A),
      child: const Icon(Icons.arrow_upward, color: Colors.white),
      onPressed: () => _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeIn),
    );
  }
}
