// AI Limit Tracker \u2014 Figma'daki kalan ekranlar (Scripter eklentisinde \u00e7al\u0131\u015ft\u0131r\u0131l\u0131r)
// Figma: Eklentiler > Scripter > yeni script > bu dosyan\u0131n tamam\u0131n\u0131 yap\u0131\u015ft\u0131r > \u00c7al\u0131\u015ft\u0131r (\u25b6).
// Starter plan en fazla 3 sayfa: hepsi tek "Ekranlar" sayfas\u0131nda b\u00f6l\u00fcmler (Ayarlar, Kurulum, Men\u00fc \u00c7ubu\u011fu, Giri\u015f penceresi,
// Popup \u00b7 Ayr\u0131k d\u00fczen). Ayr\u0131ca Popup ve Bile\u015fenler sayfalar\u0131nda "\u2248 X sa sonra dolar" etiketlerini "Bu h\u0131zla X saatte dolar" yapar.
// Uygulama s\u00fcr\u00fcm\u00fc: 0.3.11.
// Tekrar \u00e7al\u0131\u015ft\u0131r\u0131labilir: "Ekranlar" sayfas\u0131n\u0131n i\u00e7ini temizleyip ba\u015ftan kurar.
// Var olan de\u011fi\u015fkenleri (Tema \u00b7 A\u00e7\u0131k / Tema \u00b7 Koyu) ve yaz\u0131 stillerini kullan\u0131r; eksik "sistem/*" renklerini ekler.

const FONTS = [["SF Pro", "Regular"], ["SF Pro", "Medium"], ["SF Pro", "Semibold"], ["SF Pro", "Bold"], ["SF Pro Rounded", "Semibold"]];
for (const [family, style] of FONTS) await figma.loadFontAsync({ family, style });

// ---------- De\u011fi\u015fkenler ----------
const cols = await figma.variables.getLocalVariableCollectionsAsync();
const LIGHT = cols.find(c => c.name === "Tema \u00b7 A\u00e7\u0131k"), DARK = cols.find(c => c.name === "Tema \u00b7 Koyu");
if (!LIGHT || !DARK) throw new Error("Tema \u00b7 A\u00e7\u0131k / Tema \u00b7 Koyu koleksiyonlar\u0131 bulunamad\u0131");
async function varsOf(col) { const m = {}; for (const id of col.variableIds) { const v = await figma.variables.getVariableByIdAsync(id); m[v.name] = v; } return m; }
let L = await varsOf(LIGHT), D = await varsOf(DARK);
// macOS sistem renkleri (Ayarlar ve Kurulum pencereleri)
const SYSTEM = [
  ["sistem/pencere", { r: .925, g: .925, b: .925, a: 1 }, { r: .118, g: .118, b: .118, a: 1 }, ["FRAME_FILL"]],
  ["sistem/b\u00f6l\u00fcm", { r: 1, g: 1, b: 1, a: .7 }, { r: 1, g: 1, b: 1, a: .05 }, ["FRAME_FILL"]],
  ["sistem/ayra\u00e7", { r: 0, g: 0, b: 0, a: .1 }, { r: 1, g: 1, b: 1, a: .1 }, ["STROKE_COLOR", "FRAME_FILL", "SHAPE_FILL"]],
  ["sistem/birincil yaz\u0131", { r: 0, g: 0, b: 0, a: .85 }, { r: 1, g: 1, b: 1, a: .85 }, ["TEXT_FILL", "SHAPE_FILL"]],
  ["sistem/ikincil yaz\u0131", { r: 0, g: 0, b: 0, a: .5 }, { r: 1, g: 1, b: 1, a: .55 }, ["TEXT_FILL", "SHAPE_FILL"]],
  ["sistem/vurgu", { r: 0, g: .478, b: 1, a: 1 }, { r: .04, g: .52, b: 1, a: 1 }, ["FRAME_FILL", "SHAPE_FILL", "TEXT_FILL", "STROKE_COLOR"]],
  ["sistem/kontrol", { r: 0, g: 0, b: 0, a: .06 }, { r: 1, g: 1, b: 1, a: .1 }, ["FRAME_FILL", "SHAPE_FILL"]],
  ["sistem/ye\u015fil", { r: .2, g: .78, b: .35, a: 1 }, { r: .19, g: .82, b: .35, a: 1 }, ["TEXT_FILL", "SHAPE_FILL"]],
];
for (const [name, l, d, scopes] of SYSTEM) {
  if (!L[name]) { const v = figma.variables.createVariable(name, LIGHT, "COLOR"); v.setValueForMode(LIGHT.modes[0].modeId, l); v.scopes = scopes; }
  if (!D[name]) { const v = figma.variables.createVariable(name, DARK, "COLOR"); v.setValueForMode(DARK.modes[0].modeId, d); v.scopes = scopes; }
}
L = await varsOf(LIGHT); D = await varsOf(DARK);

