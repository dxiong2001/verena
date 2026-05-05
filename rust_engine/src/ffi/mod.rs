use std::ffi::CStr;
use std::os::raw::c_char;
use std::ffi::CString;
use crate::capture::capture_engine::{capture_active_window, build_result};
use crate::types::capture_result::CaptureResult;


// #[no_mangle]
// pub extern "C" fn capture_active_window_ffi(path_ptr: *const c_char) -> i32 {
//     // 1. Null check (CRITICAL)
//     if path_ptr.is_null() {
//         return -1;
//     }

//     // 2. Safe string conversion (NO unwrap)
//     let path = unsafe {
//         match CStr::from_ptr(path_ptr).to_str() {
//             Ok(s) => s,
//             Err(_) => return -2,
//         }
//     };

//     // 3. Call engine safely
//     match capture_active_window(path) {
//         Ok(_) => 0,     // success
//         Err(_) => -3,   // capture failed
//     }
// }


#[no_mangle]
pub extern "C" fn capture_active_window_ffi(
    path_ptr: *const c_char,
    prev_hash_ptr: *const u8,
) -> CaptureResult {
    if path_ptr.is_null() || prev_hash_ptr.is_null() {
        return error_result(-1);
    }

    let path = unsafe {
        match CStr::from_ptr(path_ptr).to_str() {
            Ok(s) => s,
            Err(_) => return error_result(-2),
        }
    };

    let prev_hash: [u8; 32] = unsafe {
        let mut arr = [0u8; 32];
        std::ptr::copy_nonoverlapping(prev_hash_ptr, arr.as_mut_ptr(), 32);
        arr
    };

    match capture_active_window(path, ) {
        Ok(()) => build_result(0),
        Err(_) => error_result(-3),
    }
}

#[no_mangle]
pub extern "C" fn free_string(ptr: *mut c_char) {
    if ptr.is_null() {
        return;
    }

    unsafe {
        let _ = CString::from_raw(ptr);
    }
}

pub fn error_result(code: i32) -> CaptureResult {
    CaptureResult {
        status: code,


    }
}