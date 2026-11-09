// Shared mockup script: navbar, footer, property card, states, mockup bar.
// Each function maps to a Vue component the team will build (see dev notes).
const ROB = (() => {
  const params = new URLSearchParams(location.search)
  const body = document.body
  const roles = (body.dataset.roles || 'guest,viewer,owner').split(',')
  const as = roles.includes(params.get('as')) ? params.get('as') : roles[0]
  const state = params.get('state') || 'ready'
  const user = USERS[as]

  const store = {
    get(k, d) { try { return JSON.parse(localStorage.getItem('rob-' + k)) ?? d } catch { return d } },
    set(k, v) { try { localStorage.setItem('rob-' + k, JSON.stringify(v)) } catch {} },
  }
  let compareIds = store.get('compare', [1, 3, 10])

  const link = (page, extra = '') => `${page}.html?as=${as}${extra}`
  const byId = (id) => LISTINGS.find((p) => p.property_id === Number(id))
  const money = (n) => 'RM ' + Number(n).toLocaleString('en-MY')
  const priceHTML = (p) => `${money(p.price)}${p.listing_type === 'rent' ? '<small> /month</small>' : ''}`
  const initials = (name) => name.split(' ').map((w) => w[0]).slice(0, 2).join('')
  const typeLabel = { condo: 'Condo', apartment: 'Apartment', house: 'House', townhouse: 'Townhouse', studio: 'Studio', room: 'Room' }
  const fmtDate = (d, opts = { weekday: 'short', day: 'numeric', month: 'short', year: 'numeric' }) =>
    new Date(d + 'T00:00:00').toLocaleDateString('en-GB', opts)
  const fmtTime = (t) => { const [h, m] = t.split(':').map(Number); return `${((h + 11) % 12) + 1}:${String(m).padStart(2, '0')} ${h < 12 ? 'AM' : 'PM'}` }

  function specs(p, cls = '') {
    const beds = p.bedrooms === 0 ? 'Studio' : `${p.bedrooms} bed`
    return `<ul class="specs ${cls}">
      <li><i class="bi bi-door-closed" aria-hidden="true"></i>${beds}</li>
      <li><i class="bi bi-droplet" aria-hidden="true"></i>${p.bathrooms} bath</li>
      ${p.parking_spaces ? `<li><i class="bi bi-car-front" aria-hidden="true"></i>${p.parking_spaces} parking</li>` : ''}
      <li><i class="bi bi-arrows-angle-expand" aria-hidden="true"></i>${p.floor_area_sqm} m²</li>
    </ul>`
  }

  // <PropertyCard>
  function card(p, { liked = LIKED_IDS.includes(p.property_id) && as !== 'guest' } = {}) {
    const rented = p.status !== 'available'
    const inCompare = compareIds.includes(p.property_id)
    const likeBtn = as === 'guest'
      ? `<a class="like-btn" href="${link('login')}" aria-label="Log in to save this property"><i class="bi bi-heart" aria-hidden="true"></i></a>`
      : `<button class="like-btn" type="button" aria-pressed="${liked}" aria-label="Save ${p.title}" data-like="${p.property_id}"><i class="bi bi-heart" aria-hidden="true"></i></button>`
    return `<article class="prop-card ${rented ? 'is-rented' : ''}">
      <div class="media">
        <img src="${p.cover_image}" alt="" loading="lazy" width="400" height="300">
        <span class="badge-listing ${p.listing_type === 'sale' ? 'badge-sale' : 'badge-rent'}">For ${p.listing_type}</span>
        ${rented ? `<div class="rented-flag">${p.status.toUpperCase()}</div>` : ''}
      </div>
      ${likeBtn}
      <div class="body">
        <div class="price">${priceHTML(p)}</div>
        <a class="title" href="${link('property', '&id=' + p.property_id)}">${p.title}</a>
        <div class="loc"><i class="bi bi-geo-alt" aria-hidden="true"></i> ${p.city} · ${typeLabel[p.property_type]}${p.is_furnished ? ' · Furnished' : ''}</div>
        ${specs(p)}
        <div class="footer-row">
          <label class="compare-check form-check mb-0">
            <input class="form-check-input" type="checkbox" data-compare="${p.property_id}" ${inCompare ? 'checked' : ''}>
            <span class="form-check-label">Compare</span>
          </label>
          <span class="text-muted small"><i class="bi bi-heart-fill text-danger" aria-hidden="true"></i> <span data-count="${p.property_id}">${p.like_count + (liked ? 0 : 0)}</span></span>
        </div>
      </div>
    </article>`
  }

  function cardSkeleton() {
    return `<div class="prop-card" aria-hidden="true"><div class="media skeleton" style="border-radius:0"></div>
      <div class="body"><div class="skeleton" style="height:24px;width:45%"></div><div class="skeleton" style="height:18px;width:90%"></div>
      <div class="skeleton" style="height:18px;width:60%"></div><div class="skeleton mt-2" style="height:16px;width:80%"></div></div></div>`
  }

  // <EmptyState>
  function empty({ icon = 'house', title, text, action = '' }) {
    return `<div class="empty-state"><div class="icon"><i class="bi bi-${icon}" aria-hidden="true"></i></div>
      <h2 class="h5">${title}</h2><p class="text-muted mx-auto" style="max-width:44ch">${text}</p>${action}</div>`
  }
  function errorBox(what = 'listings') {
    return `<div class="alert alert-danger d-flex gap-3 align-items-start" role="alert">
      <i class="bi bi-exclamation-octagon fs-4" aria-hidden="true"></i>
      <div class="flex-grow-1"><strong>We couldn't load the ${what}.</strong><div>Check your connection and try again. If it keeps happening, the server may be down.</div></div>
      <button class="btn btn-outline-danger btn-sm" type="button"><i class="bi bi-arrow-clockwise" aria-hidden="true"></i>Try again</button></div>`
  }

  // Renders a grid of cards, honouring ?state=loading|empty|error
  function grid(el, items, { cols = 'row-cols-1 row-cols-sm-2 row-cols-lg-3', emptyOpts, what } = {}) {
    if (state === 'loading') items = Array(6).fill(null)
    if (state === 'error') { el.innerHTML = errorBox(what); return }
    if (state === 'empty' || !items.length) { el.innerHTML = empty(emptyOpts); return }
    el.innerHTML = `<div class="row ${cols} g-4">${items.map((p) => `<div class="col">${p ? card(p) : cardSkeleton()}</div>`).join('')}</div>`
  }

  function statusBadge(s) {
    const label = { pending: 'Pending', confirmed: 'Confirmed', declined: 'Declined', cancelled: 'Cancelled', available: 'Available', rented: 'Rented', sold: 'Sold' }[s]
    return `<span class="badge-status status-${s === 'sold' ? 'rented' : s}">${label}</span>`
  }

  // <AppNavbar> - three states: guest / viewer / owner
  function nav() {
    const active = body.dataset.page
    const a = (page, text, extra = '') => `<li class="nav-item"><a class="nav-link ${active === page ? 'active' : ''}" ${active === page ? 'aria-current="page"' : ''} href="${link(page)}">${text}${extra}</a></li>`
    const pending = APPOINTMENTS.filter((x) => x.status === 'pending' && byId(x.property_id).owner === 1).length
    const right = !user
      ? `<a class="btn btn-outline-secondary" href="${link('login')}">Log in</a><a class="btn btn-primary" href="${link('register')}">Register</a>`
      : `${as === 'owner' ? `<a class="btn btn-primary d-none d-xl-inline-flex" href="${link('listing-form')}"><i class="bi bi-plus-lg" aria-hidden="true"></i>List a property</a>` : ''}
        <div class="dropdown">
          <button class="btn btn-link text-decoration-none p-0 d-flex align-items-center gap-2" data-bs-toggle="dropdown" aria-expanded="false" aria-label="Account menu">
            <span class="avatar">${initials(user.full_name)}</span><span class="fw-semibold text-body d-lg-none d-xl-inline">${user.full_name.split(' ')[0]}</span><i class="bi bi-chevron-down small text-muted" aria-hidden="true"></i>
          </button>
          <ul class="dropdown-menu dropdown-menu-end shadow-sm">
            <li><h6 class="dropdown-header">${user.email}<br><span class="text-capitalize">${user.role}</span> account</h6></li>
            <li><a class="dropdown-item" href="${link('profile')}"><i class="bi bi-person me-2" aria-hidden="true"></i>Profile</a></li>
            <li><hr class="dropdown-divider"></li>
            <li><a class="dropdown-item" href="home.html?as=guest"><i class="bi bi-box-arrow-right me-2" aria-hidden="true"></i>Log out</a></li>
          </ul>
        </div>`
    const owner = as === 'owner'
      ? `<li class="nav-item dropdown"><a class="nav-link dropdown-toggle ${active?.startsWith('owner') || ['listing-form', 'availability', 'requests'].includes(active) ? 'active' : ''}" href="#" role="button" data-bs-toggle="dropdown" aria-expanded="false">Owner<span class="compare-pill" aria-label="${pending} pending requests">${pending}</span></a>
          <ul class="dropdown-menu shadow-sm">
            <li><a class="dropdown-item" href="${link('owner-listings')}"><i class="bi bi-buildings me-2" aria-hidden="true"></i>My listings</a></li>
            <li><a class="dropdown-item" href="${link('listing-form')}"><i class="bi bi-plus-square me-2" aria-hidden="true"></i>New listing</a></li>
            <li><a class="dropdown-item" href="${link('availability')}"><i class="bi bi-calendar3 me-2" aria-hidden="true"></i>Availability</a></li>
            <li><a class="dropdown-item d-flex justify-content-between align-items-center" href="${link('requests')}"><span><i class="bi bi-inbox me-2" aria-hidden="true"></i>Viewing requests</span><span class="badge rounded-pill text-bg-primary">${pending}</span></a></li>
          </ul></li>`
      : ''
    return `<nav class="navbar navbar-expand-lg rob-nav sticky-top" aria-label="Main">
      <div class="container">
        <a class="navbar-brand" href="${link('home')}"><span class="brand-mark"><i class="bi bi-house-door-fill" aria-hidden="true"></i></span>RoB Property</a>
        <button class="navbar-toggler border-0" type="button" data-bs-toggle="collapse" data-bs-target="#mainNav" aria-controls="mainNav" aria-expanded="false" aria-label="Toggle navigation"><i class="bi bi-list fs-2" aria-hidden="true"></i></button>
        <div id="mainNav" class="collapse navbar-collapse">
          <ul class="navbar-nav me-auto ms-lg-4 gap-lg-1">
            ${a('listings', 'Properties')}${a('map', 'Map')}${a('compare', 'Compare', `<span class="compare-pill" data-compare-count>${compareIds.length}</span>`)}
            ${user ? a('liked', 'Liked') + a('appointments', 'My viewings') : ''}${owner}
          </ul>
          <div class="d-flex align-items-center gap-2 py-3 py-lg-0">${right}</div>
        </div>
      </div></nav>`
  }

  function footer() {
    return `<footer class="rob-footer mt-5"><div class="container py-5">
      <div class="row g-4">
        <div class="col-lg-5"><a class="navbar-brand d-flex align-items-center gap-2 fw-bold fs-5 text-body" href="${link('home')}"><span class="brand-mark"><i class="bi bi-house-door-fill" aria-hidden="true"></i></span>RoB Property</a>
          <p class="text-muted mt-3 mb-0" style="max-width:38ch">Rent or buy homes across Malaysia, straight from the owner. Book a viewing in two clicks.</p></div>
        <div class="col-6 col-lg-2"><h2 class="h6">Find a home</h2><ul class="list-unstyled d-grid gap-2 mb-0"><li><a href="listings.html?as=${as}">For rent</a></li><li><a href="listings.html?as=${as}">For sale</a></li><li><a href="${link('map')}">Map search</a></li></ul></div>
        <div class="col-6 col-lg-2"><h2 class="h6">Owners</h2><ul class="list-unstyled d-grid gap-2 mb-0"><li><a href="${link('register')}">List a property</a></li><li><a href="${link('owner-listings')}">My listings</a></li></ul></div>
        <div class="col-lg-3"><h2 class="h6">Cities</h2><ul class="list-unstyled d-grid gap-2 mb-0"><li><a href="listings.html?as=${as}">Kuala Lumpur</a></li><li><a href="listings.html?as=${as}">Kuching</a></li><li><a href="listings.html?as=${as}">George Town</a></li></ul></div>
      </div>
      <div class="border-top mt-4 pt-4 small text-muted d-flex flex-wrap justify-content-between gap-2"><span>© 2026 RoB Property · COS30043 student project</span><span>Photos: Unsplash</span></div>
    </div></footer>`
  }

  // Mockup-only bar: switch role and data state. Not part of the product.
  function mockBar() {
    const states = body.dataset.states
    const bar = document.createElement('div')
    bar.className = 'mock-bar'
    bar.setAttribute('aria-label', 'Mockup controls')
    bar.innerHTML = `<strong>Mockup</strong>
      <label>View as <select data-mock="as">${roles.map((r) => `<option ${r === as ? 'selected' : ''}>${r}</option>`).join('')}</select></label>
      ${states ? `<label>State <select data-mock="state">${['ready', ...states.split(',')].map((s) => `<option ${s === state ? 'selected' : ''}>${s}</option>`).join('')}</select></label>` : ''}
      <a href="../index.html">All pages</a>`
    bar.addEventListener('change', (e) => {
      const k = e.target.dataset.mock
      if (!k) return
      params.set(k, e.target.value)
      location.search = params.toString()
    })
    document.body.appendChild(bar)
  }

  function toast(msg, icon = 'check-circle') {
    let wrap = document.getElementById('toasts')
    if (!wrap) { wrap = document.createElement('div'); wrap.id = 'toasts'; wrap.className = 'toast-container position-fixed top-0 end-0 p-3'; wrap.style.zIndex = 2100; document.body.appendChild(wrap) }
    const t = document.createElement('div')
    t.className = 'toast align-items-center border-0 text-bg-dark'
    t.setAttribute('role', 'status')
    t.innerHTML = `<div class="d-flex"><div class="toast-body"><i class="bi bi-${icon} me-2" aria-hidden="true"></i>${msg}</div><button type="button" class="btn-close btn-close-white me-2 m-auto" data-bs-dismiss="toast" aria-label="Close"></button></div>`
    wrap.appendChild(t)
    new bootstrap.Toast(t, { delay: 2500 }).show()
  }

  // like + compare behaviour (event delegation, works for cards rendered later)
  document.addEventListener('click', (e) => {
    const b = e.target.closest('[data-like]')
    if (!b) return
    const on = b.getAttribute('aria-pressed') !== 'true'
    b.setAttribute('aria-pressed', on)
    document.querySelectorAll(`[data-count="${b.dataset.like}"]`).forEach((c) => (c.textContent = Number(c.textContent) + (on ? 1 : -1)))
    toast(on ? 'Saved to Liked' : 'Removed from Liked', on ? 'heart-fill' : 'heart')
  })
  document.addEventListener('change', (e) => {
    const c = e.target.closest('[data-compare]')
    if (!c) return
    const id = Number(c.dataset.compare)
    if (c.checked && compareIds.length >= 4) { c.checked = false; toast('You can compare up to 4 properties', 'info-circle'); return }
    compareIds = c.checked ? [...compareIds, id] : compareIds.filter((x) => x !== id)
    store.set('compare', compareIds)
    document.querySelectorAll('[data-compare-count]').forEach((n) => (n.textContent = compareIds.length))
  })

  document.getElementById('nav')?.insertAdjacentHTML('afterbegin', nav())
  document.getElementById('footer')?.insertAdjacentHTML('afterbegin', footer())
  mockBar()
  document.title = `${body.dataset.title || 'RoB Property'} · RoB Property`

  return { as, state, user, link, byId, money, priceHTML, specs, card, cardSkeleton, grid, empty, errorBox, statusBadge, toast, fmtDate, fmtTime, typeLabel, initials, IMG,
    get compareIds() { return compareIds } }
})()
