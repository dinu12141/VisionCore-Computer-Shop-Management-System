<template>
  <div
    class="stat-card"
    :class="[`stat-card--${gradient}`, { 'stat-card--clickable': clickable }]"
    @click="clickable ? $emit('click') : null"
  >
    <!-- Decorative orb -->
    <div class="stat-orb"></div>

    <div class="stat-inner">
      <!-- Top row: label + icon -->
      <div class="row items-start justify-between no-wrap q-mb-md">
        <div class="stat-label">{{ title }}</div>
        <div class="stat-icon-wrap" :class="`stat-icon--${gradient}`">
          <q-icon :name="icon" size="22px" />
        </div>
      </div>

      <!-- Value -->
      <div class="stat-value">
        <span v-if="prefix" class="stat-prefix">{{ prefix }}</span>
        {{ animatedValue }}<span v-if="suffix" class="stat-suffix">{{ suffix }}</span>
      </div>

      <!-- Trend -->
      <div class="q-mt-md">
        <div v-if="trend" class="stat-trend" :class="`stat-trend--${trendColor}`">
          <q-icon :name="trendIcon" size="13px" class="q-mr-xs" />
          <span>{{ trend }}</span>
          <span class="stat-trend-label">from last period</span>
        </div>
        <div v-else class="stat-trend" style="opacity: 0">
          <q-icon name="trending_flat" size="13px" />
          <span>0%</span>
        </div>
      </div>
    </div>

    <!-- Loading skeleton overlay -->
    <div v-if="loading" class="stat-loading">
      <q-skeleton type="rect" class="q-mb-sm" style="height: 14px; width: 60%" />
      <q-skeleton type="rect" class="q-mb-md" style="height: 32px; width: 80%" />
      <q-skeleton type="rect" style="height: 12px; width: 50%" />
    </div>
  </div>
</template>

<script setup>
import { ref, watch, onMounted } from 'vue'
import { useQuasar } from 'quasar'

const $q = useQuasar()

const props = defineProps({
  title: { type: String, required: true },
  value: { type: [String, Number], required: true },
  prefix: { type: String, default: '' },
  suffix: { type: String, default: '' },
  icon: { type: String, default: 'analytics' },
  color: { type: String, default: 'primary' },
  gradient: { type: String, default: 'primary' }, // primary | success | warning | danger | info | purple | neutral
  orbColor: { type: String, default: '' },
  trend: { type: String, default: '' },
  trendIcon: { type: String, default: 'trending_flat' },
  trendColor: { type: String, default: 'grey' },
  loading: { type: Boolean, default: false },
  clickable: { type: Boolean, default: false },
})

defineEmits(['click'])

const animatedValue = ref('0')

function parseNumericValue(val) {
  if (typeof val === 'number') return val
  if (!val) return 0
  const numericStr = val.toString().replace(/[^0-9.]/g, '')
  return parseFloat(numericStr) || 0
}

function animateNumber(to) {
  const currentValStr = animatedValue.value.toString().replace(/,/g, '')
  const startNum = parseFloat(currentValStr) || 0
  const duration = 700
  const startTime = performance.now()

  function update(currentTime) {
    const elapsed = currentTime - startTime
    const progress = Math.min(elapsed / duration, 1)
    const ease = 1 - Math.pow(1 - progress, 3)
    const current = startNum + (to - startNum) * ease

    animatedValue.value = current.toLocaleString(undefined, {
      minimumFractionDigits: typeof props.value === 'string' && props.value.includes('.') ? 2 : 0,
      maximumFractionDigits: typeof props.value === 'string' && props.value.includes('.') ? 2 : 0,
    })

    if (progress < 1) requestAnimationFrame(update)
  }
  requestAnimationFrame(update)
}

watch(
  () => props.value,
  (newVal) => animateNumber(parseNumericValue(newVal)),
  { immediate: false },
)
onMounted(() => animateNumber(parseNumericValue(props.value)))
</script>

