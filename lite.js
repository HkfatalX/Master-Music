/* Cliente mínimo do Supabase (Auth + PostgREST) sem biblioteca externa. */
(function () {
  function create(url, key) {
    const KEY = 'mm_session_v1';
    let session = null; const subs = [];
    try { session = JSON.parse(localStorage.getItem(KEY) || 'null'); } catch (e) { session = null; }
    const save = (s) => { session = s; try { s ? localStorage.setItem(KEY, JSON.stringify(s)) : localStorage.removeItem(KEY); } catch (e) {} };
    const emit = (ev) => subs.forEach((f) => { try { f(ev, session); } catch (e) {} });
    const norm = (j) => j && j.access_token ? { access_token: j.access_token, refresh_token: j.refresh_token, expires_at: Math.floor(Date.now() / 1000) + (j.expires_in || 3600), user: j.user } : null;
    const msg = (j, r) => (j && (j.msg || j.error_description || j.message || j.error)) || ('Erro ' + r.status);
    async function authReq(path, body, token) {
      const h = { apikey: key, 'Content-Type': 'application/json' }; if (token) h.Authorization = 'Bearer ' + token;
      let r; try { r = await fetch(url + '/auth/v1' + path, { method: 'POST', headers: h, body: JSON.stringify(body || {}) }); } catch (e) { return { data: null, error: new Error('network fetch failed') }; }
      let j = null; try { j = await r.json(); } catch (e) {}
      if (!r.ok) return { data: null, error: new Error(msg(j, r)) };
      return { data: j, error: null };
    }
    async function fresh() {
      if (!session) return null;
      if (session.expires_at - 60 > Date.now() / 1000) return session.access_token;
      const { data, error } = await authReq('/token?grant_type=refresh_token', { refresh_token: session.refresh_token });
      if (error || !norm(data)) { if (error && /network/.test(error.message)) return session.access_token; save(null); emit('SIGNED_OUT'); return null; }
      save(norm(data)); emit('TOKEN_REFRESHED'); return session.access_token;
    }
    const auth = {
      async getSession() { await fresh(); return { data: { session }, error: null }; },
      onAuthStateChange(f) { subs.push(f); return { data: { subscription: { unsubscribe() { const i = subs.indexOf(f); if (i >= 0) subs.splice(i, 1); } } } }; },
      async signInWithPassword({ email, password }) {
        const { data, error } = await authReq('/token?grant_type=password', { email, password });
        if (error) return { data: null, error };
        save(norm(data)); emit('SIGNED_IN'); return { data: { session, user: session.user }, error: null };
      },
      async signUp({ email, password }) {
        const { data, error } = await authReq('/signup', { email, password });
        if (error) return { data: null, error };
        if (data && data.access_token) { save(norm(data)); emit('SIGNED_IN'); return { data: { session, user: session.user }, error: null }; }
        return { data: { session: null, user: data }, error: null };
      },
      async signOut() { const t = session && session.access_token; save(null); if (t) authReq('/logout', {}, t); emit('SIGNED_OUT'); return { error: null }; },
    };
    class Q {
      constructor(t) { this.t = t; this.m = 'GET'; this.p = new URLSearchParams(); this.h = {}; this.body = null; this.one = false; this.head = false; }
      select(cols, opt) { if (this.m === 'GET') { this.p.set('select', cols || '*'); if (opt && opt.count) this.h.Prefer = 'count=' + opt.count; if (opt && opt.head) { this.head = true; this.m = 'HEAD'; } } else { this.p.set('select', cols || '*'); this.h.Prefer = (this.h.Prefer || '').replace(/return=\w+/, '') + ',return=representation'; } return this; }
      insert(row) { this.m = 'POST'; this.body = row; this.h.Prefer = 'return=minimal'; return this; }
      upsert(row, o) { this.m = 'POST'; this.body = row; this.h.Prefer = 'resolution=merge-duplicates,return=minimal'; if (o && o.onConflict) this.p.set('on_conflict', o.onConflict); return this; }
      delete() { this.m = 'DELETE'; this.h.Prefer = 'return=minimal'; return this; }
      eq(c, v) { this.p.append(c, 'eq.' + v); return this; }
      order(c, o) { this.p.append('order', c + '.' + (o && o.ascending === false ? 'desc' : 'asc')); return this; }
      limit(n) { this.p.set('limit', n); return this; }
      single() { this.one = true; return this; }
      then(ok, bad) { return this.run().then(ok, bad); }
      async run() {
        const tok = (await fresh()) || key;
        const h = Object.assign({ apikey: key, Authorization: 'Bearer ' + tok }, this.h);
        if (this.m === 'POST') h['Content-Type'] = 'application/json';
        if (this.one) h.Accept = 'application/vnd.pgrst.object+json';
        let r; try { r = await fetch(url + '/rest/v1/' + this.t + (this.p.toString() ? '?' + this.p : ''), { method: this.m, headers: h, body: this.body ? JSON.stringify(this.body) : undefined }); } catch (e) { return { data: null, error: new Error('network fetch failed'), count: null }; }
        let count = null; const cr = r.headers.get('content-range'); if (cr && cr.includes('/')) { const n = parseInt(cr.split('/')[1], 10); if (!isNaN(n)) count = n; }
        if (this.head) return { data: null, error: r.ok ? null : new Error('Erro ' + r.status), count };
        let j = null; const tx = await r.text(); if (tx) { try { j = JSON.parse(tx); } catch (e) {} }
        if (!r.ok) return { data: null, error: new Error((j && j.message) || 'Erro ' + r.status), count };
        return { data: j, error: null, count };
      }
    }
    async function upload(bucket, path, blob, type) {
      const tok = (await fresh()) || key;
      try { const r = await fetch(url + '/storage/v1/object/' + bucket + '/' + path.split('/').map(encodeURIComponent).join('/'), { method: 'POST', headers: { apikey: key, Authorization: 'Bearer ' + tok, 'Content-Type': type || 'application/octet-stream', 'x-upsert': 'false' }, body: blob }); if (!r.ok) { const j = await r.json().catch(() => ({})); return { error: new Error(j.message || 'Erro ' + r.status) }; } return { error: null }; } catch (e) { return { error: new Error('network fetch failed') }; }
    }
    async function remove(bucket, path) {
      const tok = (await fresh()) || key;
      try { await fetch(url + '/storage/v1/object/' + bucket + '/' + path.split('/').map(encodeURIComponent).join('/'), { method: 'DELETE', headers: { apikey: key, Authorization: 'Bearer ' + tok } }); } catch (e) {}
    }
    return { auth, from: (t) => new Q(t), upload, remove };
  }
  window.MMLite = create;
})();
