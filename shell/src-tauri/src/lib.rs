/// Choyce Engine Tauri 2 shell library entry-point.
///
/// Spawning the Godot sidecar and bridging the WebSocket envelopes.

use std::sync::Mutex;
use tauri::{State, Manager};
use tauri_plugin_shell::ShellExt;
use tauri_plugin_shell::process::{CommandEvent, CommandChild};
use std::process::{Child, Command, Stdio};
use std::io::{BufRead, BufReader};
use std::time::Duration;

enum ChildProcess {
    Sidecar(CommandChild),
    System(Child),
}

impl ChildProcess {
    fn kill(self) -> std::io::Result<()> {
        match self {
            ChildProcess::Sidecar(c) => c.kill().map_err(|e| std::io::Error::new(std::io::ErrorKind::Other, e.to_string())),
            ChildProcess::System(mut c) => c.kill(),
        }
    }
}

struct EngineManager {
    process: ChildProcess,
    port: u16,
    auth_token: String,
}

pub struct EngineState {
    manager: Mutex<Option<EngineManager>>,
}

#[derive(serde::Serialize, Clone)]
struct LaunchInfo {
    port: u16,
    auth_token: String,
}

#[tauri::command]
fn shell_smoke() -> &'static str {
    "choyce-shell ok"
}

#[tauri::command]
fn start_engine(app_handle: tauri::AppHandle, state: State<'_, EngineState>) -> Result<LaunchInfo, String> {
    let mut lock = state.manager.lock().unwrap();
    
    // If already running, return existing info
    if let Some(ref manager) = *lock {
        return Ok(LaunchInfo {
            port: manager.port,
            auth_token: manager.auth_token.clone(),
        });
    }

    // Try to spawn sidecar first
    let spawned = if let Ok(sidecar_cmd) = app_handle.shell().sidecar("play-engine") {
        let sidecar_cmd = sidecar_cmd.env("CHOYCE_SHELL_BRIDGE", "1");
        match sidecar_cmd.spawn() {
            Ok((mut rx, child)) => {
                // Read stdout via channel to find token
                let (tx, result_rx) = std::sync::mpsc::channel();
                std::thread::spawn(move || {
                    while let Some(event) = rx.blocking_recv() {
                        match event {
                            CommandEvent::Stdout(bytes) => {
                                if let Ok(line) = String::from_utf8(bytes) {
                                    if line.contains("[shell_bridge] auth_token=") {
                                        if let Some(token_part) = line.split("auth_token=").nth(1) {
                                            let parts: Vec<&str> = token_part.split(" port=").collect();
                                            if parts.len() == 2 {
                                                let token = parts[0].to_string();
                                                if let Ok(port) = parts[1].trim().parse::<u16>() {
                                                    let _ = tx.send(Ok(LaunchInfo { port, auth_token: token }));
                                                    return;
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            CommandEvent::Error(err) => {
                                let _ = tx.send(Err(err));
                                return;
                            }
                            CommandEvent::Terminated(_) => {
                                let _ = tx.send(Err("Process terminated".to_string()));
                                return;
                            }
                            _ => {}
                        }
                    }
                    let _ = tx.send(Err("Stream closed".to_string()));
                });

                match result_rx.recv_timeout(Duration::from_secs(5)) {
                    Ok(Ok(info)) => {
                        Ok(EngineManager {
                            process: ChildProcess::Sidecar(child),
                            port: info.port,
                            auth_token: info.auth_token,
                        })
                    }
                    Ok(Err(e)) => {
                        let _ = child.kill();
                        Err(e)
                    }
                    Err(_) => {
                        let _ = child.kill();
                        Err("Timed out waiting for sidecar bridge signature".to_string())
                    }
                }
            }
            Err(e) => Err(e.to_string()),
        }
    } else {
        Err("Sidecar not configured".to_string())
    };

    // If sidecar failed, try fallback to system godot4 / godot
    let manager = match spawned {
        Ok(mgr) => mgr,
        Err(_) => {
            // Try "godot4"
            let mut cmd = Command::new("godot4");
            cmd.arg("--path").arg("../");
            cmd.env("CHOYCE_SHELL_BRIDGE", "1");
            cmd.stdout(Stdio::piped());
            cmd.stderr(Stdio::inherit());

            let mut child = cmd.spawn()
                .or_else(|_| {
                    // Try fallback to "godot"
                    let mut fallback = Command::new("godot");
                    fallback.arg("--path").arg("../");
                    fallback.env("CHOYCE_SHELL_BRIDGE", "1");
                    fallback.stdout(Stdio::piped());
                    fallback.stderr(Stdio::inherit());
                    fallback.spawn()
                })
                .map_err(|e| format!("Failed to start system Godot fallback: {}", e))?;

            let stdout = child.stdout.take().ok_or("Failed to capture stdout of Godot process")?;
            let (tx, result_rx) = std::sync::mpsc::channel();
            std::thread::spawn(move || {
                let reader = BufReader::new(stdout);
                for line in reader.lines() {
                    if let Ok(l) = line {
                        if l.contains("[shell_bridge] auth_token=") {
                            if let Some(token_part) = l.split("auth_token=").nth(1) {
                                let parts: Vec<&str> = token_part.split(" port=").collect();
                                if parts.len() == 2 {
                                    let token = parts[0].to_string();
                                    if let Ok(port) = parts[1].trim().parse::<u16>() {
                                        let _ = tx.send(Ok(LaunchInfo { port, auth_token: token }));
                                        return;
                                    }
                                }
                            }
                        }
                    } else {
                        break;
                    }
                }
                let _ = tx.send(Err("EOF or read error".to_string()));
            });

            match result_rx.recv_timeout(Duration::from_secs(5)) {
                Ok(Ok(info)) => {
                    EngineManager {
                        process: ChildProcess::System(child),
                        port: info.port,
                        auth_token: info.auth_token,
                    }
                }
                Ok(Err(e)) => {
                    let _ = child.kill();
                    return Err(format!("System Godot fallback error: {}", e));
                }
                Err(_) => {
                    let _ = child.kill();
                    return Err("Timed out waiting for system Godot bridge signature".to_string());
                }
            }
        }
    };

    let info = LaunchInfo {
        port: manager.port,
        auth_token: manager.auth_token.clone(),
    };
    *lock = Some(manager);
    Ok(info)
}

#[tauri::command]
fn stop_engine(state: State<'_, EngineState>) -> Result<(), String> {
    let mut lock = state.manager.lock().unwrap();
    if let Some(manager) = lock.take() {
        let _ = manager.process.kill();
    }
    Ok(())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .manage(EngineState { manager: Mutex::new(None) })
        .invoke_handler(tauri::generate_handler![shell_smoke, start_engine, stop_engine])
        .build(tauri::generate_context!())
        .expect("error while building choyce-shell Tauri application")
        .run(|app_handle, event| {
            if let tauri::RunEvent::Exit = event {
                if let Some(state) = app_handle.try_state::<EngineState>() {
                    let mut lock = state.manager.lock().unwrap();
                    if let Some(manager) = lock.take() {
                        let _ = manager.process.kill();
                    }
                }
            }
        });
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_launch_info_serialization() {
        let info = LaunchInfo { port: 9876, auth_token: "abc".to_string() };
        let json = serde_json::to_string(&info).unwrap();
        assert_eq!(json, "{\"port\":9876,\"auth_token\":\"abc\"}");
    }
}

