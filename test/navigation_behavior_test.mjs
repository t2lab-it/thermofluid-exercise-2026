import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

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
      element.parentNode = this;
      this.children.push(element);
    }
  }

  appendChild(element) {
    this.append(element);
    return element;
  }

  after(element) {
    assert.ok(this.parentNode, "anchor must have a parent before enhancement");
    const index = this.parentNode.children.indexOf(this);
    element.parentNode = this.parentNode;
    this.parentNode.children.splice(index + 1, 0, element);
  }

  contains(candidate) {
    if (candidate === this) return true;
    return this.children.some((child) => child.contains(candidate));
  }
}

class FakeDocument extends FakeEventTarget {
  constructor({ hover = true } = {}) {
    super();
    this.defaultView = {
      matchMedia: (query) => ({ matches: hover && query.includes("hover") }),
    };
  }

  createElement(tagName) {
    return new FakeElement(tagName);
  }

  querySelectorAll() {
    return [];
  }
}

function fire(target, type, options = {}) {
  const event = new FakeEvent(type, options);
  target.dispatchEvent(event);
  return event;
}

function assertClosed(trigger, menu) {
  assert.equal(trigger.getAttribute("aria-expanded"), "false");
  assert.equal(menu.hidden, true);
}

function assertOpen(trigger, menu) {
  assert.equal(trigger.getAttribute("aria-expanded"), "true");
  assert.equal(menu.hidden, false);
}

function referenceEnhanceSplitNavigation({ anchor, menu, document }) {
  const trigger = document.createElement("button");
  trigger.setAttribute("type", "button");
  trigger.setAttribute("aria-label", `${anchor.textContent || "section"} menu`);
  trigger.setAttribute("aria-controls", menu.id);
  anchor.after(trigger);

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
    if (event.key === "Escape") setOpen(false);
  });
  document.addEventListener("click", (event) => {
    if (!trigger.contains(event.target) && !menu.contains(event.target)) setOpen(false);
  });
  return trigger;
}

const modulePath = process.argv[2];
assert.ok(modulePath, "usage: node navigation_behavior_test.mjs assets/navigation.js");

const document = new FakeDocument();
globalThis.document = document;
globalThis.window = document.defaultView;

let navigation;
if (modulePath === "--self-test") {
  navigation = { enhanceSplitNavigation: referenceEnhanceSplitNavigation };
} else {
  const source = await readFile(modulePath, "utf8");
  const moduleUrl = `data:text/javascript;base64,${Buffer.from(source).toString("base64")}`;
  navigation = await import(moduleUrl);
}
assert.equal(
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
assert.notEqual(trigger, anchor, "the section anchor and dropdown trigger must remain separate");
assert.equal(trigger.tagName, "BUTTON");
assert.deepEqual(item.children, [anchor, trigger, menu]);
assert.equal(trigger.getAttribute("aria-controls"), menu.id);
assertClosed(trigger, menu);
assert.equal(trigger.getAttribute("type"), "button");
assert.ok(trigger.getAttribute("aria-label")?.trim());

const anchorClick = fire(anchor, "click");
assert.equal(anchorClick.defaultPrevented, false, "the section anchor must remain navigable");
assert.equal(anchor.href, "lessons/index.html");
assertClosed(trigger, menu);

fire(trigger, "pointerenter");
assertOpen(trigger, menu);

fire(trigger, "click");
assertClosed(trigger, menu);
fire(trigger, "click");
assertOpen(trigger, menu);

fire(trigger, "keydown", { key: "Enter" });
assertClosed(trigger, menu);
fire(trigger, "keydown", { key: "Enter" });
assertOpen(trigger, menu);

fire(trigger, "keydown", { key: " " });
assertClosed(trigger, menu);
fire(trigger, "keydown", { key: " " });
assertOpen(trigger, menu);

fire(document, "keydown", { key: "Escape", target: trigger });
assertClosed(trigger, menu);

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
