# Requirements Document

## Introduction

The Messaging System enables employers and workers to communicate after an application is accepted or an invitation is accepted, covering Employer Flow step 8 and Worker Flow step 8. The system enforces the Messaging Rule: conversations are locked until an application or invitation is accepted. Users can view their conversations, send messages, mark messages as read, and report users. The system prevents messaging between users before the hiring relationship is established.

## Glossary

- **Conversation**: A messaging thread between an employer and worker linked to a specific job
- **Message**: A text communication sent within a conversation
- **Locked_Conversation**: A conversation with status=locked that prevents message sending
- **Unlocked_Conversation**: A conversation with status=unlocked that allows messaging
- **Messaging_Provider**: Flutter ChangeNotifier managing messaging state
- **Message_Preview**: The last message text and timestamp shown in conversation list
- **Report_User**: An action to flag inappropriate behavior

## Requirements

### Requirement 1: List User's Conversations

**User Story:** As a user, I want to view all my conversations via the API, so that I can see my message threads.

#### Acceptance Criteria

1. WHILE authenticated via Sanctum token, WHEN a user requests GET /api/v1/conversations, THE API SHALL return all conversations WHERE (employer_id=user_id OR worker_id=user_id) AND status="unlocked"
2. THE API SHALL support pagination with query parameters: page (integer, default 1), per_page (integer, default 20, max 50)
3. THE API SHALL order conversations by last_message.timestamp descending (most recent first), with conversations having no messages appearing last ordered by created_at descending
4. THE data array SHALL contain conversation objects, each with: id, job {id, title}, other_party {id, name, photo (URL or null), verification_status (boolean)}, last_message {id, text (max 100 chars preview), timestamp, sender_id} or null if no messages, unread_count (integer), created_at
5. THE unread_count SHALL be calculated as COUNT of messages WHERE is_read=false AND sender_id=other_party_id
6. IF a conversation participant has been deleted, THEN other_party.name SHALL be "Deleted User" and photo SHALL be null
7. IF the user has no unlocked conversations, THEN THE API SHALL return {"success": true, "data": [], "message": "No conversations found", "pagination": {current_page: 1, per_page: 20, total: 0, last_page: 1}}
8. WHEN conversations exist, THE API SHALL return {"success": true, "data": [...], "message": "Conversations retrieved", "pagination": {current_page, per_page, total, last_page, from, to}}

### Requirement 2: Retrieve Conversation Messages

**User Story:** As a user, I want to retrieve messages from a conversation via the API, so that I can view the message history.

#### Acceptance Criteria

1. WHILE authenticated via Sanctum token, WHEN a user requests GET /api/v1/conversations/{id}/messages, THE API SHALL verify the user is a participant (employer_id=user_id OR worker_id=user_id)
2. IF the conversation_id does not exist, THEN THE API SHALL return a 404 error with {"success": false, "data": null, "message": "Conversation not found"}
3. IF the user is not a participant in the conversation, THEN THE API SHALL return a 403 error with {"success": false, "data": null, "message": "You do not have permission to view this conversation"}
4. THE API SHALL support pagination with query parameters: page (integer, default 1), per_page (integer, default 50, max 100)
5. THE API SHALL order messages by created_at ascending (oldest first) so new messages appear at the bottom
6. THE data array SHALL contain message objects, each with: id, sender_id, sender_name (string max 100 chars), message_text (string max 2000 chars), is_read (boolean), created_at (ISO 8601 timestamp)
7. IF a message sender has been deleted, THEN sender_name SHALL be "Deleted User"
8. IF the conversation has no messages, THEN THE API SHALL return {"success": true, "data": [], "message": "No messages found", "pagination": {current_page: 1, per_page: 50, total: 0, last_page: 1}}
9. WHEN messages exist, THE API SHALL return {"success": true, "data": [...], "message": "Messages retrieved", "pagination": {current_page, per_page, total, last_page, from, to}}

### Requirement 3: Send Message in Conversation

**User Story:** As a user, I want to send a message in a conversation via the API, so that I can communicate with the other party.

#### Acceptance Criteria

