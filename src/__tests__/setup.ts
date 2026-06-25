import { vi, beforeEach } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'

// Fresh Pinia for every test
beforeEach(() => {
  setActivePinia(createPinia())
  vi.clearAllMocks()
})
