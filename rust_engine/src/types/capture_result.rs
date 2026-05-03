use std::os::raw::c_char;

#[repr(C)]
pub struct CaptureResult {
    pub status: i32,
    pub path: *mut c_char,
    pub window_title: *mut c_char,
    pub frame_hash: [u8; 32],
    pub prev_hash: [u8; 32],
}