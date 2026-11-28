import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// Backend (Spring Boot gateway) is expected on :8080 during development.
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      "/api": "http://localhost:8080",
    },
    // Contract ABIs are imported from ../contracts/abi (single source of truth).
    fs: {
      allow: [".", "../contracts/abi"],
    },
  },
});
