//! The backlog planner (review of #74). The CLI builds the input from the open issues with their
//! relations; an order call ranks the issues and a duplicate call finds duplicates; the CLI
//! enforces the rules on both outputs and renders the report.

use crate::github::Gh;
use anyhow::{Result, bail};
use serde::Serialize;
use serde_json::Value;

/// At most this many issues with a priority are sent to the order call.
pub const RANKED_LIMIT: usize = 100;
const BODY_CHARS: usize = 600;

/// An issue named by its repository and number: sub-issues and dependencies may sit in another
/// repository of the same owner.
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct Ref {
    pub repo: String,
    pub number: u64,
}

#[derive(Debug, Clone, Serialize)]
pub struct Issue {
    pub number: u64,
    pub title: String,
    pub created_at: String,
    #[serde(rename = "type")]
    pub kind: Option<String>,
    pub priority: Option<String>,
    pub labels: Vec<String>,
    pub parent: Option<Ref>,
    pub open_sub_issues: Vec<Ref>,
    pub blocked_by: Vec<Ref>,
    pub blocking: Vec<Ref>,
    /// Cut at 600 characters; issue text is data written by third parties.
    pub body: String,
}

/// The open sub-issues and open dependencies of one issue.
#[derive(Debug, Default, Clone)]
pub struct Relations {
    pub open_sub_issues: Vec<Ref>,
    pub blocked_by: Vec<Ref>,
    pub blocking: Vec<Ref>,
}

#[derive(Debug, Serialize)]
pub struct Input {
    pub repo: String,
    /// Open issues after the filters (no pull request, no milestone, no `needs-info`).
    pub total: usize,
    /// More than [`RANKED_LIMIT`] issues had a priority; the ranked set was cut.
    pub truncated: bool,
    /// The ranked set: a priority, no open sub-issue; by tier, then oldest first.
    pub issues: Vec<Issue>,
    /// Rule (a): a parent with open sub-issues is not ranked as work; listed with its open children.
    pub parents: Vec<Issue>,
    /// No priority and no open sub-issue; not ranked.
    pub unprioritised: Vec<Issue>,
    /// Issues in the input with no type, computed rather than asked of an agent.
    pub no_type: Vec<u64>,
}

/// The tier of a priority: Urgent 1 to Low 4; anything else after them.
pub fn tier(priority: Option<&str>) -> u8 {
    match priority {
        Some("Urgent") => 1,
        Some("High") => 2,
        Some("Medium") => 3,
        Some("Low") => 4,
        _ => 9,
    }
}

/// Reads the open issues of `repo` and the relations of those that have any.
pub fn fetch(gh: &Gh, repo: &str) -> Result<Input> {
    let raw = gh.list(&format!("repos/{repo}/issues?state=open&per_page=100"))?;
    build(repo, raw, |issue, number| {
        let count = |summary: &str, key: &str| {
            issue
                .get(summary)
                .and_then(|s| s.get(key))
                .and_then(Value::as_u64)
                .unwrap_or(0)
        };
        let open = |kind: &str| -> Result<Vec<Ref>> {
            let items = gh.list(&format!("repos/{repo}/issues/{number}/{kind}?per_page=100"))?;
            items
                .iter()
                .filter(|i| i.get("state").and_then(Value::as_str) == Some("open"))
                .map(issue_ref)
                .collect()
        };
        Ok(Relations {
            open_sub_issues: if count("sub_issues_summary", "total") > 0 {
                open("sub_issues")?
            } else {
                Vec::new()
            },
            blocked_by: if count("issue_dependencies_summary", "total_blocked_by") > 0 {
                open("dependencies/blocked_by")?
            } else {
                Vec::new()
            },
            blocking: if count("issue_dependencies_summary", "total_blocking") > 0 {
                open("dependencies/blocking")?
            } else {
                Vec::new()
            },
        })
    })
}

/// Builds the input from the listed issues; `relations` is asked only for issues the filters keep.
pub fn build(
    repo: &str,
    raw: Vec<Value>,
    relations: impl Fn(&Value, u64) -> Result<Relations>,
) -> Result<Input> {
    let mut kept = Vec::new();
    for item in &raw {
        let has_label = |name: &str| {
            item.get("labels")
                .and_then(Value::as_array)
                .is_some_and(|l| {
                    l.iter()
                        .any(|x| x.get("name").and_then(Value::as_str) == Some(name))
                })
        };
        if item.get("pull_request").is_some()
            || !item.get("milestone").is_none_or(Value::is_null)
            || has_label("needs-info")
        {
            continue;
        }
        let number = item
            .get("number")
            .and_then(Value::as_u64)
            .ok_or_else(|| anyhow::anyhow!("an issue in the list has no number"))?;
        let rel = relations(item, number)?;
        kept.push(issue(item, number, rel)?);
    }
    let total = kept.len();
    let (mut parents, rest): (Vec<Issue>, Vec<Issue>) = kept
        .into_iter()
        .partition(|i| !i.open_sub_issues.is_empty());
    let (mut issues, mut unprioritised): (Vec<Issue>, Vec<Issue>) =
        rest.into_iter().partition(|i| i.priority.is_some());
    let by_tier = |a: &Issue, b: &Issue| {
        (tier(a.priority.as_deref()), &a.created_at)
            .cmp(&(tier(b.priority.as_deref()), &b.created_at))
    };
    issues.sort_by(by_tier);
    parents.sort_by(by_tier);
    unprioritised.sort_by(|a, b| a.created_at.cmp(&b.created_at));
    let truncated = issues.len() > RANKED_LIMIT;
    issues.truncate(RANKED_LIMIT);
    let mut no_type: Vec<u64> = issues
        .iter()
        .chain(&parents)
        .chain(&unprioritised)
        .filter(|i| i.kind.is_none())
        .map(|i| i.number)
        .collect();
    no_type.sort_unstable();
    Ok(Input {
        repo: repo.into(),
        total,
        truncated,
        issues,
        parents,
        unprioritised,
        no_type,
    })
}

