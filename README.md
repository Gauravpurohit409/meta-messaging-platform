# Marquee

Marquee is a WhatsApp campaign desk. You draft a message template, submit it to Meta for review, and — once it is approved — send it to customers who opted in.

It is a Rails monolith: Hotwire for the desk, PostgreSQL for the records, Sidekiq and Redis for the sends, and the WhatsApp Cloud API for the live calls. The product notes from the research sit in [WHATSAPP_CAMPAIGN_PLATFORM_RD.md](WHATSAPP_CAMPAIGN_PLATFORM_RD.md).

## What you can do

- Draft a template with a header, body, footer, and up to three buttons, and watch a phone preview while you type.
- Submit it for review. In demo mode the decision comes back in a few seconds. In live mode Meta reviews it and the status webhook updates the desk.
- Build a campaign from an approved template, a shared set of variable values, and a list of phone numbers or a CSV.
- Launch now or schedule it. Sidekiq sends one message at a time, under the Cloud API throughput, and the campaign page updates as delivery receipts arrive.

## Demo mode

A new desk starts in demo mode, so you can use the product before a Meta app exists.

- Submitting a template sets it to pending, then approves it about three seconds later.
- If the body mentions “legal action”, “scam”, or “you have won”, or the template name contains `reject`, the demo review rejects it.
- Numbers ending in `0000` fail delivery. Every other number is marked delivered a couple of seconds after send.
- Nothing is sent to WhatsApp while demo mode is on.

Turn demo mode off under Connection once you have a WhatsApp Business account id, a phone number id, and a system user token. The token needs `whatsapp_business_messaging` and `whatsapp_business_management`.

## Run it

You need Ruby 3.2, PostgreSQL, and Redis.

```bash
bundle install
bin/rails db:prepare db:seed
bin/dev
```

`bin/dev` starts the web server on port **47291**, the Tailwind watcher, and a Sidekiq worker. Open [http://127.0.0.1:47291](http://127.0.0.1:47291).

Sign in to the seeded desk:

- Email: `demo@marquee.test`
- Password: `password123`

After you seed the database, Evening restock ping is a draft. Open it and launch it to watch demo delivery, including one failed number.

PostgreSQL and Redis have to be running. On this machine:

```bash
sudo pg_ctlcluster 16 main start
redis-server --daemonize yes
```

## Connect Meta for real

1. Create a Meta app with the WhatsApp use case and finish business verification.
2. Create a Facebook Login for Business configuration for Embedded Signup. Set `META_APP_ID`, `META_APP_SECRET`, and `META_EMBEDDED_SIGNUP_CONFIG_ID`.
3. In the Meta app, set the webhook callback to `https://your-host/webhooks/meta` and set the verify token to the same value as `META_VERIFY_TOKEN`.
4. Subscribe to `message_template_status_update`, `messages`, and `account_update`.
5. A business opens Connection and chooses Connect with Meta. Embedded Signup returns a code, and Marquee exchanges it, subscribes to the WhatsApp account, and registers the phone number.

Demo mode can still store a token for rehearsal. It does not call Meta.

Template sends go to `POST /{phone-number-id}/messages` on Graph `v26.0`. Marketing-only features of the Marketing Messages API are not wired up yet.

## Tests

```bash
bundle exec rspec
```

## Deploy on Render

`render.yaml` is a Render Blueprint. In the [Render dashboard](https://dashboard.render.com), choose **New → Blueprint**, connect this repository, and apply it. Render creates:

| Resource | Plan | Role |
| --- | --- | --- |
| `meta-messaging-db` | Basic Postgres | App database. Stays up so desks are not wiped after 30 days. |
| `meta-messaging-redis` | Starter | Sidekiq and Action Cable. Keeps queued sends across restarts. |
| `meta-messaging-platform` | Starter | Puma. Stays awake so Meta can deliver webhooks. |
| `meta-messaging-worker` | Starter | Sidekiq. Sends campaigns and processes webhooks. |
| `meta-messaging-retention` | Starter | Daily purge of old webhook events and old recipients. |

The first deploy migrates and seeds the demo desk (`demo@marquee.test` / `password123`). The health check is `/up`.

`bundle install` prints a Tailwind note that says to pin `tailwindcss-rails` to `~> 3.3.1`. Ignore that note. This app is already on Tailwind v4, and that pin would break the stylesheet.

You do not need a shell or a local machine to set `SECRET_KEY_BASE`. A blank value makes Rails abort the build. The app fills one in when the variable is missing. Sign-in cookies reset if the service restarts before you set your own. To keep them stable, open the web service in the Render dashboard, go to **Environment**, and set `SECRET_KEY_BASE` to any long random string. The free plan has no shell, and this field does not need one.

After the services are up, open the web service URL, sign in, and use Connection when you want live WhatsApp sends. Add `META_APP_SECRET` on the web service before Meta starts posting webhooks. Webhook URL: `https://<your-service>.onrender.com/webhooks/meta`.

The blueprint generates the Active Record encryption keys on the web service and copies them to the worker. Leave those in place after a WhatsApp token has been saved. `SECRET_KEY_BASE` can stay blank; the app supplies one when Render does not.

Set `SUPPORT_EMAIL` to the address customers use to ask for deletion. Set `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_USERNAME`, and `SMTP_PASSWORD` so confirmation and unlock email can be delivered. `RETENTION_WEBHOOK_DAYS` defaults to 30 and `RETENTION_RECIPIENT_DAYS` defaults to 180.
