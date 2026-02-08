# Deepiri Gamification System

## Overview

The Deepiri gamification system is a comprehensive productivity engine that transforms work into an engaging, game-like experience. It includes Momentum (XP system), Streaks, Boosts, Objectives, Odysseys, Seasons, and Rewards.

## Core Components

### 1. Momentum System

**Momentum** is the primary XP/leveling system that tracks skill mastery across different work activities.

#### Features:
- **Total Momentum**: Cumulative XP earned from all activities
- **Levels**: Exponential progression system (base 100, 1.5x growth factor)
- **Skill Mastery**: Tracks momentum across 8 categories:
  - Commits
  - Docs
  - Tasks
  - Reviews
  - Comments
  - Attendance
  - Features Shipped
  - Design Edits
- **Level History**: Records all level-ups with timestamps
- **Public Profile**: Showcase achievements and resume references

#### API Endpoints:
- `GET /momentum/:userId` - Get user momentum profile
- `POST /momentum/award` - Award momentum to a user
- `GET /momentum/ranking` - Get leaderboard
- `GET /momentum/:userId/rank` - Get user's rank

### 2. Streaks System

**Streaks** track consistency across different work dimensions.

#### Streak Types:
- **Daily**: Consecutive days of activity
- **Weekly**: Consecutive weeks of activity
- **Project**: Consecutive days on a specific project
- **PR**: Consecutive days with pull requests
- **Healthy**: Consecutive days without burnout

#### Features:
- Tracks current and longest streaks
- Can be cashed in for boost credits (minimum 7 days/weeks)
- Automatic streak breaking detection

#### API Endpoints:
- `GET /streaks/:userId` - Get all user streaks
- `POST /streaks/update` - Update a streak type
- `POST /streaks/cash-in` - Cash in a streak for boost credits

### 3. Boosts System

**Boosts** are temporary power-ups that enhance productivity.

#### Boost Types:
- **Focus**: Hide notifications for 60 minutes
- **Velocity**: AI autocompletes 2 tasks (30 min)
- **Clarity**: AI rewrites specs (45 min)
- **Debug**: AI fixes one bug instantly (20 min)
- **Cleanup**: AI cleans docs + structure (30 min)

#### Features:
- Boost credits system (earned from streaks/rewards)
- Daily autopilot time limits (default 60 minutes)
- Max concurrent boosts (default 1, max 3)
- Automatic expiration tracking

#### API Endpoints:
- `GET /boosts/:userId` - Get boost profile
- `POST /boosts/activate` - Activate a boost
- `POST /boosts/add-credits` - Add boost credits
- `GET /boosts/costs` - Get boost costs and durations

### 4. Objectives System

**Objectives** are tasks with momentum rewards and AI suggestions.

#### Features:
- Momentum rewards for completion
- Subtasks with individual rewards
- AI suggestions (task breakdown, optimization, resources, timeline)
- Auto-completion detection via commits/edits
- Linked to Odysseys and Seasons

#### API Endpoints:
- `POST /objectives` - Create an objective
- `GET /objectives/:userId` - Get user objectives
- `GET /objectives/detail/:id` - Get objective details
- `POST /objectives/:id/complete` - Complete an objective
- `PUT /objectives/:id` - Update an objective
- `DELETE /objectives/:id` - Delete an objective

### 5. Odysseys System

**Odysseys** are project workflows with milestones and progress tracking.

#### Features:
- Multiple scales (hours, day, week, month, custom)
- Minimum hours before selection (set by team leader)
- Multiple objectives linked to the odyssey
- Milestones with momentum rewards
- AI-generated project brief animations
- Progress maps with stages
- Auto-completion when all objectives/milestones done

#### API Endpoints:
- `POST /odysseys` - Create an odyssey
- `GET /odysseys/:userId` - Get user odysseys
- `GET /odysseys/detail/:id` - Get odyssey details
- `POST /odysseys/:id/objectives` - Add objective to odyssey
- `POST /odysseys/:id/milestones` - Add milestone
- `POST /odysseys/:id/milestones/:milestoneId/complete` - Complete milestone
- `PUT /odysseys/:id` - Update odyssey

