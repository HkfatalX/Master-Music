/* Master Music — site (player web). Mesma conta e mesmos dados do app Android. */
(() => {
'use strict';
const CFG = {
  url: 'https://jpoxxjjmxntwjdmgcypi.supabase.co',
  key: 'sb_publishable__21zkEoebAUtpDQsF-Eizg_fc1YSfbX',
  repo: 'HkfatalX/master-music',
  audius: 'https://api.audius.co/v1',
  app: 'MasterMusic',
};
const sb = window.supabase.createClient(CFG.url, CFG.key, {
  auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true, flowType: 'pkce' },
});
const BASE = (() => {
  const m = location.pathname.match(/^\/[^/]+\//);
  return location.hostname.endsWith('github.io') && m ? m[0] : '/';
})();
const $ = (s) => document.querySelector(s);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const fmt = (s) => { s = Math.max(0, Math.floor(s || 0)); return Math.floor(s / 60) + ':' + String(s % 60).padStart(2, '0'); };
const ic = {
  home: '<svg viewBox="0 0 24 24"><path d="M12 3 3 10.5V21h6v-6h6v6h6V10.5z"/></svg>',
  search: '<svg viewBox="0 0 24 24"><path d="M15.5 14h-.8l-.3-.3A6.5 6.5 0 1 0 14 15.5l.3.3v.8l5 5 1.5-1.5zm-6 0a4.5 4.5 0 1 1 0-9 4.5 4.5 0 0 1 0 9z"/></svg>',
  lib: '<svg viewBox="0 0 24 24"><path d="M4 6h2v14H4zm4-2h2v16H8zm5 1.3 1.9-.6 4.6 14.1-1.9.6z"/></svg>',
  user: '<svg viewBox="0 0 24 24"><path d="M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zm0 2c-3.3 0-8 1.7-8 5v2h16v-2c0-3.3-4.7-5-8-5z"/></svg>',
  dl: '<svg viewBox="0 0 24 24"><path d="M5 20h14v-2H5zM19 9h-4V3H9v6H5l7 7z"/></svg>',
  news: '<svg viewBox="0 0 24 24"><path d="m12 2 2.4 6.6L21 11l-6.6 2.4L12 20l-2.4-6.6L3 11l6.6-2.4z"/></svg>',
  play: '<svg viewBox="0 0 24 24"><path d="M8 5v14l11-7z"/></svg>',
  pause: '<svg viewBox="0 0 24 24"><path d="M6 5h4v14H6zm8 0h4v14h-4z"/></svg>',
  prev: '<svg viewBox="0 0 24 24"><path d="M6 6h2v12H6zm3.5 6 8.5 6V6z"/></svg>',
  next: '<svg viewBox="0 0 24 24"><path d="M6 18l8.5-6L6 6zM16 6h2v12h-2z"/></svg>',
  shuf: '<svg viewBox="0 0 24 24"><path d="M10.6 9.2 5.4 4 4 5.4l5.2 5.2zM14.5 4l2.1 2.1L4 18.6 5.4 20 18 7.4 20 9.5V4zm.3 9.4-1.4 1.4 3.2 3.2-2.1 2.1H20v-5.5l-2.1 2.1z"/></svg>',
  rep: '<svg viewBox="0 0 24 24"><path d="M7 7h10v3l4-4-4-4v3H5v6h2zm10 10H7v-3l-4 4 4 4v-3h12v-6h-2z"/></svg>',
  heart: '<svg viewBox="0 0 24 24"><path d="M12 21.4 10.6 20C5.4 15.4 2 12.3 2 8.5A5.5 5.5 0 0 1 7.5 3c1.7 0 3.4.8 4.5 2.1A6 6 0 0 1 16.5 3 5.5 5.5 0 0 1 22 8.5c0 3.8-3.4 6.9-8.6 11.5z"/></svg>',
  note: '<svg viewBox="0 0 24 24"><path d="M12 3v10.6A4 4 0 1 0 14 17V7h4V3z"/></svg>',
  plus: '<svg viewBox="0 0 24 24"><path d="M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6z"/></svg>',
};
const S = { user: null, favs: new Set(), queue: [], idx: -1, shuffle: false, repeat: 0, pending: null, recovery: false, genre: '', cache: {} };
const audio = $('#audio');

/* ---------- util ---------- */
let toastT;
function toast(msg) { const t = $('#toast'); t.textContent = msg; t.classList.add('on'); clearTimeout(toastT); toastT = setTimeout(() => t.classList.remove('on'), 3200); }
function authError(e) {
  const m = String(e && e.message || e).toLowerCase();
  if (m.includes('invalid login')) return 'E-mail ou senha incorretos.';
  if (m.includes('expired')) return 'Esse código expirou. Toque em reenviar.';
  if (m.includes('invalid') && (m.includes('token') || m.includes('otp') || m.includes('code'))) return 'Código incorreto. Confira e tente de novo.';
  if (m.includes('rate') || m.includes('too many') || m.includes('seconds')) return 'Muitas tentativas ou limite de e-mails atingido. Aguarde um pouco e tente de novo.';
  if (m.includes('already')) return 'Esse e-mail já tem conta. Tente entrar.';
  if (m.includes('weak') || m.includes('password should')) return 'Senha fraca. Use 8+ caracteres.';
  if (m.includes('same password') || m.includes('different from the old')) return 'Escolha uma senha diferente da anterior.';
  if (m.includes('provider') && m.includes('enabled')) return 'Login com Google ainda não foi ativado no servidor.';
  if (m.includes('fetch') || m.includes('network')) return 'Sem conexão com a internet.';
  return 'Algo deu errado. Tente de novo.';
}
const track = (j) => {
  const a = j.artwork || {};
  return { id: String(j.id), title: j.title || 'Sem título', artist: (j.user && j.user.name) || '', art: a['480x480'] || a['1000x1000'] || a['150x150'] || null, dur: j.duration || 0 };
};
const fromRow = (r) => ({ id: r.track_id, title: r.title, artist: r.artist, art: r.artwork_url, dur: r.duration });
const toRow = (t) => ({ track_id: t.id, title: t.title, artist: t.artist, artwork_url: t.art, duration: t.dur });
async function audiusList(path, q) {
  const u = new URL(CFG.audius + path); Object.entries({ ...q, app_name: CFG.app }).forEach(([k, v]) => v && u.searchParams.set(k, v));
  const r = await fetch(u); if (!r.ok) throw new Error('audius ' + r.status);
  const j = await r.json();
  return (j.data || []).filter((x) => x.is_streamable !== false && x.id).map(track);
}
const streamUrl = (id) => `${CFG.audius}/tracks/${encodeURIComponent(id)}/stream?app_name=${CFG.app}`;

/* ---------- auth ---------- */
const A = sb.auth;
async function passwordLogin(email, pass) {
  const { error } = await A.signInWithPassword({ email, password: pass });
  if (error) {
    if (/not confirmed/i.test(error.message)) { await A.resend({ type: 'signup', email }); S.pending = { email, purpose: 'signup' }; return; }
    throw error;
  }
  await A.signOut();
  const r = await A.signInWithOtp({ email, options: { shouldCreateUser: false } }); if (r.error) throw r.error;
  S.pending = { email, purpose: 'login' };
}
async function signUp(email, pass) {
  const { data, error } = await A.signUp({ email, password: pass, options: { emailRedirectTo: location.origin + BASE } });
  if (error) throw error;
  if (data.session) { await A.signOut(); const r = await A.signInWithOtp({ email, options: { shouldCreateUser: false } }); if (r.error) throw r.error; S.pending = { email, purpose: 'login' }; }
  else S.pending = { email, purpose: 'signup' };
}
async function forgot(email) { const { error } = await A.resetPasswordForEmail(email); if (error) throw error; S.pending = { email, purpose: 'recovery' }; }
async function verifyCode(code) {
  const { email, purpose } = S.pending;
  const type = purpose === 'login' ? 'email' : purpose;
  if (purpose === 'recovery') S.recovery = true;
  const { error } = await A.verifyOtp({ email, token: code, type });
  if (error) { if (purpose === 'recovery') S.recovery = false; throw error; }
  S.pending = null;
}
async function resendCode() {
  const { email, purpose } = S.pending; let r;
  if (purpose === 'login') r = await A.signInWithOtp({ email, options: { shouldCreateUser: false } });
  else if (purpose === 'signup') r = await A.resend({ type: 'signup', email });
  else r = await A.resetPasswordForEmail(email);
  if (r.error) throw r.error;
}
async function googleLogin() {
  sessionStorage.setItem('mm_oauth', 'login');
  const { error } = await A.signInWithOAuth({ provider: 'google', options: { redirectTo: location.origin + BASE } });
  if (error) { sessionStorage.removeItem('mm_oauth'); throw error; }
}
async function handleOAuthReturn() {
  if (!sessionStorage.getItem('mm_oauth')) return;
  const { data } = await A.getSession(); const s = data.session; if (!s) return;
  sessionStorage.removeItem('mm_oauth');
  const email = s.user.email; if (!email) return;
  await A.signOut();
  const r = await A.signInWithOtp({ email, options: { shouldCreateUser: false } });
  if (r.error) { toast(authError(r.error)); return; }
  S.pending = { email, purpose: 'login' }; go('/codigo', true);
}

/* ---------- library (Supabase) ---------- */
async function loadFavs() { const { data } = await sb.from('mm_favorites').select('track_id'); S.favs = new Set((data || []).map((r) => r.track_id)); }
async function toggleFav(t) {
  const has = S.favs.has(t.id);
  if (has) S.favs.delete(t.id); else S.favs.add(t.id);
  syncHearts();
  const q = has ? sb.from('mm_favorites').delete().eq('track_id', t.id) : sb.from('mm_favorites').upsert(toRow(t));
  const { error } = await q;
  if (error) { if (has) S.favs.add(t.id); else S.favs.delete(t.id); syncHearts(); toast('Não foi possível salvar.'); }
}
function syncHearts() { document.querySelectorAll('[data-fav]').forEach((b) => b.classList.toggle('on', S.favs.has(b.dataset.fav))); }
async function addHistory(t) { await sb.from('mm_history').insert(toRow(t)); }
const dbList = async (table, extra) => { let q = sb.from(table).select(); q = extra ? extra(q) : q; const { data, error } = await q; if (error) throw error; return data || []; };

/* ---------- player ---------- */
function curTrack() { return S.queue[S.idx] || null; }
function playQueue(list, i) {
  S.queue = list.slice(); S.idx = i; load(true);
}
function load(autoplay) {
  const t = curTrack(); if (!t) return;
  audio.src = streamUrl(t.id);
  if (autoplay) audio.play().catch(() => toast('Não foi possível tocar essa faixa.'));
  addHistory(t);
  if ('mediaSession' in navigator) {
    navigator.mediaSession.metadata = new MediaMetadata({ title: t.title, artist: t.artist, artwork: t.art ? [{ src: t.art, sizes: '480x480' }] : [] });
    navigator.mediaSession.setActionHandler('previoustrack', prev);
    navigator.mediaSession.setActionHandler('nexttrack', next);
  }
  renderPlayer(); markCurrent();
}
function next(auto) {
  if (!S.queue.length) return;
  if (auto && S.repeat === 2) { audio.currentTime = 0; audio.play(); return; }
  if (S.shuffle && S.queue.length > 1) { let n; do { n = Math.floor(Math.random() * S.queue.length); } while (n === S.idx); S.idx = n; }
  else if (S.idx + 1 < S.queue.length) S.idx++;
  else if (S.repeat === 1 || !auto) S.idx = 0;
  else { audio.pause(); return; }
  load(true);
}
function prev() { if (audio.currentTime > 3) { audio.currentTime = 0; return; } S.idx = (S.idx - 1 + S.queue.length) % S.queue.length; load(true); }
function toggle() { if (!curTrack()) return; audio.paused ? audio.play() : audio.pause(); }
audio.addEventListener('ended', () => next(true));
audio.addEventListener('error', () => { if (curTrack()) toast('Não foi possível tocar essa faixa.'); });
audio.addEventListener('play', syncPlayBtn); audio.addEventListener('pause', syncPlayBtn);
audio.addEventListener('timeupdate', () => {
  const s = $('#seek'); if (!s || s.dataset.drag) return;
  const d = audio.duration || (curTrack() && curTrack().dur) || 0;
  s.max = d || 1; s.value = audio.currentTime;
  const a = $('#tcur'); if (a) a.textContent = fmt(audio.currentTime);
  const b = $('#tdur'); if (b) b.textContent = fmt(d);
  syncLyrics();
});
function syncPlayBtn() { const b = $('#pp'); if (b) b.innerHTML = audio.paused ? ic.play : ic.pause; }
function markCurrent() { const t = curTrack(); document.querySelectorAll('.row').forEach((r) => r.classList.toggle('cur', !!t && r.dataset.id === t.id)); }
function renderPlayer() {
  const p = $('#player'); const t = curTrack();
  if (!t) { p.hidden = true; return; }
  p.hidden = false;
  p.innerHTML = `
  <div class="pi" data-go="/tocando" style="cursor:pointer">${t.art ? `<img src="${esc(t.art)}" alt="">` : `<div class="ph">${ic.note}</div>`}<div style="min-width:0"><b>${esc(t.title)}</b><span class="muted small">${esc(t.artist)}</span></div></div>
  <div class="pc"><div class="pb">
    <button class="ib hm ${S.shuffle ? 'on' : ''}" data-act="shuffle" aria-label="Aleatório">${ic.shuf}</button>
    <button class="ib" data-act="prev" aria-label="Anterior">${ic.prev}</button>
    <button class="play" id="pp" data-act="toggle" aria-label="Tocar/Pausar">${audio.paused ? ic.play : ic.pause}</button>
    <button class="ib" data-act="next" aria-label="Próxima">${ic.next}</button>
    <button class="ib hm ${S.repeat ? 'on' : ''}" data-act="repeat" aria-label="Repetir">${ic.rep}</button></div>
    <div class="seek"><span id="tcur">0:00</span><input id="seek" type="range" min="0" max="${t.dur || 1}" value="0" step="0.1" aria-label="Posição"><span id="tdur">${fmt(t.dur)}</span></div></div>
  <div class="pr"><button class="ib ${S.favs.has(t.id) ? 'on' : ''}" data-fav="${esc(t.id)}" data-act="fav" aria-label="Favoritar">${ic.heart}</button>
    <input id="vol" type="range" min="0" max="1" step="0.01" value="${audio.volume}" aria-label="Volume"></div>`;
  const s = $('#seek');
  s.addEventListener('input', () => { s.dataset.drag = '1'; $('#tcur').textContent = fmt(s.value); });
  s.addEventListener('change', () => { audio.currentTime = Number(s.value); delete s.dataset.drag; });
  $('#vol').addEventListener('input', (e) => { audio.volume = Number(e.target.value); });
}

/* ---------- views ---------- */
const row = (t, list, i) => `<div class="row" data-play="${i}" data-list="${list}" data-id="${esc(t.id)}">
  ${t.art ? `<img loading="lazy" src="${esc(t.art)}" alt="">` : `<div class="ph">${ic.note}</div>`}
  <div class="t"><b>${esc(t.title)}</b><span>${esc(t.artist)}${t.dur ? ' • ' + fmt(t.dur) : ''}</span></div>
  <button class="ib ${S.favs.has(t.id) ? 'on' : ''}" data-fav="${esc(t.id)}" data-act="favrow" data-i="${i}" data-list="${list}" aria-label="Favoritar">${ic.heart}</button>
  <button class="ib" data-act="addpl" data-i="${i}" data-list="${list}" aria-label="Adicionar à playlist">${ic.plus}</button></div>`;
const card = (t, list, i) => `<div class="card" data-play="${i}" data-list="${list}">${t.art ? `<img loading="lazy" src="${esc(t.art)}" alt="">` : `<div class="ph">${ic.note}</div>`}<b>${esc(t.title)}</b><span>${esc(t.artist)}</span></div>`;
const skel = (n = 6) => Array.from({ length: n }, () => '<div class="skel"></div>').join('');
const errBox = (m) => `<div class="box center"><p class="muted">${esc(m)}</p><br><button class="btn" data-act="reload">Tentar de novo</button></div>`;
const GENRES = [['Tudo', ''], ['Eletrônica', 'Electronic'], ['Hip-Hop', 'Hip-Hop/Rap'], ['Pop', 'Pop'], ['Rock', 'Rock'], ['Lo-Fi', 'Lo-Fi'], ['Jazz', 'Jazz'], ['Funk', 'Funk'], ['Ambient', 'Ambient']];
const lists = {}; // listas atuais por nome para os cliques

async function vHome(v) {
  const hour = new Date().getHours();
  const hi = hour < 5 ? 'Boa madrugada' : hour < 12 ? 'Bom dia' : hour < 18 ? 'Boa tarde' : 'Boa noite';
  v.innerHTML = `<p class="muted">${hi}, ${esc((S.user.email || '').split('@')[0])}</p><h1>Em alta agora</h1>
  <div class="chips">${GENRES.map(([n, g]) => `<a class="chip ${S.genre === g ? 'on' : ''}" data-genre="${esc(g)}">${n}</a>`).join('')}</div><div id="hl">${skel()}</div>`;
  try {
    const list = await audiusList('/tracks/trending', { limit: 30, genre: S.genre }); lists.home = list;
    $('#hl').innerHTML = `<div class="hero"><div><h1>Mix do momento</h1><p style="opacity:.8;margin:6px 0 16px">${list.length} faixas em alta, grátis</p>
      <button class="btn white" data-act="playall" data-list="home">▶ Tocar</button> <button class="btn alt" data-act="shuffleall" data-list="home">Aleatório</button></div><img src="img/logo-512.png" alt=""></div>
      <h2>Para você</h2><div class="grid">${list.slice(0, 12).map((t, i) => card(t, 'home', i)).join('')}</div>
      <h2>Mais faixas</h2>${list.map((t, i) => row(t, 'home', i)).join('')}`;
    markCurrent();
  } catch { $('#hl').innerHTML = errBox('Não consegui carregar as músicas. Verifique sua internet.'); }
}
async function vSearch(v) {
  v.innerHTML = `<h1>Buscar</h1><input id="q" class="field" placeholder="Músicas, artistas..." autocomplete="off" value="${esc(new URLSearchParams(location.search).get('q') || '')}"><div id="sr"></div>`;
  const q = $('#q'); let t;
  const run = async () => {
    const val = q.value.trim(); history.replaceState({}, '', BASE + 'buscar' + (val ? '?q=' + encodeURIComponent(val) : ''));
    if (val.length < 2) { $('#sr').innerHTML = `<h2>Explorar</h2><div class="chips" style="flex-wrap:wrap">${['lofi', 'phonk', 'funk', 'eletrônica', 'rap', 'chill', 'rock', 'jazz', 'trap', 'ambient'].map((x) => `<a class="chip" data-q="${x}">${x}</a>`).join('')}</div>`; return; }
    $('#sr').innerHTML = skel(7);
    try { const l = await audiusList('/tracks/search', { query: val, limit: 30 }); lists.search = l; $('#sr').innerHTML = l.length ? l.map((x, i) => row(x, 'search', i)).join('') : '<p class="muted">Nada encontrado.</p>'; markCurrent(); }
    catch { $('#sr').innerHTML = errBox('Falha na busca. Verifique sua internet.'); }
  };
  q.addEventListener('input', () => { clearTimeout(t); t = setTimeout(run, 450); });
  run(); q.focus();
}
async function vLibrary(v, sub) {
  sub = sub || 'favoritos';
  v.innerHTML = `<h1>Sua biblioteca</h1><div class="tabs2">${[['favoritos', 'Favoritos'], ['playlists', 'Playlists'], ['historico', 'Histórico']].map(([k, n]) => `<a href="${BASE}biblioteca/${k}" data-go="/biblioteca/${k}" class="${sub === k ? 'on' : ''}">${n}</a>`).join('')}</div><div id="lb">${skel()}</div>`;
  try {
    if (sub === 'favoritos') {
      const l = (await dbList('mm_favorites', (q) => q.order('created_at', { ascending: false }))).map(fromRow); lists.fav = l;
      $('#lb').innerHTML = l.length ? l.map((t, i) => row(t, 'fav', i)).join('') : '<p class="muted">Toque no coração das músicas para salvar aqui.</p>';
    } else if (sub === 'historico') {
      const seen = new Set(); const l = (await dbList('mm_history', (q) => q.order('played_at', { ascending: false }).limit(80))).map(fromRow).filter((t) => !seen.has(t.id) && seen.add(t.id)); lists.hist = l;
      $('#lb').innerHTML = l.length ? l.map((t, i) => row(t, 'hist', i)).join('') : '<p class="muted">Suas músicas tocadas aparecem aqui.</p>';
    } else {
      const pls = await dbList('mm_playlists', (q) => q.order('created_at', { ascending: false }));
      $('#lb').innerHTML = `<button class="btn" data-act="newpl">+ Nova playlist</button><div style="margin-top:16px">${pls.length ? pls.map((p) => `<a class="row" href="${BASE}playlist/${p.id}" data-go="/playlist/${p.id}"><div class="ph" style="width:52px;height:52px;border-radius:12px;flex:none">${ic.lib}</div><div class="t"><b>${esc(p.name)}</b></div></a>`).join('') : '<p class="muted">Crie sua primeira playlist.</p>'}</div>`;
    }
    markCurrent();
  } catch { $('#lb').innerHTML = errBox('Não foi possível carregar.'); }
}
async function vPlaylist(v, id) {
  v.innerHTML = `<p><a class="link" href="${BASE}biblioteca/playlists" data-go="/biblioteca/playlists">← Playlists</a></p><div id="pl">${skel()}</div>`;
  try {
    const { data: p } = await sb.from('mm_playlists').select().eq('id', id).single();
    const l = (await dbList('mm_playlist_tracks', (q) => q.eq('playlist_id', id).order('position'))).map(fromRow); lists.pl = l;
    $('#pl').innerHTML = `<h1>${esc(p ? p.name : 'Playlist')}</h1><p style="margin:14px 0"><button class="btn" data-act="playall" data-list="pl">▶ Tocar</button> <button class="btn alt" data-act="delpl" data-id="${esc(id)}">Apagar</button></p>${l.length ? l.map((t, i) => row(t, 'pl', i)).join('') : '<p class="muted">Playlist vazia. Use o + das músicas para adicionar.</p>'}`;
    markCurrent();
  } catch { $('#pl').innerHTML = errBox('Playlist não encontrada.'); }
}
function vProfile(v) {
  v.innerHTML = `<h1>Perfil</h1><div class="hero" style="margin-top:16px"><div><p style="opacity:.8">Sua conta</p><h1 style="font-size:22px;word-break:break-all">${esc(S.user.email)}</h1></div><img src="img/logo-512.png" alt=""></div>
  <div class="box" style="margin-top:16px"><p><b>Segurança:</b> <span class="muted">cada entrada pede um código de 6 dígitos enviado ao seu e-mail. Seus dados ficam na sua conta e só você vê.</span></p></div>
  <p style="margin-top:18px"><a class="btn alt" href="${BASE}baixar" data-go="/baixar">Baixar o app Android</a> <a class="btn alt" href="${BASE}novidades" data-go="/novidades">Novidades e versões</a> <button class="btn" data-act="logout">Sair da conta</button></p>`;
}
async function vNow(v) {
  const t = curTrack();
  if (!t) { v.innerHTML = '<h1>Tocando agora</h1><p class="muted" style="margin-top:12px">Nenhuma música tocando. Escolha uma na aba Início ou Buscar.</p>'; return; }
  v.innerHTML = `<div class="now">${t.art ? `<img src="${esc(t.art)}" alt="">` : `<div class="ph">${ic.note}</div>`}<div><h1>${esc(t.title)}</h1><p class="muted" style="margin:4px 0 18px">${esc(t.artist)}</p><h2>Letra</h2><div id="lyr" class="lyr muted">Buscando letra...</div></div></div>`;
  S.lyr = null;
  try {
    const u = new URL('https://lrclib.net/api/get'); u.searchParams.set('track_name', t.title); u.searchParams.set('artist_name', t.artist); if (t.dur) u.searchParams.set('duration', t.dur);
    let r = await fetch(u); let j = r.ok ? await r.json() : null;
    if (!j) { const s = await fetch('https://lrclib.net/api/search?q=' + encodeURIComponent(t.title + ' ' + t.artist)); const a = s.ok ? await s.json() : []; j = a[0] || null; }
    const box = $('#lyr'); if (!box || curTrack() !== t) return;
    if (j && j.syncedLyrics) {
      S.lyr = j.syncedLyrics.split('\n').map((l) => { const m = l.match(/^\[(\d+):(\d+(?:\.\d+)?)\](.*)$/); return m ? { t: +m[1] * 60 + +m[2], s: m[3].trim() } : null; }).filter(Boolean);
      box.className = 'lyr'; box.innerHTML = S.lyr.map((l, i) => `<p data-l="${i}">${esc(l.s || '♪')}</p>`).join('');
    } else if (j && j.plainLyrics) { box.className = 'lyr'; box.innerHTML = `<p style="color:var(--text);font-size:18px;white-space:pre-wrap">${esc(j.plainLyrics)}</p>`; }
    else box.textContent = 'Letra não encontrada para esta faixa.';
  } catch { const b = $('#lyr'); if (b) b.textContent = 'Letra indisponível.'; }
}
function syncLyrics() {
  if (!S.lyr || !$('#lyr')) return;
  let c = 0; for (let i = 0; i < S.lyr.length; i++) if (S.lyr[i].t <= audio.currentTime) c = i;
  const cur = document.querySelector('.lyr p.on'); const n = document.querySelector(`.lyr p[data-l="${c}"]`);
  if (n && n !== cur) { if (cur) cur.classList.remove('on'); n.classList.add('on'); n.scrollIntoView({ block: 'center', behavior: 'smooth' }); }
}
async function vDownload(v) {
  v.innerHTML = `<div class="dl"><div><h1>Master Music para Android</h1><p class="muted" style="margin:12px 0 20px;line-height:1.5">Mesma conta, mesmas playlists e favoritos do site. Instale o APK, entre com seu e-mail e pronto. As atualizações aparecem sozinhas dentro do app.</p><div id="dlb"><div class="skel"></div></div></div><img src="img/logo-512.png" alt="Master Music"></div>
  <h2>Como instalar</h2><ol class="muted" style="line-height:1.9;margin-left:22px"><li>Baixe o arquivo APK pelo botão acima.</li><li>Abra o arquivo e permita "instalar de fontes desconhecidas" se o Android pedir.</li><li>Abra o Master Music e entre com sua conta.</li></ol>`;
  try {
    const r = await fetch(`https://api.github.com/repos/${CFG.repo}/releases/latest`); const j = await r.json();
    const apk = (j.assets || []).find((a) => a.name.endsWith('.apk'));
    $('#dlb').innerHTML = apk ? `<a class="btn" href="${esc(apk.browser_download_url)}">⬇ Baixar v${esc(String(j.tag_name).replace(/^v/, ''))}</a><p class="muted small" style="margin-top:10px">${(apk.size / 1048576).toFixed(0)} MB • Android 7+</p>` : '<p class="muted">Nenhuma versão publicada ainda.</p>';
  } catch { $('#dlb').innerHTML = `<a class="btn" href="https://github.com/${CFG.repo}/releases/latest">Ver versões no GitHub</a>`; }
}
async function vChangelog(v) {
  v.innerHTML = `<h1>Novidades e versões</h1><div id="cl" style="margin-top:16px">${skel(3)}</div>`;
  try {
    const list = await (await fetch(BASE + 'changelog.json?_=' + Date.now())).json();
    const grp = (t, c, a) => (a && a.length ? `<h4><strong class="${c}">${t}</strong></h4><ul>${a.map((x) => `<li>${esc(x)}</li>`).join('')}</ul>` : '');
    $('#cl').innerHTML = list.map((e, i) => `<div class="entry ${i === 0 ? 'cur' : ''}"><span class="tag">v${esc(e.version)}</span> <span class="muted small" style="float:right">${esc(e.date)}</span><h3 style="margin-top:12px">${esc(e.title)}</h3>${grp('Adicionado', 'a', e.added)}${grp('Melhorado', 'i', e.improved)}${grp('Corrigido', 'f', e.fixed)}</div>`).join('');
  } catch { $('#cl').innerHTML = errBox('Não foi possível carregar as novidades.'); }
}

/* ---------- auth views ---------- */
const authShell = (inner) => `<div class="auth"><div class="box"><img class="logo" src="img/logo-512.png" alt="Master Music"><h1>Master Music</h1>${inner}</div></div>`;
function vLogin(v, signup) {
  v.innerHTML = authShell(`<p class="muted">${signup ? 'Crie sua conta grátis' : 'Bem-vindo de volta'}</p>
  <form id="af"><input class="field" id="em" type="email" placeholder="E-mail" autocomplete="email" required><input class="field" id="pw" type="password" placeholder="Senha (8+ caracteres)" minlength="8" autocomplete="${signup ? 'new-password' : 'current-password'}" required>
  <p class="err" id="er"></p><button class="btn" id="go">${signup ? 'Criar conta' : 'Entrar'}</button></form>
  <p class="muted small" style="margin:14px 0">ou</p><button class="btn alt" style="width:100%" id="gg"><b style="background:#fff;color:#4285F4;border-radius:50%;width:22px;height:22px;display:inline-grid;place-items:center">G</b> Continuar com Google</button>
  <p style="margin-top:16px">${signup ? `<a class="link" href="${BASE}entrar" data-go="/entrar">Já tenho conta • Entrar</a>` : `<a class="link" href="${BASE}recuperar" data-go="/recuperar">Esqueci minha senha</a><br><br><a class="link" href="${BASE}cadastro" data-go="/cadastro">Não tem conta? Criar agora</a>`}</p>
  <p class="muted small" style="margin-top:14px">Por segurança, enviamos um código de 6 dígitos para o seu e-mail em cada entrada.</p>
  <p class="small" style="margin-top:10px"><a class="link" href="${BASE}baixar" data-go="/baixar">Baixar o app Android</a></p>`);
  $('#af').addEventListener('submit', async (e) => {
    e.preventDefault(); const b = $('#go'); b.disabled = true; $('#er').textContent = '';
    try { await (signup ? signUp : passwordLogin)($('#em').value.trim(), $('#pw').value); go('/codigo'); }
    catch (x) { $('#er').textContent = authError(x); b.disabled = false; }
  });
  $('#gg').addEventListener('click', async () => { try { await googleLogin(); } catch (x) { $('#er').textContent = authError(x); } });
}
function vForgot(v) {
  v.innerHTML = authShell(`<p class="muted">Recuperar senha</p><form id="af"><input class="field" id="em" type="email" placeholder="Seu e-mail" required><p class="err" id="er"></p><button class="btn" id="go">Enviar código</button></form><p style="margin-top:16px"><a class="link" href="${BASE}entrar" data-go="/entrar">← Voltar</a></p>`);
  $('#af').addEventListener('submit', async (e) => { e.preventDefault(); $('#go').disabled = true; try { await forgot($('#em').value.trim()); go('/codigo'); } catch (x) { $('#er').textContent = authError(x); $('#go').disabled = false; } });
}
let cdT;
function vCode(v) {
  const p = S.pending; if (!p) { go('/entrar', true); return; }
  const title = { login: 'Código de segurança', signup: 'Confirme seu e-mail', recovery: 'Recuperar senha' }[p.purpose];
  v.innerHTML = authShell(`<p class="muted"><b style="color:var(--text);font-size:20px">${title}</b><br>Enviamos um código de 6 dígitos para<br>${esc(p.email)}</p>
  <form id="af"><input class="field code" id="cd" inputmode="numeric" autocomplete="one-time-code" maxlength="6" placeholder="••••••"><p class="err" id="er"></p><button class="btn" id="go" disabled>Confirmar</button></form>
  <p style="margin-top:14px"><button class="link" id="rs" disabled>Reenviar em 45s</button></p><p style="margin-top:10px"><a class="link" id="bk" href="${BASE}entrar">← Voltar</a></p>`);
  const cd = $('#cd'); cd.focus();
  let left = 45; clearInterval(cdT);
  const tick = () => { const b = $('#rs'); if (!b) { clearInterval(cdT); return; } if (left > 0) { b.textContent = `Reenviar em ${left}s`; b.disabled = true; left--; } else { b.textContent = 'Reenviar código'; b.disabled = false; clearInterval(cdT); } };
  tick(); cdT = setInterval(tick, 1000);
  const submit = async () => {
    if (cd.value.length < 6) return; $('#go').disabled = true; $('#er').textContent = '';
    try { await verifyCode(cd.value); go(S.recovery ? '/nova-senha' : '/', true); }
    catch (x) { $('#er').textContent = authError(x); cd.value = ''; }
  };
  cd.addEventListener('input', () => { cd.value = cd.value.replace(/\D/g, '').slice(0, 6); $('#go').disabled = cd.value.length < 6; if (cd.value.length === 6) submit(); });
  $('#af').addEventListener('submit', (e) => { e.preventDefault(); submit(); });
  $('#rs').addEventListener('click', async () => { try { await resendCode(); $('#er').className = 'err ok'; $('#er').textContent = 'Novo código enviado! Confira também o spam.'; left = 45; clearInterval(cdT); tick(); cdT = setInterval(tick, 1000); } catch (x) { $('#er').className = 'err'; $('#er').textContent = authError(x); } });
  $('#bk').addEventListener('click', (e) => { e.preventDefault(); S.pending = null; S.recovery = false; go('/entrar'); });
}
function vNewPass(v) {
  v.innerHTML = authShell(`<p class="muted">Criar nova senha</p><form id="af"><input class="field" id="p1" type="password" placeholder="Nova senha (8+)" minlength="8" required><input class="field" id="p2" type="password" placeholder="Repita a senha" minlength="8" required><p class="err" id="er"></p><button class="btn" id="go">Salvar senha</button></form>`);
  $('#af').addEventListener('submit', async (e) => {
    e.preventDefault(); if ($('#p1').value !== $('#p2').value) { $('#er').textContent = 'As senhas não são iguais.'; return; }
    $('#go').disabled = true; const { error } = await A.updateUser({ password: $('#p1').value });
    if (error) { $('#er').textContent = authError(error); $('#go').disabled = false; return; }
    S.recovery = false; toast('Senha alterada com sucesso!'); go('/', true);
  });
}

/* ---------- router ---------- */
const PUBLIC = ['/baixar', '/novidades'];
const AUTHPAGES = ['/entrar', '/cadastro', '/recuperar', '/codigo', '/nova-senha'];
function path() { let p = location.pathname.slice(BASE.length - 1).replace(/\/+$/, ''); return p || '/'; }
function go(p, replace) { const url = BASE + p.replace(/^\//, ''); (replace ? history.replaceState : history.pushState).call(history, {}, '', url); render(); window.scrollTo(0, 0); }
const NAV = [['/', 'Início', 'home'], ['/buscar', 'Buscar', 'search'], ['/biblioteca', 'Biblioteca', 'lib'], ['/perfil', 'Perfil', 'user']];
function chrome(p) {
  const on = (h) => (h === '/' ? p === '/' : p.startsWith(h));
  const links = NAV.map(([h, n, i]) => `<a class="nl ${on(h) ? 'on' : ''}" href="${BASE}${h.slice(1)}" data-go="${h}">${ic[i]}${n}</a>`).join('');
  $('#side').innerHTML = `<div class="brand"><img src="img/logo-192.png" alt="">Master Music</div>${links}<a class="nl ${on('/baixar') ? 'on' : ''}" href="${BASE}baixar" data-go="/baixar">${ic.dl}Baixar app</a><a class="nl ${on('/novidades') ? 'on' : ''}" href="${BASE}novidades" data-go="/novidades">${ic.news}Novidades</a>`;
  $('#tabs').innerHTML = NAV.map(([h, n, i]) => `<a class="${on(h) ? 'on' : ''}" href="${BASE}${h.slice(1)}" data-go="${h}">${ic[i]}${n}</a>`).join('');
}
async function render() {
  const p = path(); const v = $('#view');
  const authPage = AUTHPAGES.includes(p);
  if (S.recovery && S.user && p !== '/nova-senha') return go('/nova-senha', true);
  if (S.pending && p !== '/codigo') return go('/codigo', true);
  if (!S.user && !authPage && !PUBLIC.includes(p)) return go('/entrar', true);
  if (S.user && authPage && p !== '/nova-senha' && p !== '/codigo') return go('/', true);
  const full = authPage || !S.user;
  $('#side').hidden = full; $('#tabs').hidden = full; $('#app').style.display = full && authPage ? 'block' : '';
  $('#main').style.padding = full && authPage ? '0' : '';
  if (!full) chrome(p);
  renderPlayer();
  v.style.animation = 'none'; void v.offsetWidth; v.style.animation = '';
  document.title = 'Master Music';
  if (p === '/entrar') return vLogin(v, false);
  if (p === '/cadastro') return vLogin(v, true);
  if (p === '/recuperar') return vForgot(v);
  if (p === '/codigo') return vCode(v);
  if (p === '/nova-senha') return vNewPass(v);
  if (p === '/baixar') return vDownload(v);
  if (p === '/novidades') return vChangelog(v);
  if (p === '/') return vHome(v);
  if (p === '/buscar') return vSearch(v);
  if (p === '/perfil') return vProfile(v);
  if (p === '/tocando') return vNow(v);
  if (p === '/biblioteca') return go('/biblioteca/favoritos', true);
  let m;
  if ((m = p.match(/^\/biblioteca\/(favoritos|playlists|historico)$/))) return vLibrary(v, m[1]);
  if ((m = p.match(/^\/playlist\/([0-9a-f-]{36})$/))) return vPlaylist(v, m[1]);
  v.innerHTML = `<div class="box center"><h1>Página não encontrada</h1><p><br><a class="btn" href="${BASE}" data-go="/">Voltar ao início</a></p></div>`;
}

/* ---------- eventos ---------- */
const listOf = (el) => lists[el.dataset.list] || [];
document.addEventListener('click', async (e) => {
  const a = e.target.closest('[data-go]');
  if (a && !e.target.closest('[data-act]')) { e.preventDefault(); go(a.dataset.go); return; }
  const g = e.target.closest('[data-genre]'); if (g) { S.genre = g.dataset.genre; render(); return; }
  const q = e.target.closest('[data-q]'); if (q) { history.replaceState({}, '', BASE + 'buscar?q=' + encodeURIComponent(q.dataset.q)); render(); return; }
  const b = e.target.closest('[data-act]');
  if (b) {
    e.stopPropagation(); const act = b.dataset.act; const l = listOf(b); const i = Number(b.dataset.i);
    if (act === 'toggle') toggle(); else if (act === 'next') next(false); else if (act === 'prev') prev();
    else if (act === 'shuffle') { S.shuffle = !S.shuffle; renderPlayer(); }
    else if (act === 'repeat') { S.repeat = (S.repeat + 1) % 3; renderPlayer(); }
    else if (act === 'fav') { const t = curTrack(); if (t) toggleFav(t); }
    else if (act === 'favrow') toggleFav(l[i]);
    else if (act === 'addpl') addToPlaylist(l[i]);
    else if (act === 'playall') playQueue(l, 0);
    else if (act === 'shuffleall') playQueue(l.slice().sort(() => Math.random() - 0.5), 0);
    else if (act === 'reload') render();
    else if (act === 'logout') { await A.signOut(); S.favs = new Set(); S.queue = []; S.idx = -1; audio.pause(); audio.removeAttribute('src'); $('#player').hidden = true; go('/entrar', true); }
    else if (act === 'newpl') { const n = prompt('Nome da playlist'); if (n && n.trim()) { const { error } = await sb.from('mm_playlists').insert({ name: n.trim() }); error ? toast('Não foi possível criar.') : render(); } }
    else if (act === 'delpl') { if (confirm('Apagar playlist?')) { await sb.from('mm_playlists').delete().eq('id', b.dataset.id); go('/biblioteca/playlists'); } }
    return;
  }
  const r = e.target.closest('[data-play]'); if (r) playQueue(listOf(r), Number(r.dataset.play));
});
async function addToPlaylist(t) {
  try {
    const pls = await dbList('mm_playlists', (q) => q.order('created_at', { ascending: false }));
    let id;
    if (!pls.length) { const n = prompt('Você ainda não tem playlists. Nome da nova playlist:'); if (!n || !n.trim()) return; const { data, error } = await sb.from('mm_playlists').insert({ name: n.trim() }).select().single(); if (error) throw error; id = data.id; }
    else { const n = prompt('Adicionar em qual playlist? Digite o número:\n' + pls.map((p, i) => `${i + 1}. ${p.name}`).join('\n') + '\n0. Nova playlist'); if (n === null) return; const k = parseInt(n, 10); if (k === 0) { const nm = prompt('Nome da nova playlist'); if (!nm || !nm.trim()) return; const { data, error } = await sb.from('mm_playlists').insert({ name: nm.trim() }).select().single(); if (error) throw error; id = data.id; } else if (pls[k - 1]) id = pls[k - 1].id; else return; }
    const { count } = await sb.from('mm_playlist_tracks').select('*', { count: 'exact', head: true }).eq('playlist_id', id);
    const { error } = await sb.from('mm_playlist_tracks').upsert({ playlist_id: id, ...toRow(t), position: count || 0 });
    if (error) throw error; toast('Adicionada à playlist!');
  } catch { toast('Não foi possível salvar.'); }
}
document.addEventListener('keydown', (e) => { if (e.code === 'Space' && !/INPUT|TEXTAREA/.test(document.activeElement.tagName)) { e.preventDefault(); toggle(); } });
window.addEventListener('popstate', render);

/* ---------- init ---------- */
(async () => {
  const { data } = await A.getSession();
  S.user = data.session ? data.session.user : null;
  if (S.user) loadFavs();
  A.onAuthStateChange((ev, session) => {
    S.user = session ? session.user : null;
    setTimeout(async () => {
      if (ev === 'PASSWORD_RECOVERY') S.recovery = true;
      if (ev === 'SIGNED_IN') await handleOAuthReturn();
      if (S.user) loadFavs();
      render();
    }, 0);
  });
  await handleOAuthReturn();
  render();
})();
})();
