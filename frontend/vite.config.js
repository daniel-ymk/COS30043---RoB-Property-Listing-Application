import { fileURLToPath, URL } from 'node:url'
import process from 'node:process'

import { defineConfig, loadEnv } from 'vite'
import vue from '@vitejs/plugin-vue'
import vueDevTools from 'vite-plugin-vue-devtools'

// https://vite.dev/config/
export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd())
  // Local PHP (XAMPP) serves the repo at http://localhost/rob/ (docs/api.md §1).
  const phpTarget = env.VITE_PHP_TARGET || 'http://localhost'

  return {
    // Mercury serves the app from a sub-folder, e.g. /~s1234567/rob/
    base: env.VITE_BASE || '/',
    plugins: [vue(), vueDevTools()],
    resolve: {
      alias: {
        '@': fileURLToPath(new URL('./src', import.meta.url)),
      },
    },
    server: {
      // Same-origin in dev, so the PHP session cookie just works
      proxy: {
        '/api': {
          target: phpTarget,
          changeOrigin: true,
          rewrite: (path) => path.replace(/^\/api/, '/rob/backend/api'),
        },
        '/backend': {
          target: phpTarget,
          changeOrigin: true,
          rewrite: (path) => path.replace(/^\/backend/, '/rob/backend'),
        },
      },
    },
  }
})
