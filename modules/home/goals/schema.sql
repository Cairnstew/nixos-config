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
    "order" INTEGER NOT NULL DEFAULT 0,
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

CREATE TABLE IF NOT EXISTS profile_facts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    category TEXT NOT NULL CHECK (category IN ('background', 'current_commitment', 'skill', 'value', 'relationship', 'constraint', 'history')),
    fact_text TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'active',
    superseded_by INTEGER REFERENCES profile_facts(id),
    source_check_in_id INTEGER REFERENCES check_ins(id),
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_profile_facts_category ON profile_facts(category);
CREATE INDEX IF NOT EXISTS idx_profile_facts_status ON profile_facts(status);
CREATE INDEX IF NOT EXISTS idx_profile_facts_superseded_by ON profile_facts(superseded_by);

-- Agent self-improvement learnings (Decision 1/4, pilot: nix-refine only).
-- `domain` discriminator keeps this disjoint from personal goals/traits at
-- query time, per the redesign split. `status` is the validation gate from
-- Decision 4 (Option 1): `learning_append` writes ONLY 'proposed'; only a
-- human-reviewed `learning_promote` moves a row to 'validated'/'rejected'.
CREATE TABLE IF NOT EXISTS learnings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    domain TEXT NOT NULL DEFAULT 'agent-learning',
    command TEXT NOT NULL,
    lesson TEXT NOT NULL,
    fix TEXT NOT NULL DEFAULT '',
    evidence TEXT NOT NULL CHECK (length(trim(evidence)) > 0),
    status TEXT NOT NULL DEFAULT 'proposed',
    alpha REAL NOT NULL DEFAULT 1.0,
    beta REAL NOT NULL DEFAULT 1.0,
    confidence REAL NOT NULL DEFAULT 0.5,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    acted_on_commit TEXT,
    superseded_by INTEGER REFERENCES learnings(id)
);

CREATE INDEX IF NOT EXISTS idx_learnings_domain ON learnings(domain);
CREATE INDEX IF NOT EXISTS idx_learnings_command ON learnings(command);
CREATE INDEX IF NOT EXISTS idx_learnings_status ON learnings(status);
CREATE INDEX IF NOT EXISTS idx_learnings_superseded_by ON learnings(superseded_by);

-- Supporting observations for one learning over time (mirrors trait_evidence).
-- Confidence (alpha/beta decay) is applied via the existing TraitEngine, which
-- is only wired for goals/traits today; wiring it for learnings is a separate
-- follow-on, not part of this pilot (the schema just provisions the columns).
CREATE TABLE IF NOT EXISTS learning_evidence (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    learning_id INTEGER NOT NULL REFERENCES learnings(id),
    evidence_value REAL NOT NULL,
    note TEXT,
    observed_date TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_learning_evidence_learning ON learning_evidence(learning_id);
CREATE INDEX IF NOT EXISTS idx_learning_evidence_date ON learning_evidence(observed_date);

-- Fabrication register (Decision 6): per-command record of fabricated /
-- recalled-not-verified incidents so audits start from prior context instead
-- of zero. Seeded retroactively in mcp_server.init_db.
CREATE TABLE IF NOT EXISTS fabrication_incidents (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    domain TEXT NOT NULL DEFAULT 'agent-learning',
    command TEXT NOT NULL,
    pattern_type TEXT NOT NULL,
    date TEXT NOT NULL,
    evidence TEXT NOT NULL CHECK (length(trim(evidence)) > 0),
    description TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_fabrication_incidents_command ON fabrication_incidents(command);
CREATE INDEX IF NOT EXISTS idx_fabrication_incidents_domain ON fabrication_incidents(domain);
