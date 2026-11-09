import { reactive, watch } from 'vue'
import { defineStore } from 'pinia'
import * as likesApi from '@/api/likes'
import { useAuthStore } from './auth'
import { useToastStore } from './toast'

// Likes the user changed during this visit, so every heart for the same
// listing (card, detail page, Liked page) agrees without reloading lists.
// Cards keep the server's liked_by_me / like_count; this store only holds
// the changes on top of them.
export const useLikesStore = defineStore('likes', () => {
  const auth = useAuthStore()
  const toast = useToastStore()

  const changed = reactive({}) // property_id -> { liked, like_count }
  const busy = reactive(new Set())

  // A different user (or a guest) must not see the last user's hearts
  watch(
    () => auth.user?.user_id,
    () => {
      for (const id of Object.keys(changed)) delete changed[id]
    },
  )

  function isLiked(property) {
    return changed[property.property_id]?.liked ?? property.liked_by_me
  }

  function likeCount(property) {
    return changed[property.property_id]?.like_count ?? property.like_count
  }

  // Updates at once, then corrects from the server's answer (or rolls back).
  async function toggle(property, { offerUndo = true } = {}) {
    const id = property.property_id
    if (busy.has(id)) return
    const before = { liked: isLiked(property), like_count: likeCount(property) }
    const liking = !before.liked
    changed[id] = { liked: liking, like_count: Math.max(0, before.like_count + (liking ? 1 : -1)) }
    busy.add(id)
    try {
      const result = liking ? await likesApi.like(id) : await likesApi.unlike(id)
      changed[id] = { liked: result.liked, like_count: result.like_count }
      if (liking) {
        toast.show('Saved to Liked', { icon: 'heart-fill' })
      } else {
        toast.show('Removed from Liked', {
          icon: 'heart',
          delay: 6000,
          action: offerUndo
            ? { label: 'Undo', run: () => toggle(property, { offerUndo: false }) }
            : null,
        })
      }
    } catch (err) {
      changed[id] = before
      // 401 already sends the user to log in
      if (err.status !== 401) toast.error(err.message)
    } finally {
      busy.delete(id)
    }
  }

  return { isLiked, likeCount, toggle, busy }
})
