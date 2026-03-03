<template>
  <q-layout view="lHh Lpr lFf" class="erp-layout">
    <!-- ════════════════════════════  HEADER  ════════════════════════════ -->
    <q-header class="erp-header">
      <q-toolbar class="erp-toolbar">
        <q-btn
          flat
          dense
          round
          icon="menu"
          aria-label="Toggle navigation"
          class="menu-toggle-btn"
          @click="toggleLeftDrawer"
        />

        <q-toolbar-title />

        <!-- Global Search -->
        <GlobalSearch />

        <q-space />

        <!-- Role Chips -->
        <q-chip
          v-for="role in authStore.roles"
          :key="role"
          dense
          :color="roleChipColor(role)"
          text-color="white"
          class="q-mr-xs"
          size="sm"
        >
          <q-icon :name="roleIcon(role)" size="14px" class="q-mr-xs" />
          {{ role }}
        </q-chip>

        <!-- Theme Toggle -->
        <q-btn
          flat
          round
          dense
          :icon="$q.dark.isActive ? 'light_mode' : 'dark_mode'"
          @click="toggleTheme"
          class="q-mr-xs header-action-btn"
        >
          <q-tooltip>{{
            $q.dark.isActive ? 'Switch to Light Mode' : 'Switch to Dark Mode'
          }}</q-tooltip>
        </q-btn>

        <!-- Notification Bell -->
        <NotificationPanel />

        <!-- User Menu -->
        <q-btn round flat class="profile-btn q-ml-sm">
          <q-avatar size="36px" class="header-avatar shadow-sm">
            <img src="https://cdn.quasar.dev/img/boy-avatar.png" />
            <div class="status-indicator"></div>
          </q-avatar>

          <q-menu
            :offset="[0, 12]"
            transition-show="jump-down"
            transition-hide="jump-up"
            class="profile-dropdown-menu"
          >
            <div class="dropdown-content">
              <div class="user-profile-header q-pa-lg">
                <div class="row items-center no-wrap">
                  <q-avatar size="56px" class="q-mr-md shadow-2 avatar-glow">
                    <img src="https://cdn.quasar.dev/img/boy-avatar.png" />
                  </q-avatar>
                  <div class="column">
                    <div class="text-subtitle1 text-weight-bold lh-1 profile-name">
                      {{ authStore.userDisplayName }}
                    </div>
                    <div class="text-caption text-grey-6 q-mb-xs profile-email">
                      {{ authStore.user?.email }}
                    </div>
                    <div class="row q-gutter-xs">
                      <q-badge
                        v-for="role in authStore.roles"
                        :key="role"
                        :class="['role-pill', role === 'admin' ? 'admin-pill' : 'standard-pill']"
                      >
                        {{ role }}
                      </q-badge>
                    </div>
                  </div>
                </div>
              </div>

              <q-separator class="divider" />

              <q-list padding class="menu-list q-px-sm">
                <q-item clickable v-close-popup class="menu-item">
                  <q-item-section avatar>
                    <q-icon name="manage_accounts" size="22px" class="menu-icon" />
                  </q-item-section>
                  <q-item-section class="menu-label">Profile</q-item-section>
                  <q-item-section side>
                    <q-icon name="chevron_right" size="14px" class="chevron-icon" />
                  </q-item-section>
                </q-item>

                <q-item clickable v-close-popup class="menu-item">
                  <q-item-section avatar>
                    <q-icon name="settings" size="22px" class="menu-icon" />
                  </q-item-section>
                  <q-item-section class="menu-label">Settings</q-item-section>
                </q-item>

                <q-item clickable v-close-popup class="menu-item">
                  <q-item-section avatar>
                    <q-icon name="history" size="22px" class="menu-icon" />
                  </q-item-section>
                  <q-item-section class="menu-label">My Activity</q-item-section>
                </q-item>

                <q-item clickable @click="toggleTheme" class="menu-item theme-item">
                  <q-item-section avatar>
                    <q-icon
                      :name="$q.dark.isActive ? 'light_mode' : 'dark_mode'"
                      size="22px"
                      class="menu-icon"
                    />
                  </q-item-section>
                  <q-item-section class="menu-label">
                    {{ $q.dark.isActive ? 'Light Mode' : 'Dark Mode' }}
                  </q-item-section>
                  <q-item-section side>
                    <q-toggle
                      :model-value="$q.dark.isActive"
                      dense
                      @update:model-value="toggleTheme"
                      color="primary"
                    />
                  </q-item-section>
                </q-item>

                <q-separator class="q-my-sm divider" />

                <q-item clickable v-close-popup @click="logout" class="menu-item logout-item">
                  <q-item-section avatar>
                    <q-icon name="logout" size="22px" class="menu-icon logout-icon" />
                  </q-item-section>
                  <q-item-section class="menu-label logout-label">Sign Out</q-item-section>
                </q-item>
              </q-list>
            </div>
          </q-menu>
        </q-btn>
      </q-toolbar>
    </q-header>

    <!-- ════════════════════════════  SIDEBAR  ════════════════════════════ -->
    <q-drawer
      v-model="leftDrawerOpen"
      show-if-above
      :width="260"
      :breakpoint="1024"
      class="erp-sidebar"
    >
      <div class="sidebar-inner">
        <!-- ── Brand ── -->
        <div class="sidebar-brand">
          <div class="brand-logo-wrap">
            <q-img src="/logo.png" style="width: 30px; height: 30px" />
          </div>
          <div class="brand-text">
            <div class="brand-name">VISION CORE</div>
            <div class="brand-sub">Enterprise ERP v2</div>
          </div>
        </div>

        <!-- ── Navigation ── -->
        <q-scroll-area class="sidebar-scroll-area">
          <nav class="sidebar-nav">
            <template v-for="item in filteredMenuItems" :key="item.label">
              <!-- ── Leaf nav item (no children) ── -->
              <q-item
                v-if="!item.children"
                clickable
                v-ripple="false"
                :to="item.to"
                exact
                class="nav-item"
                active-class="nav-item--active"
              >
                <div class="nav-icon-cell">
                  <q-icon :name="item.icon" size="20px" class="nav-icon" />
                </div>
                <div class="nav-label">{{ item.label }}</div>
              </q-item>

              <!-- ── Collapsible group ── -->
              <div
                v-else
                class="nav-group"
                :class="{ 'nav-group--open': expansionState[item.label] }"
              >
                <!-- Group header -->
                <div
                  class="nav-item nav-item--group"
                  :class="{ 'nav-item--group-open': expansionState[item.label] }"
                  @click="toggleGroup(item.label)"
                >
                  <div class="nav-icon-cell">
                    <q-icon :name="item.icon" size="20px" class="nav-icon" />
                  </div>
                  <div class="nav-label">{{ item.label }}</div>
                  <div class="nav-chevron">
                    <q-icon
                      name="chevron_right"
                      size="16px"
                      class="chevron-icon"
                      :class="{ 'chevron-open': expansionState[item.label] }"
                    />
                  </div>
                </div>

                <!-- Sub-items -->
                <transition name="nav-slide">
                  <div v-if="expansionState[item.label]" class="nav-submenu">
                    <q-item
                      v-for="child in item.children"
                      :key="child.to"
                      clickable
                      v-ripple="false"
                      :to="child.to"
                      exact
                      class="nav-item nav-item--sub"
                      active-class="nav-item--active"
                    >
                      <div class="nav-sub-indent">
                        <div class="nav-sub-dot"></div>
                      </div>
                      <div class="nav-icon-cell nav-icon-cell--sub">
                        <q-icon :name="child.icon" size="17px" class="nav-icon" />
                      </div>
                      <div class="nav-label nav-label--sub">{{ child.label }}</div>
                    </q-item>
                  </div>
                </transition>
              </div>
            </template>
          </nav>
        </q-scroll-area>

        <!-- ── Sidebar Footer ── -->
        <div class="sidebar-footer">
          <div class="sidebar-divider"></div>
          <div class="sidebar-user">
            <q-avatar size="34px" class="user-avatar">
              {{ (authStore.userDisplayName || '?')[0].toUpperCase() }}
            </q-avatar>
            <div class="user-info">
              <div class="user-name">{{ authStore.userDisplayName }}</div>
              <div class="user-role">{{ authStore.roles.join(' · ') }}</div>
            </div>
            <div class="user-status-dot"></div>
          </div>
        </div>
      </div>
    </q-drawer>

    <!-- ════════════════════════════  CONTENT  ════════════════════════════ -->
    <q-page-container>
      <router-view />
    </q-page-container>
  </q-layout>
