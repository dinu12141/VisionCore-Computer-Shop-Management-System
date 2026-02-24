<template>
  <span class="v-status-badge" :class="badgeClass">
    <span class="v-status-dot"></span>
    {{ status }}
  </span>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  status: { type: String, required: true },
})

const badgeClass = computed(() => {
  const s = props.status?.toLowerCase()

  if (['completed', 'paid', 'delivered', 'ready', 'good', 'posted', 'active'].includes(s))
    return 'badge--success'
  if (['pending', 'processing', 'cooking', 'low', 'draft', 'partial'].includes(s))
    return 'badge--warning'
  if (['cancelled', 'void', 'failed', 'critical', 'overdue', 'inactive'].includes(s))
    return 'badge--danger'
  if (['info', 'review', 'on hold'].includes(s)) return 'badge--info'
  return 'badge--neutral'
})
</script>

<style scoped lang="scss">
.v-status-badge {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  padding: 3px 10px;
  border-radius: 100px;
  font-size: 11.5px;
  font-weight: 700;
  letter-spacing: 0.3px;
  text-transform: capitalize;
  white-space: nowrap;
  border: 1px solid transparent;
}

.v-status-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  flex-shrink: 0;
}

// ─── Variants ────────────────────────────────────────────────
.badge--success {
  background: rgba(16, 185, 129, 0.1);
  color: #059669;
  border-color: rgba(16, 185, 129, 0.2);
  .v-status-dot {
    background: #10b981;
  }
}

.badge--warning {
  background: rgba(245, 158, 11, 0.1);
  color: #b45309;
  border-color: rgba(245, 158, 11, 0.2);
  .v-status-dot {
    background: #f59e0b;
  }
}

.badge--danger {
  background: rgba(239, 68, 68, 0.1);
  color: #dc2626;
  border-color: rgba(239, 68, 68, 0.2);
  .v-status-dot {
    background: #ef4444;
  }
}

.badge--info {
  background: rgba(6, 182, 212, 0.1);
  color: #0891b2;
  border-color: rgba(6, 182, 212, 0.2);
  .v-status-dot {
    background: #06b6d4;
  }
}

.badge--neutral {
  background: rgba(100, 116, 139, 0.1);
  color: #475569;
  border-color: rgba(100, 116, 139, 0.15);
  .v-status-dot {
    background: #94a3b8;
  }
}

// Dark mode overrides
body.body--dark {
  .badge--success {
    background: rgba(16, 185, 129, 0.15);
    color: #34d399;
    border-color: rgba(16, 185, 129, 0.25);
  }
  .badge--warning {
    background: rgba(245, 158, 11, 0.15);
    color: #fcd34d;
    border-color: rgba(245, 158, 11, 0.25);
  }
  .badge--danger {
    background: rgba(239, 68, 68, 0.15);
    color: #fca5a5;
    border-color: rgba(239, 68, 68, 0.25);
  }
  .badge--info {
    background: rgba(6, 182, 212, 0.15);
    color: #67e8f9;
    border-color: rgba(6, 182, 212, 0.25);
  }
  .badge--neutral {
    background: rgba(100, 116, 139, 0.15);
    color: #94a3b8;
    border-color: rgba(100, 116, 139, 0.2);
  }
}
</style>
