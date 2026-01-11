# Simplified Approach: ENTRYPOINT + CMD with dumb-init

## The Cleaner Solution

Instead of a separate wrapper script, we use:
- **ENTRYPOINT**: Our script that loads K8s env vars
- **CMD**: dumb-init + the actual application

## How It Works

```dockerfile
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/usr/bin/dumb-init", "--", "node", "dist/server.js"]
```

### Execution Flow

1. Docker runs: `/usr/local/bin/docker-entrypoint.sh /usr/bin/dumb-init -- node dist/server.js`
2. `docker-entrypoint.sh`:
   - Sources `load-k8s-env.sh` (loads env vars from YAML)
   - Execs: `exec "$@"` → `exec /usr/bin/dumb-init -- node dist/server.js`
3. `dumb-init` runs with the app (preserves all signal handling)

## Benefits

✅ **Simpler** - One entrypoint script instead of two  
✅ **Cleaner** - dumb-init is in CMD where it logically belongs  
✅ **Same functionality** - Still preserves dumb-init benefits  
✅ **Easier to understand** - Clear separation: entrypoint loads env, CMD runs app

## Comparison

### Before (with wrapper):
```dockerfile
ENTRYPOINT ["/usr/local/bin/dumb-init-wrapper.sh", "--"]
CMD ["node", "dist/server.js"]
```

### After (simplified):
```dockerfile
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/usr/bin/dumb-init", "--", "node", "dist/server.js"]
```

Both approaches work the same, but the second is cleaner!

