import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/business_plan/controller_business_plan.dart';
import 'package:life_pilot/business_plan/model_plan_template.dart';
import 'package:life_pilot/business_plan/service_business_plan.dart';

ModelPlanTemplate _template(String id) =>
    ModelPlanTemplate(id: id, title: id, description: '');

class _Auth extends ControllerAuth {
  String account = 'a@example.com';
  @override
  String get currentAccount => account;
}

class _Service extends ServiceBusinessPlan {
  final pending = <Completer<List<ModelPlanTemplate>>>[];
  int calls = 0;
  bool failSync = false;
  void Function()? onRead;
  @override
  Future<List<ModelPlanTemplate>> fetchTemplates() {
    calls++;
    onRead?.call();
    if (failSync) throw StateError('sync failure');
    final done = Completer<List<ModelPlanTemplate>>();
    pending.add(done);
    return done.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Auth auth;
  late _Service service;
  late ControllerBusinessPlan c;
  setUp(() {
    auth = _Auth();
    service = _Service();
    c = ControllerBusinessPlan(service: service, auth: auth);
  });
  tearDown(() {
    if (!c.notifierDisposed) c.dispose();
    auth.dispose();
  });

  test(
    'concurrent template callers await the same complete operation',
    () async {
      final first = c.loadTemplates(), joined = c.loadTemplates();
      expect(joined, same(first));
      expect(service.calls, 1);
      var completed = false;
      unawaited(joined.then((_) => completed = true));
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);
      service.pending.single.complete([_template('a')]);
      await first;
      expect(completed, isTrue);
      expect(c.templates.single.id, 'a');
      expect(c.isTemplateLoading, isFalse);
    },
  );
  test(
    'published templates are read-only and isolated from the service list',
    () async {
      final source = [_template('a')];
      final first = c.loadTemplates();
      service.pending.single.complete(source);
      await first;
      source.clear();
      expect(c.templates.single.id, 'a');
      expect(() => c.templates.clear(), throwsUnsupportedError);
    },
  );
  test(
    'failed refresh retains templates and a successful retry clears the error',
    () async {
      final first = c.loadTemplates();
      service.pending.single.complete([_template('old')]);
      await first;
      final refresh = c.loadTemplates();
      service.pending.last.completeError(StateError('offline'));
      await refresh;
      expect(c.templates.single.id, 'old');
      expect(c.templateLoadError, isA<StateError>());
      expect(c.isTemplateLoading, isFalse);
      final retry = c.loadTemplates();
      service.pending.last.complete([_template('new')]);
      await retry;
      expect(c.templates.single.id, 'new');
      expect(c.templateLoadError, isNull);
    },
  );
  test(
    'synchronous service failure releases the request and permits retry',
    () async {
      service.failSync = true;
      await c.loadTemplates();
      expect(c.templateLoadError, isA<StateError>());
      expect(c.isTemplateLoading, isFalse);
      service.failSync = false;
      final retry = c.loadTemplates();
      service.pending.single.complete([]);
      await retry;
      expect(c.templateLoadError, isNull);
    },
  );
  test(
    'account switch during publication prevents unsent template read',
    () async {
      c.addListener(() {
        if (c.isTemplateLoading) {
          auth.account = 'b@example.com';
          c.updateAuth(auth, notify: false);
        }
      });
      await c.loadTemplates();
      expect(service.calls, 0);
      expect(c.templates, isEmpty);
    },
  );
  test('synchronous service reentry joins the registered operation', () async {
    Future<void>? nested;
    service.onRead = () {
      service.onRead = null;
      nested = c.loadTemplates();
    };
    final first = c.loadTemplates();
    expect(nested, same(first));
    expect(service.calls, 1);
    service.pending.single.complete([]);
    await Future.wait([first, nested!]);
  });
  test(
    'old account completion does not clear the new accounts loading state',
    () async {
      final old = c.loadTemplates();
      auth.account = 'b@example.com';
      c.updateAuth(auth);
      final fresh = c.loadTemplates();
      expect(service.calls, 2);
      service.pending.first.complete([_template('old')]);
      await old;
      expect(c.templates, isEmpty);
      expect(c.isTemplateLoading, isTrue);
      service.pending.last.complete([_template('fresh')]);
      await fresh;
      expect(c.templates.single.id, 'fresh');
    },
  );
  test('late failure after disposal cannot alter template state', () async {
    final pending = c.loadTemplates();
    c.dispose();
    service.pending.single.completeError(StateError('late'));
    await pending;
    expect(c.templates, isEmpty);
    expect(c.templateLoadError, isNull);
    await c.loadTemplates();
    expect(service.calls, 1);
  });
  test(
    'same-account auth update preserves the active template operation',
    () async {
      final first = c.loadTemplates();
      c.updateAuth(auth, notify: false);
      expect(c.loadTemplates(), same(first));
      service.pending.single.complete([]);
      await first;
      expect(service.calls, 1);
    },
  );
  test(
    'completed template data does not suppress an explicit later refresh',
    () async {
      final first = c.loadTemplates();
      service.pending.single.complete([]);
      await first;
      final refresh = c.loadTemplates();
      expect(service.calls, 2);
      service.pending.last.complete([_template('new')]);
      await refresh;
      expect(c.templates.single.id, 'new');
    },
  );
}