</template>

<script setup>
import { ref, computed, onMounted, reactive } from 'vue'
import { useRouter } from 'vue-router'
import { useQuasar } from 'quasar'
import { useAuthStore } from 'stores/auth'
import { getFilteredNavItems } from 'src/config/roles'
import { useModulesStore } from 'src/stores/modules'
import NotificationPanel from 'components/common/NotificationPanel.vue'
import GlobalSearch from 'components/common/GlobalSearch.vue'
import { useNotificationStore } from 'src/stores/notifications'

const $q = useQuasar()
const leftDrawerOpen = ref(true)
const expansionState = reactive({})

const router = useRouter()
const authStore = useAuthStore()
const modulesStore = useModulesStore()
const notificationStore = useNotificationStore()

onMounted(async () => {
  if (authStore.user) {
    const companyId = authStore.currentBranch?.company_id
    if (companyId) {
      // Run immediately + re-check every 30 min for collection date alerts
      notificationStore.startPolling(companyId)
    }
  }
})

function toggleLeftDrawer() {
  leftDrawerOpen.value = !leftDrawerOpen.value
}

function toggleTheme() {
  $q.dark.toggle()
  localStorage.setItem('theme-dark', String($q.dark.isActive))
}

function toggleGroup(label) {
  expansionState[label] = !expansionState[label]
}

