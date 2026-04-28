import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OmhcSilenceApp());
}

class OmhcSilenceApp extends StatelessWidget {
  const OmhcSilenceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OmhcSilence WebView',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 2), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const WebViewScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFE94560),
                  width: 3,
                ),
              ),
              child: const Icon(
                Icons.public,
                size: 80,
                color: Color(0xFFE94560),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'OmhcSilence',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Build APK',
              style: TextStyle(
                fontSize: 18,
                color: Color(0xFFE94560),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 50),
            const SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                color: Color(0xFFE94560),
                strokeWidth: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  bool _isOnline = true;
  double _progress = 0;
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  
  // URL will be injected during build
  final String _url = 'WEBVIEW_URL_PLACEHOLDER';

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((ConnectivityResult result) {
      setState(() {
        _isOnline = result != ConnectivityResult.none;
      });
      if (_isOnline && _webViewController != null) {
        _webViewController?.reload();
      }
    });
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isOnline = connectivityResult != ConnectivityResult.none;
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_webViewController != null) {
          final canGoBack = await _webViewController!.canGoBack();
          if (canGoBack) {
            _webViewController!.goBack();
            return false;
          }
        }
        return true;
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // Loading progress bar
              if (_isLoading)
                LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFFE94560),
                  ),
                  minHeight: 3,
                ),
              // WebView
              Expanded(
                child: _isOnline
                    ? InAppWebView(
                        initialUrlRequest: URLRequest(
                          url: WebUri(_url),
                        ),
                        initialSettings: InAppWebViewSettings(
                          javaScriptEnabled: true,
                          domStorageEnabled: true,
                          allowFileAccess: false,
                          allowContentAccess: false,
                          mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                          supportZoom: true,
                          builtInZoomControls: true,
                          displayZoomControls: false,
                          useWideViewPort: true,
                          loadWithOverviewMode: true,
                          allowUniversalAccessFromFileURLs: false,
                          allowFileAccessFromFileURLs: false,
                          mediaPlaybackRequiresUserGesture: false,
                          allowBackgroundAudioPlaying: true,
                          cacheEnabled: true,
                          clearCache: false,
                          hardwareAcceleration: true,
                        ),
                        onWebViewCreated: (controller) {
                          _webViewController = controller;
                        },
                        onLoadStart: (controller, url) {
                          setState(() {
                            _isLoading = true;
                          });
                        },
                        onLoadStop: (controller, url) async {
                          setState(() {
                            _isLoading = false;
                          });
                          // Inject custom CSS/JS if needed
                          await controller.evaluateJavascript(source: """
                            // Remove unwanted elements
                            document.addEventListener('DOMContentLoaded', function() {
                              // Add any custom modifications here
                            });
                          """);
                        },
                        onProgressChanged: (controller, progress) {
                          setState(() {
                            _progress = progress / 100;
                          });
                        },
                        onReceivedError: (controller, request, error) {
                          setState(() {
                            _isLoading = false;
                          });
                        },
                        shouldOverrideUrlLoading: (controller, navigationAction) async {
                          final uri = navigationAction.request.url;
                          
                          // Handle external links
                          if (uri != null && 
                              !uri.toString().startsWith(_url) && 
                              (uri.scheme == 'http' || uri.scheme == 'https')) {
                            // Open in external browser
                            // You can add url_launcher here if needed
                            return NavigationActionPolicy.CANCEL;
                          }
                          return NavigationActionPolicy.ALLOW;
                        },
                      )
                    : _buildNoInternetScreen(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoInternetScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_off,
            size: 100,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 20),
          const Text(
            'No Internet Connection',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Please check your connection',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () {
              _checkConnectivity();
              if (_isOnline && _webViewController != null) {
                _webViewController!.reload();
              }
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE94560),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 30,
                vertical: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
