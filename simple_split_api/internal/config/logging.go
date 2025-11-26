package config

import (
	"bytes"
	"fmt"
	"io"
	"log/slog"
	"net/http"
)

type loggingResponseWriter struct {
	http.ResponseWriter
	statusCode int
	body       bytes.Buffer
}

func LoggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if err := recover(); err != nil {
				slog.Error("Panic in LoggingMiddleware", "error", err, "path", r.URL.Path)
				// Re-panic so outer middleware can handle it
				panic(err)
			}
		}()

		// Log request details
		slog.Info(fmt.Sprintf("Request URL: %s, Method: %s", r.URL.String(), r.Method))
		body, err := io.ReadAll(r.Body)
		if err != nil {
			slog.Error("Failed to read request body: %v", "error", err)
		} else {
			slog.Debug(fmt.Sprintf("Request URL: %s, Method: %s, Body: %s", r.URL.String(), r.Method, string(body)))
		}
		r.Body = io.NopCloser(bytes.NewBuffer(body)) // Restore request body

		// Wrap ResponseWriter
		lrw := &loggingResponseWriter{ResponseWriter: w, statusCode: http.StatusOK}

		// Call the next handler
		next.ServeHTTP(lrw, r)

		// Log response details
		slog.Info(fmt.Sprintf("Response Status: %d, Body: %s", lrw.statusCode, lrw.body.String()), "status", lrw.statusCode, "body", lrw.body.String())
	})

}
func (lrw *loggingResponseWriter) WriteHeader(code int) {
	lrw.statusCode = code
	lrw.ResponseWriter.WriteHeader(code)
}

func (lrw *loggingResponseWriter) Write(data []byte) (int, error) {
	lrw.body.Write(data) // Capture response body
	return lrw.ResponseWriter.Write(data)
}
