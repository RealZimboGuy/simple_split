package domain

import (
	"time"
)

type GroupAddCurrency struct {
	Currency string    `json:"currency"`
	DateTime time.Time `json:"date_time"`
}
