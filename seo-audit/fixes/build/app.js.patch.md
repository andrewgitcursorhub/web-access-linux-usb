# Companion change to `assets/app.js` for build-time inlining (P2-1)

One small edit. Without it the build-time inlining still works, but every page would
re-fetch and overwrite the header and footer you just inlined, so you would keep the
two extra network round-trips you were trying to remove.

## The current code

```js
function loadPartial(id, url, callback) {
  const el = document.getElementById(id);
  if (!el) return;

  fetch(url)
    .then((res) => res.text())
    .then((html) => {
      el.innerHTML = html;
      if (typeof callback === 'function') callback(el);
    })
    .catch((err) => console.error('Error loading', url, err));
}
```

## The change

Add the three-line short-circuit. Everything else stays as it is.

```js
function loadPartial(id, url, callback) {
  const el = document.getElementById(id);
  if (!el) return;

  // Already inlined at build time by build/inline-partials.mjs. Skip the network
  // round-trip, but still run the callback so initHeaderChrome() and adjustFooter()
  // wire up as normal.
  if (el.children.length > 0) {
    if (typeof callback === 'function') callback(el);
    return;
  }

  fetch(url)
    .then((res) => res.text())
    .then((html) => {
      el.innerHTML = html;
      if (typeof callback === 'function') callback(el);
    })
    .catch((err) => console.error('Error loading', url, err));
}
```

## Why it is written this way

**The callback must still fire.** `loadPartial` is called as:

```js
loadPartial('header-placeholder', '/partials/header', initHeaderChrome)
loadPartial('footer-placeholder', '/partials/footer', () => { adjustFooter(); ... })
```

`initHeaderChrome()` wires up the mobile menu button. `adjustFooter()` handles footer
spacing on short pages. Returning early without calling the callback would ship a
broken mobile menu — which is why the short-circuit calls it rather than just
returning.

**The wrapper `<div>` must survive.** `adjustFooter()` selects
`'#footer-placeholder .site-footer'`. If the build replaced the placeholder div with
the footer markup instead of filling it, that selector would stop matching and the
spacing logic would silently die. `inline-partials.mjs` fills the div and leaves the
wrapper in place specifically for this.

**It degrades safely.** If the build step ever fails to run, the placeholders arrive
empty, `el.children.length` is `0`, and the old fetch path runs exactly as it does
today. You cannot end up with a page that has no navigation.

## Optional follow-up, once you have confirmed inlining works in production

At that point nothing fetches `/partials/*` any more, so you can:

1. Delete the two `loadPartial(...)` call sites and the `loadPartial` function.
2. Call `initHeaderChrome()` and the footer callback directly on `DOMContentLoaded`.
3. Move `partials/header.html` and `partials/footer.html` out of the published output
   so those URLs stop existing entirely. That fully closes P1-4 — no `robots.txt`
   rule and no `X-Robots-Tag` needed, because there is nothing left to crawl.

Do this only after production is verified. Until then keep the fallback.
