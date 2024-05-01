// This file is Free Software under the Apache-2.0 License
// without warranty, see README.md and LICENSES/Apache-2.0.txt for details.
//
// SPDX-License-Identifier: Apache-2.0
//
// SPDX-FileCopyrightText: 2024 German Federal Office for Information Security (BSI) <https://www.bsi.bund.de>
// Software-Engineering: 2024 Intevation GmbH <https://intevation.de>

package models

// StoredQuery represents a stored query.
type StoredQuery struct {
	ID          int64     `json:"id"`
	Advisories  bool      `json:"advisories"`
	Definer     string    `json:"definer"`
	Gobal       bool      `json:"global"`
	Name        string    `json:"name"`
	Description *string   `json:"description,omitempty"`
	Query       string    `json:"query"`
	Num         int64     `json:"num"`
	Columns     []string  `json:"columns"`
	Orders      *[]string `json:"orders,omitempty"`
}
