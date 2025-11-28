# CI/CD Workflow Optimization Guide

This document explains what should and shouldn't run in our CI/CD workflows, and why.

## Key Principle: **Idempotency and Efficiency**

- **Always run**: Steps needed to detect changes or make decisions
- **Conditionally run**: Steps that modify infrastructure or deploy code
- **Skip if unnecessary**: Steps that are expensive or redundant

---

## Infrastructure Workflow (`infrastructure.yml`)

### ✅ **Always Run** (Decision-Making Steps)

These steps are needed to determine what actions to take:

1. **Checkout Code** - Required to access files
2. **Configure AWS Credentials** - Required for Terraform/AWS operations
3. **Setup Terraform** - Required for Terraform operations
4. **Terraform Init** - Required to initialize Terraform
5. **Detect File Changes** - Determines if Terraform/Ansible files changed
6. **Terraform Plan** - Generates plan to detect infrastructure changes
7. **Check for Drift** - Analyzes plan to determine change type (first_run, none, expected, drift)

**Why always?** These steps are fast and necessary to make decisions about what to do next.

---

### ⚠️ **Conditionally Run** (Modification Steps)

These steps only run when needed:

#### 1. **Terraform Apply**
- **Runs when**: 
  - `change_type == 'first_run'` (first deployment)
  - `change_type == 'none'` (no changes, but plan succeeded)
  - `change_type == 'expected'` (Terraform files changed)
  - `change_type == 'drift'` AND `manual-approval == 'success'` (drift approved)
- **Skips when**: 
  - `change_type == 'drift'` AND approval denied
  - Plan shows no changes

#### 2. **Ansible Installation** (on GitHub Runner)
- **Runs when**: Ansible deployment job runs
- **Optimization**: Checks if Ansible is already installed (unlikely on fresh runners, but good practice)
- **Why needed?** GitHub Actions runners are ephemeral (fresh VM each time), so Ansible must be installed

#### 3. **Ansible Deployment** (entire job)
- **Runs when**:
  - `ansible_files_changed == 'true'` (playbook/roles updated), OR
  - `infrastructure_changed == 'true'` (new instance, etc.), OR
  - `change_type == 'first_run'` (infrastructure being created)
- **Skips when**: 
  - Only Terraform code changed (no infrastructure changes)
  - No Ansible files changed
  - Infrastructure already exists and unchanged

#### 4. **Docker Installation** (on server via Ansible)
- **Runs when**: Docker is not installed on the server
- **Skips when**: Docker is already installed (idempotent check)
- **Optimization**: Added check `docker --version` before installation

#### 5. **Application Deployment** (via Ansible)
- **Runs when**: Ansible deployment job runs
- **Skips when**: Ansible deployment job is skipped

---

## Application Workflow (`application.yml`)

### ✅ **Always Run**

1. **Checkout Code** - Required
2. **Configure AWS Credentials** - Required for AWS queries
3. **Get Server IP** - Required to know where to deploy
4. **Setup SSH** - Required for Ansible connection
5. **Install Ansible** - Required (optimized with check)

### ⚠️ **Conditionally Run**

1. **Deploy Application** - Only runs when:
   - Application code changed (frontend, APIs, docker-compose.yml)
   - Workflow is manually triggered

---

## Optimization Summary

### What We Optimized:

1. **Ansible Installation**:
   - ✅ Added check: `if ! command -v ansible` before installing
   - ✅ Added `-qq` flag to `apt-get update` (quiet mode)
   - ⚠️ **Note**: GitHub Actions runners are ephemeral, so Ansible will always need to be installed, but the check is good practice

2. **Docker Installation** (on server):
   - ✅ Added check: `docker --version` before installation
   - ✅ Skips all Docker installation steps if already installed
   - ✅ Skips apt cache updates if Docker already installed

3. **Ansible Deployment Job**:
   - ✅ Only runs when:
     - Ansible files changed, OR
     - Infrastructure actually changed, OR
     - First run
   - ✅ Skips when only Terraform code changes (no infrastructure impact)

4. **Terraform Apply**:
   - ✅ Only runs when changes are detected or approved
   - ✅ Skips when plan shows "No changes"

---

## Decision Matrix

| Step | Always Run? | Condition |
|------|-------------|-----------|
| Checkout Code | ✅ Yes | Always needed |
| AWS Credentials | ✅ Yes | Always needed |
| Terraform Init | ✅ Yes | Always needed |
| Terraform Plan | ✅ Yes | Needed to detect changes |
| File Change Detection | ✅ Yes | Needed to determine change type |
| Drift Detection | ✅ Yes | Needed to analyze plan |
| Terraform Apply | ⚠️ Conditional | Only if changes detected/approved |
| Ansible Installation (Runner) | ⚠️ Conditional | Only if Ansible job runs (but check first) |
| Ansible Deployment | ⚠️ Conditional | Only if Ansible files changed OR infrastructure changed |
| Docker Installation (Server) | ⚠️ Conditional | Only if not already installed |
| Application Deployment | ⚠️ Conditional | Only if app code changed |

---

## Performance Impact

### Before Optimization:
- Ansible installed every run (even when not needed)
- Docker installation attempted every run (even if installed)
- Ansible deployment ran even for Terraform-only changes

### After Optimization:
- Ansible installation: ~5-10 seconds (only when needed)
- Docker installation: Skipped if already installed (saves ~30-60 seconds)
- Ansible deployment: Skipped for Terraform-only changes (saves ~2-5 minutes)

**Total time saved per run**: ~2-6 minutes when conditions are met

---

## Best Practices Applied

1. **Idempotency**: All installation steps check if already installed
2. **Conditional Execution**: Use `if:` conditions to skip unnecessary steps
3. **Early Exit**: Check conditions early to avoid unnecessary work
4. **Clear Logging**: Show why steps are skipped or run
5. **Error Handling**: Gracefully handle missing files/commands

---

## Future Optimizations (Optional)

1. **Use GitHub Actions Cache** for Ansible installation (if it becomes a bottleneck)
2. **Use `actions/setup-ansible`** action if available (official GitHub action)
3. **Parallel Jobs**: Run Terraform and Ansible file detection in parallel
4. **Matrix Strategy**: Test multiple environments in parallel

---

## Notes

- **GitHub Actions Runners**: Are ephemeral (fresh VM each run), so tools like Ansible must be installed each time
- **Server State**: Persists between runs, so we can check if Docker/software is already installed
- **Terraform State**: Persists (via artifacts), so we can detect changes and avoid unnecessary applies

