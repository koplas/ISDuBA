-- This file is Free Software under the Apache-2.0 License
-- without warranty, see README.md and LICENSES/Apache-2.0.txt for details.
--
-- SPDX-License-Identifier: Apache-2.0
--
-- SPDX-FileCopyrightText: 2024 German Federal Office for Information Security (BSI) <https://www.bsi.bund.de>
-- Software-Engineering: 2024 Intevation GmbH <https://intevation.de>

CREATE TABLE mentioned (
    who         varchar NOT NULL,
    comments_id int NOT NULL REFERENCES comments(id) ON DELETE CASCADE,
    UNIQUE (who, comments_id)
);

CREATE INDEX ON mentioned(comments_id);

INSERT INTO mentioned (who, comments_id)
    SELECT regexp_matches(message, '@([\w\d_]+)', 'g'), id
    FROM comments ON CONFLICT DO NOTHING;

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

GRANT INSERT, DELETE, SELECT, UPDATE ON mentioned TO {{ .User | sanitize }};
