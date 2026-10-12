import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "odin-gpu · WebGPU examples",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  // NOTE: id="body" is required. The framework measures the surface with
  // get_bounding_client_rect("body") (getElementById); a missing id yields a
  // 0x0 swapchain. Same for id="canvas" on example pages.
  return (
    <html lang="en" className="h-full">
      <body id="body" className="bg-page text-ink">
        {children}
      </body>
    </html>
  );
}
