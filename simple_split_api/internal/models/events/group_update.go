package events

import "time"

type GroupUpdate struct {
	Name     string    `json:"name"`
	DateTime time.Time `json:"date_time"`
}
