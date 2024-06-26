// This file is Free Software under the Apache-2.0 License
// without warranty, see README.md and LICENSES/Apache-2.0.txt for details.
//
// SPDX-License-Identifier: Apache-2.0
//
// SPDX-FileCopyrightText: 2024 German Federal Office for Information Security (BSI) <https://www.bsi.bund.de>
// Software-Engineering: 2024 Intevation GmbH <https://intevation.de>

package web

import (
	"context"
	"errors"
	"log/slog"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/ISDuBA/ISDuBA/pkg/models"
)

type advisoryState struct {
	Publisher  string          `uri:"publisher" binding:"required" json:"publisher"`
	TrackingID string          `uri:"trackingid" binding:"required" json:"tracking_id"`
	State      models.Workflow `uri:"state" binding:"required" json:"state"`
}

type advisoryStates []advisoryState

func (c *Controller) changeStatusAll(ctx *gin.Context, inputs advisoryStates) {

	const (
		findAdvisory = `SELECT id, state::text, tlp ` +
			`FROM advisories ads ` +
			`JOIN documents docs ON (ads.tracking_id, ads.publisher) = (docs.tracking_id, docs.Publisher) ` +
			`WHERE docs.publisher = $1 AND docs.tracking_id = $2`
		updateState = `UPDATE advisories SET state = $1::workflow WHERE (tracking_id, publisher) = ($2, $3)`
		insertLog   = `INSERT INTO events_log (event, state, actor, documents_id) ` +
			`VALUES ('state_change', $1::workflow, $2, $3)`
	)

	var actor *string
	if !c.cfg.General.AnonymousEventLogging {
		uid := ctx.GetString("uid")
		actor = &uid
	}

	tlps := c.tlps(ctx)

	var forbidden, noTransition, bad bool

	if err := c.db.Run(
		ctx.Request.Context(),
		func(rctx context.Context, conn *pgxpool.Conn) error {
			tx, err := conn.BeginTx(rctx, pgx.TxOptions{})
			if err != nil {
				return err
			}
			defer tx.Rollback(rctx)

			for i := range inputs {
				var (
					input      = &inputs[i]
					documentID int64
					current    string
					tlp        string
				)

				if input.Publisher == "" || input.TrackingID == "" {
					bad = true
					return nil
				}
				slog.Debug("state change",
					"publisher", input.Publisher,
					"tracking_id", input.TrackingID,
					"state", input.State)

				if err := tx.QueryRow(rctx, findAdvisory, input.Publisher, input.TrackingID).Scan(
					&documentID, &current, &tlp,
				); err != nil {
					return err
				}

				// Check if we are allowed to access it.
				if len(tlps) > 0 && !tlps.Allowed(input.Publisher, models.TLP(tlp)) {
					forbidden = true
					return nil
				}

				slog.Debug("current state", "state", current)

				// Check if the transition is allowed to user.
				roles := models.Workflow(current).TransitionsRoles(input.State)
				if len(roles) == 0 {
					noTransition = true
					return nil
				}
				if !c.hasAnyRole(ctx, roles...) {
					forbidden = true
					return nil
				}

				// At this point the state change can be done.
				if _, err := tx.Exec(rctx, updateState,
					string(input.State), input.TrackingID, input.Publisher,
				); err != nil {
					return err
				}

				// Log the event
				if _, err := tx.Exec(rctx, insertLog, string(input.State), actor, documentID); err != nil {
					return err
				}
			}

			return tx.Commit(rctx)
		}, 0,
	); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			ctx.JSON(http.StatusNotFound, gin.H{"error": "advisory not found"})
		} else {
			slog.Error("state change failed", "err", err)
			ctx.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		}
		return
	}
	switch {
	case bad:
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "bad input"})
	case forbidden:
		ctx.JSON(http.StatusForbidden, gin.H{"error": "access denied"})
	case noTransition:
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "state transition not possible"})
	default:
		ctx.JSON(http.StatusOK, gin.H{"message": "transition done"})
	}
}

func (c *Controller) changeStatus(ctx *gin.Context) {
	var input advisoryState
	if err := ctx.ShouldBindUri(&input); err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.changeStatusAll(ctx, advisoryStates{input})
}

func (c *Controller) changeStatusBulk(ctx *gin.Context) {
	var inputs advisoryStates
	if err := ctx.ShouldBindJSON(&inputs); err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.changeStatusAll(ctx, inputs)
}
