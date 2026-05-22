/// Choyce Engine Tauri 2 shell library entry-point.
///
/// Spawning the Godot sidecar and bridging the WebSocket envelopes
/// lives in follow-up PRs. This skeleton just registers the shell plugin
/// (needed for the `open external URL` use case down the road) and a
/// trivial smoke command so the frontend can prove the bridge is up.
#[tauri::command]
fn shell_smoke() -> &'static str {
    "choyce-shell ok"
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .invoke_handler(tauri::generate_handler![shell_smoke])
        .run(tauri::generate_context!())
        .expect("error while running choyce-shell Tauri application");
}
