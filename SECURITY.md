# Security Policy

## Reporting a Vulnerability

Please do not open a public issue for security vulnerabilities.

If you find a vulnerability, report it privately through GitHub's security reporting tools when available, or contact the project maintainer directly.

Please include:

- A clear description of the issue
- Steps to reproduce
- Impacted feature or endpoint
- Any relevant screenshots, logs, or proof of concept details

We will review reports as quickly as possible and avoid disclosing details until a fix is available.

## Supported Versions

This project currently supports the latest version on the `master` branch.

## Stock Data Access

Stock tables are protected by the Supabase migration in
`supabase/migrations/20260826010000_secure_stock_tables.sql`.

- The `anon` role has no table privileges.
- Supabase anonymous sign-ins (`is_anonymous=true`) cannot read stock data.
- Registered authenticated users have read-only access.
- Inserts, updates, and deletes are reserved for the backend `service_role`.
- FastAPI `/stock/*` routes additionally require an authenticated admin user.

Apply all Supabase migrations before deploying the API or client. Never expose
the Supabase service-role key in Flutter, web, or other client-side code.