// ---------- Yard\u0131mc\u0131lar ----------
let T = L; // aktif tema (ekran kurarken L ya da D)
const paint = name => { const v = T[name]; const c = Object.values(v.valuesByMode)[0]; return figma.variables.setBoundVariableForPaint({ type: "SOLID", color: { r: c.r, g: c.g, b: c.b }, opacity: (c.a === undefined ? 1 : c.a) }, "color", v); };
const raw = (r, g, b, a = 1) => ({ type: "SOLID", color: { r, g, b }, opacity: a });
const sym = name => { try { return figma.util.getSfSymbolCharacter(name); } catch (e) { return "\u25cf"; } };
function frame(dir, props = {}) {
  const f = figma.createFrame(); f.fills = [];
  if (dir) { f.layoutMode = dir; f.primaryAxisSizingMode = "AUTO"; f.counterAxisSizingMode = "AUTO"; }
  Object.assign(f, props); return f;
}
function add(parent, child, fill) { parent.appendChild(child); if (fill === "x" || fill === "xy") child.layoutSizingHorizontal = "FILL"; if (fill === "y" || fill === "xy") child.layoutSizingVertical = "FILL"; return child; }
function text(chars, { size = 13, style = "Regular", family = "SF Pro", color = "sistem/birincil yaz\u0131", width, align, name } = {}) {
  const t = figma.createText(); t.fontName = { family, style }; t.fontSize = size; t.characters = chars;
  t.fills = [paint(color)]; t.name = name || chars.slice(0, 24);
  if (width) { t.textAutoResize = "HEIGHT"; t.resize(width, t.height); } else t.textAutoResize = "WIDTH_AND_HEIGHT";
  if (align) t.textAlignHorizontal = align;
  return t;
}
function symbol(name, size, color, style = "Medium") { const t = text(sym(name), { size, style, color, name: "ikon " + name }); return t; }
function spacer(parent) { const s = frame(null, { name: "bo\u015fluk" }); s.resize(1, 1); parent.appendChild(s); s.layoutGrow = 1; return s; }
function tile(symbolName, rgb, size = 52) {
  const f = frame("HORIZONTAL", { name: "simge " + symbolName, primaryAxisAlignItems: "CENTER", counterAxisAlignItems: "CENTER" });
  f.primaryAxisSizingMode = "FIXED"; f.counterAxisSizingMode = "FIXED"; f.resize(size, size); f.cornerRadius = size * 0.24;
  const lighter = { r: Math.min(rgb.r + .12, 1), g: Math.min(rgb.g + .12, 1), b: Math.min(rgb.b + .12, 1) };
  f.fills = [{ type: "GRADIENT_LINEAR", gradientTransform: [[0, 1, 0], [-1, 0, 1]], gradientStops: [{ position: 0, color: { ...lighter, a: 1 } }, { position: 1, color: { ...rgb, a: 1 } }] }];
  const t = text(sym(symbolName), { size: Math.round(size * 0.46), style: "Semibold" }); t.fills = [raw(1, 1, 1)]; f.appendChild(t);
  return f;
}
function toggle(on = true) {
  const f = frame(null, { name: on ? "anahtar a\u00e7\u0131k" : "anahtar kapal\u0131" }); f.resize(32, 18); f.cornerRadius = 9;
  f.fills = [on ? paint("sistem/vurgu") : paint("sistem/kontrol")];
  const k = figma.createEllipse(); k.resize(16, 16); k.y = 1; k.x = on ? 15 : 1; k.fills = [raw(1, 1, 1)];
  k.effects = [{ type: "DROP_SHADOW", color: { r: 0, g: 0, b: 0, a: .25 }, offset: { x: 0, y: .5 }, radius: 1, spread: 0, visible: true, blendMode: "NORMAL" }];
  f.appendChild(k); return f;
}
function button(label, prominent = false, small = false) {
  const f = frame("HORIZONTAL", { name: "d\u00fc\u011fme " + label, paddingLeft: small ? 8 : 12, paddingRight: small ? 8 : 12, paddingTop: small ? 3 : 5, paddingBottom: small ? 3 : 5, cornerRadius: small ? 5 : 6 });
  f.fills = [prominent ? paint("sistem/vurgu") : paint("sistem/kontrol")];
  const t = text(label, { size: small ? 11 : 13, style: prominent ? "Medium" : "Regular" }); if (prominent) t.fills = [raw(1, 1, 1)];
  f.appendChild(t); return f;
}
function keycaps(keys) {
  const f = frame("HORIZONTAL", { name: "k\u0131sayol", itemSpacing: 4 });
  for (const k of keys) {
    const c = frame("HORIZONTAL", { name: k, primaryAxisAlignItems: "CENTER", counterAxisAlignItems: "CENTER", paddingLeft: 3, paddingRight: 3 });
    c.counterAxisSizingMode = "FIXED"; c.resize(22, 22); c.primaryAxisSizingMode = "AUTO"; c.minWidth = 22; c.cornerRadius = 5;
    c.fills = [paint("sistem/b\u00f6l\u00fcm")]; c.strokes = [paint("sistem/ayra\u00e7")]; c.strokeWeight = 1;
    c.appendChild(text(k, { size: 12, style: "Semibold", family: "SF Pro Rounded" })); f.appendChild(c);
  }
  return f;
}
// macOS gruplu Form b\u00f6l\u00fcm\u00fc: yuvarlak k\u00f6\u015feli, sat\u0131rlar aras\u0131 ince ayra\u00e7
function section(parent, rows, { header, footer } = {}) {
  const wrap = add(parent, frame("VERTICAL", { name: "b\u00f6l\u00fcm", itemSpacing: 6 }), "x");
  if (header) add(wrap, text(header, { size: 11, style: "Semibold", color: "sistem/ikincil yaz\u0131" }));
  const box = add(wrap, frame("VERTICAL", { name: "sat\u0131rlar", cornerRadius: 10 }), "x");
  box.fills = [paint("sistem/b\u00f6l\u00fcm")]; box.strokes = [paint("sistem/ayra\u00e7")]; box.strokeWeight = .5;
  rows.forEach((r, i) => {
    if (i > 0) { const sep = figma.createRectangle(); sep.name = "ayra\u00e7"; sep.resize(100, .5); sep.fills = [paint("sistem/ayra\u00e7")]; add(box, sep, "x"); }
    add(box, r, "x");
  });
  if (footer) add(wrap, text(footer, { size: 11, color: "sistem/ikincil yaz\u0131", width: 480 }), "x");
  return wrap;
}
function row(children, { indent = 0, align = "CENTER" } = {}) {
  const r = frame("HORIZONTAL", { name: "sat\u0131r", itemSpacing: 10, counterAxisAlignItems: align, paddingLeft: 10 + indent, paddingRight: 10, paddingTop: 8, paddingBottom: 8 });
  for (const c of children) { if (c === "spacer") spacer(r); else r.appendChild(c); }
  return r;
}
function titled(title, detail, width = 300) {
  const v = frame("VERTICAL", { name: "ba\u015fl\u0131k", itemSpacing: 2 });
  v.appendChild(text(title, { size: 13, style: "Medium" }));
  if (detail) v.appendChild(text(detail, { size: 12, color: "sistem/ikincil yaz\u0131", width }));
  return v;
}
// logo bile\u015feni (Bile\u015fenler sayfas\u0131ndaki "Logo" seti)
const compPage = figma.root.children.find(p => p.name === "Bile\u015fenler");
await figma.setCurrentPageAsync(compPage);
const logoSet = compPage.findOne(n => n.type === "COMPONENT_SET" && n.name === "Logo");
function logoTile(provider) {
  const f = frame("HORIZONTAL", { name: "logo " + provider, primaryAxisAlignItems: "CENTER", counterAxisAlignItems: "CENTER" });
  f.primaryAxisSizingMode = "FIXED"; f.counterAxisSizingMode = "FIXED"; f.resize(30, 30); f.cornerRadius = 7; f.fills = [paint("sistem/kontrol")];
  const v = logoSet && logoSet.children.find(c => c.name === "Sa\u011flay\u0131c\u0131=" + provider);
  if (v) { const i = v.createInstance(); i.resize(18, 18); f.appendChild(i); }
  return f;
}
// pencere: ba\u015fl\u0131k \u00e7ubu\u011fu (trafik \u0131\u015f\u0131klar\u0131) + i\u00e7erik
function window(name, w, h, title, { transparentTitle = false } = {}) {
  const win = frame("VERTICAL", { name }); win.primaryAxisSizingMode = "FIXED"; win.counterAxisSizingMode = "FIXED"; win.resize(w, h);
  win.cornerRadius = 12; win.clipsContent = true; win.fills = [paint("sistem/pencere")]; win.strokes = [paint("sistem/ayra\u00e7")]; win.strokeWeight = .5;
  win.effects = [{ type: "DROP_SHADOW", color: { r: 0, g: 0, b: 0, a: .25 }, offset: { x: 0, y: 16 }, radius: 40, spread: 0, visible: true, blendMode: "NORMAL" }];
  const bar = add(win, frame("HORIZONTAL", { name: "ba\u015fl\u0131k \u00e7ubu\u011fu", itemSpacing: 8, counterAxisAlignItems: "CENTER", paddingLeft: 12, paddingRight: 12 }), "x");
  bar.counterAxisSizingMode = "FIXED"; bar.resize(w, 28);
  for (const c of [[1, .37, .34], [1, .74, .18], [.16, .79, .25]]) { const e = figma.createEllipse(); e.resize(12, 12); e.fills = [raw(...c)]; bar.appendChild(e); }
  if (!transparentTitle) { spacer(bar); bar.appendChild(text(title, { size: 13, style: "Semibold" })); spacer(bar); const pad = frame(null); pad.resize(52, 1); bar.appendChild(pad); }
  return win;
}

