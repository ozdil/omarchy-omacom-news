mod feed;
mod state;
mod subproc;

use feed::{get_default_articles, parse_atom_releases, parse_rss, Article};
use serde::{Deserialize, Serialize};
use state::{load_cache_file, load_state, save_cache_file, save_state};
use std::collections::HashSet;
use std::env;
use std::time::{Duration, Instant};
use subproc::run_cmd_bounded;

#[derive(Serialize, Deserialize, Debug)]
pub struct NewsState {
    pub status: String,
    pub total: usize,
    pub unread: usize,
    pub installed_version: String,
    pub latest_release: String,
    pub is_system_updated: bool,
    pub latest_title: String,
    pub latest_date: String,
    pub articles: Vec<Article>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct StatusOutput {
    pub text: String,
    pub tooltip: String,
    pub class: String,
}

pub fn get_installed_omarchy_version() -> String {
    let deadline = Instant::now() + Duration::from_millis(500);
    if let Some(out) = run_cmd_bounded("/usr/bin/pacman", &["-Q", "omarchy"], &[], deadline, 4096) {
        let text = String::from_utf8_lossy(&out);
        if let Some(ver) = text.split_whitespace().nth(1) {
            return ver.to_string();
        }
    }
    "4.0.3-1".to_string()
}

pub fn fetch_feed_bounded(url: &str, cache_name: &str) -> Option<String> {
    let deadline = Instant::now() + Duration::from_secs(3);
    let output = run_cmd_bounded(
        "/usr/bin/curl",
        &[
            "-sL",
            "--max-time",
            "3",
            "-A",
            "OmaNews/1.2.0 (Omarchy Linux)",
            url,
        ],
        &[],
        deadline,
        1_048_576, // 1 MiB cap
    );

    if let Some(bytes) = output {
        if !bytes.is_empty() {
            let text = String::from_utf8_lossy(&bytes).to_string();
            if text.contains("<rss") || text.contains("<feed") || text.contains("<entry") || text.contains("<item") {
                save_cache_file(cache_name, &text);
                return Some(text);
            }
        }
    }

    load_cache_file(cache_name)
}

pub fn get_all_articles() -> (Vec<Article>, String, String, bool) {
    let mut all_articles = Vec::new();

    // 1. Fetch and parse Omarchy releases Atom feed
    let releases_xml = fetch_feed_bounded(
        "https://github.com/omacom/omarchy/releases.atom",
        "releases.atom.cache",
    );
    if let Some(xml) = releases_xml {
        let parsed = parse_atom_releases(&xml);
        all_articles.extend(parsed);
    }

    // 2. Fetch and parse Omarchy official News RSS feed
    let news_xml = fetch_feed_bounded(
        "https://omarchy.org/news/rss.xml",
        "news.rss.cache",
    );
    if let Some(xml) = news_xml {
        let parsed = parse_rss(&xml);
        all_articles.extend(parsed);
    }

    // Fallback to built-in default articles if network and cache are unavailable
    if all_articles.is_empty() {
        all_articles = get_default_articles();
    }

    // Deduplicate by ID
    let mut seen_ids = HashSet::new();
    let mut deduped = Vec::new();
    for a in all_articles {
        if !seen_ids.contains(&a.id) {
            seen_ids.insert(a.id.clone());
            deduped.push(a);
        }
    }

    // Sort by date descending (newest first)
    deduped.sort_by(|a, b| b.date.cmp(&a.date));

    // Determine installed version and latest release version
    let installed_ver = get_installed_omarchy_version();
    let mut latest_release = "v4.0.3".to_string();
    for a in &deduped {
        if a.category == "Release" {
            if let Some(tag) = a.title.split(':').next() {
                let clean_tag = tag.trim();
                if clean_tag.starts_with('v') {
                    latest_release = clean_tag.to_string();
                    break;
                }
            }
        }
    }

    let is_updated = installed_ver.starts_with(&latest_release.trim_start_matches('v')[..3]);

    // Apply read state
    let state = load_state();
    let read_set: HashSet<String> = state.read_ids.into_iter().collect();
    for a in &mut deduped {
        if read_set.contains(&a.id) {
            a.is_read = true;
        }
    }

    (deduped, installed_ver, latest_release, is_updated)
}

pub fn send_desktop_notification(article: &Article) {
    let prefix = match article.category.as_str() {
        "Release" => "OMARCHY SÜRÜM GÜNCELLEMESİ",
        "Foundation" => "OMACOM VAKFI DUYURUSU",
        "Distro" => "OMARCHY SİSTEM DUYURUSU",
        "Community" => "OMARCHY TOPLULUK",
        "Ecosystem" => "OMARCHY EKOSİSTEM",
        _ => "OMANEWS HABER",
    };

    let summary = format!("{}: {}", prefix, article.title);
    let body = format!("{} • {}\n{}", article.date, article.author, article.excerpt);

    let deadline = Instant::now() + Duration::from_secs(2);
    let _ = run_cmd_bounded(
        "/usr/bin/notify-send",
        &[
            "--app-name=OmaNews",
            "--urgency=normal",
            &summary,
            &body,
        ],
        &[],
        deadline,
        1024,
    );
}

pub fn check_and_notify_latest(articles: &[Article]) {
    if let Some(latest) = articles.first() {
        let mut state = load_state();
        if state.last_notified_id != latest.id {
            send_desktop_notification(latest);
            state.last_notified_id = latest.id.clone();
            let _ = save_state(&state);
        }
    }
}

fn main() {
    let args: Vec<String> = env::args().collect();
    let (articles, installed_version, latest_release, is_system_updated) = get_all_articles();

    if args.iter().any(|a| a == "--check-notify") {
        check_and_notify_latest(&articles);
        println!("Notification check complete.");
        return;
    }

    if args.iter().any(|a| a == "--notify") {
        let target = if let Some(idx) = args.iter().position(|a| a == "--notify") {
            if idx + 1 < args.len() {
                articles.iter().find(|a| a.id == args[idx + 1])
            } else {
                articles.first()
            }
        } else {
            articles.first()
        };

        if let Some(art) = target {
            send_desktop_notification(art);
            let mut state = load_state();
            state.last_notified_id = art.id.clone();
            let _ = save_state(&state);
            println!("Notification dispatched for: {}", art.title);
        }
        return;
    }

    if args.iter().any(|a| a == "--read") {
        if let Some(idx) = args.iter().position(|a| a == "--read") {
            if idx + 1 < args.len() {
                let target_url = &args[idx + 1];
                let _ = std::process::Command::new("/usr/bin/xdg-open")
                    .arg(target_url)
                    .spawn();
            }
        }
        return;
    }

    if args.iter().any(|a| a == "--mark-read-single") {
        if let Some(idx) = args.iter().position(|a| a == "--mark-read-single") {
            if idx + 1 < args.len() {
                let target_id = &args[idx + 1];
                let mut state = load_state();
                if !state.read_ids.contains(target_id) {
                    state.read_ids.push(target_id.clone());
                    let _ = save_state(&state);
                }
            }
        }
        return;
    }

    if args.iter().any(|a| a == "--mark-read") {
        let mut state = load_state();
        for a in &articles {
            if !state.read_ids.contains(&a.id) {
                state.read_ids.push(a.id.clone());
            }
        }
        let _ = save_state(&state);
        println!("All articles and updates marked as read.");
        return;
    }

    let unread = articles.iter().filter(|a| !a.is_read).count();
    let total = articles.len();
    let latest_title = articles.first().map(|a| a.title.clone()).unwrap_or_default();
    let latest_date = articles.first().map(|a| a.date.clone()).unwrap_or_default();

    if args.iter().any(|a| a == "--status") {
        let text = if unread > 0 {
            format!("OMANEWS: {} NEW", unread)
        } else {
            format!("OMANEWS: {}", latest_release)
        };

        let tooltip = format!(
            "OmaNews Hub\nOmarchy Sürümü: {}\nSon Sürüm: {}\nSon Haber: {}\nTarih: {}\nOkunmamış: {}\nMotor: Güvenli Native Rust",
            installed_version, latest_release, latest_title, latest_date, unread
        );

        let out = StatusOutput {
            text,
            tooltip,
            class: if unread > 0 { "active".to_string() } else { "normal".to_string() },
        };
        println!("{}", serde_json::to_string(&out).unwrap());
        return;
    }

    if args.iter().any(|a| a == "--json") {
        let state = NewsState {
            status: "OK".to_string(),
            total,
            unread,
            installed_version,
            latest_release,
            is_system_updated,
            latest_title,
            latest_date,
            articles,
        };
        println!("{}", serde_json::to_string(&state).unwrap());
        return;
    }

    // Default console output
    println!("==========================================================================================");
    println!("                                   OMANEWS DESKTOP HUB                                   ");
    println!("==========================================================================================");
    println!("Omarchy Kurulu: {} | Son Dağıtım Sürümü: {} (Güncel: {})", installed_version, latest_release, is_system_updated);
    println!("Toplam Haber/Sürüm: {} | Okunmamış: {}", total, unread);
    println!("------------------------------------------------------------------------------------------");
    println!("{:<12} {:<12} {:<54} {:<8}", "TARİH", "KATEGORİ", "BAŞLIK", "DURUM");
    println!("------------------------------------------------------------------------------------------");
    for a in &articles {
        let mark = if a.is_read { "OKUNDU" } else { "YENİ" };
        let short_title = if a.title.len() > 52 {
            format!("{}...", &a.title[..49])
        } else {
            a.title.clone()
        };
        println!("{:<12} [{:<10}] {:<54} [{}]", a.date, a.category, short_title, mark);
    }
    println!("==========================================================================================");
}