<style scoped lang="scss">
// ─── Card Base ───────────────────────────────────────────────
.stat-card {
  position: relative;
  border-radius: 18px;
  overflow: hidden;
  padding: 22px;
  min-height: 152px;
  cursor: default;
  transition:
    transform 0.22s cubic-bezier(0.4, 0, 0.2, 1),
    box-shadow 0.22s cubic-bezier(0.4, 0, 0.2, 1);
  border: 1px solid var(--v-border);
  background: var(--v-surface);

  &:hover {
    transform: translateY(-3px);
    box-shadow: var(--v-shadow-lg);
  }

  &--clickable {
    cursor: pointer;
    &:hover {
      transform: translateY(-4px);
    }
    &:active {
      transform: translateY(-1px);
    }
  }
}

// ─── Gradient Variants ───────────────────────────────────────
.stat-card--primary {
  background: linear-gradient(140deg, #4f46e5 0%, #6d28d9 100%);
  border-color: transparent;
  box-shadow:
    0 8px 28px rgba(79, 70, 229, 0.28),
    0 2px 8px rgba(79, 70, 229, 0.15);

  .stat-label {
    color: rgba(255, 255, 255, 0.75);
  }
  .stat-value {
    color: #ffffff;
  }
  .stat-prefix,
  .stat-suffix {
    color: rgba(255, 255, 255, 0.7);
  }
  .stat-trend {
    background: rgba(255, 255, 255, 0.12);
    color: rgba(255, 255, 255, 0.85);
  }
}

.stat-card--success {
  background: linear-gradient(140deg, #059669 0%, #10b981 100%);
  border-color: transparent;
  box-shadow:
    0 8px 28px rgba(16, 185, 129, 0.28),
    0 2px 8px rgba(16, 185, 129, 0.15);

  .stat-label {
    color: rgba(255, 255, 255, 0.75);
  }
  .stat-value {
    color: #ffffff;
  }
  .stat-prefix,
  .stat-suffix {
    color: rgba(255, 255, 255, 0.7);
  }
  .stat-trend {
    background: rgba(255, 255, 255, 0.12);
    color: rgba(255, 255, 255, 0.85);
  }
}

.stat-card--warning {
  background: linear-gradient(140deg, #d97706 0%, #f59e0b 100%);
  border-color: transparent;
  box-shadow:
    0 8px 28px rgba(245, 158, 11, 0.28),
    0 2px 8px rgba(245, 158, 11, 0.15);

  .stat-label {
    color: rgba(255, 255, 255, 0.75);
  }
  .stat-value {
    color: #ffffff;
  }
  .stat-prefix,
  .stat-suffix {
    color: rgba(255, 255, 255, 0.7);
  }
  .stat-trend {
    background: rgba(255, 255, 255, 0.12);
    color: rgba(255, 255, 255, 0.85);
  }
}

.stat-card--danger {
  background: linear-gradient(140deg, #dc2626 0%, #ef4444 100%);
  border-color: transparent;
  box-shadow:
    0 8px 28px rgba(239, 68, 68, 0.28),
    0 2px 8px rgba(239, 68, 68, 0.15);

  .stat-label {
    color: rgba(255, 255, 255, 0.75);
  }
  .stat-value {
    color: #ffffff;
  }
  .stat-prefix,
  .stat-suffix {
    color: rgba(255, 255, 255, 0.7);
  }
  .stat-trend {
    background: rgba(255, 255, 255, 0.12);
    color: rgba(255, 255, 255, 0.85);
  }
}

.stat-card--info {
  background: linear-gradient(140deg, #0891b2 0%, #06b6d4 100%);
  border-color: transparent;
  box-shadow:
    0 8px 28px rgba(6, 182, 212, 0.28),
    0 2px 8px rgba(6, 182, 212, 0.15);

  .stat-label {
    color: rgba(255, 255, 255, 0.75);
  }
  .stat-value {
    color: #ffffff;
  }
  .stat-prefix,
  .stat-suffix {
    color: rgba(255, 255, 255, 0.7);
  }
  .stat-trend {
    background: rgba(255, 255, 255, 0.12);
    color: rgba(255, 255, 255, 0.85);
  }
}

.stat-card--purple {
  background: linear-gradient(140deg, #7c3aed 0%, #a855f7 100%);
  border-color: transparent;
  box-shadow:
    0 8px 28px rgba(139, 92, 246, 0.28),
    0 2px 8px rgba(139, 92, 246, 0.15);

  .stat-label {
    color: rgba(255, 255, 255, 0.75);
  }
  .stat-value {
    color: #ffffff;
  }
  .stat-prefix,
  .stat-suffix {
    color: rgba(255, 255, 255, 0.7);
  }
  .stat-trend {
    background: rgba(255, 255, 255, 0.12);
    color: rgba(255, 255, 255, 0.85);
  }
}

.stat-card--neutral {
  background: v-bind("$q.dark.isActive ? 'rgba(30,40,58,0.9)' : 'rgba(255,255,255,0.95)'");
  box-shadow: var(--v-shadow-sm);
  border-color: var(--v-border);

  .stat-label {
    color: var(--v-text-2);
  }
  .stat-value {
    color: var(--v-text-1);
  }
  .stat-prefix,
  .stat-suffix {
    color: var(--v-text-3);
  }
}

// ─── Decorative Orb ─────────────────────────────────────────
.stat-orb {
  position: absolute;
  right: -32px;
  top: -32px;
  width: 120px;
  height: 120px;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.08);
  pointer-events: none;

  .stat-card--neutral & {
    display: none;
  }
}

// ─── Content ────────────────────────────────────────────────
.stat-inner {
  position: relative;
  z-index: 1;
}

.stat-label {
  font-size: 11.5px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.9px;
  line-height: 1.4;
}

.stat-icon-wrap {
  width: 42px;
  height: 42px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(255, 255, 255, 0.18);
  border: 1px solid rgba(255, 255, 255, 0.2);
  flex-shrink: 0;

  .stat-card--neutral & {
    background: var(--v-primary-soft);
    border-color: rgba(79, 70, 229, 0.15);
    color: var(--v-primary);
  }
}

.stat-value {
  font-size: 1.875rem;
  font-weight: 800;
  letter-spacing: -0.03em;
  line-height: 1.15;
  font-family: 'Inter', 'JetBrains Mono', monospace;
}

.stat-prefix {
  font-size: 1rem;
  font-weight: 600;
  margin-right: 4px;
  opacity: 0.75;
  vertical-align: baseline;
}

.stat-suffix {
  font-size: 1.1rem;
  font-weight: 600;
  margin-left: 2px;
  opacity: 0.75;
}

.stat-trend {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  font-size: 12px;
  font-weight: 600;
  padding: 3px 8px;
  border-radius: 20px;
  letter-spacing: 0.2px;

  .stat-card--neutral & {
    &.stat-trend--positive {
      background: var(--v-success-soft);
      color: #059669;
    }
    &.stat-trend--negative {
      background: var(--v-danger-soft);
      color: #dc2626;
    }
    &.stat-trend--grey {
      background: var(--v-border);
      color: var(--v-text-2);
    }
  }
}

.stat-trend-label {
  font-weight: 400;
  opacity: 0.7;
  margin-left: 4px;
  font-size: 11px;
}

// ─── Loading Overlay ────────────────────────────────────────
.stat-loading {
  position: absolute;
  inset: 0;
  background: v-bind("$q.dark.isActive ? 'rgba(15,22,36,0.7)' : 'rgba(255,255,255,0.7)'");
  backdrop-filter: blur(6px);
  border-radius: inherit;
  padding: 22px;
  display: flex;
  flex-direction: column;
  justify-content: center;
}
</style>
