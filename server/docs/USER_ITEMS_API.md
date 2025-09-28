# User Items API Documentation

The User Items system allows users to store, manage, and organize various items they collect during their adventures and experiences.

## Overview

User Items can be:
- **Physical items**: Souvenirs, tickets, collectibles
- **Digital items**: Photos, videos, documents
- **Virtual items**: Badges, achievements, tokens
- **Memories**: Experience records, notes

## API Endpoints

### Base URL: `/api/user-items`

All endpoints require authentication via JWT token in the Authorization header:
```
Authorization: Bearer <your-jwt-token>
```

### Get User Items
```http
GET /api/user-items
```

**Query Parameters:**
- `category` (string): Filter by category (adventure_gear, collectible, badge, etc.)
- `status` (string): Filter by status (active, archived, deleted)
- `isFavorite` (boolean): Filter favorite items
- `isPublic` (boolean): Filter public items
- `tags` (string): Comma-separated tags to filter by
- `sort` (string): Sort field (createdAt, name, etc.)
- `order` (string): Sort order (asc, desc)
- `limit` (number): Number of items per page (default: 50)
- `page` (number): Page number (default: 1)

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "_id": "item_id",
      "name": "Concert Ticket",
      "description": "Amazing rock concert",
      "category": "ticket",
      "type": "physical",
      "rarity": "common",
      "value": {
        "points": 50,
        "coins": 0
      },
      "location": {
        "source": "event",
        "acquiredAt": "2023-12-01T20:00:00Z"
      },
      "metadata": {
        "tags": ["music", "concert"],
        "isFavorite": false,
        "isPublic": false
      },
      "createdAt": "2023-12-01T20:00:00Z"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 50,
    "total": 1
  }
}
```

### Create User Item
```http
POST /api/user-items
```

**Request Body:**
```json
{
  "name": "Adventure Badge",
  "description": "Completed first adventure",
  "category": "badge",
  "type": "achievement",
  "rarity": "rare",
  "value": {
    "points": 100,
    "coins": 50
  },
  "source": "adventure",
  "sourceId": "adventure_123",
  "sourceName": "Downtown Food Tour",
  "tags": ["adventure", "food"],
  "isPublic": false,
  "isFavorite": true,
  "notes": "Great experience!"
}
```

### Get Specific Item
```http
GET /api/user-items/:itemId
```

### Update User Item
```http
PUT /api/user-items/:itemId
```

**Request Body:** (partial update)
```json
{
  "name": "Updated Name",
  "metadata": {
    "isFavorite": true,
    "tags": ["updated", "tag"]
  }
}
```

### Toggle Favorite
```http
PATCH /api/user-items/:itemId/favorite
```

### Add Memory to Item
```http
POST /api/user-items/:itemId/memories
```

**Request Body:**
```json
{
  "title": "Great Adventure",
  "description": "Had an amazing time exploring the city",
  "emotion": "happy",
  "date": "2023-12-01T15:30:00Z"
}
```

### Share Item
```http
POST /api/user-items/:itemId/share
```

**Request Body:**
```json
{
  "sharedWith": [
    {
      "userId": "user_123",
      "permission": "view"
    }
  ],
  "isPublic": true
}
```

### Delete Item
```http
DELETE /api/user-items/:itemId?permanent=false
```

**Query Parameters:**
- `permanent` (boolean): If true, permanently deletes the item. If false (default), soft deletes.

### Get User Statistics
```http
GET /api/user-items/stats
```

**Response:**
```json
{
  "success": true,
  "data": {
    "totalItems": 25,
    "totalValue": 1250,
    "favoriteCount": 8,
    "categoryStats": [
      {
        "_id": "badge",
        "count": 10,
        "totalValue": 800,
        "favorites": 5
      }
    ],
    "rarityStats": [
      {
        "_id": "rare",
        "count": 3,
        "totalValue": 500
      }
    ],
    "recentItems": [...],
    "favoriteItems": [...]
  }
}
```

### Search Items
```http
GET /api/user-items/search?q=concert&category=ticket&limit=10
```

### Get Shared Items
```http
GET /api/user-items/shared
```

### Get Public Items (Community)
```http
GET /api/user-items/public?category=badge&limit=20
```

### Export Items
```http
GET /api/user-items/export?format=json
```

**Formats:** `json`, `csv`

### Bulk Create Items
```http
POST /api/user-items/bulk
```

**Request Body:**
```json
{
  "items": [
    {
      "name": "Item 1",
      "category": "collectible",
      "type": "physical"
    },
    {
      "name": "Item 2",
      "category": "badge",
      "type": "achievement"
    }
  ]
}
```

## Item Categories

- `adventure_gear`: Equipment and gear used in adventures
- `collectible`: General collectible items
- `badge`: Achievement badges and awards
- `achievement`: Accomplishment records
- `souvenir`: Travel and experience souvenirs
- `memory`: Memory records and notes
- `photo`: Photo items
- `ticket`: Event and experience tickets
- `certificate`: Certificates and credentials
- `virtual_item`: Virtual/digital items
- `reward`: Rewards and prizes
- `token`: Tokens and currencies
- `other`: Other items

## Item Types

- `physical`: Physical, tangible items
- `digital`: Digital files and content
- `virtual`: Virtual/game items
- `achievement`: Achievement records
- `badge`: Badge items
- `token`: Token items
- `memory`: Memory records
- `experience`: Experience records

## Rarity Levels

- `common`: Common items (default)
- `uncommon`: Uncommon items
- `rare`: Rare items
- `epic`: Epic items
- `legendary`: Legendary items

## Error Responses

All endpoints return error responses in the following format:

```json
{
  "success": false,
  "message": "Error description",
  "errors": ["Detailed error messages"]
}
```

Common HTTP status codes:
- `400`: Bad Request (validation errors)
- `401`: Unauthorized (missing or invalid token)
- `404`: Not Found (item not found)
- `500`: Internal Server Error

## Examples

### Creating an Adventure Souvenir
```javascript
const response = await fetch('/api/user-items', {
  method: 'POST',
  headers: {
    'Authorization': 'Bearer ' + token,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    name: 'Local Coffee Shop Mug',
    description: 'Beautiful handmade mug from the downtown coffee adventure',
    category: 'souvenir',
    type: 'physical',
    rarity: 'uncommon',
    value: { points: 75 },
    source: 'adventure',
    sourceId: 'adv_123',
    sourceName: 'Downtown Coffee Tour',
    acquiredLocation: {
      lat: 40.7128,
      lng: -74.0060,
      address: '123 Coffee St, New York, NY',
      venue: 'Local Brew Coffee'
    },
    media: {
      images: [{
        url: 'https://example.com/mug-photo.jpg',
        caption: 'My new favorite mug!',
        isPrimary: true
      }]
    },
    tags: ['coffee', 'adventure', 'souvenir'],
    notes: 'The barista was so friendly and told me about the local coffee culture!'
  })
});
```

### Getting User's Favorite Items
```javascript
const favorites = await fetch('/api/user-items?isFavorite=true&sort=createdAt&order=desc', {
  headers: {
    'Authorization': 'Bearer ' + token
  }
});
```
