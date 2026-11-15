export interface SignedReading {
  shipment_id: string;
  device_address: string;
  sequence_number: number;
  temperature_centi_celsius: number; // e.g. 450 = 4.50°C
  humidity_percent: number;
  timestamp_epoch_seconds: number;
  signature_hex: string;
}

export interface TemperaturePolicy {
  policy_id: string;
  policy_name: string;
  min_temp: number;
  max_temp: number;
  max_continuous_excursion_seconds: number;
  max_cumulative_excursion_seconds: number;
  critical_spoilage_min: number;
  critical_spoilage_max: number;
  penalty_per_second: string;
}

export interface ExcursionReport {
  is_excursion: boolean;
  start_timestamp: number;
  end_timestamp: number;
  duration_seconds: number;
  min_recorded: number;
  max_recorded: number;
  critical_spoilage_detected: boolean;
}

export interface ShipmentDetails {
  shipmentId: string;
  owner: string;
  carrier: string;
  receiver: string;
  assignedDevice: string;
  policyId: string;
  productCategory: string;
  originLocation: string;
  destinationLocation: string;
  status: "Created" | "EscrowFunded" | "InTransit" | "Delivered" | "Settled" | "Cancelled" | "Disputed";
  createdAt: number;
}
