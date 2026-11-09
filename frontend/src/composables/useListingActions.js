import { ref } from 'vue'
import { setPropertyStatus, deleteProperty } from '@/api/properties'
import { useConfirmStore } from '@/stores/confirm'
import { useToastStore } from '@/stores/toast'
import { STATUS_LABELS } from '@/utils/format'

// Status changes and deletion for an owner's listing, with the confirmation
// and toast each needs. Shared by My listings and the property page.
export function useListingActions() {
  const confirm = useConfirmStore()
  const toast = useToastStore()
  const busyId = ref(null)

  // Resolves with the updated listing, or null if cancelled / failed
  async function changeStatus(property, status) {
    if (status === property.status) return null
    if (status !== 'available') {
      const ok = await confirm.ask({
        title: `Mark "${property.title}" as ${status}?`,
        text: 'It leaves public search. Pending viewing requests are declined and confirmed viewings are cancelled.',
        confirmLabel: `Mark as ${status}`,
      })
      if (!ok) return null
    }
    busyId.value = property.property_id
    try {
      const updated = await setPropertyStatus(property.property_id, status)
      toast.show(`Marked as ${STATUS_LABELS[status].toLowerCase()}`)
      return updated
    } catch (err) {
      toast.error(err.message)
      return null
    } finally {
      busyId.value = null
    }
  }

  // Resolves true once deleted
  async function remove(property) {
    const ok = await confirm.ask({
      title: `Delete "${property.title}"?`,
      text: "Its photos, likes and viewing requests are deleted too. This can't be undone.",
      confirmLabel: 'Delete listing',
      cancelLabel: 'Keep listing',
      danger: true,
    })
    if (!ok) return false
    busyId.value = property.property_id
    try {
      await deleteProperty(property.property_id)
      toast.show('Listing deleted', { icon: 'trash3' })
      return true
    } catch (err) {
      toast.error(err.message)
      return false
    } finally {
      busyId.value = null
    }
  }

  return { changeStatus, remove, busyId }
}
