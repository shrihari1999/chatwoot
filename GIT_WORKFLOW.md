# Git Workflow for Custom Chatwoot Fork

This document describes the 3-branch Git strategy for maintaining your custom Chatwoot fork alongside official updates.

## Branch Structure

### Production Branch (Protected)
- **Purpose**: Production-ready code currently running on your server
- **Location**: Local + origin/production
- **Source**: Created from feature/canned-response-images-claude (your working state)
- **Updates**: Only from tested, stable feature branches via pull requests

### Develop Branch (Upstream-Tracking)
- **Purpose**: Stays synchronized with official Chatwoot development
- **Location**: Local only (tracks upstream/develop)
- **Source**: Tracks official Chatwoot develop branch
- **Updates**: git pull from upstream (automatic fast-forward)
- **Protected**: Pre-push hook prevents direct pushes to origin/develop

### Feature Branches
- **Purpose**: Individual feature development and customizations
- **Examples**: 
  - feature/canned-response-images-claude (current)
  - feature/lazada-integration (completed)
- **Workflow**: Branch from develop, develop, test, merge to production

---

## Daily Workflow

### Starting a New Feature
Step 1: Update develop with latest upstream changes
  git checkout develop
  git pull

Step 2: Create feature branch
  git checkout -b feature/your-feature-name

Step 3: Develop and commit
  git add .
  git commit -m "feat: Your feature description"

Step 4: Push to your fork
  git push origin feature/your-feature-name

### Merging Official Updates
Step 1: Update develop
  git checkout develop
  git pull

Step 2: Merge into your feature branch
  git checkout feature/your-feature-name
  git merge develop

Step 3: Resolve conflicts (if any), test thoroughly
Step 4: Deploy to production once stable

### Deploying to Production
Step 1: Ensure feature is complete and tested
  git checkout production
  git merge feature/your-feature-name

Step 2: Push to your fork
  git push origin production

Step 3: Pull on server and restart services
  cd /home/chatwoot/chatwoot
  git checkout production
  git pull origin production
  sudo systemctl restart chatwoot-web.1.service
  sudo systemctl restart chatwoot-worker.1.service
  sudo systemctl restart chatwoot-sidekiq.service

---

## Custom Features Implemented

### Canned Response Image Uploads
- Backend: ActiveStorage integration with Azure Blob Storage
- Frontend: Vue components with image preview
- Files Modified: See CANNED_RESPONSE_IMAGE_FEATURE.md

### Lazada IM Integration
- Webhook Processing: Incoming messages and read receipts
- Message Sending: Text + image attachments with dimensions
- Real-time Updates: ActionCable websocket status sync
- Read Receipts: SESSION_UPDATE webhook processing
- Key Files:
  - Backend: app/models/channel/lazada.rb, app/services/lazada/*
  - Frontend: app/javascript/dashboard/components-next/message/MessageMeta.vue

---

## Conflict Resolution Strategy

When merging develop into feature branches, common conflicts may occur in:

1. Database Migrations
   - Keep both migrations
   - Rename custom migration timestamps if needed to maintain chronological order

2. Routes
   - Preserve custom routes (e.g., /webhooks/lazada/:shop_id)
   - Merge new official routes

3. Gemfile/package.json
   - Use official versions unless custom version is required
   - Test thoroughly after dependency updates

4. Model Changes
   - Review official changes to core models (Message, Inbox, Contact)
   - Ensure custom integrations remain compatible

---

## Remote Configuration

Current remotes:
  origin: https://github.com/shrihari1999/chatwoot.git
  upstream: https://github.com/chatwoot/chatwoot.git

---

## Current Branch Status (March 31, 2025)

Local Branches:
  develop                -> tracks upstream/develop (b4b5de9b46)
  production             -> your stable code (6d35137da3)
  feature/canned-response-images-claude -> active development (6d35137da3)

Remote Branches (your fork):
  origin/production
  origin/develop
  origin/feature/canned-response-images-claude

---

## Database Migration Considerations

Since you have a single production database:

1. Before merging upstream develop:
   - Review new migrations in upstream
   - Check for destructive changes (column removals, table drops)

2. After merge, before deploy:
   - Run migrations in a transaction: bundle exec rails db:migrate
   - Always backup database first

3. Rollback plan: Keep previous Git SHA and database backup for quick recovery

---

## Tips

- Sync develop weekly to stay current with official updates
- Test after every merge from develop to feature branch
- Document custom changes in this file for future reference
- Review upstream PRs that touch files you have customized
- Keep features small for easier conflict resolution

