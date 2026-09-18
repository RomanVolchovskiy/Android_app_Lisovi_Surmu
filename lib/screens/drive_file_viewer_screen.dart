import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class DriveFileViewerScreen extends StatefulWidget {
  final String url;
  final String title;

  const DriveFileViewerScreen({super.key, required this.url, required this.title});

  @override
  State<DriveFileViewerScreen> createState() => _DriveFileViewerScreenState();
}

class _DriveFileViewerScreenState extends State<DriveFileViewerScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  /// Converts any Google Drive/Docs URL to a direct preview URL.
  String _toPreviewUrl(String url) {
    if (url.isEmpty) return url;

    // Google Docs: /document/d/ID/edit  →  /document/d/ID/preview
    final docsMatch = RegExp(r'docs\.google\.com/document/d/([a-zA-Z0-9_-]+)').firstMatch(url);
    if (docsMatch != null) {
      return 'https://docs.google.com/document/d/${docsMatch.group(1)}/preview';
    }

    // Google Slides: /presentation/d/ID/edit  →  /presentation/d/ID/preview
    final slidesMatch = RegExp(r'docs\.google\.com/presentation/d/([a-zA-Z0-9_-]+)').firstMatch(url);
    if (slidesMatch != null) {
      return 'https://docs.google.com/presentation/d/${slidesMatch.group(1)}/preview';
    }

    // Google Sheets: /spreadsheets/d/ID/edit  →  /spreadsheets/d/ID/htmlview
    final sheetsMatch = RegExp(r'docs\.google\.com/spreadsheets/d/([a-zA-Z0-9_-]+)').firstMatch(url);
    if (sheetsMatch != null) {
      return 'https://docs.google.com/spreadsheets/d/${sheetsMatch.group(1)}/htmlview';
    }

    // Drive file: /file/d/ID/view  →  /file/d/ID/preview
    final fileMatch = RegExp(r'/file/d/([a-zA-Z0-9_-]+)').firstMatch(url);
    if (fileMatch != null) {
      return 'https://drive.google.com/file/d/${fileMatch.group(1)}/preview';
    }

    // Drive open?id=ID
    final uri = Uri.tryParse(url);
    final id = uri?.queryParameters['id'];
    if (id != null) {
      return 'https://drive.google.com/file/d/$id/preview';
    }

    return url;
  }

  @override
  void initState() {
    super.initState();
    final previewUrl = _toPreviewUrl(widget.url);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (_) => setState(() => _loading = false),
        onNavigationRequest: (request) {
          final u = request.url;
          // Allow only Google auth and the file preview itself
          if (u.contains('drive.google.com') ||
              u.contains('docs.google.com') ||
              u.contains('accounts.google.com') ||
              u.contains('google.com/accounts')) {
            return NavigationDecision.navigate;
          }
          return NavigationDecision.prevent;
        },
      ))
      ..loadRequest(Uri.parse(previewUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C3A1C),
      appBar: AppBar(
        title: Text(widget.title, overflow: TextOverflow.ellipsis),
        backgroundColor: const Color(0xFF1C3A1C),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFFD4A017)),
            ),
        ],
      ),
    );
  }
}
