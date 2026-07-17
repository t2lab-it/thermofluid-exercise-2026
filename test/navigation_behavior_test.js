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

function assertChildren(actual, expected) {
  assertEqual(actual.length, expected.length, "unexpected child count");
  expected.forEach((child, index) => {
    assertEqual(actual[index], child, `unexpected child at index ${index}`);
  });
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
}

class FakeDocument extends FakeEventTarget {
  constructor({ hover = true } = {}) {
    super();
    this.queries = [];
    this.defaultView = {
      matchMedia: (query) => ({ matches: hover && query.includes("hover") }),
    };
  }

  createElement(tagName) {
    return new FakeElement(tagName);
  }

  querySelectorAll(selector) {
    this.queries.push(selector);
    return [];
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
  const trigger = document.createElement("button");
  trigger.setAttribute("type", "button");
  trigger.setAttribute("aria-label", `${anchor.textContent || "section"} menu`);
  trigger.setAttribute("aria-controls", menu.id);
  insertTrigger(anchor, menu, trigger);

  const setOpen = (open) => {
    menu.hidden = !open;
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

function referenceEnhanceSplitNavigation(options) {
  return referenceEnhanceSplitNavigationUsing(
    options,
    (anchor, _menu, trigger) => anchor.after(trigger),
  );
}

function referenceEnhanceSplitNavigationWithInsertBefore(options) {
  return referenceEnhanceSplitNavigationUsing(
    options,
    (anchor, menu, trigger) => anchor.parentNode.insertBefore(trigger, menu),
  );
}

const modulePath = Deno.args[0];
assert(modulePath, "usage: quarto run test/navigation_behavior_test.js assets/navigation.js");

const document = new FakeDocument();
globalThis.document = document;
globalThis.window = document.defaultView;

let navigation;
if (modulePath === "--self-test") {
  navigation = { enhanceSplitNavigation: referenceEnhanceSplitNavigation };
} else if (modulePath === "--insert-before-self-test") {
  navigation = { enhanceSplitNavigation: referenceEnhanceSplitNavigationWithInsertBefore };
} else {
  const source = await Deno.readTextFile(modulePath);
  const moduleUrl = `data:text/javascript;charset=utf-8,${encodeURIComponent(source)}`;
  navigation = await import(moduleUrl);
  assert(
    document.queries.some((selector) => selector.includes("split-navigation")),
    "automatic enhancement must select only explicitly marked section links",
  );
}
assertEqual(
  typeof navigation.enhanceSplitNavigation,
  "function",
  "assets/navigation.js must export enhanceSplitNavigation({ anchor, menu, document })",
);

const item = new FakeElement("li");
const anchor = new FakeElement("a");
anchor.href = "lessons/index.html";
anchor.textContent = "授業";
const menu = new FakeElement("ul");
menu.id = "course-menu";
item.append(anchor, menu);

const trigger = navigation.enhanceSplitNavigation({ anchor, menu, document });
assertNotEqual(trigger, anchor, "the section anchor and dropdown trigger must remain separate");
assertEqual(trigger.tagName, "BUTTON");
assertChildren(item.children, [anchor, trigger, menu]);
assertEqual(trigger.getAttribute("aria-controls"), menu.id);
assertClosed(trigger, menu);
assertEqual(trigger.getAttribute("type"), "button");
assert(trigger.getAttribute("aria-label")?.trim());

const anchorClick = fire(anchor, "click");
assertEqual(anchorClick.defaultPrevented, false, "the section anchor must remain navigable");
assertEqual(anchor.href, "lessons/index.html");
assertClosed(trigger, menu);

fire(trigger, "pointerenter");
assertOpen(trigger, menu);

fire(trigger, "click");
assertClosed(trigger, menu);
fire(trigger, "click");
assertOpen(trigger, menu);

const enterClose = fire(trigger, "keydown", { key: "Enter" });
assertEqual(enterClose.defaultPrevented, true, "Enter must prevent its native button action");
assertClosed(trigger, menu);
const enterOpen = fire(trigger, "keydown", { key: "Enter" });
assertEqual(enterOpen.defaultPrevented, true, "Enter must prevent its native button action");
assertOpen(trigger, menu);

const spaceClose = fire(trigger, "keydown", { key: " " });
assertEqual(spaceClose.defaultPrevented, true, "Space must prevent its native button action");
assertClosed(trigger, menu);
const spaceOpen = fire(trigger, "keydown", { key: " " });
assertEqual(spaceOpen.defaultPrevented, true, "Space must prevent its native button action");
assertOpen(trigger, menu);

fire(document, "keydown", { key: "Escape", target: trigger });
assertClosed(trigger, menu);
assertEqual(trigger.focused, true, "Escape from the trigger must restore trigger focus");

trigger.focused = false;
fire(trigger, "click");
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
console.log("navigation behavior contract passed");
