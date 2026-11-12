// Runtime-neutral handler: tested with Node; deployed with Deno. No client keys
// or Render URLs are embedded here. User RPCs retain the caller's RLS context.
export class ServiceFailure extends Error {
  constructor(status, code) { super(code); this.status = status; }
}
const fail = (status, code) => { throw new ServiceFailure(status, code); };
const calendars = {
  zh: ['TW', 'zh.taiwan#holiday@group.v.calendar.google.com'],
  en: ['US', 'en.usa#holiday@group.v.calendar.google.com'],
  ja: ['JP', 'ja.japanese#holiday@group.v.calendar.google.com'],
  ko: ['KR', 'ko.south_korea#holiday@group.v.calendar.google.com'],
};
const finite = (n) => typeof n === 'number' && Number.isFinite(n);
const integer = (n, min, max) => Number.isInteger(n) && n >= min && n <= max;
const object = (v) => v !== null && typeof v === 'object' && !Array.isArray(v);
export function publicEventTarget(raw) {
  let url;
  try { url = new URL(raw); } catch { fail(400, 'invalid_public_event_url'); }
  if (url.protocol !== 'https:' || url.hostname !== 'www.taiwan.net.tw' || url.pathname !== '/m1.aspx' ||
      url.username || url.password || (url.port && url.port !== '443') || url.href.length > 4096) {
    fail(403, 'public_event_target_not_allowed');
  }
  return url;
}
// Match the existing database/Python half-to-even coordinate buckets.
export function coordinateBucket(value) {
  const n = value * 1000, floor = Math.floor(n), fraction = n - floor;
  return fraction === .5 ? floor + (floor % 2 === 0 ? 0 : 1) : Math.round(n);
}
async function hash(value) {
  return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value))))
    .map((v) => v.toString(16).padStart(2, '0')).join('');
}
export function temporaryPassword() {
  const groups = ['ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz', '0123456789', '!@#$%'];
  const all = groups.join('');
  function random(max) {
    const value = new Uint8Array(1), cap = 256 - 256 % max;
    do { crypto.getRandomValues(value); } while (value[0] >= cap);
    return value[0] % max;
  }
  const chars = groups.map((g) => g[random(g.length)]);
  while (chars.length < 16) chars.push(all[random(all.length)]);
  for (let i = chars.length - 1; i > 0; i--) { const j = random(i + 1); [chars[i], chars[j]] = [chars[j], chars[i]]; }
  return chars.join('');
}
async function boundedText(response, limit = 4 * 1024 * 1024) {
  if (Number(response.headers.get('content-length')) > limit) fail(413, 'response_too_large');
  if (!response.body) return '';
  const reader = response.body.getReader(), chunks = []; let size = 0;
  try {
    while (true) {
      const { value, done } = await reader.read(); if (done) break;
      size += value.length;
      if (size > limit) { await reader.cancel(); fail(413, 'response_too_large'); }
      chunks.push(value);
    }
  } finally { reader.releaseLock(); }
  const bytes = new Uint8Array(size); let at = 0;
  for (const chunk of chunks) { bytes.set(chunk, at); at += chunk.length; }
  const encoding = /charset\s*=\s*["']?([\w-]+)/i.exec(response.headers.get('content-type') ?? '')?.[1] ?? 'utf-8';
  try { return new TextDecoder(encoding).decode(bytes); } catch { fail(502, 'unsupported_provider_encoding'); }
}

export function createHandler({ env, fetchImpl = fetch, now = Date.now }) {
  function required(name) { const value = env(name)?.trim(); if (!value) fail(503, `missing_${name}`); return value; }
  function limit(name, fallback) {
    const raw = env(name); const value = raw ? Number(raw) : fallback;
    if (!integer(value, 1, 1_000_000)) fail(503, 'invalid_service_budget'); return value;
  }
  const defaultOrigins = ['https://ct01795.github.io'];
  function originAllowed(origin) {
    return !origin || (env('CORS_ALLOWED_ORIGINS')?.split(',').map((s) => s.trim()) ?? defaultOrigins).includes(origin) ||
      /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin);
  }
  async function network(url, options = {}) {
    try { return await fetchImpl(url, { ...options, redirect: 'error', signal: AbortSignal.timeout(12000) }); }
    catch { fail(503, 'upstream_unavailable'); }
  }
  async function jsonFetch(url, options, userAuth = false) {
    const response = await network(url, options);
    const text = await boundedText(response);
    let value; try { value = text ? JSON.parse(text) : null; } catch { fail(502, 'invalid_upstream_json'); }
    if (!response.ok) {
      const code = object(value) ? String(value.message ?? value.code ?? '') : '';
      if (code.includes('rate_limit') || code.includes('daily_service_budget')) fail(429, 'service_rate_limit_exceeded');
      if (userAuth && code.includes('user_not_found')) fail(401, 'user_not_found');
      if (userAuth && response.status === 401 && code === 'user_banned') fail(401, 'user_banned');
      if (userAuth && response.status === 409 && code === 'account_storage_purge_in_progress') {
        fail(409, 'account_storage_purge_in_progress');
      }
      fail(userAuth && response.status === 401 ? 401 : userAuth && response.status === 403 ? 403 : 502, 'upstream_request_rejected');
    }
    return value;
  }
  return async function handle(request) {
    const origin = request.headers.get('origin');
    const cors = originAllowed(origin) ? {
      'Access-Control-Allow-Origin': origin ?? '*', 'Vary': 'Origin',
      'Access-Control-Allow-Headers': 'authorization, apikey, x-client-info, content-type',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
    } : {};
    const respond = (value, status = 200) => new Response(JSON.stringify(value), {
      status, headers: { ...cors, 'Content-Type': 'application/json', 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' },
    });
    try {
      if (!originAllowed(origin)) fail(403, 'origin_not_allowed');
      if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
      if (request.method !== 'POST') fail(405, 'method_not_allowed');
      const authorization = request.headers.get('authorization') ?? '';
      if (!/^Bearer \S+$/.test(authorization)) fail(401, 'authentication_required');
      const base = required('SUPABASE_URL').replace(/\/$/, '');
      const anon = required('SUPABASE_ANON_KEY');
      const user = await jsonFetch(`${base}/auth/v1/user`, { headers: { apikey: anon, Authorization: authorization } }, true);
      if (!object(user) || typeof user.id !== 'string') fail(401, 'user_not_found');
      let envelope; try { envelope = JSON.parse(await boundedText(request, 1024 * 1024)); } catch (e) {
        if (e instanceof ServiceFailure) throw e; fail(400, 'invalid_request_json');
      }
      if (!object(envelope) || !object(envelope.body)) fail(400, 'invalid_request');
      const { route, method = 'POST', body } = envelope;
      if (typeof route !== 'string' || !['GET', 'POST'].includes(method)) fail(400, 'invalid_route');
      const rpc = (name, params = {}, admin = false) => {
        const key = admin ? (env('LIFE_PILOT_SERVICE_ROLE_KEY') || required('SUPABASE_SERVICE_ROLE_KEY')) : anon;
        return jsonFetch(`${base}/rest/v1/rpc/${name}`, { method: 'POST', headers: {
          apikey: key, Authorization: admin ? `Bearer ${key}` : authorization, 'Content-Type': 'application/json',
        }, body: JSON.stringify(params) }, !admin);
      };
      const disabled = await rpc('is_my_life_pilot_account_disabled');
      if (disabled === true) fail(401, 'user_banned');
      if (disabled !== false) fail(502, 'account_status_unavailable');
      let adminCheck;
      const requireAdmin = async () => {
        adminCheck ??= rpc('life_pilot_is_admin');
        if (await adminCheck !== true) fail(403, 'administrator_required');
      };
      const admit = (kind, perUser, perDay) => rpc('life_pilot_edge_admit', {
        p_actor: user.id, p_kind: kind,
        p_user_limit: limit(`EDGE_${kind.toUpperCase()}_USER_LIMIT`, perUser),
        p_daily_limit: limit(`EDGE_${kind.toUpperCase()}_DAILY_LIMIT`, perDay),
      }, true);
      async function cached(kind, key, produce, perUser = 30, perDay = 1000) {
        const lease = await rpc('life_pilot_edge_claim', { p_kind: kind, p_key: key }, true);
        if (lease?.cached === true) return lease.payload;
        if (lease?.claimed !== true || !lease.token) fail(409, 'refresh_in_progress');
        try {
          await admit(kind, perUser, perDay);
          const result = await produce();
          await rpc('life_pilot_edge_finish', { p_kind: kind, p_key: key, p_token: lease.token,
            p_payload: result.payload, p_expires_at: result.expires, p_meta: result.meta ?? {} }, true);
          return result.payload;
        } catch (error) {
          try { await rpc('life_pilot_edge_release', { p_kind: kind, p_key: key, p_token: lease.token }, true); } catch { /* lease expires */ }
          throw error;
        }
      }
      async function geocode(query) {
        if (typeof query !== 'string') fail(400, 'invalid_geocode_query');
        query = query.normalize('NFKC').trim().replace(/\s+/gu, ' ');
        if (!query || query.length > 200) fail(400, 'invalid_geocode_query');
        return cached('geocode', await hash(query.toLowerCase()), async () => {
          const url = new URL('https://api.openweathermap.org/geo/1.0/direct');
          url.search = new URLSearchParams({ q: query, limit: '1', appid: required('OPEN_WEATHER_API_KEY') });
          const data = await jsonFetch(url);
          if (!Array.isArray(data)) fail(502, 'invalid_geocode_response');
          const row = data[0];
          const payload = !row ? {} : finite(row.lat) && finite(row.lon) && Math.abs(row.lat) <= 90 && Math.abs(row.lon) <= 180
            ? { lat: row.lat, lng: row.lon } : fail(502, 'invalid_geocode_response');
          return { payload, expires: new Date(now() + (row ? 180 : 7) * 86400000).toISOString() };
        });
      }
      if (method !== 'POST') fail(405, 'method_not_allowed');
      if (route === 'event/get_public_event_url_data') {
        if ((body.method ?? 'GET') !== 'GET' || body.data_type === 'audio') fail(400, 'public_event_method_not_allowed');
        const url = publicEventTarget(body.url);
        return respond(await cached('public_proxy', await hash(url.href), async () => {
          const response = await network(url, { headers: { 'User-Agent': 'LifePilot/1.0 public event reader' } });
          if (!response.ok) fail(502, 'public_event_provider_unavailable');
          return { payload: { status: 'ok', data: await boundedText(response) }, expires: new Date(now() + 900000).toISOString() };
        }, 60, 32));
      }
      if (route === 'external/geocode') return respond(await geocode(body.query));
      if (route === 'external/geocode-batch') {
        if (!Array.isArray(body.queries) || body.queries.length < 1 || body.queries.length > 25) {
          fail(400, 'invalid_geocode_batch');
        }
        const results = [];
        for (const query of body.queries) {
          try { results.push(await geocode(query)); }
          catch (error) {
            if (error instanceof ServiceFailure && [400, 429, 503].includes(error.status)) throw error;
            results.push({});
          }
        }
        return respond({ results });
      }
      if (route === 'external/map-geocode/backfill') {
        await requireAdmin();
        const offset = body.offset ?? 0, count = body.limit ?? 25;
        if (!['recommended_events', 'recommended_attractions'].includes(body.table_name) || !integer(offset, 0, 100000000) || !integer(count, 1, 25)) fail(400, 'invalid_backfill');
        const rows = await rpc('life_pilot_edge_missing_map_targets', { p_table_name: body.table_name, p_offset: offset, p_limit: count });
        if (!Array.isArray(rows)) fail(502, 'invalid_map_targets');
        const deadline = now() + 18000; let stopped;
        for (const row of rows) {
          if (now() >= deadline) { stopped = 'time_budget'; break; }
          try { await geocode([row.location?.trim(), row.city?.trim(), row.country?.trim() || 'TW'].filter(Boolean).join(', ')); }
          catch (e) { stopped = e instanceof ServiceFailure ? e.message : 'provider_unavailable'; break; }
        }
        const result = await rpc('life_pilot_backfill_cached_map_coordinates', { p_table_name: body.table_name, p_offset: offset, p_limit: count });
        return respond({ ...result, stopped_reason: stopped ?? null });
      }
      if (route === 'external/weather') {
        if (!finite(body.lat) || !finite(body.lng) || Math.abs(body.lat) > 90 || Math.abs(body.lng) > 180) fail(400, 'invalid_coordinates');
        const key = await hash(`${coordinateBucket(body.lat)}:${coordinateBucket(body.lng)}`);
        return respond(await cached('weather', key, async () => {
          const url = new URL('https://api.openweathermap.org/data/2.5/forecast');
          url.search = new URLSearchParams({ lat: String(body.lat), lon: String(body.lng), appid: required('OPEN_WEATHER_API_KEY'), units: 'metric' });
          const data = await jsonFetch(url);
          if (!Array.isArray(data?.list) || !integer(data?.city?.timezone, -64800, 64800)) fail(502, 'invalid_weather_response');
          const items = data.list.map((r) => {
            if (!integer(r.dt, 0, 100000000000) || !object(r.main) || !object(r.weather?.[0])) fail(502, 'invalid_weather_item');
            const result = { date: new Date(r.dt * 1000).toISOString(), main: r.weather[0].main, description: r.weather[0].description, icon: r.weather[0].icon };
            if (![result.main, result.description, result.icon].every((v) => typeof v === 'string')) fail(502, 'invalid_weather_item');
            for (const field of ['temp', 'feels_like', 'temp_min', 'temp_max', 'pressure', 'sea_level', 'grnd_level']) {
              result[field] = r.main[field] ?? (['sea_level', 'grnd_level'].includes(field) ? r.main.pressure : null);
              if (!finite(result[field])) fail(502, 'invalid_weather_item');
            }
            return result;
          });
          const shift = data.city.timezone * 1000;
          const expires = new Date((Math.floor((now() + shift) / 86400000) + 1) * 86400000 - shift).toISOString();
          return { payload: { items, expires_at: expires }, expires };
        }, 300));
      }
      if (route === 'external/holidays') {
        if (typeof body.start !== 'string' || typeof body.end !== 'string') fail(400, 'invalid_holiday_range');
        const calendar = calendars[body.language_code], start = new Date(body.start), end = new Date(body.end);
        if (!calendar || !Number.isFinite(+start) || !Number.isFinite(+end) || end <= start || end - start > 366 * 86400000) fail(400, 'invalid_holiday_range');
        const items = [];
        for (let year = start.getUTCFullYear(); year <= new Date(+end - 1).getUTCFullYear(); year++) {
          if (!integer(year, 1, 9998)) fail(400, 'invalid_holiday_year');
          const result = await cached('holidays', `${calendar[0]}:${year}`, async () => {
            const url = new URL(`https://www.googleapis.com/calendar/v3/calendars/${encodeURIComponent(calendar[1])}/events`);
            url.search = new URLSearchParams({ timeMin: `${year}-01-01T00:00:00Z`, timeMax: `${year + 1}-01-01T00:00:00Z`, orderBy: 'startTime', singleEvents: 'true', maxResults: '2500' });
            const data = await jsonFetch(url, { headers: { 'x-goog-api-key': required('GOOGLE_API_KEY') } });
            if (!Array.isArray(data?.items) || data.nextPageToken) fail(502, 'invalid_holiday_response');
            const rows = [];
            for (const row of data.items) {
              const date = row?.start?.date, summary = typeof row?.summary === 'string' ? row.summary.trim() : '';
              if (typeof date !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(date) || !summary) continue;
              rows.push({ date, summary, source_event_id: typeof row.id === 'string' && row.id ? row.id : `generated_${await hash(`${calendar[0]}|${date}|${summary}`)}` });
            }
            return { payload: { items: rows }, expires: new Date((Math.floor(now() / 86400000) + 1) * 86400000).toISOString(), meta: { country: calendar[0], language: body.language_code, year } };
          }, 20, 32);
          if (!Array.isArray(result?.items)) fail(502, 'invalid_holiday_cache');
          items.push(...result.items.filter((row) => row.date >= body.start.slice(0, 10) && row.date < body.end.slice(0, 10)));
        }
        return respond({ items });
      }
      if (route === 'account/admin/purge-account') {
        await requireAdmin();
        const id = body.request_id;
        if (typeof id !== 'string' || !/^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(id)) {
          fail(400, 'invalid_deletion_request');
        }
        const batch = await rpc('admin_prepare_account_storage_purge', { p_request_id: id });
        if (typeof batch?.token !== 'string' || !Array.isArray(batch.files) || batch.files.length > 100) {
          fail(502, 'invalid_account_storage_purge_batch');
        }
        const buckets = new Map();
        for (const file of batch.files) {
          if (typeof file?.bucket_id !== 'string' || !file.bucket_id || file.bucket_id === '.' ||
              file.bucket_id === '..' || typeof file.name !== 'string' || !file.name) {
            fail(502, 'invalid_account_storage_purge_batch');
          }
          if (!buckets.has(file.bucket_id)) buckets.set(file.bucket_id, []);
          buckets.get(file.bucket_id).push(file.name);
        }
        if (buckets.size) {
          const key = env('LIFE_PILOT_SERVICE_ROLE_KEY') || required('SUPABASE_SERVICE_ROLE_KEY');
          for (const [bucket, paths] of buckets) {
            const removed = await jsonFetch(base + '/storage/v1/object/' + encodeURIComponent(bucket), {
              method: 'DELETE',
              headers: { apikey: key, Authorization: 'Bearer ' + key, 'Content-Type': 'application/json' },
              body: JSON.stringify({ prefixes: paths }),
            });
            if (!Array.isArray(removed)) fail(502, 'account_storage_purge_failed');
          }
        }
        const completed = await rpc('admin_finish_account_storage_purge', {
          p_request_id: id, p_token: batch.token, p_finish: true,
        });
        if (typeof completed !== 'boolean') fail(502, 'invalid_account_storage_purge_result');
        return respond({ completed });
      }
      if (['account/admin/create-user', 'account/admin/reset-password'].includes(route)) {
        await requireAdmin();
        const email = typeof body.email === 'string' ? body.email.trim().toLowerCase() : '';
        if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 254) fail(400, 'invalid_email');
        await admit('account_admin', 30, 1000);
        const existing = await rpc('life_pilot_edge_find_auth_user', { p_email: email }, true);
        if (existing?.disabled === true) fail(403, 'account_disabled');
        const creating = route.endsWith('create-user');
        if (creating && existing?.confirmed === true) fail(409, 'user_already_exists');
        if (!creating && !existing?.id) fail(404, 'account_not_found');
        const password = temporaryPassword(), accountType = body.account_type === 'vendor' ? 'vendor' : 'personal';
        const key = env('LIFE_PILOT_SERVICE_ROLE_KEY') || required('SUPABASE_SERVICE_ROLE_KEY');
        const target = existing?.id ? `/auth/v1/admin/users/${encodeURIComponent(existing.id)}` : '/auth/v1/admin/users';
        await jsonFetch(`${base}${target}`, { method: existing?.id ? 'PUT' : 'POST', headers: { apikey: key, Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' }, body: JSON.stringify({
          password, ...(creating ? { email, email_confirm: true, user_metadata: { account_type: accountType } } : {}),
        }) });
        return respond({ email, temporary_password: password, ...(creating ? { account_type: accountType } : {}) });
      }
      fail(404, 'route_not_found');
    } catch (error) {
      // Never return upstream URLs, keys, JWTs, passwords or raw exception text.
      return respond({ code: error instanceof ServiceFailure ? error.message : 'internal_service_error' },
        error instanceof ServiceFailure ? error.status : 500);
    }
  };
}
