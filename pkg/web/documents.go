// This file is Free Software under the MIT License
// without warranty, see README.md and LICENSES/MIT.txt for details.
//
// SPDX-License-Identifier: MIT
//
// SPDX-FileCopyrightText: 2024 German Federal Office for Information Security (BSI) <https://www.bsi.bund.de>
// Software-Engineering: 2024 Intevation GmbH <https://intevation.de>

package web

import (
	"bytes"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"regexp"
	"strconv"
	"strings"
	"sync"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/ISDuBA/ISDuBA/pkg/database"
	"github.com/ISDuBA/ISDuBA/pkg/models"
)

// importDocument is an end point to import a document.
func (c *Controller) importDocument(ctx *gin.Context) {

	var actor *string
	if !c.cfg.General.AnonymousEventLogging {
		uid := ctx.GetString("uid")
		actor = &uid
	}

	file, err := ctx.FormFile("file")
	if err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error:": err})
		return
	}
	f, err := file.Open()
	if err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error:": err})
		return
	}
	limited := http.MaxBytesReader(
		ctx.Writer, f, int64(c.cfg.General.AdvisoryUploadLimit))
	defer limited.Close()

	rctx := ctx.Request.Context()

	var id int64

	if err = c.db.Run(rctx, func(conn *pgxpool.Conn) error {
		id, err = models.ImportDocument(
			rctx, conn, limited, actor, c.tlps(ctx), false)
		return err
	}); err != nil {
		switch {
		case errors.Is(err, models.ErrAlreadyInDatabase):
			ctx.JSON(http.StatusConflict, gin.H{"error": "already in database"})
		case errors.Is(err, models.ErrNotAllowed):
			ctx.JSON(http.StatusForbidden, gin.H{"error": "wrong publisher/tlp"})
		default:
			ctx.JSON(http.StatusBadRequest, gin.H{"error": err})
		}
		return
	}

	ctx.JSON(http.StatusCreated, gin.H{"id": id})
}

// viewDocument is an end point to export a document.
func (c *Controller) viewDocument(ctx *gin.Context) {
	idS := ctx.Param("id")
	id, err := strconv.ParseInt(idS, 10, 64)
	if err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": err})
		return
	}

	query := fmt.Sprintf("$id %d int =", id)
	expr, err := database.Parse(query)
	if err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error:": err})
		return
	}

	// Filter the allowed
	if tlps := c.tlps(ctx); len(tlps) > 0 {
		conditions := tlps.AsConditions()
		tlpExpr, err := database.Parse(conditions)
		if err != nil {
			slog.Warn("TLP filter failed", "err", err)
			ctx.JSON(http.StatusInternalServerError, gin.H{"error:": err})
			return
		}
		expr = expr.And(tlpExpr)
	}

	fields := []string{"original"}
	where, replacements, aliases := expr.Where()
	sql := database.CreateQuerySQL(fields, aliases, where, "", -1, -1)

	var original []byte

	rctx := ctx.Request.Context()
	if err := c.db.Run(rctx, func(conn *pgxpool.Conn) error {
		return conn.QueryRow(rctx, sql, replacements...).Scan(&original)
	}); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			ctx.JSON(http.StatusNotFound, gin.H{"error": "document not found"})
		} else {
			ctx.JSON(http.StatusInternalServerError, gin.H{"error": err})
		}
		return
	}

	extraHeaders := map[string]string{
		"Content-Disposition": `attachment; filename="document.json"`,
	}

	ctx.DataFromReader(
		http.StatusOK, int64(len(original)),
		"application/json",
		bytes.NewReader(original),
		extraHeaders)
}

