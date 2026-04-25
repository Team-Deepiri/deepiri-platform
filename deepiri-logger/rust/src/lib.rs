use serde::Serialize;

#[derive(Debug, Clone, Serialize)]
pub struct DeepiriLogEvent {
    pub timestamp: String,
    pub level: String,
    pub service_name: String,
    pub version: String,
    pub trace_id: String,
    pub message: String,
    pub context: serde_json::Value,
}

pub fn init(_service_name: &str, _version: &str) {
    let subscriber = tracing_subscriber::fmt()
        .json()
        .with_current_span(false)
        .with_span_list(false)
        .finish();

    let _ = tracing::subscriber::set_global_default(subscriber);
}
