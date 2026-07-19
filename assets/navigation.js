export function enhanceSplitNavigation({ anchor, menu, document }) {
  if (!anchor || !menu || !document) return null;

  const item = anchor.parentNode;
  if (!item) return null;

  const trigger = document.createElement("button");
  const label = anchor.textContent?.trim() || "section";

  trigger.className = "nav-link split-nav-trigger";
  trigger.setAttribute("type", "button");
  trigger.setAttribute("aria-label", `${label}のメニュー`);
  trigger.setAttribute("aria-controls", menu.id);
  trigger.setAttribute("aria-haspopup", "true");

  const setOpen = (open) => {
    menu.hidden = !open;
    menu.classList?.toggle("show", open);
    item.classList?.toggle("split-nav-open", open);
    trigger.setAttribute("aria-expanded", String(open));
  };
  const toggle = () => setOpen(trigger.getAttribute("aria-expanded") !== "true");

  setOpen(false);
  if (typeof anchor.after === "function") {
    anchor.after(trigger);
  } else {
    item.insertBefore(trigger, menu);
  }

  trigger.addEventListener("click", toggle);
  trigger.addEventListener("keydown", (event) => {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      toggle();
    }
  });
  if (document.defaultView?.matchMedia?.("(hover: hover)").matches) {
    trigger.addEventListener("pointerenter", () => setOpen(true));
    item.addEventListener("pointerleave", () => setOpen(false));
  }
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && (trigger.contains(event.target) || menu.contains(event.target))) {
      setOpen(false);
      trigger.focus();
    }
  });
  document.addEventListener("click", (event) => {
    if (!trigger.contains(event.target) && !menu.contains(event.target)) setOpen(false);
  });

  return trigger;
}

function enhanceRenderedNavbar(document) {
  const sectionLinks = document.querySelectorAll(
    '.navbar .nav-item.dropdown > a[rel~="split-navigation"]',
  );
  for (const anchor of sectionLinks) {
    const item = anchor.parentNode;
    const menu = item?.querySelector(":scope > .dropdown-menu");
    if (!anchor.getAttribute("href") || !menu || item.querySelector(".split-nav-trigger")) continue;

    if (!menu.id) menu.id = `${anchor.id || "navbar-section"}-submenu`;
    anchor.classList.remove("dropdown-toggle");
    anchor.removeAttribute("data-bs-toggle");
    anchor.removeAttribute("aria-expanded");
    anchor.classList.add("split-nav-anchor");
    enhanceSplitNavigation({ anchor, menu, document });
  }
}

if (typeof globalThis.document !== "undefined") {
  enhanceRenderedNavbar(globalThis.document);
}
