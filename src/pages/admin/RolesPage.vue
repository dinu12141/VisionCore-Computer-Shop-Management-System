<template>
  <q-page class="q-pa-md">
    <PageHeader
      title="Access Management"
      subtitle="Grant or restrict system feature access per user"
      showBack
    />

    <!-- Loading -->
    <div v-if="loading" class="row justify-center q-mt-xl">
      <q-spinner-dots color="primary" size="48px" />
    </div>

    <template v-else>
      <div class="row q-col-gutter-lg q-mt-sm">
        <!-- ── LEFT: User List ────────────────────────────── -->
        <div class="col-12 col-md-4">
          <q-card flat bordered class="user-panel">
            <q-card-section class="q-pb-sm">
              <div class="text-subtitle1 text-weight-bold">System Users</div>
              <div class="text-caption text-grey q-mb-sm">Select a user to manage their access</div>
              <q-input
                v-model="userSearch"
                dense
                outlined
                placeholder="Search users..."
                :dark="$q.dark.isActive"
              >
                <template v-slot:prepend><q-icon name="search" /></template>
              </q-input>
            </q-card-section>

            <q-list separator>
              <q-item
                v-for="user in filteredUsers"
                :key="user.id"
                clickable
                v-ripple
                :active="selectedUser?.id === user.id"
                active-class="user-active"
                class="user-row q-py-sm"
                @click="selectUser(user)"
              >
                <q-item-section avatar>
                  <q-avatar
                    size="40px"
                    :color="user.id === selectedUser?.id ? 'primary' : 'grey-4'"
                    :text-color="user.id === selectedUser?.id ? 'white' : 'grey-8'"
                    class="text-weight-bold"
                  >
                    {{ (user.full_name || user.email || '?')[0].toUpperCase() }}
                  </q-avatar>
                </q-item-section>

                <q-item-section>
                  <q-item-label class="text-weight-medium">{{
                    user.full_name || '(No name)'
                  }}</q-item-label>
                  <q-item-label caption class="text-grey-6">{{ user.email }}</q-item-label>
                  <div class="row q-gutter-xs q-mt-xs">
                    <q-badge
                      v-for="role in user.roles || []"
                      :key="role"
                      :color="roleColor(role)"
                      class="text-lowercase"
                      style="font-size: 10px"
                      >{{ role }}</q-badge
                    >
                  </div>
                </q-item-section>

                <q-item-section side>
                  <q-icon
                    name="chevron_right"
                    :color="user.id === selectedUser?.id ? 'primary' : 'grey-4'"
                  />
                </q-item-section>
              </q-item>

              <q-item v-if="filteredUsers.length === 0">
                <q-item-section class="text-center text-grey q-py-xl">
                  <q-icon name="person_off" size="32px" class="q-mb-sm" />
                  <div>No users found</div>
                </q-item-section>
              </q-item>
            </q-list>
          </q-card>
        </div>

        <!-- ── RIGHT: Feature Access (Menu Mirror) ──────── -->
        <div class="col-12 col-md-8">
          <!-- No user selected placeholder -->
          <q-card
            v-if="!selectedUser"
            flat
            bordered
            class="full-height-placeholder column items-center justify-center text-grey"
            style="min-height: 500px"
          >
            <q-icon name="person_search" size="64px" class="q-mb-md" color="grey-4" />
            <div class="text-h6 text-grey-5">Select a user</div>
            <div class="text-caption text-grey-4">
              Choose a user from the list to manage their feature access
            </div>
          </q-card>

          <!-- Feature access panel -->
          <q-card v-else flat bordered class="access-panel">
            <!-- Header -->
            <q-card-section class="access-header">
              <div class="row items-center justify-between no-wrap">
                <div class="row items-center no-wrap">
                  <q-avatar
                    size="46px"
                    color="primary"
                    text-color="white"
                    class="q-mr-md text-weight-bold text-h6"
                  >
                    {{ (selectedUser.full_name || selectedUser.email || '?')[0].toUpperCase() }}
                  </q-avatar>
                  <div>
                    <div class="text-h6 text-weight-bold">
                      {{ selectedUser.full_name || selectedUser.email }}
                    </div>
                    <div class="row q-gutter-xs q-mt-xs">
                      <q-badge
                        v-for="role in selectedUser.roles || []"
                        :key="role"
                        :color="roleColor(role)"
                        style="font-size: 10px; text-transform: capitalize"
                        >{{ role }}</q-badge
                      >
                    </div>
                  </div>
                </div>
                <q-btn
                  color="primary"
                  label="Save Access"
                  icon="shield"
                  :loading="saving"
                  @click="saveAccess"
                />
              </div>
            </q-card-section>

            <q-separator />

            <!-- Admin notice -->
            <q-card-section v-if="selectedUser?.roles?.includes('admin')" class="q-pa-md">
              <q-banner rounded class="bg-red-1 text-red-9">
                <template v-slot:avatar>
                  <q-icon name="security" color="red-9" size="24px" />
                </template>
                This user has the <strong>Admin</strong> role which grants unrestricted access to
                all features automatically.
              </q-banner>
            </q-card-section>

            <!-- Menu Feature Toggles -->
            <q-card-section v-else class="q-pa-sm">
              <div class="q-px-md q-pt-sm q-pb-xs">
                <div
                  class="text-caption text-grey text-weight-bold text-uppercase"
                  style="letter-spacing: 1px"
                >
                  Feature Access — Toggle which system pages this user can access
                </div>
              </div>

              <template v-for="section in menuSections" :key="section.label">
                <!-- Section header (parent with children) -->
                <div v-if="section.children?.length" class="q-mt-sm">
                  <!-- Section group label -->
                  <div class="section-group-header q-px-md q-py-xs row items-center">
                    <q-icon
                      :name="section.icon"
                      size="18px"
                      class="q-mr-sm"
                      :color="sectionColor(section.label)"
                    />
                    <span
                      class="text-caption text-weight-bold text-uppercase"
                      style="letter-spacing: 0.8px"
                    >
                      {{ section.label }}
                    </span>
                    <!-- Enable all toggle -->
                    <q-space />
                    <q-btn
                      flat
                      dense
                      round
                      size="sm"
                      :icon="allChildrenOn(section) ? 'toggle_on' : 'toggle_off'"
                      :color="allChildrenOn(section) ? 'primary' : 'grey-5'"
                      @click="toggleAllChildren(section)"
                    >
                      <q-tooltip>{{
                        allChildrenOn(section) ? 'Disable all' : 'Enable all'
                      }}</q-tooltip>
                    </q-btn>
                  </div>

                  <!-- Children -->
                  <q-item
                    v-for="child in section.children"
                    :key="child.to"
                    class="feature-item child-feature"
                    :class="{ 'feature-on': isOn(child.to) }"
                  >
                    <q-item-section avatar>
                      <div class="feature-icon" :class="{ 'feature-icon-on': isOn(child.to) }">
                        <q-icon :name="child.icon || 'chevron_right'" size="18px" />
                      </div>
                    </q-item-section>
                    <q-item-section>
                      <q-item-label>{{ child.label }}</q-item-label>
                      <q-item-label caption class="text-grey-5">{{ child.to }}</q-item-label>
                    </q-item-section>
                    <q-item-section side>
                      <q-toggle
                        :model-value="isOn(child.to)"
                        color="primary"
                        size="sm"
                        @update:model-value="toggle(child.to)"
                      />
                    </q-item-section>
                  </q-item>
                </div>

                <!-- Single item (no children) -->
                <q-item
                  v-else-if="section.to"
                  class="feature-item"
                  :class="{ 'feature-on': isOn(section.to) }"
                >
                  <q-item-section avatar>
                    <div class="feature-icon" :class="{ 'feature-icon-on': isOn(section.to) }">
                      <q-icon :name="section.icon" size="20px" />
                    </div>
                  </q-item-section>
                  <q-item-section>
                    <q-item-label class="text-weight-medium">{{ section.label }}</q-item-label>
                    <q-item-label caption class="text-grey-5">{{ section.to }}</q-item-label>
                  </q-item-section>
                  <q-item-section side>
                    <q-toggle
                      :model-value="isOn(section.to)"
                      color="primary"
                      @update:model-value="toggle(section.to)"
                    />
                  </q-item-section>
                </q-item>
              </template>
            </q-card-section>
          </q-card>
        </div>
      </div>
    </template>
  </q-page>
