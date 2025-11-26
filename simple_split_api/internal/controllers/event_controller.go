package controllers

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"

	"github.com/RealZimboGuy/budgetApp/internal/domain"
	"github.com/RealZimboGuy/budgetApp/internal/repository"
	"github.com/RealZimboGuy/budgetApp/internal/util"
)

// EventController handles HTTP requests related to events
type EventController struct {
	EventRepo *repository.EventRepository
	UserRepo  *repository.UserRepository
	GroupRepo *repository.GroupRepository
}

// NewEventController creates a new event controller
func NewEventController(eventRepo *repository.EventRepository, userRepo *repository.UserRepository, groupRepo *repository.GroupRepository) *EventController {
	return &EventController{
		EventRepo: eventRepo,
		UserRepo:  userRepo,
		GroupRepo: groupRepo,
	}
}

// CreateEvent handles event creation requests
func (c *EventController) CreateEvent(w http.ResponseWriter, r *http.Request) {
	// Parse request body
	var reqBody struct {
		EventID       string          `json:"event_id"`
		LinkedEventID string          `json:"linked_event_id"`
		GroupID       string          `json:"group_id"`
		UserID        string          `json:"user_id"`
		EventType     string          `json:"event_type"`
		Payload       json.RawMessage `json:"payload"`
	}

	err := json.NewDecoder(r.Body).Decode(&reqBody)
	if err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	// Validate request
	if reqBody.EventID == "" {
		http.Error(w, "Event ID is required", http.StatusBadRequest)
		return
	}

	if reqBody.GroupID == "" {
		http.Error(w, "Group ID is required", http.StatusBadRequest)
		return
	}
	if reqBody.UserID == "" {
		http.Error(w, "User ID is required", http.StatusBadRequest)
		return
	}
	if reqBody.EventType == "" {
		http.Error(w, "Event type is required", http.StatusBadRequest)
		return
	}
	if len(reqBody.Payload) == 0 {
		http.Error(w, "Payload is required", http.StatusBadRequest)
		return
	}

	// Check if user exists
	_, err = c.UserRepo.GetByID(r.Context(), reqBody.UserID)
	if err != nil {
		http.Error(w, fmt.Sprintf("User not found:%s", reqBody.UserID), http.StatusBadRequest)
		return
	}

	// Check if group exists
	_, err = c.GroupRepo.GetByID(r.Context(), reqBody.GroupID)
	if err != nil {
		http.Error(w, "Group not found", http.StatusBadRequest)
		return
	}

	//if the event exists then return it as is already
	existing, err := c.EventRepo.GetByID(r.Context(), reqBody.EventID)
	if err == nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(existing)
		return
	}

	// Create event
	event := domain.NewEvent(
		reqBody.EventID,
		reqBody.LinkedEventID,
		reqBody.GroupID,
		reqBody.UserID,
		util.EventType(reqBody.EventType),
		reqBody.Payload,
	)

	err = c.EventRepo.Create(r.Context(), event)
	if err != nil {
		log.Printf("Failed to create event: %v", err)
		http.Error(w, "Failed to create event", http.StatusInternalServerError)
		return
	}

	// Return created event
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(event)
}

// GetEvent handles event retrieval requests
func (c *EventController) GetEvent(w http.ResponseWriter, r *http.Request) {
	// Get event ID from URL
	eventID := r.URL.Query().Get("id")
	if eventID == "" {
		http.Error(w, "Event ID is required", http.StatusBadRequest)
		return
	}

	// Get event
	event, err := c.EventRepo.GetByID(r.Context(), eventID)
	if err != nil {
		log.Printf("Failed to get event: %v", err)
		http.Error(w, "Failed to get event", http.StatusNotFound)
		return
	}

	// Return event
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(event)
}

// GetEventsByGroup handles requests to get events for a group
func (c *EventController) GetEventsByGroup(w http.ResponseWriter, r *http.Request) {
	// Get group ID from URL
	groupID := r.URL.Query().Get("group_id")
	if groupID == "" {
		http.Error(w, "Group ID is required", http.StatusBadRequest)
		return
	}

	// Get event ID to start from (or "0" for the beginning)
	afterEventID := r.URL.Query().Get("after_id")
	if afterEventID == "" {
		afterEventID = "0" // Default to start from the beginning
	}

	// Get events (limit to 1000)
	events, err := c.EventRepo.GetEventsByGroupAfterID(r.Context(), groupID, afterEventID, 1000)
	if err != nil {
		log.Printf("Failed to get events: %v", err)
		http.Error(w, "Failed to get events", http.StatusInternalServerError)
		return
	}

	// Return events as regular JSON array
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(events)
}

// GetAllEvents handles requests to get all events
func (c *EventController) GetAllEvents(w http.ResponseWriter, r *http.Request) {
	// Get all events
	events, err := c.EventRepo.GetAll(r.Context())
	if err != nil {
		log.Printf("Failed to get events: %v", err)
		http.Error(w, "Failed to get events", http.StatusInternalServerError)
		return
	}

	// Return events
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(events)
}

// DeleteEvent handles event deletion requests
func (c *EventController) DeleteEvent(w http.ResponseWriter, r *http.Request) {
	// Get event ID from URL
	eventID := r.URL.Query().Get("id")
	if eventID == "" {
		http.Error(w, "Event ID is required", http.StatusBadRequest)
		return
	}

	// Delete event
	err := c.EventRepo.Delete(r.Context(), eventID)
	if err != nil {
		log.Printf("Failed to delete event: %v", err)
		http.Error(w, "Failed to delete event", http.StatusInternalServerError)
		return
	}

	// Return success
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"message":"Event deleted successfully"}`))
}
