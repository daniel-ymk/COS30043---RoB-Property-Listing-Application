// Mockup data, taken from backend/database/seed.sql and shaped like the
// "Property card" / "Property detail" objects in docs/api.md.
// Photos are Unsplash stand-ins in design/img; the real app uses uploads/.
const IMG = (n) => `../img/p${String(n).padStart(2, '0')}.jpg`

const OWNERS = {
  1: { user_id: 1, full_name: 'Aisha Rahman', phone: '60123456789' },
  2: { user_id: 2, full_name: 'Jonathan Wong', phone: '60198765432' },
  3: { user_id: 3, full_name: 'Priya Nair', phone: '60167788990' },
}

const P = (o) => ({ state: 'Wilayah Persekutuan', status: 'available', like_count: 0, liked_by_me: false, ...o })

const LISTINGS = [
  P({ property_id: 1, owner: 1, title: 'Fully furnished 2-bed condo in Mont Kiara', listing_type: 'rent', property_type: 'condo', price: 3800, bedrooms: 2, bathrooms: 2, parking_spaces: 1, floor_area_sqm: 95, is_furnished: true, address: 'Jalan Kiara 3, Mont Kiara', city: 'Kuala Lumpur', postcode: '50480', latitude: 3.17, longitude: 101.65, like_count: 3, days: 2,
    description: 'Bright corner unit with pool and gym access, 5 minutes to international schools and Publika.', images: [9, 17, 8, 12, 24] }),
  P({ property_id: 2, owner: 1, title: 'Bangsar townhouse near LRT', listing_type: 'rent', property_type: 'townhouse', price: 5200, bedrooms: 3, bathrooms: 3, parking_spaces: 2, floor_area_sqm: 160, is_furnished: false, address: 'Jalan Telawi 5, Bangsar', city: 'Kuala Lumpur', postcode: '59100', latitude: 3.129, longitude: 101.679, like_count: 5, days: 10,
    description: 'Three-storey townhouse on a quiet street, walking distance to Bangsar LRT and Telawi cafes.', images: [10, 7, 22, 23] }),
  P({ property_id: 3, owner: 1, title: 'KLCC view luxury condo', listing_type: 'sale', property_type: 'condo', price: 1850000, bedrooms: 3, bathrooms: 2, parking_spaces: 2, floor_area_sqm: 140, is_furnished: true, address: 'Jalan Ampang, KLCC', city: 'Kuala Lumpur', postcode: '50450', latitude: 3.1579, longitude: 101.7123, like_count: 9, days: 5,
    description: 'High-floor unit with full Petronas Towers view, concierge, infinity pool and two car parks.', images: [13, 17, 22, 12] }),
  P({ property_id: 4, owner: 1, title: 'Affordable family apartment in Cheras', listing_type: 'rent', property_type: 'apartment', price: 1500, bedrooms: 3, bathrooms: 2, parking_spaces: 1, floor_area_sqm: 85, is_furnished: false, address: 'Jalan Cheras, Taman Connaught', city: 'Kuala Lumpur', postcode: '56000', latitude: 3.085, longitude: 101.745, like_count: 2, days: 20,
    description: 'Spacious 3-bedroom apartment near MRT Taman Connaught, markets and schools nearby.', images: [7, 8, 23] }),
  P({ property_id: 5, owner: 1, title: 'Studio in the heart of Bukit Bintang', listing_type: 'rent', property_type: 'studio', price: 2200, bedrooms: 0, bathrooms: 1, parking_spaces: 0, floor_area_sqm: 42, is_furnished: true, address: 'Jalan Bukit Bintang', city: 'Kuala Lumpur', postcode: '55100', latitude: 3.1466, longitude: 101.7101, like_count: 4, days: 1,
    description: 'Compact furnished studio above Pavilion area, ideal for young professionals. Utilities included.', images: [11, 6, 8] }),
  P({ property_id: 6, owner: 1, title: 'Room for rent near Sentul LRT', listing_type: 'rent', property_type: 'room', price: 750, bedrooms: 1, bathrooms: 1, parking_spaces: 0, floor_area_sqm: 14, is_furnished: true, address: 'Jalan Sentul', city: 'Kuala Lumpur', postcode: '51000', latitude: 3.183, longitude: 101.693, like_count: 1, days: 7,
    description: 'Furnished middle room in a shared condo, Wi-Fi and cleaning included. Female tenants preferred.', images: [23, 6] }),
  P({ property_id: 7, owner: 1, title: 'Desa ParkCity family house', listing_type: 'rent', property_type: 'house', price: 6500, bedrooms: 4, bathrooms: 4, parking_spaces: 2, floor_area_sqm: 260, is_furnished: true, address: 'Persiaran Prima, Desa ParkCity', city: 'Kuala Lumpur', postcode: '52200', latitude: 3.186, longitude: 101.63, like_count: 6, days: 45, status: 'rented',
    description: 'Landed home facing the park with a private garden and maid room. Pet friendly.', images: [18, 17, 22] }),
  P({ property_id: 8, owner: 1, title: 'Setapak apartment near TAR UMT', listing_type: 'sale', property_type: 'apartment', price: 420000, bedrooms: 3, bathrooms: 2, parking_spaces: 1, floor_area_sqm: 90, is_furnished: false, address: 'Jalan Genting Kelang, Setapak', city: 'Kuala Lumpur', postcode: '53300', latitude: 3.205, longitude: 101.727, like_count: 2, days: 15,
    description: 'Freehold apartment close to universities, a good starter home or investment unit.', images: [6, 7, 23] }),
  P({ property_id: 9, owner: 2, title: 'Tabuan Jaya terrace house', listing_type: 'rent', property_type: 'house', price: 1800, bedrooms: 4, bathrooms: 3, parking_spaces: 2, floor_area_sqm: 180, is_furnished: false, address: 'Lorong Tabuan Jaya 2', city: 'Kuching', state: 'Sarawak', postcode: '93350', latitude: 1.517, longitude: 110.38, like_count: 3, days: 3,
    description: 'Double-storey intermediate terrace with renovated kitchen, near Tabuan Jaya food court.', images: [21, 22, 12] }),
  P({ property_id: 10, owner: 2, title: 'BDC condo near Swinburne', listing_type: 'rent', property_type: 'condo', price: 1600, bedrooms: 3, bathrooms: 2, parking_spaces: 1, floor_area_sqm: 110, is_furnished: true, address: 'Jalan Stutong, BDC', city: 'Kuching', state: 'Sarawak', postcode: '93350', latitude: 1.53, longitude: 110.365, like_count: 7, days: 6,
    description: 'Furnished condo with pool, 5 minutes drive to Swinburne Sarawak campus and The Spring mall.', images: [24, 13, 23] }),
  P({ property_id: 11, owner: 2, title: 'Riverside apartment by the Waterfront', listing_type: 'sale', property_type: 'apartment', price: 520000, bedrooms: 2, bathrooms: 2, parking_spaces: 1, floor_area_sqm: 88, is_furnished: true, address: 'Jalan Main Bazaar', city: 'Kuching', state: 'Sarawak', postcode: '93000', latitude: 1.559, longitude: 110.346, like_count: 4, days: 12,
    description: 'Walk to the Kuching Waterfront and Main Bazaar. River view from the balcony.', images: [22, 17, 12] }),
  P({ property_id: 12, owner: 2, title: 'Batu Kawa semi-detached house', listing_type: 'sale', property_type: 'house', price: 780000, bedrooms: 4, bathrooms: 3, parking_spaces: 2, floor_area_sqm: 220, is_furnished: false, address: 'Jalan Batu Kawa', city: 'Kuching', state: 'Sarawak', postcode: '93250', latitude: 1.51, longitude: 110.31, like_count: 2, days: 25,
    description: 'Corner semi-D with large compound, extended kitchen and covered car porch for two.', images: [14, 22, 23] }),
  P({ property_id: 17, owner: 3, title: 'Gurney Drive seaview condo', listing_type: 'rent', property_type: 'condo', price: 4500, bedrooms: 3, bathrooms: 2, parking_spaces: 2, floor_area_sqm: 130, is_furnished: true, address: 'Persiaran Gurney', city: 'George Town', state: 'Penang', postcode: '10250', latitude: 5.437, longitude: 100.309, like_count: 8, days: 4,
    description: 'Furnished seaview unit steps from Gurney Plaza and the hawker centre.', images: [20, 17, 12, 22] }),
  P({ property_id: 18, owner: 3, title: 'Tanjung Tokong apartment', listing_type: 'sale', property_type: 'apartment', price: 680000, bedrooms: 3, bathrooms: 2, parking_spaces: 1, floor_area_sqm: 105, is_furnished: false, address: 'Jalan Tanjung Tokong', city: 'George Town', state: 'Penang', postcode: '10470', latitude: 5.456, longitude: 100.304, like_count: 3, days: 14,
    description: 'Well-kept unit near Straits Quay marina, schools and supermarkets.', images: [2, 7, 23] }),
  P({ property_id: 19, owner: 3, title: 'Restored heritage shophouse', listing_type: 'sale', property_type: 'house', price: 2300000, bedrooms: 3, bathrooms: 3, parking_spaces: 0, floor_area_sqm: 240, is_furnished: false, address: 'Lebuh Armenian', city: 'George Town', state: 'Penang', postcode: '10200', latitude: 5.4145, longitude: 100.3377, like_count: 11, days: 8,
    description: 'Pre-war shophouse in the UNESCO heritage zone, fully restored with an air well and courtyard.', images: [24, 13] }),
]
LISTINGS.forEach((p) => {
  p.cover_image = p.images.length ? IMG(p.images[0]) : null
  p.ownerObj = OWNERS[p.owner]
})

