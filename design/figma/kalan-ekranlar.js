// AI Limit Tracker — Figma'daki kalan ekranlar (Scripter eklentisinde çalıştırılır)
// Figma: Eklentiler > Scripter > yeni script > bu dosyanın tamamını yapıştır > Çalıştır (▶).
// Starter plan en fazla 3 sayfa: hepsi tek "Ekranlar" sayfasında üç bölüm (Ayarlar, Kurulum, Menü Çubuğu).
// Tekrar çalıştırılabilir: "Ekranlar" sayfasının içini temizleyip baştan kurar.
// Var olan değişkenleri (Tema · Açık / Tema · Koyu) ve yazı stillerini kullanır; eksik "sistem/*" renklerini ekler.

const FONTS = [["SF Pro", "Regular"], ["SF Pro", "Medium"], ["SF Pro", "Semibold"], ["SF Pro", "Bold"], ["SF Pro Rounded", "Semibold"]];
for (const [family, style] of FONTS) await figma.loadFontAsync({ family, style });

// ---------- Değişkenler ----------
const cols = await figma.variables.getLocalVariableCollectionsAsync();
const LIGHT = cols.find(c => c.name === "Tema · Açık"), DARK = cols.find(c => c.name === "Tema · Koyu");
if (!LIGHT || !DARK) throw new Error("Tema · Açık / Tema · Koyu koleksiyonları bulunamadı");
async function varsOf(col) { const m = {}; for (const id of col.variableIds) { const v = await figma.variables.getVariableByIdAsync(id); m[v.name] = v; } return m; }
let L = await varsOf(LIGHT), D = await varsOf(DARK);
// macOS sistem renkleri (Ayarlar ve Kurulum pencereleri)
const SYSTEM = [
  ["sistem/pencere", { r: .925, g: .925, b: .925, a: 1 }, { r: .118, g: .118, b: .118, a: 1 }, ["FRAME_FILL"]],
  ["sistem/bölüm", { r: 1, g: 1, b: 1, a: .7 }, { r: 1, g: 1, b: 1, a: .05 }, ["FRAME_FILL"]],
  ["sistem/ayraç", { r: 0, g: 0, b: 0, a: .1 }, { r: 1, g: 1, b: 1, a: .1 }, ["STROKE_COLOR", "FRAME_FILL", "SHAPE_FILL"]],
  ["sistem/birincil yazı", { r: 0, g: 0, b: 0, a: .85 }, { r: 1, g: 1, b: 1, a: .85 }, ["TEXT_FILL", "SHAPE_FILL"]],
  ["sistem/ikincil yazı", { r: 0, g: 0, b: 0, a: .5 }, { r: 1, g: 1, b: 1, a: .55 }, ["TEXT_FILL", "SHAPE_FILL"]],
  ["sistem/vurgu", { r: 0, g: .478, b: 1, a: 1 }, { r: .04, g: .52, b: 1, a: 1 }, ["FRAME_FILL", "SHAPE_FILL", "TEXT_FILL", "STROKE_COLOR"]],
  ["sistem/kontrol", { r: 0, g: 0, b: 0, a: .06 }, { r: 1, g: 1, b: 1, a: .1 }, ["FRAME_FILL", "SHAPE_FILL"]],
  ["sistem/yeşil", { r: .2, g: .78, b: .35, a: 1 }, { r: .19, g: .82, b: .35, a: 1 }, ["TEXT_FILL", "SHAPE_FILL"]],
];
for (const [name, l, d, scopes] of SYSTEM) {
  if (!L[name]) { const v = figma.variables.createVariable(name, LIGHT, "COLOR"); v.setValueForMode(LIGHT.modes[0].modeId, l); v.scopes = scopes; }
  if (!D[name]) { const v = figma.variables.createVariable(name, DARK, "COLOR"); v.setValueForMode(DARK.modes[0].modeId, d); v.scopes = scopes; }
}
L = await varsOf(LIGHT); D = await varsOf(DARK);

