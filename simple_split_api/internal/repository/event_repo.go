package repository

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"log/slog"

	"github.com/RealZimboGuy/budgetApp/internal/domain"
	"github.com/RealZimboGuy/budgetApp/internal/util"
)

// EventRepository handles database operations for events
type EventRepository struct {
	DB *util.Database
}

// NewEventRepository creates a new event repository
func NewEventRepository(db *util.Database) *EventRepository {
	return &EventRepository{
		DB: db,
	}
}

// Create adds a new event to the database
func (r *EventRepository) Create(ctx context.Context, event *domain.Event) error {
	query := `
		INSERT INTO events (event_id, linked_event_id, group_id, user_id, event_type, payload)
		VALUES ($1, $2, $3, $4, $5, $6)
		ON CONFLICT (event_id) DO NOTHING
	`

	var linkedEventID interface{}
	if event.LinkedEventID == "" {
		linkedEventID = nil
	} else {
		linkedEventID = event.LinkedEventID
	}

	result, err := r.DB.DB.ExecContext(
		ctx,
		query,
		event.EventID,
		linkedEventID,
		event.GroupID,
		event.UserID,
		string(event.EventType),
		event.Payload,
	)
	if err != nil {
		slog.Error("Error creating Event", "error", err)
		return fmt.Errorf("failed to create event: %w", err)
	}

	// Optional: detect duplicate insert (no-op)
	rowsAffected, err := result.RowsAffected()
	if err == nil && rowsAffected == 0 {
		// event already existed — not an error
		slog.Info("Event already existed", "eventID", event.EventID)
		return fmt.Errorf("event already existed: %w", err)
	}

	return nil
}

// GetByID retrieves an event by ID
func (r *EventRepository) GetByID(ctx context.Context, eventID string) (*domain.Event, error) {
	query := `
		SELECT event_id, group_id, user_id, event_type, payload, created_at
		FROM events
		WHERE event_id = $1
	`

	event := &domain.Event{}
	var eventTypeStr string
	err := r.DB.DB.QueryRowContext(ctx, query, eventID).Scan(
		&event.EventID,
		&event.GroupID,
		&event.UserID,
		&eventTypeStr,
		&event.Payload,
		&event.CreatedAt,
	)

	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, fmt.Errorf("event not found: %s", eventID)
		}
		return nil, fmt.Errorf("failed to get event: %w", err)
	}

	event.EventType = util.EventType(eventTypeStr)
	return event, nil
}

// GetByGroupID retrieves all events for a group
func (r *EventRepository) GetByGroupID(ctx context.Context, groupID string) ([]*domain.Event, error) {
	query := `
		SELECT event_id, group_id, user_id, event_type, payload, created_at
		FROM events
		WHERE group_id = $1
		ORDER BY created_at DESC
	`

	rows, err := r.DB.DB.QueryContext(ctx, query, groupID)
	if err != nil {
		return nil, fmt.Errorf("failed to query events: %w", err)
	}
	defer rows.Close()

	var events []*domain.Event
	for rows.Next() {
		event := &domain.Event{}
		var eventTypeStr string
		if err := rows.Scan(
			&event.EventID,
			&event.GroupID,
			&event.UserID,
			&eventTypeStr,
			&event.Payload,
			&event.CreatedAt,
		); err != nil {
			return nil, fmt.Errorf("failed to scan event row: %w", err)
		}
		event.EventType = util.EventType(eventTypeStr)
		events = append(events, event)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating event rows: %w", err)
	}

	return events, nil
}

// GetEventsByGroupAfterID retrieves events for a group with pagination support
// If afterEventID is "0", it returns the first batch of events
// Results are ordered chronologically (ascending by created_at)
func (r *EventRepository) GetEventsByGroupAfterID(ctx context.Context, groupID string, afterEventID string, limit int) ([]*domain.Event, error) {
	var query string
	var rows *sql.Rows
	var err error

	if afterEventID == "0" {
		// If afterEventID is "0", get the first batch of events
		query = `
			SELECT event_id, linked_event_id,group_id, user_id, event_type, payload, created_at
			FROM events
			WHERE group_id = $1
			ORDER BY created_at ASC
			LIMIT $2
		`
		rows, err = r.DB.DB.QueryContext(ctx, query, groupID, limit)
	} else {
		// Otherwise, get events after the specified event ID
		query = `
			SELECT e.event_id,e.linked_event_id, e.group_id, e.user_id, e.event_type, e.payload, e.created_at
			FROM events e
			JOIN events after_event ON after_event.event_id = $2
			WHERE e.group_id = $1
			  AND e.created_at > after_event.created_at
			ORDER BY e.created_at ASC
			LIMIT $3
		`
		rows, err = r.DB.DB.QueryContext(ctx, query, groupID, afterEventID, limit)
	}

	if err != nil {
		return nil, fmt.Errorf("failed to query events: %w", err)
	}
	defer rows.Close()

	var events []*domain.Event = make([]*domain.Event, 0)
	for rows.Next() {
		event := &domain.Event{}
		var eventTypeStr string
		var linkedEventID sql.NullString
		if err := rows.Scan(
			&event.EventID,
			&linkedEventID,
			&event.GroupID,
			&event.UserID,
			&eventTypeStr,
			&event.Payload,
			&event.CreatedAt,
		); err != nil {
			return nil, fmt.Errorf("failed to scan event row: %w", err)
		}
		if linkedEventID.Valid {
			event.LinkedEventID = linkedEventID.String
		}
		event.EventType = util.EventType(eventTypeStr)
		events = append(events, event)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating event rows: %w", err)
	}

	return events, nil
}

// GetAll retrieves all events
func (r *EventRepository) GetAll(ctx context.Context) ([]*domain.Event, error) {
	query := `
		SELECT event_id, group_id, user_id, event_type, payload, created_at
		FROM events
		ORDER BY created_at DESC
	`

	rows, err := r.DB.DB.QueryContext(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("failed to query events: %w", err)
	}
	defer rows.Close()

	var events []*domain.Event
	for rows.Next() {
		event := &domain.Event{}
		var eventTypeStr string
		if err := rows.Scan(
			&event.EventID,
			&event.GroupID,
			&event.UserID,
			&eventTypeStr,
			&event.Payload,
			&event.CreatedAt,
		); err != nil {
			return nil, fmt.Errorf("failed to scan event row: %w", err)
		}
		event.EventType = util.EventType(eventTypeStr)
		events = append(events, event)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating event rows: %w", err)
	}

	return events, nil
}

// Update updates an event's information
func (r *EventRepository) Update(ctx context.Context, event *domain.Event) error {
	query := `
		UPDATE events
		SET group_id = $1, user_id = $2, event_type = $3, payload = $4
		WHERE event_id = $5
	`

	result, err := r.DB.DB.ExecContext(ctx,
		query,
		event.GroupID,
		event.UserID,
		string(event.EventType),
		event.Payload,
		event.EventID,
	)
	if err != nil {
		return fmt.Errorf("failed to update event: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}

	if rowsAffected == 0 {
		return fmt.Errorf("event not found: %s", event.EventID)
	}

	return nil
}

// Delete removes an event from the database
func (r *EventRepository) Delete(ctx context.Context, eventID string) error {
	query := `
		DELETE FROM events
		WHERE event_id = $1
	`

	result, err := r.DB.DB.ExecContext(ctx, query, eventID)
	if err != nil {
		return fmt.Errorf("failed to delete event: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}

	if rowsAffected == 0 {
		return fmt.Errorf("event not found: %s", eventID)
	}

	return nil
}
