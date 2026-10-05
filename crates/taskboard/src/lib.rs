//! Application logic and SQLite persistence. No dependency on IIS or COM.
use rusqlite::{Connection, params};
use std::{fmt, path::Path, time::Duration};

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Task {
    pub id: i32,
    pub title: String,
    pub done: bool,
    pub created_at: String,
}

#[derive(Debug)]
pub enum Error {
    Invalid(&'static str),
    NotFound,
    Storage(rusqlite::Error),
}
impl fmt::Display for Error {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Invalid(message) => f.write_str(message),
            Self::NotFound => f.write_str("That task no longer exists."),
            Self::Storage(_) => f.write_str("The task database is unavailable."),
        }
    }
}
impl std::error::Error for Error {}
impl From<rusqlite::Error> for Error {
    fn from(value: rusqlite::Error) -> Self {
        Self::Storage(value)
    }
}
type Result<T> = std::result::Result<T, Error>;

pub struct Store(Connection);
impl Store {
    pub fn open(path: impl AsRef<Path>) -> Result<Self> {
        let connection = Connection::open(path)?;
        connection.busy_timeout(Duration::from_secs(5))?;
        connection.execute_batch(
            "PRAGMA journal_mode=WAL;
             CREATE TABLE IF NOT EXISTS tasks (
               id INTEGER PRIMARY KEY AUTOINCREMENT CHECK (id <= 2147483647),
               title TEXT NOT NULL CHECK (length(title) BETWEEN 1 AND 200),
               done INTEGER NOT NULL DEFAULT 0 CHECK (done IN (0,1)),
               created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
             );",
        )?;
        Ok(Self(connection))
    }
    pub fn add(&self, title: &str) -> Result<i32> {
        let title = validate_title(title)?;
        self.0
            .execute("INSERT INTO tasks(title) VALUES (?1)", [title])?;
        Ok(self.0.last_insert_rowid() as i32)
    }
    pub fn list(&self, filter: &str) -> Result<Vec<Task>> {
        let done: Option<bool> = match filter {
            "all" => None,
            "open" => Some(false),
            "done" => Some(true),
            _ => return Err(Error::Invalid("Choose all, open, or done.")),
        };
        let mut statement = self.0.prepare(
            "SELECT id,title,done,created_at FROM tasks WHERE (?1 IS NULL OR done=?1) ORDER BY id DESC"
        )?;
        let rows = statement.query_map([done], |row| {
            Ok(Task {
                id: row.get(0)?,
                title: row.get(1)?,
                done: row.get(2)?,
                created_at: row.get(3)?,
            })
        })?;
        Ok(rows.collect::<std::result::Result<Vec<_>, _>>()?)
    }
    pub fn rename(&self, id: i32, title: &str) -> Result<()> {
        validate_id(id)?;
        let title = validate_title(title)?;
        changed(
            self.0
                .execute("UPDATE tasks SET title=?1 WHERE id=?2", params![title, id])?,
        )
    }
    pub fn set_done(&self, id: i32, done: bool) -> Result<()> {
        validate_id(id)?;
        changed(
            self.0
                .execute("UPDATE tasks SET done=?1 WHERE id=?2", params![done, id])?,
        )
    }
    pub fn delete(&self, id: i32) -> Result<()> {
        validate_id(id)?;
        changed(self.0.execute("DELETE FROM tasks WHERE id=?1", [id])?)
    }
}
fn validate_title(title: &str) -> Result<&str> {
    let title = title.trim();
    if title.is_empty() || title.chars().count() > 200 {
        return Err(Error::Invalid("Use a title between 1 and 200 characters."));
    }
    if title.chars().any(char::is_control) {
        return Err(Error::Invalid(
            "Task titles must be a single line without control characters.",
        ));
    }
    Ok(title)
}
fn validate_id(id: i32) -> Result<()> {
    if id <= 0 {
        Err(Error::Invalid("Invalid task ID."))
    } else {
        Ok(())
    }
}
fn changed(count: usize) -> Result<()> {
    if count == 0 {
        Err(Error::NotFound)
    } else {
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn lifecycle_and_filters() {
        let db = Store::open(":memory:").unwrap();
        let id = db.add("  Ship the follow-up  ").unwrap();
        assert_eq!(db.list("open").unwrap()[0].title, "Ship the follow-up");
        db.rename(id, "Prove the COM boundary").unwrap();
        db.set_done(id, true).unwrap();
        assert!(db.list("open").unwrap().is_empty());
        assert_eq!(db.list("done").unwrap()[0].title, "Prove the COM boundary");
        db.set_done(id, false).unwrap();
        assert_eq!(db.list("all").unwrap().len(), 1);
        db.delete(id).unwrap();
        assert!(db.list("all").unwrap().is_empty());
        assert!(matches!(db.delete(id), Err(Error::NotFound)));
    }
    #[test]
    fn validates_titles_ids_and_filters() {
        let db = Store::open(":memory:").unwrap();
        for title in [
            "".to_string(),
            "   ".to_string(),
            "a".repeat(201),
            "a\0b".to_string(),
            "a\nb".to_string(),
        ] {
            assert!(db.add(&title).is_err());
        }
        assert!(db.add(&"🦀".repeat(200)).is_ok());
        assert!(db.list("anything").is_err());
        assert!(db.set_done(0, true).is_err());
        assert!(db.rename(-1, "title").is_err());
        assert!(matches!(db.rename(999, "title"), Err(Error::NotFound)));
    }
    #[test]
    fn sql_and_html_are_stored_as_plain_data() {
        let db = Store::open(":memory:").unwrap();
        let value = "<script>alert('x')</script>'); DROP TABLE tasks;--";
        db.add(value).unwrap();
        assert_eq!(db.list("all").unwrap()[0].title, value);
        assert!(db.add("Still here").is_ok());
    }
    #[test]
    fn survives_reopening_and_two_connections() {
        let path = std::env::temp_dir().join(format!(
            "rusty-asp-test-{}-{}.sqlite",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        {
            let first = Store::open(&path).unwrap();
            first.add("Persistent").unwrap();
            let second = Store::open(&path).unwrap();
            let id = second.add("Second connection").unwrap();
            first.set_done(id, true).unwrap();
            assert_eq!(second.list("done").unwrap().len(), 1);
        }
        {
            let reopened = Store::open(&path).unwrap();
            assert_eq!(reopened.list("all").unwrap().len(), 2);
        }
        std::fs::remove_file(path).unwrap();
    }
}