// ---------- Yardımcılar ----------
let T = L; // aktif tema (ekran kurarken L ya da D)
const paint = name => { const v = T[name]; const c = Object.values(v.valuesByMode)[0]; return figma.variables.setBoundVariableForPaint({ type: "SOLID", color: { r: c.r, g: c.g, b: c.b }, opacity: (c.a === undefined ? 1 : c.a) }, "color", v); };
const raw = (r, g, b, a = 1) => ({ type: "SOLID", color: { r, g, b }, opacity: a });
const sym = name => { try { return figma.util.getSfSymbolCharacter(name); } catch (e) { return "●"; } };
function frame(dir, props = {}) {
  const f = figma.createFrame(); f.fills = [];
  if (dir) { f.layoutMode = dir; f.primaryAxisSizingMode = "AUTO"; f.counterAxisSizingMode = "AUTO"; }
  Object.assign(f, props); return f;
}
function add(parent, child, fill) { parent.appendChild(child); if (fill === "x" || fill === "xy") child.layoutSizingHorizontal = "FILL"; if (fill === "y" || fill === "xy") child.layoutSizingVertical = "FILL"; return child; }
function text(chars, { size = 13, style = "Regular", family = "SF Pro", color = "sistem/birincil yazı", width, align, name } = {}) {
  const t = figma.createText(); t.fontName = { family, style }; t.fontSize = size; t.characters = chars;
  t.fills = [paint(color)]; t.name = name || chars.slice(0, 24);
  if (width) { t.textAutoResize = "HEIGHT"; t.resize(width, t.height); } else t.textAutoResize = "WIDTH_AND_HEIGHT";
  if (align) t.textAlignHorizontal = align;
  return t;
}
function symbol(name, size, color, style = "Medium") { const t = text(sym(name), { size, style, color, name: "ikon " + name }); return t; }
function spacer(parent) { const s = frame(null, { name: "boşluk" }); s.resize(1, 1); parent.appendChild(s); s.layoutGrow = 1; return s; }
function tile(symbolName, rgb, size = 52) {
  const f = frame("HORIZONTAL", { name: "simge " + symbolName, primaryAxisAlignItems: "CENTER", counterAxisAlignItems: "CENTER" });
  f.primaryAxisSizingMode = "FIXED"; f.counterAxisSizingMode = "FIXED"; f.resize(size, size); f.cornerRadius = size * 0.24;
  const lighter = { r: Math.min(rgb.r + .12, 1), g: Math.min(rgb.g + .12, 1), b: Math.min(rgb.b + .12, 1) };
  f.fills = [{ type: "GRADIENT_LINEAR", gradientTransform: [[0, 1, 0], [-1, 0, 1]], gradientStops: [{ position: 0, color: { ...lighter, a: 1 } }, { position: 1, color: { ...rgb, a: 1 } }] }];
  const t = text(sym(symbolName), { size: Math.round(size * 0.46), style: "Semibold" }); t.fills = [raw(1, 1, 1)]; f.appendChild(t);
  return f;
}
function toggle(on = true) {
  const f = frame(null, { name: on ? "anahtar açık" : "anahtar kapalı" }); f.resize(32, 18); f.cornerRadius = 9;
  f.fills = [on ? paint("sistem/vurgu") : paint("sistem/kontrol")];
  const k = figma.createEllipse(); k.resize(16, 16); k.y = 1; k.x = on ? 15 : 1; k.fills = [raw(1, 1, 1)];
  k.effects = [{ type: "DROP_SHADOW", color: { r: 0, g: 0, b: 0, a: .25 }, offset: { x: 0, y: .5 }, radius: 1, spread: 0, visible: true, blendMode: "NORMAL" }];
  f.appendChild(k); return f;
}
function button(label, prominent = false, small = false) {
  const f = frame("HORIZONTAL", { name: "düğme " + label, paddingLeft: small ? 8 : 12, paddingRight: small ? 8 : 12, paddingTop: small ? 3 : 5, paddingBottom: small ? 3 : 5, cornerRadius: small ? 5 : 6 });
  f.fills = [prominent ? paint("sistem/vurgu") : paint("sistem/kontrol")];
  const t = text(label, { size: small ? 11 : 13, style: prominent ? "Medium" : "Regular" }); if (prominent) t.fills = [raw(1, 1, 1)];
  f.appendChild(t); return f;
}
function keycaps(keys) {
  const f = frame("HORIZONTAL", { name: "kısayol", itemSpacing: 4 });
  for (const k of keys) {
    const c = frame("HORIZONTAL", { name: k, primaryAxisAlignItems: "CENTER", counterAxisAlignItems: "CENTER", paddingLeft: 3, paddingRight: 3 });
    c.counterAxisSizingMode = "FIXED"; c.resize(22, 22); c.primaryAxisSizingMode = "AUTO"; c.minWidth = 22; c.cornerRadius = 5;
    c.fills = [paint("sistem/bölüm")]; c.strokes = [paint("sistem/ayraç")]; c.strokeWeight = 1;
    c.appendChild(text(k, { size: 12, style: "Semibold", family: "SF Pro Rounded" })); f.appendChild(c);
  }
  return f;
}
// macOS gruplu Form bölümü: yuvarlak köşeli, satırlar arası ince ayraç
function section(parent, rows, { header, footer } = {}) {
  const wrap = add(parent, frame("VERTICAL", { name: "bölüm", itemSpacing: 6 }), "x");
  if (header) add(wrap, text(header, { size: 11, style: "Semibold", color: "sistem/ikincil yazı" }));
  const box = add(wrap, frame("VERTICAL", { name: "satırlar", cornerRadius: 10 }), "x");
  box.fills = [paint("sistem/bölüm")]; box.strokes = [paint("sistem/ayraç")]; box.strokeWeight = .5;
  rows.forEach((r, i) => {
    if (i > 0) { const sep = figma.createRectangle(); sep.name = "ayraç"; sep.resize(100, .5); sep.fills = [paint("sistem/ayraç")]; add(box, sep, "x"); }
    add(box, r, "x");
  });
  if (footer) add(wrap, text(footer, { size: 11, color: "sistem/ikincil yazı", width: 480 }), "x");
  return wrap;
}
function row(children, { indent = 0, align = "CENTER" } = {}) {
  const r = frame("HORIZONTAL", { name: "satır", itemSpacing: 10, counterAxisAlignItems: align, paddingLeft: 10 + indent, paddingRight: 10, paddingTop: 8, paddingBottom: 8 });
  for (const c of children) { if (c === "spacer") spacer(r); else r.appendChild(c); }
  return r;
}
function titled(title, detail, width = 300) {
  const v = frame("VERTICAL", { name: "başlık", itemSpacing: 2 });
  v.appendChild(text(title, { size: 13, style: "Medium" }));
  if (detail) v.appendChild(text(detail, { size: 12, color: "sistem/ikincil yazı", width }));
  return v;
}
// logo bileşeni (Bileşenler sayfasındaki "Logo" seti)
const compPage = figma.root.children.find(p => p.name === "Bileşenler");
await figma.setCurrentPageAsync(compPage);
const logoSet = compPage.findOne(n => n.type === "COMPONENT_SET" && n.name === "Logo");
function logoTile(provider) {
  const f = frame("HORIZONTAL", { name: "logo " + provider, primaryAxisAlignItems: "CENTER", counterAxisAlignItems: "CENTER" });
  f.primaryAxisSizingMode = "FIXED"; f.counterAxisSizingMode = "FIXED"; f.resize(30, 30); f.cornerRadius = 7; f.fills = [paint("sistem/kontrol")];
  const v = logoSet && logoSet.children.find(c => c.name === "Sağlayıcı=" + provider);
  if (v) { const i = v.createInstance(); i.resize(18, 18); f.appendChild(i); }
  return f;
}
// pencere: başlık çubuğu (trafik ışıkları) + içerik
function window(name, w, h, title, { transparentTitle = false } = {}) {
  const win = frame("VERTICAL", { name }); win.primaryAxisSizingMode = "FIXED"; win.counterAxisSizingMode = "FIXED"; win.resize(w, h);
  win.cornerRadius = 12; win.clipsContent = true; win.fills = [paint("sistem/pencere")]; win.strokes = [paint("sistem/ayraç")]; win.strokeWeight = .5;
  win.effects = [{ type: "DROP_SHADOW", color: { r: 0, g: 0, b: 0, a: .25 }, offset: { x: 0, y: 16 }, radius: 40, spread: 0, visible: true, blendMode: "NORMAL" }];
  const bar = add(win, frame("HORIZONTAL", { name: "başlık çubuğu", itemSpacing: 8, counterAxisAlignItems: "CENTER", paddingLeft: 12, paddingRight: 12 }), "x");
  bar.counterAxisSizingMode = "FIXED"; bar.resize(w, 28);
  for (const c of [[1, .37, .34], [1, .74, .18], [.16, .79, .25]]) { const e = figma.createEllipse(); e.resize(12, 12); e.fills = [raw(...c)]; bar.appendChild(e); }
  if (!transparentTitle) { spacer(bar); bar.appendChild(text(title, { size: 13, style: "Semibold" })); spacer(bar); const pad = frame(null); pad.resize(52, 1); bar.appendChild(pad); }
  return win;
}