### 6. Seasons System

**Seasons** represent sprint cycles or major deadline phases.

#### Features:
- Start/end dates with automatic status updates
- Sprint cycle configuration
- Season boosts (multipliers for momentum)
- Auto-generated highlights reel
- Top contributors tracking
- Linked to multiple odysseys

#### API Endpoints:
- `POST /seasons` - Create a season
- `GET /seasons` - Get seasons (with filters)
- `GET /seasons/:id` - Get season details
- `POST /seasons/:id/odysseys` - Add odyssey to season
- `POST /seasons/:id/boost` - Enable season boost
- `POST /seasons/:id/highlights` - Generate highlights reel

### 7. Rewards System

**Rewards** are earned from streaks, momentum milestones, seasons, and achievements.

#### Reward Types:
- **boost_credits**: Credits for activating boosts
- **momentum_bonus**: Bonus momentum points
- **skip_day**: Skip a day without breaking streaks
- **break_time**: 30-minute break credits
- **custom**: Custom rewards

#### Features:
- Automatic reward creation from streaks/momentum
- Expiration dates
- Claim tracking
- Source tracking (streak, momentum, season, achievement, manual)

#### API Endpoints:
- `POST /rewards` - Create a reward
- `GET /rewards/:userId` - Get user rewards
- `POST /rewards/:id/claim` - Claim a reward
- `GET /rewards/:userId/pending-count` - Get pending rewards count

## Data Models

### Momentum Model
```typescript
{
  userId: ObjectId
  totalMomentum: number
  currentLevel: number
  momentumToNextLevel: number
  skillMastery: {
    commits, docs, tasks, reviews, comments,
    attendance, featuresShipped, designEdits
  }
  levelHistory: Array<{level, reachedAt, totalMomentum}>
  achievements: Array<{achievementId, name, description, unlockedAt, showcaseable}>
  publicProfile: {
    displayMomentum: boolean
    showcaseAchievements: string[]
    resumeReferences: string[]
  }
}
```

### Streak Model
```typescript
{
  userId: ObjectId
  daily: {current, longest, lastDate, canCashIn}
  weekly: {current, longest, lastWeek, canCashIn}
  project: {current, longest, projectId, lastProjectDate, canCashIn}
  pr: {current, longest, lastPRDate, canCashIn}
  healthy: {current, longest, lastHealthyDate, canCashIn, consecutiveDaysWithoutBurnout}
  cashedInStreaks: Array<{streakType, cashedAt, streakValue, boostCreditsEarned}>
}
```

### Boost Model
```typescript
{
  userId: ObjectId
  activeBoosts: Array<{boostType, activatedAt, expiresAt, duration, metadata}>
  boostCredits: number
  boostHistory: Array<{boostType, activatedAt, expiredAt, duration, creditsUsed, source}>
  settings: {
    maxConcurrentBoosts: number
    maxAutopilotTimePerDay: number
    autopilotTimeUsedToday: number
    lastAutopilotReset: Date
  }
}
```

### Objective Model
```typescript
{
  userId: ObjectId
  title: string
  description?: string
  status: 'draft' | 'active' | 'completed' | 'cancelled'
  momentumReward: number
  deadline?: Date
  subtasks: Array<{id, title, completed, momentumReward}>
  aiSuggestions: Array<{suggestion, type, confidence}>
  completionData: {
    completedAt?: Date
    actualDuration?: number
    momentumEarned: number
    autoDetected: boolean
  }
  odysseyId?: ObjectId
  seasonId?: ObjectId
}
```

### Odyssey Model
```typescript
{
  userId: ObjectId
  organizationId?: ObjectId
  title: string
  description?: string
  scale: 'hours' | 'day' | 'week' | 'month' | 'custom'
  minimumHoursBeforeSelection?: number
  status: 'planning' | 'active' | 'completed' | 'paused' | 'cancelled'
  objectives: ObjectId[]
  milestones: Array<{id, title, description, completed, completedAt, momentumReward}>
  progress: {
    objectivesCompleted, totalObjectives,
    milestonesCompleted, totalMilestones,
    progressPercentage
  }
  aiGeneratedBrief: {animation?, summary, generatedAt}
  progressMap: {currentStage, stages: Array<{stageId, name, completed, completedAt}>}
  startDate: Date
  endDate?: Date
  seasonId?: ObjectId
}
```