// ---------- Sayfalar ----------
let screens = figma.root.children.find(p => p.name === "Ekranlar" || p.name === "Ayarlar" || p.name === "Kurulum" || p.name === "Men\u00fc \u00c7ubu\u011fu");
if (!screens) screens = figma.createPage();
screens.name = "Ekranlar";
await figma.setCurrentPageAsync(screens);
for (const n of [...screens.children]) n.remove();
// her b\u00f6l\u00fcm bir Section; i\u00e7erik b\u00f6l\u00fcm\u00fcn i\u00e7ine kurulur
function makeSection(name, y, w, h) { const s = figma.createSection(); s.name = name; screens.appendChild(s); s.x = -40; s.y = y; s.resizeWithoutConstraints(w, h); return s; }
const secSettings = makeSection("Ayarlar", -40, 2500, 600);
const secSetup = makeSection("Kurulum", 640, 3640, 720);
const secMenu = makeSection("Men\u00fc \u00c7ubu\u011fu", 1440, 560, 260);
const secLogin = makeSection("Giri\u015f penceresi", 1780, 1620, 680);
const secSplit = makeSection("Popup \u00b7 Ayr\u0131k d\u00fczen", 2540, 900, 560);
const into = (sec, node, x, y) => { sec.appendChild(node); node.x = x; node.y = y; };

