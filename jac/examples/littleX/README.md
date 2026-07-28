# Little X

A full Twitter-style social app in Jac: the backend (3 node types, 4 edge
types, 20 walkers) lives in `social_graph.jac`, the React-style frontend in
`frontend.jac` + `components/`.

## Run it

```bash
jac start main.jac
```

State goes to local files under `.jac/data/` by default.

## Run it serverless (Supabase)

Little X is also the reference app for **jac-serverless**: same code, no
changes, just a database URL. Point it at a managed Postgres (for example a
[Supabase](https://supabase.com) project: Settings > Database > Connection
string) and the whole app becomes stateless; the graph and users live in the
database.

```bash
export SUPABASE_DB_URL="postgresql://postgres:PASSWORD@db.PROJECT.supabase.co:5432/postgres"
jac start main.jac --serverless
```

That is all. Kill the process, cold start it anywhere else with the same URL,
and every user, tweet, and follow is still there. The URL can also be set as
`DATABASE_URL`, or committed as `[serverless] database_url` in `jac.toml`
(with a URL configured, serverless mode also engages without the flag; the
flag makes it explicit and fails fast when no database is configured).

### Walkers as serverless functions

The `jac serverless` command runs and ships the app as a single serverless
function (AWS Lambda function URL semantics; every walker is an endpoint):

```bash
# one-shot local invocation, function-style
jac serverless invoke --file social_graph.jac --method GET --path /healthz

# build dist/function.zip for AWS Lambda (python3.13, handler.handler)
jac serverless package --file social_graph.jac

# package + deploy to AWS Lambda with a public function URL
jac serverless deploy --file social_graph.jac --role_arn arn:aws:iam::ACCOUNT:role/LAMBDA_ROLE
```

`deploy` passes the resolved database URL to the function as `DATABASE_URL`,
so the Lambda is fully stateless against Supabase.

## Tests

```bash
jac test tests/test_littlex.jac
```

Note: with a shared external database the tests contaminate each other's
state (they were written assuming isolated per-test stores); run them against
a disposable database, or without `SUPABASE_DB_URL`/`DATABASE_URL` set.
