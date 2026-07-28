import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/service/service_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

ServiceApi api = ServiceApi(dbMacUrl);
ServiceApi apiSupabase = ServiceApi(dbSupabaseUrl);
SupabaseClient supabase = Supabase.instance.client;
