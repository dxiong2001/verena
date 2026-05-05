use std::thread;
use std::time::{Duration, SystemTime, UNIX_EPOCH};
use std::sync::atomic::{AtomicBool, Ordering};

use allo_isolate::{Isolate, IntoDart};
use image::{RgbaImage, DynamicImage};
use crate::capture::{
    active_window::get_active_window,
};
use std::time::Instant;

use win_screenshot::prelude::*;
use std::sync::Mutex;


static mut PORT: i64 = 0;
static RUNNING: AtomicBool = AtomicBool::new(false);
static SAVE_DIR: Mutex<Option<String>> = Mutex::new(None);

#[no_mangle]
pub extern "C" fn register_send_port(port: i64) {
    unsafe {
        PORT = port;
    }
}

// 🔥 pass directory from Flutter
#[no_mangle]
pub extern "C" fn set_save_directory(dir: *const std::os::raw::c_char) {
    if dir.is_null() {
        return;
    }

    let c_str = unsafe { std::ffi::CStr::from_ptr(dir) };
    let dir_str = match c_str.to_str() {
        Ok(s) => s.to_string(),
        Err(_) => return,
    };

    let mut lock = SAVE_DIR.lock().unwrap();
    *lock = Some(dir_str);
}

#[no_mangle]
pub extern "C" fn start_capture() {
    if RUNNING.load(Ordering::Relaxed) {
        return;
    }

    RUNNING.store(true, Ordering::Relaxed);

    thread::spawn(|| {
        // 🔥 delay BEFORE loop
        println!("Waiting 10 seconds before capture...");
        thread::sleep(Duration::from_secs(10));

        capture_loop();
    });
}

#[no_mangle]
pub extern "C" fn stop_capture() {
    RUNNING.store(false, Ordering::Relaxed);
}

fn capture_loop() {
    let mut id: i64 = 0;

    while RUNNING.load(Ordering::Relaxed) {
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_millis() as i64;

        let hwnd = match get_active_window() {
            Some(h) => h,
            None => {
                thread::sleep(Duration::from_millis(200));
                continue;
            }
        };
        let t0 = Instant::now();
        let buf = match capture_window(hwnd.0 as isize) {
            Ok(b) => b,
            Err(_) => {
                thread::sleep(Duration::from_millis(200));
                continue;
            }
        };
        println!("capture_window took: {:?}", t0.elapsed());
        // 🔥 get directory
        let dir = {
            let lock = SAVE_DIR.lock().unwrap();
            match &*lock {
                Some(d) => d.clone(),
                None => "captures".to_string(), // fallback
            }
        };

        let path = format!("{}/frame_{}.jpg", dir, id);

        // if save_buffer(buf, &path).is_err() {
        //     thread::sleep(Duration::from_millis(200));
        //     continue;
        // }

        unsafe {
            send_to_flutter(id, now, path);
        }

        id += 1;
        println!("Capture {}", id);
        // thread::sleep(Duration::from_millis(100));
    }

    println!("Capture stopped");
}

unsafe fn send_to_flutter(id: i64, timestamp: i64, path: String) {
    let isolate = Isolate::new(PORT);

    let msg = vec![
        id.into_dart(),
        timestamp.into_dart(),
        path.into_dart(),
    ];

    isolate.post(msg);
}


pub fn save_buffer(buf: win_screenshot::capture::RgbBuf, path: &str) -> Result<(), String> {
    let img = RgbaImage::from_raw(
        buf.width,
        buf.height,
        buf.pixels,
    ).ok_or("failed to build image")?;

    DynamicImage::ImageRgba8(img)
        .save(path)
        .map_err(|e| e.to_string())?;

    Ok(())
}
