package domain

type PaidBy struct {
	UserID string  `json:"user_id"`
	Amount float64 `json:"amount"`
}

type PaidFor struct {
	UserID string  `json:"user_id"`
	Amount float64 `json:"amount"`
}

type ExpenseCreated struct {
	Description string    `json:"description"`
	DateTime    string    `json:"date_time"`
	SplitType   string    `json:"split_type"`
	Currency    string    `json:"currency"`
	Total       float64   `json:"total"`
	PaidBy      []PaidBy  `json:"paid_by"`
	PaidFor     []PaidFor `json:"paid_for"`
}