1. WHILE authenticated via Sanctum token, WHEN a user sends POST /api/v1/conversations/{id}/messages with request body {message_text: string}, THE API SHALL validate all conditions before creating the message
2. IF the conversation_id does not exist, THEN THE API SHALL return a 404 error with {"success": false, "data": null, "message": "Conversation not found"}
3. IF the user is not a participant in the conversation, THEN THE API SHALL return a 403 error with {"success": false, "data": null, "message": "You do not have permission to send messages in this conversation"}
4. IF the conversation status="locked", THEN THE API SHALL return a 403 error with {"success": false, "data": null, "message": "Messaging unlocks once the application is accepted"}
5. IF message_text is missing or empty (after trimming whitespace), THEN THE API SHALL return a 422 error with {"success": false, "data": null, "message": "message_text is required"}
6. IF message_text length > 2000 characters, THEN THE API SHALL return a 422 error with {"success": false, "data": null, "message": "message_text must not exceed 2000 characters"}
7. IF a block exists WHERE (blocker_id=user_id AND blocked_user_id=other_participant_id) OR (blocker_id=other_participant_id AND blocked_user_id=user_id), THEN THE API SHALL return a 403 error with {"success": false, "data": null, "message": "You cannot message this user"}
8. IF the other participant's account has account_status="suspended", THEN THE API SHALL return a 422 error with {"success": false, "data": null, "message": "The recipient's account is not available"}
9. WHILE all validations pass, WHEN the user sends the message, THE API SHALL create a message record with conversation_id, sender_id (authenticated user), message_text (trimmed), is_read=false, created_at, updated_at
10. WHEN the operation succeeds, THE API SHALL return {"success": true, "data": {message object with id, sender_id, sender_name, message_text, is_read, created_at}, "message": "Message sent successfully"}

### Requirement 4: Mark Messages as Read

**User Story:** As a user, I want to mark messages as read via the API, so that I can track which messages I've viewed.

#### Acceptance Criteria

1. WHILE authenticated via Sanctum token, WHEN a user sends PATCH /api/v1/conversations/{id}/read, THE API SHALL verify the user is a participant in the conversation
2. IF the conversation_id does not exist, THEN THE API SHALL return a 404 error with {"success": false, "data": null, "message": "Conversation not found"}
3. IF the user is not a participant, THEN THE API SHALL return a 403 error with {"success": false, "data": null, "message": "You do not have permission to access this conversation"}
4. WHILE the user is a participant, WHEN the request processes, THE API SHALL update all messages WHERE conversation_id={id} AND sender_id!={authenticated_user_id} AND is_read=false, setting is_read=true and updated_at=current_timestamp
5. THE API SHALL return the count of messages marked as read
6. WHEN the operation succeeds, THE API SHALL return {"success": true, "data": {marked_read_count: integer}, "message": "Messages marked as read"}

### Requirement 5: Conversations Screen in Flutter

**User Story:** As a user, I want to view all my conversations in the mobile app, so that I can access my message threads.

#### Acceptance Criteria

1. THE App SHALL provide a Conversations screen accessible from the main navigation
2. WHEN the screen loads, THE App SHALL call GET /api/v1/conversations
3. THE App SHALL display a search bar at the top to filter by name or job title
4. THE App SHALL display filter options (by job, by unread)
5. THE App SHALL display each conversation as a card showing: other party's photo, name with verification badge (if verified), job title, last message preview (truncated to 50 chars), timestamp (relative format), unread count badge
6. THE App SHALL display the unread count badge only if unread_count > 0
7. WHEN the user taps a conversation card, THE App SHALL navigate to the Chat screen
8. IF the user has no conversations, THEN THE App SHALL display an empty state message
9. THE App SHALL apply the design system colors, typography, and spacing

### Requirement 6: Chat Screen in Flutter

**User Story:** As a user, I want to send and view messages in a conversation in the mobile app, so that I can communicate with the other party.

#### Acceptance Criteria