function logout() {
  router.push('/auth/login')
  authStore.signOut()
}

// Filtered + module-gated nav items
const filteredMenuItems = computed(() => {
  const roleFiltered = getFilteredNavItems(authStore.roles || [], authStore.canAccess)

  function recursiveModuleFilter(items) {
    return items
      .filter((item) => {
        if (!item.moduleCode) return true
        return modulesStore.isModuleEnabled(item.moduleCode)
      })
      .map((item) => {
        if (item.children) {
          return { ...item, children: recursiveModuleFilter(item.children) }
        }
        return item
      })
      .filter((item) => {
        if (item.children && item.children.length === 0 && !item.to) return false
        return true
      })
  }

  return recursiveModuleFilter(roleFiltered)
})

const themeStyles = computed(() => {
  const isDark = $q.dark.isActive
  return {
    headerBg: isDark ? 'rgba(10, 15, 28, 0.97)' : 'rgba(255, 255, 255, 0.95)',
    headerBorder: isDark ? 'rgba(255, 255, 255, 0.055)' : 'rgba(15, 23, 42, 0.055)',
    headerShadow: isDark
      ? '0 1px 0 rgba(255, 255, 255, 0.04), 0 4px 24px rgba(0, 0, 0, 0.05)'
      : '0 1px 0 rgba(0, 0, 0, 0.04), 0 4px 24px rgba(0, 0, 0, 0.05)',
    headerText: isDark ? '#F1F5F9' : '#0F172A',
    headerAction: isDark ? 'rgba(241, 245, 249, 0.6)' : 'rgba(100, 116, 139, 0.9)',
    sidebarBg: isDark ? '#0D1117' : '#FAFBFC',
    sidebarBorder: isDark ? 'rgba(255, 255, 255, 0.055)' : 'rgba(15, 23, 42, 0.07)',
    sidebarShadow: isDark
      ? '1px 0 0 rgba(255, 255, 255, 0.02), 4px 0 32px rgba(0, 0, 0, 0.06)'
      : '1px 0 0 rgba(0, 0, 0, 0.02), 4px 0 32px rgba(0, 0, 0, 0.06)',
    brandBg: isDark ? 'rgba(79, 70, 229, 0.09)' : 'rgba(79, 70, 229, 0.05)',
    brandBorder: isDark ? 'rgba(99, 102, 241, 0.18)' : 'rgba(99, 102, 241, 0.10)',
    brandName: isDark ? '#E2E8F0' : '#0F172A',
    brandSub: isDark ? 'rgba(99, 102, 241, 0.9)' : '#6366F1',
    navItemText: isDark ? 'rgba(203, 213, 225, 0.65)' : 'rgba(71, 85, 105, 0.85)',
    navHoverBg: isDark ? 'rgba(255, 255, 255, 0.05)' : 'rgba(79, 70, 229, 0.05)',
    navHoverText: isDark ? 'rgba(224, 231, 255, 0.9)' : '#4338CA',
    navIcon: isDark ? 'rgba(148, 163, 184, 0.6)' : 'rgba(100, 116, 139, 0.7)',
    navIconHover: isDark ? '#818CF8' : '#4F46E5',
    navActiveBg: isDark
      ? 'linear-gradient(135deg, rgba(79, 70, 229, 0.2) 0%, rgba(99, 102, 241, 0.12) 100%)'
      : 'linear-gradient(135deg, rgba(79, 70, 229, 0.1) 0%, rgba(99, 102, 241, 0.06) 100%)',
    navActiveText: isDark ? '#A5B4FC' : '#4338CA',
    navActiveShadow: isDark
      ? 'inset 0 0 0 1px rgba(99, 102, 241, 0.15)'
      : 'inset 0 0 0 1px rgba(79, 70, 229, 0.1)',

    divider: isDark ? 'rgba(255, 255, 255, 0.06)' : 'rgba(15, 23, 42, 0.06)',
    footerUserBg: isDark ? 'rgba(255, 255, 255, 0.035)' : 'rgba(15, 23, 42, 0.03)',
    footerUserBorder: isDark ? 'rgba(255, 255, 255, 0.05)' : 'rgba(15, 23, 42, 0.05)',
    userName: isDark ? '#E2E8F0' : '#0F172A',
    userRole: isDark ? 'rgba(148, 163, 184, 0.6)' : 'rgba(100, 116, 139, 0.7)',
    dropdownBg: isDark ? 'rgba(22, 30, 46, 0.98)' : 'rgba(255, 255, 255, 0.98)',
  }
})

