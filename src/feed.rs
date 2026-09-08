use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq)]
pub struct Article {
    pub id: String,
    pub title: String,
    pub date: String,
    pub author: String,
    pub excerpt: String,
    pub url: String,
    pub category: String,
    pub is_read: bool,
}

pub fn strip_html_and_clean(input: &str) -> String {
    let unescaped = input
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&quot;", "\"")
        .replace("&amp;", "&")
        .replace("&#39;", "'")
        .replace("&apos;", "'")
        .replace("&#8217;", "'")
        .replace("&#8220;", "\"")
        .replace("&#8221;", "\"")
        .replace("&nbsp;", " ");

    let mut result = String::with_capacity(unescaped.len());
    let mut in_tag = false;

    for ch in unescaped.chars() {
        if ch == '<' {
            in_tag = true;
        } else if ch == '>' {
            in_tag = false;
        } else if !in_tag {
            result.push(ch);
        }
    }

    let words: Vec<&str> = result.split_whitespace().collect();
    let cleaned = words.join(" ");

    if cleaned.len() > 220 {
        format!("{}...", &cleaned[..217])
    } else {
        cleaned
    }
}

pub fn parse_rfc822_date(date_str: &str) -> String {
    let parts: Vec<&str> = date_str.split_whitespace().collect();
    if parts.len() >= 4 {
        let (day_str, month_str, year_str) = if parts[0].ends_with(',') && parts.len() >= 4 {
            (parts[1], parts[2], parts[3])
        } else {
            (parts[0], parts[1], parts[2])
        };

        let day = match day_str.parse::<u32>() {
            Ok(d) => format!("{:02}", d),
            Err(_) => return date_str.to_string(),
        };

        let month = match month_str.to_lowercase().as_str() {
            "jan" => "01",
            "feb" => "02",
            "mar" => "03",
            "apr" => "04",
            "may" => "05",
            "jun" => "06",
            "jul" => "07",
            "aug" => "08",
            "sep" => "09",
            "oct" => "10",
            "nov" => "11",
            "dec" => "12",
            _ => return date_str.to_string(),
        };

        let year = year_str.trim();
        if year.len() == 4 && year.chars().all(|c| c.is_ascii_digit()) {
            return format!("{}-{}-{}", year, month, day);
        }
    }

    date_str.to_string()
}

pub fn parse_iso_date(date_str: &str) -> String {
    if let Some(pos) = date_str.find('T') {
        date_str[..pos].to_string()
    } else if date_str.len() >= 10 {
        date_str[..10].to_string()
    } else {
        date_str.to_string()
    }
}

pub fn detect_category(title: &str, is_release_feed: bool) -> String {
    if is_release_feed || title.starts_with('v') || title.contains("Release") || title.contains("Sürüm") {
        return "Release".to_string();
    }

    let lower = title.to_lowercase();
    if lower.contains("foundation")
        || lower.contains("patron")
        || lower.contains("patronage")
        || lower.contains("funding")
        || lower.contains("dollar")
        || lower.contains("raises")
        || lower.contains("tokens")
    {
        "Foundation".to_string()
    } else if lower.contains("quattro")
        || lower.contains("redesign")
        || lower.contains("download")
        || lower.contains("iso")
        || lower.contains("air")
    {
        "Distro".to_string()
    } else if lower.contains("plugin")
        || lower.contains("competition")
        || lower.contains("mise")
        || lower.contains("quickshell")
        || lower.contains("hyprland")
        || lower.contains("sponsor")
    {
        "Ecosystem".to_string()
    } else if lower.contains("meetup")
        || lower.contains("ranger")
        || lower.contains("core team")
        || lower.contains("hire")
        || lower.contains("team")
    {
        "Community".to_string()
    } else {
        "News".to_string()
    }
}

pub fn extract_xml_tag(block: &str, tag: &str) -> String {
    let open_tag = format!("<{}>", tag);
    let close_tag = format!("</{}>", tag);

    if let Some(start) = block.find(&open_tag) {
        let content_start = start + open_tag.len();
        if let Some(end) = block[content_start..].find(&close_tag) {
            let inner = &block[content_start..content_start + end];
            if inner.starts_with("<![CDATA[") && inner.ends_with("]]>") {
                return inner[9..inner.len() - 3].trim().to_string();
            }
            return inner.trim().to_string();
        }
    }

    let prefix = format!("<{}", tag);
    if let Some(start) = block.find(&prefix) {
        if let Some(gt) = block[start..].find('>') {
            let content_start = start + gt + 1;
            if let Some(end) = block[content_start..].find(&close_tag) {
                let inner = &block[content_start..content_start + end];
                if inner.starts_with("<![CDATA[") && inner.ends_with("]]>") {
                    return inner[9..inner.len() - 3].trim().to_string();
                }
                return inner.trim().to_string();
            }
        }
    }

    String::new()
}

