package controllers

import (
	"log/slog"
	"net/http"
	"os"
	"runtime/debug"

	"github.com/RealZimboGuy/budgetApp/internal/config"
	"github.com/RealZimboGuy/budgetApp/internal/repository"
	"github.com/RealZimboGuy/budgetApp/internal/services"
	"github.com/RealZimboGuy/budgetApp/internal/util"
)

// Router handles HTTP routing for the application
type Router struct {
	UserController  *UserController
	GroupController *GroupController
	EventController *EventController
	mux             *http.ServeMux
}

// NewRouter creates a new router with all controllers
func NewRouter(db *util.Database) *Router {
	// Create repositories
	userRepo := repository.NewUserRepository(db)
	groupRepo := repository.NewGroupRepository(db)
	eventRepo := repository.NewEventRepository(db)

	// Get Firebase API key from environment or use a default for development
	firebaseUrl := os.Getenv("FIREBASE_URL")

	// Create Firebase service if API key is provided
	var firebaseService *services.FirebaseService
	if firebaseUrl != "" {
		slog.Info("Firebase URL key found, initializing Firebase service")
		firebaseService = services.NewFirebaseService(userRepo, firebaseUrl)
	} else {
		slog.Warn("No Firebase URL key found, notifications will not be sent")
	}

	// Create controllers
	userController := NewUserController(userRepo)
	groupController := NewGroupController(groupRepo)
	eventController := NewEventController(eventRepo, userRepo, groupRepo, firebaseService)

	return &Router{
		UserController:  userController,
		GroupController: groupController,
		EventController: eventController,
		mux:             http.NewServeMux(),
	}
}

type Middleware func(http.Handler) http.Handler

// Chain combines middleware functions
func Chain(h http.Handler, middlewares ...Middleware) http.Handler {
	for i := len(middlewares) - 1; i >= 0; i-- {
		h = middlewares[i](h)
	}
	return h
}

// SetupRoutes configures all routes
func (r *Router) SetupRoutes() http.Handler {
	// User routes
	// fix: use Handle because Chain returns http.Handler
	r.mux.Handle("/api/users/create", Chain(http.HandlerFunc(r.UserController.CreateUser), config.LoggingMiddleware, PanicRecoveryMiddleware))
	r.mux.Handle("/api/users/get", Chain(http.HandlerFunc(r.UserController.GetUser), config.LoggingMiddleware, PanicRecoveryMiddleware))
	r.mux.Handle("/api/users/firebase", Chain(http.HandlerFunc(r.UserController.RegisterFirebaseToken), config.LoggingMiddleware, PanicRecoveryMiddleware))
	// Group routes
	r.mux.Handle("/api/groups/create", Chain(http.HandlerFunc(r.GroupController.CreateGroup), config.LoggingMiddleware, PanicRecoveryMiddleware))
	r.mux.Handle("/api/groups/get", Chain(http.HandlerFunc(r.GroupController.GetGroup), config.LoggingMiddleware, PanicRecoveryMiddleware))
	r.mux.Handle("/api/groups/by-user", Chain(http.HandlerFunc(r.GroupController.GetGroupsByUser), config.LoggingMiddleware, PanicRecoveryMiddleware))

	// Event routes
	r.mux.Handle("/api/events/create", Chain(http.HandlerFunc(r.EventController.CreateEvent), config.LoggingMiddleware, PanicRecoveryMiddleware))
	r.mux.Handle("/api/events/get", Chain(http.HandlerFunc(r.EventController.GetEvent), config.LoggingMiddleware, PanicRecoveryMiddleware))
	r.mux.Handle("/api/events/by-group", Chain(http.HandlerFunc(r.EventController.GetEventsByGroup), config.LoggingMiddleware, PanicRecoveryMiddleware))

	return r.mux
}

// ServeHTTP implements the http.Handler interface
func (r *Router) ServeHTTP(w http.ResponseWriter, req *http.Request) {
	r.mux.ServeHTTP(w, req)
}
func PanicRecoveryMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if err := recover(); err != nil {
				ctx := r.Context()
				// log the panic
				slog.ErrorContext(ctx, "Panic recovered",
					"error", err,
					"path", r.URL.Path,
				)
				// optionally print stack to stderr for diagnostics:
				debug.PrintStack()

				http.Error(w, "Internal Server Error", http.StatusInternalServerError)
			}
		}()

		next.ServeHTTP(w, r)
	})
}