// Sarah Tan (viewer) likes these
const LIKED_IDS = [1, 3, 10, 17]

const APPOINTMENTS = [
  { appointment_id: 1, status: 'pending', viewing_date: '2026-11-08', viewing_time: '10:00', property_id: 1, viewer: 'Sarah Tan', message: 'Hi, I would like to view the Mont Kiara unit.', created_at: '5 Nov 2026' },
  { appointment_id: 2, status: 'confirmed', viewing_date: '2026-11-12', viewing_time: '14:00', property_id: 3, viewer: 'Sarah Tan', message: 'Is the parking included in the price?', created_at: '3 Nov 2026' },
  { appointment_id: 3, status: 'declined', viewing_date: '2026-11-06', viewing_time: '11:00', property_id: 17, viewer: 'Sarah Tan', message: '', created_at: '1 Nov 2026' },
  { appointment_id: 4, status: 'pending', viewing_date: '2026-11-09', viewing_time: '15:30', property_id: 2, viewer: 'Hafiz Ismail', message: 'Can I bring my wife to the viewing?', created_at: '5 Nov 2026' },
  { appointment_id: 5, status: 'pending', viewing_date: '2026-11-14', viewing_time: '10:00', property_id: 4, viewer: 'Emily Chen', message: 'Is the unit near the MRT exit?', created_at: '4 Nov 2026' },
  { appointment_id: 6, status: 'cancelled', viewing_date: '2026-11-07', viewing_time: '09:00', property_id: 5, viewer: 'Emily Chen', message: '', created_at: '2 Nov 2026' },
]

