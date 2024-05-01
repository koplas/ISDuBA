-- This file is Free Software under the Apache-2.0 License
-- without warranty, see README.md and LICENSES/Apache-2.0.txt for details.
--
-- SPDX-License-Identifier: Apache-2.0
--
-- SPDX-FileCopyrightText: 2024 German Federal Office for Information Security (BSI) <https://www.bsi.bund.de>
-- Software-Engineering: 2024 Intevation GmbH <https://intevation.de>

CREATE TABLE stored_queries (
    id          int       PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY,
    advisories  bool      NOT NULL DEFAULT TRUE,
    definer     varchar   NOT NULL,
    global      boolean   NOT NULL DEFAULT FALSE,
    name        varchar   NOT NULL,
    description varchar   NOT NULL,
    query       varchar   NOT NULL,
    num         int       NOT NULL GENERATED BY DEFAULT AS IDENTITY,
    columns     varchar[],
    orders      varchar[],
    CHECK(name <> ''),
    UNIQUE (definer, name)
);

--
-- permissions
--
GRANT INSERT, DELETE, SELECT, UPDATE ON stored_queries TO {{ .User | sanitize }};
