// MongoDB initialization script
db = db.getSiblingDB('deepiri');

// Create collections
db.createCollection('users');
db.createCollection('useritems');
db.createCollection('adventures');
db.createCollection('events');
db.createCollection('notifications');

// Create indexes for better performance
db.users.createIndex({ "email": 1 }, { unique: true });
db.users.createIndex({ "friends": 1 });

// User items indexes
db.useritems.createIndex({ "userId": 1 });
db.useritems.createIndex({ "userId": 1, "category": 1 });
db.useritems.createIndex({ "userId": 1, "metadata.isFavorite": 1 });
db.useritems.createIndex({ "userId": 1, "status": 1 });
db.useritems.createIndex({ "userId": 1, "location.source": 1 });
db.useritems.createIndex({ "metadata.tags": 1 });
db.useritems.createIndex({ "createdAt": -1 });
db.useritems.createIndex({ "metadata.isPublic": 1 });
db.useritems.createIndex({ "sharing.sharedWith.userId": 1 });

db.adventures.createIndex({ "userId": 1 });
db.adventures.createIndex({ "status": 1 });
db.adventures.createIndex({ "createdAt": -1 });

db.events.createIndex({ "location.latitude": 1, "location.longitude": 1 });
db.events.createIndex({ "startTime": 1 });
db.events.createIndex({ "type": 1 });
db.events.createIndex({ "hostUserId": 1 });

db.notifications.createIndex({ "userId": 1 });
db.notifications.createIndex({ "read": 1 });
db.notifications.createIndex({ "sentAt": -1 });

print('Database initialized with collections and indexes');

// Create a sample admin user (optional)
db.users.insertOne({
  name: "Admin User",
  email: "admin@deepiri.com",
  passwordHash: "$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi", // password: password
  preferences: {
    nightlife: "high",
    music: "high",
    food: "high",
    social: "high",
    solo: "medium"
  },
  friends: [],
  favoriteVenues: [],
  adventureHistory: [],
  badges: ["early_adopter"],
  points: 100,
  createdAt: new Date(),
  updatedAt: new Date()
});

print('Sample admin user created');
