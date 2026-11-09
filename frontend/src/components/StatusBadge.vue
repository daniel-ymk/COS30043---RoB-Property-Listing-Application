<script setup>
import { STATUS_LABELS } from '@/utils/format'

// Appointment status (pending/confirmed/declined/cancelled) or
// listing status (available/rented/sold).
defineProps({
  status: { type: String, required: true },
})
</script>

<template>
  <span class="badge-status" :class="`status-${status}`">{{
    STATUS_LABELS[status] ?? status
  }}</span>
</template>

<style scoped>
.badge-status {
  font-weight: 600;
  font-size: 0.8125rem;
  padding: 0.3rem 0.65rem;
  border-radius: 999px;
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  white-space: nowrap;
}
.badge-status::before {
  content: '';
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: currentColor;
}
.status-pending {
  background: #fef3c7;
  color: #92400e;
}
.status-confirmed,
.status-available {
  background: #dcfce7;
  color: #166534;
}
.status-declined {
  background: #fee2e2;
  color: #991b1b;
}
.status-cancelled,
.status-rented,
.status-sold {
  background: var(--rob-line);
  color: var(--rob-muted);
}
</style>
