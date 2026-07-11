import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/localization/app_language.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/secure_storage_service.dart';
import '../utils/dio_error_utils.dart';

class NovaSsoWebViewScreen extends StatefulWidget {
  const NovaSsoWebViewScreen({
    super.key,
    required this.authorizationUrl,
    required this.callbackUrl,
    required this.expectedState,
  });

  final String authorizationUrl;
  final String callbackUrl;
  final String expectedState;

  @override
  State<NovaSsoWebViewScreen> createState() => _NovaSsoWebViewScreenState();
}

class _NovaSsoWebViewScreenState extends State<NovaSsoWebViewScreen> {
  WebViewController? _controller;
  final WebViewCookieManager _cookieManager = WebViewCookieManager();
  bool _processing = false;
  bool _loadingPage = true;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  Future<void> _initializeWebView() async {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) {
              setState(() => _loadingPage = false);
            }
          },
          onNavigationRequest: (request) {
            if (request.url.startsWith(widget.callbackUrl)) {
              _handleCallback(request.url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );

    try {
      await _cookieManager.clearCookies();
      await controller.clearCache();
      await controller.clearLocalStorage();
    } catch (_) {}

    await controller.loadRequest(Uri.parse(widget.authorizationUrl));

    if (!mounted) return;
    setState(() {
      _controller = controller;
    });
  }

  Future<void> _handleCallback(String rawUrl) async {
    if (_processing) return;

    final uri = Uri.parse(rawUrl);
    final error = uri.queryParameters["error"]?.trim() ?? "";
    final errorDescription =
        uri.queryParameters["error_description"]?.trim() ?? "";
    final code = uri.queryParameters["code"]?.trim() ?? "";
    final state = uri.queryParameters["state"]?.trim() ?? "";

    setState(() => _processing = true);

    try {
      if (error.isNotEmpty) {
        throw Exception(
          errorDescription.isNotEmpty ? errorDescription : error,
        );
      }

      if (code.isEmpty) {
        throw Exception("Code d'autorisation Nova manquant.");
      }

      if (state.isEmpty || state != widget.expectedState) {
        throw Exception("State PKCE invalide ou expiré.");
      }

      final response = await AuthService.novaSsoLogin(
        code: code,
        state: state,
      );
      final token = response.data["access"]?.toString() ?? "";
      final role =
          response.data["user"]?["role"]?.toString().toUpperCase() ?? "";

      if (token.isEmpty || role.isEmpty) {
        throw Exception("Réponse Nova SSO invalide.");
      }

      await SecureStorageService.saveSession(token: token, role: role);
      await ApiService.setAuthToken();

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DioException catch (error) {
      if (!mounted) return;
      _showMessage(DioErrorUtils.friendlyMessage(error));
      setState(() => _processing = false);
    } catch (error) {
      if (!mounted) return;
      _showMessage(error.toString().replaceFirst("Exception: ", ""));
      setState(() => _processing = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.apartment_rounded),
            const SizedBox(width: 8),
            Text(AppLanguage.t("Connexion Nova SSO", "دخول Nova SSO")),
          ],
        ),
      ),
      body: Stack(
        children: [
          if (_controller != null)
            WebViewWidget(controller: _controller!)
          else
            const Center(child: CircularProgressIndicator()),
          if (_loadingPage && !_processing)
            Container(
              color: Colors.white,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          if (_processing)
            Container(
              color: Colors.black.withValues(alpha: 0.18),
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 14),
                        Text(
                          AppLanguage.t("Connexion en cours...", "جارٍ تسجيل الدخول..."),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
