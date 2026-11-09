# RoB Property – REST API Contract

This document is the agreement between the Vue frontend and the PHP backend.
The backend must return exactly these shapes.

**Change rule:** any change to an endpoint, field name or status code needs a
heads-up in the group chat and an update to this file *in the same commit*.

Related files: [`backend/database/schema.sql`](../backend/database/schema.sql)
(tables + reference SQL for most endpoints) and
[`backend/database/seed.sql`](../backend/database/seed.sql) (test accounts).

---

## 1. Conventions

### Resources and URLs
A RESTful API: each resource has its own URL, and the HTTP method says what to
do with it (`GET` read, `POST` create, `PUT` replace, `PATCH` change part,
`DELETE` remove). All requests go through one router, `backend/api/index.php`;
`backend/api/.htaccess` rewrites clean paths to it, and the handlers live one
file per resource in `backend/api/resources/`.

```
<API_BASE>/session            login state
<API_BASE>/users              accounts
<API_BASE>/me                 the logged-in user (profile, my likes, my listings, my slots, my viewings)
<API_BASE>/properties         listings
<API_BASE>/properties/5/images, /images/31
<API_BASE>/properties/5/slots
<API_BASE>/appointments
<API_BASE>/map
```

If Mercury ever blocks `mod_rewrite`, every route also works as
`<API_BASE>/index.php/properties/5`, so only `VITE_API_BASE` changes.

The frontend reads the base URLs from `frontend/.env`:

```
VITE_API_BASE=/~s1234567/rob/backend/api
VITE_BACKEND_URL=/~s1234567/rob/backend
```

Image URL = `VITE_BACKEND_URL + '/' + file_path`
(e.g. `/~s1234567/rob/backend/uploads/seed/condo.jpg`).

### Requests
- Request bodies are JSON (`Content-Type: application/json`), except photo
  upload, which is `multipart/form-data`.
- IDs go in the path (`/properties/5`); filters, sorting and paging go in the
  query string (`/properties?city=Kuching&page=2`).

### Responses
Every response is JSON (except `204`).

```jsonc
// success - single item
{ "data": { ... } }

// success - list with pagination
{ "data": [ ... ], "meta": { "page": 1, "per_page": 12, "total": 30, "total_pages": 3 } }

// error
{ "error": "Validation failed", "fields": { "email": "Email is already registered" } }
```

`fields` only appears on `422` errors, keyed by input name, so forms can show
the message under the right input.

### Status codes
| Code | When |
|---|---|
| `200` | OK |
| `201` | Created (returns the new item) |
| `204` | Deleted / logged out, no body |
| `400` | Malformed request (bad JSON) |
| `401` | Not logged in |
| `403` | Logged in, but not allowed (not your listing, viewer trying to post) |
| `404` | Item or route does not exist |
| `405` | Route exists but not with this method (`Allow` header lists the methods) |
| `409` | Conflict (slot already booked, day already has a slot, wrong status for a change) |
| `422` | Validation failed – see `fields` |
| `500` | Server/database error – never send SQL error text to the client |

### Data types
PDO returns every column as a string. PHP must cast before `json_encode`:
IDs, counts, bedrooms etc. → `int`; `price`, `floor_area_sqm`, `latitude`,
`longitude` → `float`; `is_furnished`, `is_booked` → `bool`.
Dates are `"YYYY-MM-DD"`, times `"HH:MM"`, timestamps `"YYYY-MM-DD HH:MM:SS"` (UTC+8).

### Authentication
PHP sessions (cookie, `HttpOnly`, `SameSite=Lax`). The Vue app and API are
served from the same Mercury origin, so the browser sends the cookie
automatically – no tokens, no CORS.

- After login, PHP stores `$_SESSION['user_id']` and calls `session_regenerate_id(true)`.
- On app start, Vue calls `GET /session` to restore the logged-in user into the Pinia store.
- On any `401`, Vue clears the store and redirects to `/login?redirect=<current path>`.

**Local development:** run PHP locally (XAMPP) against a local copy of
the schema + seed, and set a Vite proxy so `/api` calls stay same-origin:

```js
// vite.config.js
server: { proxy: { '/api': { target: 'http://localhost', rewrite: p => p.replace(/^\/api/, '/rob/backend/api') } } }
```

### Access levels used below
| Level | Meaning |
|---|---|
| **Guest** | Anyone, logged in or not |
| **User** | Any logged-in user (owner or viewer) |
| **Owner** | Logged in with `role = 'owner'` |
| **Own** | Owner of *that specific* listing / slot (checked in SQL with `owner_id = $_SESSION['user_id']`) |

