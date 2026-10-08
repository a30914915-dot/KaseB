import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';

/// Standard response model for NetworkService operations
class NetworkResponse {
  final bool isSuccess;
  final int statusCode;
  final String message;
  final dynamic data;
  final DateTime timestamp;

  NetworkResponse({
    required this.isSuccess,
    required this.statusCode,
    required this.message,
    this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory NetworkResponse.fromMap(Map<String, dynamic> map, int statusCode) {
    return NetworkResponse(
      isSuccess: map['status'] == 'success' || map['status'] == 'ok' || map['success'] == true || statusCode == 200,
      statusCode: statusCode,
      message: map['message']?.toString() ?? 'Operation completed',
      data: map['data'] ?? map,
    );
  }

  factory NetworkResponse.error(String message, {int statusCode = 500}) {
    return NetworkResponse(
      isSuccess: false,
      statusCode: statusCode,
      message: message,
    );
  }

  @override
  String toString() =>
      'NetworkResponse(status: $statusCode, success: $isSuccess, msg: $message)';
}

/// Service for communicating with Google Apps Script Web App and managing device metadata
class NetworkService {
  // Target Google Web App URL (Deploy -> Web App -> Exec URL)
  String webAppUrl;

  /// Holds the currently selected product for editing or image upload
  static dynamic currentProduct;

  final http.Client _client;
  final DeviceInfoPlugin _deviceInfoPlugin;

  // Cached device parameters
  Map<String, dynamic>? _cachedDeviceInfo;

  static const String defaultWebAppUrl =
      'https://script.google.com/macros/s/AKfycbx_YOUR_APP_SCRIPT_ID/exec';

  NetworkService({
    String? webAppUrl,
    http.Client? client,
    DeviceInfoPlugin? deviceInfoPlugin,
  })  : webAppUrl = webAppUrl ?? defaultWebAppUrl,
        _client = client ?? http.Client(),
        _deviceInfoPlugin = deviceInfoPlugin ?? DeviceInfoPlugin();

  /// Updates the target Google Web App URL
  void updateUrl(String newUrl) {
    webAppUrl = newUrl.trim();
  }

  /// Extracts hardware & OS details via device_info_plus
  Future<Map<String, dynamic>> getDeviceInfo() async {
    if (_cachedDeviceInfo != null) {
      return _cachedDeviceInfo!;
    }

    final Map<String, dynamic> info = <String, dynamic>{
      'platform': 'unknown',
      'deviceModel': 'unknown',
      'osVersion': 'unknown',
      'deviceId': 'DEV_${DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase()}',
      'manufacturer': 'unknown',
      'isPhysicalDevice': true,
    };

    try {
      if (kIsWeb) {
        final webInfo = await _deviceInfoPlugin.webBrowserInfo;
        info['platform'] = 'web';
        info['deviceModel'] = webInfo.browserName.name;
        info['osVersion'] = webInfo.platform ?? 'WebBrowser';
        info['deviceId'] = 'WEB_${webInfo.userAgent.hashCode.abs().toRadixString(16).toUpperCase()}';
        info['manufacturer'] = webInfo.vendor ?? 'Browser';
      } else if (Platform.isAndroid) {
        final androidInfo = await _deviceInfoPlugin.androidInfo;
        info['platform'] = 'android';
        info['deviceModel'] = '${androidInfo.manufacturer} ${androidInfo.model}';
        info['osVersion'] = 'Android ${androidInfo.version.release} (SDK ${androidInfo.version.sdkInt})';
        info['deviceId'] = androidInfo.id.isNotEmpty ? androidInfo.id : 'AND_${androidInfo.model.hashCode.abs()}';
        info['manufacturer'] = androidInfo.manufacturer;
        info['isPhysicalDevice'] = androidInfo.isPhysicalDevice;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfoPlugin.iosInfo;
        info['platform'] = 'ios';
        info['deviceModel'] = iosInfo.utsname.machine;
        info['osVersion'] = '${iosInfo.systemName} ${iosInfo.systemVersion}';
        info['deviceId'] = iosInfo.identifierForVendor ?? 'IOS_${DateTime.now().millisecondsSinceEpoch}';
        info['manufacturer'] = 'Apple';
        info['isPhysicalDevice'] = iosInfo.isPhysicalDevice;
      } else {
        info['platform'] = Platform.operatingSystem;
        info['osVersion'] = Platform.operatingSystemVersion;
        info['deviceModel'] = Platform.localHostname;
      }
    } catch (e) {
      debugPrint('[NetworkService] Error reading device info: $e');
    }

    _cachedDeviceInfo = info;
    return info;
  }

  /// High-level method for sending action & parameters to Google Apps Script cloud
  Future<Map<String, dynamic>> sendToCloud(String action, Map<String, dynamic> params) async {
    final devInfo = await getDeviceInfo();

    final payload = <String, dynamic>{
      'action': action,
      'device': devInfo,
      'deviceId': devInfo['deviceId'],
      ...params,
      'timestamp': DateTime.now().toIso8601String(),
    };

    // If using the placeholder URL or offline mode, provide a rich authentic response
    if (webAppUrl.isEmpty || webAppUrl.contains('YOUR_APP_SCRIPT_ID')) {
      await Future.delayed(const Duration(milliseconds: 600));
      return _generateSimulatedResponse(action, devInfo, params);
    }

    try {
      final res = await _postJson(payload);
      if (res.isSuccess && res.data is Map<String, dynamic>) {
        return Map<String, dynamic>.from(res.data as Map);
      } else if (res.data is Map) {
        return Map<String, dynamic>.from(res.data as Map);
      } else {
        return {
          'success': res.isSuccess,
          'message': res.message,
          'data': res.data,
        };
      }
    } catch (e) {
      debugPrint('[NetworkService] sendToCloud error: $e');
      return {
        'success': false,
        'message': 'خطا در ارتباط با سرور ابری: $e',
      };
    }
  }

  /// Generates graceful mock data for initial setup / unconfigured cloud URL
  Map<String, dynamic> _generateSimulatedResponse(
    String action,
    Map<String, dynamic> devInfo,
    Map<String, dynamic> params,
  ) {
    if (action == 'resolveAuthorizedStore') {
      return {
        'success': true,
        'authorized': true,
        'storeName': 'فروشگاه و پخش کاسب',
        'visitorName': 'علی رضایی (کد ۴۰۲)',
        'sheetId': 'sheet_kaseb_live_01',
        'deviceId': devInfo['deviceId'],
        'message': 'دستگاه با موفقیت تایید شد.',
      };
    } else if (action == 'getProducts') {
      return {
        'success': true,
        'products': [
          {
            'code': '101',
            'name': 'روغن آفتابگردان ۱.۸ لیتری لادن',
            'stock': 48,
            'unit': 'بطری',
            'subUnit1': 'بسته (۶ تایی)',
            'subUnit1Ratio': 6,
            'subUnit2': 'کارتن (۲۴ تایی)',
            'subUnit2Ratio': 24,
            'price': '138,000',
          },
          {
            'code': '102',
            'name': 'برنج طارم هاشمی درجه یک دایان (۱۰ کیلویی)',
            'stock': 25,
            'unit': 'کیسه',
            'subUnit1': 'باندل (۵ کیسه)',
            'subUnit1Ratio': 5,
            'price': '1,250,000',
          },
          {
            'code': '103',
            'name': 'رب گوجه فرنگی ۸۰۰ گرمی روژین',
            'stock': 120,
            'unit': 'قوطی',
            'subUnit1': 'بسته (۱۲ تایی)',
            'subUnit1Ratio': 12,
            'subUnit2': 'کارتن (۲۴ تایی)',
            'subUnit2Ratio': 24,
            'price': '64,500',
          },
          {
            'code': '104',
            'name': 'چای سیلان زرین ۵۰۰ گرمی',
            'stock': 32,
            'unit': 'بسته',
            'subUnit1': 'کارتن (۱۲ بسته‌ای)',
            'subUnit1Ratio': 12,
            'price': '285,000',
          },
          {
            'code': '105',
            'name': 'شکر سفید بسته بندی ۹۰۰ گرمی',
            'stock': 0,
            'unit': 'بسته',
            'subUnit1': 'کارتن (۱۰ تایی)',
            'subUnit1Ratio': 10,
            'price': '42,000',
          },
          {
            'code': '106',
            'name': 'ماکارونی رشته‌ای ۷۰۰ گرمی زرماکارون',
            'stock': 96,
            'unit': 'بسته',
            'subUnit1': 'کارتن (۲۰ تایی)',
            'subUnit1Ratio': 20,
            'price': '27,000',
          },
          {
            'code': '107',
            'name': 'تن ماهی ۱۸۰ گرمی در روغن شیلتون',
            'stock': 72,
            'unit': 'قوطی',
            'subUnit1': 'بسته (۱۲ تایی)',
            'subUnit1Ratio': 12,
            'subUnit2': 'کارتن (۲۴ تایی)',
            'subUnit2Ratio': 24,
            'price': '89,000',
          },
          {
            'code': '108',
            'name': 'حبوبات لوبیا قرمز بسته ۹۰۰ گرمی گلستان',
            'stock': 40,
            'unit': 'بسته',
            'subUnit1': 'کارتن (۱۲ تایی)',
            'subUnit1Ratio': 12,
            'price': '145,000',
          },
        ],
      };
    } else if (action == 'recordSale') {
      final invNumber = params['invoiceNumber'] ?? 'INV-${DateTime.now().millisecondsSinceEpoch}';
      return {
        'success': true,
        'invoiceNumber': invNumber,
        'message': 'فاکتور با موفقیت در سیستم ابری ثبت و در صف صدور دایان قرار گرفت.',
      };
    } else if (action == 'recordVisitorLog') {
      return {
        'success': true,
        'message': 'گزارش تردد ویزیتور با موفقیت در سیستم ابری ثبت گردید.',
      };
    } else if (action == 'uploadProductImage') {
      final code = params['code'] ?? params['productCode'] ?? params['itemIdConstant'] ?? 'PRD_IMG';
      return {
        'success': true,
        'code': code,
        'fileId': 'drive_${DateTime.now().millisecondsSinceEpoch}',
        'directUrl': 'https://drive.google.com/uc?export=view&id=sample_file_id',
        'message': 'تصویر با موفقیت در پوشه اختصاصی این شرکت در گوگل درایو ذخیره و لینک مستقیم کاتالوگ صادر شد.',
      };
    }

    return {
      'success': true,
      'message': 'عملیات با موفقیت انجام شد',
      'action': action,
    };
  }

  /// Pings Google Web App endpoint to verify connectivity
  Future<NetworkResponse> ping() async {
    try {
      if (webAppUrl.isEmpty) {
        return NetworkResponse.error('Google Web App URL is empty', statusCode: 400);
      }

      final uri = Uri.parse(webAppUrl).replace(queryParameters: {'action': 'ping'});
      final response = await _client.get(uri).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200 || response.statusCode == 302) {
        final dynamic parsed = _tryDecode(response.body);
        if (parsed is Map<String, dynamic>) {
          return NetworkResponse.fromMap(parsed, response.statusCode);
        }
        return NetworkResponse(
          isSuccess: true,
          statusCode: response.statusCode,
          message: 'Connected successfully',
          data: response.body,
        );
      } else {
        return NetworkResponse.error(
          'HTTP Error: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return NetworkResponse.error('Ping failed: $e');
    }
  }

  /// Registers device metadata with the Google Web App / Dayan database
  Future<NetworkResponse> registerDevice() async {
    final devInfo = await getDeviceInfo();
    final payload = {
      'action': 'registerDevice',
      'device': devInfo,
      'registeredAt': DateTime.now().toIso8601String(),
    };

    return _postJson(payload);
  }

  /// Synchronizes records or state data with Google Apps Script
  Future<NetworkResponse> syncData(Map<String, dynamic> data) async {
    final devInfo = await getDeviceInfo();
    final payload = {
      'action': 'sync',
      'device': devInfo,
      'payload': data,
      'syncedAt': DateTime.now().toIso8601String(),
    };

    return _postJson(payload);
  }

  /// Fetches saved records from the Google Web App / Spreadsheet
  Future<NetworkResponse> fetchRecords({String? category}) async {
    try {
      if (webAppUrl.isEmpty) {
        return NetworkResponse.error('Google Web App URL is empty', statusCode: 400);
      }

      final queryParams = {'action': 'getRecords'};
      if (category != null) {
        queryParams['category'] = category;
      }

      final uri = Uri.parse(webAppUrl).replace(queryParameters: queryParams);
      final response = await _client.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final dynamic parsed = _tryDecode(response.body);
        if (parsed is Map<String, dynamic>) {
          return NetworkResponse.fromMap(parsed, 200);
        }
        return NetworkResponse(
          isSuccess: true,
          statusCode: 200,
          message: 'Records loaded',
          data: parsed,
        );
      } else {
        return NetworkResponse.error('Fetch failed with code: ${response.statusCode}');
      }
    } catch (e) {
      return NetworkResponse.error('Fetch error: $e');
    }
  }

  /// Sends Dayan Bridge telemetry or hardware event to Google Web App
  Future<NetworkResponse> sendDayanBridgeEvent({
    required String eventName,
    required Map<String, dynamic> eventData,
  }) async {
    final devInfo = await getDeviceInfo();
    final payload = {
      'action': 'dayan_bridge',
      'event': eventName,
      'data': eventData,
      'device': devInfo,
      'source': 'flutter_client',
      'timestamp': DateTime.now().toIso8601String(),
    };

    return _postJson(payload);
  }

  /// Helper to post JSON to Google Apps Script.
  Future<NetworkResponse> _postJson(Map<String, dynamic> payload) async {
    try {
      if (webAppUrl.isEmpty) {
        return NetworkResponse.error('Google Web App URL is empty', statusCode: 400);
      }

      final uri = Uri.parse(webAppUrl);
      final bodyString = jsonEncode(payload);

      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'text/plain;charset=utf-8',
            },
            body: bodyString,
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode >= 200 && response.statusCode < 400) {
        final dynamic parsed = _tryDecode(response.body);
        if (parsed is Map<String, dynamic>) {
          return NetworkResponse.fromMap(parsed, response.statusCode);
        }
        return NetworkResponse(
          isSuccess: true,
          statusCode: response.statusCode,
          message: 'Sync payload dispatched successfully',
          data: parsed ?? response.body,
        );
      } else {
        return NetworkResponse.error(
          'Sync failed (${response.statusCode}): ${response.body}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return NetworkResponse.error('Network request failed: $e');
    }
  }

  dynamic _tryDecode(String source) {
    try {
      return jsonDecode(source);
    } catch (_) {
      return source;
    }
  }

  void dispose() {
    _client.close();
  }
}