function roleChipColor(role) {
  return (
    { admin: 'red-8', manager: 'deep-purple-8', inventory: 'green-8', finance: 'amber-9' }[role] ||
    'grey-7'
  )
}

function roleIcon(role) {
  return (
    {
      admin: 'shield',
      manager: 'supervisor_account',
      inventory: 'inventory_2',
      finance: 'account_balance',
    }[role] || 'person'
  )
}
</script>

<style scoped lang="scss">
// ═════════════════════════════════════════════
//   LAYOUT
// ═════════════════════════════════════════════
.erp-layout {
  background-color: var(--v-bg) !important;
}

// ═════════════════════════════════════════════
//   HEADER
// ═════════════════════════════════════════════
.erp-header {
  background: v-bind('themeStyles.headerBg') !important;
  backdrop-filter: blur(20px) saturate(180%);
  -webkit-backdrop-filter: blur(20px);
  border-bottom: 1px solid v-bind('themeStyles.headerBorder');
  box-shadow: v-bind('themeStyles.headerShadow');
  color: v-bind('themeStyles.headerText') !important;
}

.erp-toolbar {
  min-height: 60px;
  padding: 0 20px;
}

.menu-toggle-btn,
.header-action-btn {
  color: v-bind('themeStyles.headerAction') !important;
  transition: color 0.15s ease;
  &:hover {
    color: var(--v-primary) !important;
  }
}

// ═════════════════════════════════════════════
//   SIDEBAR SHELL
// ═════════════════════════════════════════════
.erp-sidebar {
  background: v-bind('themeStyles.sidebarBg') !important;
  border-right: 1px solid v-bind('themeStyles.sidebarBorder') !important;
  box-shadow: v-bind('themeStyles.sidebarShadow');
}

.sidebar-inner {
  display: flex;
  flex-direction: column;
  height: 100%;
}

