package repository

import (
	"context"
	"database/sql"
	"errors"
	"fmt"

	"github.com/RealZimboGuy/budgetApp/internal/domain"
	"github.com/RealZimboGuy/budgetApp/internal/util"
)

// UserRepository handles database operations for users
type UserRepository struct {
	DB *util.Database
}

// NewUserRepository creates a new user repository
func NewUserRepository(db *util.Database) *UserRepository {
	return &UserRepository{
		DB: db,
	}
}

// Create adds a new user to the database
func (r *UserRepository) Create(ctx context.Context, user *domain.User) error {
	query := `
		INSERT INTO users (name)
		VALUES ($1)
		RETURNING user_id, created_at
	`

	err := r.DB.DB.QueryRowContext(ctx, query, user.Name).Scan(&user.UserID, &user.CreatedAt)
	if err != nil {
		return fmt.Errorf("failed to create user: %w", err)
	}

	return nil
}

// GetByID retrieves a user by ID
func (r *UserRepository) GetByID(ctx context.Context, userID string) (*domain.User, error) {
	query := `
		SELECT user_id, name, created_at
		FROM users
		WHERE user_id = $1
	`

	user := &domain.User{}
	err := r.DB.DB.QueryRowContext(ctx, query, userID).Scan(
		&user.UserID,
		&user.Name,
		&user.CreatedAt,
	)

	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, fmt.Errorf("user not found: %s", userID)
		}
		return nil, fmt.Errorf("failed to get user: %w", err)
	}

	return user, nil
}

// GetAll retrieves all users
func (r *UserRepository) GetAll(ctx context.Context) ([]*domain.User, error) {
	query := `
		SELECT user_id, name, created_at
		FROM users
		ORDER BY created_at DESC
	`

	rows, err := r.DB.DB.QueryContext(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("failed to query users: %w", err)
	}
	defer rows.Close()

	var users []*domain.User
	for rows.Next() {
		user := &domain.User{}
		if err := rows.Scan(
			&user.UserID,
			&user.Name,
			&user.CreatedAt,
		); err != nil {
			return nil, fmt.Errorf("failed to scan user row: %w", err)
		}
		users = append(users, user)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating user rows: %w", err)
	}

	return users, nil
}

// Update updates a user's information
func (r *UserRepository) Update(ctx context.Context, user *domain.User) error {
	query := `
		UPDATE users
		SET name = $1
		WHERE user_id = $2
	`

	result, err := r.DB.DB.ExecContext(ctx, query, user.Name, user.UserID)
	if err != nil {
		return fmt.Errorf("failed to update user: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}

	if rowsAffected == 0 {
		return fmt.Errorf("user not found: %s", user.UserID)
	}

	return nil
}

// Delete removes a user from the database
func (r *UserRepository) Delete(ctx context.Context, userID string) error {
	query := `
		DELETE FROM users
		WHERE user_id = $1
	`

	result, err := r.DB.DB.ExecContext(ctx, query, userID)
	if err != nil {
		return fmt.Errorf("failed to delete user: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}

	if rowsAffected == 0 {
		return fmt.Errorf("user not found: %s", userID)
	}

	return nil
}