// ---------- Sayfalar ----------
let screens = figma.root.children.find(p => p.name === "Ekranlar" || p.name === "Ayarlar" || p.name === "Kurulum" || p.name === "Menü Çubuğu");
if (!screens) screens = figma.createPage();
screens.name = "Ekranlar";
await figma.setCurrentPageAsync(screens);
for (const n of [...screens.children]) n.remove();
// her bölüm bir Section; içerik bölümün içine kurulur
function makeSection(name, y, w, h) { const s = figma.createSection(); s.name = name; screens.appendChild(s); s.x = -40; s.y = y; s.resizeWithoutConstraints(w, h); return s; }
const secSettings = makeSection("Ayarlar", -40, 2500, 600);
const secSetup = makeSection("Kurulum", 640, 3640, 720);
const secMenu = makeSection("Menü Çubuğu", 1440, 560, 260);
const into = (sec, node, x, y) => { sec.appendChild(node); node.x = x; node.y = y; };

// ============ AYARLAR (560×500, sekmeler) ============
const TABS = [["Sağlayıcılar", "square.stack.3d.up"], ["Menü Çubuğu", "menubar.rectangle"], ["Bildirimler", "bell.badge"], ["Genel", "gearshape"]];
function settingsWindow(selected) {
  const win = window("Ayarlar · " + TABS[selected][0], 560, 500, "AI Limit Tracker Ayarları");
  const tb = add(win, frame("HORIZONTAL", { name: "sekmeler", itemSpacing: 2, primaryAxisAlignItems: "CENTER", paddingBottom: 8 }), "x");
  TABS.forEach(([label, icon], i) => {
    const t = frame("VERTICAL", { name: label, itemSpacing: 2, counterAxisAlignItems: "CENTER", paddingLeft: 10, paddingRight: 10, paddingTop: 4, paddingBottom: 4, cornerRadius: 6 });
    if (i === selected) t.fills = [paint("sistem/kontrol")];
    t.appendChild(symbol(icon, 17, i === selected ? "sistem/vurgu" : "sistem/ikincil yazı"));
    t.appendChild(text(label, { size: 11, color: i === selected ? "sistem/vurgu" : "sistem/ikincil yazı" }));
    tb.appendChild(t);
  });
  const sep = figma.createRectangle(); sep.resize(560, .5); sep.fills = [paint("sistem/ayraç")]; add(win, sep, "x");
  const body = add(win, frame("VERTICAL", { name: "içerik", itemSpacing: 18, paddingLeft: 20, paddingRight: 20, paddingTop: 18, paddingBottom: 18 }), "xy");
  return { win, body };
}
// 1) Sağlayıcılar
{
  const { win, body } = settingsWindow(0);
  const connected = () => { const l = frame("HORIZONTAL", { name: "bağlı", itemSpacing: 4, counterAxisAlignItems: "CENTER" }); l.appendChild(symbol("checkmark.circle.fill", 12, "sistem/yeşil")); l.appendChild(text("Bağlı", { size: 12, style: "Medium", color: "sistem/yeşil" })); return l; };
  const provRow = (p, detail) => row([logoTile(p), titled(p, detail, 260), "spacer", connected(), toggle(true)]);
  const accRow = (initial, name, meta, value) => {
    const av = frame("HORIZONTAL", { name: "baş harf", primaryAxisAlignItems: "CENTER", counterAxisAlignItems: "CENTER" }); av.primaryAxisSizingMode = "FIXED"; av.counterAxisSizingMode = "FIXED"; av.resize(24, 24); av.cornerRadius = 12; av.fills = [paint("sistem/kontrol")];
    av.appendChild(text(initial, { size: 11, style: "Semibold", family: "SF Pro Rounded", color: "sistem/ikincil yazı" }));
    return row([av, titled(name, meta, 260), "spacer", text(value, { size: 12, style: "Medium", color: "sistem/ikincil yazı" }), symbol("ellipsis.circle", 14, "sistem/ikincil yazı")], { indent: 40 });
  };
  const addRow = label => { const r = row([symbol("plus.circle.fill", 13, "sistem/vurgu"), text(label, { size: 13, color: "sistem/vurgu" })], { indent: 40 }); r.itemSpacing = 6; return r; };
  section(body, [provRow("Claude", "Pro · 5 saat %42"), accRow("B", "bireysel", "Claude Code", "%42"), accRow("İ", "iş", "claude.ai", "%0"), addRow("Hesap Ekle…")]);
  section(body, [provRow("Codex", "Team · 5 saat %0"), addRow("Başka bir Codex hesabı ekle…")]);
  section(body, [provRow("Cursor", "Free · Aylık %0"), addRow("Başka bir Cursor hesabı ekle…")],
    { footer: "Birden çok hesapta popup'taki kartın sol altında hesap çipleri çıkar. Kapalı sağlayıcılar popup'ta ve menü çubuğunda gösterilmez." });
  into(secSettings, win, 40, 50);
}
// 2) Menü Çubuğu
{
  const { win, body } = settingsWindow(1);
  const styles = [["Son kullanılan iki", "En son kullandığın iki sağlayıcı, iç içe halkalar", true], ["En dolu", "Limite en yakın sağlayıcı, ortasında logosu", false], ["Yan yana", "Her sağlayıcı kendi halkası ve logosuyla", false], ["Barlar", "Her sağlayıcı için ince bir bar", false]];
  const grid = frame("VERTICAL", { name: "stiller", itemSpacing: 10 });
  for (let r = 0; r < 2; r++) {
    const line = add(grid, frame("HORIZONTAL", { name: "sıra", itemSpacing: 10 }), "x");
    for (let c = 0; c < 2; c++) {
      const [title, detail, sel] = styles[r * 2 + c];
      const card = add(line, frame("VERTICAL", { name: title, itemSpacing: 6, paddingLeft: 10, paddingRight: 10, paddingTop: 10, paddingBottom: 10, cornerRadius: 10 }), "x");
      card.fills = [paint("sistem/bölüm")]; card.strokes = [sel ? paint("sistem/vurgu") : paint("sistem/ayraç")]; card.strokeWeight = sel ? 2 : .5;
      const strip = add(card, frame("HORIZONTAL", { name: "menü çubuğu önizleme", primaryAxisAlignItems: "CENTER", counterAxisAlignItems: "CENTER" }), "x");
      strip.counterAxisSizingMode = "FIXED"; strip.resize(200, 30); strip.cornerRadius = 6; strip.fills = [raw(.29, .45, .93, .9)];
      const hint = text("(Menü Çubuğu sayfasındaki ikon)", { size: 9 }); hint.fills = [raw(1, 1, 1, .8)]; strip.appendChild(hint);
      const tt = add(card, frame("HORIZONTAL", { name: "ad", itemSpacing: 4, counterAxisAlignItems: "CENTER" }));
      tt.appendChild(text(title, { size: 13, style: "Medium" }));
      if (sel) tt.appendChild(symbol("checkmark.circle.fill", 12, "sistem/vurgu"));
      add(card, text(detail, { size: 11, color: "sistem/ikincil yazı", width: 220 }), "x");
    }
  }
  const s = section(body, [], { header: "Simge", footer: "Önizlemeler şu anki limitlerinle çizilir. Hangi sağlayıcıların gösterileceğini Sağlayıcılar sekmesinden seçebilirsin." });
  const box = s.children.find(n => n.name === "satırlar"); box.fills = []; box.strokes = []; add(box, grid, "x");
  into(secSettings, win, 660, 50);
}
// 3) Bildirimler
{
  const { win, body } = settingsWindow(2);
  const kinds = [["gauge.with.dots.needle.67percent", { r: .2, g: .5, b: 1 }, "Limitin %75'ine ulaşınca", "Hızını ayarlaman için erken uyarı"],
    ["exclamationmark.triangle.fill", { r: 1, g: .58, b: 0 }, "Limitin %90'ına ulaşınca", "Limite çok yaklaştığında"],
    ["arrow.counterclockwise.circle.fill", { r: .2, g: .75, b: .4 }, "Limit yenilenince", "Yüksek kullandığın limit sıfırlanınca, devam edebileceğini bildirir"],
    ["alarm", { r: .6, g: .4, b: .95 }, "İstediğin limit açılınca", "Bir karta sağ tıklayıp \"açılınca haber ver\" seçerek tek seferlik hatırlatma kurarsın"]];
  section(body, kinds.map(([s, c, t, d]) => row([tile(s, c, 26), titled(t, d, 330), "spacer", toggle(true)])), { header: "Haber ver" });
  into(secSettings, win, 1280, 50);
}
// 4) Genel
{
  const { win, body } = settingsWindow(3);
  section(body, [row([text("Mac açılınca başlat", { size: 13 }), "spacer", toggle(true)]), row([text("Kısayol", { size: 13 }), "spacer", keycaps(["⌃", "⌥", "L"])])]);
  section(body, [row([titled("Sürüm 0.3.4", "En son sürümü kullanıyorsun · son kontrol 14:20", 300), "spacer", button("Güncellemeleri Denetle")]),
    row([button("Tanılama Bilgisini Kopyala"), "spacer", button("Kurulumu Yeniden Başlat")])],
    { footer: "Tanılama bilgisi sürüm, macOS ve her sağlayıcının durumunu içerir; token ya da hesap bilgisi içermez." });
  into(secSettings, win, 1900, 50);
}

