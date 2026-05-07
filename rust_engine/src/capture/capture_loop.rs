use std::thread;
use std::time::{Duration, SystemTime, UNIX_EPOCH, Instant};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Mutex;
use std::os::raw::c_char;
use std::ffi::CStr;
use std::process::{Command, Stdio};

use allo_isolate::{Isolate, IntoDart};

use dxgi_capture_rs::DXGIManager;

static mut PORT: i64 = 0;
static RUNNING: AtomicBool = AtomicBool::new(false);
static SAVE_DIR: Mutex<Option<String>> = Mutex::new(None);

// ----------------------
// GLOBAL FFmpeg STATE
// ----------------------
static mut ENCODER: Option<std::process::Child> = None;
static mut FFMPEG_STDIN: Option<std::process::ChildStdin> = None;
static mut DXGI: Option<DXGIManager> = None;
static mut CAPTURE_THREAD: Option<std::thread::JoinHandle<()>> = None;
// ----------------------
// FLUTTER BRIDGE
// ----------------------
#[no_mangle]
pub extern "C" fn register_send_port(port: i64) {
    unsafe {
        PORT = port;
    }
}

#[no_mangle]
pub extern "C" fn set_save_directory(dir: *const c_char) {
    if dir.is_null() {
        return;
    }

    let c_str = unsafe { CStr::from_ptr(dir) };
    if let Ok(s) = c_str.to_str() {
        let mut lock = SAVE_DIR.lock().unwrap();
        *lock = Some(s.to_string());
    }
}

// ----------------------
// START / STOP
// ----------------------
#[no_mangle]
pub extern "C" fn start_capture() {
    if RUNNING.load(Ordering::Relaxed) {
        return;
    }

    RUNNING.store(true, Ordering::Relaxed);

    thread::spawn(|| {
        println!("Initializing DXGI...");

        unsafe {
            DXGI = Some(
                DXGIManager::new(16)
                    .expect("Failed to init DXGI")
            );
        }

        println!("Waiting 2 seconds before capture...");
        thread::sleep(Duration::from_secs(2));

        capture_loop();
    });
}

#[no_mangle]
pub extern "C" fn stop_capture() {
    RUNNING.store(false, Ordering::Relaxed);

    // 🔥 wait for capture loop to fully exit
    unsafe {
        if let Some(handle) = CAPTURE_THREAD.take() {
            let _ = handle.join();
        }
    }

    unsafe {
        // 🔥 release DXGI AFTER loop stops
        DXGI = None;

        // close FFmpeg stdin
        if let Some(stdin) = FFMPEG_STDIN.take() {
            drop(stdin);
        }

        // wait for ffmpeg to finalize
        if let Some(mut encoder) = ENCODER.take() {
            let _ = encoder.wait();
        }
    }

    println!("Capture stopped + video finalized");
}

// ----------------------
// FFmpeg START
// ----------------------
fn start_encoder(width: usize, height: usize, output_path: &str) {
    unsafe {
        let mut child = Command::new("ffmpeg")
        .args([
            "-y",

            // INPUT (unchanged)
            "-f", "rawvideo",
            "-pix_fmt", "bgra",
            "-s", &format!("{}x{}", width, height),
            "-i", "-",
            

            // FILTERS
            "-vf", "setpts=0.1*PTS,scale=1280:-1,fps=30",

            // ENCODER (GPU)
            "-c:v", "h264_nvenc",
            "-preset", "p5",              // better compression than p4
            "-cq", "30",                  // ⬅️ CRF-like quality control (key!)
            "-b:v", "0",                  // allow variable bitrate

            // OPTIONAL: better compression tuning
            "-g", "90",                   // keyframe every ~30s at 3fps

            // SEGMENTATION (critical for long sessions)
            "-f", "segment",
            "-segment_time", "900",       // 15 min chunks
            "-reset_timestamps", "1",
            "-vsync", "0",

            output_path,
        ])
        .stdin(Stdio::piped())
        .spawn()
        .expect("failed to start ffmpeg");

        FFMPEG_STDIN = child.stdin.take();
        ENCODER = Some(child);
    }
}

// ----------------------
// MAIN LOOP
// ----------------------
fn capture_loop() {
    let mut id: i64 = 0;
    let mut encoder_started = false;

    while RUNNING.load(Ordering::Relaxed) {
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_millis() as i64;

        let dxgi = unsafe { DXGI.as_mut().unwrap() };

        let result = dxgi.capture_frame_components();

        let (frame, (w, h)) = match result {
            Ok(v) => v,
            Err(_) => continue,
        };

        // ----------------------
        // START ENCODER ON FIRST FRAME
        // ----------------------
        if !encoder_started {
            let dir = {
                let lock = SAVE_DIR.lock().unwrap();
                lock.clone().unwrap_or_else(|| "captures".to_string())
            };

            std::fs::create_dir_all(&dir).unwrap();

            let session_id = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();

            let session_dir = format!("{}/session_{}", dir, session_id);
            std::fs::create_dir_all(&session_dir).unwrap();

            let output_path = format!("{}/clip_%03d.mp4", session_dir);

            start_encoder(w, h, &output_path);

            encoder_started = true;
            println!("FFmpeg started: {}", output_path);
        }

        // ----------------------
        // WRITE FRAME TO FFMPEG
        // ----------------------
        unsafe {
            if let Some(stdin) = FFMPEG_STDIN.as_mut() {
                use std::io::Write;
                let bytes: &[u8] = bytemuck::cast_slice(&frame);
                let _ = stdin.write_all(bytes);
            }
        }

        // ----------------------
        // SEND TO FLUTTER (optional metadata)
        // ----------------------
        unsafe {
            let isolate = Isolate::new(PORT);

            isolate.post(vec![
                id.into_dart(),
                now.into_dart(),
                "frame".into_dart(),
            ]);
        }

        id += 1;
    }

    println!("Capture loop exited");
}