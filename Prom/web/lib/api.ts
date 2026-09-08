import type { Answer, AnswerResult, ServerState } from "./types";

/**
 * All requests go to /api/* on the same origin; Next rewrites them to the Go
 * service (see next.config.ts). Same-origin means the unlock cookie just works.
 */

class ApiError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
    this.name = "ApiError";
  }
}

async function req<T>(path: string, init?: RequestInit): Promise<T> {
  let res: Response;
  try {
    res = await fetch(path, {
      ...init,
      credentials: "same-origin",
      cache: "no-store",
      headers: { "Content-Type": "application/json", ...(init?.headers ?? {}) },
    });
  } catch {
    throw new ApiError(0, "Can't reach the server. Check your connection ♡");
  }

  const data = (await res.json().catch(() => ({}))) as Record<string, unknown>;
  if (!res.ok) {
    throw new ApiError(res.status, (data.error as string) ?? "Something went wrong.");
  }
  return data as T;
}

export const api = {
  getState: () => req<ServerState>("/api/state"),

  unlock: (password: string) =>
    req<{ ok: true }>("/api/unlock", {
      method: "POST",
      body: JSON.stringify({ password }),
    }),

  answer: (answer: Answer) =>
    req<AnswerResult>("/api/answer", {
      method: "POST",
      body: JSON.stringify({ answer }),
    }),
};

export { ApiError };
