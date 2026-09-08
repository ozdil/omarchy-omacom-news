use serde::{Deserialize, Serialize};
use std::env;
use std::fs::{self, OpenOptions};
use std::io::Write;
use std::os::unix::fs::{MetadataExt, OpenOptionsExt, PermissionsExt};
use std::path::PathBuf;

extern "C" {
    fn getuid() -> u32;
}

#[derive(Serialize, Deserialize, Default, Debug, Clone)]
pub struct SavedState {
    pub last_notified_id: String,
    pub read_ids: Vec<String>,
}

pub fn get_data_dir() -> PathBuf {
    let dir = if let Ok(home) = env::var("HOME") {
        PathBuf::from(home).join(".local/share/omarchy/omacom-news")
    } else {
        PathBuf::from("/tmp/omacom-news")
    };

    if !dir.exists() {
        let _ = fs::create_dir_all(&dir);
        let _ = fs::set_permissions(&dir, fs::Permissions::from_mode(0o700));
    }
    dir
}

pub fn load_state() -> SavedState {
    let path = get_data_dir().join("state.json");
    if let Ok(meta) = fs::symlink_metadata(&path) {
        // SAFETY: Reject symlinks, non-files, wrong owner UID, or insecure permissions
        if meta.file_type().is_symlink() || !meta.file_type().is_file() {
            return SavedState::default();
        }

        // SAFETY: Calling POSIX getuid()
        let current_uid = unsafe { getuid() };
        if meta.uid() != current_uid {
            return SavedState::default();
        }

        let mode = meta.mode() & 0o777;
        if mode != 0o600 {
            // Correct permissions if drifted
            let _ = fs::set_permissions(&path, fs::Permissions::from_mode(0o600));
        }

        if let Ok(content) = fs::read_to_string(&path) {
            if let Ok(s) = serde_json::from_str::<SavedState>(&content) {
                return s;
            }
        }
    }
    SavedState::default()
}

pub fn save_state(state: &SavedState) -> bool {
    let dir = get_data_dir();
    let target = dir.join("state.json");
    let tmp = dir.join(format!(".tmp_state_{}_{}", std::process::id(), std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_nanos()).unwrap_or(0)));

    let json = match serde_json::to_string_pretty(state) {
        Ok(j) => j,
        Err(_) => return false,
    };

    let mut file = match OpenOptions::new()
        .write(true)
        .create(true)
        .truncate(true)
        .mode(0o600)
        .open(&tmp)
    {
        Ok(f) => f,
        Err(_) => return false,
    };

    if file.write_all(json.as_bytes()).is_err() {
        let _ = fs::remove_file(&tmp);
        return false;
    }

    if file.sync_all().is_err() {
        let _ = fs::remove_file(&tmp);
        return false;
    }

    drop(file);

    if fs::rename(&tmp, &target).is_err() {
        let _ = fs::remove_file(&tmp);
        return false;
    }

    true
}

pub fn save_cache_file(name: &str, content: &str) {
    let dir = get_data_dir();
    let target = dir.join(name);
    let tmp = dir.join(format!(".tmp_cache_{}_{}", name, std::process::id()));

    if let Ok(mut file) = OpenOptions::new()
        .write(true)
        .create(true)
        .truncate(true)
        .mode(0o600)
        .open(&tmp)
    {
        if file.write_all(content.as_bytes()).is_ok() && file.sync_all().is_ok() {
            drop(file);
            let _ = fs::rename(&tmp, &target);
            return;
        }
        let _ = fs::remove_file(&tmp);
    }
}

pub fn load_cache_file(name: &str) -> Option<String> {
    let path = get_data_dir().join(name);
    if let Ok(meta) = fs::symlink_metadata(&path) {
        if meta.file_type().is_symlink() || !meta.file_type().is_file() {
            return None;
        }
        let current_uid = unsafe { getuid() };
        if meta.uid() != current_uid {
            return None;
        }
        return fs::read_to_string(&path).ok();
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_save_and_load_state() {
        let state = SavedState {
            last_notified_id: "test-id-123".to_string(),
            read_ids: vec!["id-1".to_string(), "id-2".to_string()],
        };
        assert!(save_state(&state));
        let loaded = load_state();
        assert_eq!(loaded.last_notified_id, "test-id-123");
        assert_eq!(loaded.read_ids.len(), 2);
    }

    #[test]
    fn test_cache_file_atomic() {
        let cache_name = "test_feed_cache.xml";
        let content = "<xml>test</xml>";
        save_cache_file(cache_name, content);
        let loaded = load_cache_file(cache_name);
        assert_eq!(loaded.as_deref(), Some(content));
        let _ = fs::remove_file(get_data_dir().join(cache_name));
    }
}
