<template>
  <div class="global-search-container">
    <!--
      Using v-model with a strictly local ref.
      Removed :loading to prevent focus issues caused by the inner spinner element.
    -->
    <q-input
      v-model="localQuery"
      dense
      standout
      placeholder="Search customers, invoices, items…"
      class="global-search-input"
      @update:model-value="onSearchUpdate"
      @keydown.down.prevent="onArrowDown"
      @keydown.up.prevent="onArrowUp"
      @keydown.enter.prevent="onEnter"
      @keydown.esc="closeMenu"
      @focus="onFocus"
      ref="searchInput"
    >
      <template v-slot:prepend>
        <q-icon name="search" size="20px" :color="localQuery ? 'primary' : 'grey-5'" />
      </template>

      <template v-slot:append>
        <q-icon
          v-if="localQuery"
          name="close"
          class="cursor-pointer"
          size="18px"
          @click="clearSearchInput"
        />
        <div v-else class="search-shortcut q-ml-sm gt-sm">
          <kbd class="kbd-key">/</kbd>
        </div>
      </template>

      <!-- ═════════════════════  SEARCH DROPDOWN  ═════════════════════ -->
      <q-menu
        v-model="showMenu"
        no-parent-event
        fit
        no-focus
        no-refocus
        max-height="520px"
        anchor="bottom left"
        self="top left"
        class="search-palette"
        transition-show="jump-down"
        transition-hide="jump-up"
        :offset="[0, 8]"
        @hide="onMenuHide"
      >
        <div class="palette-inner" style="min-width: 480px; max-width: 560px">
          <!-- ── Loading Skeleton ── -->
          <div v-if="loading" class="q-pa-md">
            <div v-for="n in 3" :key="n" class="skeleton-row">
              <q-skeleton type="QAvatar" size="36px" />
              <div class="skeleton-text">
                <q-skeleton type="text" width="55%" height="14px" />
                <q-skeleton type="text" width="75%" height="11px" class="q-mt-xs" />
              </div>
            </div>
          </div>

          <!-- ── Recent Searches (no results yet or empty input) ── -->
          <div v-else-if="!localQuery && recentSearches.length > 0" class="q-pa-sm">
            <div class="palette-section-header q-px-sm q-pb-xs row items-center justify-between">
              <span>Recent Searches</span>
              <q-btn
                flat
                dense
                no-caps
                label="Clear"
                size="xs"
                color="grey-5"
                @click="searchStore.clearRecentSearches()"
              />
            </div>
            <q-item
              v-for="term in recentSearches"
              :key="term"
              clickable
              dense
              class="recent-item"
              @click="useRecentSearch(term)"
            >
              <q-item-section avatar>
                <q-icon name="history" size="18px" color="grey-5" />
              </q-item-section>
              <q-item-section class="recent-label">{{ term }}</q-item-section>
              <q-item-section side>
                <q-icon name="north_west" size="14px" color="grey-4" />
              </q-item-section>
            </q-item>
          </div>

          <!-- ── Results ── -->
          <div v-else-if="results.length > 0" class="q-py-xs">
            <template v-for="(group, groupName) in groupedResults" :key="groupName">
              <div class="palette-section-header q-px-md q-pt-sm q-pb-xs row items-center">
                <q-icon
                  :name="getConfig(groupName).icon"
                  :color="getConfig(groupName).color"
                  size="16px"
                  class="q-mr-xs"
                />
                <span>{{ getConfig(groupName).label }}</span>
                <q-badge
                  :label="group.length"
                  color="grey-4"
                  text-color="grey-8"
                  class="q-ml-xs"
                  style="font-size: 10px; padding: 2px 6px"
                />
              </div>

              <q-item
                v-for="res in group"
                :key="res.entity_id"
                clickable
                v-close-popup
                @click="navigate(res)"
                @mouseenter="setSelectedByResult(res)"
                :active="isFlatSelected(res)"
                active-class="result-active"
                class="result-item q-mx-sm"
                :data-result-index="getFlatIndex(res)"
              >
                <q-item-section avatar>
                  <q-avatar
                    :color="getConfig(res.entity_type).bgColor"
                    :text-color="getConfig(res.entity_type).color"
                    size="36px"
                    class="result-avatar"
                  >
                    <q-icon :name="getConfig(res.entity_type).icon" size="20px" />
                  </q-avatar>
                </q-item-section>

                <q-item-section>
                  <q-item-label class="result-title">
                    <span v-html="highlightMatch(res.title)" />
                  </q-item-label>
                  <q-item-label caption class="result-subtitle">
                    <span v-html="highlightMatch(res.subtitle)" />
                  </q-item-label>
                </q-item-section>

                <q-item-section side>
                  <div class="result-action">
                    <q-badge
                      v-if="res.entity_type === 'invoice'"
                      :color="getInvoiceBadgeColor(res)"
                      :label="getInvoiceBadgeLabel(res)"
                      outline
                      class="result-badge"
                    />
                    <q-icon v-else name="chevron_right" size="18px" color="grey-4" />
                  </div>
                </q-item-section>
              </q-item>

              <q-separator
                v-if="shouldShowSeparator(groupName)"
                class="q-mx-md q-my-xs"
                style="opacity: 0.08"
              />
            </template>

            <!-- Footer -->
            <div class="palette-footer q-px-md q-py-sm row items-center justify-between">
              <span class="footer-meta">
                {{ totalResults }} result{{ totalResults !== 1 ? 's' : '' }}
                <span v-if="searchTime"> · {{ searchTime }}ms</span>
              </span>
              <q-btn
                flat
                dense
                no-caps
                label="View all results"
                icon-right="launch"
                size="sm"
                color="primary"
                @click="viewFullResults"
              />
            </div>
          </div>

          <!-- ── Empty State ── -->
          <div
            v-else-if="!loading && localQuery.length >= 2"
            class="empty-state q-pa-xl text-center"
          >
            <q-icon name="search_off" size="56px" color="grey-3" />
            <div class="text-subtitle1 text-grey-5 q-mt-md">No results found</div>
            <div class="text-caption text-grey-4 q-mt-xs">
              Try a different keyword or check your spelling
            </div>
          </div>
        </div>
      </q-menu>
    </q-input>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted, nextTick } from 'vue'