1. THE App SHALL provide a Chat screen accessible from the Conversations screen
2. WHEN the screen loads, THE App SHALL call GET /api/v1/conversations/{id}/messages
3. THE App SHALL call PATCH /api/v1/conversations/{id}/read to mark messages as read
4. THE App SHALL display the other party's name with verification badge in the app bar
5. THE App SHALL display a "Report User" action in the app bar menu
6. THE App SHALL display message bubbles with sender's message on the right (accent color) and recipient's messages on the left (neutral color)
7. THE App SHALL display each message with text, timestamp, and read indicator (for user's own messages)
8. THE App SHALL display a message input field at the bottom with a send button
9. WHEN the user types a message and taps send, THE App SHALL call POST /api/v1/conversations/{id}/messages
10. WHEN the message send succeeds, THE App SHALL add the message to the display immediately and clear the input
11. THE App SHALL implement pagination to load older messages when scrolling to the top
12. IF the conversation is locked, THEN THE App SHALL hide the message input and display a message "Messaging unlocks once the application is accepted"
13. WHEN the user taps Report User, THE App SHALL call the report endpoint (from SPEC 11)
14. THE App SHALL apply the design system colors, typography, and spacing

### Requirement 7: Messaging Provider State Management

**User Story:** As a developer, I want a MessagingProvider ChangeNotifier, so that messaging state is managed consistently across the app.

#### Acceptance Criteria

1. THE App SHALL implement a MessagingProvider class extending ChangeNotifier
2. THE MessagingProvider SHALL maintain a list of conversations
3. THE MessagingProvider SHALL maintain a map of messages by conversation_id
4. THE MessagingProvider SHALL provide methods: fetchConversations, fetchMessages, sendMessage, markAsRead
5. WHEN fetchConversations is called, THE MessagingProvider SHALL call GET /api/v1/conversations and update state
6. WHEN fetchMessages is called, THE MessagingProvider SHALL call GET /api/v1/conversations/{id}/messages and update state
7. WHEN sendMessage is called, THE MessagingProvider SHALL call POST /api/v1/conversations/{id}/messages and update state
8. WHEN markAsRead is called, THE MessagingProvider SHALL call PATCH /api/v1/conversations/{id}/read
9. WHEN any method completes, THE MessagingProvider SHALL call notifyListeners
10. THE MessagingProvider SHALL expose loading and error states
11. THE App SHALL provide MessagingProvider at the app root using ChangeNotifierProvider

### Requirement 8: Message Data Model

**User Story:** As a developer, I want Message and Conversation model classes, so that I can represent messaging data consistently.

#### Acceptance Criteria

1. THE App SHALL implement a Message model with fields: id, conversation_id, sender_id, sender_name, message_text, is_read, created_at
2. THE App SHALL implement a Conversation model with fields: id, job_id, job_title, employer_id, worker_id, other_party (name, photo, verification_status), last_message (text, timestamp, sender_id), unread_count, status, created_at, updated_at
3. BOTH models SHALL include fromJson factory constructors
4. BOTH models SHALL include toJson methods

### Requirement 9: Database Schema for Messages

**User Story:** As a developer, I want a database table to store messages, so that message data persists.

#### Acceptance Criteria

1. THE API SHALL create a table named messages with columns: id (bigint auto-increment), conversation_id (bigint), sender_id (bigint), message_text (text), is_read (boolean default false), created_at, updated_at
2. THE API SHALL create foreign key from conversation_id to conversations.id with onDelete=CASCADE
3. THE API SHALL create foreign key from sender_id to users.id with onDelete=CASCADE
4. THE API SHALL create an index on conversation_id for fast message retrieval
5. THE API SHALL create an index on (conversation_id, is_read) for unread count queries

### Requirement 10: Real-time Message Updates (Optional Enhancement)

**User Story:** As a user, I want to receive new messages in real-time, so that I can have fluid conversations.

#### Acceptance Criteria

1. THE App MAY implement polling to fetch new messages every 5-10 seconds when the Chat screen is active
2. THE App MAY use Laravel Broadcasting with Pusher or similar for real-time updates (deferred to future iteration)
3. WHEN new messages arrive, THE App SHALL update the Chat screen display without user action

### Requirement 11: Navigation Integration

**User Story:** As a user, I want to navigate between messaging screens, so that I can access conversations and chat.

#### Acceptance Criteria

1. THE App SHALL define named routes in AppRoutes for: conversations, chat
2. THE App SHALL add Conversations to the main navigation
3. THE App SHALL support passing conversation_id to the chat screen
4. THE App SHALL maintain navigation stack correctly when navigating between messaging screens
