use serde::{Deserialize, Serialize};
use sha3::{Digest, Keccak256};
use thiserror::Error;

#[derive(Error, Debug)]
pub enum TelemetryError {
    #[error("Out of order sequence: expected > {expected}, got {received}")]
    OutOfOrderSequence { expected: u64, received: u64 },

    #[error("Invalid signature: {0}")]
    InvalidSignature(String),

    #[error("Excursion processing error: {0}")]
    ExcursionError(String),
}

pub type Result<T> = std::result::Result<T, TelemetryError>;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SignedReading {
    pub shipment_id: String,
    pub device_address: String,
    pub sequence_number: u64,
    pub temperature_centi_celsius: i16, // e.g. 450 = 4.50°C
    pub humidity_percent: u8,
    pub timestamp_epoch_seconds: u64,
    pub signature_hex: String,
}

impl SignedReading {
    pub fn digest(&self) -> [u8; 32] {
        let mut hasher = Keccak256::new();
        hasher.update(self.shipment_id.as_bytes());
        hasher.update(self.device_address.as_bytes());
        hasher.update(&self.sequence_number.to_be_bytes());
        hasher.update(&self.temperature_centi_celsius.to_be_bytes());
        hasher.update(&[self.humidity_percent]);
        hasher.update(&self.timestamp_epoch_seconds.to_be_bytes());
        let res = hasher.finalize();
        let mut out = [0u8; 32];
        out.copy_from_slice(&res);
        out
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TemperaturePolicy {
    pub policy_id: String,
    pub min_temp: i16,
    pub max_temp: i16,
    pub max_continuous_excursion_seconds: u32,
    pub critical_spoilage_min: i16,
    pub critical_spoilage_max: i16,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExcursionReport {
    pub is_excursion: bool,
    pub start_timestamp: u64,
    pub end_timestamp: u64,
    pub duration_seconds: u32,
    pub min_recorded: i16,
    pub max_recorded: i16,
    pub critical_spoilage_detected: bool,
}

pub struct ExcursionDetector {
    pub policy: TemperaturePolicy,
    pub in_excursion: bool,
    pub excursion_start: u64,
    pub min_temp_seen: i16,
    pub max_temp_seen: i16,
}

impl ExcursionDetector {
    pub fn new(policy: TemperaturePolicy) -> Self {
        Self {
            policy,
            in_excursion: false,
            excursion_start: 0,
            min_temp_seen: i16::MAX,
            max_temp_seen: i16::MIN,
        }
    }

    pub fn process_reading(&mut self, reading: &SignedReading) -> Option<ExcursionReport> {
        let temp = reading.temperature_centi_celsius;
        let is_breach = temp < self.policy.min_temp || temp > self.policy.max_temp;
        let is_critical = temp <= self.policy.critical_spoilage_min || temp >= self.policy.critical_spoilage_max;

        if is_breach {
            if !self.in_excursion {
                self.in_excursion = true;
                self.excursion_start = reading.timestamp_epoch_seconds;
                self.min_temp_seen = temp;
                self.max_temp_seen = temp;
            } else {
                self.min_temp_seen = self.min_temp_seen.min(temp);
                self.max_temp_seen = self.max_temp_seen.max(temp);
            }

            let duration = (reading.timestamp_epoch_seconds.saturating_sub(self.excursion_start)) as u32;

            if duration > self.policy.max_continuous_excursion_seconds || is_critical {
                return Some(ExcursionReport {
                    is_excursion: true,
                    start_timestamp: self.excursion_start,
                    end_timestamp: reading.timestamp_epoch_seconds,
                    duration_seconds: duration,
                    min_recorded: self.min_temp_seen,
                    max_recorded: self.max_temp_seen,
                    critical_spoilage_detected: is_critical,
                });
            }
        } else if self.in_excursion {
            // Excursion ended
            let duration = (reading.timestamp_epoch_seconds.saturating_sub(self.excursion_start)) as u32;
            let report = if duration > self.policy.max_continuous_excursion_seconds {
                Some(ExcursionReport {
                    is_excursion: true,
                    start_timestamp: self.excursion_start,
                    end_timestamp: reading.timestamp_epoch_seconds,
                    duration_seconds: duration,
                    min_recorded: self.min_temp_seen,
                    max_recorded: self.max_temp_seen,
                    critical_spoilage_detected: false,
                })
            } else {
                None
            };

            self.in_excursion = false;
            self.min_temp_seen = i16::MAX;
            self.max_temp_seen = i16::MIN;
            return report;
        }

        None
    }
}

pub struct MerkleBatchTree;

impl MerkleBatchTree {
    pub fn compute_root(leaf_hashes: &[[u8; 32]]) -> [u8; 32] {
        if leaf_hashes.is_empty() {
            return [0u8; 32];
        }

        let mut current_layer: Vec<[u8; 32]> = leaf_hashes.to_vec();

        while current_layer.len() > 1 {
            let mut next_layer = Vec::new();
            for chunk in current_layer.chunks(2) {
                let mut hasher = Keccak256::new();
                if chunk.len() == 2 {
                    hasher.update(&chunk[0]);
                    hasher.update(&chunk[1]);
                } else {
                    hasher.update(&chunk[0]);
                    hasher.update(&chunk[0]); // Duplicate odd leaf
                }
                let res = hasher.finalize();
                let mut parent = [0u8; 32];
                parent.copy_from_slice(&res);
                next_layer.push(parent);
            }
            current_layer = next_layer;
        }

        current_layer[0]
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_excursion_detection() {
        let policy = TemperaturePolicy {
            policy_id: "VACCINE".into(),
            min_temp: 200, // 2.00°C
            max_temp: 800, // 8.00°C
            max_continuous_excursion_seconds: 600, // 10 min
            critical_spoilage_min: 0,
            critical_spoilage_max: 1500,
        };

        let mut detector = ExcursionDetector::new(policy);

        // Good reading
        let r1 = SignedReading {
            shipment_id: "SHIP-1".into(),
            device_address: "0x111".into(),
            sequence_number: 1,
            temperature_centi_celsius: 450,
            humidity_percent: 50,
            timestamp_epoch_seconds: 1000,
            signature_hex: "0x0".into(),
        };
        assert!(detector.process_reading(&r1).is_none());

        // Breach reading (10.00°C) starts at t=1030
        let r2 = SignedReading {
            sequence_number: 2,
            temperature_centi_celsius: 1000,
            timestamp_epoch_seconds: 1030,
            ..r1.clone()
        };
        // Within grace period (< 600s) -> no alert yet
        assert!(detector.process_reading(&r2).is_none());

        // Breach reading continues at t=1700 (duration = 670s > 600s) -> Excursion detected!
        let r3 = SignedReading {
            sequence_number: 3,
            temperature_centi_celsius: 1100,
            timestamp_epoch_seconds: 1700,
            ..r1.clone()
        };
        let alert = detector.process_reading(&r3).expect("Should detect excursion");
        assert!(alert.is_excursion);
        assert_eq!(alert.duration_seconds, 670);
    }
}
