use std::os::raw::c_char;

#[repr(C)]
pub struct FrameEvent {
    pub id: u64,
    pub timestamp: u64,
    pub width: u32,
    pub height: u32,

    pub path: *mut c_char, // JPEG file path
}