pub fn parse_rss(xml: &str) -> Vec<Article> {
    let mut articles = Vec::new();
    let item_blocks: Vec<&str> = xml.split("<item>").collect();

    for block in item_blocks.iter().skip(1) {
        let item_content = match block.split("</item>").next() {
            Some(c) => c,
            None => continue,
        };

        let title = extract_xml_tag(item_content, "title");
        if title.is_empty() {
            continue;
        }

        let link = extract_xml_tag(item_content, "link");
        let pub_date_raw = extract_xml_tag(item_content, "pubDate");
        let date = parse_rfc822_date(&pub_date_raw);

        let mut author = extract_xml_tag(item_content, "dc:creator");
        if author.is_empty() {
            author = extract_xml_tag(item_content, "author");
        }
        if author.is_empty() {
            author = "Omacom".to_string();
        }

        let mut desc = extract_xml_tag(item_content, "description");
        if desc.is_empty() {
            desc = extract_xml_tag(item_content, "content:encoded");
        }
        let excerpt = strip_html_and_clean(&desc);

        let slug = link
            .trim_end_matches('/')
            .split('/')
            .next_back()
            .unwrap_or("news")
            .to_string();

        let category = detect_category(&title, false);

        articles.push(Article {
            id: format!("news-{}", slug),
            title,
            date,
            author,
            excerpt,
            url: link,
            category,
            is_read: false,
        });
    }

    articles
}

pub fn parse_atom_releases(xml: &str) -> Vec<Article> {
    let mut articles = Vec::new();
    let entry_blocks: Vec<&str> = xml.split("<entry>").collect();

    for block in entry_blocks.iter().skip(1) {
        let entry_content = match block.split("</entry>").next() {
            Some(c) => c,
            None => continue,
        };

        let title = extract_xml_tag(entry_content, "title");
        if title.is_empty() {
            continue;
        }

        let mut link = String::new();
        if let Some(link_pos) = entry_content.find("<link ") {
            let after = &entry_content[link_pos..];
            if let Some(href_pos) = after.find("href=\"") {
                let href_val = &after[href_pos + 6..];
                if let Some(quote_end) = href_val.find('\"') {
                    link = href_val[..quote_end].to_string();
                }
            }
        }

        let updated_raw = extract_xml_tag(entry_content, "updated");
        let date = parse_iso_date(&updated_raw);

        let author_block = extract_xml_tag(entry_content, "author");
        let mut author = extract_xml_tag(&author_block, "name");
        if author.is_empty() {
            author = "omacom".to_string();
        }

        let mut content = extract_xml_tag(entry_content, "content");
        if content.is_empty() {
            content = extract_xml_tag(entry_content, "summary");
        }
        let excerpt = strip_html_and_clean(&content);

        let slug = if !link.is_empty() {
            link.trim_end_matches('/')
                .split('/')
                .next_back()
                .unwrap_or("release")
                .to_string()
        } else {
            title.replace(' ', "-").to_lowercase()
        };

        articles.push(Article {
            id: format!("release-{}", slug),
            title,
            date,
            author,
            excerpt,
            url: link,
            category: "Release".to_string(),
            is_read: false,
        });
    }

    articles
}