Liking and booking are open to any **User** (an owner can like or book other
owners' listings, never their own).

---

## 2. Shared objects

### User
```json
{ "user_id": 5, "full_name": "Sarah Tan", "email": "sarah@example.com",
  "role": "viewer", "phone": null, "created_at": "2026-11-05 10:00:00" }
```
`password_hash` is **never** returned.

### Property card (used in lists)
```json
{
  "property_id": 1,
  "title": "Fully furnished 2-bed condo in Mont Kiara",
  "listing_type": "rent",
  "property_type": "condo",
  "price": 3800.0,
  "bedrooms": 2,
  "bathrooms": 2,
  "parking_spaces": 1,
  "floor_area_sqm": 95.0,
  "is_furnished": true,
  "city": "Kuala Lumpur",
  "state": "Wilayah Persekutuan",
  "latitude": 3.17,
  "longitude": 101.65,
  "status": "available",
  "cover_image": "uploads/seed/condo.jpg",
  "like_count": 3,
  "liked_by_me": false,
  "is_mine": false,
  "created_at": "2026-11-03 10:00:00"
}
```
`liked_by_me` and `is_mine` are always `false` for guests. `is_mine` hides the
heart on an owner's own listings (liking them is a `403`). `cover_image` is the image with the
lowest `sort_order`, or `null`.

### Property detail
Everything in the card, plus:
```json
{
  "description": "Bright corner unit with pool and gym access...",
  "address": "Jalan Kiara 3, Mont Kiara",
  "postcode": "50480",
  "updated_at": null,
  "images": [
    { "image_id": 1, "file_path": "uploads/seed/condo.jpg", "sort_order": 0,
      "caption": "Front of the building", "room_tag": "exterior", "is_hidden": false },
    { "image_id": 31, "file_path": "uploads/seed/living.jpg", "sort_order": 1,
      "caption": "Living area", "room_tag": "living", "is_hidden": false }
  ],
  "owner": { "user_id": 1, "full_name": "Aisha Rahman", "phone": "60123456789" },
  "is_mine": false
}
```
**Guest visibility:** `owner.phone` is `null` for guests, so the WhatsApp
button and booking form only appear after login. `is_mine` (from the card)
lets the page show Edit / Delete instead of Book / Like.

---

## 3. Endpoints

### 3.1 Session and users

| Method | URL | Access | Body | Returns |
|---|---|---|---|---|
| `GET` | `/session` | Guest | – | `200 { data: User }` or `200 { data: null }` if not logged in |
| `POST` | `/session` | Guest | `{ email, password, remember? }` | `200 { data: User }` (logs in) |
| `DELETE` | `/session` | Guest | – | `204` (logs out) |
| `POST` | `/users` | Guest | see below | `201 { data: User }` (registers and logs in) |

Register body:
```json
{ "full_name": "Sarah Tan", "email": "sarah@example.com", "password": "Password123!",
  "role": "viewer", "phone": null }
```
- `remember: true` ("Keep me logged in") keeps the session cookie for 30 days;
  otherwise it ends when the browser closes.
- Wrong email or password on login → `401 { "error": "Invalid email or password" }`
  (same message for both, so emails can't be probed).
- Email already used → `422` with `fields.email`.

### 3.2 Properties

| Method | URL | Access | Returns |
|---|---|---|---|
| `GET` | `/properties?<filters>` | Guest | `200` list of Property cards + `meta` |
| `GET` | `/properties?ids=1,3,5` | Guest | `200 { data: [Property detail, ...] }` – compare page, max 4 |
| `GET` | `/properties/5` | Guest | `200 { data: Property detail }` |
| `POST` | `/properties` | Owner | `201 { data: Property detail }` |
| `PUT` | `/properties/5` | Own | `200 { data: Property detail }` |
| `PATCH` | `/properties/5` | Own | `{ "status": "rented" }` → `200 { data: Property detail }` – status only |
| `DELETE` | `/properties/5` | Own | `204` |
| `GET` | `/me/properties` | Owner | `200` list of my listings (all statuses) + `meta` |

**List filters** (all optional, combine freely):

| Param | Example | Notes |
|---|---|---|
| `q` | `mont kiara` | Matches title, address or city (`LIKE %q%`) |
| `listing_type` | `rent` | `rent` / `sale` |
| `property_type` | `condo,house` | one or more of the 6 types, comma-separated (matches any) |
| `city` | `Kuching` | exact match |
| `min_price`, `max_price` | `1000`, `3000` | inclusive |
| `min_bedrooms` | `2` | `>=` |
| `furnished` | `1` | only furnished |
| `sort` | `price_asc` | `newest` (default), `price_asc`, `price_desc`, `most_liked` |
| `page` | `2` | default `1` |
| `per_page` | `12` | default `12`, max `48` |

Public lists only return `status = 'available'`. `/me/properties` returns all of the owner's listings.

**Create / replace body** (`PUT` sends the full object, same rules as `POST`):
```json
{
  "title": "Fully furnished 2-bed condo in Mont Kiara",
  "description": "Bright corner unit...",
  "listing_type": "rent",
  "property_type": "condo",
  "price": 3800,
  "bedrooms": 2, "bathrooms": 2, "parking_spaces": 1,
  "floor_area_sqm": 95,
  "is_furnished": true,
  "address": "Jalan Kiara 3, Mont Kiara",
  "city": "Kuala Lumpur", "state": "Wilayah Persekutuan", "postcode": "50480",
  "latitude": 3.17, "longitude": 101.65,
  "status": "available"
}
```
`status` is only accepted on `PUT` (required there) and `PATCH`. `PATCH` takes
`status` and nothing else (`422` otherwise); My listings and the property page
use it for "Mark as rented / sold". PHP sets `updated_at = NOW()` on every
`PUT` and `PATCH`.

Side effects (SQL in `schema.sql`):
- `PUT` or `PATCH` changing status to `rented`/`sold` → declines pending and cancels confirmed
  appointments for that listing, and frees their slots.
- `DELETE` → frees slots held by its active appointments, deletes the row
  (images, likes, appointments cascade), then deletes `uploads/<property_id>/` from disk.

### 3.3 Map and cities

| Method | URL | Access | Returns |
|---|---|---|---|
| `GET` | `/map?north=3.25&south=3.05&east=101.80&west=101.60` | Guest | `200 { data: [Property card, ...] }` |
| `GET` | `/cities` | Guest | `200 { data: [ { city, state, listing_count, cover_image } ] }` |

`/map`: no pagination; capped at 200 results, newest first. Only available
listings with coordinates. All four bounds are required numbers and
`south <= north`, otherwise `422`.

`/cities`: cities that have available listings, most listings first. Feeds the
listings City filter and the home page's "Browse by city". `cover_image` is the
cover photo of the city's most liked listing.

### 3.4 Images (photo manager)

Image object: `{ image_id, file_path, sort_order, caption, room_tag, is_hidden }`.
`caption` (≤ 150 chars) is also the photo's alt text. `room_tag` is one of
`exterior`, `living`, `bedroom`, `kitchen`, `bathroom`, `dining`, `balcony`,
`other`, or `null`. `is_hidden` photos are only sent to the owner (in their
listing's `images`); everyone else never sees them, and they are never the
`cover_image`: the cover is the first photo that isn't hidden.

| Method | URL | Access | Body | Returns |
|---|---|---|---|---|
| `POST` | `/properties/5/images` | Own | `multipart/form-data`: `photos[]` (one or more files), optional `caption`, `room_tag`, `is_hidden` (`1`/`0`) for them | `201 { data: [Image, ...], meta: { created: [new image_ids] } }` – all images of the listing |
| `PUT` | `/properties/5/images` | Own | `{ "order": [31, 1, 61] }` (image_ids, new cover first) | `200 { data: [Image, ...] }` |
| `PATCH` | `/images/31` | Own | any of `{ "caption": "...", "room_tag": "kitchen", "is_hidden": true }` | `200 { data: Image }` |
| `DELETE` | `/images/31` | Own | – | `204` (row deleted **and** file unlinked) |

Rules: JPEG / PNG / WebP only (checked from the file's bytes, not its
extension), ≤ 2 MB each, ≤ 10 per listing (hidden ones count). Saved as
`uploads/<property_id>/<random>.<ext>`. New uploads are appended after the
existing ones. Every file and field is checked before any file is saved, so a
bad one saves nothing (`422`, `fields.photos` / `fields.room_tag` /
`fields.caption`). `PUT` order must list every photo id of the listing exactly
once. Seed photos (`uploads/seed/`) are shared, so deleting one removes the
row but not the file.

The frontend's photo manager compresses photos in the browser first (largest
side 1920 px), then uploads them **one file per request**, two at a time, so
each photo has its own `XMLHttpRequest.upload.onprogress` bar; `meta.created`
tells it which image id each file became.

**Older databases:** run `backend/database/migrations/001_photo_details.sql`
once to add `caption`, `room_tag` and `is_hidden` (a second run just says
"Duplicate column"), then `002_design_photos.sql` for the design's listing photos.

### 3.5 Likes

| Method | URL | Access | Body | Returns |
|---|---|---|---|---|
| `GET` | `/me/likes` | User | – | `200` list of Property cards I liked, newest like first, any status + `meta` (accepts `page`, `per_page`) |
| `PUT` | `/me/likes/5` | User | – | `200 { data: { property_id, liked: true, like_count } }` |
| `DELETE` | `/me/likes/5` | User | – | `200 { data: { property_id, liked: false, like_count } }` |

`PUT` and `DELETE` are idempotent: liking twice or unliking something not
liked is not an error. Liking your own listing → `403`. Both return the fresh
`like_count`, so the heart button can update without reloading the page.

### 3.6 Viewing slots

| Method | URL | Access | Body | Returns |
|---|---|---|---|---|
| `GET` | `/properties/5/slots` | Guest | – | `200 { data: [ {slot_id, viewing_date, viewing_time} ] }` – free, future days of that listing's owner |
| `GET` | `/me/slots` | Owner | – | `200 { data: [ {slot_id, viewing_date, viewing_time, is_booked, appointment_id} ] }` – my days from today on; `appointment_id` is the open booking holding a booked day, else `null` |
| `POST` | `/me/slots` | Owner | `{ "viewing_date": "2026-11-20", "viewing_time": "14:00" }` | `201 { data: Slot }` |
| `DELETE` | `/me/slots/3` | Own | – | `204` |

- Date in the past, a time outside 08:00–20:00, or a time already passed today → `422`.
- Already a slot that day → `409 { "error": "You already have a viewing on this day" }`.
- Times are sent and returned as `HH:MM`. PHP runs on `Asia/Kuala_Lumpur`, the same
  clock as MySQL's `+08:00`.
- Deleting a booked slot → `409` (cancel or decline the appointment first).

### 3.7 Appointments

| Method | URL | Access | Body | Returns |
|---|---|---|---|---|
| `POST` | `/appointments` | User | `{ "slot_id": 3, "property_id": 5, "message": "..." }` | `201 { data: Appointment }` |
| `GET` | `/me/appointments?as=viewer&when=upcoming` | User | – | `200` my bookings + `meta`. `when=upcoming` (pending/confirmed, still ahead; soonest first), `when=past` (everything else; latest first), or omitted (newest booking first) |
| `GET` | `/me/appointments?as=owner&status=pending` | Owner | – | `200` requests on my listings, soonest viewing first, + `meta` with `counts: {pending, confirmed, declined, cancelled}` (`status` optional) |
| `PATCH` | `/appointments/7` | see below | `{ "status": "confirmed" }` | `200 { data: Appointment }` |

Allowed status changes:
| New `status` | Who | Allowed from |
|---|---|---|
| `confirmed` | Owner of the slot | `pending` |
| `declined` | Owner of the slot | `pending` (frees the slot) |
| `cancelled` | Viewer who booked | `pending` or `confirmed` (frees the slot) |

Appointment object:
```json
{
  "appointment_id": 1,
  "status": "pending",
  "message": "Hi, I would like to view the Mont Kiara unit.",
  "viewing_date": "2026-11-07",
  "viewing_time": "10:00",
  "property": { "property_id": 1, "title": "Fully furnished 2-bed condo in Mont Kiara", "cover_image": "uploads/seed/condo.jpg" },
  "viewer": { "user_id": 5, "full_name": "Sarah Tan" },
  "owner":  { "user_id": 1, "full_name": "Aisha Rahman", "phone": "60123456789" },
  "created_at": "2026-11-05 10:00:00",
  "updated_at": null
}
```
- Slot just taken by someone else → `409 { "error": "Sorry, this day was just booked" }`.
- Already a pending or confirmed booking for the same listing → `409`.
- Booking own listing, listing not available, or slot in the past → `422`.
- Wrong status for the change, or not your appointment → `409` / `403`.
- A viewing whose date has passed can't be confirmed, declined or cancelled → `409`.
- The navbar badge uses `GET /me/appointments?as=owner&status=pending&per_page=1`
  and reads `meta.total`.

### 3.8 Me (profile)

| Method | URL | Access | Body | Returns |
|---|---|---|---|---|
| `PATCH` | `/me` | User | `{ "full_name": "...", "phone": "60123456789" }` | `200 { data: User }` |

Only the fields sent are changed. `phone` follows the §4 rule: owners must keep
one (`422` if they send `""`), viewers may clear it (`""` → `null`).
Email, role and password changes are out of scope.

---

## 4. Validation rules

Vue validates first, for instant feedback. **PHP validates again** – the
frontend can be bypassed. Use the same messages on both sides.

| Field | Rule |
|---|---|
| `full_name` | required, 2–100 chars |
| `email` | required, valid email, ≤ 150 chars, unique |
| `password` | required, ≥ 8 chars, at least one letter and one number |
| `role` | `owner` or `viewer` |
| `phone` | required if role is `owner`; digits only, 8–15 digits, starting with the country code (e.g. `60123456789`) |
| `title` | required, 5–150 chars |
| `description` | required, 20–5000 chars |
| `listing_type` / `property_type` / `status` | one of the enum values in `schema.sql` |
| `price` | required, number > 0, ≤ 9,999,999,999 |
| `bedrooms`, `bathrooms`, `parking_spaces` | integer 0–20 |
| `floor_area_sqm` | optional, number 5–100000 |
| `address` | required, ≤ 255 chars |
| `city` | required, ≤ 100 chars |
| `state` | optional, ≤ 100 chars |
| `postcode` | optional, 4–10 digits |
| `latitude` / `longitude` | optional, but both or neither; −90…90 / −180…180 |
| `viewing_date` | required, `YYYY-MM-DD`, today or later |
| `viewing_time` | required, `HH:MM`, between 08:00 and 20:00 |
| `message` | optional, ≤ 500 chars |

Security baseline: prepared statements for **every** query (no string-built
SQL), `password_hash()` / `password_verify()`, and escaping is Vue's job
(`{{ }}` – never `v-html` with user content).

---

## 5. Pages and routes

| Route | Page | Access | Uses |
|---|---|---|---|
| `/` | Home – hero search, featured & newest listings, cities | Guest | `GET /properties?sort=…&per_page=…`, `GET /cities` |
| `/properties` | Listings – filters, sort, pagination | Guest | `GET /properties?<filters>`, `GET /cities` |
| `/properties/:id` | Property detail – gallery, map, like, WhatsApp, booking | Guest (contact & booking: User) | `GET /properties/:id`, `GET /properties/:id/slots`, `PUT/DELETE /me/likes/:id`, `POST /appointments` |
| `/map` | Map search – "search this area" | Guest | `GET /map` |
| `/compare` | Compare up to 4 listings side by side | Guest | `GET /properties?ids=` |
| `/login` | Login | Guest only | `POST /session` |
| `/register` | Register (viewer or owner) | Guest only | `POST /users` |
| `/liked` | My liked properties | User | `GET /me/likes` |
| `/appointments` | My viewing bookings (as viewer) | User | `GET /me/appointments?as=viewer`, `PATCH /appointments/:id` |
| `/profile` | Edit name and WhatsApp number | User | `PATCH /me` |
| `/owner/listings` | My listings – edit / delete / mark rented | Owner | `GET /me/properties`, `PUT/DELETE /properties/:id` |
| `/owner/listings/new` | Create listing + photo uploader | Owner | `POST /properties`, `POST /properties/:id/images` |
| `/owner/listings/:id/edit` | Edit listing + reorder photos | Own | `GET/PUT /properties/:id`, image routes |
| `/owner/availability` | Manage free viewing days | Owner | `GET/POST /me/slots`, `DELETE /me/slots/:id` |
| `/owner/requests` | Approve / decline viewing requests | Owner | `GET /me/appointments?as=owner`, `PATCH /appointments/:id` |
| `/:pathMatch(.*)*` | 404 Not found | Guest | – |

Route guards use `meta: { requiresAuth: true }` and `meta: { requiresOwner: true }`.
A guard also checks the Pinia auth store; the API still enforces every rule.

---

## 6. Build order

1. **Backend:** session/users → properties (GET first) → likes → images → slots
   → appointments → map → me. Test each with the seed data before moving on.
   Routes not built yet answer `501 Not implemented yet`.
2. **Frontend:** API calls live in `frontend/src/api/`, one file per resource
   (e.g. `properties.js`), all going through `request()` in `client.js`.
