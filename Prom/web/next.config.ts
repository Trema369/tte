import type { NextConfig } from "next";

// Where the Go backend lives. In `docker compose` the web container reaches it
// as http://server:8080; in local dev it's http://localhost:8080.
const SERVER_ORIGIN = process.env.SERVER_ORIGIN ?? "http://localhost:8080";

const nextConfig: NextConfig = {
  output: "standalone",
  poweredByHeader: false,
  async rewrites() {
    return [
      {
        source: "/api/:path*",
        destination: `${SERVER_ORIGIN}/api/:path*`,
      },
    ];
  },
};

export default nextConfig;