pub fn get_default_articles() -> Vec<Article> {
    vec![
        Article {
            id: "release-v4.0.3".to_string(),
            title: "v4.0.3: Credit @Chainfire for the asdcontrol security report".to_string(),
            date: "2026-09-08".to_string(),
            author: "omacom".to_string(),
            excerpt: "Security fix and reporter credit for asdcontrol watchdog reboot. Omarchy sudo grant restricted. Upgrades live via Update > Omarchy.".to_string(),
            url: "https://github.com/omacom/omarchy/releases/tag/v4.0.3".to_string(),
            category: "Release".to_string(),
            is_read: false,
        },
        Article {
            id: "news-omacom-foundation-raises-another-half-a-million-dollars".to_string(),
            title: "Omacom Foundation raises another half a million dollars!".to_string(),
            date: "2026-09-07".to_string(),
            author: "DHH".to_string(),
            excerpt: "OpenRouter pledges $150,000 in tokens, Four Technologies commits $300,000 over three years, bringing total endowment to approximately $15.5 million.".to_string(),
            url: "https://omarchy.org/news/2026/09/omacom-foundation-raises-another-half-a-million-dollars".to_string(),
            category: "Foundation".to_string(),
            is_read: false,
        },
        Article {
            id: "news-omarchy-org-redesign-launches-with-29-languages".to_string(),
            title: "Omarchy.org redesign launches with 29 languages".to_string(),
            date: "2026-09-07".to_string(),
            author: "DHH".to_string(),
            excerpt: "A fun, retro, beautiful new home for Omarchy, with 29 languages and local domains around the world.".to_string(),
            url: "https://omarchy.org/news/2026/09/omarchy-org-redesign-launches-with-29-languages".to_string(),
            category: "Distro".to_string(),
            is_read: false,
        },
        Article {
            id: "news-omacom-foundation-secures-tokens-from-leading-labs".to_string(),
            title: "Omacom Foundation secures $1.95M in tokens from leading labs".to_string(),
            date: "2026-09-03".to_string(),
            author: "DHH".to_string(),
            excerpt: "Meta Superintelligence Labs joins as Founding Token Patron with $1.5M in tokens, and Anthropic joins with $450,000 in tokens.".to_string(),
            url: "https://omarchy.org/news/2026/09/omacom-foundation-secures-tokens-from-leading-labs".to_string(),
            category: "Foundation".to_string(),
            is_read: false,
        },
        Article {
            id: "news-omacom-foundation-accelerates-spending-goals".to_string(),
            title: "Omacom Foundation accelerates spending goals".to_string(),
            date: "2026-09-03".to_string(),
            author: "DHH".to_string(),
            excerpt: "Everything raised this year will be spent over the next three years to build out Wayland desktop ecosystem and core development.".to_string(),
            url: "https://omarchy.org/news/2026/09/omacom-foundation-accelerates-spending-goals".to_string(),
            category: "Foundation".to_string(),
            is_read: false,
        },
        Article {
            id: "news-omacom-patronage-is-open-to-everyone".to_string(),
            title: "Omarchy Patronage is now open to everyone".to_string(),
            date: "2026-09-03".to_string(),
            author: "DHH".to_string(),
            excerpt: "Patronage of the Omacom Foundation is now open to everyone in four tiers, each with its own badge and recognition.".to_string(),
            url: "https://omarchy.org/news/2026/09/omacom-patronage-is-open-to-everyone".to_string(),
            category: "Foundation".to_string(),
            is_read: false,
        },
        Article {
            id: "news-omacom-foundation-hires-krzysztof-wilczynski".to_string(),
            title: "Omacom Foundation hires kernel developer Krzysztof Wilczyński".to_string(),
            date: "2026-09-03".to_string(),
            author: "DHH".to_string(),
            excerpt: "The foundation's first full-time employee will lead the Omarchy Kernel work on performance, compatibility, and security.".to_string(),
            url: "https://omarchy.org/news/2026/09/omacom-foundation-hires-krzysztof-wilczynski".to_string(),
            category: "Community".to_string(),
            is_read: false,
        },
        Article {
            id: "news-quattro-crosses-200000-iso-downloads".to_string(),
            title: "Omarchy Quattro crosses 200,000 ISO downloads".to_string(),
            date: "2026-09-02".to_string(),
            author: "DHH".to_string(),
            excerpt: "Two hundred thousand Quattro ISOs downloaded in under 19 days across 215 countries and territories.".to_string(),
            url: "https://omarchy.org/news/2026/09/quattro-crosses-200000-iso-downloads".to_string(),
            category: "Distro".to_string(),
            is_read: false,
        },
        Article {
            id: "release-v4.0.2".to_string(),
            title: "v4.0.2: Security fixes validated by Omarchy Security team".to_string(),
            date: "2026-08-31".to_string(),
            author: "omacom".to_string(),
            excerpt: "Validated security fixes for core desktop infrastructure and package management. Update via Update > Omarchy.".to_string(),
            url: "https://github.com/omacom/omarchy/releases/tag/v4.0.2".to_string(),
            category: "Release".to_string(),
            is_read: false,
        },
        Article {
            id: "news-the-first-plugin-competition-winners".to_string(),
            title: "The first plugin competition winners".to_string(),
            date: "2026-08-28".to_string(),
            author: "DHH".to_string(),
            excerpt: "Radio Atlas, Omagotchi, and AirPods take the podium in the first Omarchy plugin competition across Security and Utility tracks.".to_string(),
            url: "https://omarchy.org/news/2026/08/the-first-plugin-competition-winners".to_string(),
            category: "Ecosystem".to_string(),
            is_read: false,
        },
        Article {
            id: "news-introducing-omarchy-air".to_string(),
            title: "Introducing Omarchy AIR".to_string(),
            date: "2026-08-28".to_string(),
            author: "DHH".to_string(),
            excerpt: "A six-month funded residency for the artists and designers who make Omarchy beautiful.".to_string(),
            url: "https://omarchy.org/news/2026/08/introducing-omarchy-air".to_string(),
            category: "Distro".to_string(),
            is_read: false,
        },
        Article {
            id: "news-introducing-the-omarchy-rangers".to_string(),
            title: "Introducing Omarchy Rangers".to_string(),
            date: "2026-08-27".to_string(),
            author: "DHH".to_string(),
            excerpt: "The first Omarchy Rangers are here to help people find their way and curate verified marketplace plugins.".to_string(),
            url: "https://omarchy.org/news/2026/08/introducing-the-omarchy-rangers".to_string(),
            category: "Community".to_string(),
            is_read: false,
        },
    ]
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_date_conversion() {
        assert_eq!(parse_rfc822_date("Mon, 07 Sep 2026 20:08:00 GMT"), "2026-09-07");
        assert_eq!(parse_rfc822_date("31 Aug 2026 13:20:00 GMT"), "2026-08-31");
        assert_eq!(parse_iso_date("2026-09-08T16:49:55Z"), "2026-09-08");
    }

    #[test]
    fn test_html_cleaner() {
        let raw = "<p>OpenRouter pledges $150,000 in tokens &amp; <a href=\"#\">patrons</a> join!</p>";
        let cleaned = strip_html_and_clean(raw);
        assert_eq!(cleaned, "OpenRouter pledges $150,000 in tokens & patrons join!");
    }

    #[test]
    fn test_parse_rss_item() {
        let sample = r#"
<rss version="2.0" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <item>
      <title>Omarchy.org redesign launches with 29 languages</title>
      <link>https://omarchy.org/news/2026/09/omarchy-org-redesign-launches-with-29-languages</link>
      <pubDate>Mon, 07 Sep 2026 18:15:00 GMT</pubDate>
      <dc:creator>DHH</dc:creator>
      <description><![CDATA[A fun, retro, beautiful new home for Omarchy.]]></description>
    </item>
  </channel>
</rss>"#;
        let articles = parse_rss(sample);
        assert_eq!(articles.len(), 1);
        assert_eq!(articles[0].title, "Omarchy.org redesign launches with 29 languages");
        assert_eq!(articles[0].date, "2026-09-07");
        assert_eq!(articles[0].author, "DHH");
        assert_eq!(articles[0].category, "Distro");
        assert_eq!(articles[0].excerpt, "A fun, retro, beautiful new home for Omarchy.");
    }

    #[test]
    fn test_parse_atom_releases() {
        let sample = r#"
<feed xmlns="http://www.w3.org/2005/Atom">
  <entry>
    <id>tag:github.com,2008:Repository/994093166/v4.0.3</id>
    <updated>2026-09-08T16:49:55Z</updated>
    <link rel="alternate" type="text/html" href="https://github.com/omacom/omarchy/releases/tag/v4.0.3"/>
    <title>v4.0.3: Credit @Chainfire for the asdcontrol security report</title>
    <content type="html">&lt;p&gt;Chainfire reported security fix.&lt;/p&gt;</content>
    <author><name>ryanrhughes</name></author>
  </entry>
</feed>"#;
        let articles = parse_atom_releases(sample);
        assert_eq!(articles.len(), 1);
        assert_eq!(articles[0].title, "v4.0.3: Credit @Chainfire for the asdcontrol security report");
        assert_eq!(articles[0].date, "2026-09-08");
        assert_eq!(articles[0].author, "ryanrhughes");
        assert_eq!(articles[0].category, "Release");
        assert_eq!(articles[0].excerpt, "Chainfire reported security fix.");
    }
}
