<template>
  <div class="column items-center justify-center q-pa-xl text-center">
    <q-icon :name="icon" size="64px" color="grey-8" />
    <div class="text-h6 text-grey-5 q-mt-md">{{ title }}</div>
    <div class="text-caption text-grey-6 q-mb-md" style="max-width: 300px">
      {{ message }}
    </div>
    <q-btn
      v-if="actionLabel"
      outline
      color="primary"
      :label="actionLabel"
      @click="$emit('action')"
    />
  </div>
</template>

<script setup>
defineProps({
  icon: {
    type: String,
    default: 'inbox',
  },
  title: {
    type: String,
    default: 'No data found',
  },
  message: {
    type: String,
    default: "There's nothing here yet.",
  },
  actionLabel: {
    type: String,
    default: '',
  },
})

defineEmits(['action'])
</script>
