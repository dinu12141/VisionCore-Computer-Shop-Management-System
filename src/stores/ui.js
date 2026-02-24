import { defineStore } from 'pinia'

export const useUIStore = defineStore('ui', {
  state: () => ({
    darkMode: true, // Default to dark mode
    sidebarOpen: true,
    sidebarCollapsed: false,
    loading: false,
    notifications: {
      enabled: true,
      sound: true,
    },
  }),

  actions: {
    toggleDarkMode() {
      this.darkMode = !this.darkMode
    },

    toggleSidebar() {
      this.sidebarOpen = !this.sidebarOpen
    },

    collapseSidebar(collapsed) {
      this.sidebarCollapsed = collapsed
    },

    setLoading(loading) {
      this.loading = loading
    },

    updateNotificationPreferences(preferences) {
      this.notifications = { ...this.notifications, ...preferences }
    },
  },

  getters: {
    isDarkMode: (state) => state.darkMode,
    isSidebarOpen: (state) => state.sidebarOpen,
    isSidebarCollapsed: (state) => state.sidebarCollapsed,
    isLoading: (state) => state.loading,
  },
})
