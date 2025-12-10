# Simple Split API

## Overview

Simple Split API is a backend service for tracking and splitting expenses within groups. It provides a RESTful API for managing users, groups, and expenses.

## Firebase Push Notifications

The API supports sending push notifications to mobile devices using Firebase Cloud Messaging (FCM). When a new expense is created, notifications are automatically sent to all users who are involved in the expense (either as payers or payees).

### Setup

1. Set the `FIREBASE_API_KEY` environment variable with your Firebase Server API key:

```
export FIREBASE_API_KEY=your_firebase_server_api_key
```

2. Mobile clients can register their FCM tokens using the API endpoint:

```
POST /api/users/firebase/{userId}
Content-Type: application/json

{
  "token": "firebase_device_token"
}
```

3. When an expense is created with the event type `EXPENSE_CREATED`, notifications will automatically be sent to all users mentioned in the `paid_by` and `paid_for` fields.

### Notification Payload

Notifications include:
- Title: "New Expense Added"
- Body: Description of the expense and group ID
- Data: Event ID, Group ID, and event type

## Database Migration

Apply the database migration to add Firebase support:

```
psql -d your_database -f migrations/add_firebase_id.sql
```
