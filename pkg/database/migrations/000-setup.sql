-- This file is Free Software under the MIT License
-- without warranty, see README.md and LICENSES/MIT.txt for details.
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
    'review', 'archive', 'delete');

CREATE FUNCTION utc_timestamp(text) RETURNS timestamp with time zone AS $$
    SELECT $1::timestamp with time zone AT time zone 'utc'
$$ LANGUAGE SQL IMMUTABLE;

CREATE FUNCTION revision_history_length(jsonb) RETURNS int AS $$
    SELECT jsonb_array_length(jsonb_path_query($1, '$.document.tracking.revision_history'))
$$ LANGUAGE SQL IMMUTABLE;

CREATE TABLE documents (
    id          int PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY,
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
    -- The data
    document    jsonb COMPRESSION lz4 NOT NULL,
    original    bytea COMPRESSION lz4 NOT NULL,

    UNIQUE (tracking_id, publisher, version, rev_history_length)
);

CREATE TABLE advisories (
    documents_id int UNIQUE NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    state        workflow NOT NULL DEFAULT 'new'
);


CREATE FUNCTION create_advisory() RETURNS trigger AS $$
    DECLARE
        old_id           int;
        old_rev_length   int;
        old_release_date timestamptz;
    BEGIN
        SELECT docs.id, docs.rev_history_length, docs.current_release_date
        INTO old_id, old_rev_length, old_release_date
        FROM  advisories ads JOIN documents docs ON ads.documents_id = docs.id
        WHERE docs.tracking_id = NEW.tracking_id AND docs.publisher = NEW.publisher;

        IF old_id IS NULL THEN
            INSERT INTO advisories (documents_id) VALUES (NEW.id);
        ELSIF NEW.current_release_date > old_release_date OR
              (NEW.current_release_date = old_release_date AND NEW.rev_history_length > old_rev_length)
        THEN
            UPDATE advisories SET (documents_id, state) = (NEW.id, 'new')
                WHERE documents_id = old_id;
        ELSE
            UPDATE advisories SET state = 'new' WHERE documents_id = old_id;
        END IF;
        RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER insert_document AFTER INSERT ON documents
    FOR EACH ROW EXECUTE FUNCTION create_advisory();

CREATE INDEX current_release_date_idx  ON documents (current_release_date);
CREATE INDEX initial_release_date_idx  ON documents (initial_release_date);

CREATE FUNCTION to_tsvector_multilang(text) RETURNS tsvector AS $$
    SELECT {{ range $idx, $lang := .TextSearch -}}
           {{ if $idx }} || {{ end }}to_tsvector({{ $lang | sqlQuote }}, $1)
           {{- end }}
$$ LANGUAGE SQL IMMUTABLE;

CREATE TABLE documents_texts (
    documents_id int NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    num          int NOT NULL,
    txt          text COMPRESSION lz4 NOT NULL,
    ts           tsvector COMPRESSION lz4
                 GENERATED ALWAYS AS (to_tsvector_multilang(txt)) STORED,
    UNIQUE(documents_id, num)
);

CREATE INDEX documents_texts_ts_idx ON documents_texts USING GIN (ts);

CREATE VIEW extended_documents AS SELECT
    *,
    (SELECT max(a::float) FROM
        jsonb_path_query(
            document, '$.vulnerabilities[*].scores[*].cvss_v2.baseScore') a)
        AS cvss_v2_score,
    (SELECT max(a::float) FROM
        jsonb_path_query(
            document, '$.vulnerabilities[*].scores[*].cvss_v3.baseScore') a)
        AS cvss_v3_score,
    (jsonb_path_query_array(
        document, '$.vulnerabilities[0 to 3]."cve"')) AS four_cves
    FROM documents;

CREATE TABLE comments (
    id           int PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY,
    documents_id int NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    time         timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    commentator  varchar NOT NULL,
    message      varchar(10000)
);

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
    documents_id int REFERENCES documents(id) ON DELETE SET NULL
);

GRANT SELECT ON versions TO {{ .User | sanitize }};
GRANT SELECT ON extended_documents TO {{ .User | sanitize }};
GRANT INSERT, DELETE, SELECT, UPDATE ON advisories TO {{ .User | sanitize }};
GRANT INSERT, DELETE, SELECT, UPDATE ON documents TO {{ .User | sanitize }};
GRANT INSERT, DELETE, SELECT, UPDATE ON documents_texts TO {{ .User | sanitize }};
GRANT INSERT, DELETE, SELECT, UPDATE ON comments TO {{ .User | sanitize }};
GRANT INSERT, DELETE, SELECT, UPDATE ON events_log TO {{ .User | sanitize }};
