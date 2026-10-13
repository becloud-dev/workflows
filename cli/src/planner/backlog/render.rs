//! The report: Markdown for the job's step summary, and the JSON report the artifact keeps.

use super::input::{Input, Issue};
use super::rules::{Conflict, Duplicates, Order, all_issues};
use serde::Serialize;
use std::collections::HashMap;
use std::fmt::Write;

#[derive(Serialize)]
pub struct Report<'a> {
    pub input: &'a Input,
    pub order: &'a Order,
    pub duplicates: &'a Duplicates,
    pub conflicts: &'a [Conflict],
}

fn label(i: &Issue) -> String {
    format!(
        "#{} [{}] {}",
        i.number,
        i.priority.as_deref().unwrap_or("no priority"),
        i.title
    )
}

fn refs(r: &[super::input::Ref], repo: &str) -> String {
    r.iter()
        .map(|x| {
            if x.repo == repo {
                format!("#{}", x.number)
            } else {
                format!("{}#{}", x.repo, x.number)
            }
        })
        .collect::<Vec<_>>()
        .join(", ")
}

/// The step summary, most important first: the order, then what the order could not settle.
pub fn markdown(report: &Report) -> String {
    let input = report.input;
    let by_number: HashMap<u64, &Issue> = all_issues(input).map(|i| (i.number, i)).collect();
    let mut s = String::new();
    let none = |s: &mut String, empty: bool| {
        if empty {
            s.push_str("None.\n");
        }
    };

    s.push_str("### Backlog order\n");
    for (n, r) in report.order.order.iter().enumerate() {
        let i = by_number[&r.number];
        let blocked = if i.blocked_by.is_empty() {
            String::new()
        } else {
            format!(" (blocked by {})", refs(&i.blocked_by, &input.repo))
        };
        let _ = writeln!(s, "{}. {}{blocked}: {}", n + 1, label(i), r.reason);
    }
    none(&mut s, report.order.order.is_empty());

    s.push_str("\n### Blockers the order does not move\n");
    for c in report.conflicts {
        let _ = writeln!(s, "- #{} is blocked by {}: {}.", c.issue, c.blocker, c.why);
    }
    none(&mut s, report.conflicts.is_empty());

    s.push_str("\n### Parents not ranked as work\n");
    for p in &input.parents {
        let _ = writeln!(
            s,
            "- {}: open sub-issues {}",
            label(p),
            refs(&p.open_sub_issues, &input.repo)
        );
    }
    none(&mut s, input.parents.is_empty());

    s.push_str("\n### Duplicates\n");
    for d in &report.duplicates.duplicates {
        let _ = writeln!(
            s,
            "- #{} duplicates #{}. {}",
            d.number, d.duplicate_of, d.evidence
        );
    }
    none(&mut s, report.duplicates.duplicates.is_empty());

    s.push_str("\n### No type\n");
    for n in &input.no_type {
        let _ = writeln!(s, "- {}", label(by_number[n]));
    }
    none(&mut s, input.no_type.is_empty());

    s.push_str("\n### Unprioritised\n");
    for i in &input.unprioritised {
        let _ = writeln!(s, "- {}", label(i));
    }
    none(&mut s, input.unprioritised.is_empty());

    let _ = write!(
        s,
        "\n### Summary\n{}\n\n{} open issues after the filters; {} ranked{}. The claims in the \
         issues are not verified against the repositories.\n",
        report.order.summary,
        input.total,
        input.issues.len(),
        if input.truncated { ", cut at 100" } else { "" }
    );
    s
}
