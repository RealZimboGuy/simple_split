package services

import (
	"bytes"
	"context"
	"crypto"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"io/ioutil"
	"log"
	"log/slog"
	"net/http"
	"os"
	"sync"
	"time"

	"github.com/RealZimboGuy/budgetApp/internal/domain"
	"github.com/RealZimboGuy/budgetApp/internal/models/events"
	"github.com/RealZimboGuy/budgetApp/internal/repository"
)

// FirebaseService handles sending push notifications to Firebase
type FirebaseService struct {
	UserRepo *repository.UserRepository
}

type ServiceAccount struct {
	PrivateKey  string `json:"private_key"`
	ClientEmail string `json:"client_email"`
}

// NewFirebaseService creates a new Firebase service
func NewFirebaseService(userRepo *repository.UserRepository, apiKey string) *FirebaseService {
	return &FirebaseService{
		UserRepo: userRepo,
	}
}

type FCMRequest struct {
	Message FirebaseMessage `json:"message"`
}
type FirebaseNotification struct {
	Title string `json:"title"`
	Body  string `json:"body"`
}

type FirebaseMessage struct {
	Token        string               `json:"token"`
	Notification FirebaseNotification `json:"notification"`
	//Data         map[string]string    `json:"data,omitempty"`
}

// SendNotification sends a notification to a specific user
func (s *FirebaseService) SendNotification(ctx context.Context, userID, title, body string, data map[string]string, accessToken string) error {
	user, err := s.UserRepo.GetByID(ctx, userID)
	if err != nil {
		slog.Error("Failed to get user", "error", err)
		return fmt.Errorf("failed to get user: %w", err)
	}

	if !user.FirebaseID.Valid || user.FirebaseID.String == "" {
		// User doesn't have a Firebase token
		slog.Warn("User doesn't have a Firebase token", "user_id", userID)
		return fmt.Errorf("user %s doesn't have a Firebase token", userID)
	}

	message := FirebaseMessage{
		Token: user.FirebaseID.String,
		Notification: FirebaseNotification{
			Title: title,
			Body:  body,
		},
		//Data: data,
	}

	return s.sendMessage(message, accessToken)
}

// SendNotificationToMultipleUsers sends a notification to multiple users
func (s *FirebaseService) SendNotificationToMultipleUsers(ctx context.Context, userIDs []string, title, body string, data map[string]string) {

	slog.Info("Sending notification to multiple users", "user_ids", userIDs)

	err, accessToken := authenticateGoogle()

	if err != nil {
		slog.Error("Failed to authenticate with Google", "error", err)
		return
	}

	var wg sync.WaitGroup

	for _, userID := range userIDs {
		wg.Add(1)
		go func(uid string) {
			defer wg.Done()
			err := s.SendNotification(ctx, uid, title, body, data, accessToken)
			if err != nil {
				log.Printf("Failed to send notification to user %s: %v", uid, err)
			}
		}(userID)
	}

	wg.Wait()
}

// sendMessage sends a Firebase message
func (s *FirebaseService) sendMessage(message FirebaseMessage, token string) error {

	fcmRequest := FCMRequest{Message: message}

	slog.Info("Sending Firebase message", "message", fcmRequest)
	jsonData, err := json.Marshal(fcmRequest)
	if err != nil {
		return fmt.Errorf("failed to marshal message: %w", err)
	}

	firebaseUrl := os.Getenv("FIREBASE_URL")
	if firebaseUrl == "" {
		return fmt.Errorf("FIREBASE_URL environment variable is not set")
	}
	slog.Info("Sending Firebase message", "firebase_url", firebaseUrl)

	req, err := http.NewRequest("POST", firebaseUrl, bytes.NewBuffer(jsonData))
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", token))

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("failed to send request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		//rpint the body if it exists
		body, _ := ioutil.ReadAll(resp.Body)
		slog.Error("Failed to send Firebase message", "status", resp.Status, "body", string(body))
		return fmt.Errorf("bad status: %s", resp.Status)
	}

	return nil
}

// ProcessExpenseCreatedEvent sends notifications for an ExpenseCreated event
func (s *FirebaseService) ProcessExpenseCreatedEvent(ctx context.Context, event *domain.Event, expense interface{}) error {
	// Extract PaidBy and PaidFor user IDs

	//parse out the event payload to ExpenseCreated
	var expenseCreated events.ExpenseCreated
	json.Unmarshal(event.Payload, &expenseCreated)

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

	// Prepare data for the notification
	title := "New Expense Added"
	body := fmt.Sprintf("%s - %s - %.2f", expenseCreated.Description, expenseCreated.Currency, expenseCreated.Total)
	data := map[string]string{
		"event_id": event.EventID,
		"group_id": event.GroupID,
		"type":     "expense_created",
	}

	// Send notifications in goroutines
	go s.SendNotificationToMultipleUsers(context.Background(), userIDs, title, body, data)

	return nil
}

func authenticateGoogle() (error, string) {
	data := os.Getenv("GOOGLE_SERVICE_ACCOUNT")
	if data == "" {
		return errors.New("GOOGLE_SERVICE_ACCOUNT environment variable is not set"), ""
	}

	var sa ServiceAccount
	if err := json.Unmarshal([]byte(data), &sa); err != nil {
		panic(err)
	}

	// Parse private key
	block, _ := pem.Decode([]byte(sa.PrivateKey))
	if block == nil {
		panic("failed to parse PEM block")
	}
	privKey, err := x509.ParsePKCS8PrivateKey(block.Bytes)
	if err != nil {
		panic(err)
	}
	rsaPrivKey := privKey.(*rsa.PrivateKey)

	// Create JWT header
	header := base64URLEncode([]byte(`{"alg":"RS256","typ":"JWT"}`))

	// Create JWT claim
	now := time.Now().Unix()
	claim := fmt.Sprintf(`{
		"iss":"%s",
		"scope":"https://www.googleapis.com/auth/firebase.messaging",
		"aud":"https://oauth2.googleapis.com/token",
		"iat":%d,
		"exp":%d
	}`, sa.ClientEmail, now, now+3600)
	payload := base64URLEncode([]byte(claim))

	// Sign JWT
	hashed := sha256.Sum256([]byte(header + "." + payload))
	signature, err := rsa.SignPKCS1v15(rand.Reader, rsaPrivKey, crypto.SHA256, hashed[:])
	if err != nil {
		panic(err)
	}
	jwt := header + "." + payload + "." + base64URLEncode(signature)

	// Exchange JWT for access token
	form := fmt.Sprintf("grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=%s", jwt)
	resp, err := http.Post("https://oauth2.googleapis.com/token",
		"application/x-www-form-urlencoded",
		bytes.NewBuffer([]byte(form)))
	if err != nil {
		panic(err)
	}
	defer resp.Body.Close()
	body, _ := ioutil.ReadAll(resp.Body)
	var tokenResp map[string]interface{}
	json.Unmarshal(body, &tokenResp)
	accessToken := tokenResp["access_token"].(string)
	return err, accessToken
}

func base64URLEncode(data []byte) string {
	s := base64.URLEncoding.EncodeToString(data)
	return string(bytes.TrimRight([]byte(s), "="))
}
