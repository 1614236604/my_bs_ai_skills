---
name: build-sync
description: "Code sync, remote build, and test execution for NTN DU project. Use when: (1) syncing code to build server, (2) building/compiling on remote server, (3) pulling code from build server, (4) running tests on build server. Triggers on: 'sync', 'push', 'build', 'compile', '编译', '同步', 'pull code', 'run test', '验证编译'."
---

# Build & Sync Operations

## Step 0: Resolve Build Server Connection

Before any operation, check memory file (`MEMORY.md`) for `## Build Server` section to get:
- **IP**: Build server IP address
- **User**: SSH username
- **Remote project**: Remote project root path
- **Local project**: Local project root path

**If not found in memory**, ask the user to provide:
1. Build server IP address
2. SSH username
3. Remote project directory path

Also remind the user: **SSH 免密登录需要用户自行配置**（`ssh-copy-id` 等方式）。

After obtaining the info, **immediately write it to memory** under `## Build Server` to avoid asking again:
```markdown
## Build Server
- IP: <ip>
- User: <user>
- Remote project: <remote_path>
- Local project: <local_path>
```

Use these values as `{IP}`, `{USER}`, `{REMOTE_PROJECT}`, `{LOCAL_PROJECT}` in all commands below.

## Sync Rules (MUST follow)

1. **Scope**: Only `src/duapp/` and `src/components/callp/` are allowed to be synced. Never sync the entire `src/` tree.
2. **No --delete**: Never use `rsync --delete`. Only overwrite existing files, never remove files on either side.
3. **callp only syncs Makefiles**: `components/callp/` uses `--include='*/' --include='Makefile' --exclude='*'` filter.
4. **Pull requires explicit user request**: Syncing from build server to local (pull) is ONLY allowed when the user explicitly asks for it. Never do this autonomously.

## Operations

### Push (local → build server)

Sync local code to build server before building:

```bash
rsync -avz {LOCAL_PROJECT}/src/duapp/ {USER}@{IP}:{REMOTE_PROJECT}/src/duapp/
rsync -avz --include='*/' --include='Makefile' --exclude='*' \
  {LOCAL_PROJECT}/src/components/callp/ \
  {USER}@{IP}:{REMOTE_PROJECT}/src/components/callp/
```

### Build (on build server)

SSH to build server and compile:

```bash
ssh {USER}@{IP} "cd {REMOTE_PROJECT}/src && make -j8 do_strip=1"
```

- Always use `make -j8 do_strip=1`
- **NEVER** use `make clean`, `make clean_<mod>`, or any clean-related commands

### Pull (build server → local)

**ONLY when user explicitly requests it.**

```bash
rsync -avz {USER}@{IP}:{REMOTE_PROJECT}/src/duapp/ {LOCAL_PROJECT}/src/duapp/
rsync -avz --include='*/' --include='Makefile' --exclude='*' \
  {USER}@{IP}:{REMOTE_PROJECT}/src/components/callp/ \
  {LOCAL_PROJECT}/src/components/callp/
```

### Test (on build server)

Run nrMacTest unit tests on build server. The test binary is at `components/rootfs/bts/bin/nrMacTest` and requires the library path `components/rootfs/bts/lib`:

```bash
ssh {USER}@{IP} "cd {REMOTE_PROJECT}/src && export LD_LIBRARY_PATH={REMOTE_PROJECT}/src/components/rootfs/bts/lib:\$LD_LIBRARY_PATH && ./components/rootfs/bts/bin/nrMacTest"
```

## Typical Workflow: Push + Build

When user asks to "编译验证" or "build and verify":

1. Push (sync local → server)
2. Build (`make -j8 do_strip=1`)
3. Report build result (success/failure with error details)

## Important Notes

- **Makefile sync handles source file deletion**: When source files are deleted locally and the corresponding Makefile is updated, the push operation syncs the updated Makefile to the build server automatically. No need to manually edit Makefiles on the server side — the normal push+build flow handles it.
