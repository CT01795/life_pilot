import test from 'node:test';
import assert from 'node:assert/strict';
import { createHandler, publicEventTarget, coordinateBucket, temporaryPassword } from './handler.mjs';

const values = { SUPABASE_URL: 'https://project.supabase.co', SUPABASE_ANON_KEY: 'public-key',
  SUPABASE_SERVICE_ROLE_KEY: 'server-key', OPEN_WEATHER_API_KEY: 'weather-secret', GOOGLE_API_KEY: 'calendar-secret' };
const json = (value, status = 200) => new Response(JSON.stringify(value), { status, headers: { 'content-type': 'application/json' } });
function setup(overrides = {}) {
  const calls = [];
  const fetchImpl = async (raw, options) => {
    const url = new URL(raw), body = options.body ? JSON.parse(options.body) : null;
    calls.push({ url, options, body });
    if (overrides.fetch) { const result = await overrides.fetch(url, options, body); if (result) return result; }
    if (url.pathname === '/auth/v1/user') return json({ id: 'owner', email: 'admin@example.com' });
    if (url.pathname.endsWith('is_my_life_pilot_account_disabled')) return json(overrides.disabled ?? false);
    if (url.pathname.endsWith('life_pilot_is_admin')) return json(overrides.admin ?? true);
    if (url.pathname.endsWith('life_pilot_edge_find_auth_user')) return json(overrides.existing ?? null);
    if (url.pathname.endsWith('life_pilot_edge_claim')) return json(overrides.lease ?? { cached: false, claimed: true, token: 'lease' });
    if (url.pathname.startsWith('/rest/v1/rpc/')) return json(null);
    if (url.pathname.startsWith('/auth/v1/admin/users')) return json({ id: 'target' });
    throw Error(`Unexpected outbound request ${url.origin}${url.pathname}`);
  };
  const handler = createHandler({ env: (key) => values[key], fetchImpl, now: () => Date.UTC(2026, 10, 2, 4) });
  const run = async (route, body = {}, headers = { Authorization: 'Bearer caller' }, method = 'POST') => {
    const response = await handler(new Request('https://project.supabase.co/functions/v1/life-pilot-services', {
      method: 'POST', headers: { 'content-type': 'application/json', ...headers }, body: JSON.stringify({ route, method, body }),
    }));
    return { response, data: await response.json() };
  };
  return { calls, handler, run };
}
test('no bearer token performs no outgoing requests', async () => {
  const s = setup(); const r = await s.run('external/geocode', { query: 'Taipei' }, {});
  assert.equal(r.response.status, 401); assert.equal(s.calls.length, 0);
});
test('untrusted origins cannot reach authentication or providers', async () => {
  const s = setup(); const r = await s.run('external/geocode', {}, { Origin: 'https://evil.example', Authorization: 'Bearer caller' });
  assert.equal(r.response.status, 403); assert.equal(s.calls.length, 0);
});
test('a disabled actor cannot reach even a cached Edge service', async () => {
  const s = setup({ disabled: true, lease: { cached: true, payload: {} } });
  const r = await s.run('external/geocode', { query: 'Taipei' });
  assert.equal(r.response.status, 401);
  assert.equal(r.data.code, 'user_banned');
  assert.equal(s.calls.length, 2);
  assert.equal(s.calls[1].options.headers.Authorization, 'Bearer caller');
});
test('disabled target is not overwritten or treated as a disabled administrator', async () => {
  const s = setup({ existing: { id: 'target', confirmed: false, disabled: true } });
  for (const action of ['create-user', 'reset-password']) {
    const r = await s.run('account/admin/' + action, { email: 'a@example.com' });
    assert.equal(r.response.status, 403);
    assert.equal(r.data.code, 'account_disabled');
  }
  assert.equal(s.calls.some((c) => c.url.pathname.includes('/admin/users')), false);
});
test('account purge deletes only paths returned by the admin RPC before finalizing', async () => {
  const requestId = '00000000-0000-0000-0000-000000000099';
  const s = setup({ fetch: (url, options, body) => {
    if (url.pathname.endsWith('admin_prepare_account_storage_purge')) {
      assert.equal(options.headers.Authorization, 'Bearer caller');
      assert.deepEqual(body, { p_request_id: requestId });
      return json({ token: 'lease', files: [{ bucket_id: 'account-images', name: 'owner/avatar.png' }] });
    }
    if (url.pathname === '/storage/v1/object/account-images') {
      assert.equal(options.method, 'DELETE');
      assert.equal(options.headers.Authorization, 'Bearer server-key');
      assert.deepEqual(body, { prefixes: ['owner/avatar.png'] });
      return json([]);
    }
    if (url.pathname.endsWith('admin_finish_account_storage_purge')) {
      assert.equal(options.headers.Authorization, 'Bearer caller');
      assert.deepEqual(body, { p_request_id: requestId, p_token: 'lease', p_finish: true });
      return json(true);
    }
  } });
  const result = await s.run('account/admin/purge-account', { request_id: requestId, files: ['unrelated.png'] });
  assert.equal(result.response.status, 200);
  assert.deepEqual(result.data, { completed: true });
});
test('account purge does not finalize after a Storage failure', async () => {
  const s = setup({ fetch: (url) => {
    if (url.pathname.endsWith('admin_prepare_account_storage_purge')) {
      return json({ token: 'lease', files: [{ bucket_id: 'account-images', name: 'owner/avatar.png' }] });
    }
    if (url.pathname.startsWith('/storage/')) return json({ message: 'failed' }, 500);
  } });
  const result = await s.run('account/admin/purge-account', { request_id: '00000000-0000-0000-0000-000000000099' });
  assert.equal(result.response.status, 502);
  assert.equal(s.calls.some(c => c.url.pathname.endsWith('admin_finish_account_storage_purge')), false);
});
test('non-admin cannot look up or modify auth users', async () => {
  const s = setup({ admin: false }); const r = await s.run('account/admin/reset-password', { email: 'a@example.com' });
  assert.equal(r.response.status, 403);
  assert.equal(s.calls.some((c) => c.url.pathname.includes('find_auth_user') || c.url.pathname.includes('/admin/users')), false);
});
test('confirmed accounts are never overwritten by account creation', async () => {
  const s = setup({ existing: { id: 'target', confirmed: true } });
  const r = await s.run('account/admin/create-user', { email: 'a@example.com' });
  assert.equal(r.response.status, 409);
  assert.equal(s.calls.some((c) => c.url.pathname.includes('/admin/users')), false);
});
test('pending accounts are approved; no admin role or email is sent automatically', async () => {
  const s = setup({ existing: { id: 'target', confirmed: false } });
  const r = await s.run('account/admin/create-user', { email: ' A@example.com ', account_type: 'vendor' });
  assert.equal(r.response.status, 200);
  const write = s.calls.find((c) => c.url.pathname === '/auth/v1/admin/users/target');
  assert.equal(write.options.method, 'PUT'); assert.equal(write.options.headers.Authorization, 'Bearer server-key');
  assert.equal(write.body.email_confirm, true); assert.deepEqual(write.body.user_metadata, { account_type: 'vendor' });
  assert.equal(write.body.app_metadata, undefined);
  assert.equal(r.response.headers.get('cache-control'), 'no-store');
  assert.equal(r.data.temporary_password.length, 16);
});
test('target account missing is not an actor-session error', async () => {
  const r = await setup().run('account/admin/reset-password', { email: 'a@example.com' });
  assert.equal(r.response.status, 404); assert.equal(r.data.code, 'account_not_found');
});
test('passwords include all required classes and are generated independently', () => {
  const seen = new Set();
  for (let i = 0; i < 100; i++) {
    const value = temporaryPassword(); seen.add(value);
    assert.equal(value.length, 16); for (const pattern of [/[A-Z]/, /[a-z]/, /[0-9]/, /[!@#$%]/]) assert.match(value, pattern);
  }
  assert.equal(seen.size, 100);
});
test('negative shared geocode hit does not call a provider or consume provider budget', async () => {
  const s = setup({ lease: { cached: true, payload: {} } });
  const r = await s.run('external/geocode', { query: 'Taipei' });
  assert.equal(r.response.status, 200); assert.deepEqual(r.data, {});
  assert.equal(s.calls.some((c) => c.url.hostname.includes('openweather') || c.url.pathname.endsWith('edge_admit')), false);
});
test('geocode miss fills shared cache, and never forwards caller credentials to provider', async () => {
  const s = setup({ fetch: (url, options) => {
    if (url.hostname === 'api.openweathermap.org') { assert.equal(options.headers, undefined); return json([{ lat: 25, lon: 121 }]); }
  } });
  const r = await s.run('external/geocode', { query: ' Taipei ' });
  assert.equal(r.response.status, 200); assert.deepEqual(r.data, { lat: 25, lng: 121 });
  const save = s.calls.find((c) => c.url.pathname.endsWith('life_pilot_edge_finish'));
  assert.deepEqual(save.body.p_payload, r.data); assert.equal(save.options.headers.Authorization, 'Bearer server-key');
});
test('provider errors never expose secrets and do not log out the caller', async () => {
  const s = setup({ fetch: (url) => url.hostname === 'api.openweathermap.org' ? json({ message: 'weather-secret' }, 401) : undefined });
  const r = await s.run('external/geocode', { query: 'Taipei' });
  assert.equal(r.response.status, 502); assert.equal(JSON.stringify(r.data).includes('weather-secret'), false);
  assert.ok(s.calls.some((c) => c.url.pathname.endsWith('life_pilot_edge_release')));
});
test('concurrent refresh lease and rate budgets stop upstream calls', async () => {
  const busy = setup({ lease: { claimed: false } });
  assert.equal((await busy.run('external/geocode', { query: 'Taipei' })).response.status, 409);
  const limited = setup({ fetch: (url) => url.pathname.endsWith('edge_admit') ? json({ message: 'daily_service_budget_exceeded' }, 400) : undefined });
  assert.equal((await limited.run('external/geocode', { query: 'Taipei' })).response.status, 429);
  assert.equal(limited.calls.some((c) => c.url.hostname.includes('openweather')), false);
});
test('map backfill remains administrator-only', async () => {
  const s = setup({ admin: false });
  assert.equal((await s.run('external/map-geocode/backfill', { table_name: 'recommended_events' })).response.status, 403);
});
test('public proxy rejects SSRF, credentials, nonstandard ports and stock endpoints', () => {
  for (const url of ['http://www.taiwan.net.tw/m1.aspx', 'https://evil.example/m1.aspx', 'https://user:pass@www.taiwan.net.tw/m1.aspx',
    'https://www.taiwan.net.tw:8443/m1.aspx', 'https://127.0.0.1/m1.aspx', 'https://www.twse.com.tw/exchangeReport/MI_INDEX']) {
    assert.throws(() => publicEventTarget(url));
  }
  assert.equal(publicEventTarget('https://www.taiwan.net.tw/m1.aspx?sNo=0000201').hostname, 'www.taiwan.net.tw');
});
test('unknown/stock routes cannot execute on the non-stock function', async () => {
  assert.equal((await setup().run('stock/update_model')).response.status, 404);
});
test('weather rounding matches database half-to-even including negatives', () => {
  assert.equal(coordinateBucket(.0005), 0); assert.equal(coordinateBucket(.0015), 2);
  assert.equal(coordinateBucket(-.0005), 0); assert.equal(coordinateBucket(-.0015), -2);
});

test('weather validates provider rows and stores expiry at provider-local midnight', async () => {
  const s = setup({ fetch: (url) => url.hostname === 'api.openweathermap.org' ? json({city:{timezone:28800},list:[{
    dt:1793581200, main:{temp:20,feels_like:19,temp_min:18,temp_max:21,pressure:1000},
    weather:[{main:'Clouds',description:'cloudy',icon:'02d'}],
  }]}) : undefined });
  const r=await s.run('external/weather',{lat:25,lng:121});
  assert.equal(r.response.status,200); assert.equal(r.data.items[0].sea_level,1000);
  assert.equal(r.data.expires_at,'2026-11-02T16:00:00.000Z');
  const save=s.calls.find(c=>c.url.pathname.endsWith('life_pilot_edge_finish'));
  assert.equal(save.body.p_payload.items.length,1);
});

test('malformed weather is not cached as a successful empty result', async () => {
  const s=setup({fetch:(url)=>url.hostname==='api.openweathermap.org'?json({list:[{}],city:{timezone:0}}):undefined});
  assert.equal((await s.run('external/weather',{lat:25,lng:121})).response.status,502);
  assert.equal(s.calls.some(c=>c.url.pathname.endsWith('life_pilot_edge_finish')),false);
});

test('holiday refresh requests a whole year and returns only the requested interval', async () => {
  const s=setup({fetch:(url,options)=>{
    if(url.hostname==='www.googleapis.com') {
      assert.equal(options.headers['x-goog-api-key'],'calendar-secret');
      assert.equal(options.headers.Authorization,undefined);
      assert.equal(url.searchParams.get('timeMin'),'2026-01-01T00:00:00Z');
      return json({items:[{id:'h1',start:{date:'2026-01-01'},summary:'New Year'},
        {id:'h2',start:{date:'2026-11-03'},summary:'Holiday'}]});
    }
  }});
  const r=await s.run('external/holidays',{start:'2026-11-01T00:00:00Z',end:'2026-12-01T00:00:00Z',language_code:'en'});
  assert.equal(r.response.status,200); assert.equal(r.data.items.length,1);
  assert.equal(r.data.items[0].date,'2026-11-03');
  const save=s.calls.find(c=>c.url.pathname.endsWith('life_pilot_edge_finish'));
  assert.equal(save.body.p_payload.items.length,2); assert.equal(save.body.p_meta.country,'US');
});

test('incomplete paged holiday response is not cached',async()=>{
  const s=setup({fetch:(url)=>url.hostname==='www.googleapis.com'?json({items:[],nextPageToken:'more'}):undefined});
  assert.equal((await s.run('external/holidays',{start:'2026-01-01',end:'2027-01-01',language_code:'zh'})).response.status,502);
  assert.equal(s.calls.some(c=>c.url.pathname.endsWith('life_pilot_edge_finish')),false);
});

test('failed shared-cache write does not claim a successful refresh',async()=>{
  const s=setup({fetch:(url)=>{
    if(url.hostname==='api.openweathermap.org') return json([]);
    if(url.pathname.endsWith('life_pilot_edge_finish')) return json({message:'database unavailable'},503);
  }});
  assert.equal((await s.run('external/geocode',{query:'Taipei'})).response.status,502);
  assert.equal(s.calls.some(c=>c.url.pathname.endsWith('life_pilot_edge_release')),true);
});

test('target deleted during Auth admin update is not a caller-session failure',async()=>{
  const s=setup({existing:{id:'target',confirmed:true},fetch:(url)=>url.pathname==='/auth/v1/admin/users/target'?json({code:'user_not_found',message:'user_not_found'},404):undefined});
  const r=await s.run('account/admin/reset-password',{email:'a@example.com'});
  assert.equal(r.response.status,502); assert.equal(r.data.code,'upstream_request_rejected');
  assert.equal(r.data.temporary_password,undefined);
});

for (const route of [
  'event/public_events_updated_today',
  'event/start_public_event_refresh',
  'event/complete_public_event_refresh',
  'event/abort_public_event_refresh',
  'event/heartbeat_public_event_refresh',
  'event/cleanup_recommended_events',
  'event/import_public_events',
  'external/map-geocode',
]) {
  test(`retired route cannot call a legacy RPC or provider: ${route}`, async () => {
    const s = setup();
    const result = await s.run(route, { table_name: 'memory_trace', event_id: 'private' });
    assert.equal(result.response.status, 404);
    assert.equal(result.data.code, 'route_not_found');
    assert.deepEqual(s.calls.map(c => c.url.pathname), [
      '/auth/v1/user', '/rest/v1/rpc/is_my_life_pilot_account_disabled',
    ]);
  });
}

test('retired GET status cannot invoke the old database wrapper', async () => {
  const s = setup();
  const result = await s.run('event/public_events_updated_today', {}, undefined, 'GET');
  assert.equal(result.response.status, 405);
  assert.equal(s.calls.length, 2);
});

test('admin batch backfill retains caller targets and cache writeback without the retired helper', async () => {
  const s = setup({ fetch: (url, options, body) => {
    if (url.pathname.endsWith('life_pilot_edge_missing_map_targets')) {
      assert.equal(options.headers.Authorization, 'Bearer caller');
      assert.deepEqual(body, { p_table_name: 'recommended_events', p_offset: 0, p_limit: 5 });
      return json([{ id: 'event', city: 'Taipei', location: 'Station', country: 'TW' }]);
    }
    if (url.hostname === 'api.openweathermap.org') return json([{ lat: 25, lon: 121 }]);
    if (url.pathname.endsWith('life_pilot_backfill_cached_map_coordinates')) {
      assert.equal(options.headers.Authorization, 'Bearer caller');
      return json({ saved: 1, remaining: 0, next_offset: 0 });
    }
  } });
  const result = await s.run('external/map-geocode/backfill', { table_name: 'recommended_events', limit: 5 });
  assert.equal(result.response.status, 200);
  assert.equal(result.data.saved, 1);
  assert.equal(s.calls.some(c => c.url.hostname === 'api.openweathermap.org'), true);
  assert.equal(s.calls.some(c => c.url.pathname.endsWith('life_pilot_edge_map_target')), false);
  assert.equal(s.calls.some(c => c.url.pathname.endsWith('life_pilot_cached_map_coordinates')), false);
});
