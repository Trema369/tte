"use client";

import { useState } from "react";
import { motion, useReducedMotion } from "motion/react";
import { api, ApiError } from "@/lib/api";
import HeartDivider from "./HeartDivider";

export default function Gate({ onUnlock }: { onUnlock: () => void }) {
  const [value, setValue] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [shake, setShake] = useState(0);
  const reduce = useReducedMotion();

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (busy || !value.trim()) return;
    setBusy(true);
    setError(null);
    try {
      await api.unlock(value.trim());
      onUnlock();
    } catch (err) {
      const msg = err instanceof ApiError ? err.message : "Something went wrong.";
      setError(msg);
      setShake((n) => n + 1);
      setBusy(false);
    }
  }

  return (
    <motion.div
      initial={{ opacity: 0, y: 24 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.8, delay: 0.15, ease: [0.22, 1, 0.36, 1] }}
      className="max-w-xl text-center sm:text-left"
    >
      <h1 className="font-serif text-4xl leading-tight text-cream sm:text-5xl lg:text-6xl">
        Something <span className="accent text-rose">special</span>
        <br />
        is waiting for you…
      </h1>

      <HeartDivider className="sm:justify-start" />

      <p className="mx-auto max-w-md text-sm text-cream/75 sm:mx-0 sm:text-base">
        A little secret before you continue.
        <br className="hidden sm:block" /> Enter the password to see what it is.
      </p>

      <motion.form
        onSubmit={submit}
        key={shake}
        animate={shake && !reduce ? { x: [0, -10, 9, -7, 5, 0] } : {}}
        transition={{ duration: 0.4 }}
        className="mt-7"
      >
        <div className="flex items-center gap-2 rounded-full bg-cream/95 p-1.5 pl-5 shadow-[0_10px_40px_-12px_rgba(0,0,0,0.6)] backdrop-blur">
          <LockIcon />
          <input
            type="password"
            autoComplete="off"
            autoCapitalize="off"
            spellCheck={false}
            placeholder="Enter password"
            value={value}
            onChange={(e) => setValue(e.target.value)}
            disabled={busy}
            className="min-w-0 flex-1 bg-transparent py-2.5 text-[15px] text-ink placeholder:text-ink/40 focus:outline-none"
            aria-label="Password"
          />
          <button
            type="submit"
            disabled={busy || !value.trim()}
            aria-label="Continue"
            className="grid h-11 w-11 shrink-0 place-items-center rounded-full bg-crimson text-cream transition hover:bg-crimson-deep disabled:opacity-45"
          >
            {busy ? <Spinner /> : <ArrowIcon />}
          </button>
        </div>
      </motion.form>

      {error && (
        <motion.p
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          className="mt-3 text-sm text-rose-bright"
        >
          {error}
        </motion.p>
      )}
    </motion.div>
  );
}

function LockIcon() {
  return (
    <svg viewBox="0 0 24 24" className="h-5 w-5 shrink-0 text-ink/50" fill="none" stroke="currentColor" strokeWidth={1.8}>
      <rect x="4.5" y="10.5" width="15" height="10" rx="2.5" />
      <path d="M8 10.5V8a4 4 0 1 1 8 0v2.5" strokeLinecap="round" />
    </svg>
  );
}

function ArrowIcon() {
  return (
    <svg viewBox="0 0 24 24" className="h-5 w-5" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
      <path d="M5 12h14M13 6l6 6-6 6" />
    </svg>
  );
}

function Spinner() {
  return (
    <svg viewBox="0 0 24 24" className="h-5 w-5 animate-spin" fill="none" stroke="currentColor" strokeWidth={2.4} strokeLinecap="round">
      <path d="M12 3a9 9 0 1 0 9 9" />
    </svg>
  );
}
