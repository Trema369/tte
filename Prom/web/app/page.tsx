"use client";

import { useCallback, useEffect, useState } from "react";
import { AnimatePresence, motion } from "motion/react";
import { api } from "@/lib/api";
import type { Answer, Screen } from "@/lib/types";
import Stage from "@/components/Stage";
import Gate from "@/components/Gate";
import Ask from "@/components/Ask";
import YesResult from "@/components/YesResult";
import NoResult from "@/components/NoResult";

export default function Page() {
  const [screen, setScreen] = useState<Screen>("loading");
  const [sending, setSending] = useState(false);

  // On load, ask the server where we should be: past answers win, then the
  // unlock cookie, otherwise the gate.
  useEffect(() => {
    let cancelled = false;
    api
      .getState()
      .then((s) => {
        if (cancelled) return;
        if (s.answered === "yes") setScreen("yes");
        else if (s.answered === "no") setScreen("no");
        else if (s.unlocked) setScreen("ask");
        else setScreen("gate");
      })
      .catch(() => !cancelled && setScreen("gate"));
    return () => {
      cancelled = true;
    };
  }, []);

  const send = useCallback(
    async (answer: Answer) => {
      if (sending) return;
      setSending(true);
      // Move to the outcome screen first — her experience shouldn't wait on
      // the network, and the server call is idempotent anyway.
      setScreen(answer);
      try {
        await api.answer(answer);
      } catch {
        /* answer is recorded on retry / already shown; nothing to do here */
      } finally {
        setSending(false);
      }
    },
    [sending],
  );

  return (
    <main className="relative min-h-dvh">
      <AnimatePresence mode="wait">
        {screen === "loading" && (
          <motion.div
            key="loading"
            exit={{ opacity: 0 }}
            className="stage-gate fixed inset-0 grid place-items-center"
          >
            <span className="text-rose/60 text-2xl heart-pulse">&#9825;</span>
          </motion.div>
        )}

        {screen === "gate" && (
          <Stage key="gate" kind="gate" align="bottom-left">
            <Gate onUnlock={() => setScreen("ask")} />
          </Stage>
        )}

        {screen === "ask" && (
          <Stage key="ask" kind="ask">
            <Ask onYes={() => send("yes")} onNo={() => send("no")} />
          </Stage>
        )}

        {screen === "yes" && (
          <Stage key="yes" kind="yes">
            <YesResult />
          </Stage>
        )}

        {screen === "no" && (
          <Stage key="no" kind="no">
            <NoResult onReconsider={() => setScreen("ask")} />
          </Stage>
        )}
      </AnimatePresence>
    </main>
  );
}
