# Chatwoot Fork — Claude Context

## What This Is

This is a self-hosted fork of [Chatwoot](https://github.com/chatwoot/chatwoot) maintained at `github.com/shrihari1999/chatwoot`. The fork adds custom features on top of upstream Chatwoot OSS. The main branch is `develop`.

## Production Instance

- **Host**: `5.223.57.108` (Hetzner cpx32, Singapore)
- **SSH**: `ssh chatwoot@5.223.57.108` (default `~/.ssh/id_ed25519`, no `-i`/`.pem`); use `ssh root@5.223.57.108` for `systemctl`
- **App directory on server**: `/home/chatwoot/chatwoot`
- **Ruby managed via**: `rvm` (not rbenv — the server uses rvm)
- **Process manager**: systemd (`chatwoot.target`)
- **Storage**: ActiveStorage (local disk by default)

## Deployment Procedure

```bash
# On local machine: push changes
git push origin <branch-name>

# On server:
cd /home/chatwoot/chatwoot
git fetch origin
git checkout <branch-name>
bundle install

# Only if frontend files changed (Vue, JS, CSS, JSON i18n):
RAILS_ENV=production bundle exec rails assets:precompile   # ~2 min

# Only if migrations were added:
RAILS_ENV=production bundle exec rails db:migrate

# Always restart after deploying:
sudo systemctl restart chatwoot.target

# Verify:
sudo systemctl status chatwoot.target
```

**When is asset precompile needed?** Any change to files under `app/javascript/`, including Vue components, JS modules, and i18n JSON files. Pure Ruby changes (models, controllers, services) only need a restart.

## Custom Features Added

### 1. Canned Response Image Attachments

**Branch**: `feature/canned-response-images-claude`

Adds image upload support to canned responses. When an agent uses a canned response, attached images are automatically included as message attachments.

**Files modified** (9 files):
- `app/models/canned_response.rb` — `has_many_attached :files`, `file_base_data`, `as_json` override
- `app/controllers/api/v1/accounts/canned_responses_controller.rb` — file attach/detach on create/update, `with_attached_files` eager loading
- `app/javascript/dashboard/routes/dashboard/settings/canned/AddCanned.vue` — image upload UI
- `app/javascript/dashboard/routes/dashboard/settings/canned/EditCanned.vue` — image upload UI with existing file display
- `app/javascript/dashboard/routes/dashboard/settings/canned/Index.vue` — image thumbnails in list, `edfiles` prop
- `app/javascript/dashboard/components/widgets/conversation/CannedResponse.vue` — emits `attachFiles` with file data
- `app/javascript/dashboard/components/widgets/WootWriter/Editor.vue` — forwards `attachCannedFiles` event
- `app/javascript/dashboard/components/widgets/conversation/ReplyBox.vue` — `attachCannedResponseFiles` method, payload prefers `blobSignedId`
- `app/javascript/dashboard/i18n/locale/en/cannedMgmt.json` — i18n strings for file upload UI

**Architecture pattern**: Uses ActiveStorage `has_many_attached :files` (same as the `Macro` model). Files are uploaded via the existing `/api/v1/accounts/:id/upload` endpoint which returns blob signed IDs. These IDs are passed to the canned response create/update API. When an agent selects a canned response in conversation, the blob signed IDs flow through CannedResponse → Editor → ReplyBox, and are included in the message payload. The same ActiveStorage blobs are shared between the canned response and the message attachments.

## Gotchas & Lessons Learned

### Rails `wrap_parameters` does NOT wrap arrays
Rails' automatic JSON parameter wrapping only wraps scalar values. Arrays and hashes at the top level are **not** nested under the resource key. For example, sending `{ short_code: "abc", file_ids: ["id1"] }` to `CannedResponsesController` results in:
```ruby
params[:canned_response]  # => { "short_code" => "abc" }  — no file_ids!
params[:file_ids]          # => ["id1"]  — it's at the top level
```
**Rule**: Always access array params via `params[:array_name]`, not `params[:resource][:array_name]`.

### ActiveStorage blob sharing
When a canned response file's `blob_signed_id` is used to attach a file to a message, ActiveStorage creates a new attachment record pointing to the **same blob**. Deleting the canned response only detaches its attachment — the blob persists as long as the message's attachment references it.

### Existing upload infrastructure
Chatwoot already has a general-purpose upload endpoint at `Api::V1::Accounts::UploadController` (`/api/v1/accounts/:id/upload`). The frontend helper is `uploadFile()` from `dashboard/helper/uploadHelper.js`. It returns `{ fileUrl, blobKey, blobId }` where `blobId` is the signed ID. Reuse this for any new file upload feature.

### ReplyBox attachment format
When programmatically adding attachments to the reply box (e.g., from canned responses), each entry in `attachedFiles` needs:
```javascript
{
  currentChatId: conversationId,
  resource: { type: contentType, name: filename, size: fileSize },
  isPrivate: boolean,
  thumb: imageUrl,        // used for preview thumbnail
  blobSignedId: signedId, // used in message payload
  isRecordedAudio: false,
}
```
The payload construction prefers `blobSignedId` when present, falling back to `resource.file` for indirect uploads.

## Upstream Sync Strategy

This fork tracks upstream `chatwoot/chatwoot`. When syncing:
1. Add upstream remote: `git remote add upstream https://github.com/chatwoot/chatwoot.git`
2. Fetch and merge: `git fetch upstream && git merge upstream/develop`
3. Resolve conflicts in customized files (listed above)
4. Test, precompile, deploy

## How to Add New Custom Features

Follow the pattern established by the canned response images feature:

1. **Backend**: Use existing Rails patterns (ActiveStorage, strong params, `as_json` overrides). Check the `Macro` model for file attachment patterns.
2. **Frontend**: Use existing helpers (`uploadFile`), Vuex store actions, and component patterns. i18n strings go in `app/javascript/dashboard/i18n/locale/en/`.
3. **Wiring**: For features that connect settings to conversation UI, the event chain is: SettingsComponent → Store → API → Model, and ConversationComponent → Editor → ReplyBox.
4. **Deploy**: Push, pull on server, precompile if frontend changed, restart.

## Key Codebase Landmarks

| Area | Backend | Frontend |
|---|---|---|
| Canned Responses | `app/models/canned_response.rb`, `app/controllers/api/v1/accounts/canned_responses_controller.rb` | `app/javascript/dashboard/routes/dashboard/settings/canned/` |
| File Uploads | `app/controllers/api/v1/accounts/upload_controller.rb` | `app/javascript/dashboard/helper/uploadHelper.js` |
| Message Sending | `app/builders/messages/message_builder.rb` | `app/javascript/dashboard/components/widgets/conversation/ReplyBox.vue` |
| Editor (ProseMirror) | — | `app/javascript/dashboard/components/widgets/WootWriter/Editor.vue` |
| Attachments | `app/models/attachment.rb` | `app/javascript/dashboard/components/widgets/AttachmentsPreview.vue` |
| Macros (file pattern reference) | `app/models/macro.rb` | — |

## Also Read

The upstream `CLAUDE.md` in this repo contains build/test/lint commands, code style rules, and general development guidelines. This file supplements it with fork-specific context.