</template>

<script setup>
import { ref, computed, reactive, onMounted } from 'vue'
import { useQuasar } from 'quasar'
import PageHeader from 'components/common/PageHeader.vue'
import { supabase } from 'src/boot/supabase'
import { NAV_ITEMS } from 'src/config/roles'

const $q = useQuasar()
const loading = ref(true)
const saving = ref(false)
const userSearch = ref('')

const users = ref([])
const selectedUser = ref(null)
// userAccessMap: { userId: string[] (route paths) }
const userAccessMap = reactive({})

// ── Sidebar menu sections ─────────────────────────────────────────────────────
// Exclude Admin Control from toggles — admins always have full access
const menuSections = computed(() => NAV_ITEMS.filter((n) => n.label !== 'Admin Control'))

// ── Filtered users ────────────────────────────────────────────────────────────
const filteredUsers = computed(() => {
  const q = userSearch.value.trim().toLowerCase()
  if (!q) return users.value
  return users.value.filter(
    (u) => u.full_name?.toLowerCase().includes(q) || u.email?.toLowerCase().includes(q),
  )
})

// ── Access state ──────────────────────────────────────────────────────────────
function isOn(route) {
  if (!selectedUser.value || !route) return false
  return (userAccessMap[selectedUser.value.id] || []).includes(route)
}

