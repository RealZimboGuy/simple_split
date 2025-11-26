package repository

import (
	"context"
	"database/sql"
	"errors"
	"fmt"

	"github.com/RealZimboGuy/budgetApp/internal/domain"
	"github.com/RealZimboGuy/budgetApp/internal/util"
)

// GroupRepository handles database operations for groups
type GroupRepository struct {
	DB *util.Database
}

// NewGroupRepository creates a new group repository
func NewGroupRepository(db *util.Database) *GroupRepository {
	return &GroupRepository{
		DB: db,
	}
}

// Create adds a new group to the database
func (r *GroupRepository) Create(ctx context.Context, group *domain.Group) error {
	query := `
		INSERT INTO groups (name)
		VALUES ($1)
		RETURNING group_id, created_at
	`

	err := r.DB.DB.QueryRowContext(ctx, query, group.Name).Scan(&group.GroupID, &group.CreatedAt)
	if err != nil {
		return fmt.Errorf("failed to create group: %w", err)
	}

	return nil
}

// GetByID retrieves a group by ID
func (r *GroupRepository) GetByID(ctx context.Context, groupID string) (*domain.Group, error) {
	query := `
		SELECT group_id, name, created_at
		FROM groups
		WHERE group_id = $1
	`

	group := &domain.Group{}
	err := r.DB.DB.QueryRowContext(ctx, query, groupID).Scan(
		&group.GroupID,
		&group.Name,
		&group.CreatedAt,
	)

	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, fmt.Errorf("group not found: %s", groupID)
		}
		return nil, fmt.Errorf("failed to get group: %w", err)
	}

	return group, nil
}

// GetAll retrieves all groups
func (r *GroupRepository) GetAll(ctx context.Context) ([]*domain.Group, error) {
	query := `
		SELECT group_id, name, created_at
		FROM groups
		ORDER BY created_at DESC
	`

	rows, err := r.DB.DB.QueryContext(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("failed to query groups: %w", err)
	}
	defer rows.Close()

	var groups []*domain.Group
	for rows.Next() {
		group := &domain.Group{}
		if err := rows.Scan(
			&group.GroupID,
			&group.Name,
			&group.CreatedAt,
		); err != nil {
			return nil, fmt.Errorf("failed to scan group row: %w", err)
		}
		groups = append(groups, group)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating group rows: %w", err)
	}

	return groups, nil
}

// Update updates a group's information
func (r *GroupRepository) Update(ctx context.Context, group *domain.Group) error {
	query := `
		UPDATE groups
		SET name = $1
		WHERE group_id = $2
	`

	result, err := r.DB.DB.ExecContext(ctx, query, group.Name, group.GroupID)
	if err != nil {
		return fmt.Errorf("failed to update group: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}

	if rowsAffected == 0 {
		return fmt.Errorf("group not found: %s", group.GroupID)
	}

	return nil
}

// Delete removes a group from the database
func (r *GroupRepository) Delete(ctx context.Context, groupID string) error {
	query := `
		DELETE FROM groups
		WHERE group_id = $1
	`

	result, err := r.DB.DB.ExecContext(ctx, query, groupID)
	if err != nil {
		return fmt.Errorf("failed to delete group: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}

	if rowsAffected == 0 {
		return fmt.Errorf("group not found: %s", groupID)
	}

	return nil
}

// GetByUserID retrieves all groups associated with a user
func (r *GroupRepository) GetByUserID(ctx context.Context, userID string) ([]*domain.Group, error) {
	query := `
		SELECT g.group_id, g.name, g.created_at
		FROM groups g
		INNER JOIN (
			SELECT DISTINCT group_id
			FROM events
			WHERE user_id = $1
		) e ON g.group_id = e.group_id
		ORDER BY g.created_at DESC
	`

	rows, err := r.DB.DB.QueryContext(ctx, query, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to query groups by user ID: %w", err)
	}
	defer rows.Close()

	var groups []*domain.Group
	for rows.Next() {
		group := &domain.Group{}
		if err := rows.Scan(
			&group.GroupID,
			&group.Name,
			&group.CreatedAt,
		); err != nil {
			return nil, fmt.Errorf("failed to scan group row: %w", err)
		}
		groups = append(groups, group)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating group rows: %w", err)
	}

	return groups, nil
}
