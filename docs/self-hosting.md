# Hosting the web app

Every release has a `pappus-<version>-web.zip` on the
[Releases page](https://github.com/Calyptra-Software/PappusTravelPlanner/releases): the app as
static files. Any web server that serves files can host it. Nothing runs on the server, and
the trips stay in each visitor's browser.

## Trying it locally

```bash
unzip pappus-<version>-web.zip
python3 -m http.server 8000 --directory pappus-<version>-web
```

Then open <http://localhost:8000>.

## Putting it on a server

- **Serve it over HTTPS.** Over plain HTTP the app works, but browsers then store its data
  in IndexedDB instead of OPFS and don't offer the device's position.
- **Serve `.wasm` files as `application/wasm`.** Most servers do already.
- **It expects the root of a domain.** To host it under a path, change
  `<base href="/">` in `index.html` to that path, for example `<base href="/pappus/">`.
- **Each address has its own data.** Browsers keep the trips per origin (scheme, host and
  port). After a move to another address the app starts empty, and clearing a site's data
  in the browser deletes the trips. Visitors keep their trips across either with *Export
  database…* and *Import database…* in the settings.

## What you take on

- **The routing service's [usage policy](https://transitous.org/api/).** Connection
  searches go to Transitous, which allows only non-commercial use. A browser can't always
  name the app in its requests, so the policy asks for contact information on your
  website instead.
- **The OpenStreetMap [tile usage policy](https://operations.osmfoundation.org/policies/tiles/).**
  Maps load tiles from `tile.openstreetmap.org`, which identifies your site by its address.
  Heavy use can get it blocked.
- **Fonts from Google.** For characters the bundled fonts lack, such as Chinese text or
  emoji, the app downloads Noto fonts from `fonts.gstatic.com`. To prevent that, add
  `config: { fontFallbackBaseUrl: "/fonts/" }` to the object passed to
  `_flutter.loader.load` in `flutter_bootstrap.js`, and serve the fonts under that path
  with the same file paths as on `fonts.gstatic.com/s/`. If the fonts are missing there,
  those characters show as boxes.

[SECURITY.md](../SECURITY.md) lists everything the app sends where.
