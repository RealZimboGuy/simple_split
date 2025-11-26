package util

import (
	"database/sql"
	"encoding/json"
	"fmt"
)

// EventType defines the type of event
type EventType string

// Event types for CRUD operations
const (
	// Group events
	GroupCreate      EventType = "GROUP_CREATED"
	GroupAddCurrency EventType = "GROUP_ADD_CURRENCY"
	//UpdateGroup      EventType = "GROUP_UPDATE"
	GroupUserJoined EventType = "GROUP_USER_JOINED"

	UserNameChanged EventType = "USER_NAME_CHANGED"

	// Generic event
	ExpenseCreated EventType = "EXPENSE_CREATED"
	ExpenseUpdated EventType = "EXPENSE_UPDATED"
	ExpenseDeleted EventType = "EXPENSE_DELETED"
)

// Database represents a database connection
type Database struct {
	DB *sql.DB
}

// NewDatabase creates a new database connection
func NewDatabase(db *sql.DB) *Database {
	return &Database{
		DB: db,
	}
}

// ToJSON converts a struct to JSON
func ToJSON(v interface{}) (json.RawMessage, error) {
	data, err := json.Marshal(v)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal to JSON: %w", err)
	}
	return json.RawMessage(data), nil
}

// FromJSON converts JSON to a struct
func FromJSON(data json.RawMessage, v interface{}) error {
	if err := json.Unmarshal(data, v); err != nil {
		return fmt.Errorf("failed to unmarshal from JSON: %w", err)
	}
	return nil
}
