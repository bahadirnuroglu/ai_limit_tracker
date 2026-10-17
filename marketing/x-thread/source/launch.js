// Tanıtım filmi (36 sn): frame(t) sahneyi t saniyesine göre çizer; snapvid kare kare yakalar.
// Kurgu: tanışma → tek bakış → tahmin → bildirim → iki hesap → kartı çevir → yolunda durmaz → bir kez giriş → kapanış.
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
  const center = el => { const r = el.getBoundingClientRect(); return [r.left + r.width / 2, r.top + r.height / 2]; };

  // Çekim: bulanıklıktan netleşerek girer, beyaza bulanıklaşarak çıkar
  function shot(el, t, a, b, fi = .55, fo = .5) {
    const i = eOut(seg(t, a, a + fi)), o = eIO(seg(t, b - fo, b));
    el.style.display = t < a || t > b ? 'none' : 'block';
    el.style.opacity = i * (1 - o);
    el.style.transform = `scale(${1.04 - .04 * i + .03 * o})`;
    el.style.filter = `blur(${10 * (1 - i) + 12 * o}px)`;
  }
  // Kelimeler: her kelime ayrı span; sırayla yukarı kayıp netleşir
  function words(el) {
    (function walk(n) {
      [...n.childNodes].forEach(c => {
        if (c.nodeType === 3) {
          const f = document.createDocumentFragment();
          c.textContent.split(/(\s+)/).forEach(p => { if (!p) return; if (/^\s+$/.test(p)) { f.appendChild(document.createTextNode(p)); return; } const s = document.createElement('span'); s.className = 'wd'; s.textContent = p; f.appendChild(s); });
          c.parentNode.replaceChild(f, c);
        } else if (c.nodeType === 1 && c.tagName !== 'BR') walk(c);
      });
    })(el);
    return [...el.querySelectorAll('.wd')];
  }
  function showWords(list, t, t0, gap = .09, d = .55) {
    list.forEach((w, i) => { const k = eOut(seg(t, t0 + i * gap, t0 + i * gap + d)); w.style.opacity = k; w.style.transform = `translateY(${18 * (1 - k)}px)`; w.style.filter = `blur(${8 * (1 - k)}px)`; });
  }
  const type = (el, text, t, t0, dur) => { const n = Math.round(text.length * seg(t, t0, t0 + dur)); if (el.textContent !== text.slice(0, n)) el.textContent = text.slice(0, n); };

  const TONES = { blue: ['#7fb2ff', '#2f74f0'], purple: ['#a58bff', '#5b3fe0'], red: ['#ff9f0a', '#ff2d20'] };
  const toneOf = p => p >= 90 ? 'red' : p >= 75 ? 'purple' : 'blue';
  function setRing(host, p, f = 1, tone) {
    const val = host.querySelector('.val'), C = +val.dataset.c, v = C * .75 * Math.min(p, 100) / 100 * f;
    val.setAttribute('stroke-dasharray', `${Math.max(.001, v)} ${C}`); val.style.opacity = v < .4 ? 0 : 1;
    if (tone) host.querySelectorAll('stop').forEach((s, i) => s.setAttribute('stop-color', TONES[tone][i]));
    const tx = host.querySelector('.pct'); if (tx) { const n = Math.round(p * Math.min(1, f)); tx.textContent = `${n}%`; tx.style.fontSize = n >= 100 ? '10.5px' : '12.5px'; }
  }
  const setChip = (c, text, kind) => { if (c.textContent !== text) c.textContent = text; c.className = `chip ${kind || ''}`; };
  const fill = (t, t0) => Math.min(1.03, spring(t - t0, 1.0, .85));
  const sway = t => $$('.card').forEach((c, i) => c.querySelectorAll('.holo').forEach((h, k) =>
    h.style.setProperty('--a', `${(k ? 64 : 118) + 26 * Math.sin(2 * Math.PI * (t / 7 + i * .17))}deg`)));
  function openPopup(pop, t, t0) {
    const x = spring(t - t0);
    pop.style.transform = `scale(${.88 + .12 * x})`; pop.style.opacity = seg(t, t0, t0 + .2);
    pop.querySelectorAll('.card').forEach((c, i) => { const y = spring(t - t0 - .08 - i * .07); c.style.transform = `translateY(${-14 * (1 - y)}px)`; c.style.opacity = seg(t, t0 + .08 + i * .07, t0 + .3 + i * .07); });
  }
  function cursor(el, t, keys, show) {
    let p = keys[0][1];
    for (let i = 1; i < keys.length; i++) { const [ta, pa] = keys[i - 1], [tb, pb] = keys[i]; if (t >= tb) p = pb; else if (t > ta) { const k = eIO((t - ta) / (tb - ta)); p = [lerp(pa[0], pb[0], k), lerp(pa[1], pb[1], k)]; break; } }
    el.style.opacity = seg(t, show[0], show[0] + .25) * (1 - seg(t, show[1], show[1] + .25));
    el.style.transform = `translate(${p[0] - 6}px, ${p[1] - 3}px)`;
  }

  const note = (t, b, time) => `<div class="note"><span class="appicon"></span><div><b>${t}</b><span>${b}</span></div><time>${time}</time></div>`;
  const live = () => ({ logo: 'claude', name: 'Claude', plan: 'PRO', chip: pace('1 hour'), chips: [[PERSONAL, 'on'], [WORK]],
    rings: [{ p: 93, tone: 'red', l: H5, r: tm(1, 12) }, { p: 41, tone: 'blue', l: WK, r: td(3, 17) }] });
  const plain = () => ({ logo: 'claude', name: 'Claude', plan: 'PRO', chip: pace('2 hours'),
    rings: [{ p: 91, tone: 'red', l: H5, r: tm(1, 12) }, { p: 41, tone: 'blue', l: WK, r: td(3, 17) }] });
  const cursorSvg = `<svg class="cur2" viewBox="0 0 24 24"><path d="M5 2.5l14 8.6-6.3 1.4 3.7 6.9-2.8 1.5-3.7-6.9L5 18.6Z" fill="#000" stroke="#fff" stroke-width="1.3" stroke-linejoin="round"/></svg>`;
  const check = `<svg width="20" height="20" viewBox="0 0 24 24"><circle cx="12" cy="12" r="11" fill="#34c759"/><path d="M7 12.5l3.2 3L17 9" fill="none" stroke="#fff" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/></svg>`;
  const styles = [
    () => miniRings(64, 44, 26),
    () => `<span style="display:flex;align-items:center;gap:5px;font:650 14px var(--round);color:#ff3b30">${ring(91, 'red', 22, 3.2, false)}91% · 22m</span>`,
    () => `<span style="display:flex;gap:6px;align-items:center">${logo('claude', 'width="13" height="13" fill="#e8643c"')}${ring(64, 'red', 20, 3, false)}${logo('openai', 'width="13" height="13" fill="#1d1d1f"')}${ring(44, 'blue', 20, 3, false)}</span>`,
    () => `<span style="display:flex;flex-direction:column;gap:5px;width:52px"><i style="display:block;height:5px;border-radius:3px;background:linear-gradient(90deg,#e8643c 64%,rgba(0,0,0,.14) 64%)"></i><i style="display:block;height:5px;border-radius:3px;background:linear-gradient(90deg,#1d1d1f 44%,rgba(0,0,0,.14) 44%)"></i></span>`];

  stage.innerHTML = `<div class="bg" id="bg"></div>
    <div class="shot" id="s1"><div class="t center" style="top:388px;font-size:84px;display:flex;justify-content:center;align-items:center;gap:24px">
      <span id="meet">Meet</span><img id="ic" src="icon.png" width="104" height="104" style="filter:drop-shadow(0 14px 28px rgba(60,40,90,.18))"><span id="wm"></span></div></div>
    <div class="shot" id="s2"><div class="t center" id="h2" style="top:92px;font-size:76px">Every AI limit.<span class="g"> One glance.</span></div>
      <div id="pop2" style="position:absolute;left:0;right:0;top:236px;display:flex;justify-content:center"><div style="zoom:2.6">${popup([live(), codex])}</div></div></div>
    <div class="shot" id="s3"><div class="t left" id="c3">Knows when<br>you’ll <span class="a">hit the wall.</span></div>
      <div id="card3" style="position:absolute;left:800px;top:330px"><div style="zoom:2.9">${card(plain())}</div></div></div>
    <div class="shot" id="s4"><div class="t left" id="c4">A heads‑up<br>at <span class="a">75% and 90%.</span></div>
      <div class="panel" id="pn4" style="left:830px;top:110px;width:900px;height:900px"><div class="lwall"></div><div style="position:absolute;left:0;right:0;top:0;zoom:1.5">${mbar()}</div>
        <div id="stack" style="position:absolute;left:36px;top:64px;display:flex;flex-direction:column;gap:12px;zoom:1.55">
          ${note('Claude · 5 hours 90%', 'You’re very close to the limit. Resets in 1 h 12 m.', 'now')}
          ${note('Codex · Weekly 75%', 'You’ve used three quarters of your limit.', '40m ago')}
          ${note('Claude · Your 5‑hour limit reset', 'Pick up right where you left off.', '14:36')}</div></div></div>
    <div class="shot" id="s5"><div class="t left" id="c5a" style="margin-top:-46px">Personal</div><div class="t left" id="c5b" style="margin-top:38px">and <span class="a">work.</span></div>
      <div id="card5" style="position:absolute;left:800px;top:300px"><div style="zoom:2.7">${card(live())}</div></div>${cursorSvg}</div>
    <div class="shot" id="s6"><div class="t center" id="c6" style="top:92px;font-size:72px">Flip it for <span class="g">the full picture.</span></div>
      <div style="position:absolute;left:0;right:0;top:250px;bottom:40px;display:flex;align-items:center;justify-content:center;perspective:2400px">
        <div id="ff" style="zoom:2.5;position:absolute">${card(live())}</div><div id="fb" style="zoom:2.15;position:absolute">${backCard('claude')}</div></div>${cursorSvg}</div>
    <div class="shot" id="s7"><div class="t left" id="c7" style="top:330px">Built to stay<br><span class="g">out of your way.</span></div>
      <div id="keys" style="position:absolute;left:96px;top:418px;display:flex;gap:18px;align-items:center;color:#86868b;font-size:34px;zoom:1.25"><div class="key"><b>⌃</b>control</div>+<div class="key"><b>⌥</b>option</div>+<div class="key" style="justify-content:center"><b>L</b></div></div>
      <div class="panel" id="bar7" style="left:820px;top:200px;width:900px;height:500px;border-radius:30px 0 0 30px"><div class="lwall"></div>
        <div style="position:absolute;left:0;right:0;top:0;height:120px;background:rgba(255,255,255,.55);-webkit-backdrop-filter:blur(30px);display:flex;align-items:center;gap:44px;padding-left:44px;font-size:34px;font-weight:500;color:#1d1d1f;letter-spacing:-.01em">
        <span id="slot" style="display:grid;place-items:center;min-width:180px;height:76px;border-radius:16px;background:rgba(0,0,0,.1)"><span id="slotIn" style="zoom:2.2;display:flex"></span></span><span>Wi‑Fi</span><span>Mon 17:12</span></div></div>
    <div class="shot" id="s8"><div class="t" id="c8" style="left:900px;top:330px;font-size:74px;width:640px">Claude <span class="g">and</span> Codex.<span class="ln" id="c8b" style="margin-top:22px;font-size:34px;font-weight:500;letter-spacing:-.012em;color:#86868b;line-height:1.3">Sign in once, in your own browser. Your tokens stay on your Mac.</span></div>
      <div id="lst" style="position:absolute;left:-60px;top:330px"><div class="list" style="zoom:1.5;box-shadow:0 30px 80px rgba(40,30,80,.14),0 0 0 1px rgba(0,0,0,.05)">
        <div class="row"><span class="ic">${logo('claude')}</span><span class="lb">Claude<small>Signed in with your browser</small></span><span class="ok">${check}Connected</span></div>
        <div class="row"><span class="ic">${logo('openai')}</span><span class="lb">Codex<small>Signed in with your browser</small></span><span class="ok">${check}Connected</span></div></div></div></div>
    <div class="shot" id="s9"><div style="position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:20px">
      <img id="o0" src="icon.png" width="150" height="150" style="filter:drop-shadow(0 20px 40px rgba(60,40,90,.2))">
      <div id="o1" style="font-size:76px;font-weight:650;letter-spacing:-.035em">AI Limit Tracker</div>
      <div id="o2" style="font-size:42px;font-weight:500;letter-spacing:-.02em;min-height:52px"></div>
      <div id="o3" style="margin-top:6px;display:flex;align-items:center;gap:14px;font-size:24px;color:#86868b;font-weight:500">Free for macOS · ${logo('claude', 'width="24" height="24" fill="#86868b"')}${logo('openai', 'width="24" height="24" fill="#86868b"')}</div></div></div>
    <div class="wash" id="wash"></div>`;

  // Hazırlık
  const W = { c3: words($('#c3')), c4: words($('#c4')), c5a: words($('#c5a')), c5b: words($('#c5b')), c6: words($('#c6')), c7: words($('#c7')), c8: words($('#c8')), h2: words($('#h2')) };
  const pop2 = $('#pop2');
  $('#pop2 .popup').style.transformOrigin = '50% 0';
  const notes = $$('#stack .note'), noteH = notes.map(n => n.offsetHeight + 12);
  const card5 = $('#card5 .card'), chips5 = [...card5.querySelectorAll('.chips span')];
  const cells = $$('#fb .hm i').map(c => [c, +c.style.gridColumn.split(' ')[0]]);
  setChip($('#ff .chip'), pace('22 min'), 'hot');
  const keyEls = $$('#keys .key'), okEls = $$('#lst .ok');
  const o2text = 'Never hit a limit mid‑task again.';


  // Ses olayları: Apple'ın kendi sesleri (iOS klavye, şarj, VoiceOver arayüz sesleri, iOS 17 tonları); sfx aracı yerleştirir
  const sfx = [], E = (t, k, g, r) => sfx.push({ t: +t.toFixed(3), k, g: g ?? 1, r: r ?? 1 });
  const cross = (f, v, a, b) => { for (let t = a; t < b; t += 1 / 120) if (f(t) >= v) return t; return b; };
  // Halka dolarken: değer her ~3 puan arttığında ilerleme tıkı, perdesi değerle yükselir
  const fillTicks = (f, a, b, from, to, step = 3, g = 1) => { let next = from + step; for (let t = a; t < b; t += 1 / 120) { const v = f(t); if ((to > from && v >= next) || (to < from && v <= next)) { E(t, 'progress', g, .85 + .7 * (v - Math.min(from, to)) / Math.abs(to - from)); next += to > from ? step : -step; } } };
  E(0.55, 'appear');
  E(4.62, 'popup'); E(5.42, 'charge');                                     // popup açılır, halkalar dolar
  fillTicks(t => 93 * Math.min(1, spring(t - 5.4, 1.0, .85)), 5.4, 6.4, 0, 93, 9, .7);
  const p3 = t => lerp(62, 91, eIO(seg(t, 9.0, 11.2)));
  fillTicks(p3, 9.0, 11.2, 62, 91, 2.5);                                   // tahmin: halka tırmanır
  E(cross(p3, 80, 9, 11.2), 'change'); E(cross(p3, 90, 9, 11.2), 'change', 1.2);
  [13.2, 13.9, 14.6].forEach((t, i) => E(t, 'notify', [.75, .6, .9][i]));  // bildirimler
  E(18.7, 'down'); E(18.79, 'up');                                         // İş hesabına geç
  fillTicks(t => lerp(93, 8, eIO(seg(t, 18.75, 19.4))), 18.75, 19.4, 93, 8, 12, .6);
  E(19.45, 'success', .8);
  E(21.62, 'down'); E(21.71, 'up'); E(21.72, 'slide');                     // kartı çevir
  for (let c = 1; c <= 13; c += 2) E(22.1 + c * .05, 'progress', .45, .9 + c * .045);   // ısı haritası dolar
  [25.8, 25.98].forEach(t => E(t, 'mod')); E(26.16, 'key');                // ⌃ ⌥ L
  [26.2, 27.0, 27.8].forEach(t => E(t, 'change', .6));                     // menü çubuğu stili
  E(29.4, 'success', .7); E(29.7, 'success', .6, 1.12);                    // bağlandı
  E(30.85, 'send');                                                        // beyaza geçiş
  E(31.42, 'welcome');                                                     // kapanış
  window.sfxEvents = sfx;
  window.duration = 36; window.poster = 11.6;
  window.frame = t => {
    $('#bg').style.transform = `translate(${Math.sin(t / 6) * 30}px, ${Math.cos(t / 7) * 20}px) scale(${1.02 + .02 * Math.sin(t / 9)})`;

    // 1 · Tanışma
    shot($('#s1'), t, 0, 3.3, .2, .5);
    { const k = eOut(seg(t, .15, .8)); $('#meet').style.opacity = k; $('#meet').style.filter = `blur(${8 * (1 - k)}px)`; }
    { const k = spring(t - .55, .5, .6); $('#ic').style.opacity = seg(t, .55, .7); $('#ic').style.transform = `scale(${.4 + .6 * k}) rotate(${(1 - Math.min(1, k)) * -18}deg)`; }
    type($('#wm'), 'AI Limit Tracker', t, .95, .85);

    // 2 · Tek bakış: başlık ortada doğar, yukarı kayar; popup alttan, kenardan taşarak gelir
    shot($('#s2'), t, 3.1, 7.8);
    showWords(W.h2.slice(0, 3), t, 3.25); showWords(W.h2.slice(3), t, 4.05);
    { const k = eIO(seg(t, 4.5, 5.6)); $('#h2').style.transform = `translateY(${300 * (1 - k)}px) scale(${1.12 - .12 * k})`; }
    { const k = eOut(seg(t, 4.6, 6.2)); pop2.style.transform = `translateY(${520 * (1 - k)}px)`; pop2.style.opacity = seg(t, 4.6, 5); }
    { const c = $$('#pop2 .card'); const [a, b] = c[0].querySelectorAll('.gauge'), [d, e] = c[1].querySelectorAll('.gauge');
      setRing(a, 93, fill(t, 5.4), 'red'); setRing(b, 41, fill(t, 5.5)); setRing(d, 44, fill(t, 5.55)); setRing(e, 23, fill(t, 5.65));
      setChip(c[0].querySelector('.chip'), pace('22 min'), 'hot'); }

    // 3 · Tahmin
    shot($('#s3'), t, 7.6, 12.3);
    showWords(W.c3, t, 7.9);
    { const k = eOut(seg(t, 7.8, 9.2)); $('#card3').style.transform = `translateX(${(1 - k) * 160}px) scale(${1 + .04 * seg(t, 8, 12.3)})`; }
    { const c = $('#card3 .card'), [g0, g1] = c.querySelectorAll('.gauge'), p = lerp(62, 91, eIO(seg(t, 9.0, 11.2)));
      setRing(g0, p, fill(t, 8.3), toneOf(p)); setRing(g1, 41, fill(t, 8.4), 'blue');
      const chip = c.querySelector('.chip');
      if (p >= 90) setChip(chip, pace('22 min'), 'hot'); else if (p >= 80) setChip(chip, pace('45 min'), ''); else setChip(chip, pace('2 hours'), '');
      chip.style.transform = `scale(${1 + .1 * (pulse(t, 10.2, .4) + pulse(t, 11.1, .45))})`; }

    // 4 · Bildirim
    shot($('#s4'), t, 12.1, 16.5);
    showWords(W.c4, t, 12.4);
    { const k = eOut(seg(t, 12.2, 13.6)); $('#pn4').style.transform = `translate(${(1 - k) * 120}px, ${(1 - k) * 60}px)`; }
    { const at = [14.6, 13.9, 13.2];
      notes.forEach((n, j) => { const k = spring(t - at[j], .55, .8); let sh = 0; for (let i = 0; i < j; i++) sh -= noteH[i] * (1 - spring(t - at[i], .55, .86)); n.style.opacity = seg(t, at[j], at[j] + .2); n.style.transform = `translate(${(1 - k) * 400}px, ${sh}px)`; }); }

    // 5 · İki hesap: "Personal" → "and work."; imleç İş çipine basar, halkalar boşalır
    shot($('#s5'), t, 16.3, 20.7);
    showWords(W.c5a, t, 16.6); showWords(W.c5b, t, 17.4);
    { const k = eOut(seg(t, 16.4, 17.8)); $('#card5').style.transform = `translateX(${(1 - k) * 160}px)`; }
    { const [g0, g1] = card5.querySelectorAll('.gauge'), work = t > 18.75, kk = eIO(seg(t, 18.75, 19.4));
      setRing(g0, work ? lerp(93, 8, kk) : 93, fill(t, 16.9), work && kk > .5 ? 'blue' : 'red'); setRing(g1, work ? lerp(41, 12, kk) : 41, fill(t, 17));
      chips5.forEach((c, i) => c.className = (i === (work ? 1 : 0)) ? 'on' : '');
      const chip = card5.querySelector('.chip'); if (work) setChip(chip, 'Available', 'ok'); else setChip(chip, pace('22 min'), 'hot');
      chip.style.transform = `scale(${1 + .12 * pulse(t, 18.8, .4)})`;
      const target = center(chips5[1]), cur = $('#s5 .cur2');
      cursor(cur, t, [[17.9, [target[0] + 220, target[1] + 160]], [18.6, target], [19.3, target], [19.9, [target[0] + 260, target[1] + 200]]], [17.9, 19.8]);
      if (t > 18.7 && t < 18.84) cur.style.transform += ' scale(.85)'; }

    // 6 · Kartı çevir
    shot($('#s6'), t, 20.5, 24.5);
    showWords(W.c6, t, 20.8);
    { const ff = $('#ff'), fb = $('#fb'), fc = center(ff), cur = $('#s6 .cur2');
      cursor(cur, t, [[21.0, [fc[0] + 240, fc[1] + 200]], [21.55, [fc[0] + 40, fc[1] + 20]], [21.9, [fc[0] + 40, fc[1] + 20]], [22.4, [fc[0] + 340, fc[1] + 260]]], [21.0, 22.3]);
      if (t > 21.62 && t < 21.76) cur.style.transform += ' scale(.85)';
      const ang = 180 * Math.min(1, spring(t - 21.7, .7, .8)), dip = 1 - .06 * Math.sin(Math.PI * ang / 180);
      ff.style.transform = `rotateY(${ang}deg) scale(${dip})`; ff.style.opacity = ang < 90 ? 1 : 0;
      fb.style.transform = `rotateY(${ang - 180}deg) scale(${dip})`; fb.style.opacity = ang >= 90 ? 1 : 0;
      cells.forEach(([c, col]) => { const k = eOut(seg(t, 22.1 + col * .05, 22.5 + col * .05)); c.style.opacity = k; c.style.transform = `scale(${.4 + .6 * k})`; });
      const [g0, g1] = ff.querySelectorAll('.gauge'); setRing(g0, 91, fill(t, 20.8), 'red'); setRing(g1, 41, fill(t, 20.9)); }

    // 7 · Yolunda durmaz: tuşlar basılır, menü çubuğu ikonu stiller arasında değişir
    shot($('#s7'), t, 24.3, 28.7);
    showWords(W.c7, t, 24.6);
    { const k = eOut(seg(t, 25.0, 26.0)); $('#keys').style.opacity = k; $('#keys').style.transform = `translateY(${30 * (1 - k)}px)`; }
    keyEls.forEach((k, i) => { const d = t > 25.8 + i * .18 && t < 26.7; k.style.transform = d ? 'translateY(5px)' : 'none'; k.style.boxShadow = d ? '0 1px 0 #fff inset, 0 1px 0 #d2d2d7, 0 2px 6px rgba(0,0,0,.08)' : ''; k.style.background = d ? '#f2f2f4' : ''; });
    { const k = eOut(seg(t, 24.4, 25.8)); $('#bar7').style.transform = `translateX(${(1 - k) * 200}px)`; }
    { const step = Math.max(0, Math.floor((t - 25.4) / .8)) % 4, ph = ((t - 25.4) / .8) % 1, si = $('#slotIn');
      const html = styles[t < 25.4 ? 0 : step](); if (si.dataset.s !== String(step)) { si.innerHTML = html; si.dataset.s = step; }
      si.style.opacity = t < 25.4 ? 1 : (ph < .15 ? ph / .15 : ph > .85 ? (1 - ph) / .15 : 1); }

    // 8 · Bir kez giriş
    shot($('#s8'), t, 28.5, 31.3, .55, .6);
    showWords(W.c8, t, 28.8, .08);
    { const k = eOut(seg(t, 28.6, 29.8)); $('#lst').style.transform = `translateX(${(k - 1) * 120}px)`; }
    okEls.forEach((o, i) => { const k = spring(t - 29.4 - i * .3, .4, .55); o.style.opacity = seg(t, 29.4 + i * .3, 29.5 + i * .3); o.style.transform = `scale(${.5 + .5 * k})`; });

    // Beyaza bulanıklaşan geçiş
    $('#wash').style.opacity = Math.sin(Math.PI * seg(t, 30.8, 31.7)) * .95;

    // 9 · Kapanış: ikon, ad, yazılan slogan, ücretsiz
    shot($('#s9'), t, 31.2, 36.2, .4, .01);
    { const k = spring(t - 31.4, .6, .65); $('#o0').style.opacity = seg(t, 31.4, 31.6); $('#o0').style.transform = `translateY(${30 * (1 - Math.min(1, k))}px) scale(${.6 + .4 * k})`; }
    { const k = eOut(seg(t, 31.9, 32.7)); $('#o1').style.opacity = k; $('#o1').style.filter = `blur(${10 * (1 - k)}px)`; $('#o1').style.transform = `translateY(${16 * (1 - k)}px)`; }
    type($('#o2'), o2text, t, 32.7, 1.5);
    { const k = eOut(seg(t, 34.4, 35.2)); $('#o3').style.opacity = k; $('#o3').style.transform = `translateY(${12 * (1 - k)}px)`; }
    sway(t);
  };
  window.frame(window.poster);
})();
