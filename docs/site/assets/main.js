/*
 * Progressive enhancement only. The page works without this file.
 * It adds previous and next buttons to the screenshot row.
 */
(function () {
  "use strict";

  var gallery = document.querySelector("[data-gallery]");
  var controls = document.querySelector("[data-gallery-controls]");
  if (!gallery || !controls) {
    return;
  }

  var buttons = controls.querySelectorAll("button");
  var reduce = window.matchMedia("(prefers-reduced-motion: reduce)");

  function update() {
    var max = gallery.scrollWidth - gallery.clientWidth - 1;
    var overflows = max > 0;
    controls.hidden = !overflows;
    buttons[0].disabled = gallery.scrollLeft <= 0;
    buttons[1].disabled = gallery.scrollLeft >= max;
  }

  controls.addEventListener("click", function (event) {
    var button = event.target.closest("button");
    if (!button) {
      return;
    }
    var item = gallery.querySelector("li");
    var step = item ? item.getBoundingClientRect().width + 24 : 280;
    var dir = Number(button.getAttribute("data-dir"));
    gallery.scrollBy({
      left: dir * step * 2,
      behavior: reduce.matches ? "auto" : "smooth"
    });
  });

  gallery.addEventListener("scroll", update, { passive: true });
  window.addEventListener("resize", update);
  update();
})();
