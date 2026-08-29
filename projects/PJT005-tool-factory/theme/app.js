/* ツール共通の挙動。ページ側は TOOL_SPEC を定義するだけでよい。
   - 入力が変わるたびに再計算する
   - 計算結果を URL に載せる（共有・再現ができる）
   - 読み込み時に URL のパラメータを復元する
   計算はすべてブラウザ内で完結し、入力値がサーバーへ送られることはない。 */
(function () {
  "use strict";

  var spec = window.TOOL_SPEC;
  if (!spec) return;

  var form = document.getElementById("calc");
  if (!form) return;

  function el(id) { return document.getElementById(id); }

  function readValue(field) {
    var node = el("in-" + field.key);
    if (!node) return NaN;
    var raw = node.value;
    if (raw === "" || raw === null) return NaN;
    var n = Number(raw);
    return isFinite(n) ? n : NaN;
  }

  function format(value, decimals) {
    if (!isFinite(value)) return "—";
    return value.toLocaleString("ja-JP", {
      minimumFractionDigits: decimals,
      maximumFractionDigits: decimals
    });
  }

  function calculate() {
    var scope = {};
    var missing = false;

    spec.inputs.forEach(function (f) {
      var v = readValue(f);
      if (isNaN(v)) missing = true;
      scope[f.key] = v;
    });

    spec.outputs.forEach(function (o) {
      var value = NaN;
      if (!missing) {
        try {
          value = o.compute(scope);
        } catch (e) {
          value = NaN;
        }
      }
      if (typeof value !== "number" || !isFinite(value)) value = NaN;
      scope[o.key] = value;

      var row = el("out-" + o.key);
      var slot = el("val-" + o.key);
      if (slot) slot.textContent = format(value, o.decimals);
      if (row) row.classList.toggle("invalid", isNaN(value));
    });

    return scope;
  }

  function syncUrl() {
    if (!window.history || !window.history.replaceState) return;
    var params = new URLSearchParams();
    spec.inputs.forEach(function (f) {
      var node = el("in-" + f.key);
      if (node && node.value !== "") params.set(f.key, node.value);
    });
    var query = params.toString();
    window.history.replaceState(null, "", query ? "?" + query : location.pathname);
  }

  function restoreFromUrl() {
    var params = new URLSearchParams(location.search);
    spec.inputs.forEach(function (f) {
      if (!params.has(f.key)) return;
      var node = el("in-" + f.key);
      if (!node) return;
      var value = params.get(f.key);
      if (node.tagName === "SELECT") {
        var ok = Array.prototype.some.call(node.options, function (o) {
          return o.value === value;
        });
        if (ok) node.value = value;
      } else if (value !== "" && isFinite(Number(value))) {
        node.value = value;
      }
    });
  }

  function resetAll() {
    spec.inputs.forEach(function (f) {
      var node = el("in-" + f.key);
      if (node) node.value = f.default;
    });
    calculate();
    syncUrl();
  }

  function copyLink(button) {
    var done = function () {
      var mark = document.createElement("span");
      mark.className = "copied";
      mark.textContent = "コピーしました";
      button.parentNode.appendChild(mark);
      setTimeout(function () { mark.remove(); }, 2000);
    };
    var url = location.href;
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(url).then(done, function () {});
    } else {
      var box = document.createElement("textarea");
      box.value = url;
      document.body.appendChild(box);
      box.select();
      try { document.execCommand("copy"); done(); } catch (e) {}
      box.remove();
    }
  }

  form.addEventListener("input", function () { calculate(); syncUrl(); });
  form.addEventListener("change", function () { calculate(); syncUrl(); });
  form.addEventListener("submit", function (e) { e.preventDefault(); });

  var resetButton = el("reset");
  if (resetButton) resetButton.addEventListener("click", resetAll);

  var copyButton = el("copy");
  if (copyButton) copyButton.addEventListener("click", function () { copyLink(copyButton); });

  restoreFromUrl();
  calculate();
})();
