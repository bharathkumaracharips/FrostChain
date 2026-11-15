import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "ColdGuard | Decentralized Cold-Chain Monitoring & Escrow DApp",
  description: "Authenticated IoT Telemetry, Excursion Alerts, Merkle Attestation Anchoring, and Automated Contractual Escrow Settlement on EVM",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className="dark">
      <body className="bg-slate-950 text-slate-100 antialiased selection:bg-cyan-600 selection:text-white">
        <header className="border-b border-slate-800 bg-slate-900/60 backdrop-blur sticky top-0 z-50">
          <div className="max-w-7xl mx-auto px-4 h-16 flex items-center justify-between">
            <div className="flex items-center space-x-3">
              <div className="w-9 h-9 rounded-xl bg-gradient-to-tr from-cyan-500 to-blue-600 flex items-center justify-center text-white font-black text-lg shadow-lg shadow-cyan-500/20">
                CG
              </div>
              <div>
                <span className="font-bold text-lg text-white tracking-tight">ColdGuard DApp</span>
                <span className="ml-2 text-xs px-2 py-0.5 rounded-full bg-cyan-500/10 text-cyan-400 border border-cyan-500/20 font-mono">
                  IoT + Smart Escrow
                </span>
              </div>
            </div>
            <div className="flex items-center space-x-6 text-sm font-medium text-slate-300">
              <a href="#monitor" className="hover:text-cyan-400 transition-colors">Live Telemetry</a>
              <a href="#shipments" className="hover:text-cyan-400 transition-colors">Shipment Escrow</a>
              <a href="#excursions" className="hover:text-cyan-400 transition-colors">Penalties & Alerts</a>
              <a href="#custody" className="hover:text-cyan-400 transition-colors">Chain of Custody</a>
            </div>
          </div>
        </header>
        <main>{children}</main>
        <footer className="border-t border-slate-800/80 py-8 text-center text-xs text-slate-500">
          ColdGuard Cold-Chain Protocol • Authenticated ESP32 Sensors • Merkle Batch Anchoring • Automated Penalties
        </footer>
      </body>
    </html>
  );
}
