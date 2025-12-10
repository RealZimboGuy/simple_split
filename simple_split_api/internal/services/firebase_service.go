package services

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/RealZimboGuy/budgetApp/internal/domain"
	"github.com/RealZimboGuy/budgetApp/internal/repository"
)

// FirebaseService handles sending push notifications to Firebase
type FirebaseService struct {
	UserRepo    *repository.UserRepository
	FirebaseURL string
	APIKey      string
}

// NewFirebaseService creates a new Firebase service
func NewFirebaseService(userRepo *repository.UserRepository, apiKey string) *FirebaseService {
	return &FirebaseService{
		UserRepo:    userRepo,
		FirebaseURL: "https://fcm.googleapis.com/fcm/send",
		APIKey:      apiKey,
	}
}

type FirebaseNotification struct {
	Title string `json:"title"`
	Body  string `json:"body"`
}

type FirebaseMessage struct {
	To           string               `json:"to"`
	Notification FirebaseNotification `json:"notification"`
	Data         map[string]string    `json:"data,omitempty"`
}

// SendNotification sends a notification to a specific user
func (s *FirebaseService) SendNotification(ctx context.Context, userID, title, body string, data map[string]string) error {
	user, err := s.UserRepo.GetByID(ctx, userID)
	if err != nil {
		return fmt.Errorf("failed to get user: %w", err)
	}

	if user.FirebaseID == "" {
		// User doesn't have a Firebase token
		return fmt.Errorf("user %s doesn't have a Firebase token", userID)
	}

	message := FirebaseMessage{
		To: user.FirebaseID,
		Notification: FirebaseNotification{
			Title: title,
			Body:  body,
		},
		Data: data,
	}

	return s.sendMessage(message)
}

// SendNotificationToMultipleUsers sends a notification to multiple users
func (s *FirebaseService) SendNotificationToMultipleUsers(ctx context.Context, userIDs []string, title, body string, data map[string]string) {
	var wg sync.WaitGroup

	for _, userID := range userIDs {
		wg.Add(1)
		go func(uid string) {
			defer wg.Done()
			err := s.SendNotification(ctx, uid, title, body, data)
			if err != nil {
				log.Printf("Failed to send notification to user %s: %v", uid, err)
			}
		}(userID)
	}

	wg.Wait()
}

// sendMessage sends a Firebase message
func (s *FirebaseService) sendMessage(message FirebaseMessage) error {
	jsonData, err := json.Marshal(message)
	if err != nil {
		return fmt.Errorf("failed to marshal message: %w", err)
	}

	req, err := http.NewRequest("POST", s.FirebaseURL, bytes.NewBuffer(jsonData))
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", fmt.Sprintf("key=%s", s.APIKey))

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("failed to send request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("bad status: %s", resp.Status)
	}

	return nil
}

// ProcessExpenseCreatedEvent sends notifications for an ExpenseCreated event
func (s *FirebaseService) ProcessExpenseCreatedEvent(ctx context.Context, event *domain.Event, expense interface{}) error {
	// Extract PaidBy and PaidFor user IDs
	expenseData, ok := expense.(map[string]interface{})
	if !ok {
		return fmt.Errorf("invalid expense data format")
	}

	// Get all users who need to be notified
	var userIDs []string

	// Extract PaidBy users
	if paidBy, ok := expenseData["paid_by"].([]interface{}); ok {
		for _, user := range paidBy {
			if userData, ok := user.(map[string]interface{}); ok {
				if userID, ok := userData["user_id"].(string); ok {
					userIDs = append(userIDs, userID)
				}
			}
		}
	}

	// Extract PaidFor users
	if paidFor, ok := expenseData["paid_for"].([]interface{}); ok {
		for _, user := range paidFor {
			if userData, ok := user.(map[string]interface{}); ok {
				if userID, ok := userData["user_id"].(string); ok {
					// Check if this user is already in our list
					found := false
					for _, id := range userIDs {
						if id == userID {
							found = true
							break
						}
					}
					if !found {
						userIDs = append(userIDs, userID)
					}
				}
			}
		}
	}

	// Get expense description
	description := "New expense"
	if desc, ok := expenseData["description"].(string); ok {
		description = desc
	}

	// Prepare data for the notification
	title := "New Expense Added"
	body := fmt.Sprintf("%s - %s", description, event.GroupID)
	
	data := map[string]string{
		"event_id": event.EventID,
		"group_id": event.GroupID,
		"type":     "expense_created",
	}

	// Send notifications in goroutines
	go s.SendNotificationToMultipleUsers(context.Background(), userIDs, title, body, data)

	return nil
}