import { useRouter } from 'vue-router'
import { useGlobalSearchStore, ENTITY_CONFIG } from 'src/stores/globalSearch'
import { storeToRefs } from 'pinia'
import { debounce } from 'quasar'

const router = useRouter()
const searchStore = useGlobalSearchStore()

// ── LOCAL input state is King. It is never overwritten by store.
const localQuery = ref('')

// De-reference store states
const {
  loading,
  results,
  selectedIndex,
  groupedResults,
  totalResults,
  recentSearches,
  searchTime,
} = storeToRefs(searchStore)

const showMenu = ref(false)
const searchInput = ref(null)

const flatResults = computed(() => results.value)

function getConfig(type) {
  return ENTITY_CONFIG[type] || ENTITY_CONFIG.item
}

// ── Search Logic ──
const performSearchDebounced = debounce((val) => {
  const q = val.trim()
  if (q.length >= 2) {
    searchStore.performSearch(q)
    showMenu.value = true
  } else {
    // Too short, clear results but don't force close if we want to show recent searches
    results.value = []
    if (!q && recentSearches.value.length > 0) {
      showMenu.value = true
    } else if (q.length > 0) {
      showMenu.value = false
    }
  }
}, 350)

function onSearchUpdate(val) {
  // val is already set in localQuery via v-model
  performSearchDebounced(val)
}

function onFocus() {
  if (localQuery.value.length >= 2 && results.value.length > 0) {
    showMenu.value = true
  } else if (!localQuery.value && recentSearches.value.length > 0) {
    showMenu.value = true
  }
}

function clearSearchInput() {
  localQuery.value = ''
  results.value = []
  selectedIndex.value = -1
  showMenu.value = false
}

function closeMenu() {
  showMenu.value = false
}

function useRecentSearch(term) {
  localQuery.value = term
  searchStore.performSearch(term)
  showMenu.value = true
}

// ── Keyboard Navigation ──
function onArrowDown() {
  if (!showMenu.value && flatResults.value.length) {
    showMenu.value = true
    return
  }
  if (selectedIndex.value < flatResults.value.length - 1) {
    selectedIndex.value++
    scrollSelectedIntoView()
  }
}

function onArrowUp() {
  if (selectedIndex.value > -1) {
    selectedIndex.value--
    scrollSelectedIntoView()
  }
}

function onEnter() {
  if (selectedIndex.value >= 0 && selectedIndex.value < flatResults.value.length) {
    navigate(flatResults.value[selectedIndex.value])
  } else if (localQuery.value.length >= 2) {
    viewFullResults()
  }
}

function isFlatSelected(res) {
  return flatResults.value[selectedIndex.value]?.entity_id === res.entity_id
}

function setSelectedByResult(res) {
  const idx = flatResults.value.findIndex((r) => r.entity_id === res.entity_id)
  if (idx !== -1) selectedIndex.value = idx
}

