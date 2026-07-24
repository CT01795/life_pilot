import 'package:flutter/material.dart';
import 'package:life_pilot/app_initializer.dart';
import 'package:life_pilot/auth/model_auth_view.dart';
import 'package:provider/provider.dart';

class StartupService{
    static Future<void> initialize(
        BuildContext context
    ) async{
      await AppInitializer.init();
      final auth = context.read<ModelAuthView>();
      await auth.initialize();
      await auth.checkLoginStatus();
    }
}
