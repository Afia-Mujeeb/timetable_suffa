import { Hono } from "hono";

type Bindings = {
  APP_NAME?: string;
  ADMIN_ENV?: string;
};

export const app = new Hono<{ Bindings: Bindings }>();

function getBindings(context: { env?: Bindings }): Bindings {
  return context.env ?? {};
}

app.get("/health", (context) => {
  const env = getBindings(context);

  return context.json({
    service: env.APP_NAME ?? "timetable-worker-admin",
    status: "ok",
    environment: env.ADMIN_ENV ?? "local",
  });
});

app.get("/imports/status", (context) => {
  const env = getBindings(context);

  return context.json({
    service: env.APP_NAME ?? "timetable-worker-admin",
    status: "idle",
    environment: env.ADMIN_ENV ?? "local",
  });
});

export default {
  fetch: app.fetch,
};
