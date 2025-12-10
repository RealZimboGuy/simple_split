package domain

import (
	"database/sql"
	"encoding/json"
	"time"
)

// User represents a user in the system
type User struct {
	UserID      string         `json:"user_id"`
	Name        string         `json:"name"`
	FirebaseID  sql.NullString `json:"-"` // Use sql.NullString to handle null values
	CreatedAt   time.Time      `json:"created_at"`
}

// MarshalJSON is a custom JSON marshaler to handle the sql.NullString
func (u User) MarshalJSON() ([]byte, error) {
	type UserAlias User
	
	var firebaseID *string
	if u.FirebaseID.Valid {
		firebaseID = &u.FirebaseID.String
	}

	return json.Marshal(&struct {
		UserAlias
		FirebaseID *string `json:"firebase_id,omitempty"`
	}{
		UserAlias:  UserAlias(u),
		FirebaseID: firebaseID,
	})
}

// NewUser creates a new user with the given name
func NewUser(name string) *User {
	return &User{
		Name:      name,
		CreatedAt: time.Now(),
	}
}
