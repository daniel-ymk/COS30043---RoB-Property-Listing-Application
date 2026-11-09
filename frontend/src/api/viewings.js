import { request } from './client'

// docs/api.md sections 3.6 (viewing days) and 3.7 (appointments)

// Free future days of a listing's owner: [{ slot_id, viewing_date, viewing_time }]
export async function listPropertySlots(propertyId) {
  const { data } = await request(`properties/${propertyId}/slots`)
  return data
}

// Owner: my days from today on, with is_booked and appointment_id
export async function listMySlots() {
  const { data } = await request('me/slots')
  return data
}

export async function addSlot(viewingDate, viewingTime) {
  const { data } = await request('me/slots', {
    method: 'POST',
    body: { viewing_date: viewingDate, viewing_time: viewingTime },
  })
  return data
}

export function deleteSlot(slotId) {
  return request(`me/slots/${slotId}`, { method: 'DELETE' })
}

export async function bookViewing(slotId, propertyId, message) {
  const { data } = await request('appointments', {
    method: 'POST',
    body: { slot_id: slotId, property_id: propertyId, message },
  })
  return data
}

// query: { as: 'viewer' | 'owner', when?, status?, page?, per_page? }
// Returns { data: [appointments], meta } (owner meta has counts per status)
export function listAppointments(query) {
  return request('me/appointments', { query })
}

// status: 'confirmed' | 'declined' (owner) or 'cancelled' (viewer)
export async function setAppointmentStatus(appointmentId, status) {
  const { data } = await request(`appointments/${appointmentId}`, {
    method: 'PATCH',
    body: { status },
  })
  return data
}