// ═════════════════════════════════════════════
//   BRAND BLOCK
// ═════════════════════════════════════════════
.sidebar-brand {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 20px 16px 18px;
  margin: 8px 10px 0;
  border-radius: 14px;
  background: v-bind('themeStyles.brandBg');
  border: 1px solid v-bind('themeStyles.brandBorder');
  flex-shrink: 0;
}

.brand-logo-wrap {
  width: 40px;
  height: 40px;
  border-radius: 11px;
  background: linear-gradient(145deg, #4f46e5 0%, #7c3aed 100%);
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow:
    0 4px 14px rgba(79, 70, 229, 0.38),
    inset 0 1px 0 rgba(255, 255, 255, 0.15);
  flex-shrink: 0;
  overflow: hidden;
  padding: 5px;
}

.brand-text {
  display: flex;
  flex-direction: column;
  gap: 1px;
}

.brand-name {
  font-size: 11.5px;
  font-weight: 800;
  letter-spacing: 1.2px;
  text-transform: uppercase;
  color: v-bind('themeStyles.brandName');
  line-height: 1.2;
}

.brand-sub {
  font-size: 10px;
  font-weight: 500;
  color: v-bind('themeStyles.brandSub');
  letter-spacing: 0.2px;
}

// ═════════════════════════════════════════════
//   SCROLL AREA
// ═════════════════════════════════════════════
.sidebar-scroll-area {
  flex: 1;
  min-height: 0;
  height: 100%;
}

// ═════════════════════════════════════════════
//   NAV WRAPPER
// ═════════════════════════════════════════════
.sidebar-nav {
  padding: 8px 0 16px;
}

// ═════════════════════════════════════════════
//   NAV ITEMS — BASE
// ═════════════════════════════════════════════
.nav-item {
  display: flex;
  align-items: center;
  gap: 0;
  margin: 1px 10px;
  padding: 0 !important;
  min-height: 42px;
  border-radius: 10px;
  cursor: pointer;
  text-decoration: none;
  color: v-bind('themeStyles.navItemText');
  transition:
    background 0.18s cubic-bezier(0.4, 0, 0.2, 1),
    color 0.18s cubic-bezier(0.4, 0, 0.2, 1),
    box-shadow 0.18s ease;
  position: relative;
  overflow: hidden;
  user-select: none;

  &:hover {
    background: v-bind('themeStyles.navHoverBg') !important;
    color: v-bind('themeStyles.navHoverText');

    .nav-icon {
      color: v-bind('themeStyles.navIconHover');
    }
  }
}

// ── Active state ──────────────────────────────
.nav-item--active {
  background: v-bind('themeStyles.navActiveBg') !important;
  color: v-bind('themeStyles.navActiveText') !important;
  font-weight: 600;
  box-shadow: v-bind('themeStyles.navActiveShadow');

  .nav-icon {
    color: v-bind('themeStyles.navIconHover') !important;
  }

  // Left accent bar
  &::before {
    content: '';
    position: absolute;
    left: 0;
    top: 7px;
    bottom: 7px;
    width: 3px;
    border-radius: 0 3px 3px 0;
    background: linear-gradient(180deg, #6366f1 0%, #8b5cf6 100%);
    box-shadow: 0 0 8px rgba(99, 102, 241, 0.5);
  }
}

// ═════════════════════════════════════════════
//   ICON CELL  (fixed 48px width → perfect alignment)
// ═════════════════════════════════════════════
.nav-icon-cell {
  width: 48px;
  height: 42px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;

  &.nav-icon-cell--sub {
    width: 36px;
    height: 36px;
  }
}

.nav-icon {
  transition: color 0.18s ease;
  color: v-bind('themeStyles.navIcon');
}

// ═════════════════════════════════════════════
//   LABELS
// ═════════════════════════════════════════════
.nav-label {
  flex: 1;
  font-size: 13.5px;
  font-weight: 500;
  letter-spacing: 0.05px;
  line-height: 1;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  padding-right: 8px;

  &.nav-label--sub {
    font-size: 13px;
    opacity: 0.85;
  }
}

// ═════════════════════════════════════════════
//   CHEVRON
// ═════════════════════════════════════════════
.nav-chevron {
  width: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.chevron-icon {
  color: v-bind('themeStyles.navIcon');
  transition:
    transform 0.22s cubic-bezier(0.4, 0, 0.2, 1),
    color 0.18s ease;
}

.chevron-open {
  transform: rotate(90deg) !important;
  color: var(--v-primary) !important;
}

// Group header hover — highlight chevron too
.nav-item--group:hover .chevron-icon {
  color: v-bind('themeStyles.navIconHover');
}

// When group open, tint the header
.nav-item--group-open {
  color: v-bind('themeStyles.navActiveText') !important;
  background: v-bind('themeStyles.navHoverBg') !important;
  font-weight: 600;

  .nav-icon {
    color: v-bind('themeStyles.navIconHover') !important;
  }
}

// ═════════════════════════════════════════════
//   SUBMENU
// ═════════════════════════════════════════════
.nav-submenu {
  padding-bottom: 4px;
}

.nav-item--sub {
  margin: 1px 10px 1px 14px !important;
  min-height: 38px;
  border-radius: 8px !important;
}

// Indent decoration for sub items
.nav-sub-indent {
  width: 20px;
  display: flex;
  align-items: center;
  justify-content: flex-end;
  padding-right: 4px;
  flex-shrink: 0;
}

.nav-sub-dot {
  width: 5px;
  height: 5px;
  border-radius: 50%;
  background: v-bind('themeStyles.divider');
  transition:
    background 0.18s ease,
    box-shadow 0.18s ease;
}

.nav-item--sub.nav-item--active .nav-sub-dot {
  background: #6366f1;
  box-shadow: 0 0 6px rgba(99, 102, 241, 0.5);
}

// ─── Slide transition for submenus ────────────────────────────────────────────
.nav-slide-enter-active {
  transition: all 0.22s cubic-bezier(0.4, 0, 0.2, 1);
  overflow: hidden;
}
.nav-slide-leave-active {
  transition: all 0.18s cubic-bezier(0.4, 0, 1, 1);
  overflow: hidden;
}
.nav-slide-enter-from,
.nav-slide-leave-to {
  opacity: 0;
  max-height: 0;
  transform: translateY(-4px);
}
.nav-slide-enter-to,
.nav-slide-leave-from {
  opacity: 1;
  max-height: 400px;
  transform: translateY(0);
}

// ═════════════════════════════════════════════
//   SIDEBAR FOOTER
// ═════════════════════════════════════════════
.sidebar-footer {
  padding: 0 10px 12px;
  flex-shrink: 0;
}

.sidebar-divider {
  height: 1px;
  background: v-bind('themeStyles.divider');
  margin-bottom: 10px;
}

.sidebar-user {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 12px;
  border-radius: 12px;
  background: v-bind('themeStyles.footerUserBg');
  border: 1px solid v-bind('themeStyles.footerUserBorder');
  transition: background 0.18s ease;
  cursor: default;

  &:hover {
    background: v-bind('themeStyles.footerUserBg');
    filter: brightness(1.05);
  }
}

.user-avatar {
  width: 34px !important;
  height: 34px !important;
  border-radius: 9px !important;
  background: linear-gradient(135deg, #4f46e5, #7c3aed) !important;
  color: #fff !important;
  font-size: 14px;
  font-weight: 700;
  flex-shrink: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 2px 8px rgba(79, 70, 229, 0.35);
}

.user-info {
  flex: 1;
  min-width: 0;
}

.user-name {
  font-size: 12.5px;
  font-weight: 600;
  color: v-bind('themeStyles.userName');
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  line-height: 1.3;
}

.user-role {
  font-size: 10.5px;
  color: v-bind('themeStyles.userRole');
  text-transform: capitalize;
  line-height: 1.3;
}

.user-status-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: #22c55e;
  box-shadow: 0 0 8px rgba(34, 197, 94, 0.5);
  flex-shrink: 0;
}

// ═════════════════════════════════════════════
//   SECTION LABEL GLOBAL OVERRIDE
// ═════════════════════════════════════════════
:deep(.q-item__label--header) {
  padding: 20px 16px 8px;
  font-size: 9.5px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 1.4px;
  opacity: 0.4;
  color: v-bind('themeStyles.sectionLabel');
}

// ═════════════════════════════════════════════
//   HEADER AVATAR & STATUS
// ═════════════════════════════════════════════
.header-avatar {
  border: 1px solid v-bind('themeStyles.headerBorder');
  transition: transform 0.2s ease;
  position: relative;
  &:hover {
    transform: scale(1.05);
  }
}

.status-indicator {
  position: absolute;
  bottom: 0;
  right: 0;
  width: 10px;
  height: 10px;
  background: #22c55e;
  border: 2px solid v-bind('themeStyles.sidebarBg');
  border-radius: 50%;
  box-shadow: 0 0 8px rgba(34, 197, 94, 0.4);
}

// ═════════════════════════════════════════════
//   PROFILE DROPDOWN
// ═════════════════════════════════════════════
.profile-dropdown-menu {
  border-radius: 16px !important;
  border: 1px solid v-bind('themeStyles.headerBorder') !important;
  box-shadow: 0 16px 48px -8px rgba(0, 0, 0, 0.25) !important;
  background: v-bind('themeStyles.dropdownBg') !important;
  backdrop-filter: blur(16px) !important;
}

.dropdown-content {
  min-width: 300px;
}

.user-profile-header {
  .profile-name {
    color: v-bind('themeStyles.userName');
    font-size: 16px;
    letter-spacing: -0.2px;
  }
  .profile-email {
    font-size: 13px;
    opacity: 0.7;
  }
}

.avatar-glow {
  position: relative;
  &::before {
    content: '';
    position: absolute;
    top: -4px;
    left: -4px;
    right: -4px;
    bottom: -4px;
    border-radius: 50%;
    background: linear-gradient(135deg, rgba(79, 70, 229, 0.2), rgba(139, 92, 246, 0.2));
    z-index: -1;
    animation: pulse-glow 3s infinite;
  }
}

@keyframes pulse-glow {
  0% {
    transform: scale(1);
    opacity: 0.5;
  }
  50% {
    transform: scale(1.08);
    opacity: 0.8;
  }
  100% {
    transform: scale(1);
    opacity: 0.5;
  }
}

.role-pill {
  padding: 4px 10px;
  border-radius: 100px;
  font-size: 10px;
  font-weight: 800;
  text-transform: uppercase;
  letter-spacing: 0.6px;
  border-width: 1px;
  border-style: solid;

  &.admin-pill {
    background: rgba(239, 68, 68, 0.08) !important;
    color: #ef4444 !important;
    border-color: rgba(239, 68, 68, 0.2) !important;
    box-shadow: 0 2px 6px rgba(239, 68, 68, 0.1);
  }
  &.standard-pill {
    background: rgba(79, 70, 229, 0.08) !important;
    color: #6366f1 !important;
    border-color: rgba(79, 70, 229, 0.2) !important;
  }
}

.menu-list {
  padding: 8px !important;

  .menu-item {
    border-radius: 10px;
    margin: 2px 0;
    transition: all 0.15s cubic-bezier(0.4, 0, 0.2, 1);
    min-height: 46px;
    color: v-bind('themeStyles.navItemText');

    .menu-icon {
      opacity: 0.7;
      transition: all 0.15s ease;
    }
    .menu-label {
      font-size: 14px;
      font-weight: 500;
      letter-spacing: 0.1px;
    }

    &:hover {
      background: v-bind('themeStyles.navHoverBg') !important;
      color: var(--v-primary);
      .menu-icon {
        opacity: 1;
        color: var(--v-primary);
        transform: translateX(1px);
      }
      .chevron-icon {
        transform: translateX(2px);
        opacity: 1;
      }
    }
  }

  .logout-item:hover {
    background: rgba(239, 68, 68, 0.06) !important;
    .logout-icon,
    .logout-label {
      color: #ef4444 !important;
    }
  }
}

.divider {
  opacity: v-bind("$q.dark.isActive ? '0.08' : '0.06'");
}

.lh-1 {
  line-height: 1.2;
}
</style>
