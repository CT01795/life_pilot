import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/accounting/controller_accounting_list.dart';
import 'package:life_pilot/accounting/model_accounting_account.dart';
import 'package:life_pilot/accounting/service_accounting.dart';
import 'package:life_pilot/apps/controller_page_main.dart';
import 'package:life_pilot/apps/service_module.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/business_plan/controller_business_plan.dart';
import 'package:life_pilot/business_plan/model_plan_template.dart';
import 'package:life_pilot/business_plan/service_business_plan.dart';
import 'package:life_pilot/feedback/controller_feedback_admin.dart';
import 'package:life_pilot/feedback/service_feedback.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/point_record/controller_point_record_list.dart';
import 'package:life_pilot/point_record/model_point_record_account.dart';
import 'package:life_pilot/point_record/service_point_record.dart';
import 'package:life_pilot/utils/enum.dart';

class _Auth extends ControllerAuth {
  @override
  String get currentAccount => 'reader@example.com';
  @override
  bool get isSysAdmin => false;
}

class _Accounting extends ServiceAccounting {
  bool fail = false;
  @override
  Future<List<ModelAccountingAccount>> fetchAccounts({
    required String user,
    String? category,
    int? projectLimit,
    bool includeGraph = true,
  }) async {
    if (fail) throw StateError('offline');
    return [
      ModelAccountingAccount(
        id: 'a',
        accountName: 'Account',
        category: 'personal',
      ),
    ];
  }
}

class _Points extends ServicePointRecord {
  bool fail = false;
  @override
  Future<List<ModelPointRecordAccount>> fetchAccounts({
    required String user,
    String? category,
    int? projectLimit,
    bool includeGraph = true,
  }) async {
    if (fail) throw StateError('offline');
    return [
      ModelPointRecordAccount(
        id: 'p',
        accountName: 'Points',
        category: 'personal',
      ),
    ];
  }
}

class _Modules extends ServiceModule {
  bool fail = false;
  @override
  Future<List<String>> loadModulesFromServer(String account) async {
    if (fail) throw StateError('offline');
    return ['game'];
  }
}

class _Plans extends ServiceBusinessPlan {
  bool fail = false;
  @override
  Future<List<ModelPlanTemplate>> fetchTemplates() async {
    if (fail) throw StateError('offline');
    return [ModelPlanTemplate(id: 't', title: 'Template', description: '')];
  }
}

class _Feedback extends ServiceFeedback {
  bool fail = false;
  @override
  Future<List<dynamic>> loadFeedback({
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    if (fail) throw StateError('offline');
    return [
      {
        'id': 1,
        'subject': 'Existing',
        'content': 'Text',
        'created_at': DateTime.now().toIso8601String(),
      },
    ];
  }

  @override
  Future<bool> hasFeedbackBefore(DateTime before) async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('account reload failure retains cards; retry clears error', () async {
    final service = _Accounting();
    final controller = ControllerAccountingList(
      service: service,
      auth: _Auth(),
    );
    await controller.loadAccounts();
    service.fail = true;
    await controller.loadAccounts();
    expect(controller.accounts.single.id, 'a');
    expect(controller.loadError, isNotNull);
    expect(controller.isLoading, false);
    service.fail = false;
    await controller.loadAccounts();
    expect(controller.loadError, isNull);
    controller.dispose();
  });
  test('point reload failure retains cards', () async {
    final service = _Points();
    final controller = ControllerPointRecordList(
      service: service,
      auth: _Auth(),
    );
    await controller.loadAccounts();
    service.fail = true;
    await controller.loadAccounts();
    expect(controller.accounts.single.id, 'p');
    expect(controller.loadError, isNotNull);
    controller.dispose();
  });
  test('module refresh failure does not erase existing permission', () async {
    final service = _Modules();
    final controller = ControllerPageMain(
      auth: _Auth(),
      serviceModule: service,
      loc: await AppLocalizations.delegate.load(const Locale('en')),
      initialLocale: const Locale('en'),
    );
    await Future<void>.delayed(Duration.zero);
    expect(controller.canAccess(PageType.game), true);
    service.fail = true;
    await controller.refreshModules();
    expect(controller.canAccess(PageType.game), true);
    expect(controller.modulesError, isNotNull);
    service.fail = false;
    await controller.refreshModules();
    expect(controller.modulesError, isNull);
    controller.dispose();
  });
  test('template failure retains templates and clears loading', () async {
    final service = _Plans();
    final controller = ControllerBusinessPlan(service: service, auth: _Auth());
    await controller.loadTemplates();
    service.fail = true;
    await controller.loadTemplates();
    expect(controller.templates.single.id, 't');
    expect(controller.templateLoadError, isNotNull);
    expect(controller.isTemplateLoading, false);
    controller.dispose();
  });
  test('feedback failure retains records', () async {
    final service = _Feedback();
    final controller = ControllerFeedbackAdmin(service, _Auth());
    await controller.loadFeedback();
    service.fail = true;
    await controller.loadFeedback();
    expect(controller.feedbackList.single.id, 1);
    expect(controller.loadError, isNotNull);
    expect(controller.isLoading, false);
    controller.dispose();
  });
}
