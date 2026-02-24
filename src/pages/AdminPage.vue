<template>
  <q-page class="q-pa-md">
    <PageHeader title="Admin Console" subtitle="System configuration and management" />

    <div class="row q-col-gutter-md">
      <div
        v-for="(module, index) in modules"
        :key="index"
        class="col-12 col-sm-6 col-md-4 col-lg-3"
      >
        <q-card
          class="full-height cursor-pointer setting-card"
          :class="$q.dark.isActive ? 'bg-grey-9 text-white' : 'bg-white text-grey-9'"
          flat
          bordered
          @click="$router.push(module.to)"
        >
          <q-card-section class="text-center q-py-xl">
            <q-avatar
              size="80px"
              font-size="40px"
              :color="module.color"
              text-color="white"
              :icon="module.icon"
              class="q-mb-md shadow-2"
            />
            <div class="text-h6">{{ module.title }}</div>
            <div
              class="text-caption q-mt-sm"
              :class="$q.dark.isActive ? 'text-grey-5' : 'text-grey-7'"
            >
              {{ module.description }}
            </div>
          </q-card-section>

          <q-separator :dark="$q.dark.isActive" />

          <q-card-actions align="center">
            <q-btn flat color="primary" label="Open Settings" :to="module.to" />
          </q-card-actions>
        </q-card>
      </div>
    </div>
  </q-page>
</template>

<script setup>
import { ref } from 'vue'
import PageHeader from 'components/common/PageHeader.vue'

const modules = ref([
  {
    title: 'User Management',
    description: 'Manage staffs, waiters, and admin accounts.',
    icon: 'group',
    color: 'blue',
    to: '/admin/users',
  },
  {
    title: 'Role & Permissions',
    description: 'Configure access levels and security policies.',
    icon: 'security',
    color: 'indigo',
    to: '/admin/roles',
  },
  {
    title: 'System Settings',
    description: 'Global system configuration',
    icon: 'settings',
    color: 'grey-8',
    to: '/admin/settings',
  },
  {
    title: 'Backup Center',
    description: 'Schedule, run, and download system backups.',
    icon: 'backup',
    color: 'teal',
    to: '/admin/backup',
  },
])
</script>

<style scoped>
.setting-card {
  transition: all 0.2s ease;
}
.setting-card:hover {
  transform: translateY(-4px);
  border-color: var(--q-primary);
}
</style>
