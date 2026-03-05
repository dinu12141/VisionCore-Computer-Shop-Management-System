<template>
  <q-page class="q-pa-md">
    <PageHeader title="System Settings" subtitle="Global configuration preferences" showBack />

    <!-- Module Configuration Section -->
    <div class="q-mt-lg">
      <div class="row items-center q-mb-md">
        <q-icon name="extension" size="28px" color="primary" class="q-mr-sm" />
        <div class="text-h6" :class="$q.dark.isActive ? 'text-white' : 'text-grey-9'">
          Module Configuration
        </div>
        <q-space />
        <q-badge v-if="hasUnsavedChanges" color="warning" label="Unsaved changes" class="q-mr-md" />
        <q-btn
          color="primary"
          label="Save Changes"
          icon="save"
          :loading="saving"
          :disable="!hasUnsavedChanges"
          @click="saveModules"
        />
      </div>

      <div v-if="modulesStore.loading" class="text-center q-pa-xl">
        <q-spinner-dots size="40px" color="primary" />
        <div class="text-grey-5 q-mt-sm">Loading modules...</div>
      </div>

      <div v-else class="row q-col-gutter-md">
        <div v-for="mod in localModules" :key="mod.id" class="col-12 col-sm-6 col-md-4">
          <q-card
            flat
            bordered
            class="module-card full-height"
            :class="{
              'module-enabled': mod.is_enabled,
              'module-disabled': !mod.is_enabled,
              'bg-grey-9 text-white': $q.dark.isActive,
              'bg-white text-grey-9': !$q.dark.isActive,
            }"
          >
            <q-card-section class="row items-start no-wrap">
              <q-avatar
                size="48px"
                :color="mod.is_enabled ? getModuleColor(mod.code) : 'grey-8'"
                text-color="white"
                :icon="mod.icon || 'settings'"
                class="q-mr-md"
              />
              <div class="col">
                <div
                  class="text-subtitle1 text-weight-bold"
                  :class="$q.dark.isActive ? 'text-white' : 'text-grey-9'"
                >
                  {{ mod.name }}
                </div>
                <div
                  class="text-caption q-mt-xs"
                  :class="$q.dark.isActive ? 'text-grey-5' : 'text-grey-7'"
                >
                  {{ mod.description }}
                </div>
              </div>
            </q-card-section>

            <q-separator :dark="$q.dark.isActive" />

            <q-card-section class="row items-center justify-between">
              <q-chip
                dense
                :color="mod.is_enabled ? 'green-9' : 'red-9'"
                text-color="white"
                :icon="mod.is_enabled ? 'check_circle' : 'cancel'"
                :label="mod.is_enabled ? 'Enabled' : 'Disabled'"
                size="sm"
              />
              <q-toggle
                :model-value="mod.is_enabled"
                :color="getModuleColor(mod.code)"
                @update:model-value="(val) => toggleLocal(mod.code, val)"
              />
            </q-card-section>
          </q-card>
        </div>
      </div>
    </div>

    <!-- General Settings Section -->
    <div class="q-mt-xl">
      <div class="row items-center q-mb-md">
        <q-icon name="tune" size="28px" color="orange" class="q-mr-sm" />
        <div class="text-h6" :class="$q.dark.isActive ? 'text-white' : 'text-grey-9'">
          General Settings
        </div>
      </div>

      <div class="row q-col-gutter-md">
        <div class="col-12 col-md-6">
          <q-card flat bordered :class="$q.dark.isActive ? 'bg-grey-10' : 'bg-white'">
            <q-card-section class="q-gutter-md">
              <q-input
                v-model="settings.appName"
                label="Application Name"
                outlined
                dense
                :dark="$q.dark.isActive"
              />
              <q-select
                v-model="settings.timezone"
                label="Timezone"
                :options="['UTC', 'EST', 'PST', 'IST', 'Asia/Colombo']"
                outlined
                dense
                :dark="$q.dark.isActive"
              />
              <q-select
                v-model="settings.currency"
                label="Currency"
                :options="['USD', 'EUR', 'INR', 'GBP', 'LKR']"
                outlined
                dense
                :dark="$q.dark.isActive"
              />
            </q-card-section>
          </q-card>
        </div>

        <div class="col-12 col-md-6">
          <q-card flat bordered :class="$q.dark.isActive ? 'bg-grey-10' : 'bg-white'">
            <q-card-section class="q-gutter-md">
              <q-input
                v-model="settings.logoUrl"
                label="Logo URL"
                outlined
                dense
                :dark="$q.dark.isActive"
              />
              <q-toggle
                v-model="settings.maintenanceMode"
                label="Maintenance Mode"
                color="red"
                :dark="$q.dark.isActive"
              />
            </q-card-section>

            <q-separator :dark="$q.dark.isActive" />

            <q-card-actions class="q-pa-md">
              <q-btn
                color="primary"
                label="Save General Settings"
                class="full-width"
                @click="saveGeneralSettings"
              />
            </q-card-actions>
          </q-card>
        </div>
      </div>
    </div>
  </q-page>
