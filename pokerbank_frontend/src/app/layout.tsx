import type { Metadata } from "next";
import localFont from "next/font/local";
import Nav from "./nav";
import "./globals.css";

const geistSans = localFont({
  src: "./fonts/GeistVF.woff",
  variable: "--font-geist-sans",
  weight: "100 900",
});

const geistMono = localFont({
  src: "./fonts/GeistMonoVF.woff",
  variable: "--font-geist-mono",
  // this doesn't work: https://github.com/vercel/next.js/issues/47814
  // declarations: [{ prop: "font-feature-settings", value: "ss09 1" }],
  weight: "100 900",
});

export const metadata: Metadata = {
  title: "Pokerbank",
  description: "ledger for home poker games",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body
        className={`${geistSans.variable} ${geistMono.variable} antialiased font-sans`}
      >
        <div className="max-w-2xl mx-auto">
          <Nav />
          {children}
        </div>
      </body>
    </html>
  );
}
