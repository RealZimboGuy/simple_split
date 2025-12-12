package controllers

import (
	"encoding/json"
	"fmt"
	"log"
	"log/slog"
	"net/http"

	"github.com/RealZimboGuy/budgetApp/internal/domain"
	"github.com/RealZimboGuy/budgetApp/internal/repository"
)

// UserController handles HTTP requests related to users
type UserController struct {
	UserRepo *repository.UserRepository
}

// NewUserController creates a new user controller
func NewUserController(userRepo *repository.UserRepository) *UserController {
	return &UserController{
		UserRepo: userRepo,
	}
}

// CreateUser handles user creation requests
func (c *UserController) CreateUser(w http.ResponseWriter, r *http.Request) {
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

	// Create user
	user := domain.NewUser(reqBody.Name)
	err = c.UserRepo.Create(r.Context(), user)
	if err != nil {
		log.Printf("Failed to create user: %v", err)
		http.Error(w, "Failed to create user", http.StatusInternalServerError)
		return
	}

	// Return created user
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(user)
}

// GetUser handles user retrieval requests
func (c *UserController) GetUser(w http.ResponseWriter, r *http.Request) {
	// Get user ID from URL
	userID := r.URL.Query().Get("id")
	if userID == "" {
		http.Error(w, "User ID is required", http.StatusBadRequest)
		return
	}

	// Get user
	user, err := c.UserRepo.GetByID(r.Context(), userID)
	if err != nil {
		log.Printf("Failed to get user: %v", err)
		http.Error(w, "Failed to get user", http.StatusNotFound)
		return
	}

	// Return user
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(user)
}

// GetAllUsers handles requests to get all users
func (c *UserController) GetAllUsers(w http.ResponseWriter, r *http.Request) {
	// Get all users
	users, err := c.UserRepo.GetAll(r.Context())
	if err != nil {
		log.Printf("Failed to get users: %v", err)
		http.Error(w, "Failed to get users", http.StatusInternalServerError)
		return
	}

	// Return users
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(users)
}

// UpdateUser handles user update requests
func (c *UserController) UpdateUser(w http.ResponseWriter, r *http.Request) {
	// Get user ID from URL
	userID := r.URL.Query().Get("id")
	if userID == "" {
		http.Error(w, "User ID is required", http.StatusBadRequest)
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

	// Update user
	user := &domain.User{
		UserID: userID,
		Name:   reqBody.Name,
	}

	err = c.UserRepo.Update(r.Context(), user)
	if err != nil {
		log.Printf("Failed to update user: %v", err)
		http.Error(w, "Failed to update user", http.StatusInternalServerError)
		return
	}

	// Return updated user
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(user)
}

// DeleteUser handles user deletion requests
func (c *UserController) DeleteUser(w http.ResponseWriter, r *http.Request) {
	// Get user ID from URL
	userID := r.URL.Query().Get("id")
	if userID == "" {
		http.Error(w, "User ID is required", http.StatusBadRequest)
		return
	}

	// Delete user
	err := c.UserRepo.Delete(r.Context(), userID)
	if err != nil {
		log.Printf("Failed to delete user: %v", err)
		http.Error(w, "Failed to delete user", http.StatusInternalServerError)
		return
	}

	// Return success
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"message":"User deleted successfully"}`))
}

// RegisterFirebaseToken handles registration of a Firebase token for a user
func (c *UserController) RegisterFirebaseToken(w http.ResponseWriter, r *http.Request) {
	// Ensure this endpoint only accepts POST requests
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Get user ID from URL path
	userID := r.URL.Query().Get("id")
	if userID == "" {
		http.Error(w, "User ID is required", http.StatusBadRequest)
		return
	}

	// Parse request body
	var reqBody struct {
		Token string `json:"token"`
	}

	err := json.NewDecoder(r.Body).Decode(&reqBody)
	if err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	// Check if user exists
	_, err = c.UserRepo.GetByID(r.Context(), userID)
	if err != nil {
		slog.ErrorContext(r.Context(), fmt.Sprintf("User not found: %s", userID))
		http.Error(w, "User not found", http.StatusNotFound)
		return
	}

	// Update user's Firebase token (can be empty to unset/remove token)
	err = c.UserRepo.UpdateFirebaseID(r.Context(), userID, reqBody.Token)
	if err != nil {
		log.Printf("Failed to update Firebase token: %v", err)
		http.Error(w, "Failed to update Firebase token", http.StatusInternalServerError)
		return
	}

	// Return success
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"message":"Firebase token registered successfully"}`))
}