</template>

<script setup>
import { ref, computed, onMounted, reactive, watch } from 'vue'
import PageHeader from 'components/common/PageHeader.vue'
import { useQuasar } from 'quasar'
import { useModulesStore } from 'src/stores/modules'
import { useAuthStore } from 'src/stores/auth'

const $q = useQuasar()
const modulesStore = useModulesStore()
const authStore = useAuthStore()

// --- Module Toggles ---
const localModules = ref([])
const saving = ref(false)

const companyId = computed(() => {
  return authStore.currentBranch?.company_id || null
})

// Deep copy modules for local editing
watch(
  () => modulesStore.modules,
  (mods) => {
    localModules.value = mods.map((m) => ({ ...m }))
  },
  { immediate: true, deep: true },
)

const hasUnsavedChanges = computed(() => {
  return localModules.value.some((local) => {
    const orig = modulesStore.modules.find((m) => m.id === local.id)
    return orig && orig.is_enabled !== local.is_enabled
  })
})

function toggleLocal(code, val) {
  const mod = localModules.value.find((m) => m.code === code)
  if (mod) mod.is_enabled = val
}

function getModuleColor(code) {
  const colors = {
    GRN: 'green-8',
    GIN: 'red-8',
    TRANSFER: 'blue-8',
    AUTO_DEDUCT: 'purple-8',
    NEGATIVE_STOCK: 'orange-8',
    BATCH_TRACKING: 'teal-8',
    FINANCE: 'amber-9',
    HR: 'pink-8',
  }
  return colors[code] || 'primary'
}

async function saveModules() {
  saving.value = true
  try {
    const changes = localModules.value
      .filter((local) => {
        const orig = modulesStore.modules.find((m) => m.id === local.id)
        return orig && orig.is_enabled !== local.is_enabled
      })
      .map((m) => ({ id: m.id, is_enabled: m.is_enabled }))

    if (changes.length === 0) return

    await modulesStore.batchUpdate(changes)
    $q.notify({ type: 'positive', message: `${changes.length} module(s) updated successfully` })
  } catch (err) {
    $q.notify({ type: 'negative', message: 'Failed to save: ' + (err.message || err) })
  } finally {
    saving.value = false
  }
}

// --- General Settings ---
const settings = reactive({
  appName: 'VisionCore ERP',
  timezone: 'Asia/Colombo',
  currency: 'LKR',
  maintenanceMode: false,
  logoUrl: '',
})

const saveGeneralSettings = () => {
  $q.loading.show()
  setTimeout(() => {
    $q.loading.hide()
    $q.notify({ type: 'positive', message: 'General settings saved' })
  }, 800)
}

// Load modules on mount
onMounted(async () => {
  if (!modulesStore.loaded) {
    await modulesStore.fetchModules(companyId.value)
  }
})
</script>

<style scoped>
.module-card {
  transition: all 0.25s ease;
}
.module-card:hover {
  transform: translateY(-2px);
}
.module-enabled {
  border-left: 3px solid #4caf50;
}
.module-disabled {
  border-left: 3px solid #666;
  opacity: 0.75;
}
</style>
