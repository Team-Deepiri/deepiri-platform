# Beginner's Guide: Implementing API Request/Response Logging and Audit Trails

**Version:** 1.0  
**Date:** 2025-01-27  
**Target Audience:** New developers learning to implement logging and audit trails  
**Framework:** FastAPI (Python)

---

## Table of Contents

1. [What You'll Learn](#what-youll-learn)
2. [Prerequisites](#prerequisites)
3. [Understanding the Problem](#understanding-the-problem)
4. [Step 1: Understanding HTTP Requests and Responses](#step-1-understanding-http-requests-and-responses)
5. [Step 2: Understanding Middleware](#step-2-understanding-middleware)
6. [Step 3: Creating a Basic Request Logger](#step-3-creating-a-basic-request-logger)
7. [Step 4: Capturing Request Data](#step-4-capturing-request-data)
8. [Step 5: Capturing Response Data](#step-5-capturing-response-data)
9. [Step 6: Adding Request IDs](#step-6-adding-request-ids)
10. [Step 7: Creating an Audit Trail System](#step-7-creating-an-audit-trail-system)
11. [Step 8: Storing Audit Logs in Database](#step-8-storing-audit-logs-in-database)
12. [Step 9: Adding Security and Data Redaction](#step-9-adding-security-and-data-redaction)
13. [Step 10: Testing Your Implementation](#step-10-testing-your-implementation)
14. [Step 11: Production Considerations](#step-11-production-considerations)
15. [Troubleshooting Common Issues](#troubleshooting-common-issues)
16. [Next Steps](#next-steps)

---

## What You'll Learn

By the end of this guide, you will:

- Understand how HTTP requests and responses work in FastAPI
- Know how to create middleware to intercept requests
- Be able to log request and response data
- Understand how to create audit trails for compliance
- Know how to store audit logs in a database
- Understand security best practices for logging sensitive data

---

## Prerequisites

Before starting, make sure you have:

1. **Basic Python knowledge** - You should understand functions, classes, and basic Python syntax
2. **FastAPI basics** - You should know how to create routes and handle requests
3. **Database basics** - Understanding of SQL and database concepts
4. **Your development environment set up** - Python 3.8+, FastAPI installed

If you're missing any of these, take time to learn them first. This guide assumes you can read and write basic Python code.

---

## Understanding the Problem

### Why Do We Need Logging?

Imagine this scenario: A user reports that they can't create an order through your API. Without logging, you have no way to know:

- What request was made
- When it happened
- What data was sent
- What error occurred
- How long it took

With proper logging, you can answer all these questions instantly.

### What is an Audit Trail?

An audit trail is a record of all actions taken in your system. It's like a security camera for your API. It records:

- Who did what (user identification)
- When they did it (timestamp)
- What they did (action/endpoint)
- What data was involved (request/response)
- Whether it succeeded or failed

Audit trails are required for:
- **Security** - Detect unauthorized access
- **Compliance** - Meet regulatory requirements (GDPR, HIPAA, SOX)
- **Debugging** - Track down issues
- **Analytics** - Understand system usage

---

## Step 1: Understanding HTTP Requests and Responses

### What Happens When a Request is Made?

When a client (like a web browser or mobile app) makes a request to your API, this is what happens:

```
1. Client sends HTTP request
   ↓
2. Request arrives at your server
   ↓
3. FastAPI processes the request
   ↓
4. Your route handler executes
   ↓
5. Response is generated
   ↓
6. Response is sent back to client
```

### Request Components

Every HTTP request has these parts:

- **Method**: GET, POST, PUT, DELETE, etc.
- **Path**: The URL path (e.g., `/api/orders`)
- **Headers**: Metadata (authentication, content type, etc.)
- **Query Parameters**: Data in the URL (e.g., `?page=1&limit=10`)
- **Body**: Data sent with the request (for POST/PUT)

### Response Components

Every HTTP response has:

- **Status Code**: 200 (success), 404 (not found), 500 (error), etc.
- **Headers**: Response metadata
- **Body**: The actual data returned

### Example Request/Response

**Request:**
```
POST /api/orders
Headers:
  Content-Type: application/json
  Authorization: Bearer token123
Body:
  {
    "item": "Pizza",
    "quantity": 2
  }
```

**Response:**
```
Status: 201 Created
Headers:
  Content-Type: application/json
Body:
  {
    "id": "order-123",
    "item": "Pizza",
    "quantity": 2,
    "status": "pending"
  }
```

---

## Step 2: Understanding Middleware

### What is Middleware?

Middleware is code that runs **between** receiving a request and sending a response. Think of it as a checkpoint that every request must pass through.

```
Request → Middleware → Your Route Handler → Response
```

### Why Use Middleware for Logging?

Middleware is perfect for logging because:

1. It runs for **every request** automatically
2. You don't need to modify each route handler
3. It can capture data before and after the handler runs
4. It's centralized - one place to manage logging logic

### FastAPI Middleware Basics

In FastAPI, middleware is created using the `@app.middleware("http")` decorator:

```python
from fastapi import FastAPI, Request
import time

app = FastAPI()

@app.middleware("http")
async def my_middleware(request: Request, call_next):
    # Code here runs BEFORE the route handler
    start_time = time.time()
    
    # Call the next middleware or route handler
    response = await call_next(request)
    
    # Code here runs AFTER the route handler
    duration = time.time() - start_time
    print(f"Request took {duration} seconds")
    
    return response
```

### Understanding `call_next`

`call_next` is a function that continues to the next middleware or route handler. You **must** call it, otherwise the request will never reach your routes.

The pattern is:
1. Do something before (like record start time)
2. Call `await call_next(request)` to continue
3. Do something after (like log the response)

---

## Step 3: Creating a Basic Request Logger

Let's start simple. We'll create a middleware that logs basic information about each request.

### Step 3.1: Create the Middleware File

Create a new file: `app/middleware/request_logger.py`

```python
from fastapi import Request
import time
import logging

# Set up a logger
logger = logging.getLogger("api.requests")

async def request_logger_middleware(request: Request, call_next):
    """
    Basic middleware to log HTTP requests.
    
    This is the simplest possible logging middleware.
    It logs the method, path, and how long the request took.
    """
    # Record when the request started
    start_time = time.time()
    
    # Get basic request information
    method = request.method
    path = request.url.path
    
    # Log that we received a request
    logger.info(f"Request received: {method} {path}")
    
    # Continue to the route handler
    response = await call_next(request)
    
    # Calculate how long it took
    duration = time.time() - start_time
    duration_ms = duration * 1000  # Convert to milliseconds
    
    # Get the response status code
    status_code = response.status_code
    
    # Log the response
    logger.info(
        f"Request completed: {method} {path} - "
        f"Status: {status_code} - "
        f"Duration: {duration_ms:.2f}ms"
    )
    
    return response
```

### Step 3.2: Register the Middleware

In your `app/main.py`, add the middleware:

```python
from fastapi import FastAPI
from .middleware.request_logger import request_logger_middleware

app = FastAPI()

# Add the middleware
@app.middleware("http")
async def log_requests(request: Request, call_next):
    return await request_logger_middleware(request, call_next)
```

### Step 3.3: Test It

Start your FastAPI server and make a request. You should see logs like:

```
INFO:api.requests:Request received: GET /health
INFO:api.requests:Request completed: GET /health - Status: 200 - Duration: 5.23ms
```

**Congratulations!** You've created your first logging middleware.

---

## Step 4: Capturing Request Data

Now let's enhance our logger to capture more request details.

### Step 4.1: Understanding Request Data

A request contains much more than just method and path:

- **Query Parameters**: `?page=1&limit=10` becomes `{"page": "1", "limit": "10"}`
- **Headers**: Authentication tokens, user agent, etc.
- **Body**: The actual data being sent (for POST/PUT requests)
- **IP Address**: Where the request came from

### Step 4.2: Reading Request Body

**Important**: Request bodies can only be read once. If you read it in middleware, the route handler won't be able to read it. We need to store it and make it available.

```python
from fastapi import Request
import time
import logging
import json

logger = logging.getLogger("api.requests")

async def request_logger_middleware(request: Request, call_next):
    start_time = time.time()
    method = request.method
    path = request.url.path
    
    # Get query parameters
    query_params = dict(request.query_params)
    
    # Get headers (but be careful with sensitive data!)
    headers = dict(request.headers)
    
    # Get IP address
    client_ip = request.client.host if request.client else None
    
    # Try to read request body (only for POST/PUT/PATCH)
    request_body = None
    if method in ["POST", "PUT", "PATCH"]:
        try:
            # Read the body
            body_bytes = await request.body()
            
            # Store it so the route handler can still use it
            async def receive():
                return {"type": "http.request", "body": body_bytes}
            request._receive = receive
            
            # Try to parse as JSON
            if body_bytes:
                try:
                    request_body = json.loads(body_bytes.decode())
                except (json.JSONDecodeError, UnicodeDecodeError):
                    request_body = body_bytes.decode('utf-8', errors='replace')
        except Exception as e:
            logger.warning(f"Could not read request body: {e}")
    
    # Log the request
    logger.info(
        f"Request: {method} {path}",
        extra={
            "method": method,
            "path": path,
            "query_params": query_params,
            "ip_address": client_ip,
            "user_agent": headers.get("user-agent"),
            "request_body": request_body
        }
    )
    
    # Continue to route handler
    response = await call_next(request)
    
    # Log response
    duration = (time.time() - start_time) * 1000
    status_code = response.status_code
    
    logger.info(
        f"Response: {method} {path} - {status_code} - {duration:.2f}ms",
        extra={
            "method": method,
            "path": path,
            "status_code": status_code,
            "duration_ms": duration
        }
    )
    
    return response
```

### Step 4.3: Better Body Reading (Advanced)

The above approach works but has limitations. A better approach is to use FastAPI's streaming body reading:

```python
from fastapi import Request
from starlette.requests import Request as StarletteRequest
import json

async def get_request_body(request: Request):
    """
    Safely read request body without consuming it.
    """
    body_bytes = b""
    
    async for chunk in request.stream():
        body_bytes += chunk
    
    if not body_bytes:
        return None
    
    try:
        return json.loads(body_bytes.decode())
    except (json.JSONDecodeError, UnicodeDecodeError):
        return body_bytes.decode('utf-8', errors='replace')
```

However, this consumes the stream. The best practice is to read it once and store it. FastAPI actually handles this for us if we use Pydantic models, but for logging we need to be careful.

**For now, use the simpler approach above.** We'll improve it later when we add response body capture.

---

## Step 5: Capturing Response Data

Capturing response data is trickier because the response is created by the route handler, not the middleware.

### Step 5.1: The Challenge

The response object is created by `call_next()`. We need to intercept it to read the body.

### Step 5.2: Intercepting Response Body

We'll wrap the response's `body_iterator` to capture the response body:

```python
from fastapi import Request
from fastapi.responses import Response
import time
import logging
import json

logger = logging.getLogger("api.requests")

async def request_logger_middleware(request: Request, call_next):
    start_time = time.time()
    method = request.method
    path = request.url.path
    
    # Log request
    logger.info(f"Request: {method} {path}")
    
    # Get the response
    response = await call_next(request)
    
    # Capture response body
    response_body = None
    
    # Check if response has a body
    if hasattr(response, 'body'):
        # For StreamingResponse or Response with body
        try:
            body_bytes = response.body
            if body_bytes:
                try:
                    response_body = json.loads(body_bytes.decode())
                except (json.JSONDecodeError, UnicodeDecodeError):
                    response_body = body_bytes.decode('utf-8', errors='replace')
        except Exception as e:
            logger.warning(f"Could not read response body: {e}")
    elif hasattr(response, 'body_iterator'):
        # For streaming responses, we need to collect chunks
        # This is more complex and we'll handle it later
        pass
    
    # Calculate duration
    duration = (time.time() - start_time) * 1000
    status_code = response.status_code
    
    # Log everything
    logger.info(
        f"Response: {method} {path} - {status_code} - {duration:.2f}ms",
        extra={
            "method": method,
            "path": path,
            "status_code": status_code,
            "duration_ms": duration,
            "response_body": response_body
        }
    )
    
    return response
```

### Step 5.3: Better Response Capture

The above works for simple responses, but FastAPI often uses streaming responses. Here's a more robust approach:

```python
from fastapi import Request
from starlette.responses import Response, StreamingResponse
import time
import logging
import json

logger = logging.getLogger("api.requests")

async def request_logger_middleware(request: Request, call_next):
    start_time = time.time()
    method = request.method
    path = request.url.path
    
    # Capture request body (simplified - see Step 4 for full version)
    request_body = None
    if method in ["POST", "PUT", "PATCH"]:
        try:
            body_bytes = await request.body()
            async def receive():
                return {"type": "http.request", "body": body_bytes}
            request._receive = receive
            
            if body_bytes:
                try:
                    request_body = json.loads(body_bytes.decode())
                except:
                    request_body = "[Non-JSON body]"
        except:
            pass
    
    # Log request
    logger.info(
        "Request received",
        extra={
            "method": method,
            "path": path,
            "request_body": request_body
        }
    )
    
    # Get response
    response = await call_next(request)
    
    # Capture response body
    response_body = None
    response_body_size = 0
    
    if isinstance(response, StreamingResponse):
        # For streaming responses, we'll log that it's streaming
        # Full capture would require more complex handling
        response_body = "[Streaming response]"
    elif isinstance(response, Response):
        # Try to get body
        if hasattr(response, 'body'):
            body_bytes = response.body
            response_body_size = len(body_bytes) if body_bytes else 0
            if body_bytes and response_body_size < 10000:  # Only log small responses
                try:
                    response_body = json.loads(body_bytes.decode())
                except:
                    response_body = "[Non-JSON response]"
    
    # Calculate duration
    duration = (time.time() - start_time) * 1000
    status_code = response.status_code
    
    # Log response
    logger.info(
        "Request completed",
        extra={
            "method": method,
            "path": path,
            "status_code": status_code,
            "duration_ms": round(duration, 2),
            "response_body": response_body,
            "response_size": response_body_size
        }
    )
    
    return response
```

**Note**: For production, you might want to limit response body logging to avoid logging huge responses. We'll add that in Step 9.

---

## Step 6: Adding Request IDs

Request IDs are crucial for tracing requests through your system, especially when debugging.

### Step 6.1: What is a Request ID?

A request ID is a unique identifier for each request. It allows you to:

- Trace a request through multiple services
- Find all logs related to a specific request
- Debug issues by searching for a specific request ID

### Step 6.2: Generating Request IDs

We'll use UUIDs (Universally Unique Identifiers) to generate request IDs:

```python
import uuid
from fastapi import Request

async def request_logger_middleware(request: Request, call_next):
    # Generate a unique request ID
    request_id = str(uuid.uuid4())
    
    # Store it in the request state so route handlers can access it
    request.state.request_id = request_id
    
    # Also check if client sent a request ID (for distributed tracing)
    client_request_id = request.headers.get("X-Request-ID")
    if client_request_id:
        # Use client's request ID if provided (for distributed systems)
        request_id = client_request_id
        request.state.request_id = request_id
    
    # Log with request ID
    logger.info(
        "Request received",
        extra={
            "request_id": request_id,
            "method": request.method,
            "path": request.url.path
        }
    )
    
    response = await call_next(request)
    
    # Add request ID to response headers so client can use it
    response.headers["X-Request-ID"] = request_id
    
    # Log response with request ID
    logger.info(
        "Request completed",
        extra={
            "request_id": request_id,
            "method": request.method,
            "path": request.url.path,
            "status_code": response.status_code
        }
    )
    
    return response
```

### Step 6.3: Using Request IDs in Route Handlers

Now your route handlers can access the request ID:

```python
from fastapi import APIRouter, Request

router = APIRouter()

@router.post("/api/orders")
async def create_order(request: Request, order_data: dict):
    # Get the request ID from request state
    request_id = request.state.request_id
    
    # Use it in your logs
    logger.info(f"Creating order - Request ID: {request_id}")
    
    # Your business logic here
    # ...
    
    return {"order_id": "123", "request_id": request_id}
```

### Step 6.4: Complete Request Logger with Request IDs

Here's the complete middleware with request IDs:

```python
from fastapi import Request
import uuid
import time
import logging
import json

logger = logging.getLogger("api.requests")

async def request_logger_middleware(request: Request, call_next):
    # Generate or get request ID
    request_id = request.headers.get("X-Request-ID") or str(uuid.uuid4())
    request.state.request_id = request_id
    
    start_time = time.time()
    method = request.method
    path = request.url.path
    
    # Get client info
    client_ip = request.client.host if request.client else None
    user_agent = request.headers.get("user-agent")
    
    # Capture request body (simplified)
    request_body = None
    if method in ["POST", "PUT", "PATCH"]:
        try:
            body_bytes = await request.body()
            async def receive():
                return {"type": "http.request", "body": body_bytes}
            request._receive = receive
            
            if body_bytes:
                try:
                    request_body = json.loads(body_bytes.decode())
                except:
                    request_body = "[Non-JSON]"
        except:
            pass
    
    # Log request
    logger.info(
        "HTTP Request",
        extra={
            "request_id": request_id,
            "method": method,
            "path": path,
            "ip_address": client_ip,
            "user_agent": user_agent,
            "request_body": request_body
        }
    )
    
    # Process request
    response = await call_next(request)
    
    # Add request ID to response
    response.headers["X-Request-ID"] = request_id
    
    # Calculate duration
    duration = (time.time() - start_time) * 1000
    status_code = response.status_code
    
    # Capture response (simplified - see Step 5 for full version)
    response_body = None
    if hasattr(response, 'body') and response.body:
        try:
            body_str = response.body.decode()
            if len(body_str) < 10000:  # Only log small responses
                try:
                    response_body = json.loads(body_str)
                except:
                    response_body = "[Non-JSON]"
        except:
            pass
    
    # Log response
    logger.info(
        "HTTP Response",
        extra={
            "request_id": request_id,
            "method": method,
            "path": path,
            "status_code": status_code,
            "duration_ms": round(duration, 2),
            "response_body": response_body
        }
    )
    
    return response
```

---

## Step 7: Creating an Audit Trail System

An audit trail is more than just logging - it's a permanent record of actions for compliance and security.

### Step 7.1: What Makes an Audit Trail Different?

**Regular Logging:**
- Temporary (logs rotate/delete)
- For debugging
- May not include all details
- Can be modified

**Audit Trail:**
- Permanent record
- For compliance/security
- Complete record of actions
- Immutable (should not be modified)
- Includes who, what, when, where

### Step 7.2: What to Include in Audit Trails

For each action, record:

1. **Who**: User ID, API key, IP address
2. **What**: Action performed (e.g., "order.created", "user.deleted")
3. **When**: Precise timestamp
4. **Where**: Endpoint, method, path
5. **Data**: Request and response data (with sensitive data redacted)
6. **Result**: Success or failure, status code
7. **Context**: Request ID, session ID, etc.

### Step 7.3: Creating an Audit Service

Create `app/services/audit_service.py`:

```python
from datetime import datetime
from typing import Optional, Dict, Any
import logging

logger = logging.getLogger("api.audit")

class AuditService:
    """
    Service for recording audit trail events.
    
    This service handles the business logic of what to audit
    and how to format audit records.
    """
    
    def __init__(self):
        self.logger = logger
    
    def should_audit(self, method: str, path: str) -> bool:
        """
        Determine if an endpoint should be audited.
        
        You might want to skip auditing for:
        - Health checks
        - Metrics endpoints
        - Public read-only endpoints
        """
        # Skip health and metrics
        if path.startswith("/health") or path.startswith("/metrics"):
            return False
        
        # Audit all write operations
        if method in ["POST", "PUT", "PATCH", "DELETE"]:
            return True
        
        # Audit sensitive read operations
        sensitive_paths = ["/api/users", "/api/orders", "/api/payments"]
        if any(path.startswith(sp) for sp in sensitive_paths):
            return True
        
        return False
    
    def extract_action(self, method: str, path: str) -> str:
        """
        Extract a human-readable action from the request.
        
        Examples:
        - POST /api/orders -> "order.created"
        - PUT /api/orders/123 -> "order.updated"
        - DELETE /api/users/456 -> "user.deleted"
        - GET /api/orders -> "order.accessed"
        """
        # Extract resource type from path
        # /api/orders -> "order"
        # /api/users/123 -> "user"
        parts = path.strip("/").split("/")
        if len(parts) >= 2:
            resource = parts[1].rstrip("s")  # Remove plural
        else:
            resource = "unknown"
        
        # Map HTTP method to action
        action_map = {
            "POST": "created",
            "PUT": "updated",
            "PATCH": "updated",
            "DELETE": "deleted",
            "GET": "accessed"
        }
        
        action = action_map.get(method, method.lower())
        return f"{resource}.{action}"
    
    def create_audit_record(
        self,
        request_id: str,
        method: str,
        path: str,
        user_id: Optional[str] = None,
        ip_address: Optional[str] = None,
        status_code: int = 200,
        request_data: Optional[Dict[str, Any]] = None,
        response_data: Optional[Dict[str, Any]] = None,
        duration_ms: float = 0,
        error: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Create a structured audit record.
        
        This is the format that will be stored in the database.
        """
        return {
            "request_id": request_id,
            "timestamp": datetime.utcnow().isoformat(),
            "action": self.extract_action(method, path),
            "method": method,
            "path": path,
            "user_id": user_id,
            "ip_address": ip_address,
            "status_code": status_code,
            "success": 200 <= status_code < 400,
            "duration_ms": duration_ms,
            "request_data": request_data,
            "response_data": response_data,
            "error": error
        }
    
    async def log_event(self, audit_record: Dict[str, Any]):
        """
        Log an audit event.
        
        For now, we'll just log it. In Step 8, we'll store it in a database.
        """
        self.logger.info(
            "Audit event",
            extra=audit_record
        )
```

### Step 7.4: Integrating Audit Service with Middleware

Update your middleware to use the audit service:

```python
from fastapi import Request
from .services.audit_service import AuditService
import uuid
import time

audit_service = AuditService()

async def request_logger_middleware(request: Request, call_next):
    request_id = request.headers.get("X-Request-ID") or str(uuid.uuid4())
    request.state.request_id = request_id
    
    start_time = time.time()
    method = request.method
    path = request.url.path
    
    # Check if we should audit this request
    should_audit = audit_service.should_audit(method, path)
    
    # Get user information (you'll need to implement authentication)
    user_id = None
    # Example: user_id = getattr(request.state, 'user_id', None)
    
    # Get client info
    client_ip = request.client.host if request.client else None
    
    # Capture request data
    request_data = None
    if method in ["POST", "PUT", "PATCH"]:
        # ... (request body capture code from Step 4)
        pass
    
    # Process request
    response = await call_next(request)
    response.headers["X-Request-ID"] = request_id
    
    # Calculate duration
    duration = (time.time() - start_time) * 1000
    status_code = response.status_code
    
    # Capture response data
    response_data = None
    # ... (response body capture code from Step 5)
    
    # Create audit record if needed
    if should_audit:
        audit_record = audit_service.create_audit_record(
            request_id=request_id,
            method=method,
            path=path,
            user_id=user_id,
            ip_address=client_ip,
            status_code=status_code,
            request_data=request_data,
            response_data=response_data,
            duration_ms=duration
        )
        
        # Log the audit event
        await audit_service.log_event(audit_record)
    
    return response
```

---

## Step 8: Storing Audit Logs in Database

Logs in files can be lost. For compliance, we need to store audit trails in a database.

### Step 8.1: Database Schema

Create a table to store audit logs. Here's a SQL schema:

```sql
CREATE TABLE audit_logs (
    id SERIAL PRIMARY KEY,
    request_id VARCHAR(255) NOT NULL,
    timestamp TIMESTAMP NOT NULL,
    action VARCHAR(255) NOT NULL,
    method VARCHAR(10) NOT NULL,
    path VARCHAR(500) NOT NULL,
    user_id VARCHAR(255),
    ip_address VARCHAR(45),
    status_code INTEGER NOT NULL,
    success BOOLEAN NOT NULL,
    duration_ms FLOAT,
    request_data JSONB,
    response_data JSONB,
    error TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_audit_logs_request_id ON audit_logs(request_id);
CREATE INDEX idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_timestamp ON audit_logs(timestamp);
CREATE INDEX idx_audit_logs_action ON audit_logs(action);
```

### Step 8.2: Database Model

Create `app/database/audit_models.py`:

```python
from sqlalchemy import Column, Integer, String, Boolean, Float, Text, DateTime, JSON
from sqlalchemy.ext.declarative import declarative_base
from datetime import datetime

Base = declarative_base()

class AuditLog(Base):
    __tablename__ = "audit_logs"
    
    id = Column(Integer, primary_key=True, index=True)
    request_id = Column(String(255), nullable=False, index=True)
    timestamp = Column(DateTime, nullable=False)
    action = Column(String(255), nullable=False, index=True)
    method = Column(String(10), nullable=False)
    path = Column(String(500), nullable=False)
    user_id = Column(String(255), index=True)
    ip_address = Column(String(45))
    status_code = Column(Integer, nullable=False)
    success = Column(Boolean, nullable=False)
    duration_ms = Column(Float)
    request_data = Column(JSON)
    response_data = Column(JSON)
    error = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)
```

### Step 8.3: Update Audit Service to Store in Database

Update `app/services/audit_service.py`:

```python
from sqlalchemy.orm import Session
from app.database.audit_models import AuditLog
from datetime import datetime
from typing import Optional, Dict, Any

class AuditService:
    def __init__(self, db_session: Optional[Session] = None):
        self.db_session = db_session
    
    async def log_event(self, audit_record: Dict[str, Any], db: Session):
        """
        Store audit event in database.
        
        Args:
            audit_record: The audit record dictionary
            db: Database session
        """
        try:
            # Convert timestamp string to datetime
            timestamp = datetime.fromisoformat(audit_record["timestamp"])
            
            # Create database record
            db_record = AuditLog(
                request_id=audit_record["request_id"],
                timestamp=timestamp,
                action=audit_record["action"],
                method=audit_record["method"],
                path=audit_record["path"],
                user_id=audit_record.get("user_id"),
                ip_address=audit_record.get("ip_address"),
                status_code=audit_record["status_code"],
                success=audit_record["success"],
                duration_ms=audit_record.get("duration_ms"),
                request_data=audit_record.get("request_data"),
                response_data=audit_record.get("response_data"),
                error=audit_record.get("error")
            )
            
            # Save to database
            db.add(db_record)
            db.commit()
            
        except Exception as e:
            # Log error but don't fail the request
            # Audit logging should never break the application
            logger.error(f"Failed to save audit log: {e}")
            db.rollback()
```

### Step 8.4: Get Database Session in Middleware

You'll need to get a database session. Here's how to do it with FastAPI's dependency injection:

```python
from fastapi import Request, Depends
from sqlalchemy.orm import Session
from app.database.postgres import get_db

async def request_logger_middleware(
    request: Request,
    call_next,
    db: Session = Depends(get_db)
):
    # ... (your existing middleware code)
    
    if should_audit:
        audit_record = audit_service.create_audit_record(...)
        await audit_service.log_event(audit_record, db)
    
    return response
```

**Wait!** Middleware can't use `Depends()`. We need a different approach. Here's the correct way:

```python
from fastapi import Request
from app.database.postgres import get_db

async def request_logger_middleware(request: Request, call_next):
    # ... (your existing code)
    
    if should_audit:
        audit_record = audit_service.create_audit_record(...)
        
        # Get database session
        db = next(get_db())
        try:
            await audit_service.log_event(audit_record, db)
        finally:
            db.close()
    
    return response
```

Or better yet, use a database connection pool and get a session directly.

---

## Step 9: Adding Security and Data Redaction

**CRITICAL**: Never log sensitive data like passwords, credit cards, or API keys!

### Step 9.1: What is Data Redaction?

Data redaction means removing or masking sensitive information before logging it.

**Example:**
```python
# Before redaction
{"password": "secret123", "credit_card": "1234-5678-9012-3456"}

# After redaction
{"password": "[REDACTED]", "credit_card": "[REDACTED]"}
```

### Step 9.2: Creating a Redaction Utility

Create `app/utils/redaction.py`:

```python
from typing import Any, Dict, List
import re

# Fields that should always be redacted
SENSITIVE_FIELDS = [
    "password",
    "passwd",
    "pwd",
    "secret",
    "token",
    "api_key",
    "apikey",
    "authorization",
    "auth",
    "credit_card",
    "creditcard",
    "card_number",
    "cvv",
    "ssn",
    "social_security",
    "email",  # Sometimes you might want to redact emails
]

# Patterns that look like sensitive data
SENSITIVE_PATTERNS = [
    r'\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b',  # Credit card
    r'\b\d{3}-\d{2}-\d{4}\b',  # SSN
    r'Bearer\s+[\w-]+',  # Bearer tokens
]

def redact_value(value: Any) -> str:
    """Redact a single value."""
    return "[REDACTED]"

def redact_dict(data: Dict[str, Any], depth: int = 0, max_depth: int = 10) -> Dict[str, Any]:
    """
    Recursively redact sensitive fields from a dictionary.
    
    Args:
        data: Dictionary to redact
        depth: Current recursion depth
        max_depth: Maximum recursion depth to prevent infinite loops
    
    Returns:
        Dictionary with sensitive fields redacted
    """
    if depth > max_depth:
        return {"error": "[Max depth reached]"}
    
    if not isinstance(data, dict):
        return data
    
    redacted = {}
    for key, value in data.items():
        # Check if key is sensitive
        key_lower = key.lower()
        is_sensitive = any(
            sensitive in key_lower 
            for sensitive in SENSITIVE_FIELDS
        )
        
        if is_sensitive:
            redacted[key] = "[REDACTED]"
        elif isinstance(value, dict):
            # Recursively redact nested dictionaries
            redacted[key] = redact_dict(value, depth + 1, max_depth)
        elif isinstance(value, list):
            # Redact items in lists
            redacted[key] = [
                redact_dict(item, depth + 1, max_depth) if isinstance(item, dict) 
                else redact_value(item) if is_sensitive else item
                for item in value
            ]
        elif isinstance(value, str):
            # Check for sensitive patterns in strings
            redacted_value = value
            for pattern in SENSITIVE_PATTERNS:
                if re.search(pattern, value, re.IGNORECASE):
                    redacted_value = "[REDACTED]"
                    break
            redacted[key] = redacted_value
        else:
            redacted[key] = value
    
    return redacted

def redact_request_data(data: Any) -> Any:
    """
    Redact sensitive data from request/response data.
    
    Handles dictionaries, lists, and other types.
    """
    if isinstance(data, dict):
        return redact_dict(data)
    elif isinstance(data, list):
        return [redact_request_data(item) for item in data]
    elif isinstance(data, str):
        # Check for sensitive patterns
        for pattern in SENSITIVE_PATTERNS:
            if re.search(pattern, data, re.IGNORECASE):
                return "[REDACTED]"
        return data
    else:
        return data
```

### Step 9.3: Using Redaction in Middleware

Update your middleware to redact sensitive data:

```python
from app.utils.redaction import redact_request_data

async def request_logger_middleware(request: Request, call_next):
    # ... (your existing code)
    
    # Capture request data
    request_data = None
    if method in ["POST", "PUT", "PATCH"]:
        # ... (capture code)
        # REDACT BEFORE LOGGING
        request_data = redact_request_data(raw_request_data)
    
    # ... (process request)
    
    # Capture response data
    response_data = None
    # ... (capture code)
    # REDACT BEFORE LOGGING
    response_data = redact_request_data(raw_response_data)
    
    # Now safe to log
    logger.info("Request", extra={"request_data": request_data})
    
    # Create audit record with redacted data
    audit_record = audit_service.create_audit_record(
        # ...
        request_data=request_data,  # Already redacted
        response_data=response_data  # Already redacted
    )
```

### Step 9.4: Limiting Response Body Size

Large responses can fill up your logs. Limit the size:

```python
MAX_LOG_BODY_SIZE = 10000  # 10KB

def limit_body_size(data: Any, max_size: int = MAX_LOG_BODY_SIZE) -> Any:
    """
    Limit the size of logged data.
    
    If data is too large, truncate it.
    """
    import json
    
    if data is None:
        return None
    
    # Convert to JSON string to check size
    try:
        json_str = json.dumps(data)
        if len(json_str) > max_size:
            return {
                "_truncated": True,
                "_original_size": len(json_str),
                "_message": f"Response body too large ({len(json_str)} bytes), truncated"
            }
    except:
        pass
    
    return data
```

Use it in your middleware:

```python
# Limit size before logging
request_data = limit_body_size(redact_request_data(raw_request_data))
response_data = limit_body_size(redact_request_data(raw_response_data))
```

---

## Step 10: Testing Your Implementation

### Step 10.1: Manual Testing

1. **Start your server**
   ```bash
   uvicorn app.main:app --reload
   ```

2. **Make test requests**
   ```bash
   # Test GET request
   curl http://localhost:8000/health
   
   # Test POST request
   curl -X POST http://localhost:8000/api/orders \
     -H "Content-Type: application/json" \
     -d '{"item": "Pizza", "quantity": 2}'
   ```

3. **Check logs**
   - Look for request/response logs
   - Verify request IDs are present
   - Check that sensitive data is redacted

### Step 10.2: Automated Testing

Create `tests/test_request_logging.py`:

```python
import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_request_id_in_response():
    """Test that request ID is included in response headers."""
    response = client.get("/health")
    assert "X-Request-ID" in response.headers
    assert response.headers["X-Request-ID"] is not None

def test_sensitive_data_redaction():
    """Test that sensitive data is redacted in logs."""
    from app.utils.redaction import redact_request_data
    
    test_data = {
        "username": "john",
        "password": "secret123",
        "credit_card": "1234-5678-9012-3456"
    }
    
    redacted = redact_request_data(test_data)
    
    assert redacted["username"] == "john"  # Not sensitive
    assert redacted["password"] == "[REDACTED]"
    assert redacted["credit_card"] == "[REDACTED]"

def test_audit_log_creation():
    """Test that audit logs are created for auditable endpoints."""
    # This would require mocking the database
    # Implementation depends on your testing setup
    pass
```

### Step 10.3: Testing Checklist

- [ ] Request IDs are generated and included in responses
- [ ] Request data is logged (for POST/PUT/PATCH)
- [ ] Response data is logged
- [ ] Sensitive data is redacted
- [ ] Large responses are truncated
- [ ] Audit logs are created for auditable endpoints
- [ ] Database records are created correctly
- [ ] Performance is acceptable (logging doesn't slow down requests significantly)

---

## Step 11: Production Considerations

### Step 11.1: Performance Optimization

Logging can slow down your API. Optimize:

1. **Async Logging**: Use async logging to avoid blocking
2. **Batch Writes**: Write audit logs in batches, not one-by-one
3. **Background Tasks**: Use background tasks for audit logging
4. **Sampling**: Only log a percentage of requests for high-volume endpoints

### Step 11.2: Using Background Tasks

FastAPI supports background tasks:

```python
from fastapi import BackgroundTasks

async def request_logger_middleware(request: Request, call_next):
    # ... (your existing code)
    
    if should_audit:
        audit_record = audit_service.create_audit_record(...)
        
        # Add as background task
        background_tasks.add_task(
            audit_service.log_event,
            audit_record,
            db
        )
    
    return response
```

### Step 11.3: Error Handling

Audit logging should **never** break your API:

```python
async def log_event(self, audit_record: Dict[str, Any], db: Session):
    try:
        # ... (save to database)
    except Exception as e:
        # Log the error but don't raise it
        logger.error(f"Audit logging failed: {e}", exc_info=True)
        # Optionally: fall back to file logging
        self.fallback_log(audit_record)
```

### Step 11.4: Log Retention

Plan for log retention:

- **How long to keep logs?** (Compliance requirements)
- **How to archive old logs?** (Move to cold storage)
- **How to delete logs?** (After retention period)

### Step 11.5: Monitoring

Monitor your logging system:

- **Log volume**: How many logs per day?
- **Database size**: Is the audit_logs table growing too fast?
- **Performance impact**: Is logging slowing down requests?
- **Errors**: Are there any logging failures?

---

## Troubleshooting Common Issues

### Issue: Request body is empty in logs

**Cause**: Body was already consumed by FastAPI.

**Solution**: Make sure you're reading the body before `call_next()` and restoring it:

```python
body_bytes = await request.body()
async def receive():
    return {"type": "http.request", "body": body_bytes}
request._receive = receive
```

### Issue: Response body is empty in logs

**Cause**: Response is streaming or already sent.

**Solution**: For streaming responses, you may need to collect chunks. For simple responses, check if `response.body` exists.

### Issue: Database connection errors in middleware

**Cause**: Database session not properly managed.

**Solution**: Use connection pooling and proper session management. Consider using background tasks.

### Issue: Logging is too slow

**Cause**: Synchronous database writes blocking requests.

**Solution**: Use async database operations or background tasks.

### Issue: Sensitive data still appearing in logs

**Cause**: Redaction not applied or missing fields in redaction list.

**Solution**: Review your redaction utility and add missing sensitive fields.

---

## Next Steps

Now that you've implemented basic logging and audit trails, consider:

1. **Structured Logging**: Use JSON logging for better parsing
2. **Log Aggregation**: Use tools like ELK Stack, Splunk, or Datadog
3. **Alerting**: Set up alerts for suspicious activities
4. **Analytics**: Build dashboards to analyze API usage
5. **Distributed Tracing**: For microservices, use tools like Jaeger or Zipkin
6. **Compliance Reports**: Generate reports for compliance audits

---

## Summary

You've learned:

1. How HTTP requests and responses work
2. How to create FastAPI middleware
3. How to capture and log request/response data
4. How to add request IDs for tracing
5. How to create an audit trail system
6. How to store audit logs in a database
7. How to redact sensitive data
8. How to test your implementation
9. Production considerations

Remember: Logging and audit trails are essential for production applications. Take time to implement them correctly, and always prioritize security and performance.

---

## Additional Resources

- [FastAPI Middleware Documentation](https://fastapi.tiangolo.com/advanced/middleware/)
- [Python Logging Best Practices](https://docs.python.org/3/howto/logging.html)
- [OWASP Logging Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html)