function getFlatIndex(res) {
  return flatResults.value.findIndex((r) => r.entity_id === res.entity_id)
}

function scrollSelectedIntoView() {
  nextTick(() => {
    const el = document.querySelector(`[data-result-index="${selectedIndex.value}"]`)
    if (el) el.scrollIntoView({ block: 'nearest', behavior: 'smooth' })
  })
}

// ── Navigation ──
function navigate(res) {
  showMenu.value = false
  results.value = []
  selectedIndex.value = -1

  const config = ENTITY_CONFIG[res.entity_type]
  if (config) {
    router.push(config.route(res.entity_id))
  }
}

function viewFullResults() {
  showMenu.value = false
  router.push(`/search?q=${encodeURIComponent(localQuery.value)}`)
}

function onMenuHide() {
  selectedIndex.value = -1
}

// ── Helpers ──
function highlightMatch(text) {
  if (!text || !localQuery.value || localQuery.value.length < 2) return text || ''
  const q = localQuery.value.trim()
  const escaped = q.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
  const regex = new RegExp(`(${escaped})`, 'gi')
  return text.replace(regex, '<mark class="search-highlight">$1</mark>')
}

function getInvoiceBadgeColor(res) {
  const status = res.extra?.status || ''
  if (status === 'cancelled') return 'red-5'
  if (status === 'issued') return 'green-6'
  return 'orange-6'
}

function getInvoiceBadgeLabel(res) {
  return (res.extra?.status || 'draft').toUpperCase()
}

function shouldShowSeparator(groupName) {
  const keys = Object.keys(groupedResults.value)
  return keys.indexOf(groupName) < keys.length - 1
}

function handleGlobalKeydown(e) {
  if (
    e.key === '/' &&
    document.activeElement.tagName !== 'INPUT' &&
    document.activeElement.tagName !== 'TEXTAREA'
  ) {
    e.preventDefault()
    searchInput.value?.focus()
  }
}

onMounted(() => window.addEventListener('keydown', handleGlobalKeydown))
onUnmounted(() => window.removeEventListener('keydown', handleGlobalKeydown))
</script>

<style scoped lang="scss">
.global-search-container {
  max-width: 480px;
  width: 100%;
}

.global-search-input {
  transition: all 0.25s cubic-bezier(0.4, 0, 0.2, 1);

  :deep(.q-field__control) {
    border-radius: 12px;
    background: #f1f5f9;
    border: 1px solid rgba(15, 23, 42, 0.08);
    min-height: 40px;

    &:before,
    &:after {
      border: none !important;
    }
  }

  /* Theme Support locally instead of v-bind inside deep */
  :deep(.q-field__native) {
    font-size: 13.5px;
    font-weight: 500;
  }
}

/* Dark Mode Overrides */
:deep(.body--dark) .global-search-input {
  .q-field__control {
    background: rgba(255, 255, 255, 0.07) !important;
    border-color: rgba(255, 255, 255, 0.1);
  }
  &.q-field--focused .q-field__control {
    background: rgba(255, 255, 255, 0.1) !important;
  }
}

.kbd-key {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 22px;
  height: 22px;
  padding: 0 6px;
  border-radius: 5px;
  font-size: 11px;
  font-weight: 700;
  color: #64748b;
  background: rgba(15, 23, 42, 0.05);
  border: 1px solid rgba(15, 23, 42, 0.08);
}

.search-palette {
  border-radius: 16px !important;
  box-shadow: 0 24px 80px -12px rgba(0, 0, 0, 0.2) !important;
  background: rgba(255, 255, 255, 0.98) !important;
  backdrop-filter: blur(24px);
  overflow: hidden;
}

:deep(.body--dark) .search-palette {
  background: rgba(17, 24, 39, 0.97) !important;
}

.palette-section-header {
  font-size: 10px;
  font-weight: 700;
  text-transform: uppercase;
  color: #64748b;
  padding: 12px 16px 4px;
}

.result-item {
  border-radius: 10px;
  margin: 1px 6px;
  &:hover,
  &.result-active {
    background: rgba(79, 70, 229, 0.06) !important;
  }
}

:deep(.body--dark) .result-item:hover,
:deep(.body--dark) .result-item.result-active {
  background: rgba(99, 102, 241, 0.12) !important;
}

.result-title {
  font-size: 13.5px;
  font-weight: 600;
}
.result-subtitle {
  font-size: 12px;
  color: #64748b;
}

:deep(.search-highlight) {
  background: rgba(251, 191, 36, 0.35);
  color: #92400e;
  border-radius: 3px;
}

.skeleton-row {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 10px 8px;
}
.skeleton-text {
  flex: 1;
}
</style>
