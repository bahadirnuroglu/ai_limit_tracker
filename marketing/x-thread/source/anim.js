// Tweet videoları: her sahne frame(t) ile t saniyesindeki hâline çizilir (deterministik; snapvid kare kare yakalar).
// Yalnızca tek sahne gösterilirken (#en-tempo gibi) çalışır; statik PNG çıktısı etkilenmez.
(() => {
  if (!only) return;
  const sec = document.querySelector('.slide');
  const id = sec.dataset.id;
  document.body.classList.add('anim');

  const C01 = x => Math.max(0, Math.min(1, x));
  const seg = (t, a, b) => C01((t - a) / (b - a));
  const eo = x => 1 - Math.pow(1 - x, 3);
  const eio = x => x < .5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2;
  const lerp = (a, b, k) => a + (b - a) * k;
  // Uygulamanın yayı (response .42, damping .68)
  function spring(t, response = .42, damping = .68) {
    if (t <= 0) return 0;
    const w = 2 * Math.PI / response, z = damping, wd = w * Math.sqrt(1 - z * z);
    return 1 - Math.exp(-z * w * t) * (Math.cos(wd * t) + z * w / wd * Math.sin(wd * t));
  }
  const $ = q => sec.querySelector(q), $$ = q => [...sec.querySelectorAll(q)];
  const TONES = { blue: ['#7fb2ff', '#2f74f0'], purple: ['#a58bff', '#5b3fe0'], red: ['#ff9f0a', '#ff2d20'] };
  const toneOf = p => p >= 90 ? 'red' : p >= 75 ? 'purple' : 'blue';

  // Halka: p yüzdesi, f dolma oranı (yay)
  function setRing(host, p, f = 1, tone) {
    const val = host.querySelector('.val'), C = +val.dataset.c, v = C * .75 * Math.min(p, 100) / 100 * f;
    val.setAttribute('stroke-dasharray', `${Math.max(.001, v)} ${C}`);
    val.style.opacity = v < .4 ? 0 : 1;
    if (tone) host.querySelectorAll('stop').forEach((s, i) => s.setAttribute('stop-color', TONES[tone][i]));
    const tx = host.querySelector('.pct');
    if (tx) { const n = Math.round(p * Math.min(1, f)); tx.textContent = `${n}%`; tx.style.fontSize = n >= 100 ? '10.5px' : '12.5px'; }
  }
  function setChip(chip, text, kind) {
    if (chip.textContent !== text) chip.textContent = text;
    chip.className = `chip ${kind || ''}`;
  }
  const pulse = (t, at, d = .35) => { const k = seg(t, at, at + d); return k > 0 && k < 1 ? Math.sin(Math.PI * k) : 0; };

  // İmleç ve tık halkası
  sec.insertAdjacentHTML('beforeend', `<svg class="cur" id="cur" viewBox="0 0 24 24"><path d="M5 2.5l14 8.6-6.3 1.4 3.7 6.9-2.8 1.5-3.7-6.9L5 18.6Z" fill="#000" stroke="#fff" stroke-width="1.3" stroke-linejoin="round"/></svg><span class="ripple" id="rip"></span><div id="fadeov" style="position:absolute;inset:0;z-index:60;pointer-events:none;opacity:0"></div>`);
  const cur = $('#cur'), rip = $('#rip'), fadeov = $('#fadeov');
  fadeov.style.background = getComputedStyle(sec).backgroundColor;
  const center = (el, dx = 0, dy = 0) => { const r = el.getBoundingClientRect(); return [r.left + r.width / 2 + dx, r.top + r.height / 2 + dy]; };
  // keys: [[zaman, [x, y]], ...] arası yumuşak geçiş
  function cursor(t, keys, show = [0, 99]) {
    let p = keys[0][1];
    for (let i = 1; i < keys.length; i++) {
      const [ta, pa] = keys[i - 1], [tb, pb] = keys[i];
      if (t >= tb) p = pb; else if (t > ta) { const k = eio((t - ta) / (tb - ta)); p = [lerp(pa[0], pb[0], k), lerp(pa[1], pb[1], k)]; break; }
    }
    const o = seg(t, show[0], show[0] + .2) * (1 - seg(t, show[1], show[1] + .2));
    cur.style.opacity = o; cur.style.transform = `translate(${p[0] - 6}px, ${p[1] - 3}px)`;
    return p;
  }
  function clicks(t, list) {
    rip.style.opacity = 0;
    for (const [at, [x, y]] of list) {
      const k = seg(t, at, at + .45);
      if (k > 0 && k < 1) { rip.style.left = `${x}px`; rip.style.top = `${y}px`; rip.style.opacity = 1 - k; rip.style.transform = `scale(${.35 + .9 * eo(k)})`; }
      if (t >= at && t < at + .12) cur.style.transform += ' scale(.86)';
    }
  }
  // Ortak giriş: başlık satırları sırayla, sahne yayla; sonda zemin rengine sön
  function enter(t, D) {
    $$('.head > *').forEach((c, i) => {
      const k = eo(seg(t, .08 + i * .1, .75 + i * .1));
      c.style.opacity = k; c.style.transform = `translateY(${26 * (1 - k)}px)`; c.style.filter = `blur(${8 * (1 - k)}px)`;
    });
    $$('.art:not(.static-only)').forEach(a => {
      const k = spring(t - .4, .7, .82);
      a.style.opacity = seg(t, .4, .75); a.style.transform = `translateY(${50 * (1 - k)}px) scale(${.95 + .05 * k})`;
    });
    const b = $('.brand'); if (b) b.style.opacity = seg(t, .6, 1);
    fadeov.style.opacity = seg(t, D - .5, D);
  }
  const sway = t => $$('.card').forEach((c, i) => c.querySelectorAll('.holo').forEach((h, k) =>
    h.style.setProperty('--a', `${(k ? 64 : 118) + 24 * Math.sin(2 * Math.PI * (t / 5 + i * .17))}deg`)));
  // Popup açılışı (uygulamadaki gibi): ölçek .88 + bulanıklıktan yay, kartlar sırayla iner, halkalar dolar
  function openPopup(pop, t, t0, tOut = 99) {
    const x = spring(t - t0), out = seg(t, tOut, tOut + .35);
    pop.style.transform = `scale(${.88 + .12 * x - .05 * out})`;
    pop.style.opacity = seg(t, t0, t0 + .18) * (1 - out);
    pop.style.filter = `blur(${Math.max(0, 8 * (1 - Math.min(1, x * 1.4))) + 8 * out}px)`;
    pop.querySelectorAll('.card').forEach((c, i) => {
      const y = spring(t - t0 - .08 - i * .06);
      c.style.transform = `translateY(${-14 * (1 - y)}px)`; c.style.opacity = seg(t, t0 + .08 + i * .06, t0 + .28 + i * .06);
    });
    const f = pop.querySelector('.foot'); if (f) f.style.opacity = seg(t, t0 + .25, t0 + .5);
  }
  const fill = (t, t0) => Math.min(1.03, spring(t - t0, .9, .82));

  const S = {};

  // ---------- 00 Hook (10 sn) ----------
  S.reel = {
    d: 10,
    init() {
      $('#rPop .popup').style.transformOrigin = '50% 0';
      // Popup'ı ikonun altına yerleştir, kamera hedefini (popup + menü çubuğu) ölç
      const ic = center($('#rIcon')), host = $('#rPop'), pw = host.getBoundingClientRect().width;
      host.style.left = `${Math.min(1600 - 24 - pw, ic[0] - pw / 2) / 1.4}px`;
      const r = host.getBoundingClientRect(); this.cam = [r.left + r.width / 2 - 60, r.top + r.height / 2 - 30];
      $('#rDesk').style.transformOrigin = '0 0';
      this.claude = $$('#rPop .card')[0]; this.codex = $$('#rPop .card')[1];
      this.chips = $$('#rPop .chips span');
    },
    f(t) {
      // 1) Acı: kelimeler tek tek, kırmızı hap sarsılarak; sonra uzaklaşır
      const open = $('#rOpen'), outO = eio(seg(t, 1.85, 2.25));
      $$('#rOpen .w').forEach((w, i) => { const k = eo(seg(t, .1 + i * .09, .55 + i * .09)); w.style.opacity = k; w.style.transform = `translateY(${30 * (1 - k)}px)`; w.style.filter = `blur(${12 * (1 - k)}px)`; });
      const pill = $('#rPill'), pk = spring(t - .95, .45, .55);
      pill.style.opacity = seg(t, .95, 1.05); pill.style.transform = `scale(${.6 + .4 * pk}) translateX(${Math.sin(t * 60) * 9 * (1 - seg(t, 1.0, 1.45)) * (t > 1 ? 1 : 0)}px)`;
      open.style.opacity = 1 - outO; open.style.transform = `scale(${1 - .08 * outO})`; open.style.filter = `blur(${10 * outO}px)`;
      open.style.display = outO >= 1 ? 'none' : 'flex';
      // 2) Masaüstü belirir, terminal çalışıyor
      // Kamera: önce geniş plan, ikona tıklanınca popup'a yaklaşır
      const desk = $('#rDesk'), dk = eo(seg(t, 1.85, 2.5)), zk = eio(seg(t, 3.0, 3.9));
      const sc = (1.06 - .06 * dk) * (1 + .62 * zk), [cx, cy] = this.cam;
      const cl = (v, lo) => Math.max(lo, Math.min(0, v));
      const tx = cl(lerp(800 - 800 * sc, 800 - cx * sc, zk), 1600 - 1600 * sc), ty = cl(lerp(450 - 450 * sc, 450 - cy * sc, zk), 900 - 900 * sc);
      desk.style.opacity = dk; desk.style.transform = `translate(${tx}px, ${ty}px) scale(${sc})`;
      $('.term .caret').style.opacity = Math.floor(t * 2.4) % 2 ? .15 : 1;
      // 3) İmleç menü çubuğundaki halkaya gider, tıklar
      const icon = $('#rIcon'), ic = center(icon), pop = $('#rPop .popup'), popHost = $('#rPop');
      const chipW = center(this.chips[1]);
      const p = cursor(t, [[2.3, [980, 640]], [3.0, ic], [3.15, ic], [3.9, [1180, 300]], [5.5, [1180, 300]], [6.1, chipW], [6.9, chipW], [7.5, [1300, 860]]], [2.3, 7.4]);
      clicks(t, [[3.05, ic], [6.15, chipW]]);
      icon.style.background = t > 3.05 && t < 7.2 ? 'rgba(0,0,0,.16)' : 'transparent';
      // 4) Popup açılır, halkalar dolar
      openPopup(pop, t, 3.1, 7.05);
      // 5) Tempo: 5 saat %78 → %93, mor → kırmızı, çip "1 saatte" → "22 dakikada"
      const [g0, g1] = this.claude.querySelectorAll('.gauge'), work = t >= 6.2;
      const climb = eio(seg(t, 4.2, 5.4)), p0 = work ? lerp(93, 8, eio(seg(t, 6.2, 6.7))) : lerp(78, 93, climb);
      const f0 = fill(t, 3.35);
      setRing(g0, p0, f0, work ? 'blue' : toneOf(p0));
      setRing(g1, work ? lerp(41, 12, eio(seg(t, 6.2, 6.7))) : 41, fill(t, 3.43), 'blue');
      const chip = this.claude.querySelector('.chip');
      if (work) setChip(chip, T('Available', 'Kullanılabilir'), 'ok');
      else if (p0 >= 90) setChip(chip, pace(T('22 min', '22 dakikada')), 'hot');
      else if (p0 >= 84) setChip(chip, pace(T('40 min', '40 dakikada')), '');
      else setChip(chip, pace(T('1 hour', '1 saatte')), '');
      chip.style.opacity = seg(t, 3.7, 4.0);
      chip.style.transform = `scale(${1 + .12 * (pulse(t, 5.15, .4) + pulse(t, 6.25, .4))})`;
      this.chips.forEach((c, i) => c.className = (i === (work ? 1 : 0)) ? 'on' : '');
      this.claude.style.boxShadow = `0 0 0 ${3 * pulse(t, 5.1, .8)}px rgba(255,59,48,.55)`;
      const [c0, c1] = this.codex.querySelectorAll('.gauge'); setRing(c0, 44, fill(t, 3.45), 'purple'); setRing(c1, 23, fill(t, 3.53), 'blue');
      const cchip = this.codex.querySelector('.chip'); cchip.style.opacity = seg(t, 3.8, 4.1);
      // 6) Kapandıktan sonra hatırlatma bildirimi sağdan kayar
      const note = $('#rNote .note'), nk = spring(t - 7.4, .55, .78), nOut = seg(t, 8.5, 8.8);
      note.style.transform = `translateX(${(1 - nk) * 520}px)`; note.style.opacity = seg(t, 7.4, 7.6) * (1 - nOut);
      // 7) Kapanış kartı
      const end = $('#rEnd'), ek = eo(seg(t, 8.6, 9.1));
      end.style.opacity = ek * (1 - seg(t, 9.6, 10));
      end.querySelectorAll('img, .h, .sub').forEach((e, i) => { const k = spring(t - 8.7 - i * .1, .6, .8); e.style.transform = `translateY(${30 * (1 - k)}px) scale(${.96 + .04 * k})`; });
      sway(t);
    }
  };

  // ---------- 01 Giriş (6 sn) ----------
  S.hero = {
    d: 6,
    init() { $('#heroPop .popup').style.transformOrigin = '50% 0'; },
    f(t) {
      const pop = $('#heroPop .popup');
      openPopup(pop, t, .3, 5.25);
      $$('#heroPop .card').forEach((c, i) => {
        c.querySelectorAll('.gauge').forEach((g, j) => { const p = +g.querySelector('.val').dataset.p; setRing(g, p, fill(t, .65 + i * .1 + j * .08)); });
        const chip = c.querySelector('.chip'); if (chip) { const v = seg(t, 1.5 + i * .1, 1.8 + i * .1); chip.style.opacity = v; chip.style.transform = `translateY(${4 * (1 - v)}px)`; }
      });
      sway(t);
    }
  };

  // ---------- 03 Tempo (7 sn) ----------
  S.tempo = {
    d: 7,
    init() { this.card = $('.card'); this.isl = $$('.island'); },
    f(t) {
      enter(t, this.d);
      const [g0, g1] = this.card.querySelectorAll('.gauge');
      const p0 = lerp(62, 91, eio(seg(t, 1.3, 3.8)));
      setRing(g0, p0, fill(t, .8), toneOf(p0)); setRing(g1, 41, fill(t, .9), 'blue');
      const chip = this.card.querySelector('.chip');
      if (p0 >= 90) setChip(chip, pace(T('22 min', '22 dakikada')), 'hot');
      else if (p0 >= 80) setChip(chip, pace(T('45 min', '45 dakikada')), '');
      else setChip(chip, pace(T('2 hours', '2 saatte')), '');
      chip.style.transform = `scale(${1 + .14 * (pulse(t, 2.55, .35) + pulse(t, 3.62, .4))})`;
      this.isl.forEach((el, i) => {
        const k = spring(t - 3.9 - i * .35, .5, .62);
        el.style.opacity = seg(t, 3.9 + i * .35, 4.05 + i * .35);
        el.style.transform = `scale(${.35 + .65 * k}, ${.7 + .3 * k})`;
        [...el.children].forEach(ch => ch.style.opacity = seg(t, 4.1 + i * .35, 4.35 + i * .35));
      });
      sway(t);
    }
  };

  // ---------- 04 Bildirimler (7 sn) ----------
  S.notifications = {
    d: 7,
    init() { this.notes = $$('.note'); this.h = this.notes.map(n => n.offsetHeight + 12); this.at = [3.6, 2.4, 1.2]; },
    f(t) {
      enter(t, this.d);
      this.notes.forEach((n, j) => {
        const k = spring(t - this.at[j], .5, .78);
        let shift = 0; for (let i = 0; i < j; i++) shift -= this.h[i] * (1 - spring(t - this.at[i], .5, .85));
        n.style.opacity = seg(t, this.at[j], this.at[j] + .15);
        n.style.transform = `translate(${(1 - k) * 440}px, ${shift}px)`;
      });
      const sel = $('.mbar .sel'); sel.style.transform = `scale(${1 + .25 * (pulse(t, 1.2) + pulse(t, 2.4) + pulse(t, 3.6))})`;
    }
  };

  // ---------- 05 Hatırlatma (7 sn) ----------
  S.remind = {
    d: 7,
    init() {
      this.ctx = $('.ctx'); this.items = [...this.ctx.querySelectorAll('div')]; this.items.forEach(i => i.classList.remove('hl'));
      this.bell = $('.bell'); this.ctx.style.transformOrigin = '0 0';
    },
    f(t) {
      enter(t, this.d);
      const r = this.ctx.getBoundingClientRect(), anchor = [r.left + 6, r.top + 6];
      const item = center(this.items[0], -60);
      cursor(t, [[1.3, [1450, 860]], [2.0, anchor], [2.5, anchor], [2.9, item], [3.4, item], [4.1, [1500, 820]]], [1.3, 4.0]);
      clicks(t, [[2.05, anchor], [3.3, item]]);
      const k = spring(t - 2.12, .35, .8), out = seg(t, 3.4, 3.6);
      this.ctx.style.opacity = seg(t, 2.12, 2.22) * (1 - out);
      this.ctx.style.transform = `scale(${.92 + .08 * k})`;
      this.items[0].classList.toggle('hl', t > 2.75 && t < 3.45 && !(t > 3.3 && t < 3.36));
      const bk = spring(t - 3.5, .45, .5);
      this.bell.style.transform = `scale(${bk}) rotate(${Math.sin((t - 3.5) * 22) * 18 * (1 - seg(t, 3.5, 4.4)) * (t > 3.5 ? 1 : 0)}deg)`;
      const [g0, g1] = $$('.gauge'); setRing(g0, 100, fill(t, .8)); setRing(g1, 58, fill(t, .9));
      sway(t);
    }
  };

  // ---------- 06 Kartı çevir (7 sn) ----------
  S.flip = {
    d: 7,
    init() {
      this.front = $('#flipFront'); this.back = $('#flipBack');
      this.cells = $$('#flipBack .hm i').map(c => [c, +c.style.gridColumn.split(' ')[0]]);
    },
    f(t) {
      enter(t, this.d);
      const fc = center(this.front), bc = center(this.back);
      cursor(t, [[1.0, [1200, 820]], [1.6, fc], [2.2, fc], [2.7, [1350, 840]], [4.3, [1350, 840]], [4.8, bc], [5.2, bc], [5.7, [1350, 860]]], [1.0, 5.6]);
      clicks(t, [[1.7, fc], [4.85, bc]]);
      const ang = 180 * Math.min(1, spring(t - 1.75, .62, .8)) - 180 * Math.min(1, spring(t - 4.9, .62, .8));
      const dip = 1 - .05 * Math.sin(Math.PI * ang / 180);
      this.front.style.transform = `rotateY(${ang}deg) scale(${dip})`; this.front.style.opacity = ang < 90 ? 1 : 0;
      this.back.style.transform = `rotateY(${ang - 180}deg) scale(${dip})`; this.back.style.opacity = ang >= 90 ? 1 : 0;
      this.cells.forEach(([c, col]) => { const k = eo(seg(t, 2.05 + col * .045, 2.35 + col * .045)); c.style.opacity = k; c.style.transform = `scale(${.4 + .6 * k})`; });
      const [g0, g1] = this.front.querySelectorAll('.gauge'); setRing(g0, 91, fill(t, .8), 'red'); setRing(g1, 41, fill(t, .9), 'blue');
      sway(t);
    }
  };

  // ---------- 07 Hesaplar (7 sn) ----------
  S.accounts = {
    d: 7,
    init() { [this.a, this.b] = $$('.card'); },
    f(t) {
      enter(t, this.d);
      const [a0, a1] = this.a.querySelectorAll('.gauge'), [b0, b1] = this.b.querySelectorAll('.gauge');
      const p = lerp(74, 100, eio(seg(t, 1.3, 3.2)));
      setRing(a0, p, fill(t, .8), toneOf(p)); setRing(a1, 63, fill(t, .88), 'blue');
      setRing(b0, 8, fill(t, .95), 'blue'); setRing(b1, 12, fill(t, 1.03), 'blue');
      const ca = this.a.querySelector('.chip'), cb = this.b.querySelector('.chip');
      if (p >= 100) setChip(ca, T('Full · opens 19:10', 'Doldu · açılış 19:10'), 'hot');
      else if (p >= 90) setChip(ca, pace(T('6 min', '6 dakikada')), 'hot');
      else setChip(ca, pace(T('25 min', '25 dakikada')), p >= 75 ? '' : '');
      ca.style.transform = `translateX(${Math.sin(t * 55) * 6 * pulse(t, 3.2, .45)}px) scale(${1 + .1 * pulse(t, 3.2, .35)})`;
      const bk = spring(t - 3.7, .45, .6);
      cb.style.opacity = seg(t, 3.7, 3.85); cb.style.transform = `scale(${.6 + .4 * bk})`;
      this.b.style.boxShadow = `0 0 0 ${3.5 * Math.sin(Math.PI * seg(t, 3.7, 5.2))}px rgba(52,199,89,.6)`;
      sway(t);
    }
  };

  // ---------- 08 Küçük detaylar (7 sn) ----------
  S.details = {
    d: 7,
    init() { this.keys = $$('.key'); this.cards = $$('.stylecard'); },
    f(t) {
      enter(t, this.d);
      this.keys.forEach((k, i) => {
        const down = (t > 1.2 + i * .2 && t < 2.3) || (t > 4.6 + i * .12 && t < 5.4);
        k.style.transform = down ? 'translateY(4px)' : 'none';
        k.style.boxShadow = down ? (dk ? '0 1px 0 #0c0c0d, 0 2px 6px rgba(0,0,0,.5)' : '0 1px 0 #fff inset, 0 1px 0 #d2d2d7, 0 2px 6px rgba(0,0,0,.08)') : '';
        k.style.background = down ? (dk ? '#232325' : '#f2f2f4') : '';
      });
      const on = t < 2.6 ? 0 : Math.floor((t - 2.6) / .85) % 4;
      this.cards.forEach((c, i) => { c.classList.toggle('on', i === on); c.style.transform = i === on ? `scale(${1 + .03 * pulse(t, 2.6 + Math.floor((t - 2.6) / .85) * .85, .3)})` : 'none'; });
    }
  };

  // ---------- 09 Gizlilik (7 sn) ----------
  S.privacy = {
    d: 7,
    init() {
      this.rows = $$('.list .row');
      this.rows.forEach(r => r.querySelector('.ok').insertAdjacentHTML('beforebegin', `<span class="wait" style="color:#86868b;font-size:18px;display:flex;align-items:center;gap:8px"><svg width="18" height="18" viewBox="0 0 24 24"><circle cx="12" cy="12" r="9" fill="none" stroke="#c7c7cc" stroke-width="3"/><path class="spin" d="M12 3a9 9 0 0 1 9 9" fill="none" stroke="#86868b" stroke-width="3" stroke-linecap="round"/></svg>${T('Waiting for browser…', 'Tarayıcı bekleniyor…')}</span>`));
      this.facts = $$('.fact');
    },
    f(t) {
      enter(t, this.d);
      this.rows.forEach((r, i) => {
        const at = 1.6 + i * .8, done = t >= at;
        r.querySelector('.wait').style.display = done ? 'none' : 'flex';
        r.querySelector('.spin').setAttribute('transform', `rotate(${t * 400} 12 12)`);
        const ok = r.querySelector('.ok'); ok.style.display = done ? 'flex' : 'none';
        ok.style.transform = `scale(${.5 + .5 * spring(t - at, .4, .55)})`;
      });
      this.facts.forEach((f, i) => { const k = eo(seg(t, 3.2 + i * .18, 3.8 + i * .18)); f.style.opacity = k; f.style.transform = `translateY(${24 * (1 - k)}px)`; });
    }
  };

  // ---------- 10 İndir (7 sn) ----------
  S.download = {
    d: 7,
    init() {
      this.box = $('.code'); this.cmd = this.box.querySelector('span'); this.full = this.cmd.textContent.replace(/^\$\s*/, '');
      this.btn = this.box.querySelector('button'); this.img = $('img'); this.h = $('.h'); this.sub = $('.sub'); this.link = this.box.nextElementSibling;
    },
    f(t) {
      const ik = spring(t - .2, .55, .55);
      this.img.style.transform = `scale(${.5 + .5 * ik}) rotate(${(1 - ik) * -12}deg)`; this.img.style.opacity = seg(t, .2, .4);
      [this.h, this.sub].forEach((e, i) => { const k = eo(seg(t, .55 + i * .12, 1.2 + i * .12)); e.style.opacity = k; e.style.transform = `translateY(${24 * (1 - k)}px)`; });
      this.box.style.opacity = seg(t, 1.1, 1.4);
      const n = Math.round(this.full.length * seg(t, 1.4, 3.2));
      this.cmd.innerHTML = `<span class="p">$</span> ${this.full.slice(0, n)}<span style="display:inline-block;width:10px;height:20px;background:#e5e5ea;vertical-align:-3px;margin-left:2px;opacity:${Math.floor(t * 2.4) % 2 ? .2 : 1}"></span>`;
      const copied = t > 3.9 && t < 5.6;
      this.btn.textContent = copied ? T('Copied ✓', 'Kopyalandı ✓') : T('Copy', 'Kopyala');
      this.btn.style.background = copied ? '#30d158' : '#2c2c2e'; this.btn.style.color = copied ? '#000' : '#f5f5f7';
      this.btn.style.transform = `scale(${1 + .1 * pulse(t, 3.9, .3)})`;
      this.link.style.opacity = seg(t, 1.8, 2.2);
      fadeov.style.opacity = seg(t, this.d - .5, this.d);
    }
  };

  const key = Object.keys(S).find(k => id.includes(k));
  const scene = S[key];
  window.duration = scene.d;
  scene.init?.call(scene);
  window.frame = t => scene.f.call(scene, t);
  window.frame(0);
})();