// ============ AYARLAR (560\u00d7500, sekmeler) ============
const TABS = [["Sa\u011flay\u0131c\u0131lar", "square.stack.3d.up"], ["Men\u00fc \u00c7ubu\u011fu", "menubar.rectangle"], ["Bildirimler", "bell.badge"], ["Genel", "gearshape"]];
function settingsWindow(selected) {
  const win = window("Ayarlar \u00b7 " + TABS[selected][0], 560, 500, "AI Limit Tracker Ayarlar\u0131");
  const tb = add(win, frame("HORIZONTAL", { name: "sekmeler", itemSpacing: 2, primaryAxisAlignItems: "CENTER", paddingBottom: 8 }), "x");
  TABS.forEach(([label, icon], i) => {
    const t = frame("VERTICAL", { name: label, itemSpacing: 2, counterAxisAlignItems: "CENTER", paddingLeft: 10, paddingRight: 10, paddingTop: 4, paddingBottom: 4, cornerRadius: 6 });
    if (i === selected) t.fills = [paint("sistem/kontrol")];
    t.appendChild(symbol(icon, 17, i === selected ? "sistem/vurgu" : "sistem/ikincil yaz\u0131"));
    t.appendChild(text(label, { size: 11, color: i === selected ? "sistem/vurgu" : "sistem/ikincil yaz\u0131" }));
    tb.appendChild(t);
  });
  const sep = figma.createRectangle(); sep.resize(560, .5); sep.fills = [paint("sistem/ayra\u00e7")]; add(win, sep, "x");
  const body = add(win, frame("VERTICAL", { name: "i\u00e7erik", itemSpacing: 18, paddingLeft: 20, paddingRight: 20, paddingTop: 18, paddingBottom: 18 }), "xy");
  return { win, body };
}
// 1) Sa\u011flay\u0131c\u0131lar
{
  const { win, body } = settingsWindow(0);
  const connected = () => { const l = frame("HORIZONTAL", { name: "ba\u011fl\u0131", itemSpacing: 4, counterAxisAlignItems: "CENTER" }); l.appendChild(symbol("checkmark.circle.fill", 12, "sistem/ye\u015fil")); l.appendChild(text("Ba\u011fl\u0131", { size: 12, style: "Medium", color: "sistem/ye\u015fil" })); return l; };
  const provRow = (p, detail) => row([logoTile(p), titled(p, detail, 260), "spacer", connected(), toggle(true)]);
  const accRow = (initial, name, meta, value) => {
    const av = frame("HORIZONTAL", { name: "ba\u015f harf", primaryAxisAlignItems: "CENTER", counterAxisAlignItems: "CENTER" }); av.primaryAxisSizingMode = "FIXED"; av.counterAxisSizingMode = "FIXED"; av.resize(24, 24); av.cornerRadius = 12; av.fills = [paint("sistem/kontrol")];
    av.appendChild(text(initial, { size: 11, style: "Semibold", family: "SF Pro Rounded", color: "sistem/ikincil yaz\u0131" }));
    return row([av, titled(name, meta, 260), "spacer", text(value, { size: 12, style: "Medium", color: "sistem/ikincil yaz\u0131" }), symbol("ellipsis.circle", 14, "sistem/ikincil yaz\u0131")], { indent: 40 });
  };
  const addRow = label => { const r = row([symbol("plus.circle.fill", 13, "sistem/vurgu"), text(label, { size: 13, color: "sistem/vurgu" })], { indent: 40 }); r.itemSpacing = 6; return r; };
  // Codex: ara\u00e7 oturumundan okunuyor ama uygulaman\u0131n kendi oturumu yok \u2192 varsay\u0131lan yol tek seferlik giri\u015f
  const loginRow = (p, detail) => row([logoTile(p), titled(p, detail, 250), "spacer", button("Giri\u015f Yap", true, true), toggle(true)]);
  section(body, [provRow("Claude", "Pro \u00b7 5 saat %42"), accRow("B", "bireysel", "Taray\u0131c\u0131dan giri\u015f", "%42"), accRow("\u0130", "i\u015f", "Taray\u0131c\u0131dan giri\u015f", "%0"), addRow("Hesap Ekle\u2026")]);
  section(body, [loginRow("Codex", "Bir kez giri\u015f yap; ba\u011flant\u0131 hep a\u00e7\u0131k kal\u0131r. Varsay\u0131lan taray\u0131c\u0131nda a\u00e7\u0131l\u0131r."), addRow("Ba\u015fka bir Codex hesab\u0131 ekle\u2026")]);
  section(body, [provRow("Cursor", "Free \u00b7 Ayl\u0131k %0"), addRow("Ba\u015fka bir Cursor hesab\u0131 ekle\u2026")],
    { footer: "Birden \u00e7ok hesapta popup'taki kart\u0131n sol alt\u0131nda hesap \u00e7ipleri \u00e7\u0131kar; yaln\u0131zca tek sa\u011flay\u0131c\u0131 ba\u011fl\u0131ysa her hesap ayr\u0131 kart olur. Hesap Ekle varsay\u0131lan taray\u0131c\u0131nda a\u00e7\u0131l\u0131r: taray\u0131c\u0131da o an a\u00e7\u0131k hesap eklenir. Kapal\u0131 sa\u011flay\u0131c\u0131lar popup'ta ve men\u00fc \u00e7ubu\u011funda g\u00f6sterilmez." });
  into(secSettings, win, 40, 50);
}
// 2) Men\u00fc \u00c7ubu\u011fu
{
  const { win, body } = settingsWindow(1);
  const styles = [["Son kullan\u0131lan iki", "En son kulland\u0131\u011f\u0131n iki sa\u011flay\u0131c\u0131, i\u00e7 i\u00e7e halkalar", true], ["En dolu", "Limite en yak\u0131n sa\u011flay\u0131c\u0131, ortas\u0131nda logosu", false], ["Yan yana", "Her sa\u011flay\u0131c\u0131 kendi halkas\u0131 ve logosuyla", false], ["Barlar", "Her sa\u011flay\u0131c\u0131 i\u00e7in ince bir bar", false]];
  const grid = frame("VERTICAL", { name: "stiller", itemSpacing: 10 });
  for (let r = 0; r < 2; r++) {
    const line = add(grid, frame("HORIZONTAL", { name: "s\u0131ra", itemSpacing: 10 }), "x");
    for (let c = 0; c < 2; c++) {
      const [title, detail, sel] = styles[r * 2 + c];
      const card = add(line, frame("VERTICAL", { name: title, itemSpacing: 6, paddingLeft: 10, paddingRight: 10, paddingTop: 10, paddingBottom: 10, cornerRadius: 10 }), "x");
      card.fills = [paint("sistem/b\u00f6l\u00fcm")]; card.strokes = [sel ? paint("sistem/vurgu") : paint("sistem/ayra\u00e7")]; card.strokeWeight = sel ? 2 : .5;
      const strip = add(card, frame("HORIZONTAL", { name: "men\u00fc \u00e7ubu\u011fu \u00f6nizleme", primaryAxisAlignItems: "CENTER", counterAxisAlignItems: "CENTER" }), "x");
      strip.counterAxisSizingMode = "FIXED"; strip.resize(200, 30); strip.cornerRadius = 6; strip.fills = [raw(.29, .45, .93, .9)];
      const hint = text("(Men\u00fc \u00c7ubu\u011fu sayfas\u0131ndaki ikon)", { size: 9 }); hint.fills = [raw(1, 1, 1, .8)]; strip.appendChild(hint);
      const tt = add(card, frame("HORIZONTAL", { name: "ad", itemSpacing: 4, counterAxisAlignItems: "CENTER" }));
      tt.appendChild(text(title, { size: 13, style: "Medium" }));
      if (sel) tt.appendChild(symbol("checkmark.circle.fill", 12, "sistem/vurgu"));
      add(card, text(detail, { size: 11, color: "sistem/ikincil yaz\u0131", width: 220 }), "x");
    }
  }
  const s = section(body, [], { header: "Simge", footer: "\u00d6nizlemeler \u015fu anki limitlerinle \u00e7izilir. Hangi sa\u011flay\u0131c\u0131lar\u0131n g\u00f6sterilece\u011fini Sa\u011flay\u0131c\u0131lar sekmesinden se\u00e7ebilirsin." });
  const box = s.children.find(n => n.name === "sat\u0131rlar"); box.fills = []; box.strokes = []; add(box, grid, "x");
  into(secSettings, win, 660, 50);
}
// 3) Bildirimler
{
  const { win, body } = settingsWindow(2);
  const kinds = [["gauge.with.dots.needle.67percent", { r: .2, g: .5, b: 1 }, "Limitin %75'ine ula\u015f\u0131nca", "H\u0131z\u0131n\u0131 ayarlaman i\u00e7in erken uyar\u0131"],
    ["exclamationmark.triangle.fill", { r: 1, g: .58, b: 0 }, "Limitin %90'\u0131na ula\u015f\u0131nca", "Limite \u00e7ok yakla\u015ft\u0131\u011f\u0131nda"],
    ["arrow.counterclockwise.circle.fill", { r: .2, g: .75, b: .4 }, "Limit yenilenince", "Y\u00fcksek kulland\u0131\u011f\u0131n limit s\u0131f\u0131rlan\u0131nca, devam edebilece\u011fini bildirir"],
    ["alarm", { r: .6, g: .4, b: .95 }, "\u0130stedi\u011fin limit a\u00e7\u0131l\u0131nca", "Bir karta sa\u011f t\u0131klay\u0131p \"a\u00e7\u0131l\u0131nca haber ver\" se\u00e7erek tek seferlik hat\u0131rlatma kurars\u0131n"]];
  section(body, kinds.map(([s, c, t, d]) => row([tile(s, c, 26), titled(t, d, 330), "spacer", toggle(true)])), { header: "Haber ver" });
  into(secSettings, win, 1280, 50);
}
// 4) Genel
{
  const { win, body } = settingsWindow(3);
  section(body, [row([text("Mac a\u00e7\u0131l\u0131nca ba\u015flat", { size: 13 }), "spacer", toggle(true)]), row([text("K\u0131sayol", { size: 13 }), "spacer", keycaps(["\u2303", "\u2325", "L"])])]);
  section(body, [row([titled("S\u00fcr\u00fcm 0.3.11", "En son s\u00fcr\u00fcm\u00fc kullan\u0131yorsun \u00b7 son kontrol 14:20", 300), "spacer", button("G\u00fcncellemeleri Denetle")]),
    row([button("Tan\u0131lama Bilgisini Kopyala"), "spacer", button("Kurulumu Yeniden Ba\u015flat")])],
    { footer: "Tan\u0131lama bilgisi s\u00fcr\u00fcm, macOS ve her sa\u011flay\u0131c\u0131n\u0131n durumunu i\u00e7erir; token ya da hesap bilgisi i\u00e7ermez." });
  into(secSettings, win, 1900, 50);
}

