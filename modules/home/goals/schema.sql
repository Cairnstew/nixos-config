CREATE TABLE IF NOT EXISTS domains (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS goals (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    domain_id INTEGER NOT NULL REFERENCES domains(id),
    title TEXT NOT NULL,
    why_it_matters TEXT NOT NULL DEFAULT '',
    status TEXT NOT NULL DEFAULT 'active',
    priority INTEGER NOT NULL DEFAULT 3,
    target_date TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS milestones (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    goal_id INTEGER NOT NULL REFERENCES goals(id),
    title TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    target_date TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS actions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    goal_id INTEGER NOT NULL REFERENCES goals(id),
    milestone_id INTEGER REFERENCES milestones(id),
    description TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    completed_at TEXT
);

CREATE TABLE IF NOT EXISTS check_ins (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    domain_id INTEGER NOT NULL REFERENCES domains(id),
    goal_id INTEGER REFERENCES goals(id),
    text TEXT NOT NULL DEFAULT '',
    sentiment TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS traits (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    description TEXT NOT NULL DEFAULT '',
    category TEXT NOT NULL DEFAULT 'behavior',
    status TEXT NOT NULL DEFAULT 'proposed',
    alpha REAL NOT NULL DEFAULT 1.0,
    beta REAL NOT NULL DEFAULT 1.0,
    confidence REAL NOT NULL DEFAULT 0.5,
    last_updated TEXT NOT NULL,
    first_observed TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS trait_evidence (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    trait_id INTEGER NOT NULL REFERENCES traits(id),
    check_in_id INTEGER REFERENCES check_ins(id),
    evidence_value REAL NOT NULL,
    note TEXT,
    observed_date TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_goals_domain ON goals(domain_id);
CREATE INDEX IF NOT EXISTS idx_goals_status ON goals(status);
CREATE INDEX IF NOT EXISTS idx_check_ins_domain ON check_ins(domain_id);
CREATE INDEX IF NOT EXISTS idx_check_ins_goal ON check_ins(goal_id);
CREATE INDEX IF NOT EXISTS idx_trait_evidence_trait ON trait_evidence(trait_id);
CREATE INDEX IF NOT EXISTS idx_trait_evidence_date ON trait_evidence(observed_date);
CREATE INDEX IF NOT EXISTS idx_traits_status ON traits(status);
