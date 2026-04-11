<template>
  <div
    class="kpi-card"
    :class="[gradientClass, { 'kpi-clickable': hasClick }]"
    @click="$emit('click')"
  >
    <!-- Decorative orb -->
    <div class="kpi-orb"></div>

    <!-- Top row -->
    <div class="row items-start justify-between no-wrap q-mb-sm">
      <div class="kpi-label">{{ title }}</div>
      <div class="kpi-icon-box">
        <q-icon :name="icon" size="20px" />
      </div>
    </div>

    <!-- Value row -->
    <div class="kpi-value-row">
      <q-skeleton v-if="loading" type="text" width="110px" class="kpi-skeleton" />
      <template v-else>
        <span v-if="prefix" class="kpi-prefix">{{ prefix }}</span>
        <span class="kpi-value">{{ formatValue(value) }}</span>
        <span v-if="suffix" class="kpi-suffix">{{ suffix }}</span>
      </template>
    </div>

    <!-- Delta row -->
    <div class="kpi-footer" v-if="!loading">
      <template v-if="delta !== undefined">
        <span class="kpi-delta" :class="delta >= 0 ? 'kpi-delta--up' : 'kpi-delta--down'">
          <q-icon :name="delta >= 0 ? 'trending_up' : 'trending_down'" size="13px" />
          {{ Math.abs(delta).toFixed(1) }}%
        </span>
        <span class="kpi-delta-label">vs prev. period</span>
      </template>
      <span v-else class="kpi-delta-placeholder">—</span>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  title: String,
  value: [Number, String],
  delta: Number,
  icon: String,
  color: { type: String, default: 'primary' },
  prefix: String,
  suffix: String,
  loading: Boolean,
})

defineEmits(['click'])

const hasClick = computed(() => Boolean(props.value !== undefined))

const gradientClass = computed(() => {
  const map = {
    primary: 'kpi--indigo',
    positive: 'kpi--green',
    negative: 'kpi--red',
    warning: 'kpi--amber',
    info: 'kpi--cyan',
    secondary: 'kpi--purple',
    'grey-7': 'kpi--slate',
  }
  return map[props.color] || 'kpi--indigo'
})

function formatValue(val) {
  if (typeof val !== 'number') return val ?? '-'
  if (val >= 1_000_000) return (val / 1_000_000).toFixed(1) + 'M'
  if (val >= 1_000) return (val / 1_000).toFixed(1) + 'K'
  return val.toLocaleString()
}
</script>

<style scoped lang="scss">
.kpi-card {
  position: relative;
  border-radius: 18px;
  padding: 20px;
  min-height: 140px;
  height: 100%;
  overflow: hidden;
  cursor: default;
  border: 1px solid transparent;
  transition:
    transform 0.2s ease,
    box-shadow 0.2s ease;
  display: flex;
  flex-direction: column;
  justify-content: space-between;

  &:hover {
    transform: translateY(-3px);
  }
  &.kpi-clickable {
    cursor: pointer;
    &:hover {
      transform: translateY(-4px);
    }
  }
}

// ─── Gradient Themes ────────────────────────────────────────
.kpi--indigo {
  background: linear-gradient(145deg, #4f46e5 0%, #6d28d9 100%);
  box-shadow: 0 8px 24px rgba(79, 70, 229, 0.3);
  .kpi-icon-box {
    background: rgba(255, 255, 255, 0.16);
  }
}
.kpi--green {
  background: linear-gradient(145deg, #059669 0%, #10b981 100%);
  box-shadow: 0 8px 24px rgba(16, 185, 129, 0.28);
  .kpi-icon-box {
    background: rgba(255, 255, 255, 0.16);
  }
}
.kpi--red {
  background: linear-gradient(145deg, #dc2626 0%, #ef4444 100%);
  box-shadow: 0 8px 24px rgba(239, 68, 68, 0.28);
  .kpi-icon-box {
    background: rgba(255, 255, 255, 0.16);
  }
}
.kpi--amber {
  background: linear-gradient(145deg, #d97706 0%, #f59e0b 100%);
  box-shadow: 0 8px 24px rgba(245, 158, 11, 0.28);
  .kpi-icon-box {
    background: rgba(255, 255, 255, 0.16);
  }
}
.kpi--cyan {
  background: linear-gradient(145deg, #0891b2 0%, #06b6d4 100%);
  box-shadow: 0 8px 24px rgba(6, 182, 212, 0.28);
  .kpi-icon-box {
    background: rgba(255, 255, 255, 0.16);
  }
}
.kpi--purple {
  background: linear-gradient(145deg, #7c3aed 0%, #a855f7 100%);
  box-shadow: 0 8px 24px rgba(139, 92, 246, 0.28);
  .kpi-icon-box {
    background: rgba(255, 255, 255, 0.16);
  }
}
.kpi--slate {
  background: linear-gradient(145deg, #475569 0%, #64748b 100%);
  box-shadow: 0 8px 24px rgba(71, 85, 105, 0.22);
  .kpi-icon-box {
    background: rgba(255, 255, 255, 0.12);
  }
}

// ─── Orb ────────────────────────────────────────────────────
.kpi-orb {
  position: absolute;
  right: -30px;
  top: -30px;
  width: 110px;
  height: 110px;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.07);
  pointer-events: none;
}

// ─── Inner ──────────────────────────────────────────────────
.kpi-label {
  font-size: 11px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.9px;
  color: rgba(255, 255, 255, 0.72);
  line-height: 1.4;
  max-width: 75%;
  min-height: 31px; // Ensures title row is always consistent height whether 1 or 2 lines
  display: -webkit-box;
  -webkit-line-clamp: 2;
  line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.kpi-icon-box {
  width: 38px;
  height: 38px;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: rgba(255, 255, 255, 0.9);
  border: 1px solid rgba(255, 255, 255, 0.15);
  flex-shrink: 0;
}

.kpi-value-row {
  display: flex;
  align-items: baseline;
  gap: 4px;
  margin: 4px 0;
}

.kpi-prefix {
  font-size: 0.875rem;
  font-weight: 600;
  color: rgba(255, 255, 255, 0.65);
}

.kpi-value {
  font-size: 1.75rem;
  font-weight: 800;
  color: #ffffff;
  letter-spacing: -0.04em;
  font-family: 'Inter', monospace;
}

.kpi-suffix {
  font-size: 1rem;
  font-weight: 600;
  color: rgba(255, 255, 255, 0.65);
}

.kpi-skeleton {
  height: 28px;
  background: rgba(255, 255, 255, 0.15);
  border-radius: 6px;
}

// ─── Footer / Delta ─────────────────────────────────────────
.kpi-footer {
  display: flex;
  align-items: center;
  gap: 6px;
}

.kpi-delta {
  display: inline-flex;
  align-items: center;
  gap: 2px;
  font-size: 11.5px;
  font-weight: 700;
  padding: 2px 7px;
  border-radius: 20px;

  &--up {
    background: rgba(255, 255, 255, 0.18);
    color: rgba(255, 255, 255, 0.95);
  }
  &--down {
    background: rgba(0, 0, 0, 0.15);
    color: rgba(255, 255, 255, 0.85);
  }
}

.kpi-delta-label {
  font-size: 11px;
  color: rgba(255, 255, 255, 0.55);
  white-space: nowrap;
}

.kpi-delta-placeholder {
  font-size: 12px;
  color: rgba(255, 255, 255, 0.3);
}
</style>
