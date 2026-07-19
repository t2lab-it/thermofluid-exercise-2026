function assert(condition, message = "assertion failed") {
  if (!condition) throw new Error(message);
}

function assertEqual(actual, expected, message = undefined) {
  if (!Object.is(actual, expected)) {
    throw new Error(message ?? `expected ${String(expected)}, got ${String(actual)}`);
  }
}

function assertNotEqual(actual, expected, message = undefined) {
  if (Object.is(actual, expected)) {
    throw new Error(message ?? `expected values to differ, both were ${String(actual)}`);
  }
}

// Production API contract:
//   enhanceSplitNavigation({ anchor, menu, document }) -> trigger button
// The function creates and inserts a separate trigger, controls menu.hidden,
// and wires all pointer, keyboard, Escape, outside-click, and ARIA behavior.

class FakeEvent {
  constructor(type, { key = undefined, target = undefined } = {}) {
    this.type = type;
    this.key = key;
    this.target = target;
    this.currentTarget = null;
    this.defaultPrevented = false;
  }

  preventDefault() {
    this.defaultPrevented = true;
  }
}

class FakeEventTarget {
  constructor() {
    this.listeners = new Map();
  }

  addEventListener(type, handler) {
    const handlers = this.listeners.get(type) ?? [];
    handlers.push(handler);
    this.listeners.set(type, handlers);
  }

  dispatchEvent(event) {
    event.target ??= this;
    event.currentTarget = this;
    for (const handler of this.listeners.get(event.type) ?? []) {
      handler.call(this, event);
    }
    return !event.defaultPrevented;
  }
}

class FakeClassList {
  constructor(element) {
    this.element = element;
    this.values = new Set();
  }

  add(...tokens) {
    tokens.forEach((token) => this.values.add(token));
    this.element.className = [...this.values].join(" ");
  }

  remove(...tokens) {
    tokens.forEach((token) => this.values.delete(token));
    this.element.className = [...this.values].join(" ");
  }

  toggle(token, force = undefined) {
    const enabled = force === undefined ? !this.values.has(token) : force;
    enabled ? this.values.add(token) : this.values.delete(token);
    this.element.className = [...this.values].join(" ");
    return enabled;
  }

  contains(token) {
    return this.values.has(token);
  }
}

class FakeElement extends FakeEventTarget {
  constructor(tagName) {
    super();
    this.tagName = tagName.toUpperCase();
    this.attributes = new Map();
    this.children = [];
    this.parentNode = null;
    this.hidden = false;
    this.id = "";
    this.href = "";
    this.textContent = "";
    this.className = "";
    this.focused = false;
    this.classList = new FakeClassList(this);
  }

  focus() {
    this.focused = true;
  }

  setAttribute(name, value) {
    const stringValue = String(value);
    this.attributes.set(name, stringValue);
    if (name === "id") this.id = stringValue;
  }

  getAttribute(name) {
    return this.attributes.get(name) ?? null;
  }

  removeAttribute(name) {
    this.attributes.delete(name);
  }

  set ariaExpanded(value) {
    this.setAttribute("aria-expanded", value);
  }

  get ariaExpanded() {
    return this.getAttribute("aria-expanded");
  }

  set ariaControls(value) {
    this.setAttribute("aria-controls", value);
  }

  get ariaControls() {
    return this.getAttribute("aria-controls");
  }

  append(...elements) {
    for (const element of elements) {
      this.insertBefore(element, null);
    }
  }

  appendChild(element) {
    this.append(element);
    return element;
  }

  insertBefore(element, reference) {
    if (reference !== null && reference.parentNode !== this) {
      throw new Error("reference node is not a child of this parent");
    }
    if (element.parentNode) {
      const previousIndex = element.parentNode.children.indexOf(element);
      if (previousIndex >= 0) element.parentNode.children.splice(previousIndex, 1);
    }
    const index = reference === null ? this.children.length : this.children.indexOf(reference);
    element.parentNode = this;
    this.children.splice(index, 0, element);
    return element;
  }

  before(...elements) {
    assert(this.parentNode, "element must have a parent before insertion");
    for (const element of elements) this.parentNode.insertBefore(element, this);
  }

