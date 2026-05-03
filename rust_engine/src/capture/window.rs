use windows::Win32::UI::WindowsAndMessaging::{
    GetForegroundWindow, GetWindowTextW,
};

pub fn get_active_window_title() -> Option<String> {
    unsafe {
        let hwnd = GetForegroundWindow();
        if hwnd.0.is_null() {
            return None;
        }

         let mut bytes: [u16; 500] = [0; 500];
        let len = GetWindowTextW(hwnd, &mut bytes);
        let title = String::from_utf16_lossy(&bytes[..len as usize]);

        if len == 0 {
            return None;
        }

        Some(title)
    }
}