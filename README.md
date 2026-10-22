# Users AI

Task #4 (Ruby group): a Rails application with registration and authentication, a users table, natural-language questions about the data, and an AI assistant that controls the table.

Stack: Ruby 3.2, Rails 8.1, PostgreSQL, Hotwire (Turbo + Stimulus), Google Gemini API (REST, no SDK).

## Setup

```bash
bundle install
cp .env.example .env        # fill in GEMINI_API_KEY
bin/rails db:create db:migrate db:seed
bin/rails server
```

`.env`:

```
GEMINI_API_KEY=AIza...
GEMINI_MODEL=gemini-3.8-flash
```

The API key comes from https://aistudio.google.com (Get API key). The free tier is enough; it allows ~5 requests per minute, and one question usually takes two requests (tool call + answer). The client retries on 429 using the delay Google returns, so bursts of questions slow down rather than fail.

Seed creates 73 users and `admin@example.com / password`. Register your own account or log in as admin.

```bash
bin/rails test
```

Tests cover the filter engine, the AI tools against a real database, and the assistant loop with a fake model (no network, no key needed).

## Part 1: web application

- Registration: `RegistrationsController` on top of the Rails 8 built-in authentication generator (`has_secure_password`, `Session` records, signed cookie, rate limiting). No Devise.
- Users page: `UsersController#index` with server-side filters and sorting. All filtering lives in one class, `UserQuery`: substring on name/e-mail, e-mail prefix list (`s, p`), domain, registration date range, sort by name/e-mail/date. The filter form is a plain GET form, so every view is a shareable URL like `/users?email_starts_with=s,p&sort=name&dir=asc`.

## Part 2: natural-language questions

The model never receives the table. It receives a list of functions and decides which to call; the application executes them in SQL and sends back small, exact results.

- `Ai::GeminiClient`: thin `Net::HTTP` wrapper around `generateContent` with function declarations and 429 retry.
- `Ai::Tools`: the functions the model may call.
  - `count_users(filters)` — `COUNT(*)`
  - `list_users(filters, limit)` — up to 50 rows plus the total count
  - `aggregate_users(group_by, filters)` — `GROUP BY` e-mail domain, registration month/year, first letter
  - `find_user(email)` — exact lookup
- `Ai::Assistant`: the function-calling loop (at most 6 steps). Each tool call and its result are recorded in a trace that the endpoint returns, so you can see exactly which query produced a number.
- `Ai::FilterSchema`: JSON schema of the filter object, shared by every tool. It is the same vocabulary `UserQuery` understands, so "e-mails starting with s or p" becomes `{"email_starts_with": ["s","p"]}` and runs as `email_address LIKE 's%' OR email_address LIKE 'p%'`.

Why this avoids hallucinated numbers: counting and grouping happen in PostgreSQL, the model only phrases the result. The system prompt forbids answering without a tool call, temperature is 0, and tool results never include `password_digest`.

## Part 3: AI controls the table

Three more tools do not touch the database. They return a UI command:

- `apply_table_filters(filters)` — replaces the table's filter set
- `sort_table(sort, dir)` — keeps the current filters, changes the order
- `clear_table_filters()` — reset

`get_table_state()` tells the model what the table currently shows, so "also hide users registered before 2026" adds a condition instead of replacing everything.

`POST /assistant` returns `{ answer, command, tool_calls }`. The Stimulus controller (`assistant_controller.js`) prints the answer and, when `command.type == "navigate"`, builds `/users?…` from the filters and performs a `Turbo.visit`. The table itself has no AI code; it renders whatever filters are in the URL, the same way the manual form does. Conversation history is kept in `sessionStorage` on the client and sent with each request, so the server stays stateless.

## Example prompts

Questions:

- How many users registered in the last 30 days?
- Which e-mail domain is the most common?
- List users whose name contains "an", newest first.
- Is there a user with e-mail anna@gmail.com?
- How many registrations were there per month this year?

Commands:

- Show only users with e-mails starting with s or p.
- Sort the table by name descending.
- Also hide users registered before 2026.
- Filter users from gmail.com registered this year.
- Clear filters.

## Project layout

```
app/controllers/registrations_controller.rb   sign-up
app/controllers/users_controller.rb           table with filters
app/controllers/assistant_controller.rb       POST /assistant
app/queries/user_query.rb                     the single filter engine
app/services/ai/filter_schema.rb              JSON schema of the filters
app/services/ai/tools.rb                      functions the model can call
app/services/ai/assistant.rb                  function-calling loop
app/services/ai/gemini_client.rb              HTTP client
app/javascript/controllers/assistant_controller.js
app/views/shared/_assistant.html.erb          chat panel
test/queries, test/services/ai               tests
```

## Limitations

- The Users page shows at most 200 rows (no pagination); the seed has 73.
- Filters are what `UserQuery` supports. If a command cannot be expressed with them, the assistant says so instead of pretending.
- Gemini free tier: about 5 requests per minute. For a demo with many rapid questions, enable billing in AI Studio or wait a few seconds between prompts.
