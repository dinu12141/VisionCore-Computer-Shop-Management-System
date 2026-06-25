import { defineConfig } from 'vitest/config'
import { fileURLToPath } from 'node:url'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: ['src/__tests__/setup.ts'],
    include: ['src/__tests__/**/*.{test,spec}.{ts,js}'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'lcov'],
      include: ['src/services/**', 'src/stores/**', 'src/boot/**'],
    },
  },
  resolve: {
    alias: {
      src: fileURLToPath(new URL('./src', import.meta.url)),
      'src/boot/supabase': fileURLToPath(
        new URL('./src/__tests__/__mocks__/supabase.ts', import.meta.url),
      ),
    },
  },
})