  after(...elements) {
    assert(this.parentNode, "element must have a parent before insertion");
    const parent = this.parentNode;
    const reference = parent.children[parent.children.indexOf(this) + 1] ?? null;
    for (const element of elements) parent.insertBefore(element, reference);
  }

  contains(candidate) {
    if (candidate === this) return true;
    return this.children.some((child) => child.contains(candidate));
  }

  querySelector(selector) {
    if (selector === ":scope > .dropdown-menu") {
      return this.children.find((child) => child.classList.contains("dropdown-menu")) ?? null;
    }
    if (selector === ".split-nav-trigger") {
      return this.children.find((child) => child.classList.contains("split-nav-trigger")) ?? null;
    }
    return null;
  }
}

class FakeDocument extends FakeEventTarget {
  constructor({
    hover = true, sectionLinks = [], sidebarLinks = [], offset = "./",
    pathname = "/index.html",
  } = {}) {
    super();
    this.queries = [];
    this.baseURI = "https://example.test/course/";
    this.defaultView = {
      matchMedia: (query) => ({ matches: hover && query.includes("hover") }),
      location: { pathname },
    };
    this.sectionLinks = sectionLinks;
    this.sidebarLinks = sidebarLinks;
    this.offset = offset;
  }

  createElement(tagName) {
    return new FakeElement(tagName);
  }

  querySelectorAll(selector) {
    this.queries.push(selector);
    if (selector === "#quarto-sidebar a.sidebar-link[href]") {
      return this.sidebarLinks;
    }
    return selector.includes("split-navigation") ? this.sectionLinks : [];
  }

  querySelector(selector) {
    if (selector === 'meta[name="quarto:offset"]') {
      return { getAttribute: (name) => name === "content" ? this.offset : null };
    }
    return null;
  }
}

function fire(target, type, options = {}) {
  const event = new FakeEvent(type, options);
  target.dispatchEvent(event);
  return event;
}

function assertClosed(trigger, menu) {
  assertEqual(trigger.getAttribute("aria-expanded"), "false");
  assertEqual(menu.hidden, true);
}

function assertOpen(trigger, menu) {
  assertEqual(trigger.getAttribute("aria-expanded"), "true");
  assertEqual(menu.hidden, false);
}

