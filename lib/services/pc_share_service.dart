import 'dart:io';

import 'package:mime/mime.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/file_type_utils.dart';
import '../core/utils/format_utils.dart';
import '../models/file_model.dart';
import 'storage_service.dart';

/// Base64 of assets/icon/app_icon.svg, inlined so the served page needs no
/// second request (and works even though the phone isn't hosting any other
/// static assets).
const _appIconSvgBase64 =
    'PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCA2NCA2NCI+CiAgPHJlY3Qgd2lkdGg9IjY0IiBoZWlnaHQ9IjY0IiByeD0iMTYiIGZpbGw9IiMyNTU3RkYiLz4KICA8cGF0aCBkPSJNMTUgMjlhMjQgMjQgMCAwIDEgMzQgME0yMiAzNmExNCAxNCAwIDAgMSAyMCAwIiBmaWxsPSJub25lIiBzdHJva2U9IiNmZmYiIHN0cm9rZS13aWR0aD0iNC41IiBzdHJva2UtbGluZWNhcD0icm91bmQiLz4KICA8Y2lyY2xlIGN4PSIzMiIgY3k9IjQ1IiByPSI0IiBmaWxsPSIjRkZDMjRCIi8+Cjwvc3ZnPgo=';
const _appIconDataUri = 'data:image/svg+xml;base64,$_appIconSvgBase64';

/// Lets a desktop browser on the same Wi-Fi network download files the phone
/// is sharing, and upload files back to it -- all over plain HTTP. No app or
/// account is needed on the PC side, and nothing leaves the local network.
class PcShareService {
  PcShareService(this._storage);

  final StorageService _storage;

  HttpServer? _server;
  final List<FileModel> _sharedFiles = [];

  /// Fires once per file saved from an upload (name, size in bytes). This is
  /// the only truly asynchronous event (an HTTP request arriving on its own
  /// schedule) -- every other state change happens as a direct result of a
  /// provider call, so the provider notifies its own listeners right after
  /// calling start/stop/addFiles/removeFileAt instead of relying on a second
  /// callback that could fire before the provider has finished updating.
  void Function(String fileName, int size)? onFileReceived;

  bool get isRunning => _server != null;
  List<FileModel> get sharedFiles => List.unmodifiable(_sharedFiles);

  void addFiles(List<FileModel> files) {
    if (files.isEmpty) return;
    _sharedFiles.addAll(files);
  }

  void removeFileAt(int index) {
    if (index < 0 || index >= _sharedFiles.length) return;
    _sharedFiles.removeAt(index);
  }

