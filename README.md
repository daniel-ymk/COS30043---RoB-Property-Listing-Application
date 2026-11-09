# COS30043 Project – RoB Property

RoB Property (Rent or Buy) – a property listing web app built with Vue 3 + Bootstrap.
Vue 3 + Bootstrap web app for COS30043 Interface Design and Development.

## Team
| Name | Role |
|---|---|
| Ye Htet Kyaw (Jason) | Project Lead & Front-end: task planning, code review and merging, Mercury deployment, UI design, layout, routing, item list/detail, search, sort, pagination |
| Ye Myat Kyaw (Daniel) | Back-end & Data: database schema, REST API (CRUD, auth, likes), Canvas submission, communication with tutor |
| Kaung Zin (Zin) | Front-end & Back-end Integration: login/registration forms with validation, guest vs. logged-in views, connecting Vue to the API |
| Khant Aung Naing | Content Features & Testing: create/edit/delete pages, likes/voting UI, responsive testing, group report and video script coordination |

## Tech stack
Vue 3 · Vite · Vue Router · Pinia · Bootstrap 5 · Leaflet · PHP REST API · MariaDB · Mercury

## Project structure
```
frontend/            Vue 3 app (Vite)
backend/api/         PHP REST API (front controller index.php, resources/)
backend/config/      db.example.php (copy to db.php; db.php is never committed)
backend/database/    schema.sql, seed.sql, migrations/
backend/uploads/     seed photos; owners' uploads (not committed)
backend/tests/       smoke.sh (API checks), php54_check.py (PHP 5.4 syntax scan)
scripts/             build-mercury.sh (builds the folder to upload)
docs/                api.md (API contract)
design/              HTML mockups from the design phase
```

## Run locally
Needs Node 22+ and XAMPP (Apache + PHP + MariaDB).

1. **Get the code**
   ```
   git clone https://github.com/kgzin19/cos30043-project-bearmini.git
   ```
2. **Link the repo into XAMPP** (once), so Apache serves it at `http://localhost/rob/`.
   In PowerShell, as administrator:
   ```
   New-Item -ItemType Junction -Path C:\xampp\htdocs\rob -Target <path to this repo>
   ```
3. **Create the local database** (once). Start MySQL in the XAMPP Control Panel, then in
   Git Bash from the repo folder:
   ```
   /c/xampp/mysql/bin/mysql -u root -e "CREATE DATABASE rob_local CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
   /c/xampp/mysql/bin/mysql -u root rob_local < backend/database/schema.sql
   /c/xampp/mysql/bin/mysql -u root rob_local < backend/database/seed.sql
   ```
4. **Point the API at it**: create `backend/config/db.local.php` (gitignored) like
   `db.example.php`, with host `localhost`, database `rob_local`, user `root` and an empty
   password. When this file exists it is used instead of `db.php`.
5. **Start Apache and MySQL** in XAMPP, then run the Vue app:
   ```
   cd frontend
   npm install
   npm run dev
   ```
   Open http://localhost:5173. Vite forwards `/api` and `/backend` to XAMPP.

Test accounts (password `Password123!` for all):

| Role | Email |
|---|---|
| Owner | `aisha@example.com`, `jonathan@example.com`, `priya@example.com`, `marcus@example.com` |
| Viewer | `sarah@example.com`, `hafiz@example.com`, `emily@example.com` |

Seed viewing days are dated from the day `seed.sql` is imported; re-import it for fresh ones.

## Checks
```
cd frontend && npm run lint && npm run build    # code style and production build
bash backend/tests/smoke.sh                     # API checks against the local database
python backend/tests/php54_check.py             # PHP 5.4 compatibility (Mercury runs PHP 5.x)
```

## Deploy to Mercury
1. **Database:** in phpMyAdmin (https://feenix-mariadb-web.swin.edu.au/) import
   `schema.sql` then `seed.sql` for a new database, or the files in
   `backend/database/migrations/` in order for an existing one.
2. **Login:** `backend/config/db.php` must hold the feenix login.
3. **Build:** `bash scripts/build-mercury.sh` creates `../deploy/rob`. The site's path is set
   in `frontend/.env.mercury`.
4. **Upload** everything inside `deploy/rob`, including the hidden `.htaccess` files, to the
   `rob` folder of the Mercury web space, and give `rob/backend/uploads/` write permission.

## API
REST API under `backend/api/`, documented in [docs/api.md](docs/api.md): sessions, users,
properties (search, sort, paging, CRUD), photos, likes, viewing days, appointments, map.

## Branch & commit rules
- Run `git pull` before you start work and before you push, to avoid conflicts.
- Branches (optional, for bigger features): `feature/...`, `fix/...`, `docs/...`
- Commits: `feat(scope): message`, `fix(scope): message`, `style: ...`, `docs: ...`

## Live site
https://mercury.swin.edu.au/cos30043/s105229648/rob/
