import type { NextConfig } from "next";

// Static export so Tauri can bundle the built UI as plain files.
// `output: "export"` writes to ./out which src-tauri/tauri.conf.json points at.
const nextConfig: NextConfig = {
  output: "export",
  images: { unoptimized: true },
  trailingSlash: true,
  reactStrictMode: true,
};

export default nextConfig;