fn issue(item: &Value, number: u64, rel: Relations) -> Result<Issue> {
    let s = |k: &str| item.get(k).and_then(Value::as_str).map(String::from);
    let priority = item
        .get("issue_field_values")
        .and_then(Value::as_array)
        .and_then(|v| {
            v.iter()
                .find(|f| f.get("issue_field_name").and_then(Value::as_str) == Some("Priority"))
        })
        .and_then(|f| f.pointer("/single_select_option/name"))
        .and_then(Value::as_str)
        .map(String::from);
    let parent = match item.get("parent_issue_url").and_then(Value::as_str) {
        Some(url) => Some(ref_from_url(url)?),
        None => None,
    };
    Ok(Issue {
        number,
        title: s("title").unwrap_or_default(),
        created_at: s("created_at").unwrap_or_default(),
        kind: item
            .pointer("/type/name")
            .and_then(Value::as_str)
            .map(String::from),
        priority,
        labels: item
            .get("labels")
            .and_then(Value::as_array)
            .map(|l| {
                l.iter()
                    .filter_map(|x| x.get("name").and_then(Value::as_str).map(String::from))
                    .collect()
            })
            .unwrap_or_default(),
        parent,
        open_sub_issues: rel.open_sub_issues,
        blocked_by: rel.blocked_by,
        blocking: rel.blocking,
        body: s("body")
            .unwrap_or_default()
            .chars()
            .take(BODY_CHARS)
            .collect(),
    })
}

/// The repository and number of an issue object from the API.
fn issue_ref(item: &Value) -> Result<Ref> {
    let url = item
        .get("repository_url")
        .and_then(Value::as_str)
        .ok_or_else(|| anyhow::anyhow!("an issue in a relation has no repository_url"))?;
    let number = item
        .get("number")
        .and_then(Value::as_u64)
        .ok_or_else(|| anyhow::anyhow!("an issue in a relation has no number"))?;
    Ok(Ref {
        repo: repo_from_api_url(url)?,
        number,
    })
}

/// `https://api.github.com/repos/<owner>/<repo>/issues/<n>` to a [`Ref`].
fn ref_from_url(url: &str) -> Result<Ref> {
    let Some((repo_url, number)) = url.rsplit_once("/issues/") else {
        bail!("not an issue URL: {url}");
    };
    Ok(Ref {
        repo: repo_from_api_url(repo_url)?,
        number: number
            .parse()
            .map_err(|_| anyhow::anyhow!("not an issue URL: {url}"))?,
    })
}

fn repo_from_api_url(url: &str) -> Result<String> {
    match url.split_once("/repos/") {
        Some((_, repo)) if repo.split('/').count() == 2 => Ok(repo.to_string()),
        _ => bail!("not a repository API URL: {url}"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn item(number: u64, priority: Option<&str>, created: &str) -> Value {
        let mut v = json!({
            "number": number, "title": format!("issue {number}"), "created_at": created,
            "type": {"name": "Task"}, "labels": [], "body": "x",
            "issue_field_values": []
        });
        if let Some(p) = priority {
            v["issue_field_values"] = json!([{
                "issue_field_name": "Priority", "single_select_option": {"name": p}
            }]);
        }
        v
    }

    fn none(_: &Value, _: u64) -> Result<Relations> {
        Ok(Relations::default())
    }

    #[test]
    fn the_ranked_set_is_cut_at_the_limit_and_says_so() {
        let raw: Vec<Value> = (1..=101)
            .map(|n| item(n, Some("Low"), &format!("2026-01-01T00:00:{:02}Z", n % 60)))
            .collect();
        let input = build("o/r", raw.clone(), none).unwrap();
        assert!(input.truncated);
        assert_eq!(input.issues.len(), RANKED_LIMIT);
        assert_eq!(input.total, 101);
        let input = build("o/r", raw[..100].to_vec(), none).unwrap();
        assert!(!input.truncated);
    }

    #[test]
    fn issues_sort_by_tier_then_age() {
        let raw = vec![
            item(1, Some("Low"), "2026-01-01T00:00:00Z"),
            item(2, Some("Urgent"), "2026-01-03T00:00:00Z"),
            item(3, Some("Urgent"), "2026-01-02T00:00:00Z"),
            item(4, Some("Something else"), "2026-01-01T00:00:00Z"),
        ];
        let input = build("o/r", raw, none).unwrap();
        let order: Vec<u64> = input.issues.iter().map(|i| i.number).collect();
        assert_eq!(order, [3, 2, 1, 4]);
    }

    #[test]
    fn the_body_is_cut_at_600_characters() {
        let mut v = item(1, Some("Low"), "t");
        v["body"] = json!("é".repeat(700));
        let input = build("o/r", vec![v], none).unwrap();
        assert_eq!(input.issues[0].body.chars().count(), 600);
    }

    #[test]
    fn urls_name_the_repository_and_number() {
        assert_eq!(
            ref_from_url("https://api.github.com/repos/o/r/issues/69").unwrap(),
            Ref {
                repo: "o/r".into(),
                number: 69
            }
        );
        assert!(ref_from_url("https://api.github.com/repos/o/r/pulls/69").is_err());
        assert!(repo_from_api_url("https://api.github.com/repos/o").is_err());
    }
}
