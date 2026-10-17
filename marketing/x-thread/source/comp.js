// Ortak bileşenler (slides.html ve film.html): uygulamanın kartları, halkalar, popup, bildirim, ısı haritası
const T = (en, tr) => lang === 'tr' ? tr : en;
const logo = (k, extra = '') => `<svg viewBox="0 0 24 24" ${extra}><path d="${LOGO[k]}"/></svg>`;

// 270° halka (RingGauge): normal mavi, tempo mor, %90+ turuncu-kırmızı
let gid = 0;
function ring(p, tone, size = 50, line = 5.5, txt = true) {
  const r = (size - line) / 2, C = 2 * Math.PI * r, arc = C * .75, v = arc * Math.min(p, 100) / 100, id = 'g' + (gid++);
  const stops = { blue: ['#7fb2ff', '#2f74f0'], purple: ['#a58bff', '#5b3fe0'], red: ['#ff9f0a', '#ff2d20'] }[tone];
  const fs = Math.round(p) >= 100 ? 10.5 : 12.5;
  return `<svg width="${size}" height="${size}" viewBox="0 0 ${size} ${size}"><defs><linearGradient id="${id}" x1="0" y1="1" x2="1" y2="0"><stop offset="0" stop-color="${stops[0]}"/><stop offset="1" stop-color="${stops[1]}"/></linearGradient></defs>
    <circle cx="${size/2}" cy="${size/2}" r="${r}" fill="none" stroke="rgba(0,0,0,.11)" stroke-width="${line}" stroke-linecap="round" stroke-dasharray="${arc} ${C}" transform="rotate(135 ${size/2} ${size/2})"/>
    <circle class="val" data-v="${v}" data-c="${C}" data-p="${p}" cx="${size/2}" cy="${size/2}" r="${r}" fill="none" stroke="url(#${id})" stroke-width="${line}" stroke-linecap="round" stroke-dasharray="${v} ${C}" transform="rotate(135 ${size/2} ${size/2})"/>
    ${txt ? `<text class="pct" data-p="${Math.round(p)}" x="50%" y="52%" text-anchor="middle" dominant-baseline="middle" style="font-size:${fs}px">${Math.round(p)}%</text>` : ''}</svg>`;
}
const gauge = g => `<div class="gauge">${ring(g.p, g.tone)}${g.bell ? `<span class="bell"><svg viewBox="0 0 24 24"><path d="M12 22a2.5 2.5 0 0 0 2.4-2h-4.8a2.5 2.5 0 0 0 2.4 2Zm7-6V11a7 7 0 0 0-5.5-6.8V3.5a1.5 1.5 0 0 0-3 0v.7A7 7 0 0 0 5 11v5l-2 2v1h18v-1Z"/></svg></span>` : ''}<div class="l">${g.l}</div><div class="r">${g.r}</div></div>`;
function card(c) {
  return `<div class="card" ${c.style ? `style="${c.style}"` : ''}><div class="holo"></div><div class="holo b"></div>
    <div class="cl"><div class="ch">${logo(c.logo)}<div><div class="cn">${c.name}</div><div class="cp">${c.plan}</div>${c.badge ? `<span class="badge">${c.badge}</span>` : ''}</div></div>
      ${c.chip ? `<span class="chip ${c.chipKind || ''}">${c.chip}</span>` : ''}
      ${c.chips ? `<div class="chips">${c.chips.map(([t, cls]) => `<span class="${cls || ''}">${t}</span>`).join('')}</div>` : ''}</div>
    <div class="rings">${c.rings.map(gauge).join('')}</div></div>`;
}
const H5 = T('5 hours', '5 saat'), WK = T('Weekly', 'Haftalık');
const tm = (h, m) => T(`${h} h ${m} m`, `${h} sa ${m} dk`), td = (d, h) => T(`${d} d ${h} h`, `${d} g ${h} sa`);
const pace = s => T(`Full in ${s} at this pace`, `Bu hızla ${s} dolar`);
const foot = `<div class="foot"><span class="sp">${T('Updated 17:12', 'Güncellendi 17:12')}</span>
  <span class="gb"><svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M4.2 4.2l2.1 2.1M17.7 17.7l2.1 2.1M2 12h3M19 12h3M4.2 19.8l2.1-2.1M17.7 6.3l2.1-2.1"/></svg>${T('Settings', 'Ayarlar')}</span>
  <span class="gb"><svg viewBox="0 0 24 24"><path d="M20 12a8 8 0 1 1-2.3-5.7M20 4v5h-5"/></svg>${T('Refresh', 'Yenile')}</span>
  <span class="gb"><svg viewBox="0 0 24 24"><path d="M12 3v8M6.3 6.3a8 8 0 1 0 11.4 0"/></svg>${T('Quit', 'Çık')}</span></div>`;
const PERSONAL = T('Personal', 'bireysel'), WORK = T('Work', 'iş');
const claudeHot = { logo: 'claude', name: 'Claude', plan: 'PRO', chip: pace(T('22 min', '22 dakikada')), chipKind: 'hot', chips: [[PERSONAL, 'on'], [WORK]],
  rings: [{ p: 91, tone: 'red', l: H5, r: tm(1, 12) }, { p: 41, tone: 'blue', l: WK, r: td(3, 17) }] };
