// lib/screens/place_picker_page.dart
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

// มือถือ / macOS (ใช้ webview_flutter)
import 'package:webview_flutter/webview_flutter.dart' as wf;
// ชี้ platform implementation ให้ชัด (กัน assert)
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart' as wpi;
import 'package:webview_flutter_android/webview_flutter_android.dart' as wfa;
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart' as wfwk;

// Windows (ใช้ webview_windows + WebView2 runtime)
import 'package:webview_windows/webview_windows.dart' as wwin;

class PlacePickerPage extends StatefulWidget {
  final String longdoJsKey; // คีย์ Longdo JS
  const PlacePickerPage({super.key, required this.longdoJsKey});

  @override
  State<PlacePickerPage> createState() => _PlacePickerPageState();
}

class _PlacePickerPageState extends State<PlacePickerPage> {
  // ---------- HTML + CSS (สวยงาม) + JS ----------
  String _html(String key) => '''
<!DOCTYPE html><html lang="th"><head>
<meta charset="utf-8"/><meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>Place Picker</title>
<script src="https://api.longdo.com/map/?key=$key"></script>
<style>
:root{
  --bg:#0b0c10; --card:#101218; --muted:#8892a6; --line:#212634; --fg:#eef2ff;
  --accent:#60a5fa; --accent-2:#22d3ee; --ok:#34d399; --warn:#f59e0b;
}
@media (prefers-color-scheme: light){
  :root{ --bg:#f7f8fb; --card:#ffffff; --muted:#667085; --line:#e6e8ee; --fg:#0f172a;
         --accent:#2563eb; --accent-2:#06b6d4; }
}
*{box-sizing:border-box} html,body{height:100%}
body{margin:0;font-family:system-ui,-apple-system,Segoe UI,Roboto,Arial;background:var(--bg);color:var(--fg)}
.container{max-width:920px;margin:0 auto;padding:16px}
.header{display:flex;align-items:center;justify-content:space-between;margin-bottom:10px}
.title{font-weight:700;font-size:18px;letter-spacing:.2px}

.searchWrap{position:sticky;top:10px;z-index:20;margin-bottom:10px}
.searchBox{position:relative;display:flex;align-items:center;background:var(--card);border:1px solid var(--line);border-radius:14px;padding:6px 10px;box-shadow:0 8px 30px rgba(0,0,0,.15)}
.searchBox input{flex:1;border:0;background:transparent;color:var(--fg);padding:10px 8px;font-size:15px;outline:none}
.icon{opacity:.9}
.btnClear{border:0;background:transparent;color:var(--muted);cursor:pointer;padding:6px;border-radius:10px}
.btnClear:hover{background:rgba(255,255,255,.06)}
.suggest{position:absolute;left:0;right:0;top:100%;margin-top:6px;background:var(--card);border:1px solid var(--line);border-radius:14px;box-shadow:0 12px 32px rgba(0,0,0,.25);display:none;max-height:260px;overflow:auto}
.suggest a{display:block;padding:10px 12px;text-decoration:none;color:var(--fg);border-bottom:1px dashed var(--line)}
.suggest a:last-child{border-bottom:0}
.badge{display:inline-flex;align-items:center;gap:6px;font-size:12px;color:var(--muted)}

.mapCard{border:1px solid var(--line);border-radius:16px;overflow:hidden;background:var(--card)}
.mapWrap{position:relative}
#map{height:320px}
.locateBtn{position:absolute;right:12px;top:12px;border:1px solid var(--line);background:var(--card);border-radius:999px;padding:10px;cursor:pointer;box-shadow:0 10px 24px rgba(0,0,0,.3)}
.locateBtn:hover{transform:translateY(-1px)}
.statusBar{display:flex;align-items:center;justify-content:space-between;padding:8px 12px;border-top:1px solid var(--line);background:var(--card)}
.spinner{width:16px;height:16px;border:2px solid var(--line);border-top:2px solid var(--accent);border-radius:50%;animation:spin 1s linear infinite}
@keyframes spin{to{transform:rotate(360deg)}}

.list{margin-top:12px;border:1px solid var(--line);border-radius:16px;overflow:hidden;background:var(--card)}
.head{display:flex;align-items:center;justify-content:space-between;padding:10px 12px;border-bottom:1px solid var(--line)}
.items{max-height:360px;overflow:auto}
.item{display:flex;gap:12px;justify-content:space-between;padding:12px;border-bottom:1px solid var(--line);cursor:pointer;transition:background .15s}
.item:hover{background:rgba(255,255,255,.04)}
.item:last-child{border-bottom:0}
.left{min-width:0}
.name{font-weight:600}
.addr{color:var(--muted);font-size:12px;margin-top:2px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;max-width:480px}
.right{text-align:right}
.coords{color:var(--muted);font-size:12px}
.index{display:inline-flex;align-items:center;justify-content:center;width:24px;height:24px;border-radius:50%;background:linear-gradient(90deg,var(--accent),var(--accent-2));color:#fff;font-weight:700;margin-right:6px;flex:none}
.selected{background:rgba(96,165,250,.12)}
.notice{padding:14px;text-align:center;color:var(--muted)}
kbd{padding:2px 6px;border-radius:6px;border:1px solid var(--line);background:var(--card);font-size:12px;color:var(--muted)}
</style>
</head><body>
<div class="container">
  <div class="header">
    <div class="title">เลือกสถานที่</div>
    <div class="badge"><svg width="14" height="14" viewBox="0 0 24 24" fill="none"><path d="M12 21s-6-4.5-6-10a6 6 0 1 1 12 0c0 5.5-6 10-6 10z" stroke="currentColor" stroke-width="1.5"/></svg> Powered by Longdo Map</div>
  </div>

  <div class="searchWrap">
    <div class="searchBox">
      <svg class="icon" width="18" height="18" viewBox="0 0 24 24" fill="none"><path d="M21 21l-4.3-4.3M10.5 18a7.5 7.5 0 1 1 0-15 7.5 7.5 0 0 1 0 15z" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg>
      <input id="q" placeholder="พิมพ์อย่างน้อย 3 ตัวอักษร แล้วกด Enter" autocomplete="off"/>
      <button class="btnClear" id="clear" title="ล้าง">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none"><path d="M18 6L6 18M6 6l12 12" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg>
      </button>
    </div>
    <div id="sg" class="suggest"></div>
  </div>

  <div class="mapCard">
    <div class="mapWrap">
      <div id="map"></div>
      <button id="loc" class="locateBtn" title="ไปยังตำแหน่งของฉัน">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none"><path d="M12 3v3m0 12v3m9-9h-3M6 12H3m12.5 0a3.5 3.5 0 1 1-7 0 3.5 3.5 0 0 1 7 0z" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/></svg>
      </button>
    </div>
    <div class="statusBar">
      <div id="statusText" class="badge">พร้อมค้นหา • กด <kbd>Enter</kbd></div>
      <div id="spin" style="display:none" class="spinner"></div>
    </div>
  </div>

  <div class="list">
    <div class="head">
      <div>ผลลัพธ์ <span id="count">0</span> รายการ</div>
      <div class="badge">แตะรายการเพื่อเลือกและส่งกลับ</div>
    </div>
    <div id="items" class="items"></div>
  </div>
</div>

<script>
function sendToHost(obj){
  try{
    var msg = JSON.stringify(obj||{});
    if (window.PlaceChannel && window.PlaceChannel.postMessage) { window.PlaceChannel.postMessage(msg); return; }
    if (window.chrome && window.chrome.webview && window.chrome.webview.postMessage) { window.chrome.webview.postMessage(msg); return; }
  }catch(e){}
}
function logToHost(level, msg){ sendToHost({ __log:true, level:level, msg:String(msg) }); }
window.onerror = function(msg, src, line, col){ logToHost('error', msg+' @ '+src+':'+line+':'+col); };
(function(){ let _l=console.log,_e=console.error,_w=console.warn;
  console.log=(...a)=>{logToHost('log',a.join(' ')); _l(...a)};
  console.error=(...a)=>{logToHost('error',a.join(' ')); _e(...a)};
  console.warn=(...a)=>{logToHost('warn',a.join(' ')); _w(...a)};
})();

var map, q, sg, itemsBox, countBox, spin, statusText, mk, mkMe, lastKw='';
function boot(){
  if(!window.longdo || !longdo.Map){ console.error('longdo not ready'); return setTimeout(boot,300); }
  map = new longdo.Map({ placeholder: document.getElementById('map') });
  q = document.getElementById('q'); sg = document.getElementById('sg');
  itemsBox = document.getElementById('items'); countBox = document.getElementById('count');
  spin = document.getElementById('spin'); statusText = document.getElementById('statusText');

  q.addEventListener('input', onInput);
  q.addEventListener('keyup', onKey);
  document.getElementById('clear').onclick = function(){ q.value=''; sg.style.display='none'; itemsBox.innerHTML=''; countBox.textContent='0'; statusText.textContent='พิมพ์คำค้นหา…'; };
  document.getElementById('loc').onclick = function(){ sendToHost({ __cmd:'locate_me' }); };

  map.Event.bind('suggest', onSuggest);
  map.Event.bind('search', onSearch);
  console.log('boot ok');
}

function onInput(){
  var t = q.value.trim();
  if (t.length < 3){ sg.style.display='none'; return; }
  clearTimeout(window.__sgTimer);
  window.__sgTimer = setTimeout(function(){ map.Search.suggest(t, {}); }, 120);
}
function onKey(e){
  if(e.key==='Enter'){
    var kw = q.value.trim();
    if(kw.length>=3){ doSearch(kw); sg.style.display='none'; }
  } else if(e.key==='Escape'){ sg.style.display='none'; }
}
function setLoading(on){ spin.style.display = on ? 'block' : 'none'; statusText.textContent = on ? 'กำลังค้นหา…' : 'พร้อมค้นหา • กด Enter'; }
function doSearch(kw){ lastKw = kw; setLoading(true); map.Search.search(kw, { limit: 10 }); }
function onSuggest(r){
  if (!q.value || q.value.trim().length < 3) { sg.style.display='none'; return; }
  sg.innerHTML='';
  (r.data||[]).forEach(function(it){
    var a=document.createElement('a'); a.href='javascript:void(0)'; a.textContent=it.w;
    a.onclick=function(){ q.value=it.w; sg.style.display='none'; doSearch(it.w); };
    sg.appendChild(a);
  });
  sg.style.display=(r.data&&r.data.length)?'block':'none';
}
function onSearch(r){
  setLoading(false);
  var d=r&&r.data?r.data:[];
  renderItems(d.slice(0,10));
  countBox.textContent = (d||[]).length;
  if(d.length){
    var f=d[0], p={lon:Number(f.lon),lat:Number(f.lat)};
    map.location(p,true); setMarker(p, f.name||f.w||'');
  }
}
function setMarker(p, title){
  try{ if(mk){ map.Overlays.remove(mk); } mk = new longdo.Marker(p, { title: title||'' }); map.Overlays.add(mk); }catch(e){}
}
function renderItems(arr){
  itemsBox.innerHTML='';
  if(!arr || !arr.length){
    var em = document.createElement('div'); em.className='notice';
    em.innerHTML='ไม่พบผลลัพธ์สำหรับ “'+escapeHtml(lastKw)+'”'; itemsBox.appendChild(em); return;
  }
  arr.forEach(function(it, idx){
    var row=document.createElement('div'); row.className='item';
    row.innerHTML = '<div class="left"><div class="name"><span class="index">'+(idx+1)+'</span>'+escapeHtml(it.name||'-')+'</div>'
                  + '<div class="addr">'+escapeHtml(it.address||'')+'</div></div>'
                  + '<div class="right"><div class="coords">'+Number(it.lat).toFixed(6)+', '+Number(it.lon).toFixed(6)+'</div></div>';
    row.onclick=function(){
      document.querySelectorAll('.item').forEach(el=>el.classList.remove('selected'));
      row.classList.add('selected');
      var p={lon:Number(it.lon),lat:Number(it.lat)};
      map.location(p,true); setMarker(p, it.name||'');
      var out={id:it.id||'',name:it.name||it.w||'',address:it.address||'',lat:p.lat,lon:p.lon};
      sendToHost(out); // คลิกแล้วค่อยส่งกลับ
    };
    itemsBox.appendChild(row);
  });
}
function escapeHtml(s){return String(s).replace(/[&<>"']/g,function(m){return({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m])})}

// รับพิกัดจาก Host แล้วแพน + ปักหมุด "ฉัน"
window.hostSetMyLocation = function(lat, lon){
  try{
    var p={lat:Number(lat), lon:Number(lon)};
    if(mkMe){ map.Overlays.remove(mkMe); }
    mkMe = new longdo.Marker(p, { title: 'ตำแหน่งของฉัน' });
    map.Overlays.add(mkMe);
    map.location(p,true);
  }catch(e){ console.error(e); }
}

document.addEventListener('DOMContentLoaded', boot);
</script>
</body></html>
''';

