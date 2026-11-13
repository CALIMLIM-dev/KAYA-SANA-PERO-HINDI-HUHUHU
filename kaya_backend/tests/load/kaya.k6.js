/*
    KAYA load test (k6). Hits the real API with the real payload shapes.

    Run against a LOCAL copy seeded with QaLoadSeeder, never the live site:

        php artisan db:seed --class=QaLoadSeeder          (QA_SEED_SCALE=2000 for volume)
        php artisan serve
        k6 run -e BASE_URL=http://127.0.0.1:8000 -e POST_ID=1 tests/load/kaya.k6.js

    What it measures, and why (QA-AUDIT.md, Step 2):
      - the job feed nearest-first and worker browse (finding 5: these
        ranked every row in PHP before the cap)
      - a flooded post's comments (finding 6)
      - the polling a signed-in phone does (finding 10: one budget per user)

    Sign-in happens once per account in setup(): /login is limited to 20 a
    minute per address and 10 per account (finding 2), and the test is about
    the screens, not about tripping the login limit.
*/
import http from 'k6/http';
import { check, sleep } from 'k6';

const BASE = (__ENV.BASE_URL || 'http://127.0.0.1:8000') + '/api/v1';
const POST_ID = __ENV.POST_ID || '1';
const PASSWORD = 'KayaLoad2026!'; // QaLoadSeeder::PASSWORD
const ACCOUNTS = Number(__ENV.ACCOUNTS || 8);

export const options = {
  scenarios: {
    browse: { executor: 'ramping-vus', startVUs: 0, stages: [
      { duration: '30s', target: 20 }, { duration: '1m', target: 20 }, { duration: '15s', target: 0 },
    ], exec: 'browse' },
    poll: { executor: 'constant-vus', vus: 10, duration: '1m45s', exec: 'poll' },
  },
  thresholds: {
    'http_req_failed{kind:read}': ['rate<0.01'],
    'http_req_duration{name:feed}': ['p(95)<1500'],
    'http_req_duration{name:workers}': ['p(95)<1500'],
    'http_req_duration{name:comments}': ['p(95)<800'],
  },
};

const json = { headers: { 'Content-Type': 'application/json', Accept: 'application/json' } };

export function setup() {
  const tokens = [];
  for (let i = 1; i <= ACCOUNTS; i++) {
    const res = http.post(`${BASE}/login`, JSON.stringify({ email: `worker${i}@load.kaya.test`, password: PASSWORD }), json);
    check(res, { 'login 200': (r) => r.status === 200 });
    if (res.status === 200) tokens.push(res.json('data.token'));
    sleep(3.5); // stays under 20 sign-ins a minute from this address
  }
  if (tokens.length === 0) throw new Error('No seeded account could sign in. Run QaLoadSeeder first.');
  return { tokens };
}

const auth = (token) => ({ headers: { Accept: 'application/json', Authorization: `Bearer ${token}` } });

export function browse(data) {
  const token = data.tokens[__VU % data.tokens.length];
  const read = { tags: { kind: 'read' } };

  const feed = http.get(`${BASE}/jobs?sort=nearest`, { ...auth(token), ...read, tags: { kind: 'read', name: 'feed' } });
  check(feed, { 'feed 200': (r) => r.status === 200 });

  const workers = http.get(`${BASE}/workers?per_page=20`, { ...auth(token), tags: { kind: 'read', name: 'workers' } });
  check(workers, { 'workers 200': (r) => r.status === 200 });

  const comments = http.get(`${BASE}/community/${POST_ID}/comments`, { ...auth(token), tags: { kind: 'read', name: 'comments' } });
  check(comments, {
    'comments 200': (r) => r.status === 200,
    'comments bounded': (r) => r.status !== 200 || r.json('data').length <= 200,
  });

  sleep(1);
}

// What an open chat screen does to the server: notifications every 5s,
// the account every 30s (the app's own intervals).
export function poll(data) {
  const token = data.tokens[__VU % data.tokens.length];
  for (let s = 0; s < 30; s += 5) {
    const n = http.get(`${BASE}/notifications?unread_only=1&per_page=1`, { ...auth(token), tags: { kind: 'read', name: 'unread' } });
    check(n, { 'poll not refused': (r) => r.status !== 429 });
    sleep(5);
  }
  http.get(`${BASE}/me`, { ...auth(token), tags: { kind: 'read', name: 'me' } });
}
