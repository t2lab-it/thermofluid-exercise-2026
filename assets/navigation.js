const SECTION_HREFS = new Map([
  ["split-navigation-guides", "guides/index.html"],
  ["split-navigation-advanced", "advanced/index.html"],
]);

export function syncThemeToggleLabel(toggle) {
  if (!toggle) return null;
  const enabled = toggle.classList?.contains("alternate") ?? false;
  const label = `ダークモード ${enabled ? "ON" : "OFF"}`;
  toggle.setAttribute("aria-label", label);
  toggle.setAttribute("title", label);
  return label;
}

export function enhanceThemeToggle(document) {
  const toggle = document?.querySelector?.(".quarto-color-scheme-toggle");
  if (!toggle) return null;

  syncThemeToggleLabel(toggle);
  toggle.addEventListener("click", () => {
    globalThis.queueMicrotask(() => syncThemeToggleLabel(toggle));
  });
  return toggle;
}

export function enhanceAssignmentLessonContext(document, pathname) {
  const match = pathname?.match(/\/assignments\/([^/]+)\.html$/);
  if (!match || !document) return null;

  const lessonSuffix = "/lessons/" + match[1] + ".html";
  const lessonLink = [...document.querySelectorAll("#quarto-sidebar a.sidebar-link[href]")]
    .find((link) => new URL(link.href, document.baseURI).pathname.endsWith(lessonSuffix));
  if (!lessonLink) return null;

  lessonLink.classList.add("active");
  lessonLink.setAttribute("aria-current", "step");
  return lessonLink;
}

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
    item.addEventListener("pointerenter", () => setOpen(true));
    item.addEventListener("pointerleave", () => setOpen(false));
  }
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && trigger.getAttribute("aria-expanded") === "true") {
      setOpen(false);
      trigger.focus();
    }
  });
  document.addEventListener("click", (event) => {
    if (!trigger.contains(event.target) && !menu.contains(event.target)) setOpen(false);
  });

  return trigger;
}

export function enhanceRenderedNavbar(document) {
  const sectionLinks = document.querySelectorAll(
    '.navbar .nav-item.dropdown > a[rel~="split-navigation"]',
  );
  const siteOffset =
    document.querySelector('meta[name="quarto:offset"]')?.getAttribute("content") ?? "./";
  for (const anchor of sectionLinks) {
    const item = anchor.parentNode;
    const menu = item?.querySelector(":scope > .dropdown-menu");
    const relTokens = anchor.getAttribute("rel")?.trim().split(/\s+/) ?? [];
    const sectionHref = relTokens
      .map((token) => SECTION_HREFS.get(token))
      .find((href) => href);
    if (!sectionHref || !menu || item.querySelector(".split-nav-trigger")) continue;

    if (!menu.id) menu.id = `${anchor.id || "navbar-section"}-submenu`;
    anchor.setAttribute("href", `${siteOffset}${sectionHref}`);
    anchor.classList.remove("dropdown-toggle");
    anchor.removeAttribute("data-bs-toggle");
    anchor.removeAttribute("aria-expanded");
    anchor.classList.add("split-nav-anchor");
    enhanceSplitNavigation({ anchor, menu, document });
  }
}

if (typeof globalThis.document !== "undefined") {
  enhanceRenderedNavbar(globalThis.document);
  enhanceThemeToggle(globalThis.document);
  enhanceAssignmentLessonContext(globalThis.document, globalThis.location?.pathname);
}
