use crate::capture::{
    active_window::get_active_window,
};

use win_screenshot::prelude::*;
use image::{RgbaImage, DynamicImage};
use std::ffi::CString;
use crate::capture::window::get_active_window_title;
use crate::types::capture_result::CaptureResult;
use crate::capture::hash::{compute_chain_hash, GENESIS_HASH};

pub struct SnapshotNative {
    pub frame_hash: [u8; 32],
    pub prev_hash: [u8; 32],
}

/// Call this from your capture pipeline
pub fn build_hash(frame_bytes: &[u8], prev_hash: Option<[u8; 32]>) -> SnapshotNative {
    let prev = prev_hash.unwrap_or(GENESIS_HASH);

    let hash = compute_chain_hash(frame_bytes, &prev);

    SnapshotNative {
        frame_hash: hash,
        prev_hash: prev,
    }
}

pub fn capture_window_primary(
    hwnd: windows::Win32::Foundation::HWND,
    path: &str,
    prev_hash: Option<[u8; 32]>,
) -> Result<SnapshotNative, String> {
    let buf = capture_window(hwnd.0 as isize)
        .map_err(|e| format!("window capture failed: {:?}", e))?;

    // 🔥 1. Extract raw frame bytes
    let frame_bytes = buf.pixels.clone();

    // 🔥 2. Compute hash chain
    let snapshot = build_hash(&frame_bytes, prev_hash);

    // 🔥 3. Save image
    save_buffer(buf, path)?;

    Ok(snapshot)
}

pub fn capture_active_window(
    path: &str,
    prev_hash: Option<[u8; 32]>,
) -> Result<SnapshotNative, String> {
    let hwnd = get_active_window()
        .ok_or("no active window")?;

    capture_window_primary(hwnd, path, prev_hash)
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


pub fn build_result(status: i32, path: &str,snapshot: SnapshotNative,) -> CaptureResult {
    let window_title = get_active_window_title()
        .unwrap_or("unknown".to_string());

    CaptureResult {
        status,
        path: CString::new(path).unwrap().into_raw(),
        window_title: CString::new(window_title).unwrap().into_raw(),
        frame_hash: snapshot.frame_hash,
        prev_hash: snapshot.prev_hash,
    }
}

