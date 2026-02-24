<template>
  <q-card
    class="my-card overflow-hidden"
    :class="$q.dark.isActive ? 'bg-grey-9 text-white' : 'bg-white text-grey-9'"
    flat
    bordered
  >
    <q-card-section>
      <div class="row items-center no-wrap">
        <div class="col">
          <div class="text-subtitle2" :class="$q.dark.isActive ? 'text-grey-4' : 'text-grey-8'">
            {{ title }}
          </div>
          <div class="text-h4 text-weight-bold q-my-sm">{{ value }}</div>
          <div
            v-if="trend !== 0"
            :class="trend > 0 ? 'text-positive' : 'text-negative'"
            class="row items-center q-gutter-x-xs text-caption text-weight-bold"
          >
            <q-icon :name="trend > 0 ? 'arrow_upward' : 'arrow_downward'" />
            <span>{{ Math.abs(trend) }}% {{ trend > 0 ? 'increase' : 'decrease' }}</span>
          </div>
        </div>
        <div class="col-auto">
          <q-avatar size="48px" :color="color" text-color="white" :icon="icon" />
        </div>
      </div>
    </q-card-section>
  </q-card>
</template>

<script setup>
defineProps({
  title: {
    type: String,
    required: true,
  },
  value: {
    type: [String, Number],
    required: true,
  },
  icon: {
    type: String,
    default: 'analytics',
  },
  color: {
    type: String,
    default: 'primary',
  },
  trend: {
    type: Number,
    default: 0,
  },
})
</script>

<style scoped>
.my-card {
  border-radius: 12px;
  transition: transform 0.2s;
}
.my-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
}
</style>