// ============ KURULUM (540\u00d7620, 6 ad\u0131m) ============
function setupWindow(name, { title, subtitle, tile: t, back = true, primary = "Devam", note }) {
  const win = window("Kurulum \u00b7 " + name, 540, 620, "", { transparentTitle: true });
  const content = add(win, frame("VERTICAL", { name: "sayfa", itemSpacing: 18, counterAxisAlignItems: "CENTER", paddingLeft: 32, paddingRight: 32, paddingTop: 16 }), "xy");
  const head = add(content, frame("VERTICAL", { name: "ba\u015fl\u0131k", itemSpacing: 10, counterAxisAlignItems: "CENTER" }), "x");
  if (t) head.appendChild(t);
  head.appendChild(text(title, { size: 26, style: "Bold", width: 440, align: "CENTER" }));
  head.appendChild(text(subtitle, { size: 13, color: "sistem/ikincil yaz\u0131", width: 400, align: "CENTER" }));
  const sep = figma.createRectangle(); sep.resize(540, .5); sep.fills = [paint("sistem/ayra\u00e7")]; add(win, sep, "x");
  const foot = add(win, frame("HORIZONTAL", { name: "alt", itemSpacing: 10, counterAxisAlignItems: "CENTER", paddingLeft: 24, paddingRight: 24, paddingTop: 16, paddingBottom: 16 }), "x");
  if (back) foot.appendChild(button("Geri"));
  spacer(foot);
  if (note) foot.appendChild(text(note, { size: 11, color: "sistem/ikincil yaz\u0131" }));
  foot.appendChild(button(primary, true));
  return { win, content };
}
const steps = [];
// 1 Ho\u015f geldin
{
  const appTile = tile("gauge.with.dots.needle.50percent", { r: .55, g: .55, b: .58 }, 72);
  const { win, content } = setupWindow("Ho\u015f geldin", { title: "AI Limit Tracker'a Ho\u015f Geldin", subtitle: "Claude, Codex ve Cursor limitlerini men\u00fc \u00e7ubu\u011funda tek bak\u0131\u015fta g\u00f6r.", tile: appTile, back: false, primary: "Ba\u015fla" });
  const list = add(content, frame("VERTICAL", { name: "\u00f6zellikler", itemSpacing: 18, paddingLeft: 24, paddingRight: 24, paddingTop: 12 }), "x");
  for (const [s, c, t, d] of [["gauge.with.dots.needle.50percent", { r: 1, g: .58, b: 0 }, "T\u00fcm limitler tek yerde", "5 saatlik ve haftal\u0131k pencereler, s\u0131f\u0131rlanmaya kalan s\u00fcre ve bu tempoyla ne zaman dolaca\u011f\u0131."],
    ["bell.badge.fill", { r: 1, g: .23, b: .19 }, "Limite tak\u0131lmadan haber al", "Limite yakla\u015f\u0131nca ve limit yenilenince bildirim; hangilerini alaca\u011f\u0131n\u0131 sen se\u00e7ersin."],
    ["lock.fill", { r: .2, g: .5, b: 1 }, "Verilerin sende kal\u0131r", "Sadece ba\u011flad\u0131\u011f\u0131n hizmetlerle ve bu Mac'teki uygulamalarla konu\u015fur, ba\u015fka sunucuya veri g\u00f6ndermez."]]) {
    const r = add(list, frame("HORIZONTAL", { name: t, itemSpacing: 14, counterAxisAlignItems: "MIN" }), "x");
    r.appendChild(tile(s, c, 36));
    const v = frame("VERTICAL", { name: "metin", itemSpacing: 2 }); v.appendChild(text(t, { size: 13, style: "Semibold" })); v.appendChild(text(d, { size: 12, color: "sistem/ikincil yaz\u0131", width: 360 })); r.appendChild(v);
  }
  steps.push(win);
}
// 2 Ara\u00e7lar
{
  const { win, content } = setupWindow("Ara\u00e7lar", { title: "Hangi ara\u00e7lar\u0131 kullan\u0131yorsun?", subtitle: "Bu Mac'te bulduklar\u0131m\u0131z\u0131 a\u00e7t\u0131k. Sonradan Ayarlar'dan de\u011fi\u015ftirebilirsin.", tile: tile("square.stack.3d.up.fill", { r: .35, g: .34, b: .84 }) });
  section(content, [["Claude", "Claude Code bulundu"], ["Codex", "Codex CLI giri\u015fi bulundu"], ["Cursor", "Cursor bulundu"]].map(([p, d]) => row([logoTile(p), titled(p, d, 280), "spacer", toggle(true)])));
  steps.push(win);
}
// 3 Ba\u011flan
{
  const { win, content } = setupWindow("Ba\u011flan", { title: "Hesaplar\u0131n\u0131 ba\u011fla", subtitle: "Her ara\u00e7 i\u00e7in bir kez giri\u015f yap: taray\u0131c\u0131nda a\u00e7\u0131l\u0131r, oradaki Google oturumun ya da kay\u0131tl\u0131 \u015fifrelerin kullan\u0131l\u0131r. Sonra ba\u011flant\u0131 hep a\u00e7\u0131k kal\u0131r.", tile: tile("link", { r: .2, g: .5, b: 1 }) });
  const ok = () => { const l = frame("HORIZONTAL", { itemSpacing: 4, counterAxisAlignItems: "CENTER", name: "ba\u011fl\u0131" }); l.appendChild(symbol("checkmark.circle.fill", 12, "sistem/ye\u015fil")); l.appendChild(text("Ba\u011fl\u0131", { size: 12, style: "Medium", color: "sistem/ye\u015fil" })); return l; };
  // Taray\u0131c\u0131da giri\u015f beklenirken sat\u0131r\u0131n sa\u011f\u0131
  const waiting = () => { const l = frame("HORIZONTAL", { itemSpacing: 8, counterAxisAlignItems: "CENTER", name: "taray\u0131c\u0131da devam et" }); l.appendChild(symbol("rays", 13, "sistem/ikincil yaz\u0131")); l.appendChild(text("Taray\u0131c\u0131da devam et", { size: 12, color: "sistem/ikincil yaz\u0131" })); l.appendChild(button("Vazge\u00e7", false, true)); return l; };
  section(content, [row([logoTile("Claude"), titled("Claude", "Bir kez giri\u015f yap (Pro ya da Max hesab\u0131); ba\u011flant\u0131 hep a\u00e7\u0131k kal\u0131r. Varsay\u0131lan taray\u0131c\u0131nda a\u00e7\u0131l\u0131r.", 230), "spacer", button("Giri\u015f Yap", true, true)]),
    row([logoTile("Codex"), titled("Codex", "Bir kez giri\u015f yap; ba\u011flant\u0131 hep a\u00e7\u0131k kal\u0131r. Varsay\u0131lan taray\u0131c\u0131nda a\u00e7\u0131l\u0131r.", 190), "spacer", waiting()]),
    row([logoTile("Cursor"), titled("Cursor", "Free \u00b7 Ayl\u0131k %0", 250), "spacer", ok()])],
    { footer: "Ayn\u0131 ara\u00e7ta birden \u00e7ok hesab\u0131n m\u0131 var? Kurulumdan sonra Ayarlar \u2192 Sa\u011flay\u0131c\u0131lar \u2192 Hesap Ekle ile ekleyebilir, popup'ta aralar\u0131nda ge\u00e7ebilirsin." });
  steps.push(win);
}
// 4 Bildirimler
{
  const { win, content } = setupWindow("Bildirimler", { title: "Bildirimler", subtitle: "Hangi anlarda haber vermemizi istedi\u011fini se\u00e7. Hi\u00e7biri g\u00fcr\u00fclt\u00fc yapmaz: her e\u015fik, her pencerede bir kez gelir.", tile: tile("bell.badge.fill", { r: 1, g: .23, b: .19 }) });
  section(content, [row([titled("Bildirim izni", "Bildirimlerin gelmesi i\u00e7in macOS izni gerekiyor.", 300), "spacer", button("\u0130zin Ver", true, true)])]);
  section(content, [["Limitin %75'ine ula\u015f\u0131nca", "H\u0131z\u0131n\u0131 ayarlaman i\u00e7in erken uyar\u0131"], ["Limitin %90'\u0131na ula\u015f\u0131nca", "Limite \u00e7ok yakla\u015ft\u0131\u011f\u0131nda"], ["Limit yenilenince", "Y\u00fcksek kulland\u0131\u011f\u0131n limit s\u0131f\u0131rlan\u0131nca, devam edebilece\u011fini bildirir"], ["\u0130stedi\u011fin limit a\u00e7\u0131l\u0131nca", "Karta sa\u011f t\u0131klay\u0131p tek seferlik hat\u0131rlatma kurars\u0131n"]]
    .map(([t, d]) => row([titled(t, d, 340), "spacer", toggle(true)])));
  steps.push(win);
}
// 5 Genel
{
  const { win, content } = setupWindow("Genel", { title: "Her zaman elinin alt\u0131nda", subtitle: "Mac a\u00e7\u0131l\u0131nca kendili\u011finden ba\u015flas\u0131n, istedi\u011fin yerden bir k\u0131sayolla a\u00e7\u0131ls\u0131n.", tile: tile("menubar.arrow.up.rectangle", { r: .19, g: .69, b: .78 }) });
  section(content, [row([symbol("power", 14, "sistem/ikincil yaz\u0131"), titled("Mac a\u00e7\u0131l\u0131nca ba\u015flat", "\u00d6nerilir; limitlerini her zaman men\u00fc \u00e7ubu\u011funda g\u00f6r\u00fcrs\u00fcn.", 300), "spacer", toggle(true)]),
    row([symbol("command", 14, "sistem/ikincil yaz\u0131"), titled("K\u0131sayol", "Popup'\u0131 her uygulamadan a\u00e7ar ve kapat\u0131r.", 300), "spacer", keycaps(["\u2303", "\u2325", "L"])])]);
  steps.push(win);
}
// 6 Haz\u0131r
{
  const { win, content } = setupWindow("Haz\u0131r", { title: "Haz\u0131rs\u0131n", subtitle: "3 sa\u011flay\u0131c\u0131 ba\u011fl\u0131. AI Limit Tracker men\u00fc \u00e7ubu\u011funun sa\u011f \u00fcst\u00fcnde, halka simgesiyle duruyor.", tile: tile("checkmark", { r: .2, g: .75, b: .4 }), back: false, primary: "Popup'\u0131 G\u00f6ster" });
  const mb = add(content, frame("HORIZONTAL", { name: "men\u00fc \u00e7ubu\u011fu \u00f6rne\u011fi", itemSpacing: 12, counterAxisAlignItems: "CENTER", paddingLeft: 14, paddingRight: 14, paddingTop: 6, paddingBottom: 6, cornerRadius: 8 }));
  mb.fills = [paint("sistem/b\u00f6l\u00fcm")]; mb.strokes = [paint("sistem/ayra\u00e7")]; mb.strokeWeight = .5;
  for (const s of ["wifi", "battery.75percent"]) mb.appendChild(symbol(s, 13, "sistem/ikincil yaz\u0131"));
  const ring = figma.createEllipse(); ring.resize(18, 18); ring.arcData = { startingAngle: 3 * Math.PI / 4, endingAngle: 3 * Math.PI / 4 + 1.5 * Math.PI * .42, innerRadius: .7 }; ring.fills = [raw(.85, .47, .34)]; ring.name = "uygulama simgesi"; mb.appendChild(ring);
  mb.appendChild(text("\u00c7ar 17:54", { size: 12, style: "Medium" }));
  const hk = add(content, frame("HORIZONTAL", { name: "k\u0131sayol ipucu", itemSpacing: 8, counterAxisAlignItems: "CENTER" }));
  hk.appendChild(text("Ya da her yerden", { size: 13, color: "sistem/ikincil yaz\u0131" })); hk.appendChild(keycaps(["\u2303", "\u2325", "L"]));
  steps.push(win);
}
steps.forEach((w, i) => into(secSetup, w, 40 + i * 600, 50));

