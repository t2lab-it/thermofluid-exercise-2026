const SECTION_HREFS = new Map([
  ["split-navigation-guides", "guides/index.html"],
  ["split-navigation-advanced", "advanced/index.html"],
]);

const SVG_NAMESPACE = "http://www.w3.org/2000/svg";

function createThemeIcon(document, className, children) {
  const svg = document.createElementNS(SVG_NAMESPACE, "svg");
  svg.classList.add("tf-theme-icon", className);
  svg.setAttribute("viewBox", "0 0 16 16");
  svg.setAttribute("aria-hidden", "true");
  svg.setAttribute("focusable", "false");
  for (const child of children) svg.append(child);
  return svg;
}

function createSvgPart(document, tagName, attributes) {
  const part = document.createElementNS(SVG_NAMESPACE, tagName);
  for (const [name, value] of Object.entries(attributes)) part.setAttribute(name, value);
  return part;
}

function buildThemeTogglePresentation(toggle, document) {
  const sun = createThemeIcon(document, "tf-theme-icon-sun", [
    createSvgPart(document, "circle", {
      cx: "8", cy: "8", r: "3.25", fill: "currentColor",
    }),
    createSvgPart(document, "path", {
      d: "M8 0.75v1.5M8 13.75v1.5M0.75 8h1.5M13.75 8h1.5M2.87 2.87l1.06 1.06M12.07 12.07l1.06 1.06M13.13 2.87l-1.06 1.06M3.93 12.07l-1.06 1.06",
      fill: "none",
      stroke: "currentColor",
      "stroke-width": "1.25",
      "stroke-linecap": "round",
    }),
  ]);
  const track = document.createElement("span");
  track.classList.add("tf-theme-switch-track");
  track.setAttribute("aria-hidden", "true");
  const thumb = document.createElement("span");
  thumb.classList.add("tf-theme-switch-thumb");
  track.append(thumb);
  const moon = createThemeIcon(document, "tf-theme-icon-moon", [
    createSvgPart(document, "path", {
      d: "M11.9 11.35A5.6 5.6 0 0 1 4.65 4.1 5.75 5.75 0 1 0 11.9 11.35Z",
      fill: "currentColor",
    }),
  ]);
  toggle.replaceChildren(sun, track, moon);
}

export function syncThemeToggleLabel(toggle) {
  if (!toggle) return null;
  const enabled = toggle.classList?.contains("alternate") ?? false;
  const label = `ダークモード ${enabled ? "ON" : "OFF"}`;
  toggle.setAttribute("role", "switch");
  toggle.setAttribute("aria-checked", String(enabled));
  toggle.setAttribute("aria-label", label);
  toggle.setAttribute("title", label);
  return label;
}

export function enhanceThemeToggle(document) {
  const toggle = document?.querySelector?.(".quarto-color-scheme-toggle");
  if (!toggle) return null;

  if (!toggle.classList.contains("tf-theme-switch")) {
    buildThemeTogglePresentation(toggle, document);
    toggle.classList.add("tf-theme-switch");
    toggle.addEventListener("click", () => {
      globalThis.queueMicrotask(() => syncThemeToggleLabel(toggle));
    });
  }
  syncThemeToggleLabel(toggle);
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
