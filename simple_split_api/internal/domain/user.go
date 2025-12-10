package domain

import (
	"time"
)

// User represents a user in the system
type User struct {
	UserID      string    `json:"user_id"`
	Name        string    `json:"name"`
	FirebaseID  string    `json:"firebase_id,omitempty"`
	CreatedAt   time.Time `json:"created_at"`
}

// NewUser creates a new user with the given name
func NewUser(name string) *User {
	return &User{
		Name:      name,
		CreatedAt: time.Now(),
	}
}
