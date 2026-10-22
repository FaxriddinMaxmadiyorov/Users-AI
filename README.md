# Users AI

Task #4 (Ruby group): a Rails application with registration and authentication, a user management table (select, block, unblock, delete), natural-language questions about the data, and an AI assistant that controls the table.

Stack: Ruby 3.2, Rails 8.1, PostgreSQL, Hotwire (Turbo + Stimulus), Google Gemini API (REST, no SDK).

## Setup

```bash
bundle install
cp .env.example .env            # DB credentials and GEMINI_API_KEY
bin/rails db:create db:migrate db:seed
bin/rails server
```

`.env`:

```
DB_USERNAME=postgres
DB_PASSWORD=
DB_HOST=localhost
GEMINI_API_KEY=AIza...
GEMINI_MODEL=gemini-3.8-flash
```

The API key comes from https://aistudio.google.com (Get API key). The free tier is enough: about 5 requests per minute, and one question usually takes two requests (tool call + answer). The client retries on 429/5xx using the delay Google returns, so bursts of questions slow down rather than fail.

Seed loads the 200 users from `db/data/users.json` (the file provided with the task) and removes everyone else, so the database contains only those users. Their password is `password`. Register your own account to get an active admin.

```bash
bin/rails test
```

Tests cover the filter engine, the AI tools against a real database, the assistant loop with a fake model (no network, no key needed), and the generated auth controllers.

## Part 1: web application

- Registration and login: `RegistrationsController` on top of the Rails 8 built-in authentication generator (`has_secure_password`, `Session` records, signed cookie, rate limiting). No Devise.
- Users table: name, e-mail, job position, last seen, status. Server-side filters and sorting live in one class, `UserQuery`: substring on name/e-mail/job, e-mail prefix list (`s, p`), domain, status, last-seen and registration date ranges. The filter form is a plain GET form, so every view is a shareable URL such as `/users?email_starts_with=s,p&status=active&sort=name&dir=asc`.
- Management: checkbox per row plus select-all (Stimulus `selection_controller`), toolbar with Block, Unblock and Delete for the selected users. Every user is an admin, including over themselves: blocking or deleting your own account ends the session and redirects to the login page on the next request; a blocked user cannot log in.
- Database: `users.email_address` has a unique index (`index_users_on_email_address`); `name`, `status` and `last_seen` are indexed for filtering and sorting.

## Part 2: natural-language questions

The model never receives the table. It receives a list of functions and decides which to call; the application executes them in SQL and returns small, exact results.

- `Ai::GeminiClient`: thin `Net::HTTP` wrapper around `generateContent` with function declarations and retry.
- `Ai::Tools`: the functions the model may call.
  - `count_users(filters)` — `COUNT(*)`
  - `list_users(filters, limit)` — up to 50 rows plus the total count
  - `aggregate_users(group_by, filters)` — `GROUP BY` status, job position, e-mail domain, last-seen month, registration month, first letter
  - `find_user(email)` — exact lookup
- `Ai::Assistant`: the function-calling loop (at most 6 steps). Each tool call and its result are recorded in a trace that the endpoint returns, so you can see which query produced a number.
- `Ai::FilterSchema`: JSON schema of the filter object, shared by every tool. It is the same vocabulary `UserQuery` understands, so "e-mails starting with s or p" becomes `{"email_starts_with": ["s","p"]}` and runs as `email_address LIKE 's%' OR email_address LIKE 'p%'`.

Why this avoids hallucinated numbers: counting and grouping happen in PostgreSQL, the model only phrases the result. The system prompt forbids answering without a tool call, temperature is 0, and tool results never include `password_digest`. The assistant is read-only: it cannot block, unblock or delete anyone and says so if asked.

## Part 3: AI controls the table

Three more tools do not touch the database. They return a UI command:

- `apply_table_filters(filters)` — replaces the table's filter set
- `sort_table(sort, dir)` — keeps the current filters, changes the order
- `clear_table_filters()` — reset

`get_table_state()` tells the model what the table currently shows, so "also hide users seen before June" adds a condition instead of replacing everything.

`POST /assistant` returns `{ answer, command, tool_calls }`. The Stimulus controller (`assistant_controller.js`) prints the answer and, when `command.type == "navigate"`, builds `/users?…` from the filters and performs a `Turbo.visit`. The table itself has no AI code; it renders whatever filters are in the URL, the same way the manual form does. Conversation history is kept in `sessionStorage` on the client and sent with each request, so the server stays stateless.

## Example prompts

Questions:

- How many users are blocked?
- Which job position is the most common?
- How many users were last seen in August 2026?
- List 5 users whose job contains "Banking", most recently seen first.
- Is there a user with e-mail tod@waelchi.test?
- How many users have e-mails starting with s or p?

Commands:

- Show only blocked users.
- Select users with e-mails starting with s or p.
- Also show only those last seen after June.
- Sort the table by name descending.
- Clear filters.

## Project layout

```
app/controllers/registrations_controller.rb   sign-up
app/controllers/users_controller.rb           table, block / unblock / delete
app/controllers/assistant_controller.rb       POST /assistant
app/controllers/concerns/authentication.rb    session handling, blocked-user check
app/queries/user_query.rb                     the single filter engine
app/services/ai/filter_schema.rb              JSON schema of the filters
app/services/ai/tools.rb                      functions the model can call
app/services/ai/assistant.rb                  function-calling loop
app/services/ai/gemini_client.rb              HTTP client with retry
app/javascript/controllers/assistant_controller.js
app/javascript/controllers/selection_controller.js
app/views/shared/_assistant.html.erb          chat panel
db/data/users.json                            seed data from the task
test/queries, test/services/ai               tests
```

## Limitations

- The Users page shows at most 200 rows (no pagination); the seed has exactly 200.
- Filters are what `UserQuery` supports. If a command cannot be expressed with them, the assistant says so instead of pretending.
- Gemini free tier: about 5 requests per minute. For a demo with many rapid questions, enable billing in AI Studio or wait a few seconds between prompts.
