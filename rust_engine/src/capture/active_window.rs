use windows::Win32::UI::WindowsAndMessaging::GetForegroundWindow;
use windows::Win32::Foundation::HWND;

pub fn get_active_window() -> Option<HWND> {
    unsafe {
        let hwnd = GetForegroundWindow();
        if hwnd.0.is_null() {
            None
        } else {
            Some(hwnd)
        }
    }
}