# LazyVim Container Lifecycle Management

This guide explains the correct workflow for managing the Lazy Docker container without losing plugin configurations, sessions, or having to rebuild unnecessarily.

## 🔧 Main Commands

### Initial Build
```bash
make build    # Builds the container for the first time
```
⚠️ **Only use when**:
- First time setting up the environment
- Need to update the base image
- Container is corrupted or damaged

### Daily Operations

#### Start Container
```bash
make start    # Starts an existing container (NO rebuild)
```
✅ **Perfect for**:
- Starting your work day
- Resuming after using `make stop`
- Reviving a container that stopped unexpectedly

#### Enter Container
```bash
make enter    # Enters the container (starts automatically if stopped)
```
✅ **Perfect for**:
- Quick access to development environment
- Automatically handles starting the container if stopped
- Most common use for daily development

#### Stop Container
```bash
make stop     # Stops the container PRESERVING all data
```
✅ **Ideal for**:
- Freeing system resources
- Ending your work day
- Temporarily suspending the environment

#### Quick Restart
```bash
make restart  # Restarts the existing container
```
✅ **Useful for**:
- Applying configuration changes
- Resolving minor issues
- Refreshing the environment without data loss

## 🔄 Recommended Daily Workflow

### Starting Your Day
```bash
make enter    # Handles everything automatically
```

### During Development
- Container keeps running
- You can exit and enter with `make enter` as many times as needed
- All plugins, configurations, and sessions are preserved

### Ending Your Day
```bash
make stop     # Frees resources but preserves everything
```

### Next Day
```bash
make enter    # Continue exactly where you left off
```

## 📊 Container States

| State | Description | Command to Continue |
|--------|-------------|----------------------|
| `missing` | Doesn't exist | `make build` |
| `exited` | Stopped but exists | `make start` or `make enter` |
| `running` | Running and ready | `make enter` |

## ✅ Check Status

```bash
make status   # Shows current status in detail
```

Example outputs:
- ✅ `Container exists and is running` - Ready to use
- ⚠️ `Container exists but is stopped` - Use `make start` or `make enter`  
- ❌ `Container does not exist` - Use `make build`

## 🚀 Quick Start Commands

```bash
make quick    # Starts and enters automatically (builds only if needed)
```

## ⚠️ Destructive Commands (Use with Caution)

```bash
make destroy  # REMOVES EVERYTHING: container, volumes, images
make build    # Rebuilds from scratch (you lose plugins/sessions)
```

## 🐛 Troubleshooting

### Problem: "Container not found"
**Symptom**: Error when using `make start` or `make enter`
```bash
make status   # Check status
make build    # Only if it really doesn't exist
```

### Problem: Container Doesn't Respond
**Symptom**: Container exists but doesn't work properly
```bash
make restart  # Try restarting first
make status   # Verify the status
```

### Problem: Configuration Changes Not Applied
**Symptom**: You modified docker-compose.yml but changes aren't applied
```bash
make restart  # For most changes
make destroy && make build  # Only for major changes
```

## 🎯 Best Practices

1. **Use `make enter` as your main command** - It's the smartest
2. **`make stop` at the end of the day** - Conserves resources
3. **Avoid `make build`** - Only when really necessary
4. **Check with `make status`** - Before reporting issues
5. **Use `make restart`** - Before `make destroy`

## 🔒 Data Preservation

The system is configured to preserve:
- ✅ Neovim plugin configurations
- ✅ GitHub Copilot sessions
- ✅ Command history
- ✅ Personal configurations
- ✅ Files in `.dotfiles/`
- ✅ Git configurations

**Data is preserved between `make stop` and `make start`**

## 📈 Performance

- `make start`: ~1-2 seconds
- `make enter`: ~1-2 seconds + startup time if it was stopped
- `make stop`: ~10 seconds (normal, Docker does clean shutdown)
- `make build`: ~2-5 minutes (only when necessary)

---

💡 **Tip**: For daily use, `make enter` is all you need 90% of the time.
