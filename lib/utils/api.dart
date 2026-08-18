import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/service/service_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String? _currentAccessToken() =>
    Supabase.instance.client.auth.currentSession?.accessToken;

ServiceApi api = ServiceApi(
  dbMacUrl,
  accessTokenProvider: _currentAccessToken,
);
ServiceApi apiSupabase = ServiceApi(
  dbSupabaseUrl,
  accessTokenProvider: _currentAccessToken,
);
SupabaseClient supabase = Supabase.instance.client;
