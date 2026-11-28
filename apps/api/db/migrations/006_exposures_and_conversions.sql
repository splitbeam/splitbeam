-- Targets for the composite foreign keys below
ALTER TABLE experiments ADD UNIQUE (id, environment_id);
ALTER TABLE variants    ADD UNIQUE (id, experiment_id);
ALTER TABLE experiments ADD UNIQUE (id, project_id);

-- Goals a project can track (defined in the dashboard)
CREATE TABLE goals (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    project_id bigint NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    key        text   NOT NULL CHECK (key ~ '^[a-z][a-z0-9_]*$'),
    name       text   NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),

    UNIQUE (project_id, key),
    UNIQUE (id, project_id)
);

-- Who saw which variant (first exposure per user per experiment)
CREATE TABLE exposures (
    id             bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    environment_id bigint NOT NULL,
    experiment_id  bigint NOT NULL,
    variant_id     bigint NOT NULL,
    user_id        text   NOT NULL CHECK (length(user_id) BETWEEN 1 AND 256),
    occurred_at    timestamptz NOT NULL,
    received_at    timestamptz NOT NULL DEFAULT now(),

    UNIQUE (experiment_id, user_id),

    FOREIGN KEY (experiment_id, environment_id)
        REFERENCES experiments (id, environment_id) ON DELETE CASCADE,
    FOREIGN KEY (variant_id, experiment_id)
        REFERENCES variants (id, experiment_id) ON DELETE CASCADE
);

-- Who did which event (every occurrence, raw)
CREATE TABLE conversions (
    id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    project_id          bigint NOT NULL,
    environment_id      bigint NOT NULL,
    goal_id bigint NOT NULL,
    user_id             text   NOT NULL CHECK (length(user_id) BETWEEN 1 AND 256),
    value               numeric,
    occurred_at         timestamptz NOT NULL,
    received_at         timestamptz NOT NULL DEFAULT now(),

    FOREIGN KEY (environment_id, project_id)
        REFERENCES environments (id, project_id) ON DELETE CASCADE,
    FOREIGN KEY (goal_id, project_id)
        REFERENCES goals (id, project_id) ON DELETE NO ACTION
);

CREATE INDEX conversions_lookup_idx
    ON conversions (environment_id, user_id, goal_id, occurred_at);

-- Which goals each experiment measures: one primary, any number secondary
CREATE TABLE experiment_goals (
    experiment_id bigint  NOT NULL,
    goal_id       bigint  NOT NULL,
    project_id    bigint  NOT NULL,
    is_primary    boolean NOT NULL DEFAULT false,
    created_at    timestamptz NOT NULL DEFAULT now(),

    PRIMARY KEY (experiment_id, goal_id),

    FOREIGN KEY (experiment_id, project_id)
        REFERENCES experiments (id, project_id) ON DELETE CASCADE,
    FOREIGN KEY (goal_id, project_id)
        REFERENCES goals (id, project_id) ON DELETE NO ACTION
);

CREATE UNIQUE INDEX one_primary_goal_per_experiment
    ON experiment_goals (experiment_id)
    WHERE is_primary;

GRANT SELECT, INSERT, UPDATE, DELETE ON goals TO app_user;
GRANT SELECT, INSERT, UPDATE ON exposures TO app_user;
GRANT SELECT, INSERT ON conversions TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON experiment_goals TO app_user;