function allChildrenOn(section) {
  if (!section.children?.length) return false
  return section.children.every((c) => isOn(c.to))
}

function toggle(route) {
  const uid = selectedUser.value?.id
  if (!uid || !route) return
  if (!userAccessMap[uid]) userAccessMap[uid] = []
  const idx = userAccessMap[uid].indexOf(route)
  if (idx === -1) userAccessMap[uid].push(route)
  else userAccessMap[uid].splice(idx, 1)
}

function toggleAllChildren(section) {
  if (!section.children || !selectedUser.value) return
  const allOn = allChildrenOn(section)
  section.children.forEach((child) => {
    const on = isOn(child.to)
    if (allOn && on) toggle(child.to) // turn off
    if (!allOn && !on) toggle(child.to) // turn on
  })
}

// ── Helpers ───────────────────────────────────────────────────────────────────
function roleColor(role) {
  const map = {
    admin: 'red-8',
    manager: 'blue-8',
    finance: 'purple-8',
    inventory: 'green-8',
    hr: 'teal-8',
    cashier: 'orange-8',
    waiter: 'cyan-8',
    kitchen: 'brown-8',
  }
  return map[role] || 'grey-7'
}

function sectionColor(label) {
  const map = {
    Dashboard: 'blue',
    'Billing & Invoices': 'green',
    Customers: 'orange',
    Inventory: 'teal',
    Finance: 'purple',
    Reports: 'indigo',
  }
  return map[label] || 'grey'
}