// overviewDocuments is an end point to return an overview document.
func (c *Controller) overviewDocuments(ctx *gin.Context) {
	query := ctx.DefaultQuery("query", "true")
	expr, err := database.Parse(query)
	if err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error:": err})
		return
	}

	// Filter the allowed
	if tlps := c.tlps(ctx); len(tlps) > 0 {
		conditions := tlps.AsConditions()
		tlpExpr, err := database.Parse(conditions)
		if err != nil {
			slog.Warn("TLP filter failed", "err", err)
			ctx.JSON(http.StatusInternalServerError, gin.H{"error:": err})
			return
		}
		expr = expr.And(tlpExpr)
	}

	where, replacements, aliases := expr.Where()

	fields := strings.Fields(
		ctx.DefaultQuery("columns", "id title tracking_id version publisher"))

	if err := database.CheckProjections(fields, aliases); err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error:": err})
		return
	}

	orderFields := strings.Fields(
		ctx.DefaultQuery("order", "publisher tracking_id -version"))
	order, err := database.CreateOrder(orderFields, aliases)
	if err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error:": err})
		return
	}

	var (
		calcCount     bool
		count         int64
		limit, offset int64 = -1, -1
		results       []map[string]any
	)

	if count := ctx.Query("count"); count != "" {
		calcCount = true
	}

	if lim := ctx.Query("limit"); lim != "" {
		limit, err = strconv.ParseInt(lim, 10, 64)
		if err != nil {
			ctx.JSON(http.StatusBadRequest, gin.H{"error:": err})
			return
		}
	}

	if ofs := ctx.Query("offset"); ofs != "" {
		offset, err = strconv.ParseInt(ofs, 10, 64)
		if err != nil {
			ctx.JSON(http.StatusBadRequest, gin.H{"error:": err})
			return
		}
	}

	rctx := ctx.Request.Context()
	if err := c.db.Run(rctx, func(conn *pgxpool.Conn) error {
		if calcCount {
			if err := conn.QueryRow(
				rctx,
				database.CreateCountSQL(where, len(aliases) > 0),
				replacements...,
			).Scan(&count); err != nil {
				return fmt.Errorf("cannot calculate count %w", err)
			}
		}
		// Skip fields if they are not requested.
		if len(fields) == 0 {
			return nil
		}

		sql := database.CreateQuerySQL(fields, aliases, where, order, limit, offset)

		values := make([]any, len(fields))
		ptrs := make([]any, len(fields))
		for i := range ptrs {
			ptrs[i] = &values[i]
		}

		if slog.Default().Enabled(rctx, slog.LevelDebug) {
			slog.Debug("documents", "SQL", qndSQLReplace(sql, replacements))
		}
		rows, err := conn.Query(rctx, sql, replacements...)
		if err != nil {
			return fmt.Errorf("cannot fetch results: %w", err)
		}
		defer rows.Close()
		for rows.Next() {
			if err := rows.Scan(ptrs...); err != nil {
				return fmt.Errorf("scan failed: %w", err)
			}
			result := make(map[string]any, len(fields))
			for i, p := range fields {
				result[p] = values[i]
			}
			results = append(results, result)
		}
		return rows.Err()
	}); err != nil {
		slog.Warn("run failed", "err", err)
		ctx.JSON(http.StatusInternalServerError, gin.H{"error": err})
		return
	}

	h := gin.H{}
	if calcCount {
		h["count"] = count
	}
	if len(results) > 0 {
		h["documents"] = results
	}
	ctx.JSON(http.StatusOK, h)
}

var (
	dirtyReplace     *regexp.Regexp
	dirtyReplaceOnce sync.Once
)

// qndSQLReplace is a quick and dirty hack to re-substitute strings
// into SQL statements. Warning: USE FOR LOGGING ONLY!
// The separation SQL <-> replacements were done beforehand to
// prevent injections!
func qndSQLReplace(sql string, replacements []any) string {
	dirtyReplaceOnce.Do(func() {
		dirtyReplace = regexp.MustCompile(`\$([\d]+)`)
	})
	sql = dirtyReplace.ReplaceAllStringFunc(sql, func(s string) string {
		m := dirtyReplace.FindStringSubmatch(s)
		return `'%[` + m[1] + `]s'`
	})
	return fmt.Sprintf(sql, replacements...)
}
