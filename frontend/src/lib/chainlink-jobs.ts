export const CHAINLINK_JOBS = [
  {
    name: "deco-verification",
    type: "Webhook",
    description: "On-demand DECO verification triggered via HTTP",
    status: "Configured",
    externalJobId: "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  },
  {
    name: "deco-verification-cron",
    type: "Cron",
    schedule: "Every 1 minute",
    description: "Scheduled DECO verification polling",
    status: "Configured",
    externalJobId: "b2c3d4e5-f6a7-8901-bcde-f23456789012",
  },
] as const;
