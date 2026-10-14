//! The development plan comment: its **Files** list, parsed in one place.

/// The plan has no `**Files**` line, so no scope can be derived from it.
#[derive(Debug, PartialEq, Eq)]
pub struct NoFilesHeading;

/// The paths of the backticked bullets (`- `path``) between a `**Files**` line and the next line
/// that starts with `**`. The heading must be present; its list may be empty.
pub fn files(plan: &str) -> Result<Vec<String>, NoFilesHeading> {
    let mut seen = false;
    let mut inside = false;
    let mut paths = Vec::new();
    for line in plan.lines() {
        if line.starts_with("**Files**") {
            seen = true;
            inside = true;
            continue;
        }
        if inside && line.starts_with("**") {
            inside = false;
        }
        if !inside {
            continue;
        }
        if let Some(rest) = line.strip_prefix("- `")
            && let Some(end) = rest.find('`').filter(|&end| end > 0)
        {
            paths.push(rest[..end].to_string());
        }
    }
    if seen { Ok(paths) } else { Err(NoFilesHeading) }
}

/// Whether the list names `path`. The comparison is literal: an entry that ends in `/` names a
/// directory and everything below it, any other entry names exactly one file.
pub fn names(files: &[String], path: &str) -> bool {
    files
        .iter()
        .any(|f| f == path || (f.ends_with('/') && path.starts_with(f.as_str())))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn list(paths: &[&str]) -> Vec<String> {
        paths.iter().map(|p| p.to_string()).collect()
    }

    #[test]
    fn reads_the_backticked_bullets_between_files_and_the_next_bold_line() {
        let plan = "<!-- dev-plan -->\n**Objective.** x\n**Files**\n- `src/a.rs` (new)\n- `docs/`\n\n**Risks**\n- `not/this.rs`\n";
        assert_eq!(files(plan), Ok(list(&["src/a.rs", "docs/"])));
    }

    #[test]
    fn a_plan_without_the_heading_is_an_error_not_an_empty_list() {
        assert_eq!(
            files("**Objective.** x\n- `src/a.rs`\n"),
            Err(NoFilesHeading)
        );
    }

    #[test]
    fn a_heading_with_no_bullets_is_an_empty_list() {
        assert_eq!(files("**Files**\n\n**Risks**\n"), Ok(vec![]));
    }

    #[test]
    fn names_with_spaces_and_crlf_lines_are_kept_whole() {
        let plan = "**Files**\r\n- `docs/my file.md`\r\n";
        assert_eq!(files(plan), Ok(list(&["docs/my file.md"])));
    }

    #[test]
    fn only_the_first_backticked_span_of_a_bullet_counts() {
        assert_eq!(
            files("**Files**\n- `a.rs` and `b.rs`\n"),
            Ok(list(&["a.rs"]))
        );
    }

    #[test]
    fn lines_that_are_not_top_level_backticked_bullets_are_ignored() {
        let plan = "**Files**\n  - `indented.rs`\n- plain.rs\n- ``\n- `unclosed\n* `star.rs`\n";
        assert_eq!(files(plan), Ok(vec![]));
    }

    #[test]
    fn a_file_entry_names_exactly_that_file() {
        let f = list(&[".github/workflows/ci.yml"]);
        assert!(names(&f, ".github/workflows/ci.yml"));
        assert!(!names(&f, ".github/workflows/ci.yml.bak"));
        assert!(!names(&f, ".github/workflows/other.yml"));
    }

    #[test]
    fn a_directory_entry_needs_its_slash_and_does_not_match_a_sibling_prefix() {
        assert!(names(&list(&["docs/"]), "docs/a/b.md"));
        assert!(!names(&list(&["docs/"]), "docs2/a.md"));
        assert!(!names(&list(&["docs"]), "docs/a.md"));
    }

    #[test]
    fn globs_and_stars_are_literal() {
        assert!(!names(
            &list(&[".github/workflows/*"]),
            ".github/workflows/ci.yml"
        ));
        assert!(names(&list(&["*.md"]), "*.md"));
    }
}
