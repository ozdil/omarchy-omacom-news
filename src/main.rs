use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct Article {
    pub id: String,
    pub title: String,
    pub date: String,
    pub author: String,
    pub excerpt: String,
    pub url: String,
    pub is_read: bool,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct NewsState {
    pub status: String,
    pub total: usize,
    pub unread: usize,
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

#[derive(Serialize, Deserialize, Default)]
struct SavedState {
    last_notified_id: String,
    read_ids: Vec<String>,
}

fn get_data_dir() -> PathBuf {
    if let Ok(home) = env::var("HOME") {
        PathBuf::from(home).join(".local/share/omarchy/omacom-news")
    } else {
        PathBuf::from("/tmp/omacom-news")
    }
}

fn load_state() -> SavedState {
    let path = get_data_dir().join("state.json");
    if path.is_file() {
        if let Ok(content) = fs::read_to_string(&path) {
            if let Ok(s) = serde_json::from_str::<SavedState>(&content) {
                return s;
            }
        }
    }
    SavedState::default()
}

fn save_state(state: &SavedState) {
    let dir = get_data_dir();
    let _ = fs::create_dir_all(&dir);
    if let Ok(data) = serde_json::to_string(state) {
        let _ = fs::write(dir.join("state.json"), data);
    }
}

fn get_default_articles() -> Vec<Article> {
    vec![
        Article {
            id: "omacom-foundation-welcomes-brian-armstrong-and-yunjie-dai".to_string(),
            title: "Omacom Foundation welcomes Brian Armstrong and Yunjie Dai".to_string(),
            date: "2026-08-31".to_string(),
            author: "DHH".to_string(),
            excerpt: "Two more Founding Patrons join the mission with $1 million each, taking the foundation endowment to $12 million.".to_string(),
            url: "https://omarchy.org/news/2026/08/omacom-foundation-welcomes-brian-armstrong-and-yunjie-dai".to_string(),
            is_read: false,
        },
        Article {
            id: "1password-and-37signals-become-distinguished-corporate-patrons".to_string(),
            title: "1Password and 37signals become Distinguished Corporate Patrons".to_string(),
            date: "2026-08-31".to_string(),
            author: "DHH".to_string(),
            excerpt: "The first two Distinguished Corporate Patrons each pledge $100,000 a year for three years to back open source desktop computing.".to_string(),
            url: "https://omarchy.org/news/2026/08/1password-and-37signals-become-distinguished-corporate-patrons".to_string(),
            is_read: false,
        },
        Article {
            id: "the-first-plugin-competition-winners".to_string(),
            title: "The first plugin competition winners".to_string(),
            date: "2026-08-28".to_string(),
            author: "DHH".to_string(),
            excerpt: "Winners of the inaugural Omarchy Plugin Competition announced across Security, Utility, and Customization tracks.".to_string(),
            url: "https://omarchy.org/news/2026/08/the-first-plugin-competition-winners".to_string(),
            is_read: false,
        },
        Article {
            id: "introducing-omarchy-air".to_string(),
            title: "Introducing Omarchy AIR".to_string(),
            date: "2026-08-28".to_string(),
            author: "DHH".to_string(),
            excerpt: "Omarchy AIR brings lightweight, ultra-fast peer-to-peer workspace synchronization and wireless file bridge.".to_string(),
            url: "https://omarchy.org/news/2026/08/introducing-omarchy-air".to_string(),
            is_read: false,
        },
        Article {
            id: "omarchy-tops-100000-downloads-in-a-week".to_string(),
            title: "Omarchy tops 100,000 downloads in a week".to_string(),
            date: "2026-08-28".to_string(),
            author: "DHH".to_string(),
            excerpt: "Global adoption accelerates as Linux desktop users worldwide migrate to Omarchy's declarative Arch base.".to_string(),
            url: "https://omarchy.org/news/2026/08/100000-downloads-in-a-week".to_string(),
            is_read: false,
        },
        Article {
            id: "introducing-omarchy-rangers".to_string(),
            title: "Introducing Omarchy Rangers".to_string(),
            date: "2026-08-27".to_string(),
            author: "DHH".to_string(),
            excerpt: "Omarchy Rangers community program launched to mentor newcomers and curate verified marketplace plugins.".to_string(),
            url: "https://omarchy.org/news/2026/08/introducing-the-omarchy-rangers".to_string(),
            is_read: false,
        },
        Article {
            id: "omacom-foundation-to-be-premier-mise-sponsor".to_string(),
            title: "Omacom Foundation to be premier mise sponsor".to_string(),
            date: "2026-08-25".to_string(),
            author: "DHH".to_string(),
            excerpt: "Omacom Foundation pledges full multi-year financial backing to support developer tooling and mise development.".to_string(),
            url: "https://omarchy.org/news/2026/08/omacom-foundation-to-be-premier-mise-sponsor".to_string(),
            is_read: false,
        },
        Article {
            id: "omacom-foundation-to-be-premier-quickshell-sponsor".to_string(),
            title: "Omacom Foundation to be premier Quickshell sponsor".to_string(),
            date: "2026-08-24".to_string(),
            author: "DHH".to_string(),
            excerpt: "Omacom Foundation establishes direct core sponsorship for Quickshell desktop environment UI toolkit.".to_string(),
            url: "https://omarchy.org/news/2026/08/omacom-foundation-to-be-premier-quickshell-sponsor".to_string(),
            is_read: false,
        },
        Article {
            id: "omacom-foundation-funding-hits-10m".to_string(),
            title: "Omacom Foundation funding hits $10m".to_string(),
            date: "2026-08-24".to_string(),
            author: "DHH".to_string(),
            excerpt: "Foundation capital milestone reached, securing multi-year funding for open source Wayland desktop infrastructure.".to_string(),
            url: "https://omarchy.org/news/2026/08/omacom-foundation-funding-hits-10m".to_string(),
            is_read: false,
        },
        Article {
            id: "omacom-foundation-to-be-exclusive-hyprland-sponsor".to_string(),
            title: "Omacom Foundation to be exclusive Hyprland sponsor".to_string(),
            date: "2026-08-21".to_string(),
            author: "DHH".to_string(),
            excerpt: "Exclusive partnership and direct grants to power Hyprland compositor innovation and stability.".to_string(),
            url: "https://omarchy.org/news/2026/08/omacom-foundation-to-be-exclusive-hyprland-sponsor".to_string(),
            is_read: false,
        },
    ]
}

fn fetch_remote_html() -> Option<String> {
    // Try fetching from https://omarchy.org/news with a quick 3-second timeout
    let output = Command::new("/usr/bin/curl")
        .args(&["-sL", "--max-time", "3", "https://omarchy.org/news"])
        .env("LC_ALL", "C")
        .output()
        .ok()?;

    if output.status.success() && !output.stdout.is_empty() {
        let text = String::from_utf8_lossy(&output.stdout).to_string();
        if text.contains("news-card") {
            let cache_file = get_data_dir().join("cache.html");
            let _ = fs::create_dir_all(get_data_dir());
            let _ = fs::write(cache_file, &text);
            return Some(text);
        }
    }

    // Fallback to local scratch site if available
    let local_site = Path::new("/home/ozdil/.gemini/antigravity/scratch/omarchy-site/news/index.html");
    if local_site.is_file() {
        if let Ok(c) = fs::read_to_string(local_site) {
            return Some(c);
        }
    }

    // Fallback to cached html
    let cache_file = get_data_dir().join("cache.html");
    if cache_file.is_file() {
        if let Ok(c) = fs::read_to_string(cache_file) {
            return Some(c);
        }
    }

    None
}

fn parse_html(html: &str) -> Vec<Article> {
    let mut articles = Vec::new();
    let parts: Vec<&str> = html.split("<article class=\"news-card\">").collect();

    for part in parts.iter().skip(1) {
        let block = match part.split("</article>").next() {
            Some(b) => b,
            None => continue,
        };

        let title = extract_tag_content(block, "h2 class=\"news-card__title\">", "</h2>");
        let date = extract_tag_content(block, "<time class=\"news-date\"", "</time>");
        let clean_date = date.split('>').nth(1).unwrap_or(&date).trim().to_string();
        let author = extract_tag_content(block, "rel=\"author\">", "</a>");
        let excerpt = extract_tag_content(block, "<div class=\"news-card__excerpt\">", "</div>");
        let link = extract_tag_content(block, "<a class=\"news-card__link\" href=\"", "\"");

        if !title.is_empty() {
            let clean_link = if link.starts_with('/') {
                format!("https://omarchy.org{}", link)
            } else {
                link
            };

            let slug = clean_link
                .trim_end_matches('/')
                .split('/')
                .last()
                .unwrap_or("article")
                .to_string();

            articles.push(Article {
                id: slug,
                title,
                date: clean_date,
                author: if author.is_empty() { "Omacom".to_string() } else { author },
                excerpt,
                url: clean_link,
                is_read: false,
            });
        }
    }

    articles
}

fn extract_tag_content(src: &str, open: &str, close: &str) -> String {
    if let Some(start) = src.find(open) {
        let rest = &src[start + open.len()..];
        if let Some(end) = rest.find(close) {
            return rest[..end].trim().to_string();
        }
    }
    String::new()
}

fn get_articles() -> Vec<Article> {
    let mut articles = if let Some(html) = fetch_remote_html() {
        let parsed = parse_html(&html);
        if !parsed.is_empty() {
            parsed
        } else {
            get_default_articles()
        }
    } else {
        get_default_articles()
    };

    let state = load_state();
    let read_set: HashSet<String> = state.read_ids.into_iter().collect();

    for a in &mut articles {
        if read_set.contains(&a.id) {
            a.is_read = true;
        }
    }

    articles
}

fn send_desktop_notification(article: &Article) {
    let summary = format!("OMACOM FOUNDATION: {}", article.title.to_uppercase());
    let body = format!("{} • {}\n{}", article.date, article.author, article.excerpt);

    let _ = Command::new("/usr/bin/notify-send")
        .args(&[
            "--app-name=Omacom News",
            "--urgency=normal",
            &summary,
            &body,
        ])
        .output();
}

fn check_and_notify_latest(articles: &[Article]) {
    if let Some(latest) = articles.first() {
        let mut state = load_state();
        if state.last_notified_id != latest.id {
            send_desktop_notification(latest);
            state.last_notified_id = latest.id.clone();
            save_state(&state);
        }
    }
}

fn main() {
    let args: Vec<String> = env::args().collect();
    let articles = get_articles();

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
            save_state(&state);
            println!("Notification dispatched for: {}", art.title);
        }
        return;
    }

    if args.iter().any(|a| a == "--read") {
        if let Some(idx) = args.iter().position(|a| a == "--read") {
            if idx + 1 < args.len() {
                let target_url = &args[idx + 1];
                let _ = Command::new("/usr/bin/xdg-open").arg(target_url).spawn();
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
        save_state(&state);
        println!("All dispatches marked as read.");
        return;
    }

    let unread = articles.iter().filter(|a| !a.is_read).count();
    let total = articles.len();
    let latest_title = articles.first().map(|a| a.title.clone()).unwrap_or_default();
    let latest_date = articles.first().map(|a| a.date.clone()).unwrap_or_default();

    if args.iter().any(|a| a == "--status") {
        let text = if unread > 0 {
            format!("OMACOM: {} NEW", unread)
        } else {
            "OMACOM: NEWS".to_string()
        };

        let tooltip = format!(
            "Omacom Foundation News Hub\nLatest: {}\nDate: {}\nUnread Dispatches: {}\nEngine: Native Rust",
            latest_title, latest_date, unread
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
            latest_title,
            latest_date,
            articles,
        };
        println!("{}", serde_json::to_string(&state).unwrap());
        return;
    }

    println!("OMACOM FOUNDATION NEWS & DISPATCHES");
    println!("Total: {} | Unread: {}", total, unread);
    println!("{:<12} {:<60} {:<10}", "DATE", "TITLE", "AUTHOR");
    println!("{}", "-".repeat(85));
    for a in &articles {
        let mark = if a.is_read { "READ" } else { "NEW" };
        println!("{:<12} {:<60} [{}]", a.date, a.title, mark);
    }
}
