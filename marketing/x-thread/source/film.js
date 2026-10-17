// Tweet filmleri: her sahne frame(t) ile t saniyesindeki hâline çizilir (deterministik; snapvid kare kare yakalar).
// Dil Apple ürün filmleri: tek ürün, yavaş kamera, uzun yumuşak geçişler, satır satır tipografi.
(() => {
  const stage = document.getElementById('stage');
  const C01 = x => Math.max(0, Math.min(1, x));
  const seg = (t, a, b) => C01((t - a) / (b - a));
  const eOut = x => 1 - Math.pow(1 - x, 4);
  const eIO = x => x < .5 ? 8 * x ** 4 : 1 - Math.pow(-2 * x + 2, 4) / 2;
  const lerp = (a, b, k) => a + (b - a) * k;
  function spring(t, response = .42, damping = .68) {
    if (t <= 0) return 0;
    const w = 2 * Math.PI / response, z = damping, wd = w * Math.sqrt(1 - z * z);
    return 1 - Math.exp(-z * w * t) * (Math.cos(wd * t) + z * w / wd * Math.sin(wd * t));
  }
  const pulse = (t, at, d = .35) => { const k = seg(t, at, at + d); return k > 0 && k < 1 ? Math.sin(Math.PI * k) : 0; };
  const $ = q => stage.querySelector(q), $$ = q => [...stage.querySelectorAll(q)];

  // Satır belirişi: yukarı kayarak, bulanıklıktan netleşerek; isteğe bağlı çıkış
  function reveal(el, t, t0, { d = 1.1, y = 26, blur = 12, out = null, outD = .55 } = {}) {
    const k = eOut(seg(t, t0, t0 + d)), q = out == null ? 0 : eIO(seg(t, out, out + outD));
    el.style.opacity = k * (1 - q);
    el.style.transform = `translateY(${y * (1 - k) - 14 * q}px)`;
    el.style.filter = `blur(${blur * (1 - k) + 10 * q}px)`;
  }
  // Çekim görünürlüğü (çapraz geçiş + hafif ölçek)
  function shot(el, t, a, b, fi = .5, fo = .5) {
    const i = eOut(seg(t, a, a + fi)), o = eIO(seg(t, b - fo, b));
    el.style.display = t < a || t > b ? 'none' : 'block';
    el.style.opacity = i * (1 - o);
    el.style.transform = `scale(${1.03 - .03 * i + .02 * o})`;
    el.style.filter = `blur(${8 * (1 - i) + 8 * o}px)`;
  }

  const TONES = { blue: ['#7fb2ff', '#2f74f0'], purple: ['#a58bff', '#5b3fe0'], red: ['#ff9f0a', '#ff2d20'] };
  const toneOf = p => p >= 90 ? 'red' : p >= 75 ? 'purple' : 'blue';
  function setRing(host, p, f = 1, tone) {
    const val = host.querySelector('.val'), C = +val.dataset.c, v = C * .75 * Math.min(p, 100) / 100 * f;
    val.setAttribute('stroke-dasharray', `${Math.max(.001, v)} ${C}`);
    val.style.opacity = v < .4 ? 0 : 1;
    if (tone) host.querySelectorAll('stop').forEach((s, i) => s.setAttribute('stop-color', TONES[tone][i]));
    const tx = host.querySelector('.pct');
    if (tx) { const n = Math.round(p * Math.min(1, f)); tx.textContent = `${n}%`; tx.style.fontSize = n >= 100 ? '10.5px' : '12.5px'; }
  }
  const setChip = (c, text, kind) => { if (c.textContent !== text) c.textContent = text; c.className = `chip ${kind || ''}`; };
  const fill = (t, t0) => Math.min(1.03, spring(t - t0, 1.0, .85));
  const sway = t => $$('.card').forEach((c, i) => c.querySelectorAll('.holo').forEach((h, k) =>
    h.style.setProperty('--a', `${(k ? 64 : 118) + 26 * Math.sin(2 * Math.PI * (t / 7 + i * .17))}deg`)));

  // İmleç (sahne koordinatında)
  const cursorSvg = `<svg class="cur2" viewBox="0 0 24 24"><path d="M5 2.5l14 8.6-6.3 1.4 3.7 6.9-2.8 1.5-3.7-6.9L5 18.6Z" fill="#000" stroke="#fff" stroke-width="1.3" stroke-linejoin="round"/></svg>`;
  function cursor(el, t, keys, show) {
    let p = keys[0][1];
    for (let i = 1; i < keys.length; i++) {
      const [ta, pa] = keys[i - 1], [tb, pb] = keys[i];
      if (t >= tb) p = pb; else if (t > ta) { const k = eIO((t - ta) / (tb - ta)); p = [lerp(pa[0], pb[0], k), lerp(pa[1], pb[1], k)]; break; }
    }
    el.style.opacity = seg(t, show[0], show[0] + .25) * (1 - seg(t, show[1], show[1] + .25));
    el.style.transform = `translate(${p[0] - 6}px, ${p[1] - 3}px)`;
  }
  const press = (el, t, at) => { if (t >= at && t < at + .14) el.style.transform += ' scale(.85)'; };
  const center = el => { const r = el.getBoundingClientRect(); return [r.left + r.width / 2, r.top + r.height / 2]; };

  // Koyu menü çubuğu ikonu (iç içe halkalar, beyaz mürekkep)
  const ringsIcon = (o, i, s = 22) => miniRings(o, i, s).replace(/#1d1d1f/g, '#f5f5f7').replace(/rgba\(0,0,0,.18\)/g, 'rgba(255,255,255,.25)');
  const deskBar = `<div class="mbar"><span></span><b>Terminal</b><span>${T('File', 'Dosya')}</span><span>${T('Edit', 'Düzen')}</span><span>${T('View', 'Görüntü')}</span><span>${T('Window', 'Pencere')}</span>
    <div class="r"><span class="sel" id="icon" style="background:transparent">${ringsIcon(30, 44)}</span>
    <svg width="22" height="12" viewBox="0 0 22 12"><rect x=".5" y=".5" width="18" height="11" rx="3" fill="none" stroke="#fff" opacity=".5"/><rect x="2" y="2" width="12" height="8" rx="1.6" fill="#fff"/></svg>
    <span>87%</span><span>Wi‑Fi</span><svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.2"><circle cx="10.5" cy="10.5" r="6.5"/><path d="M15.5 15.5 21 21"/></svg>
    <svg width="17" height="15" viewBox="0 0 24 20" fill="none" stroke="#fff" stroke-width="2"><rect x="2" y="2" width="20" height="7" rx="3.5"/><rect x="2" y="11" width="20" height="7" rx="3.5"/><circle cx="17" cy="5.5" r="1.6" fill="#fff"/><circle cx="7" cy="14.5" r="1.6" fill="#fff"/></svg>
    <span>${T('Mon 17:12', 'Pzt 17:12')}</span></div></div>`;
  const note = (t, b, time) => `<div class="note"><span class="appicon"></span><div><b>${t}</b><span>${b}</span></div><time>${time}</time></div>`;
  const claudeLive = (chips = true) => ({ logo: 'claude', name: 'Claude', plan: 'PRO', chip: pace(T('1 hour', '1 saatte')), chips: chips ? [[PERSONAL, 'on'], [WORK]] : null,
    rings: [{ p: 93, tone: 'red', l: H5, r: tm(1, 12) }, { p: 41, tone: 'blue', l: WK, r: td(3, 17) }] });
  const check = `<svg width="22" height="22" viewBox="0 0 24 24"><circle cx="12" cy="12" r="11" fill="#30d158"/><path d="M7 12.5l3.2 3L17 9" fill="none" stroke="#fff" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/></svg>`;
  const appWord = (size = 40) => `<span style="display:inline-flex;align-items:center;gap:${size * .3}px"><img src="icon.png" width="${size * 1.3}" height="${size * 1.3}" style="border-radius:${size * .29}px">AI Limit Tracker</span>`;

  // Popup açılışı: .88 ölçek + bulanıklıktan yay, kartlar sırayla
  function openPopup(pop, t, t0, tOut = 99) {
    const x = spring(t - t0), out = seg(t, tOut, tOut + .4);
    pop.style.transform = `scale(${.88 + .12 * x - .05 * out})`;
    pop.style.opacity = seg(t, t0, t0 + .2) * (1 - out);
    pop.style.filter = `blur(${Math.max(0, 8 * (1 - Math.min(1, x * 1.4))) + 8 * out}px)`;
    pop.querySelectorAll('.card').forEach((c, i) => {
      const y = spring(t - t0 - .08 - i * .07);
      c.style.transform = `translateY(${-14 * (1 - y)}px)`; c.style.opacity = seg(t, t0 + .08 + i * .07, t0 + .3 + i * .07);
    });
    const f = pop.querySelector('.foot'); if (f) f.style.opacity = seg(t, t0 + .3, t0 + .6);
  }
  // Ürünün sahneye girişi: alttan, öne eğik, ışığa doğru doğrulur
  function rise(el, t, t0, d = 1.6, base = '') {
    const k = eOut(seg(t, t0, t0 + d));
    el.style.opacity = seg(t, t0, t0 + .5);
    el.style.transform = `${base} perspective(1800px) translateY(${120 * (1 - k)}px) rotateX(${24 * (1 - k)}deg) scale(${.92 + .08 * k})`;
  }

  const S = {};

  // ===== 1 · Hook (10 sn): acı → menü çubuğu makro → popup → kapanış =====
  S.hook = {
    d: 10, poster: 7.6,
    html: () => `
      <div class="shot" id="sA"><div class="light"></div>
        <div class="cap" style="top:250px;font-size:84px"><span class="ln" id="a1">${T('Deep in a refactor.', 'Tam refactor’ın ortasında.')}</span><span class="ln g" id="a2">${T('Then this.', 'Sonra bu.')}</span></div>
        <div class="limit" id="a3"><svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M12 3 2 20h20Z"/><path d="M12 10v4M12 17v.5"/></svg>${T('Usage limit reached · resets 3:00 PM', 'Kullanım limiti doldu · 15:00’te sıfırlanır')}</div></div>
      <div class="shot" id="sB"><div class="cam" id="cam"><div class="desk"></div>
          <div style="position:absolute;left:0;right:0;top:0;zoom:1.5">${deskBar}</div>
          <div id="host" style="position:absolute;top:50px;left:0;zoom:1.4">${popup([claudeLive(), codex])}</div>
          ${cursorSvg}</div>
        <div class="cap" id="b1" style="bottom:110px">${T('See it coming.', 'Geldiğini gör.')}</div></div>
      <div class="shot" id="sD"><div class="light"></div>
        <div style="position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:22px">
          <img id="d0" src="icon.png" width="150" height="150" style="filter:drop-shadow(0 24px 50px rgba(0,0,0,.6))">
          <div class="wordmark" id="d1">AI Limit Tracker</div>
          <div class="cap small" id="d2" style="position:static">${T('Every AI limit. One glance.', 'Her AI limiti. Tek bakışta.')}</div></div></div>`,
    init() {
      const ic = center($('#icon')), host = $('#host'), pw = host.getBoundingClientRect().width;
      host.style.left = `${Math.min(1600 - 24 - pw, ic[0] - pw / 2) / 1.4}px`;
      const r = host.getBoundingClientRect();
      this.icon = ic; this.pop = [r.left + r.width / 2, r.top + r.height / 2 - 20];
      this.claude = $$('#host .card')[0]; this.codex = $$('#host .card')[1];
    },
    f(t) {
      shot($('#sA'), t, 0, 2.7, .3, .45);
      reveal($('#a1'), t, .15); reveal($('#a2'), t, .9);
      const a3 = $('#a3'), k = eOut(seg(t, 1.55, 2.0));
      a3.style.opacity = k; a3.style.transform = `translateX(calc(-50% + ${Math.sin(t * 50) * 10 * (1 - seg(t, 1.6, 2.1)) * (t > 1.6 ? 1 : 0)}px)) scale(${.94 + .06 * k})`;

      // Menü çubuğu makro (×3.4) → tıkla → kamera popup'a geri çekilir (×1.6)
      shot($('#sB'), t, 2.55, 8.75, .45, .5);
      const z = eIO(seg(t, 4.55, 5.9)), sc = lerp(3.4, 1.62, z) * (1 + .03 * seg(t, 2.5, 8.7));
      const cx = lerp(this.icon[0], this.pop[0], z), cy = lerp(this.icon[1] + 90, this.pop[1], z);
      const cl = (v, lo) => Math.max(lo, Math.min(0, v));
      $('#cam').style.transform = `translate(${cl(800 - cx * sc, 1600 - 1600 * sc)}px, ${cl(450 - cy * sc, 900 - 900 * sc)}px) scale(${sc})`;
      const o = lerp(30, 78, eIO(seg(t, 2.9, 4.2)));
      $('#icon').innerHTML = ringsIcon(o, 44);
      $('#icon').style.background = t > 4.62 && t < 8.6 ? 'rgba(255,255,255,.2)' : 'transparent';
      reveal($('#b1'), t, 3.0, { out: 4.3 });
      const cur = $('#cam .cur2'), ic = this.icon;
      cursor(cur, t, [[3.7, [ic[0] - 120, ic[1] + 70]], [4.45, [ic[0] + 2, ic[1] + 2]], [5.0, [ic[0] + 2, ic[1] + 2]], [5.8, [ic[0] - 60, ic[1] + 260]]], [3.7, 5.7]);
      press(cur, t, 4.55);
      openPopup($('#host .popup'), t, 4.62);
      const [g0, g1] = this.claude.querySelectorAll('.gauge');
      const p0 = lerp(78, 93, eIO(seg(t, 6.3, 7.4)));
      setRing(g0, p0, fill(t, 4.9), toneOf(p0)); setRing(g1, 41, fill(t, 4.98), 'blue');
      const [c0, c1] = this.codex.querySelectorAll('.gauge'); setRing(c0, 44, fill(t, 5.0), 'purple'); setRing(c1, 23, fill(t, 5.08), 'blue');
      const chip = this.claude.querySelector('.chip');
      if (p0 >= 90) setChip(chip, pace(T('22 min', '22 dakikada')), 'hot');
      else if (p0 >= 84) setChip(chip, pace(T('40 min', '40 dakikada')), '');
      else setChip(chip, pace(T('1 hour', '1 saatte')), '');
      chip.style.opacity = seg(t, 5.2, 5.5); chip.style.transform = `scale(${1 + .1 * pulse(t, 7.1, .45)})`;
      this.codex.querySelector('.chip').style.opacity = seg(t, 5.3, 5.6);
      sway(t);

      shot($('#sD'), t, 8.55, 10, .6, .35);
      reveal($('#d0'), t, 8.65, { y: 40 }); reveal($('#d1'), t, 8.85); reveal($('#d2'), t, 9.1);
    }
  };

  // ===== 2 · Tek yer (8 sn): dağınık pencereler → tek popup =====
  const winHtml = (title, rows, style) => `<div class="win" style="${style}"><div class="tb"><i></i><i></i><i></i><span>${title}</span></div><div class="bd">${rows.map(([l, p]) =>
    `<div class="rw"><b>${l}</b><span>${p}%</span><div class="bar"><i style="width:${p}%"></i></div></div>`).join('')}</div></div>`;
  S.one = {
    d: 8, poster: 6,
    html: () => `<div class="light"></div>
      <div class="cap" style="top:86px"><span class="ln" id="c1">${T('Your limits live in different places.', 'Limitlerin farklı yerlerde.')}</span></div>
      <div class="cap" style="top:86px"><span class="ln" id="c2">${T('Now they live in one. <span class="g">Your menu bar.</span>', 'Artık tek bir yerde. <span class="g">Menü çubuğunda.</span>')}</span></div>
      <div id="wins">
        ${winHtml(T('Claude — Usage', 'Claude — Kullanım'), [[T('Current session', 'Mevcut oturum'), 78], [T('Weekly · all models', 'Haftalık · tüm modeller'), 41]], 'left:100px;top:330px')}
        ${winHtml(T('Codex — Usage', 'Codex — Kullanım'), [[T('5-hour limit', '5 saatlik limit'), 44], [T('Weekly limit', 'Haftalık limit'), 23]], 'left:565px;top:260px')}
        ${winHtml(T('Claude — Work account', 'Claude — İş hesabı'), [[T('Current session', 'Mevcut oturum'), 8], [T('Weekly · all models', 'Haftalık · tüm modeller'), 12]], 'left:1030px;top:350px')}
      </div>
      <div id="pop" style="position:absolute;left:50%;top:170px;zoom:1.9">${popup([claudeLive(), codex])}</div>
`,
    init() {
      const host = $('#pop'); host.style.marginLeft = `${-host.getBoundingClientRect().width / 2 / 1.9}px`;
      this.wins = $$('.win'); this.claude = $$('#pop .card')[0]; this.codex = $$('#pop .card')[1];
      $('#pop .popup').style.transformOrigin = '50% 30%';
    },
    f(t) {
      reveal($('#c1'), t, .5, { out: 2.9 }); reveal($('#c2'), t, 3.7);
      const rot = [[-3, 5], [1.5, -3], [3, 5]];
      this.wins.forEach((w, i) => {
        const k = eOut(seg(t, .2 + i * .15, 1.6 + i * .15)), m = eIO(seg(t, 2.9 + i * .06, 3.8 + i * .06));
        const [rz, ry] = rot[i], r = w.getBoundingClientRect();
        const dx = (800 - (parseFloat(w.style.left) + 235)) * m, dy = (450 - (parseFloat(w.style.top) + 120)) * m;
        w.style.opacity = seg(t, .2 + i * .15, .7 + i * .15) * (1 - m);
        w.style.filter = `blur(${10 * m}px)`;
        w.style.transform = `perspective(1600px) translate(${dx}px, ${dy + 70 * (1 - k) + 6 * Math.sin(t * 1.3 + i)}px) rotateZ(${rz * (1 - m)}deg) rotateY(${ry * (1 - m)}deg) scale(${(.94 + .06 * k) * (1 - .55 * m)})`;
        w.querySelectorAll('.bar i').forEach((b, j) => b.style.transform = `scaleX(${eOut(seg(t, .9 + i * .15 + j * .1, 2.0 + i * .15 + j * .1))})`);
        w.querySelectorAll('.bar i').forEach(b => b.style.transformOrigin = '0 50%');
      });
      openPopup($('#pop .popup'), t, 3.45);
      const [g0, g1] = this.claude.querySelectorAll('.gauge'), [c0, c1] = this.codex.querySelectorAll('.gauge');
      setRing(g0, 78, fill(t, 3.7), 'purple'); setRing(g1, 41, fill(t, 3.78), 'blue');
      setRing(c0, 44, fill(t, 3.8), 'purple'); setRing(c1, 23, fill(t, 3.88), 'blue');
      this.claude.querySelector('.chip').style.opacity = seg(t, 4.1, 4.4); this.codex.querySelector('.chip').style.opacity = seg(t, 4.2, 4.5);
      $('#pop').style.transform = `scale(${1 + .03 * seg(t, 3.4, 8)})`;
      sway(t);
    }
  };

  // ===== 3 · Tahmin (8 sn) =====
  S.forecast = {
    d: 8, poster: 5.6,
    html: () => `<div class="light"></div>
      <div class="cap" style="top:96px"><span class="ln" id="c1">${T('It knows where you’re heading.', 'Nereye gittiğini bilir.')}</span></div>
      <div id="prod" style="position:absolute;left:0;right:0;top:300px;display:flex;justify-content:center"><div style="zoom:2.75">${card(claudeLive(false))}</div></div>
      <div class="cap small" id="c2" style="bottom:96px">${T('Time to wrap up, switch tasks or slow down.', 'Toparlamaya, iş değiştirmeye ya da yavaşlamaya vaktin olur.')}</div>`,
    init() { this.card = $('.card'); },
    f(t) {
      reveal($('#c1'), t, .35); reveal($('#c2'), t, 4.9);
      rise($('#prod'), t, .2, 1.8);
      $('#prod').style.transform += ` scale(${1 + .05 * seg(t, 1.5, 8)})`;
      const [g0, g1] = this.card.querySelectorAll('.gauge'), p0 = lerp(62, 91, eIO(seg(t, 1.9, 4.4)));
      setRing(g0, p0, fill(t, 1.0), toneOf(p0)); setRing(g1, 41, fill(t, 1.1), 'blue');
      const chip = this.card.querySelector('.chip');
      if (p0 >= 90) setChip(chip, pace(T('22 min', '22 dakikada')), 'hot');
      else if (p0 >= 80) setChip(chip, pace(T('45 min', '45 dakikada')), '');
      else setChip(chip, pace(T('2 hours', '2 saatte')), '');
      chip.style.transform = `scale(${1 + .1 * (pulse(t, 3.05, .4) + pulse(t, 4.25, .45))})`;
      sway(t);
    }
  };

  // ===== 4 · Bildirimler (8 sn): ekran köşesi yakın plan =====
  S.alerts = {
    d: 8, poster: 5.6,
    html: () => `<div class="light"></div>
      <div class="cap left" style="top:310px;font-size:58px;width:620px"><span class="ln" id="c1">${T('A nudge at 75%<br>and 90%.', '%75 ve %90’da<br>haber verir.')}</span><span class="ln g" id="c2">${T('Another the moment<br>it resets.', 'Limit yenilendiği an<br>bir daha.')}</span></div>
      <div id="corner" style="position:absolute;left:820px;top:70px;width:900px;height:900px;border-radius:34px 0 0 0;overflow:hidden;box-shadow:0 0 0 1px rgba(255,255,255,.08)">
        <div class="desk" style="width:900px;height:900px"></div>
        <div style="position:absolute;left:0;right:0;top:0;zoom:1.5">${deskBar}</div>
        <div id="stack" style="position:absolute;left:34px;top:60px;display:flex;flex-direction:column;gap:12px;zoom:1.6">
          ${note(T('Claude · 5 hours 90%', 'Claude · 5 saat %90'), T('You’re very close to the limit. Resets in 1 h 12 m.', 'Limite çok yaklaştın. 1 sa 12 dk sonra sıfırlanır.'), T('now', 'şimdi'))}
          ${note(T('Codex · Weekly 75%', 'Codex · Haftalık %75'), T('You’ve used three quarters of your limit.', 'Limitin dörtte üçünü kullandın.'), T('40m ago', '40 dk'))}
          ${note(T('Claude · Your 5‑hour limit reset', 'Claude · 5 saat limitin yenilendi'), T('Pick up right where you left off.', 'Kaldığın yerden devam edebilirsin.'), '14:36')}
        </div></div>`,
    init() { this.notes = $$('.note'); this.h = this.notes.map(n => n.offsetHeight + 12); this.at = [3.7, 2.6, 1.5]; $('#icon').innerHTML = ringsIcon(64, 44); },
    f(t) {
      reveal($('#c1'), t, .45); reveal($('#c2'), t, 3.9);
      const ck = eOut(seg(t, .1, 1.6));
      $('#corner').style.opacity = seg(t, .1, .6);
      $('#corner').style.transform = `translate(${60 * (1 - ck)}px, ${40 * (1 - ck)}px) scale(${1 + .04 * seg(t, 1, 8)})`;
      this.notes.forEach((n, j) => {
        const k = spring(t - this.at[j], .55, .8);
        let shift = 0; for (let i = 0; i < j; i++) shift -= this.h[i] * (1 - spring(t - this.at[i], .55, .86));
        n.style.opacity = seg(t, this.at[j], this.at[j] + .2);
        n.style.transform = `translate(${(1 - k) * 420}px, ${shift}px)`;
      });
      $('#icon').style.transform = `scale(${1 + .25 * (pulse(t, 1.5) + pulse(t, 2.6) + pulse(t, 3.7))})`;
    }
  };

  // ===== 5 · Açılınca haber ver (8 sn) =====
  const fullCard = { logo: 'claude', name: 'Claude', plan: 'PRO', chip: T('Full · opens 19:10', 'Doldu · açılış 19:10'), chipKind: 'hot',
    rings: [{ p: 100, tone: 'red', l: H5, r: tm(1, 48), bell: true }, { p: 58, tone: 'blue', l: WK, r: td(3, 2) }] };
  const bellPath = '<svg viewBox="0 0 24 24"><path d="M6 16V11a6 6 0 0 1 12 0v5l1.5 2h-15ZM10 21h4"/></svg>';
  S.remind = {
    d: 8, poster: 2.5,
    html: () => `<div class="light"></div>
      <div id="prod" style="position:absolute;left:0;right:0;top:250px;display:flex;justify-content:center"><div style="zoom:2.3;position:relative;margin-right:120px">${card(fullCard)}
        <div class="ctx" style="position:absolute;left:530px;top:120px;zoom:.62">
          <div>${bellPath}${T('Notify when 5 hours opens', '5 saat açılınca haber ver')}</div>
          <div>${bellPath}${T('Notify when Weekly opens', 'Haftalık açılınca haber ver')}</div><hr>
          <div><svg viewBox="0 0 24 24"><path d="M4 20h4L19 9l-4-4L4 16v4Z"/></svg>${T('Name Accounts…', 'Hesapları Adlandır…')}</div></div></div></div>
      <div id="nt" style="position:absolute;left:50%;top:70px;zoom:1.7">${note(T('Claude · 5 hours is open again', 'Claude · 5 saat açıldı'), T('You asked for a reminder. Pick up where you left off.', 'Hatırlatmanı istemiştin, kaldığın yerden devam edebilirsin.'), T('now', 'şimdi'))}</div>
      <div class="cap" style="bottom:96px"><span class="ln" id="c1">${T('Out of limit? Right‑click.', 'Doldu mu? Sağ tıkla.')}</span></div>
      <div class="cap" style="bottom:96px"><span class="ln" id="c2">${T('It tells you the moment you’re back.', 'Açıldığı an haber verir.')}</span></div>
      ${cursorSvg}`,
    init() {
      this.ctx = $('.ctx'); this.items = [...this.ctx.querySelectorAll('div')]; this.ctx.style.transformOrigin = '0 0';
      this.bell = $('.bell'); this.card = $('.card');
      const nt = $('#nt'); nt.style.marginLeft = `${-nt.getBoundingClientRect().width / 2 / 1.7}px`;
      const r = this.ctx.getBoundingClientRect(); this.anchor = [r.left + 8, r.top + 8]; this.item = center(this.items[0]); this.item[0] -= 120;
    },
    f(t) {
      rise($('#prod'), t, .1, 1.6);
      reveal($('#c1'), t, .5, { out: 3.6 }); reveal($('#c2'), t, 4.6);
      const cur = $('.cur2');
      cursor(cur, t, [[1.0, [1400, 820]], [1.6, this.anchor], [2.0, this.anchor], [2.4, this.item], [2.8, this.item], [3.4, [1420, 860]]], [1.0, 3.3]);
      press(cur, t, 1.65); press(cur, t, 2.7);
      const k = spring(t - 1.72, .36, .82), out = seg(t, 2.78, 2.98);
      this.ctx.style.opacity = seg(t, 1.72, 1.82) * (1 - out); this.ctx.style.transform = `scale(${.92 + .08 * k})`;
      this.items[0].classList.toggle('hl', t > 2.25 && t < 2.85 && !(t > 2.7 && t < 2.76));
      const bk = spring(t - 2.95, .45, .5);
      this.bell.style.transform = `scale(${bk}) rotate(${Math.sin((t - 2.95) * 22) * 18 * (1 - seg(t, 2.95, 3.9)) * (t > 2.95 ? 1 : 0)}deg)`;
      // 19:10 olur: bildirim iner, halka boşalır, çip "Açıldı"
      const n = spring(t - 4.2, .55, .8), nt = $('#nt');
      nt.style.opacity = seg(t, 4.2, 4.4); nt.style.transform = `translateY(${-90 * (1 - n)}px)`;
      const [g0, g1] = this.card.querySelectorAll('.gauge'), back = t > 4.5;
      setRing(g0, back ? lerp(100, 0, eIO(seg(t, 4.5, 5.3))) : 100, fill(t, .6), back ? 'blue' : 'red'); setRing(g1, 58, fill(t, .7), 'blue');
      if (back) { setChip(this.card.querySelector('.chip'), T('Open again', 'Yeniden açık'), 'ok'); this.bell.style.opacity = 1 - seg(t, 4.5, 4.8); }
      else setChip(this.card.querySelector('.chip'), T('Full · opens 19:10', 'Doldu · açılış 19:10'), 'hot');
      sway(t);
    }
  };

  // ===== 6 · İki hesap (8 sn) =====
  const split = (badge, chip, kind) => ({ logo: 'claude', name: 'Claude', plan: 'PRO', badge, chip, chipKind: kind,
    rings: [{ p: 50, tone: 'blue', l: H5, r: tm(1, 48) }, { p: 50, tone: 'blue', l: WK, r: td(4, 6) }] });
  S.accounts = {
    d: 8, poster: 5.4,
    html: () => `<div class="light"></div>
      <div class="cap" style="top:86px"><span class="ln" id="c1">${T('Two accounts. <span class="g">Zero downtime.</span>', 'İki hesap. <span class="g">Kesintisiz iş.</span>')}</span></div>
      <div id="prod" style="position:absolute;left:0;right:0;top:250px;display:flex;flex-direction:column;align-items:center;gap:22px">
        <div style="zoom:2" id="pa">${card(split(PERSONAL, pace(T('25 min', '25 dakikada')), ''))}</div>
        <div style="zoom:2" id="pb">${card(split(WORK, T('Available', 'Kullanılabilir'), 'ok'))}</div></div>
      <div class="cap small" id="c2" style="bottom:46px">${T('When one runs dry, keep going on the other.', 'Biri dolunca diğeriyle devam et.')}</div>`,
    init() { this.a = $('#pa .card'); this.b = $('#pb .card'); },
    f(t) {
      reveal($('#c1'), t, .35); reveal($('#c2'), t, 4.6);
      rise($('#prod'), t, .2, 1.7);
      const [a0, a1] = this.a.querySelectorAll('.gauge'), [b0, b1] = this.b.querySelectorAll('.gauge');
      const p = lerp(74, 100, eIO(seg(t, 1.8, 3.6)));
      setRing(a0, p, fill(t, 1.0), toneOf(p)); setRing(a1, 63, fill(t, 1.08), 'blue');
      setRing(b0, 8, fill(t, 1.15), 'blue'); setRing(b1, 12, fill(t, 1.23), 'blue');
      const ca = this.a.querySelector('.chip');
      if (p >= 100) setChip(ca, T('Full · opens 19:10', 'Doldu · açılış 19:10'), 'hot');
      else if (p >= 90) setChip(ca, pace(T('6 min', '6 dakikada')), 'hot');
      else setChip(ca, pace(T('25 min', '25 dakikada')), '');
      ca.style.transform = `translateX(${Math.sin(t * 50) * 6 * pulse(t, 3.6, .45)}px)`;
      const lift = eOut(seg(t, 4.0, 4.9)), dim = seg(t, 4.0, 4.9);
      $('#pa').style.opacity = 1 - .45 * dim; $('#pa').style.filter = `blur(${1.5 * dim}px)`;
      $('#pb').style.transform = `scale(${1 + .035 * lift})`;
      this.b.style.boxShadow = `0 0 0 ${2.5 * lift}px rgba(48,209,88,.75), 0 0 ${60 * lift}px rgba(48,209,88,${.25 * lift})`;
      const cb = this.b.querySelector('.chip'); cb.style.transform = `scale(${1 + .12 * pulse(t, 4.1, .4)})`;
      sway(t);
    }
  };

  // ===== 7 · Kartı çevir (8 sn) =====
  S.flip = {
    d: 8, poster: 3.9,
    html: () => `<div class="light"></div>
      <div class="cap" style="top:86px"><span class="ln" id="c1">${T('The whole picture. <span class="g">One click away.</span>', 'Resmin tamamı. <span class="g">Bir tık uzakta.</span>')}</span></div>
      <div id="prod" style="position:absolute;left:0;right:0;top:240px;bottom:60px;display:flex;align-items:center;justify-content:center;perspective:2400px">
        <div id="ff" style="zoom:2.5;position:absolute">${card(claudeLive())}</div>
        <div id="fb" style="zoom:2.15;position:absolute">${backCard('claude')}</div></div>
      ${cursorSvg}`,
    init() {
      this.cells = $$('#fb .hm i').map(c => [c, +c.style.gridColumn.split(' ')[0]]);
      this.fc = center($('#ff')); this.fc[1] += 40;
      const [g0, g1] = $('#ff').querySelectorAll('.gauge'); this.g = [g0, g1];
      setChip($('#ff .chip'), pace(T('22 min', '22 dakikada')), 'hot');
    },
    f(t) {
      reveal($('#c1'), t, .35);
      rise($('#prod'), t, .15, 1.6);
      const cur = $('.cur2'), fc = this.fc;
      cursor(cur, t, [[1.2, [fc[0] + 260, fc[1] + 260]], [1.75, fc], [2.05, fc], [2.6, [fc[0] + 420, fc[1] + 300]]], [1.2, 2.5]);
      press(cur, t, 1.85);
      const ang = 180 * Math.min(1, spring(t - 1.92, .7, .8)) - 180 * Math.min(1, spring(t - 6.2, .7, .8));
      const dip = 1 - .06 * Math.sin(Math.PI * ang / 180);
      $('#ff').style.transform = `rotateY(${ang}deg) scale(${dip})`; $('#ff').style.opacity = ang < 90 ? 1 : 0;
      $('#fb').style.transform = `rotateY(${ang - 180}deg) scale(${dip})`; $('#fb').style.opacity = ang >= 90 ? 1 : 0;
      this.cells.forEach(([c, col]) => { const k = eOut(seg(t, 2.3 + col * .05, 2.7 + col * .05)); c.style.opacity = k; c.style.transform = `scale(${.4 + .6 * k})`; });
      setRing(this.g[0], 91, fill(t, .9), 'red'); setRing(this.g[1], 41, fill(t, 1.0), 'blue');
      sway(t);
    }
  };

  // ===== 8 · Yolunda durmaz (8 sn): ⌃⌥L → menü çubuğu stilleri =====
  const styleIcons = [
    () => ringsIcon(64, 44),
    () => `<span style="display:flex;align-items:center;gap:5px;font:600 13px var(--round);color:#ff453a">${ring(91, 'red', 20, 3, false).replace('rgba(0,0,0,.11)', 'rgba(255,255,255,.2)')}91% · 22m</span>`,
    () => `<span style="display:flex;gap:5px;align-items:center">${logo('claude', 'width="12" height="12" fill="#e8643c"')}${ring(64, 'red', 18, 2.6, false).replace('rgba(0,0,0,.11)', 'rgba(255,255,255,.2)')}${logo('openai', 'width="12" height="12" fill="#f5f5f7"')}${ring(44, 'blue', 18, 2.6, false).replace('rgba(0,0,0,.11)', 'rgba(255,255,255,.2)')}</span>`,
    () => `<span style="display:flex;flex-direction:column;gap:4px;width:44px"><i style="display:block;height:4px;border-radius:2px;background:linear-gradient(90deg,#e8643c 64%,rgba(255,255,255,.2) 64%)"></i><i style="display:block;height:4px;border-radius:2px;background:linear-gradient(90deg,#f5f5f7 44%,rgba(255,255,255,.2) 44%)"></i></span>`];
  S.details = {
    d: 8, poster: 6.2,
    html: () => `<div class="shot" id="sA"><div class="light"></div>
        <div id="keys" style="position:absolute;left:0;right:0;top:250px;display:flex;justify-content:center;align-items:center;gap:26px;color:#6e6e73;font-size:44px;zoom:1.25">
          <div class="key"><b>⌃</b>control</div>+<div class="key"><b>⌥</b>option</div>+<div class="key" style="justify-content:center"><b>L</b></div></div>
        <div class="cap" style="bottom:150px"><span class="ln" id="c1">${T('Open it from anywhere.', 'Her yerden aç.')}</span></div></div>
      <div class="shot" id="sB"><div class="cam" id="cam"><div class="desk"></div><div style="position:absolute;left:0;right:0;top:0;zoom:1.5">${deskBar}</div></div>
        <div class="cap" style="bottom:110px"><span class="ln" id="c2">${T('Lives quietly in your menu bar.', 'Menü çubuğunda sessizce durur.')}</span><span class="ln g" id="c3" style="font-size:40px;margin-top:10px">${T('Four styles. Light or dark.', 'Dört stil. Açık ya da koyu.')}</span></div></div>`,
    init() { this.keys = $$('.key'); this.ic = center($('#icon')); },
    f(t) {
      shot($('#sA'), t, 0, 3.4, .3, .5);
      rise($('#keys'), t, .1, 1.3);
      this.keys.forEach((k, i) => {
        const down = t > .95 + i * .2 && t < 2.1;
        k.style.transform = down ? 'translateY(5px)' : 'none';
        k.style.boxShadow = down ? '0 1px 0 #0c0c0d, 0 2px 6px rgba(0,0,0,.5)' : '';
        k.style.background = down ? '#232325' : '';
      });
      reveal($('#c1'), t, 1.4, { out: 2.9 });
      shot($('#sB'), t, 3.0, 8, .55, .45);
      const sc = 2.9 * (1 + .04 * seg(t, 3, 8)), [cx, cy] = [this.ic[0], this.ic[1] + 120];
      $('#cam').style.transform = `translate(${Math.max(1600 - 1600 * sc, 800 - cx * sc)}px, ${Math.min(0, 450 - cy * sc)}px) scale(${sc})`;
      const step = Math.max(0, Math.floor((t - 3.6) / 1.05)) % 4, ph = ((t - 3.6) / 1.05) % 1;
      const icon = $('#icon'); icon.innerHTML = styleIcons[step]();
      icon.style.opacity = t < 3.6 ? 1 : (ph < .12 ? ph / .12 : ph > .88 ? (1 - ph) / .12 : 1);
      reveal($('#c2'), t, 3.5); reveal($('#c3'), t, 4.3);
    }
  };

  // ===== 9 · Gizlilik (8 sn) =====
  S.privacy = {
    d: 8, poster: 5.2,
    html: () => `<div class="light"></div>
      <svg id="lock" width="120" height="120" viewBox="0 0 24 24" fill="none" stroke="#f5f5f7" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round" style="position:absolute;left:740px;top:96px">
        <rect id="lk1" x="4.5" y="10.5" width="15" height="10.5" rx="2.6"/><path id="lk2" d="M8 10.5V7.2a4 4 0 0 1 8 0v3.3"/></svg>
      <div class="cap" style="top:262px"><span class="ln" id="c1">${T('Your tokens stay on your Mac.', 'Token’ların Mac’inde kalır.')}</span>
        <span class="ln g" id="c2">${T('No middleman. No analytics. No sign‑up.', 'Aracı yok. Analitik yok. Üyelik yok.')}</span></div>
      <div id="list" class="list" style="position:absolute;left:355px;top:400px;zoom:1.3">
        <div class="row"><span class="ic">${logo('claude')}</span><span class="lb">Claude<small>${T('Signed in once, in your browser', 'Tarayıcında bir kez giriş yapıldı')}</small></span><span class="ok">${check}${T('Connected', 'Bağlı')}</span></div>
        <div class="row"><span class="ic">${logo('openai')}</span><span class="lb">Codex<small>${T('Signed in once, in your browser', 'Tarayıcında bir kez giriş yapıldı')}</small></span><span class="ok">${check}${T('Connected', 'Bağlı')}</span></div></div>`,
    init() {
      ['#lk1', '#lk2'].forEach(q => { const e = $(q), L = e.getTotalLength(); e.dataset.l = L; e.style.strokeDasharray = L; });
      this.oks = $$('.list .ok');
    },
    f(t) {
      ['#lk1', '#lk2'].forEach((q, i) => { const e = $(q); e.style.strokeDashoffset = e.dataset.l * (1 - eIO(seg(t, .2 + i * .35, 1.5 + i * .35))); });
      $('#lock').style.transform = `translateY(${-6 * eOut(seg(t, 1.6, 2.4))}px)`;
      reveal($('#c1'), t, 1.2); reveal($('#c2'), t, 2.3);
      rise($('#list'), t, 3.2, 1.3);
      this.oks.forEach((o, i) => { const k = spring(t - 3.9 - i * .35, .4, .55); o.style.opacity = seg(t, 3.9 + i * .35, 4.0 + i * .35); o.style.transform = `scale(${.5 + .5 * k})`; });
    }
  };

  // ===== 10 · İndir (8 sn) =====
  S.cta = {
    d: 8, poster: 4.6,
    html: () => `<div class="light"></div>
      <div style="position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;padding-top:130px">
        <img id="i0" src="icon.png" width="190" height="190" style="filter:drop-shadow(0 30px 60px rgba(0,0,0,.65))">
        <div class="wordmark" id="i1" style="margin-top:34px">AI Limit Tracker</div>
        <div class="cap small" id="i2" style="position:static;margin-top:10px">${T('Free for macOS 14 and later.', 'macOS 14 ve üstü için ücretsiz.')}</div>
        <div class="code" id="i3" style="margin-top:46px"><span><span class="p">$</span> </span><button>${T('Copy', 'Kopyala')}</button></div>
        <div id="i4" style="margin-top:24px;font-size:22px;color:#2997ff">github.com/bahadirnuroglu/ai_limit_tracker</div></div>`,
    init() { this.full = 'curl -fsSL https://raw.githubusercontent.com/bahadirnuroglu/ai_limit_tracker/main/install.sh | bash'; this.cmd = $('#i3 span'); this.btn = $('#i3 button'); },
    f(t) {
      const ik = spring(t - .2, .8, .7);
      $('#i0').style.opacity = seg(t, .2, .6);
      $('#i0').style.transform = `perspective(900px) translateY(${50 * (1 - ik)}px) rotateY(${(1 - ik) * -28 + 6 * Math.sin(t * .9)}deg) scale(${.8 + .2 * ik})`;
      reveal($('#i1'), t, .7); reveal($('#i2'), t, 1.1);
      reveal($('#i3'), t, 1.7, { blur: 6 }); reveal($('#i4'), t, 2.2, { blur: 6 });
      const n = Math.round(this.full.length * eIO(seg(t, 2.0, 3.7)));
      this.cmd.innerHTML = `<span class="p">$</span> ${this.full.slice(0, n)}<span style="display:inline-block;width:10px;height:20px;background:#e5e5ea;vertical-align:-3px;margin-left:2px;opacity:${Math.floor(t * 2.2) % 2 ? .15 : 1}"></span>`;
      const copied = t > 4.2 && t < 6.4;
      this.btn.textContent = copied ? T('Copied ✓', 'Kopyalandı ✓') : T('Copy', 'Kopyala');
      this.btn.style.background = copied ? '#30d158' : '#2c2c2e'; this.btn.style.color = copied ? '#000' : '#f5f5f7';
      this.btn.style.transform = `scale(${1 + .1 * pulse(t, 4.2, .3)})`;
    }
  };

  const scene = S[only] || S.hook;
  stage.innerHTML = scene.html() + '<div class="vig"></div><div class="grain" id="grain"></div>';
  const fadeIn = document.createElement('div'); fadeIn.style.cssText = 'position:absolute;inset:0;background:#000;z-index:45;pointer-events:none';
  stage.appendChild(fadeIn);
  scene.init?.call(scene);
  window.duration = scene.d; window.poster = scene.poster;
  window.frame = t => {
    scene.f.call(scene, t);
    // Açılış ve kapanış siyahtan (döngü dikişsiz), gren kare başına kayar
    fadeIn.style.opacity = Math.max(1 - seg(t, 0, .35), seg(t, scene.d - .4, scene.d));
    $('#grain').style.transform = `translate(${(Math.sin(t * 97) * 40) | 0}px, ${(Math.cos(t * 61) * 40) | 0}px)`;
  };
  window.frame(scene.poster);
})();
