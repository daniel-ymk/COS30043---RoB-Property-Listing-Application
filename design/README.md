# RoB Property – page designs

Clickable HTML mockups of all 16 pages, built with Bootstrap 5.3.8, the same version as the Vue app. Designed by Zin.

**Open `design/index.html` in a browser.** It shows every page, grouped as public, account and owner pages. Nothing needs installing, but the fonts, Bootstrap and maps load from the internet.

## On every page
- **Mockup bar** (dark box, bottom right): switch *View as* between guest, viewer and owner, and *State* between ready, loading, empty and error. The bar is not part of the product.
- **Dev notes** (yellow box at the bottom): the API calls from `docs/api.md`, the components and the team member who builds the page.

## Using it in the Vue app
| Mockup file | Use it for |
|---|---|
| `css/rob.css` § 1 `:root` | Copy into `frontend/src/assets/main.css`. Every Bootstrap class picks up the RoB colours, fonts and radii. |
| `css/rob.css` § 2–9 | Styles for the components below. Copy the parts a component needs into its `<style>` or into `main.css`. |
| `js/rob.js` `card()` | `PropertyCard.vue` |
| `js/rob.js` `nav()` / `footer()` | `AppNavbar.vue` (guest / viewer / owner) and `AppFooter.vue` |
| `js/rob.js` `empty()` / `errorBox()` / `cardSkeleton()` | `EmptyState.vue`, `ErrorAlert.vue`, `CardSkeleton.vue` |
| `pages/components.html` | The design system on one page: colours with contrast ratios, type, buttons, form states, badges, cards |

Icons are [Bootstrap Icons](https://icons.getbootstrap.com/) 1.11.3 (`npm i bootstrap-icons`). Fonts are Lexend (headings) and Source Sans 3 (text) from Google Fonts. Maps use Leaflet 1.9.4 with OpenStreetMap.

## Checks done
- Every text colour pair passes WCAG AA (4.5:1); form borders pass 3:1.
- axe-core 4.10 reports no WCAG 2 A/AA or best-practice violations on any page at 1440px or 390px.
- Layout checked at 1440px and 390px.

## Photos
`img/` holds stand-in photos from Unsplash (free to use). The real app shows owners' uploads from `backend/uploads/`.