// Aisha Rahman's free viewing days (owner 1), November 2026
const SLOTS = [
  { slot_id: 1, viewing_date: '2026-11-08', viewing_time: '10:00', is_booked: true },
  { slot_id: 2, viewing_date: '2026-11-09', viewing_time: '15:30', is_booked: true },
  { slot_id: 3, viewing_date: '2026-11-11', viewing_time: '10:00', is_booked: false },
  { slot_id: 4, viewing_date: '2026-11-13', viewing_time: '18:00', is_booked: false },
  { slot_id: 5, viewing_date: '2026-11-14', viewing_time: '10:00', is_booked: true },
  { slot_id: 6, viewing_date: '2026-11-15', viewing_time: '11:00', is_booked: false },
  { slot_id: 7, viewing_date: '2026-11-18', viewing_time: '14:00', is_booked: false },
  { slot_id: 8, viewing_date: '2026-11-21', viewing_time: '10:30', is_booked: false },
  { slot_id: 9, viewing_date: '2026-11-22', viewing_time: '16:00', is_booked: false },
]

const USERS = {
  guest: null,
  viewer: { user_id: 5, full_name: 'Sarah Tan', email: 'sarah@example.com', role: 'viewer', phone: null },
  owner: { user_id: 1, full_name: 'Aisha Rahman', email: 'aisha@example.com', role: 'owner', phone: '60123456789' },
}
