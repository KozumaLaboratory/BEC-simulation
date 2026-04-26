import { defineConfig } from 'vite'
import { fileURLToPath, URL } from 'node:url'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

const API_TARGET = process.env.VITE_API_TARGET ?? 'http://localhost:8080'

export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
  server: {
    port: 5173,
    proxy: {
      '/api': { target: API_TARGET, changeOrigin: true },
    },
  },
  build: {
    // Manual chunking — keep the initial paint chunk small by pushing
    // anything heavy or tab-specific into its own lazy chunk. The 3D
    // viewer and the syntax highlighter together are 10 MB+ but neither
    // is needed for first paint of the run list / overview.
    rollupOptions: {
      output: {
        manualChunks(id) {
          if (!id.includes('node_modules')) return
          if (id.includes('three')) return 'three'
          if (id.includes('@react-three')) return 'r3f'
          if (id.includes('shiki') || id.includes('react-syntax-highlighter')) return 'syntax'
          // Group the Radix UI primitives together — they're a fair chunk
          // of weight (~80 KB minified) and only the components mounted
          // for the current tab actually pull from them at runtime.
          if (id.includes('@radix-ui')) return 'radix'
          // Lucide icons tree-shake to per-icon imports, but the whole
          // package still touches React lazy paths; keep it isolated.
          if (id.includes('lucide-react')) return 'lucide'
          // nuqs (URL state) + zustand are tiny; group them so they
          // don't bloat the React vendor chunk implicitly.
          if (id.includes('nuqs') || id.includes('zustand')) return 'state'
        },
      },
    },
    chunkSizeWarningLimit: 800,
  },
})