// ============ KURULUM (540×620, 6 adım) ============
function setupWindow(name, { title, subtitle, tile: t, back = true, primary = "Devam", note }) {
  const win = window("Kurulum · " + name, 540, 620, "", { transparentTitle: true });
  const content = add(win, frame("VERTICAL", { name: "sayfa", itemSpacing: 18, counterAxisAlignItems: "CENTER", paddingLeft: 32, paddingRight: 32, paddingTop: 16 }), "xy");
  const head = add(content, frame("VERTICAL", { name: "başlık", itemSpacing: 10, counterAxisAlignItems: "CENTER" }), "x");
  if (t) head.appendChild(t);
  head.appendChild(text(title, { size: 26, style: "Bold", width: 440, align: "CENTER" }));
  head.appendChild(text(subtitle, { size: 13, color: "sistem/ikincil yazı", width: 400, align: "CENTER" }));
  const sep = figma.createRectangle(); sep.resize(540, .5); sep.fills = [paint("sistem/ayraç")]; add(win, sep, "x");
  const foot = add(win, frame("HORIZONTAL", { name: "alt", itemSpacing: 10, counterAxisAlignItems: "CENTER", paddingLeft: 24, paddingRight: 24, paddingTop: 16, paddingBottom: 16 }), "x");
  if (back) foot.appendChild(button("Geri"));
  spacer(foot);
  if (note) foot.appendChild(text(note, { size: 11, color: "sistem/ikincil yazı" }));
  foot.appendChild(button(primary, true));
  return { win, content };
}
const steps = [];
// 1 Hoş geldin
{
  const appTile = tile("gauge.with.dots.needle.50percent", { r: .55, g: .55, b: .58 }, 72);
  const { win, content } = setupWindow("Hoş geldin", { title: "AI Limit Tracker'a Hoş Geldin", subtitle: "Claude, Codex ve Cursor limitlerini menü çubuğunda tek bakışta gör.", tile: appTile, back: false, primary: "Başla" });
  const list = add(content, frame("VERTICAL", { name: "özellikler", itemSpacing: 18, paddingLeft: 24, paddingRight: 24, paddingTop: 12 }), "x");
  for (const [s, c, t, d] of [["gauge.with.dots.needle.50percent", { r: 1, g: .58, b: 0 }, "Tüm limitler tek yerde", "5 saatlik ve haftalık pencereler, sıfırlanmaya kalan süre ve bu tempoyla ne zaman dolacağı."],
    ["bell.badge.fill", { r: 1, g: .23, b: .19 }, "Limite takılmadan haber al", "Limite yaklaşınca ve limit yenilenince bildirim; hangilerini alacağını sen seçersin."],
    ["lock.fill", { r: .2, g: .5, b: 1 }, "Verilerin sende kalır", "Sadece bağladığın hizmetlerle ve bu Mac'teki uygulamalarla konuşur, başka sunucuya veri göndermez."]]) {
    const r = add(list, frame("HORIZONTAL", { name: t, itemSpacing: 14, counterAxisAlignItems: "MIN" }), "x");
    r.appendChild(tile(s, c, 36));
    const v = frame("VERTICAL", { name: "metin", itemSpacing: 2 }); v.appendChild(text(t, { size: 13, style: "Semibold" })); v.appendChild(text(d, { size: 12, color: "sistem/ikincil yazı", width: 360 })); r.appendChild(v);
  }
  steps.push(win);
}
// 2 Araçlar
{
  const { win, content } = setupWindow("Araçlar", { title: "Hangi araçları kullanıyorsun?", subtitle: "Bu Mac'te bulduklarımızı açtık. Sonradan Ayarlar'dan değiştirebilirsin.", tile: tile("square.stack.3d.up.fill", { r: .35, g: .34, b: .84 }) });
  section(content, [["Claude", "Claude Code bulundu"], ["Codex", "Codex CLI girişi bulundu"], ["Cursor", "Cursor bulundu"]].map(([p, d]) => row([logoTile(p), titled(p, d, 280), "spacer", toggle(true)])));
  steps.push(win);
}
// 3 Bağlan
{
  const { win, content } = setupWindow("Bağlan", { title: "Hesaplarını bağla", subtitle: "Çoğu araç kendi oturumundan okunur, şifre gerekmez. Bağlanmayanları popup'tan sonra da bağlayabilirsin.", tile: tile("link", { r: .2, g: .5, b: 1 }) });
  const ok = () => { const l = frame("HORIZONTAL", { itemSpacing: 4, counterAxisAlignItems: "CENTER", name: "bağlı" }); l.appendChild(symbol("checkmark.circle.fill", 12, "sistem/yeşil")); l.appendChild(text("Bağlı", { size: 12, style: "Medium", color: "sistem/yeşil" })); return l; };
  section(content, [row([logoTile("Claude"), titled("Claude", "Claude Code oturumu kullanılır. macOS bir kez Mac parolanı isteyecek; Her Zaman İzin Ver'i seç.", 250), "spacer", button("İzin Ver", true, true)]),
    row([logoTile("Codex"), titled("Codex", "Team · 5 saat %0", 250), "spacer", ok()]),
    row([logoTile("Cursor"), titled("Cursor", "cursor.com hesabınla giriş yap.", 250), "spacer", button("Giriş Yap", true, true)])],
    { footer: "Aynı araçta birden çok hesabın mı var? Kurulumdan sonra Ayarlar → Sağlayıcılar → Hesap Ekle ile ekleyebilir, popup'ta aralarında geçebilirsin." });
  steps.push(win);
}
// 4 Bildirimler
{
  const { win, content } = setupWindow("Bildirimler", { title: "Bildirimler", subtitle: "Hangi anlarda haber vermemizi istediğini seç. Hiçbiri gürültü yapmaz: her eşik, her pencerede bir kez gelir.", tile: tile("bell.badge.fill", { r: 1, g: .23, b: .19 }) });
  section(content, [row([titled("Bildirim izni", "Bildirimlerin gelmesi için macOS izni gerekiyor.", 300), "spacer", button("İzin Ver", true, true)])]);
  section(content, [["Limitin %75'ine ulaşınca", "Hızını ayarlaman için erken uyarı"], ["Limitin %90'ına ulaşınca", "Limite çok yaklaştığında"], ["Limit yenilenince", "Yüksek kullandığın limit sıfırlanınca, devam edebileceğini bildirir"], ["İstediğin limit açılınca", "Karta sağ tıklayıp tek seferlik hatırlatma kurarsın"]]
    .map(([t, d]) => row([titled(t, d, 340), "spacer", toggle(true)])));
  steps.push(win);
}
// 5 Genel
{
  const { win, content } = setupWindow("Genel", { title: "Her zaman elinin altında", subtitle: "Mac açılınca kendiliğinden başlasın, istediğin yerden bir kısayolla açılsın.", tile: tile("menubar.arrow.up.rectangle", { r: .19, g: .69, b: .78 }) });
  section(content, [row([symbol("power", 14, "sistem/ikincil yazı"), titled("Mac açılınca başlat", "Önerilir; limitlerini her zaman menü çubuğunda görürsün.", 300), "spacer", toggle(true)]),
    row([symbol("command", 14, "sistem/ikincil yazı"), titled("Kısayol", "Popup'ı her uygulamadan açar ve kapatır.", 300), "spacer", keycaps(["⌃", "⌥", "L"])])]);
  steps.push(win);
}
// 6 Hazır
{
  const { win, content } = setupWindow("Hazır", { title: "Hazırsın", subtitle: "3 sağlayıcı bağlı. AI Limit Tracker menü çubuğunun sağ üstünde, halka simgesiyle duruyor.", tile: tile("checkmark", { r: .2, g: .75, b: .4 }), back: false, primary: "Popup'ı Göster" });
  const mb = add(content, frame("HORIZONTAL", { name: "menü çubuğu örneği", itemSpacing: 12, counterAxisAlignItems: "CENTER", paddingLeft: 14, paddingRight: 14, paddingTop: 6, paddingBottom: 6, cornerRadius: 8 }));
  mb.fills = [paint("sistem/bölüm")]; mb.strokes = [paint("sistem/ayraç")]; mb.strokeWeight = .5;
  for (const s of ["wifi", "battery.75percent"]) mb.appendChild(symbol(s, 13, "sistem/ikincil yazı"));
  const ring = figma.createEllipse(); ring.resize(18, 18); ring.arcData = { startingAngle: 3 * Math.PI / 4, endingAngle: 3 * Math.PI / 4 + 1.5 * Math.PI * .42, innerRadius: .7 }; ring.fills = [raw(.85, .47, .34)]; ring.name = "uygulama simgesi"; mb.appendChild(ring);
  mb.appendChild(text("Çar 17:54", { size: 12, style: "Medium" }));
  const hk = add(content, frame("HORIZONTAL", { name: "kısayol ipucu", itemSpacing: 8, counterAxisAlignItems: "CENTER" }));
  hk.appendChild(text("Ya da her yerden", { size: 13, color: "sistem/ikincil yazı" })); hk.appendChild(keycaps(["⌃", "⌥", "L"]));
  steps.push(win);
}
steps.forEach((w, i) => into(secSetup, w, 40 + i * 600, 50));