  // ---------- ชี้ implementation ให้ webview_flutter ----------
  void _ensureWebViewPlatform() {
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

  // ---------- ตัวควบคุมแต่ละแพลตฟอร์ม ----------
  wwin.WebviewController? _winCtl;          // Windows
  late final wf.WebViewController _mobCtl;  // Android/iOS/macOS
  bool get _isWindows => !kIsWeb && Platform.isWindows;

  Future<void> _initWindows() async {
    _winCtl = wwin.WebviewController();
    await _winCtl!.initialize();
    _winCtl!.webMessage.listen((message) {
      try {
        final data = jsonDecode(message);
        // รับคำสั่งจากเว็บ
        if (data is Map && data['__cmd'] == 'locate_me') {
          _locateMe(); // ขอพิกัดแล้วส่งกลับเข้าแผนที่
          return;
        }
        if (data is Map && data['__log'] == true) {
          debugPrint('[WV LOG] ${data['level']}: ${data['msg']}');
          return;
        }
        if (mounted) Navigator.pop(context, data); // ส่งเฉพาะตอนคลิกรายการ
      } catch (_) {
        debugPrint('[WV MSG] $message');
      }
    });
    final dataUrl = Uri.dataFromString(
      _html(widget.longdoJsKey),
      mimeType: 'text/html',
      encoding: utf8,
    ).toString();
    await _winCtl!.loadUrl(dataUrl);
    setState(() {});
  }

  void _initMobile() {
    _ensureWebViewPlatform();
    _mobCtl = wf.WebViewController()
      ..setJavaScriptMode(wf.JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('PlaceChannel', onMessageReceived: (m) {
        final data = jsonDecode(m.message);
        // รับคำสั่งจากเว็บ
        if (data is Map && data['__cmd'] == 'locate_me') {
          _locateMe(); // ขอพิกัดแล้วส่งกลับเข้าแผนที่
          return;
        }
        if (data is Map && data['__log'] == true) {
          debugPrint('[WV LOG] ${data['level']}: ${data['msg']}');
          return;
        }
        Navigator.pop(context, data); // ส่งเฉพาะตอนคลิกรายการ
      })
      ..setNavigationDelegate(wf.NavigationDelegate(
        onWebResourceError: (err) {
          debugPrint('[WV ERROR] ${err.errorType} ${err.errorCode} ${err.description}');
        },
      ))
      ..loadHtmlString(_html(widget.longdoJsKey));
  }

  // ---------- ขอสิทธิ์ + ดึงพิกัด แล้วส่งเข้า WebView ----------
  Future<void> _locateMe() async {
    try {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('กรุณาเปิด Location Service')),
          );
        }
        return;
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('แอปไม่ได้รับสิทธิ์ตำแหน่ง')),
          );
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final js = "window.hostSetMyLocation(${pos.latitude}, ${pos.longitude});";

      if (_isWindows) {
        await _winCtl?.executeScript(js);
      } else {
        await _mobCtl.runJavaScript(js);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ระบุตำแหน่งไม่ได้: $e')));
      }
    }
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
    return Scaffold(
      appBar: AppBar(title: const Text('เลือกสถานที่')),
      body: _isWindows
          ? (_winCtl == null
              ? const Center(child: CircularProgressIndicator())
              : wwin.Webview(_winCtl!))
          : wf.WebViewWidget(controller: _mobCtl),
    );
  }
}
