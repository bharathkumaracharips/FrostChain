use axum::{
    extract::{Path, State},
    http::StatusCode,
    response::IntoResponse,
    routing::{get, post},
    Json, Router,
};
use core_telemetry::{
    ExcursionDetector, ExcursionReport, MerkleBatchTree, SignedReading, TemperaturePolicy,
};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::collections::HashMap;
use std::net::SocketAddr;
use std::sync::Arc;
use tokio::sync::RwLock;
use tower_http::cors::CorsLayer;
use tracing::{info, warn, Level};
use tracing_subscriber::FmtSubscriber;

#[derive(Clone)]
struct AppState {
    readings: Arc<RwLock<HashMap<String, Vec<SignedReading>>>>,
    excursion_detectors: Arc<RwLock<HashMap<String, ExcursionDetector>>>,
    active_excursions: Arc<RwLock<HashMap<String, Vec<ExcursionReport>>>>,
}

#[tokio::main]
async fn main() {
    let subscriber = FmtSubscriber::builder()
        .with_max_level(Level::INFO)
        .finish();
    tracing::subscriber::set_global_default(subscriber).unwrap_or_default();

    let state = AppState {
        readings: Arc::new(RwLock::new(HashMap::new())),
        excursion_detectors: Arc::new(RwLock::new(HashMap::new())),
        active_excursions: Arc::new(RwLock::new(HashMap::new())),
    };

    let app = Router::new()
        .route("/health", get(health_check))
        .route("/api/v1/telemetry/ingest", post(ingest_telemetry))
        .route("/api/v1/shipments/:id/telemetry", get(get_shipment_telemetry))
        .route("/api/v1/shipments/:id/excursions", get(get_shipment_excursions))
        .route("/api/v1/attestations/anchor", post(anchor_batch))
        .layer(CorsLayer::permissive())
        .with_state(state);

    let port = std::env::var("PORT").unwrap_or_else(|_| "8082".to_string());
    let addr = SocketAddr::from(([0, 0, 0, 0], port.parse().unwrap_or(8082)));
    info!("Cold-Chain Monitoring Ingestion Server listening on {}", addr);

    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}

async fn health_check() -> impl IntoResponse {
    Json(json!({
        "status": "healthy",
        "service": "Cold-Chain IoT Telemetry & Excursion Monitor",
        "timestamp": chrono::Utc::now().to_rfc3339()
    }))
}

async fn ingest_telemetry(
    State(state): State<AppState>,
    Json(reading): Json<SignedReading>,
) -> impl IntoResponse {
    let shipment_id = reading.shipment_id.clone();

    // 1. Store reading
    {
        let mut map = state.readings.write().await;
        map.entry(shipment_id.clone()).or_default().push(reading.clone());
    }

    // 2. Ensure excursion detector exists for shipment
    {
        let mut detectors = state.excursion_detectors.write().await;
        if !detectors.contains_key(&shipment_id) {
            // Default vaccine policy 2.00°C - 8.00°C
            let default_policy = TemperaturePolicy {
                policy_id: "VACCINE_POLICY_DEFAULT".into(),
                min_temp: 200,
                max_temp: 800,
                max_continuous_excursion_seconds: 1800,
                critical_spoilage_min: 0,
                critical_spoilage_max: 1500,
            };
            detectors.insert(shipment_id.clone(), ExcursionDetector::new(default_policy));
        }

        if let Some(detector) = detectors.get_mut(&shipment_id) {
            if let Some(excursion) = detector.process_reading(&reading) {
                warn!(
                    "TEMPERATURE EXCURSION DETECTED for shipment {}: duration {}s, range {} to {}",
                    shipment_id, excursion.duration_seconds, excursion.min_recorded, excursion.max_recorded
                );
                let mut exc_map = state.active_excursions.write().await;
                exc_map.entry(shipment_id.clone()).or_default().push(excursion);
            }
        }
    }

    (
        StatusCode::OK,
        Json(json!({
            "status": "accepted",
            "shipmentId": shipment_id,
            "seqNo": reading.sequence_number,
            "timestamp": reading.timestamp_epoch_seconds
        })),
    )
}

async fn get_shipment_telemetry(
    Path(id): Path<String>,
    State(state): State<AppState>,
) -> impl IntoResponse {
    let map = state.readings.read().await;
    let list = map.get(&id).cloned().unwrap_or_default();

    Json(json!({
        "shipmentId": id,
        "readingCount": list.len(),
        "readings": list
    }))
}

async fn get_shipment_excursions(
    Path(id): Path<String>,
    State(state): State<AppState>,
) -> impl IntoResponse {
    let map = state.active_excursions.read().await;
    let list = map.get(&id).cloned().unwrap_or_default();

    Json(json!({
        "shipmentId": id,
        "excursionCount": list.len(),
        "excursions": list
    }))
}

#[derive(Debug, Deserialize)]
struct AnchorBatchRequest {
    shipment_id: String,
}

async fn anchor_batch(
    State(state): State<AppState>,
    Json(payload): Json<AnchorBatchRequest>,
) -> impl IntoResponse {
    let map = state.readings.read().await;
    let list = match map.get(&payload.shipment_id) {
        Some(l) if !l.is_empty() => l,
        _ => {
            return (
                StatusCode::BAD_REQUEST,
                Json(json!({"error": "No readings to anchor"})),
            )
        }
    };

    let digests: Vec<[u8; 32]> = list.iter().map(|r| r.digest()).collect();
    let root = MerkleBatchTree::compute_root(&digests);

    (
        StatusCode::OK,
        Json(json!({
            "shipmentId": payload.shipment_id,
            "merkleRoot": format!("0x{}", hex::encode(root)),
            "readingCount": list.len(),
            "startTimestamp": list.first().map(|r| r.timestamp_epoch_seconds).unwrap_or(0),
            "endTimestamp": list.last().map(|r| r.timestamp_epoch_seconds).unwrap_or(0),
            "ipfsReportCID": "ipfs://QmColdChainTelemetryBatchReportAnchor"
        })),
    )
}
