import { SignedReading, ExcursionReport } from "./types.js";

export class FrostChainClient {
  private baseUrl: string;

  constructor(baseUrl: string = "http://localhost:8082") {
    this.baseUrl = baseUrl;
  }

  public async ingestReading(reading: SignedReading): Promise<any> {
    const res = await fetch(`${this.baseUrl}/api/v1/telemetry/ingest`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(reading)
    });
    return res.json();
  }

  public async getTelemetry(shipmentId: string): Promise<{ readingCount: number; readings: SignedReading[] }> {
    const res = await fetch(`${this.baseUrl}/api/v1/shipments/${shipmentId}/telemetry`);
    return res.json();
  }

  public async getExcursions(shipmentId: string): Promise<{ excursionCount: number; excursions: ExcursionReport[] }> {
    const res = await fetch(`${this.baseUrl}/api/v1/shipments/${shipmentId}/excursions`);
    return res.json();
  }

  public static toCelsius(centiCelsius: number): number {
    return centiCelsius / 100;
  }

  public static toCentiCelsius(celsius: number): number {
    return Math.round(celsius * 100);
  }
}
