"use client";

import React, { useState } from "react";

interface TelemetryPoint {
  time: string;
  temp: number; // in °C
  humidity: number; // in %
  isBreach: boolean;
}

export default function Home() {
  const [activeTab, setActiveTab] = useState<"monitor" | "escrow" | "simulator" | "custody">("monitor");

  // Shipment State
  const [shipmentId, setShipmentId] = useState<string>("0x8f2b79a1c0de4918204b7123fa98e0129bc48102");
  const [productCategory, setProductCategory] = useState<string>("COVID-19 mRNA Vaccine (Pfizer-BioNTech)");
  const [status, setStatus] = useState<"InTransit" | "Delivered" | "Settled">("InTransit");

  // Escrow State (in ETH or USDC)
  const [serviceFee] = useState<number>(2.5); // ETH payout to carrier
  const [penaltyReserve] = useState<number>(1.0); // ETH reserved for penalties
  const [settled, setSettled] = useState<boolean>(false);

  // Policy Limits
  const minSafeTemp = 2.0;
  const maxSafeTemp = 8.0;

  // Real-time telemetry history
  const [telemetry, setTelemetry] = useState<TelemetryPoint[]>([
    { time: "10:00", temp: 4.2, humidity: 48, isBreach: false },
    { time: "10:15", temp: 4.5, humidity: 49, isBreach: false },
    { time: "10:30", temp: 5.1, humidity: 50, isBreach: false },
    { time: "10:45", temp: 5.8, humidity: 52, isBreach: false },
    { time: "11:00", temp: 7.2, humidity: 55, isBreach: false },
    { time: "11:15", temp: 9.4, humidity: 58, isBreach: true },
    { time: "11:30", temp: 11.2, humidity: 62, isBreach: true },
    { time: "11:45", temp: 8.8, humidity: 59, isBreach: true },
    { time: "12:00", temp: 5.2, humidity: 51, isBreach: false }
  ]);

  // Current sensor reading
  const [currentTemp, setCurrentTemp] = useState<number>(5.2);
  const [currentHumidity, setCurrentHumidity] = useState<number>(51);
  const [totalExcursionMinutes, setTotalExcursionMinutes] = useState<number>(45);

  // Derived penalty
  const allowableGraceMinutes = 30;
  const chargeableExcursionMinutes = Math.max(0, totalExcursionMinutes - allowableGraceMinutes);
  const penaltyPerMinute = 0.02; // ETH
  const calculatedPenalty = Math.min(penaltyReserve, chargeableExcursionMinutes * penaltyPerMinute);
  const carrierPayout = serviceFee + (penaltyReserve - calculatedPenalty);
  const shipperRefund = calculatedPenalty;

  // Handlers for IoT Telemetry Simulation
  const handleInjectReading = (temp: number, humidity: number) => {
    setCurrentTemp(temp);
    setCurrentHumidity(humidity);

    const isBreach = temp < minSafeTemp || temp > maxSafeTemp;
    const now = new Date();
    const timeStr = `${now.getHours()}:${String(now.getMinutes()).padStart(2, "0")}`;

    setTelemetry([...telemetry, { time: timeStr, temp, humidity, isBreach }]);

    if (isBreach) {
      setTotalExcursionMinutes(prev => prev + 15);
    }
  };

  const handleSettle = () => {
    setSettled(true);
    setStatus("Settled");
    alert(`Settlement Executed!\nCarrier Payout: ${carrierPayout.toFixed(3)} ETH\nShipper Penalty Refund: ${shipperRefund.toFixed(3)} ETH`);
  };

  return (
    <div className="max-w-7xl mx-auto px-4 py-8">
      {/* Hero Header */}
      <div className="mb-8 p-6 rounded-2xl bg-gradient-to-r from-cyan-900/30 via-blue-900/20 to-slate-900 border border-cyan-500/20 shadow-xl">
        <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
          <div>
            <h1 className="text-3xl font-extrabold text-white tracking-tight">Cold-Chain Monitoring & Escrow DApp</h1>
            <p className="text-slate-400 mt-1 text-sm">
              Authenticated IoT telemetry • On-chain Merkle batch attestations • Automated contractual penalty enforcement.
            </p>
          </div>
          <div className="flex items-center gap-3">
            <span className="inline-flex items-center px-3 py-1 rounded-full text-xs font-semibold bg-cyan-500/10 text-cyan-400 border border-cyan-500/20">
              <span className="w-2 h-2 rounded-full bg-cyan-400 mr-2 animate-pulse"></span>
              ESP32 Device #DS18B20 Online
            </span>
          </div>
        </div>
      </div>

      {/* Navigation Tabs */}
      <div className="flex flex-wrap gap-2 mb-8 border-b border-slate-800 pb-4">
        {[
          { key: "monitor", label: "Live Telemetry & Excursion Timeline" },
          { key: "escrow", label: "Smart Contract Escrow & Settlement" },
          { key: "simulator", label: "IoT Edge Sensor Simulator" },
          { key: "custody", label: "Chain of Custody & Handover" }
        ].map(tab => (
          <button
            key={tab.key}
            onClick={() => setActiveTab(tab.key as any)}
            className={`px-4 py-2 rounded-xl text-sm font-semibold transition-all ${
              activeTab === tab.key
                ? "bg-cyan-600 text-white shadow-lg shadow-cyan-500/20"
                : "bg-slate-900/60 text-slate-400 hover:text-white hover:bg-slate-800 border border-slate-800"
            }`}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {/* TAB 1: MONITOR */}
      {activeTab === "monitor" && (
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          <div className="lg:col-span-1 space-y-6">
            <div className="p-6 rounded-2xl bg-slate-900 border border-slate-800 shadow-sm">
              <h2 className="text-lg font-bold text-white mb-4">Active Shipment Status</h2>
              <div className="space-y-3 text-xs text-slate-400">
                <div className="flex justify-between">
                  <span>Shipment ID:</span>
                  <span className="font-mono text-cyan-400">{shipmentId.slice(0, 14)}...</span>
                </div>
                <div className="flex justify-between">
                  <span>Cargo:</span>
                  <span className="font-semibold text-slate-200">{productCategory}</span>
                </div>
                <div className="flex justify-between">
                  <span>Lifecycle:</span>
                  <span className="px-2 py-0.5 rounded-full bg-emerald-500/10 text-emerald-400 font-semibold border border-emerald-500/20">
                    {status}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span>Target Range:</span>
                  <span className="font-mono text-cyan-300 font-bold">{minSafeTemp.toFixed(1)}°C — {maxSafeTemp.toFixed(1)}°C</span>
                </div>
                <div className="flex justify-between">
                  <span>Current Temp:</span>
                  <span className={`text-base font-black font-mono ${currentTemp < minSafeTemp || currentTemp > maxSafeTemp ? "text-rose-400" : "text-emerald-400"}`}>
                    {currentTemp.toFixed(1)}°C
                  </span>
                </div>
              </div>
            </div>

            <div className="p-6 rounded-2xl bg-slate-900 border border-slate-800 shadow-sm space-y-3">
              <h2 className="text-lg font-bold text-white">Excursion Audit Metric</h2>
              <div className="p-4 bg-slate-950 rounded-xl border border-slate-800 space-y-2 text-xs">
                <div className="flex justify-between">
                  <span className="text-slate-400">Total Breach Duration:</span>
                  <span className="font-mono text-rose-400 font-bold">{totalExcursionMinutes} Minutes</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-slate-400">Allowable Grace:</span>
                  <span className="font-mono text-slate-200">{allowableGraceMinutes} Minutes</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-slate-400">Chargeable Overrun:</span>
                  <span className="font-mono text-amber-400 font-bold">{chargeableExcursionMinutes} Minutes</span>
                </div>
                <div className="flex justify-between pt-2 border-t border-slate-800">
                  <span className="text-slate-400">Assessed Penalty:</span>
                  <span className="font-mono text-rose-400 font-bold">{calculatedPenalty.toFixed(3)} ETH</span>
                </div>
              </div>
            </div>
          </div>

          <div className="lg:col-span-2 space-y-6">
            <div className="p-6 rounded-2xl bg-slate-900 border border-slate-800 shadow-sm">
              <div className="flex justify-between items-center mb-6">
                <div>
                  <h2 className="text-xl font-bold text-white">Continuous Temperature Telemetry Log</h2>
                  <p className="text-xs text-slate-400">IoT samples cryptographically signed and batched into on-chain Merkle roots</p>
                </div>
                <span className="text-xs px-2.5 py-1 rounded-full bg-slate-800 text-slate-300 font-semibold font-mono">
                  {telemetry.length} Samples
                </span>
              </div>

              {/* Graphical Telemetry Timeline */}
              <div className="p-4 bg-slate-950 rounded-xl border border-slate-800 space-y-3 mb-6">
                <div className="flex justify-between text-xs text-slate-400 mb-1">
                  <span>Temperature Curve (°C)</span>
                  <span className="text-cyan-400">Safe Corridor: +2.0°C to +8.0°C</span>
                </div>
                <div className="h-40 flex items-end gap-2 pt-6 pb-2 border-b border-slate-800">
                  {telemetry.map((pt, idx) => {
                    const heightPercent = Math.min(100, Math.max(10, (pt.temp / 14) * 100));
                    return (
                      <div key={idx} className="flex-1 flex flex-col items-center gap-1 group relative">
                        <div
                          style={{ height: `${heightPercent}%` }}
                          className={`w-full rounded-t transition-all ${
                            pt.isBreach
                              ? "bg-rose-500 shadow-lg shadow-rose-500/20"
                              : "bg-cyan-500/80 hover:bg-cyan-400"
                          }`}
                        ></div>
                        <span className="text-[10px] text-slate-500 font-mono scale-90">{pt.time}</span>
                        {/* Tooltip */}
                        <div className="absolute bottom-16 hidden group-hover:block bg-slate-900 text-white text-[11px] font-mono px-2 py-1 rounded border border-slate-700 whitespace-nowrap z-10">
                          {pt.temp}°C ({pt.humidity}% RH) {pt.isBreach && "⚠️ EXCURSION"}
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>

              {/* Data Table */}
              <div className="overflow-x-auto">
                <table className="w-full text-left text-xs font-mono">
                  <thead>
                    <tr className="border-b border-slate-800 text-slate-400">
                      <th className="pb-2">Time</th>
                      <th className="pb-2">Temperature</th>
                      <th className="pb-2">Humidity</th>
                      <th className="pb-2">Status</th>
                      <th className="pb-2">Merkle Proof</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-800/40 text-slate-300">
                    {telemetry.slice(-5).reverse().map((t, idx) => (
                      <tr key={idx} className="py-2">
                        <td className="py-2.5 text-slate-400">{t.time}</td>
                        <td className={`py-2.5 font-bold ${t.isBreach ? "text-rose-400" : "text-emerald-400"}`}>
                          {t.temp.toFixed(1)}°C
                        </td>
                        <td className="py-2.5">{t.humidity}%</td>
                        <td className="py-2.5">
                          {t.isBreach ? (
                            <span className="px-2 py-0.5 rounded bg-rose-500/10 text-rose-400 border border-rose-500/20">
                              Excursion
                            </span>
                          ) : (
                            <span className="px-2 py-0.5 rounded bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
                              Compliant
                            </span>
                          )}
                        </td>
                        <td className="py-2.5 text-cyan-400 hover:underline cursor-pointer">
                          Verified (AttestationAnchor)
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* TAB 2: ESCROW */}
      {activeTab === "escrow" && (
        <div className="max-w-4xl mx-auto p-8 rounded-2xl bg-slate-900 border border-slate-800 shadow-xl space-y-6">
          <div>
            <h2 className="text-2xl font-bold text-white">Smart Contract Escrow & Automated Settlement</h2>
            <p className="text-sm text-slate-400 mt-1">
              Guarantees carrier payment upon compliance while protecting the shipper with automated penalty deductions.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div className="p-5 rounded-xl bg-slate-950 border border-slate-800">
              <span className="text-xs text-slate-400 uppercase tracking-wider block mb-1">Contracted Service Fee</span>
              <span className="text-2xl font-black text-white font-mono">{serviceFee.toFixed(2)} ETH</span>
              <span className="text-[11px] text-slate-500 block mt-1">Payable to Carrier</span>
            </div>

            <div className="p-5 rounded-xl bg-slate-950 border border-slate-800">
              <span className="text-xs text-slate-400 uppercase tracking-wider block mb-1">Penalty Reserve</span>
              <span className="text-2xl font-black text-cyan-400 font-mono">{penaltyReserve.toFixed(2)} ETH</span>
              <span className="text-[11px] text-slate-500 block mt-1">Reserved for Excursions</span>
            </div>

            <div className="p-5 rounded-xl bg-slate-950 border border-slate-800">
              <span className="text-xs text-slate-400 uppercase tracking-wider block mb-1">Assessed Penalty</span>
              <span className="text-2xl font-black text-rose-400 font-mono">{calculatedPenalty.toFixed(3)} ETH</span>
              <span className="text-[11px] text-slate-500 block mt-1">{chargeableExcursionMinutes} min breach</span>
            </div>
          </div>

          <div className="p-6 rounded-xl bg-slate-950 border border-slate-800 space-y-4">
            <h3 className="text-base font-bold text-white">Automated Settlement Breakdown</h3>
            <div className="space-y-2 text-sm font-mono">
              <div className="flex justify-between p-3 bg-slate-900 rounded-lg">
                <span className="text-slate-400">Carrier Payout (Service Fee + Remaining Reserve):</span>
                <span className="text-emerald-400 font-bold">{carrierPayout.toFixed(3)} ETH</span>
              </div>
              <div className="flex justify-between p-3 bg-slate-900 rounded-lg">
                <span className="text-slate-400">Shipper Refund (Compensatory Excursion Deduction):</span>
                <span className="text-cyan-400 font-bold">{shipperRefund.toFixed(3)} ETH</span>
              </div>
            </div>

            <button
              onClick={handleSettle}
              disabled={settled}
              className="w-full py-3.5 rounded-xl bg-cyan-600 hover:bg-cyan-500 disabled:opacity-50 text-white font-bold text-sm shadow-lg shadow-cyan-500/20 transition-all"
            >
              {settled ? "Shipment Settled (Funds Disbursed)" : "Trigger Automated Settlement (SettlementManager.sol)"}
            </button>
          </div>
        </div>
      )}

      {/* TAB 3: SIMULATOR */}
      {activeTab === "simulator" && (
        <div className="max-w-3xl mx-auto p-8 rounded-2xl bg-slate-900 border border-slate-800 shadow-xl space-y-6">
          <div>
            <h2 className="text-2xl font-bold text-white">IoT Edge Sensor Telemetry Simulator</h2>
            <p className="text-sm text-slate-400 mt-1">
              Simulates live ESP32 microcontroller with DS18B20 digital sensor transmitting signed MQTT telemetry.
            </p>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <button
              onClick={() => handleInjectReading(4.5, 49)}
              className="p-5 rounded-xl bg-slate-950 hover:bg-slate-800 border border-slate-800 text-left transition-all group"
            >
              <span className="text-xs font-semibold text-emerald-400 block mb-1">Inject Normal Reading</span>
              <span className="text-xl font-bold text-white font-mono group-hover:text-cyan-400">+4.5°C</span>
              <p className="text-[11px] text-slate-500 mt-2">Compliant vaccine storage temperature.</p>
            </button>

            <button
              onClick={() => handleInjectReading(11.8, 64)}
              className="p-5 rounded-xl bg-slate-950 hover:bg-slate-800 border border-slate-800 text-left transition-all group"
            >
              <span className="text-xs font-semibold text-rose-400 block mb-1">Simulate Heat Excursion</span>
              <span className="text-xl font-bold text-white font-mono group-hover:text-rose-400">+11.8°C</span>
              <p className="text-[11px] text-slate-500 mt-2">Refrigeration failure / compressor outage.</p>
            </button>

            <button
              onClick={() => handleInjectReading(-1.5, 42)}
              className="p-5 rounded-xl bg-slate-950 hover:bg-slate-800 border border-slate-800 text-left transition-all group"
            >
              <span className="text-xs font-semibold text-blue-400 block mb-1">Simulate Freezing Breach</span>
              <span className="text-xl font-bold text-white font-mono group-hover:text-blue-400">-1.5°C</span>
              <p className="text-[11px] text-slate-500 mt-2">Critical freezing destroys protein vaccines.</p>
            </button>
          </div>
        </div>
      )}

      {/* TAB 4: CUSTODY */}
      {activeTab === "custody" && (
        <div className="max-w-3xl mx-auto p-8 rounded-2xl bg-slate-900 border border-slate-800 shadow-xl space-y-6">
          <div>
            <h2 className="text-2xl font-bold text-white">Chain of Custody & Handover Events</h2>
            <p className="text-sm text-slate-400 mt-1">
              Verifiable transfer of custody with physical seal integrity and timestamping.
            </p>
          </div>

          <div className="space-y-4">
            {[
              { role: "Shipper / Manufacturer", name: "BioPharma Logistics Hub", location: "Cambridge, MA", time: "10:00 AM", status: "Handed Over" },
              { role: "Cold-Chain Logistics Carrier", name: "Apex TransCold Fleet #412", location: "I-95 North Transit", time: "10:30 AM", status: "In Transit" },
              { role: "Receiving Consignee", name: "Metro General Hospital Cold Storage", location: "Boston, MA", time: "Pending", status: "Awaiting Arrival" }
            ].map((c, idx) => (
              <div key={idx} className="p-4 bg-slate-950 rounded-xl border border-slate-800 flex justify-between items-center">
                <div>
                  <span className="text-xs text-cyan-400 font-bold uppercase tracking-wider block">{c.role}</span>
                  <span className="text-sm font-bold text-white">{c.name}</span>
                  <span className="text-xs text-slate-500 block mt-0.5">{c.location} • {c.time}</span>
                </div>
                <span className="text-xs px-2.5 py-1 rounded-full bg-slate-900 text-slate-300 border border-slate-700 font-semibold">
                  {c.status}
                </span>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
