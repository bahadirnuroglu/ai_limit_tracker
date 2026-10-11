// Figma eklenti ortaminin hangi JavaScript kaliplarini tanidigini dener
const tests = {
  "for-of parcalama": "async () => { for (const [a, b] of [[1, 2]]) await 0; }",
  "nesne yayma": "() => { const a = {x: 1}; return { ...a, y: 2 }; }",
  "dizi yayma": "() => [...[1, 2]]",
  "parametre varsayilan nesne": "function f(a, { b = 1, c } = {}) { return b; }",
  "async function bildirimi": "async function g() { await 0; }",
  "ok fonksiyonu nesne": "() => ({ a: 1 })",
  "sablon metin": "() => `x ${1}`",
  "unicode kacis": "() => \"a\\u0131b\"",
  "nokta ile baslayan sayi": "() => .85",
  "?? isleci": "() => null ?? 1",
  "?. isleci": "() => ({})?.a",
  "catch degiskensiz": "() => { try {} catch {} }",
  "varsayilan parametre": "(a, b = 1) => a",
  "forEach parcalama": "() => [[1, 2]].forEach(([a, b], i) => a)",
  "for of": "() => { for (const x of [1]) {} }",
  "let/const": "() => { let a = 1; const b = 2; }",
  "ust seviye await (Function icinde)": "await 0",
};
const results = [];
for (const name in tests) {
  try { new Function(tests[name]); results.push("OK   " + name); }
  catch (e) { results.push("HATA " + name + "  ->  " + e.message); }
}
print(results.join("\n"));
