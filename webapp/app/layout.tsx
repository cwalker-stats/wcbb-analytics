import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "WCBB Analytics",
  description: "Women's College Basketball Team Statistics",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}