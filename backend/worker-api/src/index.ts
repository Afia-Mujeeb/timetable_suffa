import { Hono } from "hono";

type Bindings = {
  APP_NAME?: string;
  API_ENV?: string;
};

export const app = new Hono<{ Bindings: Bindings }>();

function getBindings(context: { env?: Bindings }): Bindings {
  return context.env ?? {};
}

app.get("/", (context) => {
  const env = getBindings(context);

  return context.json({
    service: env.APP_NAME ?? "timetable-worker-api",
    status: "ok",
    environment: env.API_ENV ?? "local",
  });
});

app.get("/health", (context) => {
  const env = getBindings(context);

  return context.json({
    service: env.APP_NAME ?? "timetable-worker-api",
    status: "ok",
    environment: env.API_ENV ?? "local",
  });
});

export default {
  fetch: app.fetch,
};