function referenceEnhanceSplitNavigationUsing({ anchor, menu, document }, insertTrigger) {
  if (!anchor || !menu || !document) return null;

  const item = anchor.parentNode;
  if (!item) return null;

  const trigger = document.createElement("button");
  trigger.setAttribute("type", "button");
  trigger.setAttribute("aria-label", `${anchor.textContent || "section"} menu`);
  trigger.setAttribute("aria-controls", menu.id);
  insertTrigger(anchor, menu, trigger);

  const setOpen = (open) => {
    menu.hidden = !open;
    menu.classList.toggle("show", open);
    item.classList.toggle("split-nav-open", open);
    trigger.setAttribute("aria-expanded", String(open));
  };
  const toggle = () => setOpen(trigger.getAttribute("aria-expanded") !== "true");
  setOpen(false);

  trigger.addEventListener("click", toggle);
  trigger.addEventListener("keydown", (event) => {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      toggle();
    }
  });
  if (document.defaultView.matchMedia("(hover: hover)").matches) {
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

function referenceEnhanceSplitNavigation(options) {
  return referenceEnhanceSplitNavigationUsing(
    options,
    (anchor, _menu, trigger) => anchor.after(trigger),
  );
}

const modulePath = Deno.args[0];
assert(modulePath, "usage: quarto run test/navigation_behavior_test.js assets/navigation.js");

const renderedGuideItem = new FakeElement("li");
renderedGuideItem.classList.add("nav-item", "dropdown");
const renderedGuideToggle = new FakeElement("a");
renderedGuideToggle.classList.add("nav-link", "dropdown-toggle");
renderedGuideToggle.setAttribute("href", "#");
renderedGuideToggle.href = "#";
renderedGuideToggle.setAttribute("rel", "split-navigation split-navigation-guides");
renderedGuideToggle.setAttribute("data-bs-toggle", "dropdown");
renderedGuideToggle.setAttribute("aria-expanded", "false");
renderedGuideToggle.textContent = "ガイド";
const renderedGuideMenu = new FakeElement("ul");
renderedGuideMenu.classList.add("dropdown-menu");
renderedGuideItem.append(renderedGuideToggle, renderedGuideMenu);

const document = new FakeDocument({ sectionLinks: [renderedGuideToggle] });
globalThis.document = document;
globalThis.window = document.defaultView;

let navigation;
if (modulePath === "--self-test") {
  navigation = { enhanceSplitNavigation: referenceEnhanceSplitNavigation };
} else {
  const source = await Deno.readTextFile(modulePath);
  const moduleUrl = `data:text/javascript;charset=utf-8,${encodeURIComponent(source)}`;
  navigation = await import(moduleUrl);
  assert(
    document.queries.some((selector) => selector.includes("split-navigation")),
    "automatic enhancement must select only explicitly marked section links",
  );
  assertEqual(
    renderedGuideToggle.getAttribute("href"),
    "./guides/index.html",
    "automatic enhancement must replace Quarto's dropdown placeholder with the guide parent href",
  );
  assertEqual(renderedGuideToggle.getAttribute("data-bs-toggle"), null);
  assertEqual(renderedGuideToggle.classList.contains("dropdown-toggle"), false);
  assertEqual(renderedGuideToggle.classList.contains("split-nav-anchor"), true);
  assert(renderedGuideItem.children.some((child) => child.tagName === "BUTTON"));
  assert(renderedGuideItem.contains(renderedGuideMenu));

  const nestedItem = new FakeElement("li");
  nestedItem.classList.add("nav-item", "dropdown");
  const nestedToggle = new FakeElement("a");
  nestedToggle.classList.add("nav-link", "dropdown-toggle");
  nestedToggle.setAttribute("href", "#");
  nestedToggle.setAttribute("rel", "split-navigation split-navigation-advanced");
  nestedToggle.textContent = "発展資料";
  const nestedMenu = new FakeElement("ul");
  nestedMenu.classList.add("dropdown-menu");
  nestedItem.append(nestedToggle, nestedMenu);
  const nestedDocument = new FakeDocument({ sectionLinks: [nestedToggle], offset: "../" });
  assertEqual(
    typeof navigation.enhanceRenderedNavbar,
    "function",
    "the actual rendered-navbar path must be directly regression-testable",
  );
  navigation.enhanceRenderedNavbar(nestedDocument);
  assertEqual(
    nestedToggle.getAttribute("href"),
    "../advanced/index.html",
    "nested pages must resolve section parents from Quarto's site-root offset",
  );
}

if (!modulePath.startsWith("--")) {
  assertEqual(
    typeof navigation.syncThemeToggleLabel,
    "function",
    "assets/navigation.js must export syncThemeToggleLabel(toggle)",
  );
  const themeToggle = new FakeElement("a");
  navigation.syncThemeToggleLabel(themeToggle);
  assertEqual(themeToggle.getAttribute("aria-label"), "ダークモード OFF");
  assertEqual(themeToggle.getAttribute("title"), "ダークモード OFF");

  themeToggle.classList.add("alternate");
  navigation.syncThemeToggleLabel(themeToggle);
  assertEqual(themeToggle.getAttribute("aria-label"), "ダークモード ON");
  assertEqual(themeToggle.getAttribute("title"), "ダークモード ON");

  assertEqual(
    typeof navigation.enhanceAssignmentLessonContext,
    "function",
    "assets/navigation.js must export enhanceAssignmentLessonContext(document, pathname)",
  );
  const lessonF00 = new FakeElement("a");
  lessonF00.setAttribute("href", "../lessons/F00.html");
  lessonF00.href = "https://example.test/course/lessons/F00.html";
  const assignmentDocument = new FakeDocument({
    pathname: "/course/assignments/F00.html",
    sidebarLinks: [lessonF00],
  });
  assertEqual(
    navigation.enhanceAssignmentLessonContext(
      assignmentDocument,
      assignmentDocument.defaultView.location.pathname,
    ),
    lessonF00,
  );
  assertEqual(lessonF00.classList.contains("active"), true);
  assertEqual(lessonF00.getAttribute("aria-current"), "step");

  const unmatchedLesson = new FakeElement("a");
  unmatchedLesson.href = "https://example.test/course/lessons/F00.html";
  const unmatchedDocument = new FakeDocument({ sidebarLinks: [unmatchedLesson] });
  assertEqual(
    navigation.enhanceAssignmentLessonContext(unmatchedDocument, "/course/lessons/F00.html"),
    null,
  );
  assertEqual(
    navigation.enhanceAssignmentLessonContext(unmatchedDocument, "/course/assignments/F99.html"),
    null,
  );
}
assertEqual(
  typeof navigation.enhanceSplitNavigation,
  "function",
  "assets/navigation.js must export enhanceSplitNavigation({ anchor, menu, document })",
);

const item = new FakeElement("li");
const anchor = new FakeElement("a");
anchor.setAttribute("href", "guides/index.html");
anchor.href = "guides/index.html";
anchor.textContent = "ガイド";
const menu = new FakeElement("ul");
menu.id = "course-menu";
item.append(anchor, menu);

const trigger = navigation.enhanceSplitNavigation({ anchor, menu, document });
assertNotEqual(trigger, anchor, "the section anchor and dropdown trigger must remain separate");
assertEqual(trigger.tagName, "BUTTON");
assert(item.contains(trigger));
assert(item.contains(menu));
assertEqual(trigger.getAttribute("aria-controls"), menu.id);
assertClosed(trigger, menu);
assertEqual(trigger.getAttribute("type"), "button");
assert(trigger.getAttribute("aria-label")?.trim());
assertEqual(anchor.getAttribute("href"), "guides/index.html");
assertEqual(anchor.href, "guides/index.html");

const anchorClick = fire(anchor, "click");
assertEqual(anchorClick.defaultPrevented, false, "the section anchor must remain navigable");
assertEqual(anchor.href, "guides/index.html");
assertClosed(trigger, menu);

fire(item, "pointerenter", { target: anchor });
assertOpen(trigger, menu);
fire(item, "pointerleave", { target: item });
assertClosed(trigger, menu);

fire(trigger, "click");
assertOpen(trigger, menu);

const enterClose = fire(trigger, "keydown", { key: "Enter" });
assertEqual(enterClose.defaultPrevented, true, "Enter must prevent its native button action");
assertClosed(trigger, menu);
const spaceOpen = fire(trigger, "keydown", { key: " " });
assertEqual(spaceOpen.defaultPrevented, true, "Space must prevent its native button action");
assertOpen(trigger, menu);

const menuItem = new FakeElement("a");
menu.append(menuItem);
fire(document, "keydown", { key: "Escape", target: menuItem });
assertClosed(trigger, menu);
assertEqual(trigger.focused, true, "Escape from within the menu must restore trigger focus");

fire(trigger, "click");
assertOpen(trigger, menu);
const outside = new FakeElement("main");
fire(document, "click", { target: menu });
assertOpen(trigger, menu);
fire(document, "click", { target: outside });
assertClosed(trigger, menu);

const touchDocument = new FakeDocument({ hover: false });
const touchItem = new FakeElement("li");
const touchAnchor = new FakeElement("a");
touchAnchor.href = "guides/index.html";
const touchMenu = new FakeElement("ul");
touchMenu.id = "guides-menu";
touchItem.append(touchAnchor, touchMenu);
const touchTrigger = navigation.enhanceSplitNavigation({
  anchor: touchAnchor,
  menu: touchMenu,
  document: touchDocument,
});
fire(touchTrigger, "pointerenter");
assertClosed(touchTrigger, touchMenu);
fire(touchTrigger, "click");
assertOpen(touchTrigger, touchMenu);
fire(touchItem, "pointerleave", { target: touchItem });
assertOpen(touchTrigger, touchMenu);
fire(touchTrigger, "click");
assertClosed(touchTrigger, touchMenu);
assertEqual(
  navigation.enhanceSplitNavigation({ anchor: null, menu, document }),
  null,
  "missing anchor must skip enhancement",
);
assertEqual(
  navigation.enhanceSplitNavigation({ anchor, menu: null, document }),
  null,
  "missing menu must skip enhancement",
);
console.log("navigation behavior contract passed");
