package main

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"log/slog"
	"net/http"
	"os"

	"github.com/RealZimboGuy/budgetApp/internal/controllers"
	"github.com/RealZimboGuy/budgetApp/internal/util"
	// Import postgres driver in a real application
	_ "github.com/lib/pq"
)

type googleHandler struct {
	slog.Handler
}

func main() {

	baseHandler := slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		AddSource: true,
		Level:     slog.LevelInfo,
	})

	logger := slog.New(&googleHandler{Handler: baseHandler})
	slog.SetDefault(logger)

	// Get database connection string from environment variable or use default
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		dbURL = "postgres://postgres:postgres@localhost:5432/budget_app?sslmode=disable"
	}

	// Connect to database
	db, err := sql.Open("postgres", dbURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer db.Close()

	// Check database connection
	if err := db.Ping(); err != nil {
		log.Fatalf("Failed to ping database: %v", err)
	}

	log.Println(fmt.Sprintf("Connected to database: %s", dbURL))

	// Create database wrapper
	database := util.NewDatabase(db)

	// Create router
	router := controllers.NewRouter(database)
	handler := router.SetupRoutes()

	// Get port from environment variable or use default
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	// Start server
	log.Printf("Starting server on port %s\n", port)
	if err := http.ListenAndServe(":"+port, handler); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}

func (h *googleHandler) Handle(ctx context.Context, r slog.Record) error {
	// Map slog level to Cloud severity
	var sev string
	switch {
	case r.Level >= slog.LevelError:
		sev = "ERROR"
	case r.Level >= slog.LevelWarn:
		sev = "WARNING"
	case r.Level >= slog.LevelInfo:
		sev = "INFO"
	case r.Level >= slog.LevelDebug:
		sev = "DEBUG"
	default:
		sev = "DEFAULT"
	}

	// Add Cloud Logging–compatible field
	r.AddAttrs(slog.String("severity", sev))

	// Call the wrapped handler
	return h.Handler.Handle(ctx, r)
}
