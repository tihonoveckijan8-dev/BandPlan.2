import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

abstract final class SupabaseBootstrap {
  static bool isInitialized = false;

  static Future<bool> initialize() async {
    if (!AppConfig.hasSupabaseConfig) return false;

    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabasePublishableKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    isInitialized = true;
    return true;
  }
}