// ============ MENÜ ÇUBUĞU İKONLARI (22 pt) ============
const ARC0 = 3 * Math.PI / 4, ARCS = 1.5 * Math.PI;
function arc(size, p, rgb, inner = .72, alpha = 1) { const e = figma.createEllipse(); e.resize(size, size); e.arcData = { startingAngle: ARC0, endingAngle: ARC0 + ARCS * Math.max(p, .02), innerRadius: inner }; e.fills = [raw(rgb.r, rgb.g, rgb.b, alpha)]; return e; }
const ORANGE = { r: .85, g: .47, b: .34 }, BLUE = { r: .42, g: .55, b: .98 };
function icon(style, dark) {
  const ink = dark ? { r: 1, g: 1, b: 1 } : { r: 0, g: 0, b: 0 };
  const f = frame(null, { name: style }); f.resize(style === "Barlar" ? 22 : style === "Yan yana" ? 44 : 22, 22); f.clipsContent = false;
  const put = (n, x, y) => { f.appendChild(n); n.x = x; n.y = y; return n; };
  if (style === "Son kullanılan iki") {
    put(arc(22, 1, ink, .8, .18), 0, 0); put(arc(22, .42, ORANGE, .8), 0, 0);
    put(arc(14, 1, ink, .68, .18), 4, 4); put(arc(14, .05, ink, .68, .9), 4, 4);
  } else if (style === "En dolu") {
    put(arc(22, 1, ink, .8, .18), 0, 0); put(arc(22, .42, ORANGE, .8), 0, 0);
    const lg = logoSet && logoSet.children.find(c => c.name === "Sağlayıcı=Claude"); if (lg) { const i = lg.createInstance(); i.resize(10, 10); put(i, 6, 6); }
  } else if (style === "Yan yana") {
    put(arc(20, 1, ink, .78, .18), 0, 1); put(arc(20, .42, ORANGE, .78), 0, 1);
    put(arc(20, 1, ink, .78, .18), 23, 1); put(arc(20, .05, ink, .78, .9), 23, 1);
  } else {
    [[.42, ORANGE], [.05, ink], [.0, BLUE]].forEach(([p, c], i) => {
      const tr = figma.createRectangle(); tr.resize(22, 3.5); tr.cornerRadius = 1.75; tr.fills = [raw(ink.r, ink.g, ink.b, .18)]; put(tr, 0, 3 + i * 6.5);
      const fl = figma.createRectangle(); fl.resize(Math.max(22 * p, 3.5), 3.5); fl.cornerRadius = 1.75; fl.fills = [raw(c.r, c.g, c.b)]; put(fl, 0, 3 + i * 6.5);
    });
  }
  return f;
}
const names = ["Son kullanılan iki", "En dolu", "Yan yana", "Barlar"];
[false, true].forEach((dark, k) => {
  const bar = frame("HORIZONTAL", { name: dark ? "Menü çubuğu · Koyu" : "Menü çubuğu · Açık", itemSpacing: 28, counterAxisAlignItems: "CENTER", paddingLeft: 16, paddingRight: 16 });
  bar.counterAxisSizingMode = "FIXED"; bar.resize(400, 30); bar.fills = [dark ? raw(.12, .12, .13) : raw(.95, .95, .96)];
  for (const n of names) { const col = frame("VERTICAL", { name: n, itemSpacing: 4, counterAxisAlignItems: "CENTER" }); col.appendChild(icon(n, dark)); bar.appendChild(col); }
  into(secMenu, bar, 90, 50 + k * 60);
  const lbl = text(dark ? "Koyu" : "Açık", { size: 11, color: "sistem/ikincil yazı" }); into(secMenu, lbl, 40, 58 + k * 60);
});
const legend = text("Soldan sağa: Son kullanılan iki (iç içe halkalar) · En dolu (halka + logo) · Yan yana · Barlar. Hepsi 22 pt; Claude turuncu, Codex sistem rengi, Cursor mavi.", { size: 11, color: "sistem/ikincil yazı", width: 400 });
into(secMenu, legend, 90, 180);

// ============ Popup alt şeridindeki boşluk düzeltmesi ============
const popupPage = figma.root.children.find(p => p.name === "Popup");
await figma.setCurrentPageAsync(popupPage);
let fixed = 0;
for (const n of popupPage.findAll(n => n.type === "FRAME" && n.name === "boşluk")) { n.layoutSizingVertical = "FIXED"; n.resize(n.width, 1); fixed++; }

await figma.setCurrentPageAsync(screens);
figma.viewport.scrollAndZoomIntoView(screens.children);
if (typeof print === "function") print("Bitti: Ekranlar sayfası (Ayarlar 4, Kurulum 6, Menü Çubuğu); popup boşluk düzeltmesi: " + fixed);
