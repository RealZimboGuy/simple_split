package controllers

import (
	"encoding/json"
	"log"
	"net/http"

	"github.com/RealZimboGuy/budgetApp/internal/domain"
	"github.com/RealZimboGuy/budgetApp/internal/repository"
)

// GroupController handles HTTP requests related to groups
type GroupController struct {
	GroupRepo *repository.GroupRepository
}

// NewGroupController creates a new group controller
func NewGroupController(groupRepo *repository.GroupRepository) *GroupController {
	return &GroupController{
		GroupRepo: groupRepo,
	}
}

// CreateGroup handles group creation requests
func (c *GroupController) CreateGroup(w http.ResponseWriter, r *http.Request) {
	// Parse request body
	var reqBody struct {
		Name string `json:"name"`
	}

	err := json.NewDecoder(r.Body).Decode(&reqBody)
	if err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	// Validate request
	if reqBody.Name == "" {
		http.Error(w, "Name is required", http.StatusBadRequest)
		return
	}

	// Create group
	group := domain.NewGroup(reqBody.Name)
	err = c.GroupRepo.Create(r.Context(), group)
	if err != nil {
		log.Printf("Failed to create group: %v", err)
		http.Error(w, "Failed to create group", http.StatusInternalServerError)
		return
	}

	// Return created group
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(group)
}

// GetGroup handles group retrieval requests
func (c *GroupController) GetGroup(w http.ResponseWriter, r *http.Request) {
	// Get group ID from URL
	groupID := r.URL.Query().Get("id")
	if groupID == "" {
		http.Error(w, "Group ID is required", http.StatusBadRequest)
		return
	}

	// Get group
	group, err := c.GroupRepo.GetByID(r.Context(), groupID)
	if err != nil {
		log.Printf("Failed to get group: %v", err)
		http.Error(w, "Failed to get group", http.StatusNotFound)
		return
	}

	// Return group
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(group)
}

// GetAllGroups handles requests to get all groups
func (c *GroupController) GetAllGroups(w http.ResponseWriter, r *http.Request) {
	// Get all groups
	groups, err := c.GroupRepo.GetAll(r.Context())
	if err != nil {
		log.Printf("Failed to get groups: %v", err)
		http.Error(w, "Failed to get groups", http.StatusInternalServerError)
		return
	}

	// Return groups
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(groups)
}

// UpdateGroup handles group update requests
func (c *GroupController) UpdateGroup(w http.ResponseWriter, r *http.Request) {
	// Get group ID from URL
	groupID := r.URL.Query().Get("id")
	if groupID == "" {
		http.Error(w, "Group ID is required", http.StatusBadRequest)
		return
	}

	// Parse request body
	var reqBody struct {
		Name string `json:"name"`
	}

	err := json.NewDecoder(r.Body).Decode(&reqBody)
	if err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	// Validate request
	if reqBody.Name == "" {
		http.Error(w, "Name is required", http.StatusBadRequest)
		return
	}

	// Update group
	group := &domain.Group{
		GroupID: groupID,
		Name:    reqBody.Name,
	}

	err = c.GroupRepo.Update(r.Context(), group)
	if err != nil {
		log.Printf("Failed to update group: %v", err)
		http.Error(w, "Failed to update group", http.StatusInternalServerError)
		return
	}

	// Return updated group
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(group)
}

// DeleteGroup handles group deletion requests
func (c *GroupController) DeleteGroup(w http.ResponseWriter, r *http.Request) {
	// Get group ID from URL
	groupID := r.URL.Query().Get("id")
	if groupID == "" {
		http.Error(w, "Group ID is required", http.StatusBadRequest)
		return
	}

	// Delete group
	err := c.GroupRepo.Delete(r.Context(), groupID)
	if err != nil {
		log.Printf("Failed to delete group: %v", err)
		http.Error(w, "Failed to delete group", http.StatusInternalServerError)
		return
	}

	// Return success
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"message":"Group deleted successfully"}`))
}

// GetGroupsByUser handles requests to get all groups for a user
func (c *GroupController) GetGroupsByUser(w http.ResponseWriter, r *http.Request) {
	// Get user ID from URL
	userID := r.URL.Query().Get("user_id")
	if userID == "" {
		http.Error(w, "User ID is required", http.StatusBadRequest)
		return
	}

	// Get groups for user
	groups, err := c.GroupRepo.GetByUserID(r.Context(), userID)
	if err != nil {
		log.Printf("Failed to get groups for user: %v", err)
		http.Error(w, "Failed to get groups", http.StatusInternalServerError)
		return
	}

	// Return groups
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(groups)
}
