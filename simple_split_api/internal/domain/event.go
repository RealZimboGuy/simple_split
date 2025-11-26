package domain

import (
	"encoding/json"
	"time"

	"github.com/RealZimboGuy/budgetApp/internal/util"
)

// Event represents an event in the system
type Event struct {
	EventID       string          `json:"event_id"`
	LinkedEventID string          `json:"linked_event_id"`
	GroupID       string          `json:"group_id"`
	UserID        string          `json:"user_id"`
	EventType     util.EventType  `json:"event_type"`
	Payload       json.RawMessage `json:"payload"`
	CreatedAt     time.Time       `json:"created_at"`
}

// NewEvent creates a new event
func NewEvent(eventId string, linkedEventId string, groupID string, userID string, eventType util.EventType, payload json.RawMessage) *Event {
	return &Event{
		EventID:       eventId,
		LinkedEventID: linkedEventId,
		GroupID:       groupID,
		UserID:        userID,
		EventType:     eventType,
		Payload:       payload,
		CreatedAt:     time.Now(),
	}
}
