# 🔍 Adminer - Lightweight PostgreSQL Viewer

## Overview

Adminer is a lightweight, single-file database management tool perfect for quick PostgreSQL inspection. It's much lighter than pgAdmin and loads instantly.

---

## 🚀 Quick Access

**URL:** http://localhost:8080

**Login Credentials:**
- **System:** PostgreSQL
- **Server:** `postgres` (or `localhost` from host)
- **Username:** `deepiri` (or your `POSTGRES_USER`)
- **Password:** `deepiripassword` (or your `POSTGRES_PASSWORD`)
- **Database:** `deepiri` (or your `POSTGRES_DB`)

---

## 📋 Features

### **Why Adminer?**
- ✅ **Ultra-lightweight** - Single PHP file, ~500KB
- ✅ **Fast** - Loads instantly, no heavy UI
- ✅ **Simple** - Clean, minimal interface
- ✅ **Powerful** - Full SQL editor, table browsing, data editing
- ✅ **No setup** - Works out of the box

### **What You Can Do**
- 🔍 Browse all tables and schemas
- 📊 View table data with pagination
- ✏️ Edit data directly in the browser
- 📝 Run SQL queries
- 🔧 View table structure and indexes
- 📈 Export data (CSV, SQL, JSON)
- 🔐 Manage users and permissions

---

## 🐳 Docker Configuration

Adminer is configured in all docker-compose files:

```yaml
adminer:
  image: adminer:latest
  container_name: deepiri-adminer-dev
  restart: unless-stopped
  ports:
    - "8080:8080"
  environment:
    ADMINER_DEFAULT_SERVER: postgres
  depends_on:
    - postgres
  networks:
    - deepiri-dev-network
```

---

## 🔐 Connection Details

### **From Browser (localhost)**
```
System: PostgreSQL
Server: localhost
Port: 5432
Username: deepiri
Password: deepiripassword
Database: deepiri
```

### **From Docker Container**
```
System: PostgreSQL
Server: postgres
Port: 5432
Username: deepiri
Password: deepiripassword
Database: deepiri
```

---

## 📊 Usage Examples

### **1. Browse Tables**
1. Login to Adminer
2. Click on database name (`deepiri`)
3. See all tables organized by schema:
   - `public` - Core tables (users, tasks, projects)
   - `analytics` - Gamification tables (momentum, streaks)
   - `audit` - Activity logs

### **2. View Table Data**
1. Click on any table name
2. Browse data with pagination
3. Use filters to search
4. Click on any row to edit

### **3. Run SQL Queries**
1. Click "SQL command" in the top menu
2. Write your query:
   ```sql
   SELECT * FROM users WHERE email LIKE '%@deepiri.com';
   ```
3. Click "Execute"

### **4. Export Data**
1. Browse to any table
2. Click "Export" button
3. Choose format (CSV, SQL, JSON, etc.)
4. Download

---

## 🆚 Adminer vs pgAdmin

| Feature | Adminer | pgAdmin |
|---------|---------|---------|
| **Size** | ~500KB | ~200MB |
| **Load Time** | Instant | 5-10 seconds |
| **Memory** | Minimal | Heavy |
| **UI** | Simple, clean | Feature-rich |
| **SQL Editor** | ✅ Basic | ✅ Advanced |
| **Visual Query Builder** | ❌ | ✅ |
| **Best For** | Quick inspection | Complex operations |

**Recommendation:**
- Use **Adminer** for quick data inspection and simple queries
- Use **pgAdmin** for complex database administration and visual query building

---

## 🔧 Advanced Configuration

### **Custom Adminer Theme**
You can customize Adminer by mounting a custom CSS file:

```yaml
adminer:
  volumes:
    - ./adminer-custom.css:/var/www/html/adminer.css
```

### **Multiple Database Support**
Adminer can connect to multiple databases. Just change the "Database" field in the login form.

### **Connection from Remote**
If you need to access Adminer from a remote machine, ensure port 8080 is exposed:

```yaml
ports:
  - "0.0.0.0:8080:8080"  # Accessible from any IP
```

---

## 🛡️ Security Notes

### **Production Recommendations**
1. **Don't expose Adminer publicly** - Use VPN or SSH tunnel
2. **Use strong passwords** - Change default PostgreSQL password
3. **Restrict access** - Use firewall rules
4. **Consider authentication** - Add HTTP basic auth in front of Adminer

### **Add HTTP Basic Auth (Optional)**
```yaml
adminer:
  environment:
    ADMINER_DEFAULT_SERVER: postgres
  labels:
    - "traefik.http.middlewares.adminer-auth.basicauth.users=admin:$$apr1$$..."
```

---

## 📝 Quick Reference

### **Common Queries in Adminer**

**View all users:**
```sql
SELECT id, email, name, created_at FROM public.users;
```

**Check table counts:**
```sql
SELECT 
  schemaname,
  tablename,
  n_live_tup as row_count
FROM pg_stat_user_tables
ORDER BY n_live_tup DESC;
```

**View recent activity:**
```sql
SELECT * FROM audit.activity_logs 
ORDER BY created_at DESC 
LIMIT 20;
```

**Check momentum stats:**
```sql
SELECT 
  u.email,
  m.total_momentum,
  m.current_level
FROM analytics.momentum m
JOIN public.users u ON m.user_id = u.id
ORDER BY m.total_momentum DESC;
```

---

## 🚨 Troubleshooting

### **"Cannot connect to server"**
- Check PostgreSQL is running: `docker ps | grep postgres`
- Verify network: Adminer and PostgreSQL must be on same Docker network
- Check server name: Use `postgres` (container name) not `localhost`

### **"Authentication failed"**
- Verify credentials match your `POSTGRES_USER` and `POSTGRES_PASSWORD`
- Check PostgreSQL logs: `docker logs deepiri-postgres-dev`

### **"Database does not exist"**
- Ensure database name matches `POSTGRES_DB` (default: `deepiri`)
- Check database exists: `docker exec -it deepiri-postgres-dev psql -U deepiri -l`

---

## 📚 Resources

- **Adminer Official:** https://www.adminer.org/
- **Documentation:** https://www.adminer.org/en/
- **GitHub:** https://github.com/vrana/adminer

---

## ✅ Status

Adminer is now available in:
- ✅ `docker-compose.dev.yml`
- ✅ `docker-compose.backend-team.yml`
- ✅ `docker-compose.platform-engineers.yml`

**Access:** http://localhost:8080

**Last Updated:** 2025-01-29

