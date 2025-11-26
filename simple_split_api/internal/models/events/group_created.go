package domain

import (
	"time"
)

type GroupCreated struct {
	Name     string    `json:"name"`
	DateTime time.Time `json:"date_time"`
}
