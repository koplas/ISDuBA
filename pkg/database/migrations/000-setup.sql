-- This file is Free Software under the Apache-2.0 License
-- without warranty, see README.md and LICENSES/Apache-2.0.txt for details.
--
-- SPDX-License-Identifier: Apache-2.0
--
-- SPDX-FileCopyrightText: 2024 German Federal Office for Information Security (BSI) <https://www.bsi.bund.de>
-- Software-Engineering: 2024 Intevation GmbH <https://intevation.de>

CREATE TABLE versions (
    version     int PRIMARY KEY,
    description text NOT NULL,
    time        timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TYPE workflow AS ENUM (
    'new', 'read', 'assessing',
    'review', 'archived', 'delete');

CREATE TABLE advisories (
    tracking_id  text NOT NULL,
    publisher    text NOT NULL,
    state        workflow NOT NULL DEFAULT 'new',
    PRIMARY KEY(tracking_id, publisher)
);

CREATE FUNCTION utc_timestamp(text) RETURNS timestamp with time zone AS $$
    SELECT $1::timestamp with time zone AT time zone 'utc'
$$ LANGUAGE SQL IMMUTABLE;

CREATE FUNCTION revision_history_length(jsonb) RETURNS int AS $$
    SELECT jsonb_array_length(jsonb_path_query($1, '$.document.tracking.revision_history'))
$$ LANGUAGE SQL IMMUTABLE;

CREATE FUNCTION max_cvss2_score(jsonb) RETURNS float AS $$
    SELECT max(a::float) FROM
        jsonb_path_query(
            $1, '$.vulnerabilities[*].scores[*].cvss_v2.baseScore') a
$$ LANGUAGE SQL IMMUTABLE;

CREATE FUNCTION max_cvss3_score(jsonb) RETURNS float AS $$
    SELECT max(a::float) FROM
        jsonb_path_query(
            $1, '$.vulnerabilities[*].scores[*].cvss_v3.baseScore') a
$$ LANGUAGE SQL IMMUTABLE;

CREATE FUNCTION first_four_cves(jsonb) RETURNS jsonb AS $$
    SELECT jsonb_path_query_array(
        $1, '$.vulnerabilities[0 to 3]."cve"')
$$ LANGUAGE SQL IMMUTABLE;

CREATE TABLE documents (
    id          int PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY,
    latest      boolean,
    -- The 'kinda' primary key if we could version seriously.
    tracking_id text NOT NULL
                GENERATED ALWAYS AS (document #>> '{document,tracking,id}') STORED,
    publisher   text NOT NULL
                GENERATED ALWAYS AS (document #>> '{document,publisher,name}') STORED,
    version     text NOT NULL
                GENERATED ALWAYS AS (document #>> '{document,tracking,version}') STORED,
    -- Tracking dates
    current_release_date timestamptz
                GENERATED ALWAYS AS (
                utc_timestamp(document #>> '{document,tracking,current_release_date}')) STORED,
    initial_release_date timestamptz
                GENERATED ALWAYS AS (
                utc_timestamp(document #>> '{document,tracking,initial_release_date}')) STORED,
    -- Often used
    tlp         text
                GENERATED ALWAYS AS (document #>> '{document,distribution,tlp,label}') STORED,
    title       text
                GENERATED ALWAYS AS (document #>> '{document,title}') STORED,
    rev_history_length int
                GENERATED ALWAYS AS (revision_history_length(document)) STORED,
    cvss_v2_score float
                GENERATED ALWAYS AS (max_cvss2_score(document)) STORED,
    cvss_v3_score float
                GENERATED ALWAYS AS (max_cvss3_score(document)) STORED,
    four_cves   jsonb
                GENERATED ALWAYS AS (first_four_cves(document)) STORED,
    ssvc        text,
    -- The data
    document    jsonb COMPRESSION lz4 NOT NULL,
    original    bytea COMPRESSION lz4 NOT NULL,

    FOREIGN KEY (tracking_id, publisher)
        REFERENCES advisories(tracking_id, publisher)
        ON DELETE CASCADE
        DEFERRABLE INITIALLY DEFERRED,
    UNIQUE (tracking_id, publisher, version, rev_history_length)
);

CREATE UNIQUE INDEX only_one_latest_constraint
    ON documents (tracking_id, publisher)
    WHERE latest;

-- create_advisory checks if the new document is newer than the old one.
CREATE FUNCTION create_advisory() RETURNS trigger AS $$
    DECLARE
        old_id           int;
        old_rev_length   int;
        old_release_date timestamptz;
    BEGIN
        -- Ensure having an advisories record.
        INSERT INTO advisories (tracking_id, publisher)
            VALUES (NEW.tracking_id, NEW.publisher)
            ON CONFLICT (tracking_id, publisher) DO NOTHING;

        SELECT id, rev_history_length, current_release_date
            INTO old_id, old_rev_length, old_release_date
            FROM documents
            WHERE latest AND tracking_id = NEW.tracking_id AND publisher = NEW.publisher;

        IF NOT FOUND THEN -- No latest -> we are
            UPDATE documents SET latest = TRUE WHERE id = NEW.id;
        ELSE
            -- Check if the new record is in fact newer than the old one.
            IF NEW.current_release_date > old_release_date OR
               (NEW.current_release_date = old_release_date AND
                NEW.rev_history_length > old_rev_length)
            THEN
                -- Take over lead.
                UPDATE documents SET latest = FALSE WHERE id = old_id;
                UPDATE documents SET latest = TRUE  WHERE id = NEW.id;
            END IF;
        END IF;
        RETURN NULL;
    END;
$$ LANGUAGE plpgsql;

-- delete_advisory tries to re-establish an advisory after the last head was deleted.
CREATE FUNCTION delete_advisory() RETURNS trigger AS $$
    DECLARE
        lead_id int;
    BEGIN
        -- Update is only needed if deleted one was latest.
        IF OLD.latest THEN
            SELECT id
                INTO lead_id
                FROM documents
                WHERE tracking_id = OLD.tracking_id AND publisher = OLD.publisher
                ORDER BY current_release_date DESC, rev_history_length DESC;
            IF FOUND THEN
                UPDATE documents SET latest = TRUE WHERE id = lead_id;
            ELSE -- No documents for advisory -> Delete advisory.
                DELETE FROM advisories WHERE (tracking_id, publisher) = (OLD.tracking_id, OLD.publisher);
            END IF;
        END IF;
        RETURN NULL;
    END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER insert_document
    AFTER INSERT
    ON documents
    FOR EACH ROW EXECUTE FUNCTION create_advisory();

CREATE TRIGGER delete_document AFTER DELETE ON documents
    FOR EACH ROW EXECUTE FUNCTION delete_advisory();

CREATE INDEX current_release_date_idx ON documents (current_release_date);
CREATE INDEX initial_release_date_idx ON documents (initial_release_date);

CREATE INDEX documents_cvss2_idx ON documents(coalesce(cvss_v2_score, '0'::double precision) DESC);
CREATE INDEX documents_cvss3_idx ON documents(coalesce(cvss_v3_score, '0'::double precision) DESC);

CREATE FUNCTION to_tsvector_multilang(text) RETURNS tsvector AS $$
    SELECT {{ range $idx, $lang := .TextSearch -}}
           {{ if $idx }} || {{ end }}to_tsvector({{ $lang | sqlQuote }}, $1)
           {{- end }}
$$ LANGUAGE SQL IMMUTABLE;

CREATE TABLE unique_texts (
    id  int PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY,
    txt text COMPRESSION lz4 NOT NULL,
    ts  tsvector COMPRESSION lz4
        GENERATED ALWAYS AS (to_tsvector_multilang(txt)) STORED,
    EXCLUDE USING HASH (txt WITH =)
);

CREATE TABLE documents_texts (
    documents_id int NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    num          int NOT NULL,
    txt_id       int NOT NULL REFERENCES unique_texts(id) ON DELETE CASCADE,
    UNIQUE(documents_id, num)
);

CREATE INDEX documents_texts_ts_idx ON unique_texts USING GIN (ts);

CREATE TABLE comments (
    id           int PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY,
    documents_id int NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    time         timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    commentator  varchar NOT NULL,
    message      varchar(10000)
);

CREATE TABLE mentioned (
    who         varchar NOT NULL,
    comments_id int NOT NULL REFERENCES comments(id) ON DELETE CASCADE,
    UNIQUE (who, comments_id)
);

CREATE INDEX ON mentioned(comments_id);

CREATE FUNCTION update_mentioned() RETURNS trigger AS $$
    BEGIN
        DELETE FROM mentioned WHERE comments_id = NEW.id;
        INSERT INTO mentioned (who, comments_id)
            SELECT regexp_matches(NEW.message, '@([\w\d_]+)', 'g'), NEW.id
            ON CONFLICT DO NOTHING;
    END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER mentioned_update AFTER INSERT OR UPDATE ON comments
    FOR EACH ROW EXECUTE FUNCTION update_mentioned();

CREATE TYPE events AS ENUM (
    'import_document', 'delete_document',
    'state_change',
    'add_sscv', 'change_sscv', 'delete_sscv',
    'add_comment', 'change_comment', 'delete_comment'
);

CREATE TABLE events_log (
    event        events NOT NULL,
    state        workflow,
    time         timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actor        varchar,
    documents_id int REFERENCES documents(id) ON DELETE SET NULL,
    comments_id  int REFERENCES comments(id) ON DELETE SET NULL
);

--
-- user defined stored queries
--
CREATE TABLE stored_queries (
    id          int       PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY,
    advisories  bool      NOT NULL DEFAULT TRUE,
    definer     varchar   NOT NULL,
    global      boolean   NOT NULL DEFAULT FALSE,
    name        varchar   NOT NULL,
    description varchar,
    query       varchar   NOT NULL,
    num         int       NOT NULL GENERATED BY DEFAULT AS IDENTITY,
    columns     varchar[] NOT NULL,
    orders      varchar[],
    CHECK(name <> ''),
    UNIQUE (definer, name),
    UNIQUE (definer, num)
);

--
-- permissions
--
GRANT SELECT ON versions                                TO {{ .User | sanitize }};
GRANT INSERT, DELETE, SELECT, UPDATE ON advisories      TO {{ .User | sanitize }};
GRANT INSERT, DELETE, SELECT, UPDATE ON documents       TO {{ .User | sanitize }};
GRANT INSERT, DELETE, SELECT, UPDATE ON documents_texts TO {{ .User | sanitize }};
GRANT INSERT, DELETE, SELECT, UPDATE ON unique_texts    TO {{ .User | sanitize }};
GRANT INSERT, DELETE, SELECT, UPDATE ON comments        TO {{ .User | sanitize }};
GRANT INSERT, DELETE, SELECT, UPDATE ON events_log      TO {{ .User | sanitize }};
GRANT INSERT, DELETE, SELECT, UPDATE ON stored_queries  TO {{ .User | sanitize }};
GRANT INSERT, DELETE, SELECT, UPDATE ON mentioned       TO {{ .User | sanitize }};
