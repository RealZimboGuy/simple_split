package events

import (
	"time"
)

type GroupUserJoin struct {
	Name     string    `json:"name"`
	UserId   string    `json:"user_id"`
	DateTime time.Time `json:"date_time"`
}
