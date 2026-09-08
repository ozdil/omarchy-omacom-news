use std::io::Read;
use std::os::unix::io::AsRawFd;
use std::os::unix::process::CommandExt;
use std::process::{Command, Stdio};
use std::time::{Duration, Instant};

#[repr(C)]
struct PollFd {
    fd: i32,
    events: i16,
    revents: i16,
}

const POLLIN: i16 = 0x0001;
const POLLHUP: i16 = 0x0010;
const POLLERR: i16 = 0x0008;

const F_GETFL: i32 = 3;
const F_SETFL: i32 = 4;
const O_NONBLOCK: i32 = 2048; // 0o4000 on Linux

extern "C" {
    fn poll(fds: *mut PollFd, nfds: usize, timeout: i32) -> i32;
    fn kill(pid: i32, sig: i32) -> i32;
    fn fcntl(fd: i32, cmd: i32, arg: i32) -> i32;
}

pub fn reap_process_group(child: &mut std::process::Child, pid: i32) {
    if pid > 1 {
        // SAFETY: kill(-pid, 15) sends SIGTERM to the process group with valid PID.
        unsafe {
            kill(-pid, 15);
        }
        std::thread::sleep(Duration::from_millis(5));
        // SAFETY: kill(-pid, 9) sends SIGKILL to the process group with valid PID to eliminate stubborn processes.
        unsafe {
            kill(-pid, 9);
        }
    }
    let _ = child.wait();
}

pub struct ProcessGroupGuard<'a> {
    pub child: &'a mut std::process::Child,
    pub pid: i32,
    pub active: bool,
}

impl<'a> Drop for ProcessGroupGuard<'a> {
    fn drop(&mut self) {
        if self.active {
            reap_process_group(self.child, self.pid);
        }
    }
}

pub fn run_cmd_bounded(
    cmd_path: &str,
    args: &[&str],
    extra_envs: &[(&str, &str)],
    deadline: Instant,
    max_output_bytes: usize,
) -> Option<Vec<u8>> {
    if Instant::now() >= deadline {
        return None;
    }

    let mut cmd = Command::new(cmd_path);
    cmd.args(args)
        .env_clear()
        .env("PATH", "/usr/bin:/bin")
        .env("LC_ALL", "C")
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::null());

    for (k, v) in extra_envs {
        cmd.env(k, v);
    }

    cmd.process_group(0);

    let mut child = cmd.spawn().ok()?;
    let pid = child.id() as i32;
    let mut stdout = child.stdout.take()?;
    let raw_fd = stdout.as_raw_fd();

    // SAFETY: F_GETFL and F_SETFL are standard POSIX fcntl operations on a valid pipe file descriptor.
    unsafe {
        let flags = fcntl(raw_fd, F_GETFL, 0);
        if flags >= 0 {
            let _ = fcntl(raw_fd, F_SETFL, flags | O_NONBLOCK);
        }
    }

    let mut guard = ProcessGroupGuard {
        child: &mut child,
        pid,
        active: true,
    };

    let mut buffer = Vec::new();
    let mut chunk = [0u8; 4096];
    let mut stdout_closed = false;
    let mut direct_child_exited = false;
    let mut direct_child_success = false;
    let mut overrun = false;
    let mut failed = false;

    loop {
        if Instant::now() >= deadline {
            break;
        }

        if !direct_child_exited {
            match guard.child.try_wait() {
                Ok(Some(status)) => {
                    direct_child_exited = true;
                    direct_child_success = status.success();
                }
                Ok(None) => {}
                Err(_) => {
                    failed = true;
                    break;
                }
            }
        }

        if stdout_closed {
            if direct_child_exited {
                break;
            }
            std::thread::sleep(Duration::from_millis(5));
            continue;
        }

        let remaining = deadline.saturating_duration_since(Instant::now());
        let wait_ms = (remaining.as_millis().min(50)) as i32;
        if wait_ms <= 0 {
            break;
        }

        let mut pfd = PollFd {
            fd: raw_fd,
            events: POLLIN | POLLHUP | POLLERR,
            revents: 0,
        };

        // SAFETY: poll with 1 descriptor, stack-allocated, valid timeout.
        let pret = unsafe { poll(&mut pfd, 1, wait_ms) };
        if pret < 0 {
            let err = std::io::Error::last_os_error();
            if err.kind() == std::io::ErrorKind::Interrupted {
                continue;
            }
            failed = true;
            break;
        }

        if pret > 0 {
            if pfd.revents & (POLLERR | POLLHUP) != 0 && (pfd.revents & POLLIN) == 0 {
                stdout_closed = true;
                continue;
            }

            loop {
                match stdout.read(&mut chunk) {
                    Ok(0) => {
                        stdout_closed = true;
                        break;
                    }
                    Ok(n) => {
                        if buffer.len().saturating_add(n) > max_output_bytes {
                            overrun = true;
                            break;
                        }
                        buffer.extend_from_slice(&chunk[..n]);
                    }
                    Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                        break;
                    }
                    Err(e) if e.kind() == std::io::ErrorKind::Interrupted => {
                        continue;
                    }
                    Err(_) => {
                        failed = true;
                        break;
                    }
                }
            }

            if overrun || failed {
                break;
            }
        }
    }

    if overrun || failed || Instant::now() >= deadline {
        return None;
    }

    if !direct_child_exited {
        match guard.child.try_wait() {
            Ok(Some(status)) => {
                direct_child_success = status.success();
            }
            _ => {
                return None;
            }
        }
    }

    guard.active = false;
    reap_process_group(guard.child, guard.pid);

    if direct_child_success {
        Some(buffer)
    } else {
        None
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_run_cmd_bounded_echo() {
        let deadline = Instant::now() + Duration::from_secs(2);
        let out = run_cmd_bounded("/bin/echo", &["hello_omarchy"], &[], deadline, 1024);
        assert!(out.is_some());
        let s = String::from_utf8_lossy(&out.unwrap()).to_string();
        assert!(s.contains("hello_omarchy"));
    }

    #[test]
    fn test_run_cmd_bounded_timeout() {
        let deadline = Instant::now() + Duration::from_millis(50);
        let out = run_cmd_bounded("/bin/sleep", &["1"], &[], deadline, 1024);
        assert!(out.is_none());
    }

    #[test]
    fn test_run_cmd_bounded_overrun() {
        let deadline = Instant::now() + Duration::from_secs(2);
        let out = run_cmd_bounded(
            "/bin/sh",
            &["-c", "for i in $(seq 1 50); do echo test_overrun_line; done"],
            &[],
            deadline,
            50,
        );
        assert!(out.is_none());
    }
}
