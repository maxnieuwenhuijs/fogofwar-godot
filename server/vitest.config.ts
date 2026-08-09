import { defineConfig } from "vitest/config";

export default defineConfig({
  // Vite zoekt standaard omhoog naar een postcss-config en vindt dan een
  // verdwaalde uit een ANDER project in de thuismap. Dit is een backend
  // zonder css: expliciet lege postcss-config, zoeken uit.
  css: { postcss: {} },
  test: {
    // Integratietests delen een database: geen parallelle bestanden.
    fileParallelism: false,
    testTimeout: 30_000,
  },
});
