// ============================
// lib/screens/trip_map_page.dart
// ============================
// หน้าเต็มจอ: แสดงแผนที่ Longdo พร้อมหมุด ณ lat/lon ที่รับมาจาก ViewTripDetailScreen
// รองรับ Android/iOS/macOS (webview_flutter) และ Windows (webview_windows)

import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// webview สำหรับมือถือ/macOS
import 'package:webview_flutter/webview_flutter.dart' as wf;
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart' as wpi;
import 'package:webview_flutter_android/webview_flutter_android.dart' as wfa;
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart' as wfwk;

// webview สำหรับ Windows
import 'package:webview_windows/webview_windows.dart' as wwin;

class TripMapPage extends StatefulWidget {
  final double lat;
  final double lon;
  final String title;
  final String longdoJsKey; // ใส่คีย์ Longdo JS
  final int zoom;

  const TripMapPage({
    super.key,
    required this.lat,
    required this.lon,
    required this.title,
    required this.longdoJsKey,
    this.zoom = 16,
  });

  @override
  State<TripMapPage> createState() => _TripMapPageState();
}

class _TripMapPageState extends State<TripMapPage> {
  wwin.WebviewController? _winCtl;          // Windows
  late final wf.WebViewController _mobCtl;  // Android/iOS/macOS
  bool get _isWindows => !kIsWeb && Platform.isWindows;

  String _html() {
    final escTitle = jsonEncode(widget.title);
    return '''
<!DOCTYPE html><html lang="th"><head>
<meta charset="utf-8"/><meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>Trip Map</title>
<script src="https://api.longdo.com/map/?key=${widget.longdoJsKey}"></script>
<style>html,body{margin:0;height:100%}#map{height:100%}</style>
</head><body>
<div id="map"></div>
<script>
function boot(){
  if(!window.longdo||!longdo.Map){ return setTimeout(boot,200); }
  var map=new longdo.Map({ placeholder: document.getElementById('map') });
  var p={ lon:${widget.lon}, lat:${widget.lat} };
  var mk=new longdo.Marker(p,{ title:${escTitle} });
  map.Overlays.add(mk);
  map.location(p,true);
  map.zoom(${widget.zoom});
}
boot();
</script>
</body></html>
''';
  }

  void _ensurePlatform() {
    if (wpi.WebViewPlatform.instance == null) {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          wpi.WebViewPlatform.instance = wfa.AndroidWebViewPlatform();
          break;
        case TargetPlatform.iOS:
        case TargetPlatform.macOS:
          wpi.WebViewPlatform.instance = wfwk.WebKitWebViewPlatform();
          break;
        default:
          break;
      }
    }
  }

  Future<void> _initWindows() async {
    _winCtl = wwin.WebviewController();
    await _winCtl!.initialize();
    final dataUrl = Uri.dataFromString(_html(), mimeType: 'text/html', encoding: const Utf8Codec()).toString();
    await _winCtl!.loadUrl(dataUrl);
    setState(() {});
  }

  void _initMobile() {
    _ensurePlatform();
    _mobCtl = wf.WebViewController()
      ..setJavaScriptMode(wf.JavaScriptMode.unrestricted)
      ..loadHtmlString(_html());
  }

  @override
  void initState() {
    super.initState();
    if (_isWindows) {
      _initWindows();
    } else {
      _initMobile();
    }
  }

  @override
  void dispose() {
    _winCtl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = _isWindows
        ? (_winCtl == null ? const Center(child: CircularProgressIndicator()) : wwin.Webview(_winCtl!))
        : wf.WebViewWidget(controller: _mobCtl);

    return Scaffold(
      appBar: AppBar(title: Text(widget.title.isEmpty ? 'แผนที่' : widget.title)),
      body: SafeArea(child: child),
    );
  }
}


// ============================
// แก้ ViewTripDetailScreen ให้กดแล้วเด้งไป TripMapPage
// ============================
// 1) เพิ่ม import ด้านบนไฟล์ ViewTripDetailScreen.dart
// import 'dart:convert';
// import 'package:finalproject/screens/trip_map_page.dart';

// 2) เพิ่มเมธอดใน _ViewTripDetailScreenState
/*
  void _openTripMap() {
    double? lat; double? lon; String title = '';
    try {
      final m = jsonDecode(trip.location ?? '') as Map<String, dynamic>;
      lat = (m['lat'] as num?)?.toDouble();
      lon = (m['lon'] as num?)?.toDouble();
      title = (m['name'] as String?) ?? (m['address'] as String?) ?? (trip.tripName ?? '');
    } catch (_) {
      title = trip.location ?? (trip.tripName ?? '');
    }

    if (lat == null || lon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ทริปนี้ยังไม่มีพิกัด (lat/lon)')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TripMapPage(
          lat: lat!,
          lon: lon!,
          title: title,
          longdoJsKey: '2fda6462e44be22918f1bb3e1fc8dc79',
        ),
      ),
    );
  }
*/

// 3) แก้ส่วนแสดง Location row ให้กดได้ (แทนโค้ดเดิม)
/*
  InkWell(
    onTap: _openTripMap,
    child: Row(
      children: [
        const Icon(Icons.location_on_outlined, color: Colors.grey, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trip.location ?? '-',
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              const Text('แตะเพื่อดูแผนที่', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
            ],
          ),
        ),
        const Icon(Icons.map_outlined, color: Colors.blueGrey),
      ],
    ),
  ),
*/

// หมายเหตุ:
// - ให้แน่ใจว่า AndroidManifest มี INTERNET
//   <uses-permission android:name="android.permission.INTERNET" />
// - ถ้า Windows ให้ติดตั้ง WebView2 Runtime และเพิ่ม dependency webview_windows
