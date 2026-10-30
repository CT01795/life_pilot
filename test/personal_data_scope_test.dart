import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/utils/model_personal_data_scope.dart';

void main() {
  ModelPersonalDataScope scope({
    String? account = 'a@example.com',
    DataStorageLocation? storage = DataStorageLocation.cloud,
    int revision = 3,
  }) => ModelPersonalDataScope(
    account: account,
    storage: storage,
    revision: revision,
  );

  test('normalization keeps equivalent account identities equal', () {
    final a = scope(), b = scope(account: '  A@EXAMPLE.COM  ');
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(b.account, 'a@example.com');
    expect(a, isNot(same(b)));
  });

  for (final field in ['account', 'storage', 'revision']) {
    test('a changed $field invalidates the scope', () {
      final original = scope();
      final changed = switch (field) {
        'account' => scope(account: 'b@example.com'),
        'storage' => scope(storage: DataStorageLocation.local),
        _ => scope(revision: 4),
      };
      expect(changed, isNot(original));
      expect(original.account, 'a@example.com');
      expect(original.storage, DataStorageLocation.cloud);
      expect(original.revision, 3);
    });
  }

  test('missing and blank accounts match the previous normalization rule', () {
    final missing = scope(account: null);
    expect(missing, scope(account: ''));
    expect(missing, scope(account: '   '));
    expect(missing, isNot(scope()));
  });

  test('a missing storage mode is distinct from cloud and local modes', () {
    expect(scope(storage: null), isNot(scope()));
    expect(
      scope(storage: null),
      isNot(scope(storage: DataStorageLocation.local)),
    );
    expect(scope(storage: null), scope(storage: null));
  });

  test('scope is a snapshot rather than a reference to mutable auth state', () {
    var account = 'a@example.com';
    var storage = DataStorageLocation.cloud;
    var revision = 3;
    final before = scope(
      account: account,
      storage: storage,
      revision: revision,
    );
    account = 'b@example.com';
    storage = DataStorageLocation.local;
    revision++;
    final after = scope(account: account, storage: storage, revision: revision);
    expect(before, scope());
    expect(before, isNot(after));
  });

  test('set and map lookups use the complete value identity', () {
    final values = {
      scope(),
      scope(account: ' A@EXAMPLE.COM '),
      scope(revision: 4),
      scope(storage: DataStorageLocation.local),
    };
    expect(values, hasLength(3));
    final cache = {scope(): 'same', scope(revision: 4): 'cleaned'};
    expect(cache[scope(account: 'A@example.com')], 'same');
    expect(cache[scope(revision: 4)], 'cleaned');
    expect(cache[scope(account: 'other@example.com')], isNull);
  });

  test('account text is not interpreted as serialized scope components', () {
    final value = scope(account: ' A|local|7@EXAMPLE.COM ');
    expect(value.account, 'a|local|7@example.com');
    expect(value.storage, DataStorageLocation.cloud);
    expect(value.revision, 3);
    expect(
      value,
      isNot(
        scope(account: 'a', storage: DataStorageLocation.local, revision: 7),
      ),
    );
    final Object serialized = 'a|local|7@example.com|cloud|3';
    expect(value == serialized, isFalse);
  });
}
