// Animations reprises de PowerPoint, paragraphe par paragraphe.
// Un marqueur vide en tête de paragraphe ou d'élément de liste :
//   - []{.frag fragment-index=2} texte             apparaît à l'étape 2
//   - []{.frag out-index=3} texte                  disparaît à l'étape 3
//   - []{.frag fragment-index=2 out-index=3} texte  visible à l'étape 2 seulement
// est transformé en fragment reveal.js sur l'élément de liste (avec ses
// sous-éléments) ou sur le paragraphe qui le contient. Les images et blocs
// utilisent directement les classes .fragment de Quarto.
//
// Plugin reveal.js (et non simple <script> en fin de page) : `init` est appelé
// avant que reveal.js ne recense les fragments et ne lise l'étape demandée
// dans l'URL (#/diapositive/étape : rechargement de la page, vue orateur).
window.RevealFrag = function () {
  return {
    id: "RevealFrag",
    init: function (deck) {
      deck.getRevealElement().querySelectorAll("span.frag").forEach(function (m) {
        var target = m.parentElement;
        if (target.tagName === "P" && target.parentElement.tagName === "LI" &&
            target === target.parentElement.firstElementChild) {
          target = target.parentElement;
        }
        var a = m.getAttribute("data-fragment-index");
        var d = m.getAttribute("data-out-index");
        if (a !== null) {
          target.classList.add("fragment");
          target.setAttribute("data-fragment-index", a);
        }
        if (d !== null) {
          // disparition : enveloppe le contenu dans un fragment .fade-out
          var wrap = document.createElement(target.tagName === "LI" ? "div" : "span");
          wrap.className = "fragment fade-out";
          wrap.setAttribute("data-fragment-index", d);
          while (target.firstChild) { wrap.appendChild(target.firstChild); }
          target.appendChild(wrap);
          if (target.tagName === "LI") { wrap.style.display = "inline-block"; wrap.style.verticalAlign = "top"; }
        }
        m.remove();
      });
    }
  };
};