// ── Data loading ──────────────────────────────────────────────────────────────
async function callAdminFn(body) {
  const {
    data: { session },
  } = await supabase.auth.getSession()
  const res = await fetch(`${import.meta.env.VITE_SUPABASE_URL}/functions/v1/admin-manage-users`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${session.access_token}`,
      apikey: import.meta.env.VITE_SUPABASE_ANON_KEY,
    },
    body: JSON.stringify(body),
  })
  const json = await res.json()
  if (!res.ok || json.error) throw new Error(json.error || 'Server error')
  return json
}

async function loadUsers() {
  const data = await callAdminFn({ action: 'list' })
  users.value = data.users || []
}

async function loadUserAccess() {
  // Load per-user overrides from user_route_access table
  // Per-user access: user_id → route_path with enabled boolean
  const { data, error } = await supabase
    .from('user_route_access')
    .select('user_id, route_path, enabled')

  if (error) {
    // Table may not exist yet — use role-based defaults
    console.warn('[RolesPage] user_route_access not found, using role defaults')
    return
  }

  for (const row of data || []) {
    if (!userAccessMap[row.user_id]) userAccessMap[row.user_id] = []
    if (row.enabled) {
      userAccessMap[row.user_id].push(row.route_path)
    }
  }
}

function selectUser(user) {
  selectedUser.value = user

  // Pre-fill from role defaults if no user-specific record exists
  if (!userAccessMap[user.id]) {
    userAccessMap[user.id] = getRoleDefaults(user.roles || [])
  }
}

function getRoleDefaults(roles) {
  // role_route_access reference — get routes the role normally has
  const ROLE_DEFAULTS = {
    admin: ['*'],
    user: [
      '/dashboard',
      '/billing',
      '/billing/history',
      '/collections/outstanding',
      '/customers',
      '/inventory',
      '/finance',
      '/services',
      '/services/jobs',
      '/services/new',
      '/services/reports',
      '/reports/sales',
      '/reports/invoices',
      '/reports/payments',
    ],
    manager: [
      '/dashboard',
      '/billing',
      '/billing/history',
      '/collections/outstanding',
      '/customers',
      '/inventory',
      '/finance',
      '/services',
      '/services/jobs',
      '/services/new',
      '/services/reports',
      '/reports/sales',
      '/reports/invoices',
      '/reports/payments',
    ],
    finance: [
      '/finance',
      '/billing/history',
      '/collections/outstanding',
      '/reports/invoices',
      '/reports/payments',
    ],
    inventory: ['/inventory'],
    hr: ['/dashboard'],
    cashier: ['/billing', '/billing/history', '/collections/outstanding'],
    waiter: ['/billing'],
    kitchen: [],
  }

  const routes = new Set()
  for (const role of roles) {
    const paths = ROLE_DEFAULTS[role] || []
    if (paths.includes('*')) return [] // admin — no restrictions
    paths.forEach((p) => routes.add(p))
  }
  return [...routes]
}

// ── Save access ───────────────────────────────────────────────────────────────
async function saveAccess() {
  const user = selectedUser.value
  if (!user) return
  saving.value = true

  try {
    const routes = userAccessMap[user.id] || []

    // Upsert user_route_access for this user
    // First delete existing records for this user
    const { error: delErr } = await supabase
      .from('user_route_access')
      .delete()
      .eq('user_id', user.id)

    if (delErr) throw delErr

    // Then insert new access records
    if (routes.length > 0) {
      const { error: insErr } = await supabase.from('user_route_access').insert(
        routes.map((r) => ({
          user_id: user.id,
          route_path: r,
          enabled: true,
        })),
      )

      if (insErr) throw insErr
    }

    // Also reflect in auth store's canAccess override
    $q.notify({
      type: 'positive',
      icon: 'check_circle',
      message: `Access updated for ${user.full_name || user.email}`,
      caption: 'Changes take effect on their next login',
      position: 'top-right',
    })
  } catch (err) {
    $q.notify({ type: 'negative', message: 'Save failed: ' + err.message })
  } finally {
    saving.value = false
  }
}

// ── Init ──────────────────────────────────────────────────────────────────────
onMounted(async () => {
  try {
    await Promise.all([loadUsers(), loadUserAccess()])
    if (users.value.length) selectUser(users.value[0])
  } catch (err) {
    $q.notify({ type: 'negative', message: 'Failed to load: ' + err.message })
  } finally {
    loading.value = false
  }
})
</script>

<style scoped>
.user-panel {
  border-radius: 16px !important;
}

.access-panel {
  border-radius: 16px !important;
}

.user-row {
  border-radius: 10px;
  margin: 2px 8px;
  transition: all 0.15s ease;
}

.user-active {
  background: rgba(79, 70, 229, 0.08) !important;
  border-left: 3px solid var(--q-primary);
}

.section-group-header {
  padding-top: 12px;
  padding-bottom: 4px;
  opacity: 0.7;
}

.feature-item {
  border-radius: 10px;
  margin: 3px 12px;
  min-height: 50px;
  transition: all 0.15s ease;
}

.child-feature {
  margin-left: 28px;
  min-height: 44px;
}

.feature-on {
  background: rgba(79, 70, 229, 0.06);
}

.feature-icon {
  width: 34px;
  height: 34px;
  border-radius: 9px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(148, 163, 184, 0.1);
  color: rgba(148, 163, 184, 0.7);
  transition: all 0.18s ease;
}

.feature-icon-on {
  background: rgba(79, 70, 229, 0.15);
  color: #4f46e5;
  box-shadow: 0 2px 8px rgba(79, 70, 229, 0.2);
}

.access-header {
  background: linear-gradient(135deg, rgba(79, 70, 229, 0.04) 0%, rgba(139, 92, 246, 0.02) 100%);
  border-radius: 16px 16px 0 0;
}
</style>