const codex = { logo: 'openai', name: 'Codex', plan: 'TEAM', chip: pace(T('3 hours', '3 saatte')),
  rings: [{ p: 44, tone: 'purple', l: H5, r: tm(3, 27) }, { p: 23, tone: 'blue', l: WK, r: td(6, 17) }] };
const popup = (cards, cls = '') => `<div class="popup ${cls}">${cards.map(card).join('')}${foot}</div>`;
const miniRings = (o = 64, i = 28, s = 22) => `<svg width="${s}" height="${s}" viewBox="0 0 24 24"><circle cx="12" cy="12" r="9" fill="none" stroke="rgba(0,0,0,.18)" stroke-width="3" stroke-linecap="round" stroke-dasharray="42.4 14.1" transform="rotate(135 12 12)"/><circle cx="12" cy="12" r="9" fill="none" stroke="#e8643c" stroke-width="3" stroke-linecap="round" stroke-dasharray="${42.4*o/100} 56.5" transform="rotate(135 12 12)"/><circle cx="12" cy="12" r="4.4" fill="none" stroke="rgba(0,0,0,.18)" stroke-width="2.4" stroke-linecap="round" stroke-dasharray="20.7 6.9" transform="rotate(135 12 12)"/><circle cx="12" cy="12" r="4.4" fill="none" stroke="#1d1d1f" stroke-width="2.4" stroke-linecap="round" stroke-dasharray="${20.7*i/100} 27.6" transform="rotate(135 12 12)"/></svg>`;
const brand = `<div class="brand">${miniRings(64, 28, 24).replace(/#1d1d1f/g, '#86868b')}AI Limit Tracker</div>`;
const mbar = (extra = '') => `<div class="mbar"><span></span><b>Terminal</b><span>${T('File', 'Dosya')}</span><span>${T('Edit', 'Düzen')}</span><span>${T('View', 'Görüntü')}</span><div class="r">${extra}<span class="sel">${miniRings(87, 44)}</span><span>Wi‑Fi</span><span>${T('Mon 17:12', 'Pzt 17:12')}</span></div></div>`;

function heat(tint) {
  const months = T(['Jul', 'Aug', 'Sep', 'Oct'], ['Tem', 'Ağu', 'Eyl', 'Eki']), days = T(['Mon', '', 'Wed', '', 'Fri', '', ''], ['Pzt', '', 'Çar', '', 'Cum', '', '']);
  const E = dk ? 'rgba(255,255,255,.08)' : 'rgba(0,0,0,.08)';
  const pal = tint === 'orange' ? [E, '#f6c9b5', '#f2a07d', '#ec7a4c', '#e2562a'] : [E, '#cdbcff', '#a68bff', '#7c5cf6', '#5a35e6'];
  let seed = tint === 'orange' ? 7 : 3; const rnd = () => (seed = (seed * 9301 + 49297) % 233280) / 233280;
  let h = [0, 4, 8, 12].map((w, k) => `<span class="m" style="grid-row:1;grid-column:${w + 2} / span 3">${months[k]}</span>`).join('');
  for (let d = 0; d < 7; d++) { h += `<span style="grid-row:${d + 2};grid-column:1">${days[d]}</span>`; for (let w = 0; w < 13; w++) { const x = rnd() * (0.35 + w / 13) * (d > 4 ? .5 : 1); const lv = (w === 12 && d > 1) ? -1 : x < .22 ? 0 : x < .42 ? 1 : x < .6 ? 2 : x < .8 ? 3 : 4; if (lv >= 0) h += `<i style="grid-row:${d + 2};grid-column:${w + 2};background:${pal[lv]}"></i>`; } }
  return { grid: `<div class="hm">${h}</div>`, legend: `<div class="lg">${T('Less', 'Az')} ${pal.map(c => `<i style="background:${c}"></i>`).join('')} ${T('More', 'Çok')}</div>` };
}
function backCard(k, style = '') {
  const hm = heat(k === 'claude' ? 'orange' : 'purple');
  return `<div class="card back" style="${style}"><div class="holo"></div><div class="holo b"></div>
    <div class="top">${logo(k, 'style="width:26px;height:26px;fill:#666"')}<div><div class="cn">${T('Activity', 'Etkinlik')}</div><div class="cp">${k === 'claude' ? 'Claude Code' : 'Codex CLI'} · ${T('last 13 weeks', 'son 13 hafta')}</div></div><span class="usage">↗ ${T('Usage', 'Kullanım')}</span></div>
    ${hm.grid}<div class="bot"><span>${k === 'claude' ? T('2.4M tokens · 38 active days', '2,4M token · 38 aktif gün') : T('4.1M tokens · 41 active days', '4,1M token · 41 aktif gün')}</span>${hm.legend}</div>
    <div class="seg2"><span>${T('Limits', 'Limitler')}</span><span class="on">${T('Activity', 'Etkinlik')}</span></div></div>`;
}