### Season Model
```typescript
{
  userId: ObjectId
  organizationId?: ObjectId
  name: string
  description?: string
  startDate: Date
  endDate: Date
  sprintCycle?: string
  status: 'upcoming' | 'active' | 'completed'
  odysseys: ObjectId[]
  seasonBoosts: {
    enabled: boolean
    boostType?: string
    multiplier?: number
    description?: string
  }
  highlights: {
    totalMomentumEarned: number
    objectivesCompleted: number
    odysseysCompleted: number
    topContributors: Array<{userId, momentum, name?}>
    highlightsReel?: string
    generatedAt?: Date
  }
}
```

### Reward Model
```typescript
{
  userId: ObjectId
  rewardType: 'boost_credits' | 'momentum_bonus' | 'skip_day' | 'break_time' | 'custom'
  amount: number
  source: 'streak' | 'momentum' | 'season' | 'achievement' | 'manual'
  sourceId?: string
  description: string
  status: 'pending' | 'claimed' | 'expired'
  claimedAt?: Date
  expiresAt?: Date
}
```

## Integration Points

### Task Completion → Momentum
When a task is completed, award momentum:
```typescript
await momentumService.awardMomentum(userId, amount, 'tasks');
```

### Commit → Momentum + Streaks
On commit:
```typescript
await momentumService.awardMomentum(userId, 5, 'commits');
await streakService.updateDailyStreak(userId);
await streakService.updatePRStreak(userId);
```

### Objective Completion → Momentum + Rewards
When objective completed:
```typescript
await objectiveService.completeObjective(objectiveId);
// Automatically awards momentum and creates rewards if thresholds met
```

### Streak Cash-In → Boost Credits
```typescript
await streakService.cashInStreak(userId, 'daily');
// Creates boost credits reward automatically
```

## Usage Examples

### Award Momentum for Task Completion
```bash
POST /api/gamification/momentum/award
{
  "userId": "user123",
  "amount": 10,
  "source": "tasks"
}
```

### Update Daily Streak
```bash
POST /api/gamification/streaks/update
{
  "userId": "user123",
  "streakType": "daily"
}
```

### Activate Focus Boost
```bash
POST /api/gamification/boosts/activate
{
  "userId": "user123",
  "boostType": "focus",
  "source": "purchased"
}
```

### Create Objective
```bash
POST /api/gamification/objectives
{
  "userId": "user123",
  "title": "Build login system",
  "momentumReward": 50,
  "deadline": "2024-12-31T23:59:59Z"
}
```

### Create Odyssey
```bash
POST /api/gamification/odysseys
{
  "userId": "user123",
  "title": "Q4 Product Launch",
  "scale": "month",
  "minimumHoursBeforeSelection": 40
}
```

## Configuration

### Momentum Leveling
- Base momentum per level: 100
- Growth factor: 1.5x
- Formula: `momentumToNextLevel = 100 * (1.5 ^ (level - 1))`

### Boost Costs
- Focus: 5 credits (60 min)
- Velocity: 3 credits (30 min)
- Clarity: 4 credits (45 min)
- Debug: 2 credits (20 min)
- Cleanup: 3 credits (30 min)

### Streak Cash-In Minimums
- Daily: 7 days
- Weekly: 2 weeks
- Project: 3 days
- PR: 5 days
- Healthy: 7 days

## Future Enhancements

1. **AI-Generated Animations**: Integrate with animation service for odyssey briefs
2. **Public Social System**: GitHub-like profile showcasing momentum and achievements
3. **Role-Based Abilities**: Dynamic AI shortcuts based on user roles
4. **Advanced Analytics**: Predictive modeling for momentum trends
5. **Team Competitions**: Cross-team odyssey competitions
6. **Achievement System**: Expandable achievement framework

