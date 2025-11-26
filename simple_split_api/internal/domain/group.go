package domain

import (
	"time"
)

// Group represents a group in the system
type Group struct {
	GroupID   string    `json:"group_id"`
	Name      string    `json:"name"`
	CreatedAt time.Time `json:"created_at"`
}

// NewGroup creates a new group with the given name
func NewGroup(name string) *Group {
	return &Group{
		Name:      name,
		CreatedAt: time.Now(),
	}
}
