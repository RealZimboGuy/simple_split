# Use the official Go image as the base image
FROM golang:1.24.3-alpine  AS build-stage

# Set the working directory inside the container
WORKDIR /goapp

# Copy the Go module files
COPY go.mod go.sum ./

# Download the dependencies
RUN go mod download

# Copy the rest of the application code
COPY . .

# Run tests
RUN go test ./... -v

# Build the Go application
RUN go build -o main ./cmd/simplesplit/main.go


# 3. Release stage
FROM gcr.io/distroless/base-debian12 AS release-stage
WORKDIR /goapp

# Copy built binary from build stage
COPY --from=build-stage /goapp/main ./main

# Expose port if needed
EXPOSE 8080

# Use non-root user
USER nonroot:nonroot

# Set the entrypoint to the binary
ENTRYPOINT ["./main"]