  /// Best-effort local Wi-Fi IPv4 address, so we can show `http://<ip>:port`.
  /// Prefers an interface actually named like Wi-Fi (Android's is `wlan0`)
  /// over VPN/mobile-data interfaces that might also be up.
  Future<String?> primaryLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: false,
      );
      final withAddr = interfaces.where((i) => i.addresses.isNotEmpty).toList();
      if (withAddr.isEmpty) return null;
      final wifi = withAddr.where((i) => i.name.toLowerCase().contains('wlan'));
      final chosen = wifi.isNotEmpty ? wifi.first : withAddr.first;
      return chosen.addresses.first.address;
    } catch (_) {
      return null;
    }
  }

  /// Starts the server and returns the URL to show/scan, or null if there's
  /// no usable Wi-Fi address or the port could not be bound.
  Future<String?> start() async {
    final ip = await primaryLocalIp();
    if (ip == null) return null;
    if (_server != null) return 'http://$ip:${AppConstants.pcSharePort}';
    try {
      final server = await HttpServer.bind(InternetAddress.anyIPv4, AppConstants.pcSharePort, shared: true);
      _server = server;
      server.listen((req) async {
        try {
          await _handle(req);
        } catch (_) {
          try {
            req.response.statusCode = HttpStatus.internalServerError;
            await req.response.close();
          } catch (_) {}
        }
      });
      return 'http://$ip:${AppConstants.pcSharePort}';
    } catch (_) {
      _server = null;
      return null;
    }
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    _sharedFiles.clear();
    if (server != null) {
      await server.close(force: true);
    }
  }

  // ---- routing --------------------------------------------------------

  Future<void> _handle(HttpRequest req) async {
    final path = req.uri.path;
    if (req.method == 'GET' && (path == '/' || path == '/index.html')) {
      await _serveIndex(req);
    } else if (req.method == 'GET' && path.startsWith('/download/')) {
      await _serveDownload(req, path.substring('/download/'.length));
    } else if (req.method == 'POST' && path == '/upload') {
      await _handleUpload(req);
    } else {
      req.response.statusCode = HttpStatus.notFound;
      req.response.write('Not found');
      await req.response.close();
    }
  }

  Future<void> _serveIndex(HttpRequest req) async {
    final uploaded = req.uri.queryParameters['uploaded'];
    final notice = (uploaded != null && uploaded != '0')
        ? '<p class="notice">Sent $uploaded file${uploaded == '1' ? '' : 's'} to the phone &#10003;</p>'
        : '';
    final items = _sharedFiles.isEmpty
        ? '<p class="muted">Nothing shared yet. Add files on the phone.</p>'
        : '<ul>${[
            for (var i = 0; i < _sharedFiles.length; i++)
              '<li><a href="/download/$i">${_escape(_sharedFiles[i].name)}</a>'
                  '<span class="muted"> &middot; ${formatBytes(_sharedFiles[i].size)}</span></li>'
          ].join()}</ul>';

    req.response.headers.contentType = ContentType.html;
    req.response.write('''
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<link rel="icon" type="image/svg+xml" href="$_appIconDataUri">
<title>${AppConstants.appName}</title>
<style>
  body { font-family: -apple-system, "Segoe UI", Roboto, sans-serif; background:#F6F8FC; color:#0F172A;
         max-width:640px; margin:48px auto; padding:0 20px; }
  h1 { font-size:22px; margin-bottom:4px; }
  h2 { font-size:16px; margin:0 0 12px; }
  .brand { display:flex; align-items:center; gap:12px; }
  .brand img { width:40px; height:40px; border-radius:10px; }
  .card { background:#fff; border:1px solid #E2E8F0; border-radius:16px; padding:20px; margin-bottom:20px; }
  ul { list-style:none; padding:0; margin:0; }
  li { padding:10px 0; border-bottom:1px solid #E2E8F0; display:flex; justify-content:space-between; }
  li:last-child { border-bottom:none; }
  a { color:#2563EB; text-decoration:none; font-weight:600; }
  .muted { color:#64748B; font-size:13px; }
  .notice { background:#ECFDF5; color:#047857; padding:10px 14px; border-radius:10px; font-size:14px; }
  button { background:#2563EB; color:#fff; border:none; padding:10px 18px; border-radius:10px;
           font-weight:600; cursor:pointer; margin-top:12px; }
</style>
</head>
<body>
  <div class="brand">
    <img src="$_appIconDataUri" alt="${AppConstants.appName}">
    <h1>${AppConstants.appName}</h1>
  </div>
  <p class="muted">Connected to your phone over Wi-Fi.</p>
  $notice
  <div class="card">
    <h2>Download from phone</h2>
    $items
  </div>
  <div class="card">
    <h2>Send to phone</h2>
    <form method="post" action="/upload" enctype="multipart/form-data">
      <input type="file" name="files" multiple>
      <br>
      <button type="submit">Upload</button>
    </form>
  </div>
</body>
</html>
''');
    await req.response.close();
  }

  Future<void> _serveDownload(HttpRequest req, String idxStr) async {
    final idx = int.tryParse(idxStr);
    if (idx == null || idx < 0 || idx >= _sharedFiles.length) {
      req.response.statusCode = HttpStatus.notFound;
      await req.response.close();
      return;
    }
    final model = _sharedFiles[idx];
    final filePath = model.path;
    if (filePath == null || !await File(filePath).exists()) {
      req.response.statusCode = HttpStatus.gone;
      req.response.write('This file is no longer available on the phone.');
      await req.response.close();
      return;
    }
    final file = File(filePath);
    req.response.headers.set(HttpHeaders.contentTypeHeader, mimeForName(model.name));
    req.response.headers.set(HttpHeaders.contentLengthHeader, (await file.length()).toString());
    req.response.headers.set('Content-Disposition', 'attachment; filename="${_escape(model.name)}"');
    await req.response.addStream(file.openRead());
    await req.response.close();
  }

  Future<void> _handleUpload(HttpRequest req) async {
    final boundary = req.headers.contentType?.parameters['boundary'];
    if (boundary == null) {
      req.response.statusCode = HttpStatus.badRequest;
      req.response.write('Bad upload');
      await req.response.close();
      return;
    }
    var count = 0;
    await for (final part in MimeMultipartTransformer(boundary).bind(req)) {
      final fileName = _fileNameFrom(part.headers['content-disposition'] ?? '');
      if (fileName == null) {
        await part.drain<void>();
        continue;
      }
      final staged = await _storage.stagingPathFor(fileName);
      final sink = File(staged).openWrite();
      var size = 0;
      await for (final chunk in part) {
        size += chunk.length;
        sink.add(chunk);
      }
      await sink.close();
      if (size == 0) {
        try {
          await File(staged).delete();
        } catch (_) {}
        continue; // empty file input left blank in the form; nothing to save
      }
      await _storage.publish(staged, fileName);
      count++;
      onFileReceived?.call(fileName, size);
    }
    req.response.statusCode = HttpStatus.found;
    req.response.headers.set(HttpHeaders.locationHeader, '/?uploaded=$count');
    await req.response.close();
  }

  String? _fileNameFrom(String disposition) {
    final match = RegExp(r'filename="?([^";]*)"?').firstMatch(disposition);
    final raw = match?.group(1)?.trim();
    if (raw == null || raw.isEmpty) return null;
    return sanitizeFileName(raw);
  }

  String _escape(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
}