// ============ MEN\u00dc \u00c7UBU\u011eU \u0130KONLARI (22 pt) ============
const ARC0 = 3 * Math.PI / 4, ARCS = 1.5 * Math.PI;
function arc(size, p, rgb, inner = .72, alpha = 1) { const e = figma.createEllipse(); e.resize(size, size); e.arcData = { startingAngle: ARC0, endingAngle: ARC0 + ARCS * Math.max(p, .02), innerRadius: inner }; e.fills = [raw(rgb.r, rgb.g, rgb.b, alpha)]; return e; }
const ORANGE = { r: .85, g: .47, b: .34 }, BLUE = { r: .42, g: .55, b: .98 };
function icon(style, dark) {
  const ink = dark ? { r: 1, g: 1, b: 1 } : { r: 0, g: 0, b: 0 };
  const f = frame(null, { name: style }); f.resize(style === "Barlar" ? 22 : style === "Yan yana" ? 44 : 22, 22); f.clipsContent = false;
  const put = (n, x, y) => { f.appendChild(n); n.x = x; n.y = y; return n; };
  if (style === "Son kullan\u0131lan iki") {
    put(arc(22, 1, ink, .8, .18), 0, 0); put(arc(22, .42, ORANGE, .8), 0, 0);
    put(arc(14, 1, ink, .68, .18), 4, 4); put(arc(14, .05, ink, .68, .9), 4, 4);
  } else if (style === "En dolu") {
    put(arc(22, 1, ink, .8, .18), 0, 0); put(arc(22, .42, ORANGE, .8), 0, 0);
    const lg = logoSet && logoSet.children.find(c => c.name === "Sa\u011flay\u0131c\u0131=Claude"); if (lg) { const i = lg.createInstance(); i.resize(10, 10); put(i, 6, 6); }
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
const names = ["Son kullan\u0131lan iki", "En dolu", "Yan yana", "Barlar"];
[false, true].forEach((dark, k) => {
  const bar = frame("HORIZONTAL", { name: dark ? "Men\u00fc \u00e7ubu\u011fu \u00b7 Koyu" : "Men\u00fc \u00e7ubu\u011fu \u00b7 A\u00e7\u0131k", itemSpacing: 28, counterAxisAlignItems: "CENTER", paddingLeft: 16, paddingRight: 16 });
  bar.counterAxisSizingMode = "FIXED"; bar.resize(400, 30); bar.fills = [dark ? raw(.12, .12, .13) : raw(.95, .95, .96)];
  for (const n of names) { const col = frame("VERTICAL", { name: n, itemSpacing: 4, counterAxisAlignItems: "CENTER" }); col.appendChild(icon(n, dark)); bar.appendChild(col); }
  into(secMenu, bar, 90, 50 + k * 60);
  const lbl = text(dark ? "Koyu" : "A\u00e7\u0131k", { size: 11, color: "sistem/ikincil yaz\u0131" }); into(secMenu, lbl, 40, 58 + k * 60);
});
const legend = text("Soldan sa\u011fa: Son kullan\u0131lan iki (i\u00e7 i\u00e7e halkalar) \u00b7 En dolu (halka + logo) \u00b7 Yan yana \u00b7 Barlar. Hepsi 22 pt; Claude turuncu, Codex sistem rengi, Cursor mavi.", { size: 11, color: "sistem/ikincil yaz\u0131", width: 400 });
into(secMenu, legend, 90, 180);

// ============ G\u0130R\u0130\u015e PENCERES\u0130 (uygulama penceresi; yaln\u0131zca ara\u00e7 yoksa: Cursor, Claude Code/Codex kurulu olmayan Mac) ============
function loginWindow(done) {
  const win = window(done ? "Giri\u015f penceresi \u00b7 Giri\u015f tamam" : "Giri\u015f penceresi", 720, 520, "claude.ai giri\u015fi \u00b7 AI Limit Tracker");
  const note = add(win, frame("HORIZONTAL", { name: "not", itemSpacing: 12, counterAxisAlignItems: "CENTER", paddingLeft: 16, paddingRight: 16, paddingTop: 12, paddingBottom: 12 }), "x");
  note.fills = [paint("sistem/b\u00f6l\u00fcm")];
  note.appendChild(symbol(done ? "checkmark.circle.fill" : "lock.shield", 22, done ? "sistem/ye\u015fil" : "sistem/vurgu"));
  const v = frame("VERTICAL", { name: "metin", itemSpacing: 2 });
  v.appendChild(text(done ? "Giri\u015f tamam" : "Bu pencere taray\u0131c\u0131ndan ayr\u0131", { size: 13, style: "Semibold" }));
  v.appendChild(done ? text("Limitlerin geliyor, pencere kapan\u0131yor\u2026", { size: 12, color: "sistem/ikincil yaz\u0131" })
    : text("Chrome ya da Safari'deki giri\u015fin ve kay\u0131tl\u0131 \u015fifrelerin burada g\u00f6r\u00fcnmez. claude.ai hesab\u0131na bir kez giri\u015f yapman yeter: oturum hat\u0131rlan\u0131r, giri\u015f bitince pencere kendili\u011finden kapan\u0131r.", { size: 12, color: "sistem/ikincil yaz\u0131", width: 520 }));
  note.appendChild(v); spacer(note);
  if (!done) note.appendChild(button("Kapat"));
  const sep = figma.createRectangle(); sep.resize(720, .5); sep.fills = [paint("sistem/ayra\u00e7")]; add(win, sep, "x");
  const site = add(win, frame("VERTICAL", { name: "site", itemSpacing: 6, primaryAxisAlignItems: "CENTER", counterAxisAlignItems: "CENTER" }), "xy");
  site.fills = [paint("sistem/kontrol")];
  site.appendChild(text("claude.ai giri\u015f sayfas\u0131", { size: 15, style: "Semibold", color: "sistem/ikincil yaz\u0131" }));
  site.appendChild(text("Sitenin kendisi: Google / Apple ile devam et ya da e-posta", { size: 12, color: "sistem/ikincil yaz\u0131" }));
  return win;
}
into(secLogin, loginWindow(false), 40, 60);
into(secLogin, loginWindow(true), 820, 60);
into(secLogin, text("Claude ve Codex'te her giri\u015f (Giri\u015f Yap, Hesap Ekle, Yeniden Giri\u015f Yap) varsay\u0131lan taray\u0131c\u0131da a\u00e7\u0131l\u0131r (claude auth login / codex login). Bu pencere yaln\u0131zca taray\u0131c\u0131 giri\u015fi m\u00fcmk\u00fcn de\u011filse: Cursor ve Claude Code/Codex kurulu olmayan Mac. Giri\u015f 2 sn'de bir denetlenir, veri gelince pencere kendili\u011finden kapan\u0131r.", { size: 12, color: "sistem/ikincil yaz\u0131", width: 1500 }), 40, 600);

// ============ POPUP \u00b7 AYRIK D\u00dcZEN (tek sa\u011flay\u0131c\u0131 ba\u011fl\u0131, birden \u00e7ok hesap: her hesap ayr\u0131 kart, \u00e7ip yok) ============
const cardComp = compPage.findOne(n => n.type === "COMPONENT" && n.name === "Kart / \u00d6n y\u00fcz");
async function loadFontsOf(t) { for (const f of t.getRangeAllFontNames(0, t.characters.length)) await figma.loadFontAsync(f); }
// "\u2248 2 sa sonra dolar" \u2192 "Bu h\u0131zla 2 saatte dolar" (uygulamadaki Countdown.within)
const UNIT = { sa: "saatte", dk: "dakikada", g: "g\u00fcnde" };
async function fixEta(root) {
  let n = 0;
  for (const t of root.findAll(x => x.type === "TEXT" && x.characters.indexOf("sonra dolar") >= 0)) {
    const m = t.characters.match(/(\d+)\s*(sa|dk|g)\s*sonra dolar/);
    if (!m) continue;
    await loadFontsOf(t);
    t.characters = "Bu h\u0131zla " + m[1] + " " + UNIT[m[2]] + " dolar"; n++;
  }
  return n;
}
function accountBadge(label) {
  const b = frame("HORIZONTAL", { name: "hesap rozeti", paddingLeft: 5, paddingRight: 5, paddingTop: 3, paddingBottom: 3, cornerRadius: 5 });
  b.fills = [raw(.4, .4, .4, .13)];
  const t = text(label, { size: 10.5, style: "Semibold" }); t.fills = [raw(.4, .4, .4)]; b.appendChild(t);
  return b;
}
async function splitCard(label) {
  const card = cardComp.createInstance().detachInstance();
  card.name = "Kart \u00b7 " + label;
  const picker = card.findOne(n => n.name === "Hesap Se\u00e7ici");
  if (picker) picker.remove();
  await fixEta(card);
  const name = card.findOne(n => n.type === "TEXT" && n.characters === "Claude");
  if (name && name.parent) name.parent.appendChild(accountBadge(label));
  return card;
}
if (cardComp) {
  const tray = frame("VERTICAL", { name: "Popup \u00b7 ayr\u0131k d\u00fczen", itemSpacing: 6, paddingLeft: 6, paddingRight: 6, paddingTop: 6, paddingBottom: 6, cornerRadius: 14 });
  tray.fills = [paint("sistem/b\u00f6l\u00fcm")]; tray.strokes = [paint("sistem/ayra\u00e7")]; tray.strokeWeight = .5;
  for (const label of ["bireysel", "i\u015f"]) { const c = await splitCard(label); tray.appendChild(c); }
  into(secSplit, tray, 40, 60);
}
into(secSplit, text("Yaln\u0131zca TEK sa\u011flay\u0131c\u0131 ba\u011fl\u0131ysa ve onda birden \u00e7ok hesap varsa her hesap ayr\u0131 kart: hesap \u00e7ipleri yok, hesab\u0131n ad\u0131 (Ayarlar'dan de\u011fi\u015ftirilebilir) ad\u0131n ve plan\u0131n alt\u0131nda sabit boyda rozet. Men\u00fc \u00e7ubu\u011funda hesap ba\u015f\u0131na halka. \u0130kinci bir sa\u011flay\u0131c\u0131 ba\u011flan\u0131nca tek kart + \u00e7iplere d\u00f6ner.", { size: 12, color: "sistem/ikincil yaz\u0131", width: 400 }), 460, 60);

// ============ Popup alt \u015feridindeki bo\u015fluk d\u00fczeltmesi ============
const popupPage = figma.root.children.find(p => p.name === "Popup");
await figma.setCurrentPageAsync(popupPage);
let fixed = 0;
for (const n of popupPage.findAll(n => n.type === "FRAME" && n.name === "bo\u015fluk")) { n.layoutSizingVertical = "FIXED"; n.resize(n.width, 1); fixed++; }
let etas = await fixEta(popupPage);
await figma.setCurrentPageAsync(compPage);
etas += await fixEta(compPage);

await figma.setCurrentPageAsync(screens);
figma.viewport.scrollAndZoomIntoView(screens.children);
if (typeof print === "function") print("Bitti: Ekranlar (Ayarlar 4, Kurulum 6, Men\u00fc \u00c7ubu\u011fu, Giri\u015f penceresi 2, Ayr\u0131k d\u00fczen" + (cardComp ? "" : " \u2014 Kart / \u00d6n y\u00fcz bulunamad\u0131") + "); bo\u015fluk d\u00fczeltmesi: " + fixed + "; etiket metni: " + etas);
